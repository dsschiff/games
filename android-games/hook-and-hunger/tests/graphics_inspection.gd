extends "res://tests/native_transfer.gd"
const Policy = preload("res://tests/campaign_policy.gd")
var checkpoint := ""
var seconds := 8.0
var native_frames := false
var recording := false
var frame_number := 0
var observed_roles := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--checkpoint="):
			checkpoint = arg.trim_prefix("--checkpoint=")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
		elif arg == "--native-frames":
			native_frames = true
	call_deferred("run")

func capture_native_frame() -> void:
	if not recording or not native_frames:
		return
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(720, 1280):
		recording = false
		check(false, "actual movie framebuffer must be 720x1280")
		return
	image.save_png(capture_dir.path_join("frames/%06d.png" % frame_number))
	frame_number += 1

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered inspection requires root's explicit render slot. CPU checks use presentation_tests.")
		quit(1)
		return
	check(DisplayServer.window_get_size() == Vector2i(720, 1280), "actual desktop window is 720x1280")
	var loaded := S.decode(FileAccess.get_file_as_string(checkpoint))
	check(loaded.ok, "authenticated historical earned export decodes")
	if not loaded.ok:
		quit(1)
		return
	check(S.write(loaded.state, loaded.settings, S.PATH, null, false, loaded.profile), "isolated test save installs complete historical earned context")
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	check(scene.state == loaded.state and scene.profile == loaded.profile and scene.settings == loaded.settings, "normal cold load preserves complete selected packet")
	if scene.paused:
		await tap_button("RESUME")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().get_size() == Vector2i(720, 1280), "actual framebuffer is 720x1280")
	await snap("inspection-before")
	if native_frames:
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("frames"))
		recording = true
		RenderingServer.frame_post_draw.connect(capture_native_frame)
	var started: float = scene.state.time
	var wall := Time.get_ticks_msec()
	while scene.state.phase == "playing" and scene.state.time - started < seconds:
		if Time.get_ticks_msec() - wall > 60000:
			check(false, "inspection wall timeout; lifecycle pause remains genuine")
			break
		for enemy in scene.presentation.actors.values():
			observed_roles[enemy.role] = true
		await steer(Policy.direction(scene.state))
		await physics_frame
	await release()
	recording = false
	await snap("inspection-after")
	var output := {"checks": checks, "failures": failures, "details": report, "events": events,
		"checkpoint": checkpoint, "state": scene.state, "profile": scene.profile, "settings": scene.settings,
		"observed_roles": observed_roles.keys(), "frames": frame_number, "simulation_seconds": scene.state.time - started,
		"scope": "Short authenticated earned-save continuation using real engine touch. Fixed cadence frames are not FPS. No phone/native Android/graphics acceptance from this harness alone."}
	FileAccess.open(capture_dir.path_join("inspection-report.json"), FileAccess.WRITE).store_string(JSON.stringify(output, "  "))
	FileAccess.open(capture_dir.path_join("continued-save.json"), FileAccess.WRITE).store_string(S.encode(scene.state, scene.settings, 0, true, scene.profile))
	print("INSPECTION: ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	scene.free()
	await process_frame
	quit(0 if failures == 0 else 1)
