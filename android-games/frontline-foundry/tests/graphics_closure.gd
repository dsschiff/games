extends "res://tests/graphics_benchmark.gd"
## Focused real-input review closure. No gameplay/animation handler calls.
var stage := "park"
var native_frames := false
var recording := false
var frame_rows: Array = []
var check_rows: Array = []
var closure_events: Array = []
var canvas_size := Vector2i(984, 1280)

func _initialize() -> void:
	super._initialize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			stage = arg.trim_prefix("--stage=")
		if arg == "--native-frames":
			native_frames = true

func check(okay: bool, message: String) -> void:
	check_rows.append({"pass": okay, "message": message, "frame": Engine.get_physics_frames()})
	if not okay:
		errors.append(message)
		push_error(message)

func run() -> void:
	Engine.time_scale = 1.0
	root.size = Vector2i(720, 1280)
	if expected_start.is_empty():
		errors.append("Closure requires an authentic app-written boundary")
		await finish()
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_start))
	var loaded := S.read()
	if not loaded.ok or not D.same(loaded.state, expected.state) or not D.same(loaded.profile, expected.profile) or not D.same(loaded.settings, expected.settings) or not D.same(loaded.career, expected.career):
		errors.append("Authentic expected boundary failed before boot")
		await finish()
		return
	app = load("res://boot.tscn").instantiate()
	root.add_child(app)
	for i in 5:
		await process_frame
	scene = app.session
	start_time = scene.state.time
	if native_frames and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
		RenderingServer.frame_post_draw.connect(record_frame)
		recording = true
	await snap("00-authentic-loaded-boundary")
	check(D.same(scene.state, expected.state) and D.same(scene.career, expected.career) and D.same(scene.profile, expected.profile) and D.same(scene.settings, expected.settings), "actual loaded complete boundary equals genuine supplied save")
	match stage:
		"sideways":
			await sideways_passage()
		"park":
			await park_passage()
		"restore":
			await restore_passage()
		"retry":
			await retry_passage()
		_:
			check(false, "unknown closure stage")
	await snap("99-final-state")
	await finish()

func whole() -> Dictionary:
	return {"state": scene.state.duplicate(true), "profile": scene.profile.duplicate(true), "career": scene.career.duplicate(true), "settings": scene.settings.duplicate(true)}

func poses() -> String:
	var rows := {}
	for key in scene.presentation.units:
		var unit: Node3D = scene.presentation.units[key]
		var bones: Array = []
		if unit.rig != null:
			for index in unit.rig.get_bone_count():
				bones.append([unit.rig.get_bone_pose_rotation(index), unit.rig.get_bone_pose_scale(index)])
		rows[key] = [unit.position, unit.rotation, unit.model.rotation, unit.gait, unit.fire_left, unit.hit_left, unit.death_time, bones]
	return JSON.stringify(rows)

func dwell(seconds: float) -> void:
	for i in int(ceil(seconds * 60)):
		await physics_frame

func pause_and_hold(label: String) -> void:
	if not scene.paused:
		await release()
		await click(scene.pause_button.text)
	await dwell(.15)
	check(scene.paused, label + " real GUI pause")
	var saved := whole()
	var pose := poses()
	await snap(label + "-held-before")
	await dwell(1.0)
	check(D.same(whole(), saved) and poses() == pose, label + " complete state and actor poses freeze")
	await snap(label + "-held-after")

func play_policy(seconds: float) -> void:
	var until: float = scene.state.time + seconds
	for i in int(seconds * 65) + 60:
		if scene.state.phase != "playing" or scene.paused or scene.state.time >= until:
			break
		var choice := P.decide(scene.state)
		if choice.station >= 0 and C.can_buy(scene.state, choice.station):
			await release()
			await click(scene.build_button.text)
		else:
			steer((choice.goal - C.position(scene.state)).limit_length())
			await physics_frame
	await release()

func wait_for_warning(seconds: float) -> bool:
	var until: float = scene.state.time + seconds
	for i in int(seconds * 65) + 60:
		if not scene.state.marks.is_empty():
			return true
		if scene.state.phase != "playing" or scene.paused or scene.state.time >= until:
			break
		var choice := P.decide(scene.state)
		steer((choice.goal - C.position(scene.state)).limit_length())
		await physics_frame
	return false

func park_passage() -> void:
	check(scene.state.phase == "playing" and scene.paused, "park starts from genuine active save paused on boot")
	await pause_and_hold("initial-pause")
	await click("RESUME")
	var before: Vector2 = C.position(scene.state)
	await play_policy(1.0)
	check(not scene.paused and C.position(scene.state).distance_to(before) > .1, "real resume and joystick produce movement")
	await pause_and_hold("active-pause")
	if not scene.settings.reduced_effects:
		await click(scene.effects_button.text)
	check(scene.settings.reduced_effects, "real GUI enables reduced effects and writes setting")
	await click("RESUME")
	var found := await wait_for_warning(30)
	check(found and scene.settings.reduced_effects and scene.presentation.warnings.size() > 0, "real Storm telegraph remains visible with reduced effects")
	await snap("reduced-effects-live-warning")
	await pause_and_hold("warning-pause")
	var held := whole()
	root.size = Vector2i(984, 1092)
	await dwell(.2)
	closure_events.append({"kind": "window_resize", "requested": [984, 1092], "actual": DisplayServer.window_get_size(), "frame": Engine.get_physics_frames()})
	check(D.same(whole(), held), "paused inner-aspect resize retains the entire context")
	await snap("inner-aspect-paused-warning")
	await click("RESUME")
	before = C.position(scene.state)
	await play_policy(.6)
	check(C.position(scene.state).distance_to(before) > .1, "real joystick works in resized live window")
	var career_before: Dictionary = scene.career.duplicate(true)
	var profile_before: Dictionary = scene.profile.duplicate(true)
	var definition: String = scene.state.definition_hash
	root.size = Vector2i(720, 1280)
	await dwell(.2)
	closure_events.append({"kind": "live_window_resize", "requested": [720, 1280], "actual": DisplayServer.window_get_size(), "frame": Engine.get_physics_frames()})
	check(not scene.paused and D.same(scene.career, career_before) and D.same(scene.profile, profile_before) and scene.state.definition_hash == definition and scene.input_vector == Vector2.ZERO, "live resize retains encounter identity and clears active stick")
	await snap("native-live-after-resize")
	found = await wait_for_warning(5)
	check(found, "next real warning provides an active cold-save boundary")
	await pause_and_hold("cold-save-warning")
	await export_app_written_save()

func restore_passage() -> void:
	check(scene.paused and scene.state.phase == "playing" and scene.settings.reduced_effects and not scene.state.marks.is_empty(), "cold boot restores reduced-effects active warning, whole profile and paused presentation")
	check(scene.presentation.effects.is_empty() and scene.presentation.pending.is_empty(), "cold hydration has no phantom effects or queued attacks")
	await pause_and_hold("cold-loaded-pause")
	await click("RESUME")
	var before: Vector2 = C.position(scene.state)
	await play_policy(.2)
	await snap("cold-resume-essential-warning")
	await play_policy(3.0)
	check(not scene.paused and C.position(scene.state).distance_to(before) > .1 and scene.settings.reduced_effects, "cold resume retains articulated real movement under reduced effects")
	await snap("cold-resumed-live-motion")
	await pause_and_hold("cold-resumed-pause")
	await export_app_written_save()

func retry_passage() -> void:
	check(scene.state.phase == "victory", "Retry starts from a genuine naturally earned terminal save")
	var earned: Dictionary = scene.career.duplicate(true)
	var profile_before: Dictionary = scene.profile.duplicate(true)
	var definition: String = scene.state.definition_hash
	await dwell(1)
	await click("RETRY SIEGE")
	check(scene.state.phase == "ready" and scene.state.time == 0 and scene.state.definition_hash == definition and D.same(scene.career, earned) and D.same(scene.profile, profile_before), "real Retry rebuilds the same definition and retains the entire earned profile")
	check(scene.presentation.effects.is_empty() and scene.presentation.pending.is_empty(), "real Retry with reused actor IDs has no stale effects")
	await snap("genuine-retry-ready")
	await dwell(1)
	await click("LAUNCH SORTIE")
	await play_policy(1.4)
	await snap("genuine-retry-live")
	await pause_and_hold("retry-live-pause")

func sideways_passage() -> void:
	check(scene.paused and scene.state.phase == "playing", "sideways shot starts from genuine active opening save")
	await click("RESUME")
	var cursor: int = scene.event_log.size()
	var until: float = scene.state.time + 28
	var found := false
	for frame in 1800:
		if scene.state.phase != "playing" or scene.state.time >= until or found:
			break
		steer((Vector2(-4.2, 5.5) - C.position(scene.state)).limit_length())
		await physics_frame
		for i in range(cursor, scene.event_log.size()):
			var row: Dictionary = scene.event_log[i]
			var event: Dictionary = row.event
			if event.kind != "shot" or event.owner != "rover":
				continue
			var unit: Node3D = scene.presentation.units.get(event.actor)
			if unit == null or absf(unit.turret.rotation.y) < deg_to_rad(30):
				continue
			var trail := {}
			for effect in scene.presentation.effects:
				var node: MeshInstance3D = effect.node
				if not node.mesh is BoxMesh:
					continue
				var length: float = node.mesh.size.z
				var endpoint: Vector3 = node.global_position - node.global_basis.z * length * .5
				if endpoint.distance_to(Vector3(event.to[0], .75, event.to[1])) < .01:
					trail = {"origin": node.global_position + node.global_basis.z * length * .5, "endpoint": endpoint}
					break
			if trail.is_empty():
				continue
			found = true
			closure_events.append({"kind": "actual_sideways_rover_shot", "simulation": row.time, "event": event.duplicate(true), "turret_yaw": unit.turret.rotation.y, "hull_yaw": unit.rotation.y, "muzzle": unit.muzzle.global_position, "barrel_transform": unit.barrel.global_transform, "trail": trail, "frame": Engine.get_physics_frames()})
			await snap("actual-sideways-shot")
			await dwell(.14)
			await snap("actual-sideways-recoil")
			await dwell(1)
			break
		cursor = scene.event_log.size()
	await release()
	check(found, "actual authoritative rover attack emits a visible sideways tracer from animated barrel")
	await pause_and_hold("sideways-shot-pause")

func export_app_written_save() -> void:
	var actual := S.read()
	check(actual.ok and D.same(actual.state, scene.state) and D.same(actual.profile, scene.profile) and D.same(actual.career, scene.career) and D.same(actual.settings, scene.settings), "real GUI pause wrote the complete current context before cold exit")
	var destination := folder.path_join("closure-save")
	DirAccess.make_dir_recursive_absolute(destination)
	var hashes := {}
	for slot in 2:
		var source: String = S.PATH + str(slot)
		if FileAccess.file_exists(source):
			var bytes := FileAccess.get_file_as_bytes(source)
			var file := FileAccess.open(destination.path_join("frontline-save-" + str(slot)), FileAccess.WRITE)
			file.store_buffer(bytes)
			file.close()
			hashes[str(slot)] = FileAccess.get_sha256(source)
	var file := FileAccess.open(destination.path_join("provenance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Exact app-written slots copied after real GUI Pause; no packet edits", "stage": stage, "slot_sha256": hashes, "state": actual.state, "career": actual.career, "profile": actual.profile, "settings": actual.settings}, "  "))

func record_frame() -> void:
	if not recording:
		return
	var image := root.get_texture().get_image()
	var size := image.get_size()
	if size.x > canvas_size.x or size.y > canvas_size.y:
		errors.append("Native framebuffer exceeds fixed evidence canvas; refusing crop/scale")
		recording = false
		return
	var canvas := Image.create(canvas_size.x, canvas_size.y, false, image.get_format())
	canvas.fill(Color("1d2c27"))
	canvas.blit_rect(image, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	var index := frame_rows.size()
	var error := canvas.save_png(folder.path_join("frames/%06d.png" % index))
	if error != OK:
		errors.append("Native frame write failed: " + str(error))
		recording = false
	var window := DisplayServer.window_get_size()
	frame_rows.append({"index": index, "physics_frame": Engine.get_physics_frames(), "simulation": scene.state.time, "paused": scene.paused, "native_pixels": [size.x, size.y], "window_pixels": [window.x, window.y]})

func finish() -> void:
	recording = false
	if not folder.is_empty():
		var file := FileAccess.open(folder.path_join("closure-report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"stage": stage, "checks": check_rows, "events": closure_events, "frames": frame_rows, "canvas_pixels": canvas_size, "scope": "Separate natural process passage; real GUI touch, Window size API and exact app-written saves only. Native frame pixels are padded, never scaled. Fixed-step 1x simulation; focused frame videos are silent. No stitched cold-relaunch claim, injected gameplay, handler calls or clipboard."}, "  "))
	print("FRONTLINE_CLOSURE ", stage, " checks=", check_rows.size(), " errors=", errors)
	await super.finish()
