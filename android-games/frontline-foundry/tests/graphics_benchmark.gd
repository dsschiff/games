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
	call_deferred("run")

func run() -> void:
	Engine.time_scale = 1.0
	root.size = Vector2i(720, 1280)
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
	if measure_frames:
		sampler.start(root)
		RenderingServer.frame_post_draw.connect(sample_frame)
	var started := Time.get_ticks_msec()
	var purchase_count: int = scene.state.purchases.size()
	while scene.state.phase == "playing" and scene.state.time - start_time < duration and not finished:
		if Time.get_ticks_msec() - started > int((duration + 35) * 1000):
			errors.append("Stopped at wall-clock bound; no time-scale compensation")
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
	await finish()

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
	var row := {"name": name, "frame": Engine.get_physics_frames(), "state": scene.state.duplicate(true), "career": scene.career.duplicate(true), "presentation_epoch": scene.presentation.adapter.epoch, "actors": scene.presentation.units.size(), "effects": scene.presentation.effects.size()}
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
	if not folder.is_empty():
		var file := FileAccess.open(folder.path_join("benchmark-report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
	print("FRONTLINE_GRAPHICS_BENCHMARK observed=", observed.keys(), " errors=", errors)
	if app != null:
		app.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
