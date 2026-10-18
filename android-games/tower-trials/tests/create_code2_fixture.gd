extends SceneTree
## Execute against the frozen code2 project; fixture is earned with touch input.
const Scene = preload("res://main.tscn")
const Rules = preload("res://scripts/rules.gd")
func _initialize() -> void:
	root.size = Vector2i(600, 1066)
	call_deferred("run")
func run() -> void:
	var path := "user://code2-active-fixture.json"
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: DirAccess.remove_absolute(path + suffix)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(OS.get_environment("TOWER_CODE2_SOURCE")))
	file.close()
	var game := Scene.instantiate()
	game.save_path = path
	root.add_child(game)
	for i in 3: await process_frame
	var room_point: Vector2 = game.room_rect(Rules.find_room(game.level, "key")).get_center()
	for point in [room_point, Vector2(300, 906)]:
		for pressed in [true, false]:
			var event := InputEventScreenTouch.new()
			event.position = root.get_final_transform() * game.to_global(point)
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await process_frame
	for i in 65: await process_frame
	if game.data.schema != 2 or game.state.power != 9 or game.state.keys != 1 or game.data.profile.size() != 18:
		printerr("Expected real code2 active key route: " + JSON.stringify(game.state))
		quit(1)
		return
	file = FileAccess.open(OS.get_environment("TOWER_CODE2_TARGET"), FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(path))
	file.close()
	file = FileAccess.open(OS.get_environment("TOWER_CODE2_TARGET") + ".expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"state": game.state, "provenance": "Frozen0e4decc actual input-earned18-clear checkpoint, then two actual touches and natural engine frames in the original code2 runtime; no gameplay field injection"}, "\t"))
	file.close()
	print("CODE2 FIXTURE: schema2/catalog2, 18 earned clears, power9/key1")
	game.queue_free()
	await process_frame
	quit()
