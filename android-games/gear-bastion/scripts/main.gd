extends Node2D
## Fixed portrait battlefield and continuously interactive socket board.

const Gear = preload("res://scripts/gear_rules.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const Saves = preload("res://scripts/save_store.gd")
const Content = preload("res://scripts/campaign_data.gd")
const Profile = preload("res://scripts/campaign_profile.gd")
const CampaignUI = preload("res://scripts/campaign_ui.gd")
const FrameCapture = preload("res://scripts/frame_capture.gd")
const LocalAudio = preload("res://scripts/local_audio.gd")
const CampaignView = preload("res://scripts/campaign_view.gd")
const ActorArt = preload("res://scripts/actor_art.gd")
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
var message_until := 0.0
var message := "Drag a drive beside a troop gear to raise its rate.":
	set(value):
		message = value
		message_until = clock + 3.0
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
var profile: Dictionary = Profile.fresh()
var screen := "map"
var start_on_map := true
var abandon_dialog: ConfirmationDialog
var help_dialog: AcceptDialog
var pending_mission := ""
var pending_challenge := -1
var frame_capture := FrameCapture.new()
var sound_bank := LocalAudio.new()
var draw_microseconds := 0
var fx_sound_clock := 0.0
var actor_art := ActorArt.new()
var menu_dialog: AcceptDialog

func _ready() -> void:
	get_tree().quit_on_go_back = false
	var loaded := Saves.read(save_path, save_backend)
	if loaded.ok:
		state = loaded.state
		settings = loaded.settings
		profile = loaded.profile
		paused = state.phase == "battle"
		message = "Resumed safely · tap Resume when ready" if paused else "Saved foundry restored"
	elif start_on_map:
		state = Battle.initial(1701, "camp_01")
	if not start_on_map:
		screen = "game"
	audio = AudioStreamPlayer.new()
	add_child(audio)
	_build_save_dialog()
	RenderingServer.frame_post_draw.connect(_capture_render_frame)
	abandon_dialog = ConfirmationDialog.new()
	abandon_dialog.title = "Replace active defense?"
	abandon_dialog.dialog_text = "Starting another foundry replaces this active run.\nYour cleared foundries and medals stay saved."
	abandon_dialog.ok_button_text = "Start new defense"
	abandon_dialog.get_ok_button().custom_minimum_size = Vector2(210, 80)
	abandon_dialog.get_cancel_button().custom_minimum_size = Vector2(180, 80)
	add_child(abandon_dialog)
	abandon_dialog.confirmed.connect(func(): start_mission(pending_mission, pending_challenge))
	help_dialog = AcceptDialog.new()
	help_dialog.title = "Foundry guide"
	help_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_dialog.get_ok_button().custom_minimum_size = Vector2(160, 80)
	add_child(help_dialog)
	_build_menu()
	actor_art.bake(self)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		drag_id = -1
		drag_kind = ""
		dragging = false
		active_touch = -1
		persist()
		paused = true
		queue_redraw()
	if what == NOTIFICATION_APPLICATION_RESUMED and state.phase == "battle":
		paused = true
		message = "Welcome back · Resume when ready"
		queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()

func persist() -> bool:
	# Every caller is covered by the persistent warning, including autosave and
	# lifecycle notifications. Only confirmed success clears a prior failure.
	var success := Saves.write(state, settings, save_path, save_backend, true, profile)
	if save_failed == success:
		queue_redraw()
	save_failed = not success
	return success

func _process(delta: float) -> void:
	clock += delta
	fx_sound_clock += delta
	if not paused and screen == "game":
		advance(minf(delta, 0.2) * speed)
	save_clock += delta
	if save_clock >= 5:
		save_clock = 0
		persist()
	if (screen == "game" and state.phase in ["ready", "battle"] and not paused) or dragging:
		queue_redraw()

func advance(seconds: float) -> void:
	if paused:
		return
	accumulator += seconds
	while accumulator + 0.000000001 >= Battle.STEP:
		var before: String = state.phase
		var before_wave: int = state.wave
		var before_kills: int = state.kills
		Battle.tick(state, Battle.STEP)
		accumulator = maxf(0.0, accumulator - Battle.STEP)
		if state.wave != before_wave:
			_tone(580 + int(state.wave) * 30)
		elif int(state.kills) > before_kills and fx_sound_clock >= 0.6:
			_tone(190 + int(state.kills) % 4 * 20)
			fx_sound_clock = 0.0
		if before == "battle" and state.phase != before:
			if state.phase == "victory":
				Profile.award(profile, state)
			message = "Foundry held. Every gear helped." if state.phase == "victory" else "Wall breached. Retry and reconnect your foundry."
			_tone(660 if state.phase == "victory" else 140)
			persist()
			queue_redraw()

func retry() -> void:
	var snapshot: Dictionary = state.config.duplicate(true)
	state = Battle.from_snapshot(snapshot, int(state.seed)) if not snapshot.is_empty() else Battle.initial(int(state.seed), str(state.encounter))
	paused = false
	speed = 1
	undo_board.clear()
	drag_id = -1
	drag_kind = ""
	selected = 2
	accumulator = 0
	message = "Fresh attempt · rearrange freely, then Begin"
	persist()

func handle_back() -> void:
	if is_instance_valid(save_dialog) and save_dialog.visible:
		save_dialog.hide()
	elif is_instance_valid(help_dialog) and help_dialog.visible:
		help_dialog.hide()
	elif is_instance_valid(menu_dialog) and menu_dialog.visible:
		menu_dialog.hide()
	elif is_instance_valid(abandon_dialog) and abandon_dialog.visible:
		abandon_dialog.hide()
	elif screen == "game" and state.phase == "battle" and not paused:
		paused = true
		message = "Paused and saved · Back again opens the journey"
	elif screen == "game":
		paused = true
		screen = "map"
	else:
		screen = "map"
		message = "Progress saved · use Home to leave"
	persist()
	queue_redraw()

func _capture_render_frame() -> void:
	var eligible: bool = screen == "game" and state.phase == "battle" and not paused and not save_dialog.visible and not abandon_dialog.visible and not help_dialog.visible and not menu_dialog.visible
	frame_capture.sample(Time.get_ticks_usec(), eligible, {"friendly": state.units.size(), "enemies": state.enemies.size(), "encounter": state.encounter, "reduced_effects": settings.reduced_effects}, draw_microseconds)

func stop_frame_capture() -> void:
	var report := frame_capture.stop()
	var source := JSON.stringify(report)
	var path := "user://frames-%d.json" % int(Time.get_unix_time_from_system())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(source)
		file.close()
	save_text.text = source
	save_dialog.title = "Local frame timing report · copy to export"

func request_mission(id: String, challenge: int = -1) -> void:
	if id != "tutorial" and not Profile.accessible(profile, id):
		message = "Defend the previous foundry first"
		return
	pending_mission = id
	pending_challenge = challenge
	if state.phase == "battle":
		abandon_dialog.popup_centered(Vector2i(520, 260))
	else:
		start_mission(id, challenge)

func start_mission(id: String, challenge: int = -1) -> void:
	state = Battle.initial(1701 if challenge < 0 else 1729 + challenge, id)
	if challenge >= 0:
		state.config.challenge = true
		state.config.budget -= 6
		state.gold -= 6
		state.config.seed_offset = challenge
	paused = false
	speed = 1
	screen = "game"
	selected = 1
	accumulator = 0
	undo_board.clear()
	drag_id = -1
	drag_kind = ""
	dragging = false
	message = state.config.get("decision", "Tutorial · connect your foundry")
	persist()

func cell_center(x: int, y: int) -> Vector2:
	return board_origin() + Vector2(x + 0.5, y + 0.5) * CELL

func board_origin() -> Vector2:
	return BOARD_ORIGIN if state.config.is_empty() else CampaignView.board_origin(self)

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - board_origin().x) / CELL), floori((point.y - board_origin().y) / CELL))

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
		queue_redraw()
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
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		handle_back()

func buttons() -> Dictionary:
	if screen != "game":
		return CampaignUI.buttons(self)
	if not state.config.is_empty():
		return CampaignView.buttons(self)
	var result := {"pause": Rect2(20, 65, 110, 46), "speed": Rect2(140, 65, 88, 46),
		"mute": Rect2(238, 65, 104, 46), "effects": Rect2(352, 65, 110, 46),
		"save": Rect2(472, 65, 108, 46), "begin": Rect2(420, 584, 160, 50),
		"drive": Rect2(20, 1001, 130, 53), "guard": Rect2(160, 1001, 130, 53),
		"ranger": Rect2(300, 1001, 140, 53), "undo": Rect2(450, 1001, 130, 53),
		"gate0": Rect2(510, 700, 80, 80), "gate1": Rect2(510, 790, 80, 80), "gate2": Rect2(510, 880, 80, 80)}
	if not state.config.is_empty():
		result.merge({"map": Rect2(8, 685, 84, 80), "refit": Rect2(8, 785, 84, 80), "help": Rect2(8, 885, 84, 80), "drive": Rect2(10, 1001, 110, 53), "guard": Rect2(125, 1001, 110, 53), "ranger": Rect2(240, 1001, 110, 53), "mortar": Rect2(355, 1001, 110, 53), "undo": Rect2(470, 1001, 120, 53)}, true)
		if state.phase == "victory":
			result["next"] = Rect2(310, 440, 220, 80)
		elif state.phase == "battle":
			result["rally"] = Rect2(185, 239, 230, 46)
	elif state.phase == "ready":
		result.merge({"tutorial": Rect2(90, 440, 200, 80), "trial": Rect2(310, 440, 200, 80)})
	if state.encounter == "iron_trial":
		result["refit"] = Rect2(8, 880, 84, 80)
	return result

func hitboxes() -> Dictionary:
	var result := buttons()
	if screen != "game" or not state.config.is_empty():
		return result
	# Minimum 80 logical pixels = 48 dp at a 360 dp-wide portrait presentation.
	for key in ["pause", "speed", "mute", "effects", "save", "begin"]:
		var box: Rect2 = result[key]
		result[key] = Rect2(box.position.x, box.get_center().y - 40, box.size.x, 80)
	for key in ["drive", "guard", "ranger", "mortar", "undo"]:
		if not result.has(key):
			continue
		var box: Rect2 = result[key]
		result[key] = Rect2(box.position.x, 986, box.size.x, 80)
	return result

func press(point: Vector2) -> void:
	queue_redraw()
	pointer = point
	drag_start = point
	dragging = false
	var ui := hitboxes()
	if screen != "game":
		return
	for kind in ["drive", "guard", "ranger", "mortar"]:
		if not ui.has(kind):
			continue
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
	queue_redraw()
	pointer = point
	if screen != "game":
		for action in buttons():
			if buttons()[action].has_point(point) and buttons()[action].has_point(drag_start):
				act(action)
				return
		return
	if drag_kind != "":
		if dragging:
			var cell := cell_at(point)
			var result := Gear.buy(state.board, drag_kind, cell.x, cell.y, int(state.gold), int(state.next_id), str(state.encounter), state.config)
			message = result.message
			if result.ok:
				state.board = result.board
				state.gold = result.gold
				state.spent = int(state.spent) + int(state.config.get("costs", Gear.COSTS)[drag_kind])
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
			var result := Gear.move(state.board, drag_id, cell.x, cell.y, str(state.encounter), state.config)
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
	if action.begins_with("mission"):
		request_mission(Content.IDS[int(action.trim_prefix("mission"))])
		return
	if action.begins_with("challenge") and action != "challenges":
		var slot := int(action.trim_prefix("challenge"))
		request_mission(["camp_05", "camp_07", "camp_09"][slot], slot)
		return
	match action:
		"map", "journey":
			paused = true
			screen = "map"
		"menu":
			paused = true
			menu_dialog.find_child("Action_speed", true, false).text = "Speed: %d×" % speed
			menu_dialog.find_child("Action_mute", true, false).text = "Sound: off" if settings.muted else "Sound: on"
			menu_dialog.find_child("Action_effects", true, false).text = "Calm FX: on" if settings.reduced_effects else "Calm FX: off"
			menu_dialog.popup_centered(Vector2i(520, 590))
		"resume_run":
			screen = "game"
			paused = state.phase == "battle"
		"practice":
			request_mission("tutorial")
		"challenges":
			screen = "challenges"
		"next":
			var index := Content.IDS.find(state.encounter)
			if bool(state.config.get("challenge", false)):
				screen = "challenges"
			elif index == 8:
				screen = "ending"
				profile.ending_seen = true
			else:
				start_mission(Content.IDS[index + 1])
		"rally":
			state.rally = not state.rally
			message = "Next formations arriving faster" if state.rally else "Normal formation pace"
		"help":
			paused = true
			help_dialog.dialog_text = str(state.config.decision) + "\n\nMint joints show power carried by touching gears from the gold core. Drives add 25% per level to adjacent troop gears, up to 3x. A stopped gear reads OFF.\n\nGuards absorb fire. Rangers give strong single-target damage. Mortars hit packed enemies, with lower single-target damage.\n\nTap a troop gear to choose its exit. Refit shows the next role and price difference. Equal drives merge by dragging; Undo restores a move or merge.\n\nBosses call escorts as they weaken. Rangers pierce their armor. Keep troops near siege engines to interrupt volleys. After 60 seconds a surviving boss attacks the wall.\n\nMedals: clear, wall intact, and efficiency (save 6 brass and finish under par). Rally sends formations faster when ready."
			help_dialog.popup_centered(Vector2i(540, 800))
		"pause":
			paused = not paused
		"speed":
			speed = 2 if speed == 1 else 1
		"mute":
			settings.muted = not settings.muted
			if settings.muted:
				audio.stop()
		"effects":
			settings.reduced_effects = not settings.reduced_effects
		"save":
			paused = true
			if not persist():
				save_dialog.title = "Save failed · export current progress below"
			else:
				save_dialog.title = "Portable save · copy or paste below"
			save_text.text = Saves.portable(state, settings, profile)
			save_dialog.popup_centered(Vector2i(540, 850))
		"begin":
			if state.phase in ["defeat", "victory"]:
				retry()
			elif state.phase == "ready":
				Battle.start(state)
				message = "Battle live · rearrange to balance your army"
				_tone(740)
			else:
				if not state.config.is_empty():
					act("help")
				else:
					message = "Carapaces shrug off guards and cleave crowds · use rangers" if state.encounter == "iron_trial" else "Shells resist guards · support them with rangers"
		"tutorial", "trial":
			state = Battle.initial(int(state.seed), "iron_trial" if action == "trial" else "tutorial")
			undo_board.clear()
			selected = 1
			paused = false
			message = "54 brass total · no kill income · refit costs the difference" if action == "trial" else "Tutorial · connect your foundry"
		"refit":
			if not state.config.is_empty() and state.config.allowed.size() < 2:
				message = "Rangers unlock at the next foundry"
				return
			var result := Gear.refit(state.board, selected, int(state.gold), state.config.allowed if not state.config.is_empty() else ["guard", "ranger"], state.config.get("costs", Gear.COSTS))
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
			if not piece.is_empty() and piece.kind in Gear.BASE_RATES:
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
	explanation.text = "Copy the save code to export. Paste a code, then Import.\nYour local save resumes the battle paused."
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
					if Saves.write(result.state, result.settings, save_path, save_backend, false, result.profile):
						state = result.state
						settings = result.settings
						profile = result.profile
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
	var timing_row := HBoxContainer.new()
	content.add_child(timing_row)
	for caption in ["Start timings", "Stop + export"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(238, 80)
		timing_row.add_child(button)
		button.pressed.connect(func():
			if caption == "Start timings":
				frame_capture.start()
				message = "Local timings started · resume battle to sample"
				save_dialog.hide()
			else:
				stop_frame_capture()
		)

func _tone(frequency: float) -> void:
	if settings.muted or not is_instance_valid(audio) or DisplayServer.get_name() == "headless":
		return
	audio.stream = sound_bank.tone(frequency)
	audio.play()

func _build_menu() -> void:
	menu_dialog = AcceptDialog.new()
	menu_dialog.title = "Defense menu"
	menu_dialog.ok_button_text = "Close"
	menu_dialog.get_ok_button().custom_minimum_size = Vector2(180, 80)
	add_child(menu_dialog)
	var rows := GridContainer.new()
	rows.columns = 2
	menu_dialog.add_child(rows)
	for item in [["pause", "Resume defense"], ["map", "Journey map"], ["speed", "Change speed"], ["mute", "Toggle sound"], ["effects", "Toggle calm FX"], ["save", "Save / export"], ["help", "Foundry guide"]]:
		var button := Button.new()
		button.name = "Action_" + item[0]
		button.text = item[1]
		button.custom_minimum_size = Vector2(232, 90)
		rows.add_child(button)
		button.pressed.connect(func():
			menu_dialog.hide()
			act(item[0])
		)

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
	var started := Time.get_ticks_usec()
	_draw_content()
	draw_microseconds = Time.get_ticks_usec() - started

func _draw_content() -> void:
	if screen != "game":
		CampaignUI.draw(self)
		if save_failed:
			panel(Rect2(28, 116, 544, 44), INK, RED, 6)
			label_at("Save failed · retry Save or export before closing", Vector2(300, 145), 18, RED, true)
		return
	if not state.config.is_empty():
		CampaignView.draw(self)
		return
	draw_rect(Rect2(0, 0, 600, 1066), Color("10212c"))
	label_at("GEAR BASTION", Vector2(20, 37), 28, GOLD)
	var heading := "IRON TRIAL · 54 BRASS" if state.encounter == "iron_trial" else "THE FIRST FOUNDRY"
	if not state.config.is_empty():
		heading = "%02d · %s" % [int(state.config.index) + 1, state.config.name]
	label_at(heading, Vector2(578, 32) - Vector2(font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, 0), 14, MINT)
	var ui := buttons()
	for key in ["pause", "speed", "mute", "effects", "save"]:
		panel(ui[key], Color("243c48"))
	var labels := {"pause": "Resume" if paused else "Pause", "speed": "%d× speed" % speed,
		"mute": "Muted" if settings.muted else "Sound on", "effects": "Calm FX" if settings.reduced_effects else "Full FX", "save": "Save"}
	for key in labels:
		label_at(labels[key], ui[key].get_center() + Vector2(0, 6), 17, CREAM, true)
	_draw_field()
	if frame_capture.enabled:
		label_at("Local timings · %d frames" % frame_capture.rows.size(), Vector2(300, 234), 15, MINT, true)
	if save_failed:
		panel(Rect2(28, 194, 544, 44), INK, RED, 6)
		label_at("Save failed · retry Save or export before closing", Vector2(300, 222), 18, RED, true)
	_draw_wall()
	panel(Rect2(20, 584, 388, 50), Color("203844"))
	label_at("%d brass   ·   %.2f troops/s" % [int(state.gold), Gear.total_rate(state.board, state.config)], Vector2(34, 617), 21, GOLD)
	panel(ui.begin, MINT if state.phase == "ready" else Color("344e58"))
	var begin_text := "Begin defense" if state.phase == "ready" else "Threat tips"
	if state.phase in ["defeat", "victory"]:
		begin_text = "Retry now"
	label_at(begin_text, ui.begin.get_center() + Vector2(0, 7), 21, INK if state.phase == "ready" else CREAM, true)
	label_at("POWER NETWORK", Vector2(20, 653), 15, MINT)
	_draw_board()
	if not state.config.is_empty():
		for key in ["map", "refit", "help"]:
			panel(ui[key], Color("304754"))
			label_at("Map" if key == "map" else "Refit" if key == "refit" else "Guide", ui[key].get_center() + Vector2(0, 7), 20, CREAM, true)
	else:
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
	elif state.config.is_empty():
		label_at("cap 3×", Vector2(50, 911), 20, GOLD, true)
	var chosen := selected_piece()
	label_at("EXIT", Vector2(550, 686), 17, MINT, true)
	for lane in 3:
		var active: bool = not chosen.is_empty() and chosen.kind in Gear.BASE_RATES and int(chosen.lane) == lane
		panel(ui["gate%d" % lane], Color("385d65") if active else Color("1b323e"), MINT if active else Color.TRANSPARENT)
		label_at("Exit %d" % (lane + 1), ui["gate%d" % lane].get_center() + Vector2(0, 7), 20, CREAM, true)
	var shortened := message
	if shortened.length() > 60:
		shortened = shortened.left(57) + "…"
	label_at(shortened, Vector2(300, 996), 17, MINT, true)
	for key in ["drive", "guard", "ranger", "mortar", "undo"]:
		if not ui.has(key):
			continue
		panel(ui[key], Color("304754"), GOLD if key == "undo" and not undo_board.is_empty() else Color.TRANSPARENT)
		var text := "Undo" if key == "undo" else "%s %d" % [key.capitalize(), state.config.get("costs", Gear.COSTS)[key]]
		var available: bool = state.config.is_empty() or key in ["drive", "undo"] or key in state.config.allowed
		label_at(text if available else "Locked", ui[key].get_center() + Vector2(0, 7), 18 if not state.config.is_empty() else 20, CREAM if available else Color("75858c"), true)
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
		if not state.config.is_empty():
			_draw_campaign_brief()
			return
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
		var wave: Dictionary = Battle.run_waves(state)[wave_index]
		panel(Rect2(145, 164, 310, 28), Color(0.06, 0.12, 0.15, 0.8), Color.TRANSPARENT, 6)
		label_at("WAVE %d / %d · %s" % [int(state.wave), Battle.run_waves(state).size(), wave.name], Vector2(300, 185), 17, CREAM, true)
		var forecast := "Final push · armor + crowd-cleave · use rangers" if state.encounter == "iron_trial" else "Final push · shells resist guard attacks"
		if int(state.wave) < Battle.run_waves(state).size():
			forecast = "Next: " + str(Battle.run_waves(state)[int(state.wave)].name)
		if not state.config.is_empty():
			forecast = "Now: " + str(wave.name) + " · exits " + ",".join(PackedStringArray(wave.lanes.map(func(v): return str(int(v) + 1))))
			if state.boss_spawned:
				forecast = "Boss phase %d · screen the front to stop volleys" % int(state.boss_phase)
				for enemy in state.enemies:
					if enemy.kind in ["captain", "siege", "matriarch"]:
						panel(Rect2(90, 196, 420, 32), INK, GOLD, 5)
						draw_rect(Rect2(96, 220, 408 * maxf(0, float(enemy.hp)) / float(enemy.max_hp), 4), RED)
						label_at("%s · %d HP" % [str(enemy.kind).capitalize(), ceili(float(enemy.hp))], Vector2(300, 216), 18, GOLD, true)
			elif state.phase == "battle":
				panel(buttons().rally, Color("263c46"))
				label_at("Normal pace" if state.rally else "Rally formations", buttons().rally.get_center() + Vector2(0, 7), 18, CREAM, true)
		if state.units.size() >= Battle.UNIT_CAP:
			var producer := Battle.next_producer(state, Gear.rates(state.board, state.config))
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
			label_at("Choose Next or Retry" if not state.config.is_empty() and state.phase == "victory" else "Tap Retry now below", Vector2(300, 401), 20, GOLD, true)
			if not state.config.is_empty() and state.phase == "victory":
				panel(buttons().next, Color("2c5c59"), MINT)
				label_at("Ending" if state.encounter == "camp_09" else "Next foundry", buttons().next.get_center() + Vector2(0, 8), 23, CREAM, true)

func _draw_campaign_brief() -> void:
	label_at(state.config.name, Vector2(300, 242), 29, GOLD, true)
	var line := ""
	var y := 295
	for word in str(state.config.decision).split(" "):
		if font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x > 485:
			label_at(line, Vector2(300, y), 21, CREAM, true)
			y += 31
			line = ""
		line += word + " "
	label_at(line, Vector2(300, y), 21, CREAM, true)
	label_at("%d brass · %s" % [int(state.config.budget), " / ".join(PackedStringArray(state.config.allowed)).capitalize()], Vector2(300, 396), 22, MINT, true)
	label_at("Drag gears, choose exits, then Begin.", Vector2(300, 438), 21, CREAM, true)
	label_at("The board stays live throughout the defense.", Vector2(300, 475), 20, CREAM, true)

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
			if not Gear.cell_allowed(x, y, str(state.encounter), state.config):
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
				valid = Gear.move(state.board, drag_id, cell.x, cell.y, str(state.encounter), state.config).ok
			else:
				valid = Gear.buy(state.board, drag_kind, cell.x, cell.y, int(state.gold), int(state.next_id), str(state.encounter), state.config).ok
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
	elif kind == "mortar":
		draw_circle(center + Vector2(-4, 5), 8, color)
		draw_line(center + Vector2(-4, 5), center + Vector2(10, -9), color, 8)
	else:
		draw_arc(center + Vector2(-6, 0), 12, -1.1, 1.1, 12, color, 3, true)
		draw_line(center + Vector2(0, -11), center + Vector2(0, 11), color, 2)
		draw_line(center + Vector2(-9, 0), center + Vector2(12, 0), color, 2)
	if kind in Gear.BASE_RATES and not ghost:
		var rate := Gear.rate(state.board, int(piece.id), state.config)
		panel(Rect2(center + Vector2(-37, 20), Vector2(74, 23)), INK, Color.TRANSPARENT, 4)
		label_at("%.2f/s" % rate if active else "OFF", center + Vector2(0, 38), 20, MINT if active else RED, true)
		label_at(str(int(piece.lane) + 1), center + Vector2(21, -16), 13, GOLD, true)
	if int(piece.id) == selected and not ghost:
		draw_arc(center, 31, 0, TAU, 48, GOLD, 2, true)

func _draw_unit(unit: Dictionary, friendly: bool) -> void:
	actor_art.draw_unit(self, unit, friendly, Vector2(float(unit.x), float(unit.y)))

func draw_ellipse_shadow(point: Vector2) -> void:
	draw_circle(point + Vector2(1, 6), 9, Color(0.04, 0.09, 0.08, 0.3))
