extends Node2D
## Expandable battlefield and continuously interactive socket board.

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
const WindowLayout = preload("res://scripts/window_layout.gd")
const Foundry3D = preload("res://scripts/presentation/foundry.gd")
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
var layout := WindowLayout.new()
var usable := Rect2()
var safe_area_override := Rect2()
var dialog_scrolls: Dictionary = {}
var presentation_view: SubViewport
var presentation: Node3D

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
	abandon_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	abandon_dialog.dialog_text = "Starting another foundry replaces this active run.\nYour cleared foundries and medals stay saved."
	abandon_dialog.ok_button_text = "Start new defense"
	abandon_dialog.get_ok_button().custom_minimum_size = Vector2(210, 80)
	abandon_dialog.get_cancel_button().custom_minimum_size = Vector2(180, 80)
	add_child(abandon_dialog)
	abandon_dialog.confirmed.connect(func(): start_mission(pending_mission, pending_challenge))
	help_dialog = AcceptDialog.new()
	help_dialog.title = "Foundry guide"
	var guide := Label.new()
	guide.name = "GuideText"
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.custom_minimum_size.x = 280
	scroll_content(help_dialog, guide)
	help_dialog.get_ok_button().custom_minimum_size = Vector2(160, 80)
	add_child(help_dialog)
	_build_menu()
	# AcceptDialog rewrites button minima from its theme during every layout.
	var dialog_theme := Theme.new()
	dialog_theme.set_constant("buttons_min_width", "AcceptDialog", 160)
	dialog_theme.set_constant("buttons_min_height", "AcceptDialog", 80)
	for dialog in [save_dialog, menu_dialog, help_dialog, abandon_dialog]:
		dialog.theme = dialog_theme
	get_viewport().size_changed.connect(refresh_layout)
	refresh_layout()
	presentation_view = SubViewport.new()
	presentation_view.name = "OriginalFoundry3D"
	presentation_view.own_world_3d = true
	presentation_view.render_target_update_mode = SubViewport.UPDATE_DISABLED if DisplayServer.get_name() == "headless" else SubViewport.UPDATE_ALWAYS
	presentation_view.msaa_3d = Viewport.MSAA_2X
	add_child(presentation_view)
	presentation = Foundry3D.new()
	presentation_view.add_child(presentation)
	presentation_view.size = render_dimensions()
	presentation.build(layout,Vector2(presentation_view.size))
	reset_presentation()
	queue_redraw()

func suspend_battle() -> void:
	paused = state.phase == "battle"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		drag_id = -1
		drag_kind = ""
		dragging = false
		active_touch = -1
		persist()
		suspend_battle()
		queue_redraw()
	if what == NOTIFICATION_APPLICATION_RESUMED and state.phase == "battle":
		suspend_battle()
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
	refresh_layout()
	clock += delta
	fx_sound_clock += delta
	if not paused and screen == "game":
		advance(minf(delta, 0.2) * speed)
	if is_instance_valid(presentation):
		if paused or screen != "game" or state.phase != "battle":
			presentation.sync(state,[])
		presentation.step(delta*speed,paused or screen != "game",bool(settings.reduced_effects))
		presentation.drag_preview(pointer - Vector2(0,42),selected_piece() if drag_kind == "" else Gear.piece(0,drag_kind,0,0),dragging)
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
		var render_events: Array = []
		Battle.tick(state, Battle.STEP, render_events)
		if is_instance_valid(presentation):
			presentation.reduced = bool(settings.reduced_effects)
			presentation.sync(state,render_events,Battle.STEP)
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
	reset_presentation()
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
		suspend_battle()
		message = "Paused and saved · Back again opens the journey"
	elif screen == "game":
		suspend_battle()
		screen = "map"
	else:
		screen = "map"
		message = "Progress saved · use Home to leave"
	persist()
	queue_redraw()

func _capture_render_frame() -> void:
	var eligible: bool = screen == "game" and state.phase == "battle" and not paused and not save_dialog.visible and not abandon_dialog.visible and not help_dialog.visible and not menu_dialog.visible
	var tag := {"friendly": state.units.size(), "enemies": state.enemies.size(), "encounter": state.encounter, "reduced_effects": settings.reduced_effects}
	if frame_capture.enabled and is_instance_valid(presentation_view):
		tag["draw_calls"] = presentation_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		tag["primitives"] = presentation_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		tag["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		tag["render_size"] = [presentation_view.size.x,presentation_view.size.y]
	frame_capture.sample(Time.get_ticks_usec(), eligible, tag, draw_microseconds)

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
		show_dialog(abandon_dialog)
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
	reset_presentation()
	persist()

func cell_center(x: int, y: int) -> Vector2:
	return board_origin() + Vector2(x + 0.5, y + 0.5) * CELL

func board_origin() -> Vector2:
	return layout.board.position

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - board_origin().x) / CELL), floori((point.y - board_origin().y) / CELL))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if active_touch >= 0:
				return
			active_touch = event.index
			press(to_local(event.position))
		else:
			if active_touch != event.index:
				return
			active_touch = -1
			if event.canceled:
				drag_id = -1
				drag_kind = ""
				dragging = false
			else:
				release(to_local(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index != active_touch:
			return
		pointer = to_local(event.position)
		dragging = pointer.distance_to(drag_start) > 12
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == -1:
			return
		if event.pressed:
			press(to_local(event.position))
		else:
			release(to_local(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (drag_id >= 0 or drag_kind != ""):
		pointer = to_local(event.position)
		dragging = pointer.distance_to(drag_start) > 12
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		handle_back()

func buttons() -> Dictionary:
	return CampaignUI.buttons(self) if screen != "game" else layout.game_buttons(self)

func hitboxes() -> Dictionary:
	return buttons()

func cancel_drag() -> void:
	drag_start = Vector2(-1000, -1000)
	drag_id = -1
	drag_kind = ""
	dragging = false
	active_touch = -1

func refresh_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var next := Rect2(Vector2.ZERO, viewport_size)
	if safe_area_override.has_area():
		next = next.intersection(safe_area_override)
	elif OS.has_feature("android"):
		var physical := Rect2(DisplayServer.get_display_safe_area())
		if physical.has_area():
			var inverse := get_viewport().get_screen_transform().affine_inverse()
			next = next.intersection(Rect2(inverse * physical.position, inverse.basis_xform(physical.size)))
	if not next.has_area():
		next = Rect2(Vector2.ZERO, viewport_size)
	if next == usable:
		return
	usable = next
	# Below the normal minimum, shrink uniformly rather than clip sockets or controls.
	var factor := minf(1, minf(usable.size.x / 600, usable.size.y / 1000))
	position = usable.position
	scale = Vector2.ONE * factor
	layout.arrange(usable.size / factor)
	if is_instance_valid(presentation):
		presentation_view.size = render_dimensions()
		presentation.fit(layout,Vector2(presentation_view.size))
		presentation.sync_board(state,true)
	cancel_drag()
	for dialog in [save_dialog, menu_dialog, help_dialog, abandon_dialog]:
		if is_instance_valid(dialog) and dialog.visible:
			fit_dialog(dialog)
	queue_redraw()

func render_dimensions() -> Vector2i:
	var density := clampf(get_viewport().get_final_transform().get_scale().x * scale.x,1,2)
	return Vector2i(layout.size * density)

func reset_presentation() -> void:
	if is_instance_valid(presentation):
		presentation.hydrate(state,paused or screen != "game")

func show_dialog(dialog: AcceptDialog) -> void:
	cancel_drag()
	# A hidden window can retain a position from a previous, wider viewport.
	fit_dialog(dialog)
	dialog.popup()
	fit_dialog(dialog)

func fit_dialog(dialog: AcceptDialog) -> void:
	var extent := usable.size - Vector2(24, 64)
	var desired := Vector2(minf(620, extent.x), minf(850, extent.y))
	if dialog == abandon_dialog:
		desired.y = minf(300, extent.y)
	elif dialog == menu_dialog:
		desired.y = minf(620, extent.y)
	elif dialog == help_dialog:
		desired.y = minf(800, extent.y)
	if dialog_scrolls.has(dialog):
		var scroll: ScrollContainer = dialog_scrolls[dialog]
		scroll.custom_minimum_size = Vector2(maxf(200, desired.x - 36), maxf(100, desired.y - 140))
	# Embedded window decorations extend above the client rectangle.
	dialog.size = Vector2i(desired)
	dialog.position = Vector2i(usable.position + (usable.size - Vector2(dialog.size)) / 2 + Vector2(0, 12))

func scroll_content(dialog: AcceptDialog, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	scroll.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_scrolls[dialog] = scroll

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
			suspend_battle()
			screen = "map"
		"menu":
			suspend_battle()
			menu_dialog.find_child("Action_speed", true, false).text = "Speed: %d×" % speed
			menu_dialog.find_child("Action_mute", true, false).text = "Sound: off" if settings.muted else "Sound: on"
			menu_dialog.find_child("Action_effects", true, false).text = "Calm FX: on" if settings.reduced_effects else "Calm FX: off"
			show_dialog(menu_dialog)
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
			suspend_battle()
			help_dialog.find_child("GuideText", true, false).text = str(state.config.get("decision", "Connect gears to the brass core; balance guards and rangers.")) + "\n\nMint joints show power carried by touching gears from the gold core. Drives add 25% per level to adjacent troop gears, up to 3x. A stopped gear reads OFF.\n\nGuards absorb fire. Rangers give strong single-target damage. Mortars hit packed enemies, with lower single-target damage.\n\nTap a troop gear to choose its exit. Refit shows the next role and price difference. Equal drives merge by dragging; Undo restores a move or merge.\n\nBosses call escorts as they weaken. Rangers pierce their armor. Keep troops near siege engines to interrupt volleys. After 60 seconds a surviving boss attacks the wall.\n\nMedals: clear, wall intact, and efficiency (save 6 brass and finish under par). Rally sends formations faster when ready."
			show_dialog(help_dialog)
		"pause":
			paused = state.phase == "battle" and not paused
		"speed":
			speed = 2 if speed == 1 else 1
		"mute":
			settings.muted = not settings.muted
			if settings.muted:
				audio.stop()
		"effects":
			settings.reduced_effects = not settings.reduced_effects
		"save":
			suspend_battle()
			if not persist():
				save_dialog.title = "Save failed · export current progress below"
			else:
				save_dialog.title = "Portable save · copy or paste below"
			save_text.text = Saves.portable(state, settings, profile)
			show_dialog(save_dialog)
		"begin":
			if state.phase in ["defeat", "victory"]:
				retry()
			elif state.phase == "ready":
				paused = false
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
			reset_presentation()
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
	content.custom_minimum_size = Vector2(280, 540)
	scroll_content(save_dialog, content)
	var explanation := Label.new()
	explanation.text = "Copy the save code to export. Paste a code, then Import.\nYour local save resumes the battle paused."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(explanation)
	save_text = TextEdit.new()
	save_text.custom_minimum_size = Vector2(280, 320)
	save_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(save_text)
	var row := HBoxContainer.new()
	content.add_child(row)
	for label in ["Copy save", "Paste", "Import"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(80, 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
						suspend_battle()
						save_failed = false
						message = "Imported · Resume when ready" if paused else "Imported · Begin when ready" if state.phase == "ready" else "Imported · result restored"
						reset_presentation()
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
		button.custom_minimum_size = Vector2(110, 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	scroll_content(menu_dialog, rows)
	for item in [["pause", "Resume defense"], ["map", "Journey map"], ["speed", "Change speed"], ["mute", "Toggle sound"], ["effects", "Toggle calm FX"], ["save", "Save / export"], ["help", "Foundry guide"]]:
		var button := Button.new()
		button.name = "Action_" + item[0]
		button.text = item[1]
		button.custom_minimum_size = Vector2(130, 90)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if is_instance_valid(presentation_view):
		draw_texture_rect(presentation_view.get_texture(),Rect2(Vector2.ZERO,layout.size),false)
	if screen == "game":
		CampaignView.draw(self)
	else:
		CampaignUI.draw(self)
