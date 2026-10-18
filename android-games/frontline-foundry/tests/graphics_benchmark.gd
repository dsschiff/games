extends SceneTree
## Executable real-input capture policy. Root schedules rendered runs. No state
## injection, handler calls, time scaling, campaign skip, ADB or clipboard use.
const C = preload("res://scripts/campaign_rules.gd")
const P = preload("res://tests/policy.gd")
const S = preload("res://scripts/save_store.gd")
const D = preload("res://scripts/definitions.gd")
var app: Node
var scene: Node
var folder := ""
var duration := 145.0
var touch_active := false
var inputs: Array = []
var captures: Array = []
var observed := {}
var errors: Array = []
var start_time := 0.0
var finished := false
var expected_start := ""
var measure_frames := false
var sampler := preload("res://tests/frame_sampler.gd").new()
var require_reuse := false
var actor_leases := {}
var reuse_observations: Array = []
var save_boundary := {}
var measurement_resumes: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--seconds="):
			duration = clampf(float(arg.trim_prefix("--seconds=")), 1, 180)
		if arg.begins_with("--expected-start="):
			expected_start = arg.trim_prefix("--expected-start=")
		if arg == "--measure-frames":
			measure_frames = true
		if arg == "--require-reuse":
			require_reuse = true
	call_deferred("run")

func run() -> void:
	Engine.time_scale = 1.0
	root.size = Vector2i(720, 1280)
	if measure_frames:
		assert(Engine.get_write_movie_path().is_empty() and not "--fixed-fps" in OS.get_cmdline_args())
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		assert(Engine.max_fps == 0 and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED)
	if not expected_start.is_empty():
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_start))
		var actual := S.read()
		if not actual.ok or not D.same(actual.state, expected.state) or not D.same(actual.profile, expected.profile) or not D.same(actual.settings, expected.settings) or not D.same(actual.career, expected.career):
			errors.append("Expected authentic saved boundary failed decode or complete-state equality; stopped before boot can create/write a fresh campaign.")
			await finish()
			return
	app = load("res://boot.tscn").instantiate()
	root.add_child(app)
	for i in 5:
		await process_frame
	scene = app.session
	if int(scene.state.catalog) != 2:
		errors.append("Requires a fresh isolated campaign profile or genuinely earned campaign save; legacy saves are never overwritten by this capture policy.")
		await finish()
		return
	await snap("00-loaded-boundary")
	if scene.paused:
		await click("RESUME")
	elif scene.state.phase == "ready":
		await click("LAUNCH SORTIE")
	if scene.state.phase != "playing" or scene.paused:
		errors.append("Real start/resume input did not reach active campaign")
		await finish()
		return
	start_time = scene.state.time
	observe_reuse()
	if measure_frames:
		sampler.start(root)
		RenderingServer.frame_post_draw.connect(sample_frame)
	var started := Time.get_ticks_msec()
	var purchase_count: int = scene.state.purchases.size()
	while scene.state.phase == "playing" and scene.state.time - start_time < duration and not finished:
		if Time.get_ticks_msec() - started > int((duration + 35) * 1000):
			errors.append("Stopped at wall-clock bound; no time-scale compensation")
			break
		if measure_frames and scene.paused:
			# Focus loss invokes the real game's pause policy. Use its GUI to
			# resume and retain the interruption; held frames remain excluded.
			measurement_resumes.append({"simulation": scene.state.time, "wall_msec": Time.get_ticks_msec(), "menu_visible": scene.menu.visible})
			await release()
			await click("RESUME")
			if scene.paused:
				errors.append("Real Resume input did not clear observed measurement pause")
				break
		var choice := P.decide(scene.state)
		if choice.station >= 0 and C.can_buy(scene.state, choice.station):
			await release()
			await click(scene.build_button.text)
			if scene.state.purchases.size() != purchase_count + 1:
				errors.append("Real contextual purchase did not append one purchase")
				break
			purchase_count += 1
			await snap("purchase-%02d" % purchase_count)
		else:
			steer((choice.goal - C.position(scene.state)).limit_length())
			await physics_frame
		observe_reuse()
		for spec in [["equipping", scene.state.recruits.any(func(r): return r.phase == "equipping")], ["deployment", scene.state.recruits.any(func(r): return r.phase == "deploying" and r.waypoint == 1)], ["recruit-fire", scene.state.recruits.any(func(r): return r.shots > 0)], ["vehicle", scene.state.recruits.any(func(r): return r.role == "rover" and r.phase == "fighting")], ["collected", not scene.state.collected.is_empty()], ["first-casualty", not scene.state.killed.is_empty()], ["hostile-contact", scene.state.commander_taken + scene.state.hq_taken > 0]]:
			if spec[1] and not observed.has(spec[0]):
				observed[spec[0]] = scene.state.time
				await snap(spec[0])
	if measure_frames:
		RenderingServer.frame_post_draw.disconnect(sample_frame)
		var file := FileAccess.open(folder.path_join("frame-timing.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(sampler.stop(), "  "))
	await release()
	await snap("99-final-untouched-state")
	if require_reuse:
		var pool: Dictionary = scene.presentation.pool_snapshot()
		if pool.actors_reused <= 0 or pool.effects_reused <= 0 or reuse_observations.is_empty():
			errors.append("Authentic passage did not observe actual actor/model/rig plus effect-node reuse")
		if pool.inactive_actors > pool.inactive_actor_cap or pool.inactive_effects > pool.inactive_effect_cap or pool.active_effects > pool.active_effect_cap:
			errors.append("Actual reserve/effect cap exceeded")
		if scene.state.phase == "playing" and not scene.paused:
			await click("II")
		await retain_app_written_boundary()
		await snap("genuine-paused-save-boundary")
	await finish()

func observe_reuse() -> void:
	if not require_reuse:
		return
	for key in scene.presentation.units:
		var actor: Node3D = scene.presentation.units[key]
		var id := actor.get_instance_id()
		if actor_leases.has(id) and actor_leases[id] != key:
			reuse_observations.append({"simulation": scene.state.time, "instance": id, "old_key": actor_leases[id], "new_key": key, "role": actor.role, "team": actor.team, "model_instance": actor.model.get_instance_id(), "rig_instance": actor.rig.get_instance_id() if actor.rig != null else 0, "death_time": actor.death_time, "epoch": scene.presentation.adapter.epoch})
		actor_leases[id] = key

func retain_app_written_boundary() -> void:
	var actual := S.read()
	if not actual.ok or not D.same(actual.state, scene.state) or not D.same(actual.profile, scene.profile) or not D.same(actual.settings, scene.settings) or not D.same(actual.career, scene.career):
		errors.append("Actual GUI pause did not preserve complete current state/profile/settings/career on disk")
		return
	var destination := folder.path_join("reuse-save")
	DirAccess.make_dir_recursive_absolute(destination)
	var hashes := {}
	for slot in 2:
		var path: String = S.PATH + str(slot)
		if FileAccess.file_exists(path):
			var file := FileAccess.open(destination.path_join("frontline-save-" + str(slot)), FileAccess.WRITE)
			file.store_buffer(FileAccess.get_file_as_bytes(path))
			file.close()
			hashes[str(slot)] = FileAccess.get_sha256(path)
	save_boundary = {"method": "Exact raw app-written slots after real GUI pause; no packet edits or forced save handler", "slot_sha256": hashes, "state": actual.state, "profile": actual.profile, "settings": actual.settings, "career": actual.career, "revision": actual.revision}
	var file := FileAccess.open(destination.path_join("provenance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(save_boundary, "  "))

func origin() -> Vector2:
	return Vector2(110, root.get_visible_rect().size.y - 115)

func sample_frame() -> void:
	sampler.sample(scene)

func steer(direction: Vector2) -> void:
	if not touch_active:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = root.get_final_transform() * origin()
		touch.pressed = true
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		touch_active = true
		inputs.append({"kind": "stick_press", "frame": Engine.get_physics_frames(), "position": touch.position})
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = root.get_final_transform() * (origin() + direction * 65)
	drag.relative = direction * 65
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	inputs.append({"kind": "stick_drag", "frame": Engine.get_physics_frames(), "time": scene.state.time, "position": drag.position})

func release() -> void:
	if touch_active:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = root.get_final_transform() * origin()
		touch.pressed = false
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		touch_active = false
		inputs.append({"kind": "stick_release", "frame": Engine.get_physics_frames()})
	await process_frame

func click(text: String) -> void:
	await process_frame
	var target: Button
	for button in scene.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree() and not button.disabled:
			target = button
	if target == null:
		errors.append("Missing enabled GUI target " + text)
		finished = true
		return
	var point := root.get_final_transform() * target.get_global_rect().get_center()
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 1
		touch.position = point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		inputs.append({"kind": "gui_press" if pressed else "gui_release", "frame": Engine.get_physics_frames(), "target": text, "position": point})
		await process_frame

func snap(name: String) -> void:
	var row := {"name": name, "frame": Engine.get_physics_frames(), "state": scene.state.duplicate(true), "career": scene.career.duplicate(true), "profile": scene.profile.duplicate(true), "settings": scene.settings.duplicate(true), "presentation_epoch": scene.presentation.adapter.epoch, "actors": scene.presentation.units.size(), "effects": scene.presentation.effects.size(), "pool": scene.presentation.pool_snapshot()}
	if not folder.is_empty() and DisplayServer.get_name() != "headless" and not sampler.active:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		row["image_pixels"] = [image.get_width(), image.get_height()]
		row["image_error"] = image.save_png(folder.path_join(name + ".png"))
	captures.append(row)

func finish() -> void:
	var sources := {}
	for path in ["scripts/presentation/actor.gd", "scripts/presentation/adapter.gd", "scripts/presentation/outpost.gd", "scripts/campaign_rules.gd", "scripts/campaign_main.gd", "scripts/main.gd", "scripts/definitions.gd", "tests/graphics_benchmark.gd", "tests/policy.gd", "art/source/build_assets.py", "art/manifest.json", "project.godot"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	for file in DirAccess.get_files_at("res://art/models"):
		if file.ends_with(".glb"):
			sources["art/models/" + file] = FileAccess.get_sha256("res://art/models/" + file)
	var report := {"scope": "Normal 1x real Godot ScreenTouch/GUI input; read-only policy; no gameplay injection, handler calls, forced save/render state, clipboard or ADB. Structural/headless execution is not visual acceptance.", "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "viewport": root.size, "time_scale": Engine.time_scale, "sources_sha256": sources, "inputs": inputs, "captures": captures, "observed": observed, "errors": errors, "normal_speed_simulation_seconds": scene.state.time - start_time if scene != null else 0}
	report["dimensions"] = {"logical_visible_rect": root.get_visible_rect().size, "window_pixels": DisplayServer.window_get_size(), "root_window_size": root.size, "framebuffer_pixels": root.get_texture().get_size() if DisplayServer.get_name() != "headless" else Vector2.ZERO, "startup_window_override": Vector2i(ProjectSettings.get_setting("display/window/size/window_width_override"), ProjectSettings.get_setting("display/window/size/window_height_override")), "movie_encoded_size": "See external ffprobe movie-probe.json; script/root size never establishes encoded dimensions"}
	report["measurement_gui_resumes"] = measurement_resumes
	if scene != null:
		report["pool"] = scene.presentation.pool_snapshot()
		report["reuse_observations"] = reuse_observations
		report["save_boundary"] = save_boundary
	if not folder.is_empty():
		var file := FileAccess.open(folder.path_join("benchmark-report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
	print("FRONTLINE_GRAPHICS_BENCHMARK observed=", observed.keys(), " errors=", errors)
	if app != null:
		app.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
