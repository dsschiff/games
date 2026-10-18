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
	check(game.buttons().has(id), "Visible action exists: " + id)
	if game.buttons().has(id):
		await tap(game.buttons()[id].get_center())

func choose(id: String) -> void:
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

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		DirAccess.remove_absolute(test_path + suffix)
	await create_game()
	check(game.state.power == 3 and game.data.profile.is_empty(), "Fresh playable begins without synthetic progress")
	await frame("00-first-light")
	await choose("rope")
	await frame("01-equality-forecast")
	await action("enter")
	await wait_frames(65)
	check(game.state.status == "lost" and game.state.power == 3, "Natural equality defeat after input and engine frames")
	await frame("02-natural-defeat")
	await action("retry")
	check(game.state == Rules.initial(game.level), "Actual Retry resets full active state")
	await choose("bell")
	await action("enter")
	await wait_frames(25)
	check(not game.pending.is_empty() and game.state.power == 3, "Short combat visibly in flight before transfer")
	await frame("03-flight")
	await wait_frames(45)
	check(game.state.power == 5 and game.state.claimed == ["bell"], "Natural transfer adds power and one visible tower floor")
	check(not game.buttons().has("enter"), "Claimed selected room has no misleading Enter affordance")
	await frame("04-grown-watch")
	var earned: Dictionary = game.state.duplicate(true)
	await action("undo")
	check(game.state == Rules.initial(game.level) and game.data.used_undo, "Input Undo exactly restores active state and marks clean-run medal unavailable")
	await enter("bell")
	check(game.state == earned, "Replay after Undo restores same claim")
	var saved_data: Dictionary = game.data.duplicate(true)
	game.queue_free()
	await wait_frames(3)
	await create_game()
	check(game.state == earned and game.data.actions == saved_data.actions and game.data.used_undo, "Cold scene restart restores earned route and undo flag from app-written disk")
	await enter("rope")
	await enter("clock")
	await enter("light")
	check(game.state.status == "won" and game.data.profile.has("watch_01"), "Natural first victory awards clear")
	check(int(game.data.profile.watch_01.medals) & 8 == 0, "Undone route does not earn no-undo medal")
	await frame("05-natural-victory")
	journey.append({"id": game.level.id, "state": game.state.duplicate(true), "medal": game.data.profile[game.level.id]})
	await action("next")
	await choose("pair")
	await frame("06-ordered-preview")
	for id in ["pair", "loft", "star", "light"]:
		await enter(id)
	check(game.state.status == "won" and game.state.treasure == 1, "Ordered fights plus optional treasure reaches second victory")
	await frame("07-chime-victory")
	journey.append({"id": game.level.id, "state": game.state.duplicate(true), "medal": game.data.profile[game.level.id]})
	await action("next")
	await choose("easy")
	await frame("08-greedy-danger")
	await action("enter")
	await wait_frames(65)
	check(game.state.status == "lost" and game.state.collapsed == ["key"], "Input greedy ferry choice produces natural stranded defeat")
	await frame("09-greedy-stranded")
	await action("undo")
	check(game.state.keys == 0 and game.state.collapsed.is_empty() and game.state.claimed.is_empty(), "Input Undo restores key ferry and collapsed routes")
	await enter("key")
	check(game.state.keys == 1 and game.state.collapsed == ["easy"], "Input key choice changes visible routes and inventory")
	await choose("easy")
	check(not game.buttons().has("enter"), "Collapsed selection has no Enter affordance")
	await frame("10-key-claimed")
	await enter("door")
	check(game.state.keys == 0, "Input door consumes the actual key")
	await enter("light")
	check(game.state.status == "won", "Corrected key route reaches keeper")
	journey.append({"id": game.level.id, "state": game.state.duplicate(true), "medal": game.data.profile[game.level.id]})
	await action("next")
	await enter("trap")
	check(game.state.status == "lost", "Input unshielded trap loses")
	await frame("11-trap-defeat")
	await action("retry")
	await enter("shield")
	await choose("trap")
	await frame("12-shield-forecast")
	await action("enter")
	await wait_frames(65)
	check(game.state.shields == 0 and game.state.power == 17, "Input shield blocks trap and is consumed")
	await enter("loft")
	await enter("light")
	check(game.state.status == "won" and game.data.profile.size() == 4, "All four actual-input watches complete")
	await frame("13-sequence-victory")
	journey.append({"id": game.level.id, "state": game.state.duplicate(true), "medal": game.data.profile[game.level.id]})
	await action("undo")
	check(game.state.status == "active" and game.data.profile.size() == 4, "Undo from victory preserves already earned profile")
	await action("retry")
	for id in ["sun", "loft", "light"]:
		await enter(id)
	check(game.state.status == "won" and game.state.moves == 3, "Alternate sun route naturally wins in three moves")
	await frame("14-sun-route-victory")
	await action("settings")
	await action("sound")
	await action("effects")
	check(not game.data.settings.sound and game.data.settings.reduced_effects, "Touch settings toggle and persist")
	await action("transfer")
	check(game.editor.visible and Saves.decode(game.editor.text).ok, "Real export UI contains a valid earned save")
	var before_import: Dictionary = game.state.duplicate(true)
	await action("import")
	check(game.state == before_import and not game.transfer, "Real import UI roundtrip retains complete route")
	await action("settings")
	await action("transfer")
	await tap(Vector2(100, 350))
	await press(KEY_A, true)
	await press(KEY_BACKSPACE)
	for letter in "bad":
		await press(KEY_NONE, false, letter.unicode_at(0))
	await action("import")
	check(game.transfer and game.state == before_import and not Saves.decode(game.editor.text).ok, "Typed malformed import is rejected without replacing active route")
	await action("close_transfer")
	await action("close_menu")
	await press(KEY_ESCAPE)
	check(game.paused, "Back pauses current route")
	await press(KEY_ESCAPE)
	check(game.screen == "map", "Second Back opens journey")
	await frame("15-earned-journey")
	await action("resume")
	var before_resize: Dictionary = game.state.duplicate(true)
	root.size = Vector2i(900, 1000)
	await wait_frames(5)
	check(game.state == before_resize, "Unfolded desktop aspect preserves whole active route")
	await frame("16-unfolded-aspect")
	var result := {"checks": checks, "failures": failures, "actual_touch_taps": taps, "actual_key_events": keys, "journey": journey, "captures": captures, "renderer": DisplayServer.get_name(), "limitations": ["Desktop engine input, not physical touch", "No Android/device/FPS/sound-output claim", "Prototype is four puzzles, not the full journey"]}
	var file := FileAccess.open(folder + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("TOWER INPUT: %d checks; %d failures; %d actual touch taps" % [checks, failures.size(), taps])
	game.queue_free()
	await wait_frames(3)
	if failures.is_empty():
		print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
