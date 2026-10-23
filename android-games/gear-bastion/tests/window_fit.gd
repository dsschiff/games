extends "res://tests/legacy_playthrough.gd"
## Focused CPU/input geometry test; the same script can capture rendered smoke
## frames when the coordinator grants the exclusive GPU slot.
const Battle = preload("res://scripts/battle_rules.gd")
const Profile = preload("res://scripts/campaign_profile.gd")
const Policy = preload("res://tests/campaign_policies.gd")
var samples: Array = []
var rendered := false
var terminal_fixtures: Array = []

func _initialize() -> void:
	rendered = DisplayServer.get_name() != "headless"
	evidence = "res://.artifacts/window-fit" + ("/rendered" if rendered else "/headless")
	root.size = Vector2i(600, 1066)
	call_deferred("run")

func local_to_view(point: Vector2) -> Vector2:
	return game.get_global_transform_with_canvas() * point

func action(key: String) -> void:
	if game.buttons().has(key):
		await tap(game.buttons()[key].get_center())
		return
	await action("menu")
	var button: Button = game.menu_dialog.find_child("Action_" + key, true, false)
	check(button != null, "Menu contains " + key)
	if button != null:
		var point := Vector2(game.menu_dialog.position) + button.get_global_rect().get_center()
		await tap(game.to_local(point))

func touch(point: Vector2, pressed: bool) -> void:
	await super.touch(local_to_view(point), pressed)

func drag(from: Vector2, to: Vector2) -> void:
	await touch(from, true)
	for fraction in [0.25, 0.5, 0.75, 1.0]:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = root.get_final_transform() * local_to_view(from.lerp(to, fraction))
		event.relative = root.get_final_transform().basis_xform(local_to_view(to) - local_to_view(from)) * 0.25
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		events += 1
		await process_frame
	await touch(to, false)

func key_back() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	events += 1
	await process_frame

func settle() -> void:
	for i in 3:
		await process_frame
	game.refresh_layout()

func capture(name: String) -> void:
	if rendered:
		game.queue_redraw()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence + "/" + name + ".png")

func geometry(label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, game.layout.size)
	var final := root.get_final_transform()
	check((final * Vector2.ZERO).distance_to(Vector2.ZERO) < 1 and (final * root.get_visible_rect().size).distance_to(Vector2(root.size)) < 2, label + " expanded viewport fills physical window")
	check(bounds.encloses(game.layout.board.grow(8)), label + " all twenty sockets visible")
	check(game.layout.field.size.x == bounds.size.x and game.layout.field.position.x == 0, label + " field spans available width")
	check(game.layout.field.end.y <= game.layout.wall.position.y and game.layout.wall.end.y < game.layout.board.position.y, label + " battlefield and three exits above board")
	var boxes: Dictionary = game.buttons()
	for key in boxes:
		var box: Rect2 = boxes[key]
		check(bounds.encloses(box), label + " control in bounds: " + key)
		check(box.size.x >= 80 and box.size.y >= 80, label + " touch target: " + key)
		check(not box.intersects(game.layout.board), label + " control clear of sockets: " + key)
		for other in boxes:
			if str(other) > str(key):
				check(not box.intersects(boxes[other]), label + " disjoint controls: " + key + "/" + other)
	for y in 4:
		for x in 5:
			var center: Vector2 = game.cell_center(x, y)
			var physical: Vector2 = root.get_final_transform() * local_to_view(center)
			var viewport_point: Vector2 = root.get_final_transform().affine_inverse() * physical
			check(game.cell_at(game.to_local(viewport_point)) == Vector2i(x, y), label + " socket inverse %d,%d" % [x, y])
	if game.layout.wide:
		check(boxes.drive.position.x > game.layout.board.end.x and boxes.refit.end.x < game.layout.board.position.x, label + " controls flank board")
	samples.append({"label": label, "window": str(root.size), "viewport": str(root.get_visible_rect().size), "usable": str(game.usable), "canvas": str(game.layout.size), "wide": game.layout.wide, "board": str(game.layout.board), "field": str(game.layout.field)})

func modal(kind: String, label: String) -> void:
	await action(kind)
	await settle()
	var dialog: AcceptDialog = game.save_dialog if kind == "save" else game.help_dialog if kind == "help" else game.menu_dialog
	check(dialog.visible, label + " opens " + kind)
	var client := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	check(game.usable.encloses(client), label + " modal client in safe area " + kind + " " + str(client))
	check(float(dialog.position.y) - 32 >= game.usable.position.y, label + " modal title in safe area " + kind)
	var scroll: ScrollContainer = game.dialog_scrolls[dialog]
	check(scroll.get_global_rect().size.x <= client.size.x, label + " modal content scrolls within width " + kind)
	check(dialog.get_ok_button().size.x >= 160 and dialog.get_ok_button().size.y >= 80, label + " usable actual modal Close target " + kind)
	await capture(label + "-" + kind)
	await key_back()
	check(not dialog.visible and game.screen == "game", label + " Back closes " + kind + " before navigation")

func input_case(label: String, legacy: bool) -> void:
	# Fresh fixtures bound the input exercise. No campaign progress is fabricated.
	game.state = Battle.initial(1701, "iron_trial" if legacy else "camp_02")
	game.screen = "game"
	game.paused = true
	game.undo_board.clear()
	await settle()
	geometry(label + "-ready")
	await capture(label + "-ready")
	var before: Dictionary = game.state.duplicate(true)
	await purchase("guard", 1, 2, 2)
	var index: int = Gear.at(game.state.board, 1, 2)
	check(index >= 0 and game.state.board[index].kind == "guard" and int(game.state.board[index].lane) == 2, label + " actual tray drag buys guard and exit tap selects east")
	check(int(game.state.gold) == int(before.gold) - int(Gear.COSTS.guard), label + " purchase charges exactly once")
	await action("refit")
	index = Gear.at(game.state.board, 1, 2)
	check(index >= 0 and game.state.board[index].kind == "ranger" and int(game.state.gold) == int(before.gold) - int(Gear.COSTS.ranger), label + " actual refit changes role and exact price")
	await move(1, 2, 1, 1)
	check(Gear.at(game.state.board, 1, 2) < 0 and Gear.at(game.state.board, 1, 1) >= 0, label + " actual installed gear move")
	await action("undo")
	check(Gear.at(game.state.board, 1, 2) >= 0 and Gear.at(game.state.board, 1, 1) < 0, label + " actual Undo restores move")
	var board_before: Array = game.state.board.duplicate(true)
	await drag(game.cell_center(1, 2), Vector2(-50, -50))
	check(game.state.board == board_before, label + " outside drop retains board")
	await action("begin")
	check(game.state.phase == "battle", label + " Begin works after reflow")
	game.paused = false
	game.advance(8)
	check(float(game.state.time) > 7.9 and not game.state.enemies.is_empty(), label + " live simulation populated actual field")
	geometry(label + "-battle")
	await tap(game.cell_center(1, 2))
	await action("gate0")
	index = Gear.at(game.state.board, 1, 2)
	check(index >= 0 and int(game.state.board[index].lane) == 0, label + " live exit changes after reflow")
	await capture(label + "-battle")
	await modal("menu", label)
	await modal("help", label)
	await modal("save", label)
	var packet := Saves.decode(game.save_text.text)
	check(packet.ok, label + " export validates: " + str(packet.get("message", "valid")))
	if packet.ok:
		var decoded = JSON.parse_string(Saves.encode(packet.state, packet.settings, 0, true, packet.profile))
		var original = JSON.parse_string(Saves.encode(game.state, game.settings, 0, true, game.profile))
		check(decoded == original, label + " export preserves whole run, pinned content, settings and profile")
	# The Close button is actual GUI input, separately from Android-style Back.
	await action("menu")
	await settle()
	var close_button: Button = game.menu_dialog.get_ok_button()
	await tap(game.to_local(Vector2(game.menu_dialog.position) + close_button.get_global_rect().get_center()))
	check(not game.menu_dialog.visible, label + " actual Close button dismisses modal")

func terminal_case(label: String) -> void:
	for fixture in terminal_fixtures:
		game.state = fixture.duplicate(true)
		game.screen = "game"
		game.paused = false
		var outcome: String = game.state.phase
		geometry(label + "-" + outcome)
		await capture(label + "-" + outcome + "-fixture")
		await action("begin")
		check(game.state.phase == "ready" and game.state.time == 0, label + " terminal Retry is reachable for " + outcome)

func transfer_case() -> void:
	for phase in ["ready", "battle"]:
		game.state = Battle.initial(1701, "camp_02")
		if phase == "battle": Battle.start(game.state)
		game.screen = "game"
		await action("save")
		await settle()
		var exported: String = game.save_text.text
		var before = JSON.parse_string(Saves.encode(game.state, game.settings, 0, true, game.profile))
		var import_button: Button
		for candidate in game.save_dialog.find_children("*", "Button", true, false):
			if candidate.text == "Import":
				import_button = candidate
		check(import_button != null, "Transfer exposes Import button")
		game.save_text.text = "invalid fixture text"
		await tap(game.to_local(Vector2(game.save_dialog.position) + import_button.get_global_rect().get_center()))
		check(game.save_dialog.visible and before == JSON.parse_string(Saves.encode(game.state, game.settings, 0, true, game.profile)), "Invalid Import button retains entire run/settings/profile")
		game.save_text.text = exported
		await tap(game.to_local(Vector2(game.save_dialog.position) + import_button.get_global_rect().get_center()))
		check(not game.save_dialog.visible and game.paused == (phase == "battle") and before == JSON.parse_string(Saves.encode(game.state, game.settings, 0, true, game.profile)), "App-produced " + phase + " export retains whole context and phase-aware pause through actual Import button")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	game = Scene.instantiate()
	game.save_path = "user://window-fit-isolated.json"
	game.save_backend = FaultFiles.new()
	root.add_child(game)
	game.set_process(false)
	await settle()
	# Generate two terminal drawing fixtures once, rather than replay every campaign.
	for win in [false, true]:
		var state := Battle.initial(1701, "camp_01")
		if win:
			Policy.apply(state, "A")
		Battle.start(state)
		while state.phase == "battle":
			Battle.tick(state, Battle.STEP)
		terminal_fixtures.append(state)
	for dimensions in [Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1080, 2400), Vector2i(2184, 1968), Vector2i(1200, 1600), Vector2i(900, 1300), Vector2i(600, 1066)]:
		root.size = dimensions
		game.safe_area_override = Rect2()
		await settle()
		var label := "%dx%d" % [dimensions.x, dimensions.y]
		await input_case(label, false)
		await input_case(label + "-legacy", true)
		# Hold an active paused encounter and cancel a gesture across fold/resize.
		var held: String = Saves.encode(game.state, game.settings, 0, true, game.profile)
		await touch(game.cell_center(1, 2), true)
		root.size = Vector2i(dimensions.y, dimensions.x)
		await settle()
		await touch(game.cell_center(0, 2), false)
		check(game.drag_id == -1 and game.active_touch == -1 and held == Saves.encode(game.state, game.settings, 0, true, game.profile), label + " resize cancels stale drag without changing entire save")
		await move(1, 2, 1, 1)
		check(Gear.at(game.state.board, 1, 1) >= 0, label + " real move works immediately after state-preserving resize")
		await action("undo")
		check(held == Saves.encode(game.state, game.settings, 0, true, game.profile), label + " move and Undo after resize restore whole active state")
		await action("save")
		root.size = dimensions
		await settle()
		check(game.save_dialog.visible and game.usable.encloses(Rect2(Vector2(game.save_dialog.position), Vector2(game.save_dialog.size))), label + " open transfer reflows during resize")
		await key_back()
		# Emulated cutout/navigation insets are viewport units, distinct from physical Android validation.
		var view: Vector2 = root.get_visible_rect().size
		game.safe_area_override = Rect2(25, 40, view.x - 60, view.y - 90)
		await settle()
		await input_case(label + "-safe", false)
		await terminal_case(label + "-safe")
		await transfer_case()
		# Resume a live fixture before checking the guarded map transition below.
		await action("begin")
		game.screen = "map"
		await settle()
		var map_bounds := Rect2(Vector2.ZERO, game.layout.size)
		for screen in ["map", "challenges", "ending"]:
			game.screen = screen
			for key in game.buttons():
				check(map_bounds.encloses(game.buttons()[key]), label + " " + screen + " navigation visible " + key)
			await capture(label + "-" + screen)
		game.screen = "map"
		await action("mission0")
		# Active-run replacement uses its ordinary confirmation, then cancellation.
		await settle()
		check(game.abandon_dialog.visible, label + " actual map selection guards active encounter")
		check(game.usable.encloses(Rect2(Vector2(game.abandon_dialog.position), Vector2(game.abandon_dialog.size))), label + " confirmation fits safe area")
		await key_back()
		check(not game.abandon_dialog.visible, label + " Back closes confirmation")
	var report := {"checks": checks, "failures": failures, "events": events, "rendered": rendered, "samples": samples}
	var file := FileAccess.open(evidence + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("WINDOW_FIT: %d checks, %d failures, %d input events" % [checks, failures.size(), events])
	print("SUITE_COMPLETE: ", "PASS" if failures.is_empty() else "FAIL")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
