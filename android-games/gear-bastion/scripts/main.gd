extends Node2D
## Fixed portrait battlefield and continuously interactive socket board.

const Gear = preload("res://scripts/gear_rules.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const Saves = preload("res://scripts/save_store.gd")
const BOARD_ORIGIN := Vector2(100, 660)
const CELL := 80.0
const INK := Color("172b36")
const CREAM := Color("f4e7bd")
const GOLD := Color("e3b65c")
const MINT := Color("78d8ba")
const RED := Color("ec887a")
const BLUE := Color("81c4e0")
var state: Dictionary = Battle.initial()
var settings := {"muted": false, "reduced_effects": false}
var paused := false
var speed := 1
var selected := 2
var drag_id := -1
var drag_kind := ""
var drag_start := Vector2.ZERO
var pointer := Vector2.ZERO
var dragging := false
var active_touch := -1
var undo_board: Array = []
var message := "Drag a drive beside a troop gear to raise its rate."
var clock := 0.0
var accumulator := 0.0
var save_clock := 0.0
var font: Font = ThemeDB.fallback_font
var audio: AudioStreamPlayer
var save_dialog: AcceptDialog
var save_text: TextEdit
var save_path := Saves.PATH
var save_backend: Variant = null
var save_failed := false

func _ready() -> void:
	var loaded := Saves.read(save_path, save_backend)
	if loaded.ok:
		state = loaded.state
		settings = loaded.settings
		paused = state.phase == "battle"
		message = "Resumed safely · tap Resume when ready" if paused else "Saved foundry restored"
	audio = AudioStreamPlayer.new()
	add_child(audio)
	_build_save_dialog()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		drag_id = -1
		drag_kind = ""
		dragging = false
		active_touch = -1
		persist()
		paused = true
	if what == NOTIFICATION_APPLICATION_RESUMED and state.phase == "battle":
		paused = true
		message = "Welcome back · Resume when ready"

func persist() -> bool:
	# Every caller is covered by the persistent warning, including autosave and
	# lifecycle notifications. Only confirmed success clears a prior failure.
	var success := Saves.write(state, settings, save_path, save_backend)
	save_failed = not success
	return success

func _process(delta: float) -> void:
	clock += delta
	if not paused:
		advance(minf(delta, 0.2) * speed)
	save_clock += delta
	if save_clock >= 5:
		save_clock = 0
		persist()
	queue_redraw()

func advance(seconds: float) -> void:
	if paused:
		return
	accumulator += seconds
	while accumulator + 0.000000001 >= Battle.STEP:
		var before: String = state.phase
		Battle.tick(state, Battle.STEP)
		accumulator = maxf(0.0, accumulator - Battle.STEP)
		if before == "battle" and state.phase != before:
			message = "Foundry held. Every gear helped." if state.phase == "victory" else "Wall breached. Retry and reconnect your foundry."
			_tone(660 if state.phase == "victory" else 140)
			persist()

func retry() -> void:
	state = Battle.initial(int(state.seed), str(state.encounter))
	paused = false
	speed = 1
	undo_board.clear()
	drag_id = -1
	drag_kind = ""
	selected = 2
	accumulator = 0
	message = "Fresh attempt · rearrange freely, then Begin"
	persist()

func cell_center(x: int, y: int) -> Vector2:
	return BOARD_ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - BOARD_ORIGIN.x) / CELL), floori((point.y - BOARD_ORIGIN.y) / CELL))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if active_touch >= 0:
				return
			active_touch = event.index
			press(event.position)
		else:
			if active_touch != event.index:
				return
			active_touch = -1
			if event.canceled:
				drag_id = -1
				drag_kind = ""
				dragging = false
			else:
				release(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index != active_touch:
			return
		pointer = event.position
		dragging = pointer.distance_to(drag_start) > 12
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == -1:
			return
		if event.pressed:
			press(event.position)
		else:
			release(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (drag_id >= 0 or drag_kind != ""):
		pointer = event.position
		dragging = pointer.distance_to(drag_start) > 12
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		paused = not paused

func buttons() -> Dictionary:
	var result := {"pause": Rect2(20, 65, 110, 46), "speed": Rect2(140, 65, 88, 46),
		"mute": Rect2(238, 65, 104, 46), "effects": Rect2(352, 65, 110, 46),
		"save": Rect2(472, 65, 108, 46), "begin": Rect2(420, 584, 160, 50),
		"drive": Rect2(20, 1001, 130, 53), "guard": Rect2(160, 1001, 130, 53),
		"ranger": Rect2(300, 1001, 140, 53), "undo": Rect2(450, 1001, 130, 53),
		"gate0": Rect2(510, 700, 80, 80), "gate1": Rect2(510, 790, 80, 80), "gate2": Rect2(510, 880, 80, 80)}
	if state.phase == "ready":
		result.merge({"tutorial": Rect2(90, 440, 200, 80), "trial": Rect2(310, 440, 200, 80)})
	if state.encounter == "iron_trial":
		result["refit"] = Rect2(8, 880, 84, 80)
	return result

func hitboxes() -> Dictionary:
	var result := buttons()
	# Minimum 80 logical pixels = 48 dp at a 360 dp-wide portrait presentation.
	for key in ["pause", "speed", "mute", "effects", "save", "begin"]:
		var box: Rect2 = result[key]
		result[key] = Rect2(box.position.x, box.get_center().y - 40, box.size.x, 80)
	for key in ["drive", "guard", "ranger", "undo"]:
		var box: Rect2 = result[key]
		result[key] = Rect2(box.position.x, 986, box.size.x, 80)
	return result

func press(point: Vector2) -> void:
	pointer = point
	drag_start = point
	dragging = false
	var ui := hitboxes()
	for kind in ["drive", "guard", "ranger"]:
		if ui[kind].has_point(point):
			drag_kind = kind
			drag_id = -1
			return
	var cell := cell_at(point)
	var index := Gear.at(state.board, cell.x, cell.y)
	if index >= 0:
		selected = int(state.board[index].id)
		drag_id = selected
		drag_kind = ""

func release(point: Vector2) -> void:
	pointer = point
	if drag_kind != "":
		if dragging:
			var cell := cell_at(point)
			var result := Gear.buy(state.board, drag_kind, cell.x, cell.y, int(state.gold), int(state.next_id), str(state.encounter))
			message = result.message
			if result.ok:
				state.board = result.board
				state.gold = result.gold
				state.spent = int(state.spent) + int(Gear.COSTS[drag_kind])
				selected = int(state.next_id)
				state.next_id = int(state.next_id) + 1
				undo_board.clear()
				_tone(440)
				persist()
		else:
			message = "Drag %s from this tray to an empty socket" % drag_kind
		drag_kind = ""
		dragging = false
		return
	if drag_id >= 0:
		if dragging:
			var cell := cell_at(point)
			var result := Gear.move(state.board, drag_id, cell.x, cell.y, str(state.encounter))
			message = result.message
			if result.ok:
				undo_board = state.board.duplicate(true)
				state.board = result.board
				_tone(520)
				persist()
		else:
			var piece := selected_piece()
			if not piece.is_empty():
				message = "Core powers connected pieces" if piece.kind == "core" else "%s · %s" % [str(piece.kind).capitalize(), "choose exit at right" if piece.kind in ["guard", "ranger"] else "equal drives merge · Undo restores"]
		drag_id = -1
		dragging = false
		return
	for action in hitboxes():
		if hitboxes()[action].has_point(point) and hitboxes()[action].has_point(drag_start):
			act(action)
			return

func act(action: String) -> void:
	match action:
		"pause":
			paused = not paused
		"speed":
			speed = 2 if speed == 1 else 1
		"mute":
			settings.muted = not settings.muted
		"effects":
			settings.reduced_effects = not settings.reduced_effects
		"save":
			paused = true
			if not persist():
				save_dialog.title = "Save failed · export current progress below"
			else:
				save_dialog.title = "Portable save · copy or paste below"
			save_text.text = Saves.encode(state, settings)
			save_dialog.popup_centered(Vector2i(540, 760))
		"begin":
			if state.phase in ["defeat", "victory"]:
				retry()
			elif state.phase == "ready":
				Battle.start(state)
				message = "Battle live · rearrange to balance your army"
				_tone(740)
			else:
				message = "Carapaces shrug off guards and cleave crowds · use rangers" if state.encounter == "iron_trial" else "Shells resist guards · support them with rangers"
		"tutorial", "trial":
			state = Battle.initial(int(state.seed), "iron_trial" if action == "trial" else "tutorial")
			undo_board.clear()
			selected = 1
			paused = false
			message = "54 brass total · no kill income · refit costs the difference" if action == "trial" else "Tutorial · connect your foundry"
		"refit":
			var result := Gear.refit(state.board, selected, int(state.gold))
			message = result.message
			if result.ok:
				state.board = result.board
				state.gold = result.gold
				state.spent = int(state.spent) + int(result.cost)
				undo_board.clear()
		"undo":
			if not undo_board.is_empty():
				state.board = undo_board.duplicate(true)
				undo_board.clear()
				message = "Move restored · battle continues"
			else:
				message = "Undo restores your last move or merge"
		"gate0", "gate1", "gate2":
			var piece := selected_piece()
			if not piece.is_empty() and piece.kind in ["guard", "ranger"]:
				piece.lane = int(action.right(1))
				message = "New %s troops use exit %d" % [piece.kind, int(piece.lane) + 1]
	if action != "save":
		persist()
	queue_redraw()

func selected_piece() -> Dictionary:
	for piece in state.board:
		if int(piece.id) == selected:
			return piece
	return {}

func _build_save_dialog() -> void:
	save_dialog = AcceptDialog.new()
	save_dialog.title = "Portable save · copy or paste below"
	save_dialog.dialog_text = ""
	save_dialog.ok_button_text = "Close"
	save_dialog.get_ok_button().custom_minimum_size = Vector2(160, 80)
	add_child(save_dialog)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(500, 540)
	save_dialog.add_child(content)
	var explanation := Label.new()
	explanation.text = "Select all / copy to export. Paste a save, then Import.\nYour local save resumes the battle paused."
	content.add_child(explanation)
	save_text = TextEdit.new()
	save_text.custom_minimum_size = Vector2(500, 420)
	save_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(save_text)
	var row := HBoxContainer.new()
	content.add_child(row)
	for label in ["Copy save", "Paste", "Import"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(155, 80)
		row.add_child(button)
		button.pressed.connect(func():
			if label == "Copy save":
				DisplayServer.clipboard_set(save_text.text)
				message = "Save copied · keep it somewhere safe"
			elif label == "Paste":
				save_text.text = DisplayServer.clipboard_get()
			else:
				var result := Saves.decode(save_text.text)
				if result.ok:
					if Saves.write(result.state, result.settings, save_path, save_backend, false):
						state = result.state
						settings = result.settings
						undo_board.clear()
						accumulator = 0
						paused = true
						save_failed = false
						message = "Imported · Resume when ready"
						save_dialog.hide()
					else:
						save_failed = true
						save_dialog.title = "Save failed · current game retained"
				else:
					save_dialog.title = "Invalid save · current game retained"
		)

func _tone(frequency: float) -> void:
	if settings.muted or not is_instance_valid(audio):
		return
	var data := PackedByteArray()
	data.resize(4410)
	for i in 2205:
		var t := float(i) / 22050.0
		var value := int(sin(t * frequency * TAU) * (1.0 - float(i) / 2205.0) * 3500)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	audio.stream = stream
	audio.play()

func panel(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT, radius: int = 14) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0 else 0)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func label_at(value: String, point: Vector2, size: int = 20, color: Color = CREAM, centered: bool = false) -> void:
	var origin := point
	if centered:
		origin.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string(font, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 600, 1066), Color("10212c"))
	label_at("GEAR BASTION", Vector2(20, 37), 28, GOLD)
	var heading := "IRON TRIAL · 54 BRASS" if state.encounter == "iron_trial" else "THE FIRST FOUNDRY"
	label_at(heading, Vector2(578, 32) - Vector2(font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, 0), 14, MINT)
	var ui := buttons()
	for key in ["pause", "speed", "mute", "effects", "save"]:
		panel(ui[key], Color("243c48"))
	var labels := {"pause": "Resume" if paused else "Pause", "speed": "%d× speed" % speed,
		"mute": "Muted" if settings.muted else "Sound on", "effects": "Calm FX" if settings.reduced_effects else "Full FX", "save": "Save"}
	for key in labels:
		label_at(labels[key], ui[key].get_center() + Vector2(0, 6), 17, CREAM, true)
	_draw_field()
	if save_failed:
		panel(Rect2(28, 194, 544, 44), INK, RED, 6)
		label_at("Save failed · retry Save or export before closing", Vector2(300, 222), 18, RED, true)
	_draw_wall()
	panel(Rect2(20, 584, 388, 50), Color("203844"))
	label_at("%d brass   ·   %.2f troops/s" % [int(state.gold), Gear.total_rate(state.board)], Vector2(34, 617), 21, GOLD)
	panel(ui.begin, MINT if state.phase == "ready" else Color("344e58"))
	var begin_text := "Begin defense" if state.phase == "ready" else "Threat tips"
	if state.phase in ["defeat", "victory"]:
		begin_text = "Retry now"
	label_at(begin_text, ui.begin.get_center() + Vector2(0, 7), 21, INK if state.phase == "ready" else CREAM, true)
	label_at("POWER NETWORK", Vector2(20, 653), 15, MINT)
	_draw_board()
	label_at("BRASS", Vector2(50, 718), 17, GOLD, true)
	label_at("CORE", Vector2(50, 742), 17, GOLD, true)
	label_at("+25%", Vector2(50, 794), 24, BLUE, true)
	label_at("per level", Vector2(50, 820), 17, CREAM, true)
	label_at("adjacent", Vector2(50, 845), 17, CREAM, true)
	label_at("drive", Vector2(50, 870), 17, CREAM, true)
	if state.encounter == "iron_trial":
		var refit_piece := selected_piece()
		panel(ui.refit, Color("304754"))
		label_at("Refit", Vector2(50, 913), 20, CREAM, true)
		label_at("-2" if refit_piece.get("kind", "") == "ranger" else "+2", Vector2(50, 944), 24, GOLD, true)
	else:
		label_at("cap 3×", Vector2(50, 911), 20, GOLD, true)
	var chosen := selected_piece()
	label_at("EXIT", Vector2(550, 686), 17, MINT, true)
	for lane in 3:
		var active: bool = not chosen.is_empty() and chosen.kind in ["guard", "ranger"] and int(chosen.lane) == lane
		panel(ui["gate%d" % lane], Color("385d65") if active else Color("1b323e"), MINT if active else Color.TRANSPARENT)
		label_at("Exit %d" % (lane + 1), ui["gate%d" % lane].get_center() + Vector2(0, 7), 20, CREAM, true)
	var shortened := message
	if shortened.length() > 60:
		shortened = shortened.left(57) + "…"
	label_at(shortened, Vector2(300, 996), 17, MINT, true)
	for key in ["drive", "guard", "ranger", "undo"]:
		panel(ui[key], Color("304754"), GOLD if key == "undo" and not undo_board.is_empty() else Color.TRANSPARENT)
		var text := "Undo move" if key == "undo" else "%s  %d" % [key.capitalize(), Gear.COSTS[key]]
		label_at(text, ui[key].get_center() + Vector2(0, 7), 20, CREAM, true)
	if dragging and (drag_id >= 0 or drag_kind != ""):
		var piece := selected_piece() if drag_kind == "" else Gear.piece(0, drag_kind, 0, 0)
		if not piece.is_empty():
			_draw_gear(pointer - Vector2(0, 42), piece, true, true)

func _draw_field() -> void:
	panel(Rect2(20, 121, 560, 408), Color("314a49"), Color("587369"))
	for lane in 3:
		var lane_x := 116 + 184 * lane
		draw_rect(Rect2(lane_x - 64, 161, 128, 364), Color("38534d"))
		for y in range(190, 520, 56):
			draw_line(Vector2(lane_x - 22, y), Vector2(lane_x + 22, y - 8), Color("426052"), 2)
	label_at("WALL %d / %d" % [ceili(float(state.wall)), int(Battle.wall_limit(state))], Vector2(36, 150), 20, CREAM)
	label_at("ARMY %d / %d" % [state.units.size(), Battle.UNIT_CAP], Vector2(564, 150) - Vector2(font.get_string_size("ARMY %d / %d" % [state.units.size(), Battle.UNIT_CAP], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, 0), 18, GOLD)
	if state.phase == "ready":
		label_at("Iron Trial · one fixed budget" if state.encounter == "iron_trial" else "The beetle tide is coming", Vector2(300, 254), 25, CREAM, true)
		label_at("1. Connect gears to the gold core", Vector2(300, 299), 21, MINT, true)
		label_at("2. Place drives beside troop gears", Vector2(300, 333), 21, MINT, true)
		label_at("3. Begin · keep building as they fight", Vector2(300, 367), 21, MINT, true)
		label_at("Guards screen spitters. Rangers pierce armor." if state.encounter == "iron_trial" else "Guards block. Rangers pierce shells.", Vector2(300, 426), 19, GOLD, true)
		for key in ["tutorial", "trial"]:
			panel(buttons()[key], Color("243c48"), MINT if (key == "trial") == (state.encounter == "iron_trial") else Color.TRANSPARENT)
			label_at("Tutorial" if key == "tutorial" else "Iron Trial", buttons()[key].get_center() + Vector2(0, 7), 22, CREAM, true)
	else:
		for unit in state.units:
			_draw_unit(unit, true)
		for enemy in state.enemies:
			_draw_unit(enemy, false)
		if not settings.reduced_effects:
			for arrow in state.projectiles:
				draw_line(Vector2(arrow[0], arrow[1]), Vector2(arrow[2], arrow[3]), GOLD if arrow.size() < 5 or arrow[4] else RED, 2)
		var wave_index := maxi(0, int(state.wave) - 1)
		var wave: Dictionary = Battle.waves(str(state.encounter))[wave_index]
		panel(Rect2(145, 164, 310, 28), Color(0.06, 0.12, 0.15, 0.8), Color.TRANSPARENT, 6)
		label_at("WAVE %d / 3 · %s" % [int(state.wave), wave.name], Vector2(300, 185), 17, CREAM, true)
		var forecast := "Final push · armor + crowd-cleave · use rangers" if state.encounter == "iron_trial" else "Final push · shells resist guard attacks"
		if int(state.wave) < 3:
			forecast = "Next: " + str(Battle.waves(str(state.encounter))[int(state.wave)].name)
		if state.units.size() >= Battle.UNIT_CAP:
			var producer := Battle.next_producer(state, Gear.rates(state.board))
			forecast = "Army full · fair turns · next " + str(producer.get("kind", "charging"))
		if state.encounter == "iron_trial":
			panel(Rect2(46, 474, 508, 48), Color(0.06, 0.12, 0.15, 0.9), Color.TRANSPARENT, 5)
			label_at("%d lost · carapaces shrug off guards and cleave crowds" % int(state.losses), Vector2(300, 491), 15, CREAM, true)
		else:
			panel(Rect2(72, 494, 456, 28), Color(0.06, 0.12, 0.15, 0.85), Color.TRANSPARENT, 5)
		label_at(forecast, Vector2(300, 514), 16, GOLD, true)
		if paused:
			panel(Rect2(192, 308, 216, 63), Color("172b36"), GOLD)
			label_at("PAUSED", Vector2(300, 349), 28, GOLD, true)
		if state.phase in ["victory", "defeat"]:
			panel(Rect2(82, 277, 436, 155), Color("172b36"), MINT if state.phase == "victory" else RED)
			label_at("FOUNDRY HELD" if state.phase == "victory" else "WALL BREACHED", Vector2(300, 319), 30, MINT if state.phase == "victory" else RED, true)
			label_at("%d troops built · %d raiders stopped" % [int(state.produced), int(state.kills)], Vector2(300, 360), 20, CREAM, true)
			label_at("Tap Retry now below", Vector2(300, 401), 20, GOLD, true)

func _draw_wall() -> void:
	draw_rect(Rect2(20, 530, 560, 48), Color("a09c7e"))
	for x in range(20, 579, 40):
		draw_rect(Rect2(x, 521, 22, 16), Color("c3bd95"))
	for lane in 3:
		var x := 116 + lane * 184
		panel(Rect2(x - 27, 531, 54, 47), Color("152f3c"), GOLD, 5)
		label_at(str(lane + 1), Vector2(x, 561), 25, GOLD, true)
	draw_rect(Rect2(20, 577, 560, 5), Color("6d443f"))
	draw_rect(Rect2(20, 577, 560 * float(state.wall) / Battle.wall_limit(state), 5), MINT)

func _draw_board() -> void:
	var network := Gear.powered(state.board)
	for y in 4:
		for x in 5:
			var center := cell_center(x, y)
			if not Gear.cell_allowed(x, y, str(state.encounter)):
				draw_line(center - Vector2(12, 12), center + Vector2(12, 12), Color("39505a"), 3)
				draw_line(center + Vector2(-12, 12), center + Vector2(12, -12), Color("39505a"), 3)
				continue
			panel(Rect2(center - Vector2(36, 36), Vector2(72, 72)), Color("213b49"), Color("365361"), 10)
	for p in state.board:
		for other in state.board:
			if int(other.id) <= int(p.id):
				continue
			if absi(int(p.x) - int(other.x)) + absi(int(p.y) - int(other.y)) == 1:
				var active := network.has(int(p.id)) and network.has(int(other.id))
				draw_line(cell_center(int(p.x), int(p.y)), cell_center(int(other.x), int(other.y)), MINT if active else Color("6e5251"), 7)
	for p in state.board:
		_draw_gear(cell_center(int(p.x), int(p.y)), p, network.has(int(p.id)), false)
	if dragging:
		var cell := cell_at(pointer)
		if cell.x >= 0 and cell.x < 5 and cell.y >= 0 and cell.y < 4:
			var valid := false
			if drag_id >= 0:
				valid = Gear.move(state.board, drag_id, cell.x, cell.y, str(state.encounter)).ok
			else:
				valid = Gear.buy(state.board, drag_kind, cell.x, cell.y, int(state.gold), int(state.next_id), str(state.encounter)).ok
			panel(Rect2(cell_center(cell.x, cell.y) - Vector2(37, 37), Vector2(74, 74)), Color(0, 0, 0, 0), MINT if valid else RED)

func _draw_gear(center: Vector2, piece: Dictionary, active: bool, ghost: bool) -> void:
	var kind: String = piece.kind
	var color := GOLD if kind == "core" else BLUE if kind == "drive" else CREAM
	if not active:
		color = Color("81736d")
	var rotation_angle := 0.0
	if active and not settings.reduced_effects and not paused:
		rotation_angle = clock * 0.55 * (1 if (int(piece.x) + int(piece.y)) % 2 == 0 else -1)
	for tooth in 10:
		var angle := TAU * tooth / 10.0 + rotation_angle
		var radial := Vector2.from_angle(angle)
		draw_line(center + radial * 21, center + radial * 28, color, 9, true)
	draw_circle(center, 23, color)
	draw_circle(center, 18, INK)
	if kind == "core":
		draw_circle(center, 10, GOLD)
		draw_line(center + Vector2(-3, -7), center + Vector2(5, -1), CREAM, 3)
		draw_line(center + Vector2(5, -1), center + Vector2(-2, 7), CREAM, 3)
	elif kind == "drive":
		label_at(str(int(piece.level)), center + Vector2(0, 8), 26, BLUE if active else color, true)
	elif kind == "guard":
		draw_line(center + Vector2(0, 9), center + Vector2(0, -11), color, 4)
		draw_line(center + Vector2(-7, 3), center + Vector2(7, 3), color, 3)
	else:
		draw_arc(center + Vector2(-6, 0), 12, -1.1, 1.1, 12, color, 3, true)
		draw_line(center + Vector2(0, -11), center + Vector2(0, 11), color, 2)
		draw_line(center + Vector2(-9, 0), center + Vector2(12, 0), color, 2)
	if kind in ["guard", "ranger"] and not ghost:
		var rate := Gear.rate(state.board, int(piece.id))
		panel(Rect2(center + Vector2(-37, 20), Vector2(74, 23)), INK, Color.TRANSPARENT, 4)
		label_at("%.2f/s" % rate if active else "OFF", center + Vector2(0, 38), 20, MINT if active else RED, true)
		label_at(str(int(piece.lane) + 1), center + Vector2(21, -16), 13, GOLD, true)
	if int(piece.id) == selected and not ghost:
		draw_arc(center, 31, 0, TAU, 48, GOLD, 2, true)

func _draw_unit(unit: Dictionary, friendly: bool) -> void:
	var point := Vector2(float(unit.x), float(unit.y))
	var kind: String = unit.kind
	var color := GOLD if friendly else Color("b75e5e")
	if kind == "ranger":
		color = BLUE
	elif kind == "shell":
		color = Color("a5a875")
	elif kind == "carapace":
		color = Color("ac8cd3")
	elif kind == "spitter":
		color = Color("db9b5f")
	elif kind == "skitter":
		color = Color("d48f61")
	if float(unit.flash) > 0 and not settings.reduced_effects:
		color = Color.WHITE
	draw_ellipse_shadow(point)
	if friendly:
		var bob := sin(clock * 9 + int(unit.id)) * 1.2 if not paused and not settings.reduced_effects else 0.0
		point.y += bob
		draw_line(point + Vector2(-4, 5), point + Vector2(-5, 10), INK, 3)
		draw_line(point + Vector2(4, 5), point + Vector2(5, 10), INK, 3)
		panel(Rect2(point - Vector2(6, 4), Vector2(12, 12)), color, INK, 3)
		draw_circle(point + Vector2(0, -7), 5, color)
		draw_circle(point + Vector2(-2, -8), 1, INK)
		draw_circle(point + Vector2(2, -8), 1, INK)
		if kind == "guard":
			draw_line(point + Vector2(9, 5), point + Vector2(9, -9), CREAM, 2)
			draw_circle(point + Vector2(-8, 1), 5, Color("6fa7a3"))
		else:
			draw_arc(point + Vector2(8, 0), 7, -1.5, 1.5, 8, CREAM, 2)
	else:
		for leg in [-1, 1]:
			for offset in [-5, 2, 7]:
				draw_line(point + Vector2(leg * 4, offset), point + Vector2(leg * 12, offset + 3), INK, 2)
		draw_circle(point, 10 if kind == "shell" else 8, INK)
		draw_circle(point - Vector2(0, 1), 8 if kind == "shell" else 6, color)
		draw_line(point + Vector2(0, -7), point + Vector2(0, 6), INK, 2)
		if kind == "carapace":
			draw_arc(point, 11, 0, TAU, 14, color, 3)
			draw_line(point + Vector2(-5, -5), point + Vector2(5, -5), CREAM, 2)
			draw_line(point + Vector2(-5, 2), point + Vector2(5, 2), CREAM, 2)
		elif kind == "spitter":
			draw_circle(point + Vector2(0, 4), 3, MINT)
	if float(unit.hp) < float(unit.max_hp):
		draw_rect(Rect2(point + Vector2(-9, -17), Vector2(18, 3)), INK)
		draw_rect(Rect2(point + Vector2(-9, -17), Vector2(18 * float(unit.hp) / float(unit.max_hp), 3)), MINT if friendly else RED)

func draw_ellipse_shadow(point: Vector2) -> void:
	draw_circle(point + Vector2(1, 6), 9, Color(0.04, 0.09, 0.08, 0.3))
