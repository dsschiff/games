extends RefCounted
## Opt-in desktop measurement. This never changes simulation or rendering settings.
var rows: Array = []
var active := false
var last_usec := 0
var warm_seconds := 0.0
var excluded := 0
var metadata := {}
var dropped_rows := 0
const WARMUP := 1.5
const MAX_ROWS := 120000

func start(window: Window) -> void:
	metadata = {"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "device": OS.get_model_name(), "os": OS.get_name(), "os_version": OS.get_version(), "engine": Engine.get_version_info(), "gpu": RenderingServer.get_video_adapter_name(), "gpu_vendor": RenderingServer.get_video_adapter_vendor(), "gpu_driver": RenderingServer.get_video_adapter_api_version(), "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "window_pixels": DisplayServer.window_get_size(), "framebuffer_pixels": window.get_texture().get_size(), "visible_rect": window.get_visible_rect().size, "vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps, "time_scale": Engine.time_scale, "physics_ticks_per_second": Engine.physics_ticks_per_second, "msaa_3d": window.msaa_3d, "screen_space_aa": window.screen_space_aa, "scaling_3d_scale": window.scaling_3d_scale, "started_unix": Time.get_unix_time_from_system(), "capture": "No movie writer, fixed-fps argument, frame PNGs or framebuffer readbacks during measured interval"}
	active = true

func sample(scene: Node) -> void:
	if not active:
		return
	var eligible: bool = is_instance_valid(scene) and scene.state.phase == "playing" and not scene.paused and not scene.menu.visible and not scene.transfer.visible and not scene.journey.visible and not scene.seed_panel.visible and not scene.support_panel.visible
	if not eligible:
		excluded += 1
		last_usec = 0
		return
	var now := Time.get_ticks_usec()
	if last_usec == 0:
		last_usec = now
		return
	var ms := (now - last_usec) / 1000.0
	last_usec = now
	warm_seconds += ms / 1000.0
	if warm_seconds <= WARMUP:
		return
	if rows.size() >= MAX_ROWS:
		dropped_rows += 1
		return
	var friendly := 1
	for recruit in scene.state.recruits:
		if recruit.phase in ["deploying", "fighting"] and recruit.hp > 0:
			friendly += 1
	var bosses: Array = []
	for enemy in scene.state.enemies:
		if enemy.role in ["drill", "carrier", "storm"] and enemy.hp > 0:
			bosses.append(enemy.role)
	rows.append([ms, scene.state.time, friendly, scene.state.enemies.size(), bosses, scene.settings.reduced_effects, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.MEMORY_STATIC)), Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, scene.presentation.effects.size()])

func summarize(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"frames": 0}
	var intervals: Array = samples.map(func(row): return float(row[0]))
	intervals.sort()
	var seconds := 0.0
	var over_60 := 0
	var over_30 := 0
	var draw_max := 0
	var primitive_max := 0
	var node_max := 0
	var actor_max := 0
	for row in samples:
		seconds += float(row[0]) / 1000
		over_60 += int(float(row[0]) > 16.667)
		over_30 += int(float(row[0]) > 33.333)
		draw_max = maxi(draw_max, row[6])
		primitive_max = maxi(primitive_max, row[7])
		node_max = maxi(node_max, row[9])
		actor_max = maxi(actor_max, int(row[2]) + int(row[3]))
	return {"frames": samples.size(), "seconds": seconds, "median_ms": intervals[floori((intervals.size() - 1) * .5)], "p95_ms": intervals[ceili(intervals.size() * .95) - 1], "p99_ms": intervals[ceili(intervals.size() * .99) - 1], "over_16_667_ms": over_60, "over_33_333_ms": over_30, "draw_calls_max": draw_max, "primitives_max": primitive_max, "nodes_max": node_max, "combatants_max": actor_max}

func stop() -> Dictionary:
	active = false
	return {"schema": 1, "row_cap": MAX_ROWS, "dropped_rows": dropped_rows, "metadata": metadata, "criteria": {"clock": "Time.get_ticks_usec in RenderingServer.frame_post_draw: render-loop submission intervals, not OS presentation timestamps or GPU timestamps", "warmup_eligible_seconds": WARMUP, "exclusions": "paused, ready, terminal, loading and visible modals; interval cursor resets across gaps", "heavy_filter": "a live Drill, Carrier or Storm boss OR at least 12 actual combatants (commander + deployed/fighting recruits + enemies)", "limits": "Desktop host observation only; instrumentation and actual input policy remain in process; no phone frame-rate inference"}, "excluded_frames": excluded, "all_frames": summarize(rows), "heavy_frames": summarize(rows.filter(func(row): return not row[4].is_empty() or int(row[2]) + int(row[3]) >= 12)), "columns": ["submission_interval_ms", "simulation_seconds", "friendly_combatants", "enemies", "live_bosses", "reduced_effects", "draw_calls", "primitives", "render_objects", "nodes", "static_memory_bytes", "process_cpu_ms", "physics_cpu_ms", "visible_effects"], "rows": rows}
