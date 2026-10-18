extends "res://tests/input_base.gd"
## Starts from unchanged app-written checkpoints earned in the 36-watch input run.
const Content = preload("res://scripts/content.gd")

func _initialize() -> void:
	root.size = Vector2i(600, 1066)
	folder = "res://.artifacts/campaign/motion"
	rendered = true
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var rows: Array = []
	for index in [0, 18, 35]:
		test_path = "user://tower-movie-%02d.json" % index
		for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
			DirAccess.remove_absolute(test_path + suffix)
		var checkpoint_path := "res://.artifacts/campaign/checkpoints/stage%02d.json" % index
		var file := FileAccess.open(test_path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(checkpoint_path))
		file.close()
		await create_game()
		check(game.data.profile.size() == index and game.data.level_id == Content.levels()[index].id, "Movie restores real touch-earned checkpoint " + str(index))
		await wait_frames(24)
		var route: Array = Rules.solve(game.level, game.state).route
		for id in route:
			await choose(id)
			await wait_frames(15)
			await action("enter")
			await wait_frames(62)
		check(game.state.status == "won", "First/middle/final input movie naturally wins " + str(index))
		rows.append({"index": index, "checkpoint": checkpoint_path, "route": game.data.actions.duplicate(), "final_state": game.state.duplicate(true)})
		await wait_frames(30)
		if index == 35:
			await action("next")
			check(game.screen == "ending", "Movie naturally opens final ending")
			await wait_frames(90)
		game.queue_free()
		await wait_frames(3)
	var file := FileAccess.open(folder + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "touch_taps": taps, "scenes": rows, "scope": "Restored unchanged app-written checkpoints earned through actual 36-watch touch play; new actions only through Input events; fixed60fps movie, not measured phone FPS"}, "\t"))
	file.close()
	print("TOWER CAMPAIGN MOTION: %d checks; %d failures" % [checks, failures.size()])
	if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
