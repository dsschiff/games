extends SceneTree
const Challenge = preload("res://scripts/challenge_v1.gd")
const Saves = preload("res://scripts/save_store.gd")
func _initialize() -> void:
	var result := Challenge.generate("key", 137, {"weave": 3, "treasure": true}, 0)
	if not result.ok: quit(1); return
	var data := Saves.fresh()
	data.kind = "challenge"
	data.challenge_run = {"bundle": result.bundle, "actions": [result.bundle.witness[0]], "used_undo": true}
	if not Saves.write(data, "user://challenge-fallback-fixture.json"): quit(1); return
	var file := FileAccess.open("res://tests/fixtures/challenge-v1-fallback.json", FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes("user://challenge-fallback-fixture.json"))
	file.close()
	print("Pinned fallback fixture written: synthetic budget-exhaustion compatibility fixture, not input/Android evidence")
	quit()
