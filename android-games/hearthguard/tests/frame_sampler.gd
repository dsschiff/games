extends RefCounted
## Adapted from the completed Frontline frame_post_draw sampler; no image readback.
const WARMUP := 1.5
const MAX_ROWS := 60000
var rows: Array = []
var last_usec := 0
var warm_seconds := 0.0
var excluded := 0
var warm_frames := 0
var dropped := 0
var active := false
var metadata := {}
var observer := preload("res://tests/production_observer.gd").new()

func start(window: Window, scene: Node) -> void:
	assert(Engine.get_write_movie_path().is_empty() and not OS.get_cmdline_args().has("--fixed-fps"))
	metadata = {"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "os": OS.get_name(),
		"os_version": OS.get_version(), "engine": Engine.get_version_info(), "gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(), "gpu_driver": RenderingServer.get_video_adapter_api_version(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "window_pixels": DisplayServer.window_get_size(),
		"framebuffer_pixels": window.get_texture().get_size(), "visible_rect": window.get_visible_rect().size,
		"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps, "time_scale": Engine.time_scale,
		"physics_ticks_per_second": Engine.physics_ticks_per_second, "msaa_3d": window.msaa_3d,
		"screen_space_aa": window.screen_space_aa, "scaling_3d_scale": window.scaling_3d_scale,
		"settings": scene.settings.duplicate(true), "started_unix": Time.get_unix_time_from_system(),
		"capture": "No movie/fixed-fps/PNG/framebuffer readback during measured interval; metadata dimensions only"}
	active = true

func eligible(scene: Node) -> bool:
	return is_instance_valid(scene) and scene.state.phase == "playing" and not scene.paused and not scene.menu.visible and not scene.transfer.visible and not scene.journey.visible and not scene.confirm_panel.visible and not scene.ending_panel.visible and not scene.terminal.visible

func sample(scene: Node) -> void:
	if not active:
		return
	if not eligible(scene):
		excluded += 1
		last_usec = 0
		warm_seconds = 0
		return
	var now := Time.get_ticks_usec()
	if last_usec == 0:
		last_usec = now
		return
	var ms := (now - last_usec) / 1000.0
	last_usec = now
	warm_seconds += ms / 1000.0
	if warm_seconds <= WARMUP:
		warm_frames += 1
		return
	if rows.size() >= MAX_ROWS:
		dropped += 1
		return
	var friendly := 1
	for tower in scene.state.towers:
		friendly += int(tower.family >= 0)
	var bosses: Array = []
	for enemy in scene.state.enemies:
		var role: String = scene.state.definition.roster[int(enemy.id)].role
		if role in ["ram", "matriarch", "regent"] and enemy.hp > 0:
			bosses.append(role)
	var pool: Dictionary = observer.pool_sample(scene)
	rows.append([ms, float(scene.state.time), friendly, scene.state.enemies.size(), bosses, scene.settings.reduced_effects,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.MEMORY_STATIC)), Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, scene.presenter.effects.size(), pool.actor_reserve, pool.effect_reserve,
		pool.actor_cross_id_reuses, pool.effect_observed_reuses])

func summarize(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"frames": 0}
	var intervals: Array = samples.map(func(row): return float(row[0]))
	intervals.sort()
	var seconds := 0.0
	var over_60 := 0
	var over_30 := 0
	var draws := 0
	var primitives := 0
	var nodes := 0
	var enemies := 0
	for row in samples:
		seconds += float(row[0]) / 1000
		over_60 += int(float(row[0]) > 16.667)
		over_30 += int(float(row[0]) > 33.333)
		draws = maxi(draws, row[6])
		primitives = maxi(primitives, row[7])
		nodes = maxi(nodes, row[9])
		enemies = maxi(enemies, row[3])
	return {"frames": samples.size(), "seconds": seconds, "median_ms": intervals[floori((intervals.size() - 1) * .5)],
		"p95_ms": intervals[ceili(intervals.size() * .95) - 1], "p99_ms": intervals[ceili(intervals.size() * .99) - 1],
		"over_16_667_ms": over_60, "over_33_333_ms": over_30, "draw_calls_max": draws,
		"primitives_max": primitives, "nodes_max": nodes, "enemies_max": enemies}

func stop() -> Dictionary:
	active = false
	var worst := rows.duplicate()
	worst.sort_custom(func(a, b): return a[0] > b[0])
	return {"schema": 1, "metadata": metadata, "criteria": {"clock": "Time.get_ticks_usec in frame_post_draw: host render-loop submission intervals, not OS presentation or GPU timestamps",
		"warmup_eligible_seconds": WARMUP, "exclusions": "paused/ready/terminal/loading and visible modals; cursor and warmup reset across gaps",
		"heavy_filter": "live Ram/Matriarch/Regent OR at least6 live enemies; friendly count is commander plus constructed tower operators, excludes decorative citizens",
		"percentiles": "nearest rank ceil(n*p)-1; median lower middle floor((n-1)*.5)",
		"counter_scope": "Performance total draw/primitives/render-objects for the entire Godot viewport, including UI/scenery; process/physics CPU monitors; instrumentation, real input and normal autosaves remain in process",
		"limits": "Unpaced desktop host only; not display-presented FPS, maximum possible density, phone performance or fun"},
		"excluded_frames": excluded, "warmup_frames": warm_frames, "row_cap": MAX_ROWS, "samples_dropped_after_cap": dropped,
		"all_frames": summarize(rows), "heavy_frames": summarize(rows.filter(func(row): return not row[4].is_empty() or row[3] >= 6)),
		"columns": ["submission_interval_ms", "simulation_seconds", "friendly_combatants", "enemies", "live_bosses", "reduced_effects", "draw_calls", "primitives", "render_objects", "nodes", "static_memory_bytes", "process_cpu_ms", "physics_cpu_ms", "visible_effects", "actor_reserve", "effect_reserve", "actor_observed_cross_id_reuses", "effect_observed_reuses"],
		"rows": rows, "worst25": worst.slice(0, 25), "last120": rows.slice(maxi(0, rows.size() - 120)),
		"pool_observation": observer.report()}
