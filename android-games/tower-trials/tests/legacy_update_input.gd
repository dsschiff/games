extends "res://tests/input_base.gd"

func _initialize() -> void:
	root.size = Vector2i(600, 1066)
	rendered = DisplayServer.get_name() != "headless"
	folder = "res://.artifacts/campaign/legacy-" + ("rendered" if rendered else "headless")
	test_path = "user://legacy-update-input.json"
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		DirAccess.remove_absolute(test_path + suffix)
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes("res://tests/fixtures/code1-active-route.json"))
	file.close()
	await create_game()
	check(game.data.schema == 2 and game.data.catalog == 1 and game.state.power == 5 and not game.state.has("rescued"), "Updated runtime loads genuine old touch-earned state without adding fields or changing rules")
	var original: Dictionary = game.state.duplicate(true)
	await frame("00-legacy-restored")
	await enter("rope")
	check(game.state.power == 8 and game.data.catalog == 1, "Actual input continues original arithmetic after schema migration")
	await action("undo")
	check(game.state == original and game.data.used_undo, "Actual Undo returns to exact code1 state")
	game.queue_free()
	await wait_frames(3)
	await create_game()
	check(game.state == original and game.data.catalog == 1 and game.data.used_undo, "Cold restart retains migrated legacy run and Undo history")
	await action("retry")
	check(game.state.power == 3 and game.data.catalog == 1, "Retry stays on the pinned old definition")
	for id in ["bell", "rope", "clock", "light"]: await enter(id)
	await action("next")
	check(game.data.catalog == 2 and game.data.level_id == "watch_02" and game.data.profile.has("watch_01"), "Natural next puzzle adopts current catalog after the legacy run finishes")
	await frame("01-current-after-legacy")
	file = FileAccess.open(folder + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "actual_touch_taps": taps, "scope": "Desktop code1 touch-created fixture restored under code2; not APK install-r evidence"}, "\t"))
	file.close()
	print("TOWER LEGACY INPUT: %d checks; %d failures" % [checks, failures.size()])
	game.queue_free()
	await wait_frames(3)
	if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
