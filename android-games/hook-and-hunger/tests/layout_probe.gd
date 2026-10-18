extends "res://tests/playthrough.gd"
var resume_path := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--checkpoint="):
			resume_path = arg.trim_prefix("--checkpoint=")
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1280)
	var loaded := S.decode(FileAccess.get_file_as_string(resume_path))
	check(loaded.ok, "earned checkpoint validates")
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(slot) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	S.write(loaded.state, loaded.settings, S.PATH, null, false, loaded.profile)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if scene.state.phase == "victory":
		await click("HARBOR / REPLAY")
		print("MENUDEBUG paused=",scene.paused," arena=",scene.arena_panel.visible," target=",scene.arena_weapon_button.get_global_rect())
		await click(scene.arena_weapon_button.text)
		print("MENUDEBUG after weapon=",scene.profile.arena_weapon," target=",scene.arena_weapon_button.get_global_rect())
		check(scene.profile.arena_weapon == 1, "real scroll and loadout click works")
		await snap("arena-menu-cover")
		await click("SAIL TO ARENA")
		check(scene.state.definition.arena, "actual arena entry button works")
	else:
		await click("RESUME")
	check(not scene.paused, "initial scene resumes")
	await click("PAUSE")
	check(scene.paused, "cover pause button works")
	var before := JSON.stringify(scene.state)
	root.size = Vector2i(1000, 1110)
	await process_frame
	await process_frame
	check(JSON.stringify(scene.state) == before, "whole state survives unfold")
	await snap("menu-unfolded")
	await click("RESUME")
	check(not scene.paused, "unfolded Resume receives actual input")
	await snap("active-unfolded")
	await click("PAUSE")
	check(scene.paused, "unfolded Pause receives actual input")
	check(scene.menu_button.size.y >= 96 and scene.buy_button.size.y >= 96, "touch hit heights at least96 logical pixels")
	root.size = Vector2i(720, 1680)
	await process_frame
	await process_frame
	await click("RESUME")
	check(not scene.paused, "tall Fold cover Resume receives actual input")
	await snap("active-tall-cover")
	print("LAYOUT_PROBE: ",checks," checks; failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
