extends "res://tests/playthrough.gd"
## Movie output is deterministic engine-frame pacing, never measured phone FPS.

func _initialize() -> void:
	root.size = Vector2i(600, 1066)
	folder = "res://.artifacts/prototype/motion"
	test_path = "user://tower-motion.json"
	rendered = true
	call_deferred("run")

func beat_room(id: String) -> void:
	await choose(id)
	await wait_frames(24)
	await action("enter")
	await wait_frames(76)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		DirAccess.remove_absolute(test_path + suffix)
	await create_game()
	await wait_frames(50)
	for id in ["bell", "rope", "clock", "light"]:
		await beat_room(id)
	await wait_frames(45)
	check(game.state.status == "won", "Movie first tower naturally won")
	await action("next")
	for id in ["pair", "loft", "light"]:
		await beat_room(id)
	await wait_frames(35)
	check(game.state.status == "won", "Movie second tower naturally won")
	await action("next")
	await beat_room("easy")
	await wait_frames(35)
	check(game.state.status == "lost", "Movie greedy route stranded")
	await action("undo")
	await beat_room("key")
	await beat_room("door")
	await beat_room("light")
	await wait_frames(90)
	check(game.state.status == "won", "Movie corrected ferry route naturally won")
	var file := FileAccess.open(folder + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "touch_taps": taps, "final_state": game.state, "scope": "Actual Input.parse_input_event touches, engine _process only; fixed 60fps movie clock, Dummy audio driver, not measured phone performance"}, "\t"))
	file.close()
	print("TOWER MOTION: %d checks; %d failures; %d taps" % [checks, failures.size(), taps])
	game.queue_free()
	await wait_frames(3)
	quit(0 if failures.is_empty() else 1)
