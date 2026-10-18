extends "res://tests/playthrough.gd"
const Policy = preload("res://tests/campaign_policy.gd")
var resume_path := ""
var seconds := 20.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--checkpoint="):
			resume_path = arg.trim_prefix("--checkpoint=")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1280)
	var loaded := S.decode(FileAccess.get_file_as_string(resume_path))
	check(loaded.ok, "earned full-journey checkpoint decodes")
	if not loaded.ok:
		quit(1)
		return
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(slot) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	check(S.write(loaded.state, loaded.settings, S.PATH, null, false, loaded.profile), "checkpoint installed in isolated test save")
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await click("RESUME")
	await dwell(30)
	print("BUYDEBUG rect=", scene.buy_button.get_global_rect(), " disabled=", scene.buy_button.disabled, " price=", scene.state.definition.offer, " wallet=", scene.state.wallet, " pos=", R.position(scene.state), " menu=", scene.menu.visible, " root=", root.size)
	await snap("before")
	if scene.state.schema == 2 and scene.state.tier < scene.state.definition.offer:
		await click(scene.buy_button.text)
		print("BUYDEBUG after tier=", scene.state.tier, " wallet=", scene.state.wallet)
		check(scene.state.tier == scene.state.definition.offer, "visible forge purchase delivered")
		await dwell(90)
		await snap("purchased")
	for frame in int(seconds * 60):
		if scene.state.phase != "playing":
			break
		await steer(Policy.direction(scene.state))
		await physics_frame
		if frame in [180, 600, 1100]:
			await snap("motion-" + str(frame))
	await release()
	await snap("after")
	if not capture_dir.is_empty():
		var f := FileAccess.open(capture_dir.path_join("motion-report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"checkpoint": resume_path, "checks": checks, "failures": failures, "snapshots": snapshots, "events": events, "scope": "Normal loading of a checkpoint earned by full actual-input journey, followed by new real touch/GUI input at fixed60Hz; not phone FPS."}, "  "))
		f.close()
	print("MOTION_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
