extends Node3D
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
var state := R.fresh()
var profile := R.profile()
var settings := {"sound": true, "reduced_effects": false}
var paused := false
var input_vector := Vector2.ZERO
var stick_id := -1
var stick_origin := Vector2.ZERO
var avatar: Node3D
var camera: Camera3D
var actors: Node3D
var recruit_nodes: Array = []
var pad_labels: Array = []
var station_nodes: Array = []
var enemy_nodes := {}
var coin_nodes := {}
var bolts: Array = []
var ui: Control
var head: Panel
var wallet_label: Label
var status_label: Label
var wave_label: Label
var queue_label: Label
var guidance: Label
var build_button: Button
var start_button: Button
var pause_button: Button
var menu: Panel
var terminal: Panel
var terminal_title: Label
var terminal_detail: Label
var journal: Label
var transfer: Panel
var code_edit: TextEdit
var notice: Label
var sound_button: Button
var effects_button: Button
var stick: Control
var stick_knob: Panel
var save_clock := 0.0
var audio: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var tone_clock := 0.0
var tone_pitch := 0.0
var save_io: Variant = null
var save_problem := false
var event_log: Array = []
var presentation: Node3D
const Outpost = preload("res://scripts/presentation/outpost.gd")

func _ready() -> void:
	var saved := S.read()
	if saved.ok:
		state = saved.state
		profile = saved.profile
		settings = saved.settings
		paused = state.phase == "playing"
	make_world()
	make_ui()
	get_viewport().size_changed.connect(layout)
	setup_audio()
	layout()
	sync_world(0)
	refresh()
	menu.visible = paused
	save_now()

func make_world() -> void:
	if presentation != null:
		presentation.set_process(false)
		remove_child(presentation)
		presentation.queue_free()
	presentation = Outpost.new()
	add_child(presentation)
	presentation.build(state)
	camera = presentation.camera
	actors = presentation

func style(bg: String, border: String = "426779", radius: int = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg)
	s.border_color = Color(border)
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	return s

func panel(parent: Node, color: String = "152e43") -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", style(color))
	parent.add_child(p)
	return p

func label(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int = 28, color: String = "e8f3e4") -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(color))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 27)
	b.add_theme_stylebox_override("normal", style("28656c", "63c8b0"))
	b.add_theme_stylebox_override("hover", style("347c80", "e6d895"))
	b.add_theme_stylebox_override("pressed", style("a57f47", "ffe09c"))
	b.add_theme_stylebox_override("disabled", style("304550", "506070"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	head = panel(ui)
	label(head, "FRONTLINE FOUNDRY", Vector2(20, 10), Vector2(530, 36), 30, "ffe1a0")
	wallet_label = label(head, "", Vector2(20, 48), Vector2(520, 40), 31, "ffdf8c")
	status_label = label(head, "", Vector2(20, 88), Vector2(630, 35), 27)
	wave_label = label(head, "", Vector2(20, 124), Vector2(640, 35), 25)
	queue_label = label(head, "", Vector2(20, 159), Vector2(640, 36), 24, "a8efdc")
	pause_button = button(head, "II", toggle_pause)
	guidance = label(ui, "", Vector2.ZERO, Vector2.ZERO, 27)
	guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guidance.add_theme_color_override("font_color", Color("344b3e"))
	build_button = button(ui, "", build_nearby)
	start_button = button(ui, "BREAK THE SIEGE", begin)
	stick = Control.new()
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(stick)
	var ring := panel(stick, "203f54aa")
	ring.size = Vector2(160, 160)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_knob = panel(stick, "e6d596aa")
	stick_knob.size = Vector2(64, 64)
	stick_knob.position = Vector2(48, 48)
	stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = panel(ui)
	label(menu, "FIELD LOG  /  PAUSED", Vector2(24, 20), Vector2(560, 40), 32, "ffe1a0")
	journal = label(menu, "", Vector2(24, 70), Vector2(570, 40), 25)
	var row := 0
	for spec in [["RESUME", toggle_pause], ["SOUND  ON", toggle_sound], ["REDUCED EFFECTS  OFF", toggle_effects], ["SAVE / TRANSFER", open_transfer]]:
		var b := button(menu, spec[0], spec[1])
		b.set_meta("row", row)
		if row == 1:
			sound_button = b
		if row == 2:
			effects_button = b
		row += 1
	menu.hide()
	var journey_button := button(menu, "BEGIN CAMPAIGN", enter_campaign)
	journey_button.position = Vector2(24, 550)
	journey_button.size = Vector2(572, 96)
	terminal = panel(ui)
	terminal_title = label(terminal, "", Vector2(24, 24), Vector2(570, 55), 36, "ffe1a0")
	terminal_detail = label(terminal, "", Vector2(24, 85), Vector2(570, 175), 28)
	var retry_button := button(terminal, "RETRY SIEGE", retry)
	retry_button.position = Vector2(24, 285)
	terminal.hide()
	transfer = panel(ui)
	label(transfer, "LOCAL SAVE CODE", Vector2(22, 18), Vector2(570, 40), 32)
	code_edit = TextEdit.new()
	code_edit.add_theme_font_size_override("font_size", 23)
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	transfer.add_child(code_edit)
	notice = label(transfer, "", Vector2(22, 385), Vector2(576, 55), 22, "ffe1a0")
	row = 0
	for spec in [["EXPORT", copy_code], ["PASTE", paste_code], ["IMPORT", import_code], ["CLOSE", close_transfer]]:
		var b := button(transfer, spec[0], spec[1])
		b.set_meta("transfer", row)
		row += 1
	transfer.hide()

func layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var w := view.x
	var h := view.y
	presentation.fit(view)
	head.position = Vector2(18, 18)
	head.size = Vector2(w - 36, 155)
	head.add_theme_stylebox_override("panel", style("253c35ed", "61765c"))
	queue_label.hide()
	wave_label.position.y = 119
	wave_label.add_theme_font_size_override("font_size", 23)
	pause_button.position = Vector2(w - 150, 15)
	pause_button.size = Vector2(96, 96)
	guidance.position = Vector2(12, h - 295)
	guidance.size = Vector2(w - 24, 80)
	stick.position = Vector2(35, h - 205)
	build_button.position = Vector2(w - 425, h - 204)
	build_button.size = Vector2(395, 112)
	start_button.position = Vector2(70, h - 202)
	start_button.size = Vector2(w - 140, 112)
	for p in [menu, terminal, transfer]:
		p.position = Vector2((w - 620) / 2, 245 if p != terminal else h * 0.34)
		p.size = Vector2(620, 660 if p != terminal else 410)
	for child in menu.get_children():
		if child.has_meta("row"):
			child.position = Vector2(24, 126 + int(child.get_meta("row")) * 105)
			child.size = Vector2(572, 96)
	for child in terminal.get_children():
		if child is Button:
			child.size = Vector2(572, 96)
	code_edit.position = Vector2(22, 80)
	code_edit.size = Vector2(576, 300)
	for child in transfer.get_children():
		if child.has_meta("transfer"):
			var n := int(child.get_meta("transfer"))
			child.position = Vector2(22 + (n % 2) * 295, 445 + int(n / 2) * 105)
			child.size = Vector2(281, 96)
	stop_move()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		back()
	# GUI still receives emulated mouse events, including TextEdit's touch focus.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if paused or state.phase != "playing":
		return
	var point := Vector2.ZERO
	var pointer := -2
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		point = event.position
		pointer = event.index
		pressed = event.pressed
		released = not pressed
	elif event is InputEventScreenDrag:
		point = event.position
		pointer = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		pointer = -3
		pressed = event.pressed
		released = not pressed
	elif event is InputEventMouseMotion:
		point = event.position
		pointer = -3
	else:
		return
	var view := get_viewport().get_visible_rect().size
	if pressed and stick_id == -1 and point.x < view.x * 0.38 and point.y > 250:
		stick_id = pointer
		stick_origin = point
		stick.position = point - Vector2(80, 80)
	if pointer == stick_id:
		if released:
			stop_move()
		else:
			input_vector = ((point - stick_origin) / 65).limit_length()
			stick_knob.position = Vector2(48, 48) + input_vector * 50

func stop_move() -> void:
	stick_id = -1
	input_vector = Vector2.ZERO
	if stick != null:
		stick_knob.position = Vector2(48, 48)
		stick.position = Vector2(35, get_viewport().get_visible_rect().size.y - 205)

func begin() -> void:
	state.phase = "playing"
	stop_move()
	save_now()
	refresh()

func enter_campaign() -> void:
	var C = load("res://scripts/campaign_rules.gd")
	var D = load("res://scripts/definitions.gd")
	var saved := S.read()
	var c: Dictionary = saved.career if saved.ok else C.career()
	c.legacy_state = state.duplicate(true)
	c.legacy_profile = profile.duplicate(true)
	if S.write(C.fresh(D.mission(0)), profile, settings, S.PATH, save_io, false, c):
		get_tree().change_scene_to_file("res://boot.tscn")
	else:
		save_problem = true
		refresh()

func build_nearby() -> void:
	if not paused and R.buy(state, R.nearby_pad(state)):
		tone(450, 0.25)
		save_now()
		refresh()

func retry() -> void:
	state = R.fresh()
	make_world()
	layout()
	state.phase = "playing"
	paused = false
	stop_move()
	terminal.hide()
	menu.hide()
	save_now()
	sync_world(0)
	refresh()

func toggle_pause() -> void:
	if transfer.visible:
		close_transfer()
		return
	paused = not paused
	stop_move()
	menu.visible = paused
	save_now()
	refresh()

func back() -> void:
	if transfer.visible:
		close_transfer()
	else:
		toggle_pause()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		paused = true
		stop_move()
		menu.show()
		save_now()
		refresh()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()

func toggle_sound() -> void:
	settings.sound = not settings.sound
	save_now()
	refresh()

func toggle_effects() -> void:
	settings.reduced_effects = not settings.reduced_effects
	save_now()
	refresh()

func save_now() -> bool:
	var saved := S.write(state, profile, settings, S.PATH, save_io)
	save_problem = not saved
	return saved

func open_transfer() -> void:
	stop_move()
	paused = true
	var saved := S.read()
	code_edit.text = S.encode(state, profile, settings, 0, true, saved.career if saved.ok else {})
	notice.text = "Local code. Import replaces this save after validation."
	transfer.show()

func close_transfer() -> void:
	transfer.hide()
	code_edit.release_focus()
	menu.show()
	paused = true
	refresh()

func copy_code() -> void:
	# Export always regenerates from progress, never copies an edited invalid code.
	var saved := S.read()
	code_edit.text = S.encode(state, profile, settings, 0, true, saved.career if saved.ok else {})
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		code_edit.select_all()
		notice.text = "Clipboard unavailable. Select and copy the code."
		return
	DisplayServer.clipboard_set(code_edit.text)
	code_edit.select_all()
	notice.text = "Checking clipboard..."
	await get_tree().create_timer(0.08, true, false, true).timeout
	notice.text = "Code copied." if DisplayServer.clipboard_get() == code_edit.text else "Copy unconfirmed. Select and copy the code."

func paste_code() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		notice.text = "Clipboard unavailable. Current code kept."
		return
	var copied := DisplayServer.clipboard_get()
	if copied.is_empty():
		notice.text = "Clipboard empty. Current code kept."
	else:
		code_edit.text = copied
		notice.text = "Pasted. Import checks before replacing."

func import_code() -> void:
	var decoded := S.decode(code_edit.text)
	if not decoded.ok:
		notice.text = "Invalid code. Entire current save kept."
		return
	if not S.write(decoded.state, decoded.profile, decoded.settings, S.PATH, save_io, true, decoded.career):
		notice.text = "Storage failed. Entire current save kept."
		return
	if decoded.state.catalog == 2:
		get_tree().change_scene_to_file("res://boot.tscn")
		return
	state = decoded.state
	make_world()
	layout()
	profile = decoded.profile
	settings = decoded.settings
	close_transfer()
	sync_world(0)
	refresh()

func _physics_process(delta: float) -> void:
	if not paused and state.phase == "playing":
		var events := R.tick(state, input_vector, delta)
		presentation.queue_events(events)
		for e in events:
			event_log.append({"time": state.time, "event": e})
			if e.kind == "shot":
				tone(170 if e.owner == "vehicle" else 340, 0.04)
			elif e.kind == "pickup":
				tone(800, 0.12)
			elif e.kind == "equip":
				tone(500, 0.16)
		if state.phase != "playing":
			R.finish(state, profile)
			save_now()
			tone(600 if state.phase == "victory" else 100, 0.5)
		save_clock += delta
		if save_clock >= 1:
			save_clock = 0
			save_now()
	sync_world(delta if not paused else 0)
	refresh()
	fill_audio()

func refresh() -> void:
	if wallet_label == null:
		return
	wallet_label.text = "SCRAP  %d" % state.wallet
	status_label.text = "COMMANDER %d    /    HQ %d" % [state.hp, state.hq]
	wave_label.text = "SIEGE  %d / 10 STOPPED   •   %.0fs" % [state.killed.size(), state.time]
	if save_problem:
		wave_label.text = "SAVE FAILED • Pause and export your code"
	var deployed := 0
	for r in state.recruits:
		if r.phase in ["deploying", "fighting"]:
			deployed += 1
	queue_label.text = "EQUIPPED %d / 4    •    ON FRONT %d" % [state.consumed[0] + state.consumed[1], deployed]
	journal.text = "Wins %d  /  Best %d stopped  /  Attempts %d" % [profile.wins, profile.best_kills, profile.attempts]
	sound_button.text = "SOUND  " + ("ON" if settings.sound else "OFF")
	effects_button.text = "REDUCED EFFECTS  " + ("ON" if settings.reduced_effects else "OFF")
	start_button.visible = state.phase == "ready" and not paused
	stick.visible = state.phase == "playing" and not paused
	build_button.visible = state.phase == "playing" and not paused
	var nearby := R.nearby_pad(state)
	var build_disabled := true
	if nearby >= 0:
		if state.pads[nearby]:
			build_button.text = "STATION SUPPLIED"
		elif nearby == 1 and not state.pads[0]:
			build_button.text = "SUPPLY RIFLES FIRST"
		else:
			build_button.text = "SUPPLY %s • %d" % ["RIFLES" if nearby == 0 else "ROVER", R.COSTS[nearby]]
			build_disabled = state.wallet < R.COSTS[nearby]
	else:
		build_button.text = "APPROACH A PAD"
	build_button.disabled = build_disabled
	if state.phase == "ready":
		guidance.text = "Left thumb moves. Your weapon fires automatically.\n8 scrap equips rifles → earn 14 → equip the rover."
	elif not state.pads[0]:
		guidance.text = "Move to the left 8 pad. Tap Supply to arm recruits.\nCrossing a pad never spends scrap."
	elif not state.pads[1]:
		guidance.text = "Armed recruits hold the front. Collect gold scrap.\nReturn to the 14 rover pad before armored drones."
	else:
		guidance.text = "Rover cannon pierces armor. Help hold the line.\nStop at least 8 of 10 drones; protect HQ and yourself."
	terminal.visible = state.phase in ["victory", "defeat"] and not paused
	if terminal.visible:
		terminal_title.text = "SIEGE BROKEN" if state.phase == "victory" else "FOUNDRY LOST"
		terminal_detail.text = "%s\n%d stopped • %d escaped • %.0fs\nRetry restores supplies and recruits.\nYour record and settings stay." % [state.cause, state.killed.size(), state.leaked.size(), state.time]
	guidance.visible = not paused and not terminal.visible
	pause_button.disabled = transfer.visible

func sync_world(dt: float) -> void:
	if presentation != null:
		presentation.sync(state, paused, settings.reduced_effects, dt)
		avatar = presentation.units.get("commander")

func setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	audio = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.12
	audio.stream = generator
	audio.volume_db = -20
	add_child(audio)
	audio.play()
	audio_playback = audio.get_stream_playback()

func tone(pitch: float, duration: float) -> void:
	if settings.sound:
		tone_pitch = pitch
		tone_clock = duration

func fill_audio() -> void:
	if audio_playback == null:
		return
	for i in audio_playback.get_frames_available():
		var value := 0.0
		if settings.sound and tone_clock > 0:
			value = sin(tone_clock * tone_pitch * TAU) * minf(tone_clock * 20, 0.6)
			tone_clock -= 1.0 / 22050
		audio_playback.push_frame(Vector2(value, value))

func _exit_tree() -> void:
	if audio != null:
		audio.stop()
