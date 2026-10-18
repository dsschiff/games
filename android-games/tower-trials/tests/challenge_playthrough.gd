extends "res://tests/input_base.gd"
const Flow = preload("res://tests/challenge_flow.gd")
func _initialize() -> void:
	root.size = Vector2i(600, 1066)
	rendered = DisplayServer.get_name() != "headless"
	folder = "res://.artifacts/challenge-v1/input/" + ("rendered" if rendered else "headless")
	test_path = "user://challenge-v1-input.json"
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: DirAccess.remove_absolute(test_path + suffix)
	await create_game()
	await enter("bell")
	var result := await Flow.run(self)
	var file := FileAccess.open(folder + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "actual_touch_taps": taps, "keys": keys, "journey": result, "captures": captures}, "\t"))
	file.close()
	print("CHALLENGE INPUT: %d checks; %d failures; %d taps" % [checks, failures.size(), taps])
	game.queue_free()
	await wait_frames(3)
	if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
