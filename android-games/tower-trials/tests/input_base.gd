extends SceneTree

const Scene = preload("res://main.tscn")
const Rules = preload("res://scripts/rules.gd")
const Saves = preload("res://scripts/save_store.gd")
var game: Node2D
var failures: Array = []
var checks := 0
var taps := 0
var keys := 0
var captures: Array = []
var journey: Array = []
var rendered := false
var folder := "res://.artifacts/prototype/headless"
var test_path := "user://tower-input-test.json"

func _initialize() -> void:
	root.size = Vector2i(600, 1066)
	rendered = DisplayServer.get_name() != "headless"
	if rendered:
		folder = "res://.artifacts/prototype/rendered"
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func wait_frames(count: int) -> void:
	for i in count:
		await process_frame

func create_game() -> void:
	game = Scene.instantiate()
	game.save_path = test_path
	root.add_child(game)
	await wait_frames(3)

func tap(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = root.get_final_transform() * game.to_global(point)
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	taps += 1
	await process_frame

func press(keycode: int, ctrl: bool = false, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.unicode = unicode_value
	event.ctrl_pressed = ctrl
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	keys += 1
	await process_frame

func action(id: String) -> void:
	if id.begins_with("level") and not game.buttons().has(id):
		await drag(Vector2(540, 840), Vector2(540, 400))
	check(game.buttons().has(id), "Visible action exists: " + id)
	if game.buttons().has(id):
		await tap(game.buttons()[id].get_center())

func drag(from: Vector2, to: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = root.get_final_transform() * game.to_global(from)
	touch.pressed = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await process_frame
	for i in 5:
		var event := InputEventScreenDrag.new()
		event.position = root.get_final_transform() * game.to_global(from.lerp(to, (i + 1) / 5.0))
		event.relative = root.get_final_transform().basis_xform((to - from) * game.scale / 5.0)
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	touch.position = root.get_final_transform() * game.to_global(to)
	touch.pressed = false
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await process_frame

func choose(id: String) -> void:
	if game.paused:
		await action("resume")
	await tap(game.room_rect(Rules.find_room(game.level, id)).get_center())
	check(game.selected == id, "Room selected by touch: " + id)

func enter(id: String) -> void:
	await choose(id)
	await action("enter")
	await wait_frames(65)

func frame(id: String) -> void:
	await wait_frames(2)
	if rendered:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(image.save_png(folder + "/" + id + ".png") == OK, "Rendered actual-input capture " + id)
	var record := {"id": id, "state": game.state, "save": game.data, "pending": game.pending, "selected": game.selected, "screen": game.screen, "paused": game.paused, "taps": taps, "keys": keys}
	var file := FileAccess.open(folder + "/" + id + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	captures.append(id)

