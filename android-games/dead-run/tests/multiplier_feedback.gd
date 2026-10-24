extends "res://tests/campaign_input.gd"
## Fresh production owner and real ScreenTouch/Drag only. Typed label fixtures
## are tested separately after the earned opening and never saved as progress.
const Adapter = preload("res://scripts/presentation/adapter.gd")
class InputClock extends Node:
	var events: Array = []
	func _input(event: InputEvent) -> void:
		if not (event is InputEventScreenTouch or event is InputEventScreenDrag): return
		var row := {"physics_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(),
			"index": event.index, "position": [event.position.x, event.position.y]}
		row.kind = "touch" if event is InputEventScreenTouch else "drag"
		if event is InputEventScreenTouch: row.pressed = event.pressed
		events.append(row)

var route_only := false
var native_frames := false
var input_clock: InputClock
var clock_physics := 0
var clock_process := 0
var capture_active := false
var capture_ok := true
var capture_last_tick := -1
var duplicate_live_draws := 0
var capture_rows: Array = []
var capture_marks: Array = []
var pending_marks: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--route-only": route_only = true
		if arg == "--native-frames": native_frames = true
	super._initialize()

var observations: Array = []
var tick_contexts: Array = []
var crossings: Array = []
var mismatches: Array = []

func observe(label: String) -> void:
	var info: Dictionary = scene.presentation.gates[3]
	observations.append({"label": label, "tick": scene.state.tick, "context": scene.ctx.duplicate(true),
		"number": info.number.text, "caption": info.caption.text, "caption_font": info.caption.font_size})
	if route_only:
		pending_marks.append({"label": label, "requested_tick": scene.state.tick,
			"requested_physics": Engine.get_physics_frames() - clock_physics,
			"requested_process": Engine.get_process_frames() - clock_process,
			"requested_context_sha256": JSON.stringify(scene.ctx, "", true, true).sha256_text()})
		if label == "started":
			capture_active = true
			if native_frames: RenderingServer.frame_post_draw.connect(sample_capture)
			else: process_frame.connect(sample_capture)

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	if route_only:
		check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "route capture uses unscaled60Hz simulation")
		clock_physics = Engine.get_physics_frames()
		clock_process = Engine.get_process_frames()
		input_clock = InputClock.new()
		root.add_child(input_clock)
		if native_frames:
			DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
			DirAccess.make_dir_recursive_absolute(folder.path_join("stills"))
	await dwell(6)
	check(scene.journey_visible and scene.ctx.profile.clears.is_empty(), "fresh production owner has no invented progress")
	await click(scene.stage_buttons[0].text)
	await click("START RESCUE")
	check(scene.state.phase == "playing" and scene.state.weapon == "rivet", "actual Start begins fresh Rivet opening")
	observe("started")
	var partial := false
	var returned := false
	var away_until := -1
	var away_x := 0.0
	var before_hits := 0
	var valid := true
	var correct := true
	var last_hits := 0
	var last_value := 1
	for frame in 3300:
		if scene.state.phase != "playing" or scene.state.gates[3].crossed: break
		var s: Dictionary = scene.state
		var gd: Dictionary = s.definition.gates[3]
		var g: Dictionary = s.gates[3]
		var target := Policy.aim(s, "rescue-harm")
		if s.tick >= gd.born:
			target = gd.x + C.half_width(s.crew) + gd.width - .3
			if returned and g.z < 5: target = gd.x
			if not partial and g.hits >= 8 and g.value == 1:
				partial = true
				away_until = s.tick + 60
				away_x = 3.8 if gd.x < 0 else -3.8
				before_hits = g.hits
				observe("partial-before-away")
				check(scene.presentation.gates[3].caption.text.contains(str(int(g.hits)) + "/" + str(int(gd.step))), "partial actual hits are visible before threshold")
			if partial and s.tick < away_until: target = away_x
			elif partial and not returned:
				returned = true
				observe("return-to-gate")
				check(g.hits >= before_hits and g.hits < gd.step, "actual partial charge survives steering away and return before threshold")
		if absf(target - prior_aim) > .025:
			drive(target)
			prior_aim = target
		await physics_frame
		s = scene.state
		g = s.gates[3]
		tick_contexts.append({"tick": s.tick, "sha256": JSON.stringify(scene.ctx, "", true, true).sha256_text()})
		if frame % 60 == 0: valid = valid and C.valid(s)
		if int(g.value) != last_value:
			crossings.append({"before_hits": last_hits, "after_hits": g.hits, "tick": s.tick, "before_value": last_value, "after_value": g.value})
			observe("threshold")
		last_hits = g.hits
		last_value = g.value
		correct = correct and scene.presentation.gates[3].number.text == char(215) + str(int(g.value))
	check(valid and C.valid(scene.state), "every sampled earned opening context validates")
	check(partial and returned, "natural partial charge followed by actual steer away and return")
	check(not crossings.is_empty() and scene.state.gates[3].value == 2, "real projectile contacts earn multiplier threshold")
	check(scene.state.gates[3].crossed and scene.state.gates[3].applied == 2, "natural crossing applies displayed multiplier once")
	check(correct, "numeral always equals actual applied-value candidate")
	await release()
	await click("II")
	check(scene.paused, "actual Pause freezes final earned opening")
	observe("final-paused")
	var saved := Store.read()
	check(saved.ok and Data.same(saved.context, scene.ctx), "checked final save retains complete live context")
	var raw := {}
	for i in 2:
		for suffix in ["", ".tmp"]:
			var path: String = Store.PATH + str(i) + suffix
			if FileAccess.file_exists(path): raw[path] = FileAccess.get_file_as_string(path)
	var route_capture := {}
	var fixture_context: Dictionary = scene.ctx.duplicate(true)
	if route_only:
		route_capture = await finish_capture()
		check(Data.same(scene.ctx, fixture_context) and Data.same(Store.read(), saved), "final held draw flush preserves complete live and durable context")
		for path in raw:
			check(FileAccess.get_file_as_string(path) == raw[path], "final held draw flush preserves raw slot " + path)
	else:
		label_fixtures()
		check(Data.same(scene.ctx, fixture_context), "isolated label fixtures leave complete earned context unchanged")
	write("multiplier-feedback.json", {"checks": checks, "failures": failures, "details": details,
		"observations": observations, "crossings": crossings, "tick_contexts": tick_contexts,
		"route_only": route_only, "route_capture": route_capture, "mismatches": mismatches, "context": scene.ctx.duplicate(true), "saved": saved, "raw_slots": raw,
		"scope": "Fresh actual production input opening; no injected progress. CPU is not rendered/native/human acceptance."})
	write("raw-input-events.json", events)
	scene.queue_free()
	scene = null
	await process_frame
	await process_frame
	print("MULTIPLIER_FEEDBACK ", checks, " failures=", failures, " crossings=", crossings)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func label_fixtures() -> void:
	for catalog in [1, 2]:
		for road in 24:
			for seed in [0, 61723]:
				var s: Dictionary = C.Catalog1.fresh(road, "rivet", seed) if catalog == 1 else C.fresh(road, "rivet", seed)
				var p := Adapter.new()
				p.root = Node3D.new()
				root.add_child(p.root)
				p.kit = scene.presentation.kit
				p.label_font = scene.presentation.label_font
				p._build_gates(s.definition)
				var captions := true
				var fits := true
				var unchanged := true
				for i in s.gates.size():
					var gd: Dictionary = s.definition.gates[i]
					var g: Dictionary = s.gates[i]
					var mul: bool = gd.get("kind", "add") == "mul"
					var points: Array = [0]
					if mul:
						for value in range(int(gd.initial), int(gd.cap)):
							var threshold: int = (value + 1 - int(gd.initial)) * int(gd.step)
							points.append_array([threshold - 1, threshold, threshold + 1])
					for hits in points:
						g.hits = hits
						g.value = C.gate_value(gd, hits) if mul else mini(gd.cap, gd.initial + hits)
						s.tick = gd.born
						var before: Dictionary = s.duplicate(true)
						p._sync_gates(s, s.definition, true)
						unchanged = unchanged and Data.same(s, before)
						var caption: Label3D = p.gates[i].caption
						var expected := "CREW"
						if mul and g.value < gd.cap:
							expected = "NEXT %d/%d" % [hits, (int(g.value) + 1 - int(gd.initial)) * int(gd.step)]
						captions = captions and caption.text == expected
						if mul:
							var measured: float = (caption.font.get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.font_size).x + 2 * caption.outline_size) * caption.pixel_size
							if g.value < gd.cap: fits = fits and measured <= p.gates[i].panel.mesh.size.x - .1
							captions = captions and p.gates[i].number.text == char(215) + str(int(g.value))
						else: captions = captions and caption.font_size == 50 and caption.position == Vector3(0, .42, .05)
					g.crossed = true
					p._sync_gates(s, s.definition, true)
					captions = captions and not p.gates[i].node.visible
				check(captions, "catalog%d road%d seed%d: next threshold/cap, applied numeral, add gate and crossed visibility" % [catalog, road, seed])
				check(fits, "catalog%d road%d seed%d: measured caption and outline stay inside original panel" % [catalog, road, seed])
				check(unchanged, "catalog%d road%d seed%d: hydration reads pinned state without mutation" % [catalog, road, seed])
				p.root.queue_free()

func capture_metadata() -> Dictionary:
	var camera: Camera3D = scene.camera
	return {"tick": scene.state.tick, "physics": Engine.get_physics_frames() - clock_physics,
		"process": Engine.get_process_frames() - clock_process, "paused": scene.paused,
		"context_sha256": JSON.stringify(scene.ctx, "", true, true).sha256_text(),
		"camera": {"position": [camera.position.x, camera.position.y, camera.position.z],
			"rotation": [camera.rotation.x, camera.rotation.y, camera.rotation.z], "fov": camera.fov,
			"projection": camera.projection, "keep_aspect": camera.keep_aspect,
			"viewport": [root.size.x, root.size.y]}}

func sample_capture() -> void:
	if not capture_active or not is_instance_valid(scene): return
	var tick: int = scene.state.tick
	if not scene.paused and scene.state.phase == "playing" and tick >= 2 and tick % 2 == 0 and tick == capture_last_tick:
		duplicate_live_draws += 1
		capture_ok = false
	capture_ok = capture_ok and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60
	var sample: bool = not scene.paused and scene.state.phase == "playing" and tick >= 2 and tick % 2 == 0 and tick != capture_last_tick
	if not sample and pending_marks.is_empty(): return
	var row := capture_metadata()
	var image: Image
	if native_frames:
		image = root.get_texture().get_image()
		capture_ok = capture_ok and image.get_size() == Vector2i(720, 1280)
		row.image_size = [image.get_width(), image.get_height()]
	if sample:
		capture_ok = capture_ok and tick == (2 if capture_last_tick < 0 else capture_last_tick + 2)
		capture_last_tick = tick
		var filename := "frames/%06d.png" % capture_rows.size()
		row.file = filename
		if native_frames: capture_ok = image.save_png(folder.path_join(filename)) == OK and capture_ok
		capture_rows.append(row)
	for mark in pending_marks:
		var filename: String = "stills/" + mark.label + ".png"
		mark.actual = capture_metadata()
		mark.file = filename
		if native_frames:
			mark.actual.image_size = [image.get_width(), image.get_height()]
			capture_ok = image.save_png(folder.path_join(filename)) == OK and capture_ok
		capture_marks.append(mark)
	pending_marks.clear()

func finish_capture() -> Dictionary:
	check(scene.paused and scene.state.tick == 2737, "capture ends only at the original actual paused boundary")
	# No live-route await: finish the last marked still only after actual Pause.
	if native_frames: await RenderingServer.frame_post_draw
	else: await process_frame
	capture_active = false
	if RenderingServer.frame_post_draw.is_connected(sample_capture): RenderingServer.frame_post_draw.disconnect(sample_capture)
	if process_frame.is_connected(sample_capture): process_frame.disconnect(sample_capture)
	check(capture_ok and capture_rows.size() == 1368 and capture_last_tick == 2736, "every two simulation ticks forms the complete 45.6s30fps route without gaps")
	check(pending_marks.is_empty() and capture_marks.size() == 5, "all five real route marks flush without a gameplay hold")
	var timed_inputs: Array = input_clock.events.duplicate(true)
	for event in timed_inputs:
		event.physics_frame -= clock_physics
		event.process_frame -= clock_process
	input_clock.queue_free()
	return {"rendered": native_frames, "time_scale": Engine.time_scale, "simulation_hz": Engine.physics_ticks_per_second, "video_fps": 30, "duration_seconds": 45.6, "duplicate_live_draws": duplicate_live_draws,
		"clock_origin_physics": clock_physics, "clock_origin_process": clock_process,
		"observer": "frame_post_draw" if native_frames else "headless process_frame plan; no pixels",
		"frames": capture_rows, "marks": capture_marks, "timed_inputs": timed_inputs,
		"limits": "No resizing, frame interpolation, live-route waits or typed fixture tail. Fixed-step video is not measured FPS, native Android or human pacing."}
