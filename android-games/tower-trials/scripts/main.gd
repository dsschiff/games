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
var guide := false
var details := false
var chapter := 0
var map_scroll := 0.0
var map_press := Vector2.ZERO
var map_touch_pending := false
var map_dragged := false
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
	chapter = maxi(0, Content.index_of(data.level_id)) / 9

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
	if paused or menu or transfer or guide or details or screen != "game":
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
	if details:
		return {"close_details": Rect2(42, 910, 516, 80)}
	if guide:
		return {"close_guide": Rect2(42, 876, 516, 80)}
	if transfer:
		return {"copy": Rect2(42, 710, 160, 80), "paste": Rect2(220, 710, 160, 80), "import": Rect2(398, 710, 160, 80), "close_transfer": Rect2(42, 804, 516, 80)}
	if menu:
		return {"sound": Rect2(58, 282, 484, 80), "effects": Rect2(58, 370, 484, 80), "transfer": Rect2(58, 458, 484, 80), "guide": Rect2(58, 546, 484, 80), "close_menu": Rect2(58, 650, 484, 80)}
	if screen == "ending":
		return {"map": Rect2(26, 930, 548, 80), "settings": Rect2(496, 18, 80, 80)}
	if screen == "map":
		var result := {"settings": Rect2(496, 18, 80, 80), "resume": Rect2(26, 966, 548, 80)}
		for i in 4:
			result["chapter%d" % i] = Rect2(26 + i * 140, 154, 128, 80)
		for i in 9:
			var rect := Rect2(26, 240 + i * 84 - map_scroll, 548, 80)
			if rect.position.y >= 240 and rect.end.y <= 922:
				result["level%d" % (chapter * 9 + i)] = rect
		return result
	var result := {"settings": Rect2(496, 18, 80, 80), "undo": Rect2(24, 966, 174, 80), "retry": Rect2(213, 966, 174, 80), "map": Rect2(402, 966, 174, 80)}
	if state.status == "won":
		result["next"] = Rect2(38, 862, 524, 80)
	elif paused:
		result["resume"] = Rect2(38, 862, 524, 80)
	elif selected != "" and pending.is_empty() and Rules.blocked(state, Rules.find_room(level, selected)) == "":
		result["enter"] = Rect2(38, 866, 524, 80)
		result["details"] = Rect2(38, 786, 524, 80)
	return result

func room_rect(room: Dictionary) -> Rect2:
	var rows := 1
	for item in level.rooms:
		rows = maxi(rows, int(item.floor) + 1)
	var stride := 115 if rows >= 4 else 140
	return Rect2(182 + (int(room.column) - 1) * 200, 620 - int(room.floor) * stride, 180, 104 if rows >= 4 else 122)

func home_stride() -> float:
	return minf(64, 384.0 / maxi(1, state.claimed.size()))

func home_point() -> Vector2:
	return Vector2(89, 637 - state.claimed.size() * home_stride())

func _unhandled_input(event: InputEvent) -> void:
	# Native text editing needs touch-to-mouse emulation; avoid handling it twice.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if screen == "map" and not menu and not transfer and not guide:
		if event is InputEventScreenDrag and map_touch_pending:
			map_dragged = true
			map_scroll = clampf(map_scroll - event.relative.y / scale.y, 0, 76)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch:
			var local := to_local(event.position)
			if event.pressed and Rect2(26, 240, 548, 682).has_point(local):
				map_touch_pending = true
				map_press = local
				map_dragged = false
				get_viewport().set_input_as_handled()
				return
			if not event.pressed and map_touch_pending:
				map_touch_pending = false
				if not map_dragged and local.distance_to(map_press) < 20:
					var visible_buttons := buttons()
					for key in visible_buttons:
						if key.begins_with("level") and visible_buttons[key].has_point(local):
							action(key)
							break
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			map_scroll = clampf(map_scroll + (84 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -84), 0, 76)
			queue_redraw()
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
	if screen == "game" and not menu and not transfer and not guide and not details and pending.is_empty() and not paused:
		for room in level.rooms:
			if room_rect(room).has_point(point):
				selected = room.id
				tone(420)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return

func back() -> void:
	if details:
		details = false
	elif guide:
		guide = false
		menu = true
	elif transfer:
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
	elif key == "guide":
		guide = true
		menu = false
	elif key == "close_guide":
		guide = false
		menu = true
	elif key == "details":
		details = true
	elif key == "close_details":
		details = false
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
	elif key.begins_with("chapter"):
		chapter = int(key.trim_prefix("chapter"))
		map_scroll = 0
	elif key.begins_with("level"):
		var index := int(key.trim_prefix("level"))
		var levels := Content.levels()
		if Content.unlocked(index, data.profile) or levels[index].id == data.level_id or data.profile.has(levels[index].id):
			if levels[index].id != data.level_id:
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
		var next_index := Content.index_of(data.level_id) + 1
		# Inserted tutorials remain real requirements for historic profiles.
		for i in next_index:
			if not data.profile.has(Content.levels()[i].id):
				next_index = i
				break
		if next_index < Content.levels().size():
			data.level = next_index
			data.level_id = Content.levels()[int(data.level)].id
			data.catalog = Content.VERSION
			data.actions = []
			data.used_undo = false
			load_run()
			note = ""
			persist()
		else:
			screen = "ending"
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

func spirit(at: Vector2, active: bool = true, compact: bool = false) -> void:
	var tint := RED if active else Color("4b7c83")
	draw_set_transform(at, 0, Vector2.ONE * (0.7 if compact else 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 15), Vector2(-13, -8), Vector2(13, -8), Vector2(17, 15), Vector2(5, 10), Vector2(-6, 15)]), tint)
	draw_circle(Vector2(0, -8), 16, tint)
	draw_circle(Vector2(0, -8), 11, INK)
	draw_line(Vector2(0, -8), Vector2(0, -15), SAND, 2)
	draw_line(Vector2(0, -8), Vector2(6, -5), SAND, 2)
	draw_set_transform(Vector2.ZERO)

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
		text_at("%02d / %02d  ·  %s" % [Content.index_of(data.level_id) + 1, Content.levels().size(), level.name], Vector2(26, 126), 23)
		box(Rect2(24, 146, 260, 72), Color("173e53"), 12, Color("347b7d"))
		text_at("COURIER POWER", Vector2(40, 170), 15, TEAL)
		text_at(str(state.power), Vector2(40, 205), 34, GOLD)
		text_at("Keys  %d    Shields  %d" % [state.keys, state.shields], Vector2(310, 172), 20)
		text_at("Moves %d    Treasure %d" % [state.moves, state.treasure], Vector2(310, 204), 19, MUTED)
		if not state.get("rescued", []).is_empty():
			text_at("Keepers rescued: %d" % state.rescued.size(), Vector2(310, 232), 17, TEAL)

func draw_board() -> void:
	for column in [1, 2]:
		var highest := -1
		for room in level.rooms:
			if int(room.column) == column:
				highest = maxi(highest, int(room.floor))
		if highest >= 0:
			var x: int = 182 + (column - 1) * 200
			var highest_room: Dictionary = level.rooms.filter(func(item): return int(item.column) == column and int(item.floor) == highest)[0]
			var y: int = int(room_rect(highest_room).position.y)
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
		var rect := Rect2(31, 692 - i * home_stride(), 116, home_stride() - 2)
		box(rect, Color("397781") if i > 0 else Color("345566"), 4, Color("64bea9"))
		draw_rect(Rect2(72, rect.position.y + 19, 29, minf(32, home_stride() - 22)), INK)
		if i > 0:
			draw_circle(rect.position + Vector2(100, 12), 4, GOLD)
	var top: float = 692 - (floors - 1) * home_stride()
	draw_colored_polygon(PackedVector2Array([Vector2(23, top), Vector2(89, top - 42), Vector2(156, top)]), TEAL)
	draw_line(Vector2(89, top - 42), Vector2(89, top - 69), GOLD, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(90, top - 69), Vector2(116, top - 61), Vector2(90, top - 52)]), GOLD)
	text_at("YOUR WATCH", Vector2(25, 778), 16, TEAL)
	for room in level.rooms:
		var rect := room_rect(room)
		var claimed: bool = room.id in state.claimed
		var collapsed: bool = room.id in state.collapsed and not claimed
		var blocked := Rules.blocked(state, room)
		var fill := Color("405a66") if blocked != "" else Color("e0cba5")
		if claimed:
			fill = Color("397781")
		if collapsed:
			fill = Color("263c50")
		box(rect, fill, 5, GOLD if selected == room.id else Color("75949a"))
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 24), Vector2(180, 24)), Color("274859"))
		centered(room.name, Rect2(rect.position + Vector2(0, rect.size.y - 24), Vector2(180, 24)), 16, WHITE)
		if collapsed:
			centered("COLLAPSED", Rect2(rect.position, Vector2(180, 90)), 18, MUTED)
		elif claimed:
			centered("CLAIMED  +", Rect2(rect.position, Vector2(180, 70)), 21, TEAL)
			centered("Power sent home", Rect2(rect.position + Vector2(0, 57), Vector2(180, 25)), 14, SAND)
		else:
			for i in room.enemies.size():
				var enemy_x: float = (i + 1) * 180.0 / (room.enemies.size() + 1)
				var compact: bool = rect.size.y < 120
				spirit(rect.position + Vector2(enemy_x, 67 if compact else 77), blocked == "", compact)
				centered(str(room.enemies[i]), Rect2(rect.position + Vector2(enemy_x - 42, 22), Vector2(84, 34)), 32, INK if blocked == "" else GOLD)
			var tags: Array = []
			if room.key_cost > 0: tags.append("LOCK %d" % room.key_cost)
			if room.keys > 0: tags.append("+%d KEY" % int(room.keys))
			if room.shields > 0: tags.append("+%d SHIELD" % int(room.shields))
			if room.trap > 0: tags.append("TRAP %d" % room.trap)
			if room.multiplier > 1: tags.append("SUN x%d" % room.multiplier)
			if room.treasure: tags.append("CHEST")
			if room.rescue: tags.append("RESCUE")
			if room.get("keeper", false): tags.append("KEEPER")
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
		button("next", "Next watch" if Content.index_of(data.level_id) + 1 < Content.levels().size() else "The ending · all lanterns rise", TEAL)
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
			text_at("FORECAST: %s · %d to %d" % ["CLAIM" if preview.win else "DEFEAT", int(state.power), int(preview.state.power)], Vector2(40, 820), 21, TEAL if preview.win else RED)
			text_at("Tap forecast for all steps and resources", Vector2(40, 851), 17, SAND)
		button("enter", "Enter room" if preview.get("win", false) else "Enter anyway · danger", TEAL if preview.get("win", false) else Color("633f4b"))
	else:
		text_at("READ THE TOWER", Vector2(40, 825), 22, GOLD)
		lines(level.lesson, Vector2(40, 858), 510, 21, WHITE, 3)
	button("undo", "Undo")
	button("retry", "Retry")
	button("map", "Journey")

func draw_map() -> void:
	var titles := ["Lantern Coast", "Salt Archives", "Glass March", "Last Meridian"]
	text_at(titles[chapter], Vector2(26, 130), 32)
	for i in 4:
		button("chapter%d" % i, ["Coast", "Archive", "Glass", "Meridian"][i], TEAL if chapter == i else Color("24485e"))
	var all := Content.levels()
	for slot in 9:
		var i := chapter * 9 + slot
		var current: bool = all[i].id == data.level_id
		var earned: bool = data.profile.has(all[i].id)
		var available: bool = Content.unlocked(i, data.profile) or current or earned
		if not buttons().has("level%d" % i): continue
		var rect: Rect2 = buttons()["level%d" % i]
		box(rect, Color("254c5e") if available else Color("182f43"), 10, TEAL if current else Color.TRANSPARENT)
		text_at("%02d" % (i + 1), rect.position + Vector2(16, 32), 24, GOLD if available else MUTED)
		text_at(all[i].name, rect.position + Vector2(70, 29), 23, WHITE if available else MUTED)
		var medals: Dictionary = data.profile.get(all[i].id, {})
		var possible: int = 4 if all[i].rooms.any(func(room): return room.treasure) else 3
		var count := 0
		for bit in [1, 2, 4, 8]:
			if int(medals.get("medals", 0)) & bit: count += 1
		text_at("Best %d · medals %d/%d" % [int(medals.best), count, possible] if earned else ("Par %d%s" % [int(all[i].par), " · chapter finale" if bool(all[i].get("finale", false)) else ""] if available else "Rescue the previous keepers"), rect.position + Vector2(70, 55), 17, TEAL if available else MUTED)
	text_at("Drag the list to see all nine watches", Vector2(26, 945), 18, SAND)
	button("resume", "Return to current route", TEAL)
	text_at("%d / 36 rescued · rules and medal guide in •••" % data.profile.size(), Vector2(26, 962), 15, MUTED)

func draw_ending() -> void:
	text_at("ALL LANTERNS RISE", Vector2(26, 180), 36, GOLD)
	lines("The last chime crosses the sea. Every watch answers. You brought the lost keepers home.", Vector2(28, 234), 530, 27, WHITE, 4)
	for i in 12:
		var x := 34 + (i % 6) * 93
		var y := 488 + (i / 6) * 168
		box(Rect2(x, y, 68, 104), Color("397781"), 5, TEAL)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y), Vector2(x + 34, y - 36), Vector2(x + 73, y)]), TEAL)
		draw_circle(Vector2(x + 34, y + 44), 10, GOLD)
	courier(Vector2(300, 750), 1.6)
	lines("36 authored watches. Return for unclaimed treasure, par routes, clean runs and alternate branches.", Vector2(28, 836), 530, 22, SAND, 3)
	button("map", "Explore your journey", TEAL)

func _draw() -> void:
	if state == null:
		return
	background()
	draw_header()
	if screen == "game": draw_game()
	elif screen == "ending": draw_ending()
	else: draw_map()
	if save_error != "":
		box(Rect2(12, 226, 576, 65), Color("6a2838"), 8)
		lines(save_error, Vector2(24, 250), 550, 19, WHITE, 2)
	if menu:
		draw_rect(Rect2(0, 0, 600, 1066), Color(0.01, 0.03, 0.08, 0.85))
		box(Rect2(30, 180, 540, 580), INK, 20, Color("467a87"))
		text_at("Your lantern", Vector2(58, 242), 32, GOLD)
		button("sound", "Sound: " + ("on" if data.settings.sound else "off"))
		button("effects", "Reduced effects: " + ("on" if data.settings.reduced_effects else "off"))
		button("transfer", "Export / import save")
		button("guide", "Rules and medals")
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

	if guide:
		draw_rect(Rect2(0, 0, 600, 1066), Color("0b2037"))
		text_at("Carry the light", Vector2(42, 107), 34, GOLD)
		var help := ["Power must be GREATER than each enemy. Equality loses. Add each defeated strength before the next voice.", "A key opens one lock, then is gone. Read the lock cost and the keys a room gives.", "A dashed bridge seals the named alternative rooms. Rescue KEEPER rooms before their bridge closes.", "A shield blocks one trap before combat. Otherwise subtract the trap from power first.", "A sun lens multiplies after enemies. It refuses a carried shield: spend protection before entering.", "Medals reward rescue, a route at par, no Undo and treasure where offered. Earn them on separate replays. Retry starts a clean attempt; earned medals stay."]
		for i in help.size():
			text_at(str(i + 1), Vector2(42, 174 + i * 111), 26, TEAL)
			lines(help[i], Vector2(80, 168 + i * 111), 470, 21, WHITE, 4)
		button("close_guide", "Return", TEAL)
	if details:
		draw_rect(Rect2(0, 0, 600, 1066), Color("0b2037"))
		var preview := Rules.step(level, state, selected)
		text_at("Every step is visible", Vector2(42, 104), 32, GOLD)
		text_at(Rules.find_room(level, selected).name, Vector2(42, 148), 26, WHITE)
		text_at("Power %d to %d" % [state.power, preview.state.power], Vector2(42, 196), 26, TEAL if preview.get("win", false) else RED)
		text_at("Keys %d to %d · Shields %d to %d" % [state.keys, preview.state.keys, state.shields, preview.state.shields], Vector2(42, 231), 22, SAND)
		var y := 290
		for event in preview.events:
			lines(str(event), Vector2(42, y), 516, 23, WHITE, 2)
			y += 78
		button("close_details", "Return to room choice", TEAL)
