extends SceneTree
## Run ONLY against the frozen code1 project copied under ignored evidence.
const Scene = preload("res://main.tscn")
var game: Node2D

func _initialize() -> void:
	root.size = Vector2i(600, 1066)
	call_deferred("run")

func run() -> void:
	var path := "user://code1-active-fixture.json"
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		DirAccess.remove_absolute(path + suffix)
	game = Scene.instantiate()
	game.save_path = path
	root.add_child(game)
	await process_frame
	for point in [Vector2(272, 681), Vector2(300, 912)]:
		for pressed in [true, false]:
			var event := InputEventScreenTouch.new()
			event.position = root.get_final_transform() * game.to_global(point)
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await process_frame
	for i in 65: await process_frame
	if game.state.power != 5 or game.state.claimed != ["bell"] or game.data.schema != 1:
		printerr("Legacy fixture must come from actual code1 touch play: " + JSON.stringify(game.state))
		quit(1)
		return
	var destination := OS.get_environment("TOWER_FIXTURE_PATH")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(path))
	file.close()
	file = FileAccess.open(destination + ".expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"state": game.state, "profile": game.data.profile, "settings": game.data.settings, "source_commit": "3b4643b", "input": "Two actual touch taps; natural engine frames; app-written save bytes copied unchanged", "scope": "Desktop old-project fixture, not the separate coordinator Android install-r evidence"}, "\t"))
	file.close()
	print("CODE1 FIXTURE: actual touch-created power5, bell claimed, schema1/catalog1")
	game.queue_free()
	await process_frame
	quit()
