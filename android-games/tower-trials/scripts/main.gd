extends Node2D

const Content = preload("res://scripts/content.gd")
const Rules = preload("res://scripts/rules.gd")
const Saves = preload("res://scripts/save_store.gd")
const Audio = preload("res://scripts/local_audio.gd")
const INK := Color("102c42")
const SAND := Color("edddbc")
const TEAL := Color("63e0bf")
const GOLD := Color("ffd17d")
const RED := Color("fa8b7c")
const WHITE := Color("f4eee3")
const MUTED := Color("a5bcc9")

var save_path := Saves.PATH
var data := Saves.fresh()
var level: Dictionary
var state: Dictionary
var selected := ""
var screen := "game"
var menu := false
var transfer := false
var save_error := ""
var note := ""
var pending: Dictionary = {}
var pending_room := ""
var beat := 0.0
var phase := 0.0
var paused := false
var font: Font = ThemeDB.fallback_font
var sound := Audio.new()
var player := AudioStreamPlayer.new()
var editor := TextEdit.new()
var input_count := 0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var restored := Saves.read(save_path)
	if restored.ok:
		data = restored.data
	elif FileAccess.file_exists(save_path):
		save_error = "Save damaged; no valid recovery. Import a saved route."
	load_run()
	add_child(player)
	add_child(editor)
	editor.position = Vector2(42, 310)
	editor.size = Vector2(516, 380)
	editor.add_theme_font_size_override("font_size", 20)
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.visible = false
	get_viewport().size_changed.connect(layout)
	layout()
	queue_redraw()

func _exit_tree() -> void:
	player.stop()
	player.stream = null
	sound.cache.clear()

func load_run() -> void:
	level = Content.by_id(data.level_id, int(data.catalog))
	state = Saves.replay(data)
	selected = ""
	pending = {}
	beat = 0

func layout() -> void:
	var area := get_viewport_rect().size
	var factor := minf(area.x / 600.0, area.y / 1066.0)
	scale = Vector2.ONE * factor
	position = (area - Vector2(600, 1066) * factor) * 0.5
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		paused = true
		if is_node_ready():
			persist()
			queue_redraw()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		back()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		persist()
		get_tree().quit()

func persist(recoverable: bool = true) -> bool:
	var ok := Saves.write(data, save_path, null, recoverable)
	save_error = "" if ok else "SAVE FAILED — keep this app open; export your route."
	queue_redraw()
	return ok

func tone(hz: float) -> void:
	if data.settings.sound and DisplayServer.get_name() != "headless":
		player.stream = sound.tone(hz)
		player.play()

func _process(delta: float) -> void:
	if paused or menu or transfer or screen != "game":
		return
	if not pending.is_empty():
		beat += delta
		if beat >= 0.9:
			state = pending.state
			data.actions.append(pending_room)
			note = "  /  ".join(pending.events)
			pending = {}
			if state.status == "won":
				award()
			tone(740 if state.status != "lost" else 160)
			persist()
		queue_redraw()
	phase += delta

func award() -> void:
	var medals := 1
	if int(state.moves) <= int(level.par):
		medals |= 2
	if state.treasure > 0:
		medals |= 4
	if not data.used_undo:
		medals |= 8
	var prior: Dictionary = data.profile.get(level.id, {"best": 99, "medals": 0})
	data.profile[level.id] = {"best": mini(int(prior.best), int(state.moves)), "medals": int(prior.medals) | medals}

func buttons() -> Dictionary:
	if transfer:
		return {"copy": Rect2(42, 710, 160, 60), "paste": Rect2(220, 710, 160, 60), "import": Rect2(398, 710, 160, 60), "close_transfer": Rect2(42, 794, 516, 60)}
	if menu:
		return {"sound": Rect2(58, 312, 484, 64), "effects": Rect2(58, 392, 484, 64), "transfer": Rect2(58, 472, 484, 64), "close_menu": Rect2(58, 568, 484, 64)}
	if screen == "map":
		var result := {"settings": Rect2(500, 28, 76, 60), "resume": Rect2(26, 912, 548, 68)}
		for i in Content.levels().size():
			result["level%d" % i] = Rect2(26, 240 + i * 132, 548, 112)
		return result
	var result := {"settings": Rect2(500, 28, 76, 60), "undo": Rect2(24, 966, 174, 64), "retry": Rect2(213, 966, 174, 64), "map": Rect2(402, 966, 174, 64)}
	if state.status == "won":
		result["next"] = Rect2(38, 862, 524, 72)
	elif paused:
		result["resume"] = Rect2(38, 862, 524, 72)
	elif selected != "" and pending.is_empty() and Rules.blocked(state, Rules.find_room(level, selected)) == "":
		result["enter"] = Rect2(38, 882, 524, 60)
	return result

func room_rect(room: Dictionary) -> Rect2:
	return Rect2(182 + (int(room.column) - 1) * 200, 620 - int(room.floor) * 140, 180, 122)

func home_point() -> Vector2:
	return Vector2(89, 637 - mini(5, state.claimed.size()) * 64)

func _unhandled_input(event: InputEvent) -> void:
	# Native text editing needs touch-to-mouse emulation; avoid handling it twice.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		point = to_local(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = to_local(event.position)
	else:
		return
	input_count += 1
	for key in buttons():
		if buttons()[key].has_point(point):
			action(key)
			get_viewport().set_input_as_handled()
			return
	if screen == "game" and not menu and not transfer and pending.is_empty() and not paused:
		for room in level.rooms:
			if room_rect(room).has_point(point):
				selected = room.id
				tone(420)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return

func back() -> void:
	if transfer:
		transfer = false
		editor.visible = false
	elif menu:
		menu = false
	elif screen == "map":
		screen = "game"
	elif not paused:
		paused = true
	else:
		screen = "map"
	persist()
	queue_redraw()

func action(key: String) -> void:
	if key == "settings":
		menu = true
	elif key == "close_menu":
		menu = false
	elif key == "sound":
		data.settings.sound = not data.settings.sound
		persist()
	elif key == "effects":
		data.settings.reduced_effects = not data.settings.reduced_effects
		persist()
	elif key == "transfer":
		transfer = true
		editor.text = Saves.encode(data)
		editor.visible = true
	elif key == "close_transfer":
		transfer = false
		editor.visible = false
	elif key == "copy":
		DisplayServer.clipboard_set(editor.text)
		note = "Save text copied. Store it somewhere private."
	elif key == "paste":
		editor.text = DisplayServer.clipboard_get()
	elif key == "import":
		var decoded := Saves.decode(editor.text)
		if decoded.ok and Saves.write(decoded.data, save_path, null, false):
			data = decoded.data
			load_run()
			transfer = false
			editor.visible = false
			menu = false
			note = "Imported route and earned progress."
			save_error = ""
		else:
			note = decoded.get("message", "Import could not be saved; current route kept.")
	elif key == "resume":
		screen = "game"
		paused = false
	elif key == "map":
		screen = "map"
		persist()
	elif key.begins_with("level"):
		var index := int(key.trim_prefix("level"))
		var levels := Content.levels()
		if index == 0 or data.profile.has(levels[index - 1].id):
			if index != int(data.level):
				data.level = index
				data.level_id = levels[index].id
				data.catalog = Content.VERSION
				data.actions = []
				data.used_undo = false
				load_run()
				note = ""
			persist()
			screen = "game"
			paused = false
	elif key == "retry":
		data.actions = []
		data.used_undo = false
		load_run()
		note = "A fresh route. Earned medals stay."
		paused = false
		persist()
	elif key == "undo" and pending.is_empty():
		if not data.actions.is_empty():
			data.actions.pop_back()
			data.used_undo = true
			load_run()
			note = "Undone: power, key, shield and bridges restored."
			persist()
	elif key == "next" and state.status == "won":
		if int(data.level) + 1 < Content.levels().size():
			data.level += 1
			data.level_id = Content.levels()[int(data.level)].id
			data.catalog = Content.VERSION
			data.actions = []
			data.used_undo = false
			load_run()
			note = ""
			persist()
		else:
			screen = "map"
	elif key == "enter" and pending.is_empty() and not paused:
		var result := Rules.step(level, state, selected)
		if result.ok:
			pending = result
			pending_room = selected
			beat = 0
			tone(260)
		else:
			note = result.message
	queue_redraw()

func box(rect: Rect2, color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(2)
	draw_style_box(style, rect)

func text_at(value: String, at: Vector2, size: int, color: Color = WHITE) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, rect: Rect2, size: int, color: Color = WHITE) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_at(value, Vector2(rect.get_center().x - width * 0.5, rect.position.y + rect.size.y * 0.5 + size * 0.34), size, color)

func lines(value: String, at: Vector2, width: float, size: int, color: Color = WHITE, max_lines: int = 3) -> void:
	var line := ""
	var row := 0
	for word in value.split(" "):
		if font.get_string_size(line + " " + word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			text_at(line, at + Vector2(0, row * (size + 5)), size, color)
			row += 1
			line = word
			if row >= max_lines:
				return
		else:
			line = word if line == "" else line + " " + word
	text_at(line, at + Vector2(0, row * (size + 5)), size, color)

func button(key: String, label: String, color: Color = Color("24485e")) -> void:
	if buttons().has(key):
		box(buttons()[key], color, 12)
		centered(label, buttons()[key], 23, INK if color == TEAL or color == GOLD else WHITE)

func courier(at: Vector2, factor: float = 1.0) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-14, -2) * factor, at + Vector2(-23, 29) * factor, at + Vector2(15, 22) * factor, at + Vector2(11, -7) * factor]), Color("32baa2"))
	draw_line(at + Vector2(-6, 18) * factor, at + Vector2(-7, 32) * factor, SAND, 6 * factor)
	draw_line(at + Vector2(7, 18) * factor, at + Vector2(11, 32) * factor, SAND, 6 * factor)
	draw_circle(at + Vector2(0, -12) * factor, 15 * factor, GOLD)
	draw_line(at + Vector2(-13, -12) * factor, at + Vector2(14, -12) * factor, INK, 9 * factor)
	draw_circle(at + Vector2(7, -13) * factor, 2 * factor, WHITE)
	draw_line(at + Vector2(11, 4) * factor, at + Vector2(25, 9) * factor, GOLD, 4 * factor)
	draw_circle(at + Vector2(27, 10) * factor, 6 * factor, GOLD)

func spirit(at: Vector2, number: int, active: bool = true) -> void:
	var tint := RED if active else Color("4b7c83")
	draw_colored_polygon(PackedVector2Array([at + Vector2(-16, 15), at + Vector2(-13, -8), at + Vector2(13, -8), at + Vector2(17, 15), at + Vector2(5, 10), at + Vector2(-6, 15)]), tint)
	draw_circle(at + Vector2(0, -8), 16, tint)
	draw_circle(at + Vector2(0, -8), 11, INK)
	draw_line(at + Vector2(0, -8), at + Vector2(0, -15), SAND, 2)
	draw_line(at + Vector2(0, -8), at + Vector2(6, -5), SAND, 2)
	centered(str(number), Rect2(at + Vector2(-42, -67), Vector2(84, 40)), 34, INK if active else GOLD)

func background() -> void:
	for y in 54:
		draw_rect(Rect2(0, y * 20, 600, 20), Color("0a182e").lerp(Color("285264"), float(y) / 54.0))
	for i in 18:
		draw_circle(Vector2(fmod(i * 127 + 41, 590), fmod(i * 73, 290) + 94), 1.3, Color("829ead"))
	draw_circle(Vector2(521, 262), 35, Color("d2c8ae"))
	draw_circle(Vector2(505, 253), 31, Color("193a51"))
	for i in 8:
		var x := float(i * 92 - 30)
		draw_rect(Rect2(x, 605 + (i % 3) * 19, 65, 148), Color("234456"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, 608 + (i % 3) * 19), Vector2(x + 32, 574 + (i % 3) * 19), Vector2(x + 72, 608 + (i % 3) * 19)]), Color("2d5360"))
	draw_rect(Rect2(0, 746, 600, 320), Color("102d42"))
	for i in 7:
		draw_line(Vector2(i * 96, 759 + (i % 2) * 10), Vector2(i * 96 + 58, 759 + (i % 2) * 10), Color("417789"), 2)

func draw_header() -> void:
	text_at("TOWER TRIALS", Vector2(26, 58), 29, GOLD)
	button("settings", "•••")
	text_at("COAST OF THE LOST CHIMES", Vector2(26, 84), 15, MUTED)
	if screen == "game":
		text_at("%02d / %02d  ·  %s" % [int(data.level) + 1, Content.levels().size(), level.name], Vector2(26, 126), 23)
		box(Rect2(24, 146, 260, 72), Color("173e53"), 12, Color("347b7d"))
		text_at("COURIER POWER", Vector2(40, 170), 15, TEAL)
		text_at(str(state.power), Vector2(40, 205), 34, GOLD)
		text_at("Keys  %d    Shields  %d" % [state.keys, state.shields], Vector2(310, 172), 20)
		text_at("Moves %d    Treasure %d" % [state.moves, state.treasure], Vector2(310, 204), 19, MUTED)

func draw_board() -> void:
	for column in [1, 2]:
		var highest := -1
		for room in level.rooms:
			if int(room.column) == column:
				highest = maxi(highest, int(room.floor))
		if highest >= 0:
			var x: int = 182 + (column - 1) * 200
			var y: int = 620 - highest * 140
			draw_rect(Rect2(x + 6, y + 5, 168, 742 - y), Color("345566"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 7, y), Vector2(x + 90, y - 50), Vector2(x + 187, y)]), Color("5f7e89"))
	for room in level.rooms:
		for prerequisite in room.requires:
			var other := Rules.find_room(level, prerequisite)
			if not other.is_empty():
				draw_line(room_rect(other).get_center(), room_rect(room).get_center(), Color("74b9ab"), 3)
		if not room.collapse.is_empty():
			var other := Rules.find_room(level, room.collapse[0])
			if not other.is_empty():
				draw_dashed_line(room_rect(room).get_center(), room_rect(other).get_center(), GOLD, 2, 8)
	var floors: int = state.claimed.size() + 1
	for i in floors:
		var rect := Rect2(31, 692 - i * 64, 116, 62)
		box(rect, Color("397781") if i > 0 else Color("345566"), 4, Color("64bea9"))
		draw_rect(Rect2(72, rect.position.y + 19, 29, 32), INK)
		if i > 0:
			draw_circle(rect.position + Vector2(100, 12), 4, GOLD)
	var top: int = 692 - (floors - 1) * 64
	draw_colored_polygon(PackedVector2Array([Vector2(23, top), Vector2(89, top - 42), Vector2(156, top)]), TEAL)
	draw_line(Vector2(89, top - 42), Vector2(89, top - 69), GOLD, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(90, top - 69), Vector2(116, top - 61), Vector2(90, top - 52)]), GOLD)
	text_at("YOUR WATCH", Vector2(25, 778), 16, TEAL)
	for room in level.rooms:
		var rect := room_rect(room)
		var claimed: bool = room.id in state.claimed
		var collapsed: bool = room.id in state.collapsed
		var blocked := Rules.blocked(state, room)
		var fill := Color("405a66") if blocked != "" else Color("e0cba5")
		if claimed:
			fill = Color("397781")
		if collapsed:
			fill = Color("263c50")
		box(rect, fill, 5, GOLD if selected == room.id else Color("75949a"))
		draw_rect(Rect2(rect.position + Vector2(0, 98), Vector2(180, 24)), Color("274859"))
		centered(room.name, Rect2(rect.position + Vector2(0, 98), Vector2(180, 24)), 16, WHITE)
		if collapsed:
			centered("COLLAPSED", Rect2(rect.position, Vector2(180, 90)), 18, MUTED)
		elif claimed:
			centered("CLAIMED  +", Rect2(rect.position, Vector2(180, 70)), 21, TEAL)
			centered("Power sent home", Rect2(rect.position + Vector2(0, 57), Vector2(180, 25)), 14, SAND)
		else:
			for i in room.enemies.size():
				spirit(rect.position + Vector2((i + 1) * 180.0 / (room.enemies.size() + 1), 77), int(room.enemies[i]), blocked == "")
			var tags: Array = []
			if room.key_cost > 0: tags.append("LOCK %d" % room.key_cost)
			if room.keys > 0: tags.append("+KEY")
			if room.shields > 0: tags.append("+SHIELD")
			if room.trap > 0: tags.append("TRAP %d" % room.trap)
			if room.multiplier > 1: tags.append("SUN x%d" % room.multiplier)
			if room.treasure: tags.append("CHEST")
			if room.rescue: tags.append("RESCUE")
			centered("  ".join(tags), Rect2(rect.position + Vector2(0, 2), Vector2(180, 20)), 13, INK if blocked == "" else GOLD)
	var hero := home_point()
	if not pending.is_empty() and not data.settings.reduced_effects:
		var target := room_rect(Rules.find_room(level, pending_room)).get_center()
		var fraction := clampf(beat / 0.9, 0, 1)
		hero = home_point().lerp(target, sin(fraction * PI))
		hero.y -= sin(fraction * PI) * 50
		draw_arc(hero, 34, phase * 5, phase * 5 + 3.8, 20, GOLD, 4)
		if fraction > 0.5:
			text_at("+POWER" if pending.win else "CLASH", hero + Vector2(-44, -48), 20, GOLD)
	courier(hero)

func draw_game() -> void:
	draw_board()
	box(Rect2(24, 792, 552, 158), Color("091d32"), 16)
	if state.status == "won":
		text_at("KEEPER RESCUED", Vector2(40, 826), 29, TEAL)
		text_at("Your watch stands %d rooms tall.  Best: %d moves" % [state.claimed.size() + 1, int(data.profile[level.id].best)], Vector2(40, 850), 17, SAND)
		button("next", "Next watch" if int(data.level) + 1 < Content.levels().size() else "Sequence complete · Journey", TEAL)
	elif paused:
		text_at("ROUTE PAUSED", Vector2(40, 829), 27, GOLD)
		button("resume", "Resume route", TEAL)
	elif state.status == "lost":
		text_at("LANTERN EXTINGUISHED", Vector2(40, 827), 25, RED)
		lines(note, Vector2(40, 859), 500, 18, SAND, 2)
		text_at("Undo the last room or Retry below.", Vector2(40, 927), 20, WHITE)
	elif not pending.is_empty():
		text_at("COURIER IN FLIGHT", Vector2(40, 829), 24, GOLD)
		lines("  /  ".join(pending.events), Vector2(40, 861), 510, 19, SAND, 3)
	elif selected != "":
		var preview := Rules.step(level, state, selected)
		if not preview.ok:
			text_at("ROUTE CLOSED", Vector2(40, 824), 22, MUTED)
			lines(preview.message, Vector2(40, 854), 500, 18, WHITE, 1)
		else:
			text_at("FORECAST: " + ("CLAIM" if preview.win else "DEFEAT"), Vector2(40, 822), 22, TEAL if preview.win else RED)
			lines("  /  ".join(preview.events), Vector2(40, 848), 510, 17, SAND, 2)
		button("enter", "Enter room" if preview.get("win", false) else "Enter anyway · danger", TEAL if preview.get("win", false) else Color("633f4b"))
	else:
		text_at("READ THE TOWER", Vector2(40, 825), 22, GOLD)
		lines(level.lesson, Vector2(40, 858), 510, 21, WHITE, 3)
	button("undo", "Undo")
	button("retry", "Retry")
	button("map", "Journey")

func draw_map() -> void:
	text_at("The lost watches", Vector2(26, 143), 35)
	lines("Rescue each keeper. Return for treasure, a shorter route or a clean run.", Vector2(28, 181), 540, 21, SAND, 2)
	var levels := Content.levels()
	for i in levels.size():
		var unlocked: bool = i == 0 or data.profile.has(levels[i - 1].id)
		var rect: Rect2 = buttons()["level%d" % i]
		box(rect, Color("254c5e") if unlocked else Color("182f43"), 14, TEAL if i == int(data.level) else Color.TRANSPARENT)
		text_at("%02d" % (i + 1), rect.position + Vector2(18, 43), 28, GOLD if unlocked else MUTED)
		text_at(levels[i].name if unlocked else "Keeper still lost", rect.position + Vector2(80, 41), 26)
		var medals: Dictionary = data.profile.get(levels[i].id, {})
		var possible: int = 4 if levels[i].rooms.any(func(room): return room.treasure) else 3
		text_at("Best %d moves · medals %d/%d" % [medals.best, (1 if int(medals.medals) & 1 else 0) + (1 if int(medals.medals) & 2 else 0) + (1 if int(medals.medals) & 4 else 0) + (1 if int(medals.medals) & 8 else 0), possible] if not medals.is_empty() else ("Tap to begin · par %d" % int(levels[i].par) if unlocked else "Rescue the previous keeper"), rect.position + Vector2(80, 79), 19, TEAL if unlocked else MUTED)
	lines("Medals: rescue · par route · no undo · treasure where offered. Replay any earned watch.", Vector2(28, 824), 530, 20, SAND, 3)
	button("resume", "Return to current route", TEAL)
	text_at("Prototype · four authored watches", Vector2(26, 1023), 18, MUTED)

func _draw() -> void:
	if state == null:
		return
	background()
	draw_header()
	if screen == "game": draw_game()
	else: draw_map()
	if save_error != "":
		box(Rect2(12, 226, 576, 65), Color("6a2838"), 8)
		lines(save_error, Vector2(24, 250), 550, 19, WHITE, 2)
	if menu:
		draw_rect(Rect2(0, 0, 600, 1066), Color(0.01, 0.03, 0.08, 0.85))
		box(Rect2(30, 222, 540, 454), INK, 20, Color("467a87"))
		text_at("Your lantern", Vector2(58, 277), 32, GOLD)
		button("sound", "Sound: " + ("on" if data.settings.sound else "off"))
		button("effects", "Reduced effects: " + ("on" if data.settings.reduced_effects else "off"))
		button("transfer", "Export / import save")
		button("close_menu", "Return", TEAL)
	if transfer:
		draw_rect(Rect2(0, 0, 600, 1066), Color(0.01, 0.03, 0.08, 0.95))
		text_at("A route in your pocket", Vector2(42, 244), 29, GOLD)
		lines("Copy this text to keep a backup. Paste a saved route and Import to restore.", Vector2(42, 277), 516, 18, SAND, 2)
		button("copy", "Copy")
		button("paste", "Paste")
		button("import", "Import", TEAL)
		button("close_transfer", "Return")
		lines(note, Vector2(42, 893), 516, 19, WHITE, 3)
