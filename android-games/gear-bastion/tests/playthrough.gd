extends SceneTree
## Every game action goes through real touch events; time alone is accelerated.
const Scene = preload("res://main.tscn")
const Gear = preload("res://scripts/gear_rules.gd")
const Saves = preload("res://scripts/save_store.gd")
const FaultFiles = preload("res://tests/fault_files.gd")
var game: Node2D
var checks := 0
var failures: Array[String] = []
var events := 0
var pointer_events := 0
var key_events := 0
var evidence := "res://.artifacts/review-playthrough"
var trial_outcomes: Dictionary = {}

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		evidence += "/headless"
	root.size = Vector2i(600, 1066)
	call_deferred("run")

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures.append(detail)
		push_error(detail)

func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = root.get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	events += 1
	pointer_events += 1
	await process_frame

func tap(point: Vector2) -> void:
	await touch(point, true)
	await touch(point, false)

func drag(from: Vector2, to: Vector2) -> void:
	await touch(from, true)
	for fraction in [0.25, 0.5, 0.75, 1.0]:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = root.get_final_transform() * from.lerp(to, fraction)
		event.relative = root.get_final_transform().basis_xform((to - from) * 0.25)
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		events += 1
		pointer_events += 1
		await process_frame
	await touch(to, false)

func move(x: int, y: int, target_x: int, target_y: int) -> void:
	await drag(game.cell_center(x, y), game.cell_center(target_x, target_y))

func action(key: String) -> void:
	await tap(game.buttons()[key].get_center())

func purchase(kind: String, x: int, y: int, lane: int = 1) -> void:
	await drag(game.buttons()[kind].get_center(), game.cell_center(x, y))
	if kind in ["guard", "ranger"]:
		await action("gate%d" % lane)

func trial_build(strategy: String) -> void:
	if strategy == "B":
		await purchase("guard", 1, 2, 0)
		await purchase("guard", 3, 2, 2)
		await purchase("guard", 2, 3, 1)
		await purchase("ranger", 1, 1, 0)
	elif strategy == "R":
		await purchase("ranger", 1, 2, 0)
		await purchase("ranger", 3, 2, 2)
		await purchase("ranger", 2, 3, 1)
		await purchase("drive", 1, 3)
		await purchase("drive", 3, 3)
	else:
		await purchase("guard", 1, 2, 0)
		await purchase("guard", 3, 2, 2)
		await purchase("guard" if strategy == "C" else "ranger", 1, 1, 0)
		await purchase("guard" if strategy == "C" else "ranger", 3, 1, 2)

func trial_result(name: String) -> void:
	trial_outcomes[name] = {"phase": game.state.phase, "wall": game.state.wall, "spent": game.state.spent, "gold": game.state.gold, "time": game.state.time, "losses": game.state.losses, "kills": game.state.kills}
	print("INPUT TRIAL ", name, ": ", trial_outcomes[name])

func dialog_action(text: String) -> void:
	for node in game.save_dialog.find_children("*", "Button", true, false):
		if node.text == text:
			await tap(Vector2(game.save_dialog.position) + node.get_global_rect().get_center())
			return
	check(false, "Missing dialog action " + text)

func type_save(text: String) -> void:
	await tap(Vector2(game.save_dialog.position) + game.save_text.get_global_rect().position + Vector2(40, 60))
	var select := InputEventKey.new()
	select.keycode = KEY_A
	select.ctrl_pressed = true
	select.pressed = true
	Input.parse_input_event(select)
	key_events += 1
	events += 1
	select = select.duplicate()
	select.pressed = false
	Input.parse_input_event(select)
	key_events += 1
	events += 1
	var erase := InputEventKey.new()
	erase.keycode = KEY_BACKSPACE
	erase.pressed = true
	Input.parse_input_event(erase)
	key_events += 1
	events += 1
	for character in text:
		var key := InputEventKey.new()
		key.unicode = character.unicode_at(0)
		key.pressed = true
		Input.parse_input_event(key)
		events += 1
		key_events += 1
	Input.flush_buffered_events()
	await process_frame

func advance(seconds: float) -> void:
	game.advance(seconds)
	game.queue_redraw()
	await process_frame

func frame(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence + "/" + name + ".png")

func create_game() -> void:
	game = Scene.instantiate()
	game.save_path = "user://input-playthrough.json"
	root.add_child(game)
	game.set_process(false)
	await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		DirAccess.remove_absolute("user://input-playthrough.json" + suffix)
	await create_game()
	await frame("01-first-foundry")
	check(game.state.phase == "ready", "Fresh scene ready")
	var baseline: float = Gear.total_rate(game.state.board)
	await move(2, 0, 1, 1)
	check(Gear.total_rate(game.state.board) > baseline, "Touch drive placement raises displayed and actual production")
	await action("undo")
	check(is_equal_approx(Gear.total_rate(game.state.board), baseline), "Touch undo restores prior network")
	await move(1, 2, 0, 0)
	check(Gear.rate(game.state.board, 2) == 0, "Touch disconnect stops generator")
	await frame("02-disconnected")
	await move(0, 0, 1, 2)
	check(Gear.rate(game.state.board, 2) > 0, "Touch reconnect restarts generator")
	var board_before: Array = game.state.board.duplicate(true)
	await drag(game.cell_center(1, 2), Vector2(10, 450))
	check(game.state.board == board_before, "Outside drop retains old board")
	await move(2, 0, 2, 1)
	check(game.state.board.size() == 4, "Touch direct equal-drive merge")
	await action("undo")
	check(game.state.board.size() == 5, "Touch merge undo restores pieces")
	await action("begin")
	check(game.state.phase == "battle", "Touch begins live defense")
	await advance(8)
	await frame("03a-first-clash")
	var resize_state := Saves.encode(game.state, game.settings)
	for dimensions in [Vector2i(1080, 2520), Vector2i(1968, 2184)]:
		root.size = dimensions
		await process_frame
		await process_frame
		check(root.size == dimensions, "Requested desktop viewport resolution applied at " + str(dimensions))
		check(Saves.encode(game.state, game.settings) == resize_state, "Live battle preserved across resize at " + str(dimensions))
		await move(2, 0, 1, 1)
		check(Gear.total_rate(game.state.board) > 1.24, "Touch remaps after live resize at " + str(dimensions))
		await frame("03-aspect-%dx%d" % [dimensions.x, dimensions.y])
		await action("undo")
	root.size = Vector2i(600, 1066)
	await process_frame
	await advance(4)
	var count: int = game.state.produced
	await move(2, 0, 1, 1)
	check(game.state.phase == "battle" and Gear.total_rate(game.state.board) > baseline, "Board stays interactive during battle")
	await advance(13)
	check(game.state.produced > count and game.state.units.size() > 0, "Power becomes visible troops")
	await frame("03-battle-first-layout")
	await action("pause")
	check(game.paused, "Touch pause")
	var pause_time: float = game.state.time
	await advance(2)
	check(game.state.time == pause_time, "Paused simulation does not advance")
	await action("speed")
	check(game.speed == 2, "Touch speed")
	await action("mute")
	await action("effects")
	check(game.settings.muted and game.settings.reduced_effects, "Touch accessibility preferences")
	var app_written := Saves.read(game.save_path)
	check(app_written.ok and not app_written.recovered and app_written.path == game.save_path, "Normal app-written primary save reads directly without recovery fixtures")
	if DisplayServer.get_name() != "headless":
		await action("save")
		await frame("03b-portable-save")
		var exported: String = game.save_text.text
		check(Saves.decode(exported).ok, "Export dialog exposes a valid portable save")
		await type_save("{invalid")
		await dialog_action("Import")
		check(game.save_dialog.visible and game.state.phase == "battle", "Touch invalid import retains active game")
		await type_save(exported)
		await dialog_action("Import")
		check(not game.save_dialog.visible and game.paused and game.settings.muted, "Touch valid import restores paused state and preferences")
	var saved_produced: int = game.state.produced
	var saved_rate: float = Gear.total_rate(game.state.board)
	game.queue_free()
	await process_frame
	await create_game()
	check(game.paused and game.state.produced == saved_produced and is_equal_approx(Gear.total_rate(game.state.board), saved_rate), "Scene reload restores exact board and active battle paused")
	check(game.settings.muted and game.settings.reduced_effects, "Scene reload preserves settings")
	await action("pause")
	await advance(180)
	check(game.state.phase == "victory", "First layout wins through touch actions")
	await frame("04-victory-first-layout")
	await action("begin")
	check(game.state.phase == "ready" and game.state.wall == 220, "Immediate retry resets battle")
	# A second layout relocates production below core and concentrates both exits.
	await move(1, 2, 1, 3)
	await move(3, 2, 2, 3)
	await move(2, 0, 0, 3)
	await tap(game.cell_center(2, 3))
	await action("gate1")
	await drag(game.buttons().guard.get_center(), game.cell_center(3, 2))
	check(game.state.board.size() == 6 and game.state.gold == 12, "Touch tray purchase consumes actual brass")
	await action("begin")
	await advance(35)
	await frame("05-battle-second-layout")
	await advance(180)
	print("SECOND LAYOUT result: ", game.state.phase, " wall ", game.state.wall)
	check(game.state.phase == "victory", "Second distinct layout wins")
	await action("begin")
	await move(1, 2, 0, 0)
	await move(3, 2, 4, 0)
	await action("begin")
	await advance(20)
	check(game.state.phase == "battle" and game.state.wall < 220, "Disconnected layout incurs repairable wall damage")
	await frame("06-failing-strategy")
	await move(0, 0, 1, 2)
	await move(4, 0, 3, 2)
	await advance(180)
	check(game.state.phase == "victory", "Live touch rearrangement rescues damaged strategy")
	await frame("07-repaired-victory")
	await action("begin")
	await move(1, 2, 0, 0)
	await move(3, 2, 4, 0)
	await action("begin")
	await advance(180)
	check(game.state.phase == "defeat" and game.state.produced == 0, "Uncorrected disconnection loses")
	await frame("08-defeat")
	await action("begin")
	check(game.state.phase == "ready" and game.state.units.is_empty() and game.state.wall == 220, "Defeat permits immediate clean retry")
	# The following backend is an explicitly injected storage fault, separate from
	# normal app-save/reload above. UI actions still enter through actual input.
	var fault := FaultFiles.new()
	var protected_source := Saves.encode(game.state, game.settings, 100)
	fault.files[game.save_path] = protected_source
	fault.files[game.save_path + ".bak"] = protected_source
	fault.fail_suffix = ".json.tmp"
	fault.fail_mode = "flush"
	game.save_backend = fault
	await action("save")
	check(game.save_failed and game.save_dialog.visible and fault.files[game.save_path] == protected_source, "Touch Save surfaces injected flush failure while preserving good primary")
	if DisplayServer.get_name() != "headless":
		var import_state: Dictionary = game.state.duplicate(true)
		import_state.seed = 9999
		await type_save(Saves.encode(import_state, game.settings))
		await dialog_action("Import")
		check(game.state.seed != 9999 and game.save_dialog.visible and game.save_failed, "Failed import persistence retains current in-memory game and shows failure")
		check(Saves.read(game.save_path, fault).state.seed != 9999, "Failed import temp cannot silently replace game on next load")
	await dialog_action("Close")
	await frame("09-save-failure-visible")
	await action("speed")
	check(game.save_failed, "Save warning survives unrelated gameplay status messages")
	game.save_backend = null
	await action("save")
	check(not game.save_failed and Saves.read(game.save_path).ok, "Successful retry clears save warning")
	await dialog_action("Close")
	await action("trial")
	check(game.state.encounter == "iron_trial" and game.state.gold == 54 and game.state.board.size() == 2, "Touch enters fixed-budget constrained trial")
	await purchase("guard", 0, 0)
	check(game.state.gold == 54 and game.state.board.size() == 2, "Blocked trial socket rejects purchase without spending")
	await trial_build("A")
	check(game.state.spent == 52 and game.state.gold == 2 and Gear.powered(game.state.board).size() == 6, "First trial strategy spends 52 brass on fully connected mixed army")
	var mixed_rate: float = Gear.total_rate(game.state.board)
	await action("begin")
	await advance(30)
	await frame("10-trial-A-battle")
	await advance(180)
	check(game.state.phase == "victory", "Actual-input constrained strategy A wins")
	trial_result("A")
	await frame("11-trial-A-victory")
	await action("begin")
	check(game.state.encounter == "iron_trial" and game.state.gold == 54, "Retry retains trial and resets its fixed budget")
	await trial_build("B")
	check(game.state.spent == 50 and game.state.gold == 4 and Gear.powered(game.state.board).size() == 6, "Second trial strategy spends comparable 50 brass on three-gate guards and one ranger generator")
	await action("begin")
	await advance(30)
	await frame("12-trial-B-battle")
	await advance(180)
	check(game.state.phase == "victory", "Actual-input constrained strategy B wins")
	trial_result("B")
	await action("begin")
	await trial_build("R")
	check(game.state.spent == 54 and Gear.powered(game.state.board).size() == 7, "All-ranger comparison spends full budget and remains connected")
	await action("begin")
	await advance(180)
	check(game.state.phase == "defeat", "Actual-input all-ranger build fails against opening ranged pressure")
	trial_result("R")
	await frame("12b-trial-unshielded-defeat")
	await action("begin")
	await trial_build("C")
	check(game.state.spent == 48 and Gear.powered(game.state.board).size() == game.state.board.size() and Gear.total_rate(game.state.board) > mixed_rate, "Counter-inappropriate trial build is fully powered and produces faster than winning mixed build")
	await action("begin")
	await advance(36)
	check(game.state.losses >= 40 and game.state.wave == 2 and game.state.enemies.any(func(e): return e.kind == "carapace") and game.state.phase == "battle", "All-guard trial has visible casualties and carapace pressure")
	await frame("13-trial-connected-counter-failure")
	await advance(180)
	check(game.state.phase == "defeat", "Actual-input connected but counter-inappropriate army loses")
	trial_result("C")
	await frame("14-trial-counter-defeat")
	await action("begin")
	await trial_build("C")
	await action("begin")
	await advance(36)
	check(game.state.losses >= 40 and game.state.wave == 2 and game.state.phase == "battle", "Repair starts at same visible failure point")
	await tap(game.cell_center(1, 1))
	await action("refit")
	await tap(game.cell_center(3, 1))
	await action("refit")
	check(game.state.spent == 52 and game.state.gold == 2 and Gear.powered(game.state.board).size() == 6, "Live role refit costs only four brass and keeps every generator connected")
	await advance(8)
	await frame("15-trial-live-refit")
	await advance(180)
	check(game.state.phase == "victory", "Actual-input live counter repair rescues same connected losing strategy")
	trial_result("repair")
	await frame("16-trial-repaired-victory")
	game.queue_free()
	await process_frame
	await create_game()
	check(game.state.phase == "victory" and game.state.encounter == "iron_trial" and game.state.spent == 52 and not Saves.read(game.save_path).recovered, "Normal app-written challenge result reloads from primary without fixture recovery")
	var report := {"checks": checks, "failures": failures, "input_events": events, "pointer_events": pointer_events, "keyboard_events": key_events, "trial_outcomes": trial_outcomes, "renderer": DisplayServer.get_name(), "result": "passed" if failures.is_empty() else "failed", "scope": "prototype plus constrained review trial; simulated time accelerated; injected storage fault separately labeled; desktop resize only; no phone claim; clipboard not verified"}
	var file := FileAccess.open(evidence + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("INPUT PLAYTHROUGH: ", checks, " checks; ", pointer_events, " pointer + ", key_events, " keyboard input events; ", failures.size(), " failures")
	print("SUITE_COMPLETE: PASS" if failures.is_empty() else "SUITE_COMPLETE: FAIL")
	quit(0 if failures.is_empty() else 1)
