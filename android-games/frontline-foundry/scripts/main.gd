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

func mat(color: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color).srgb_to_linear()
	m.roughness = 0.85
	return m

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat(color)
	n.position = pos
	parent.add_child(n)
	return n

func box(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, color)

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius * 0.9
	shape.height = height
	shape.radial_segments = 12
	return mesh(parent, shape, pos, color)

func label3(parent: Node3D, text: String, pos: Vector3, color: String, size: int = 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.012
	l.modulate = Color(color)
	l.outline_size = 9
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	parent.add_child(l)
	return l

func soldier(parent: Node3D, color: String, commander: bool = false) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	cylinder(n, Vector3(0, 0.45, 0), 0.27, 0.65, color)
	cylinder(n, Vector3(0, 0.92, 0), 0.23, 0.27, "f5dcac")
	cylinder(n, Vector3(0, 1.08, 0), 0.31, 0.16, color)
	box(n, Vector3(-0.16, 0.1, 0), Vector3(0.19, 0.2, 0.3), "223b4b")
	box(n, Vector3(0.16, 0.1, 0), Vector3(0.19, 0.2, 0.3), "223b4b")
	var weapon := box(n, Vector3(0.35, 0.6, -0.3), Vector3(0.16, 0.17, 0.85), "e6f7e6")
	weapon.name = "Weapon"
	if commander:
		cylinder(n, Vector3(0, 0.02, 0), 0.48, 0.06, "ffda79")
		label3(n, "YOU", Vector3(0, 1.75, 0), "ffe9a2", 34)
	return n

func make_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("142b3b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0f5f0")
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -25, 0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 18, 15)
	camera.look_at(Vector3(0, 0, 0.8))
	camera.current = true
	box(self, Vector3(0, -0.3, 0), Vector3(10.4, 0.6, 14), "78999b")
	box(self, Vector3(0, -0.65, 0), Vector3(10.7, 0.3, 14.3), "32495c")
	box(self, Vector3(0, 0.01, -3.5), Vector3(9.6, 0.04, 6.4), "a8bab2")
	box(self, Vector3(0, 0.03, 3.2), Vector3(1.3, 0.08, 5.7), "b4c9bc")
	for side in [-1, 1]:
		for i in 4:
			box(self, Vector3(side * (1.6 + i * 0.85), 0.35, -0.35), Vector3(0.8, 0.6, 0.6), "e6d4aa")
		for i in 6:
			box(self, Vector3(side * 4.9, 0.3, -5.6 + i * 2.2), Vector3(0.3, 0.6, 0.5), "c3e3d8")
	box(self, Vector3(0, 0.65, 5.5), Vector3(2.5, 1.3, 1.1), "2c747e")
	box(self, Vector3(0, 1.4, 5.5), Vector3(2.8, 0.3, 1.4), "45b7a5")
	label3(self, "FOUNDRY HQ", Vector3(0, 2.1, 5.5), "d5fff2", 30)
	# Starter sentry protects bootstrap income but cannot defeat the armored siege.
	cylinder(self, Vector3(0, 0.45, 0.6), 0.35, 0.8, "526778")
	box(self, Vector3(0, 0.95, 0.25), Vector3(0.18, 0.22, 0.8), "f7d77c")
	label3(self, "SENTRY", Vector3(0, 1.7, 0.6), "fff0af", 28)
	for i in 2:
		var p: Vector2 = R.PADS[i]
		box(self, Vector3(p.x, 0.07, p.y), Vector3(2.2, 0.14, 1.8), "f1d58b")
		box(self, Vector3(p.x, 0.17, p.y), Vector3(1.95, 0.10, 1.55), "276d70")
		pad_labels.append(label3(self, "", Vector3(p.x, 1.55, p.y - 0.5), "ffe8a8", 40))
		var station := Node3D.new()
		add_child(station)
		station.position = Vector3(p.x, 0.2, p.y)
		box(station, Vector3(0, 0.5, 0), Vector3(1.5, 0.8, 0.7), "36ae9e")
		box(station, Vector3(0, 0.95, 0), Vector3(1.7, 0.12, 0.9), "f9df91")
		for j in 3:
			box(station, Vector3(-0.45 + j * 0.45, 1.15, -0.1), Vector3(0.12, 0.12, 0.6), "e6f7e6")
		station_nodes.append(station)
	actors = Node3D.new()
	add_child(actors)
	avatar = soldier(actors, "ffc966", true)
	for i in 4:
		var n: Node3D
		if i < 3:
			n = soldier(actors, "34b5a4")
		else:
			n = Node3D.new()
			actors.add_child(n)
			box(n, Vector3(0, 0.45, 0), Vector3(1.15, 0.65, 1.6), "38a99a")
			for x in [-0.65, 0.65]:
				box(n, Vector3(x, 0.22, 0), Vector3(0.3, 0.4, 1.8), "233a48")
			var weapon := box(n, Vector3(0, 0.95, -0.5), Vector3(0.2, 0.2, 1.5), "ffe3a3")
			weapon.name = "Weapon"
		var l := label3(n, "", Vector3(0, 1.5 if i < 3 else 1.8, 0), "bff9e4", 29)
		l.name = "Status"
		recruit_nodes.append(n)

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
	camera.size = maxf(19.8, 12.0 * h / w)
	head.position = Vector2(18, 18)
	head.size = Vector2(w - 36, 207)
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
	profile = decoded.profile
	settings = decoded.settings
	close_transfer()
	sync_world(0)
	refresh()

func _physics_process(delta: float) -> void:
	if not paused and state.phase == "playing":
		var events := R.tick(state, input_vector, delta)
		for e in events:
			event_log.append({"time": state.time, "event": e})
			if e.kind == "shot":
				make_bolt(e)
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
	avatar.position = Vector3(state.x, 0.1, state.z)
	avatar.rotation.z = sin(state.time * 12) * 0.06 if input_vector.length() > 0.1 and not settings.reduced_effects and not paused else 0
	for i in 2:
		station_nodes[i].visible = state.pads[i]
		pad_labels[i].text = ("RIFLES" if i == 0 else "ROVER") + ("\nSUPPLIED" if state.pads[i] else "\n" + str(R.COSTS[i]) + " SCRAP")
	for r in state.recruits:
		var n: Node3D = recruit_nodes[int(r.id)]
		n.visible = r.phase != "fallen"
		n.position = Vector3(r.x, 0.1, r.z)
		n.get_node("Weapon").visible = r.phase != "waiting"
		(n.get_node("Status") as Label3D).text = {"waiting": "NEEDS RIFLE" if r.role == "rifle" else "NEEDS CANNON", "equipping": "ARMING!", "deploying": "TO FRONT", "fighting": str(int(r.hp)) + " HP", "fallen": ""}[r.phase]
	var alive := {}
	for e in state.enemies:
		var id := int(e.id)
		alive[id] = true
		if not enemy_nodes.has(id):
			var n := Node3D.new()
			actors.add_child(n)
			box(n, Vector3(0, 0.55, 0), Vector3(0.8, 0.8, 0.9) if e.armored else Vector3(0.5, 0.65, 0.5), "a94e50" if not e.armored else "824f73")
			cylinder(n, Vector3(0, 1.02, 0), 0.3, 0.2, "ef9b73")
			for x in [-0.3, 0.3]:
				box(n, Vector3(x, 0.15, 0), Vector3(0.2, 0.3, 0.45), "583a50")
			var l := label3(n, "", Vector3(0, 1.5, 0), "ffe2c4", 30)
			l.name = "Health"
			enemy_nodes[id] = n
		var n: Node3D = enemy_nodes[id]
		n.position = Vector3(e.x, 0.1, e.z)
		(n.get_node("Health") as Label3D).text = ("ARMOR " if e.armored else "") + str(int(ceil(e.hp)))
	for id in enemy_nodes.keys():
		if not alive.has(id):
			enemy_nodes[id].queue_free()
			enemy_nodes.erase(id)
	var drops := {}
	for c in state.coins:
		var id := int(c.id)
		drops[id] = true
		if not coin_nodes.has(id):
			var n := Node3D.new()
			actors.add_child(n)
			var coin := cylinder(n, Vector3(0, 0.4, 0), 0.3, 0.15, "ffd36c")
			coin.rotation_degrees.x = 70
			label3(n, "+" + str(int(c.value)), Vector3(0, 1, 0), "ffe594", 35)
			coin_nodes[id] = n
		coin_nodes[id].position = Vector3(c.x, 0.12, c.z)
	for id in coin_nodes.keys():
		if not drops.has(id):
			coin_nodes[id].queue_free()
			coin_nodes.erase(id)
	for i in range(bolts.size() - 1, -1, -1):
		bolts[i].life -= dt
		if bolts[i].life <= 0:
			bolts[i].node.queue_free()
			bolts.remove_at(i)
		else:
			bolts[i].node.position = bolts[i].from.lerp(bolts[i].to, 1 - bolts[i].life / 0.16)

func make_bolt(e: Dictionary) -> void:
	var from := Vector3(e.from[0], 0.9, e.from[1])
	var to := Vector3(e.to[0], 0.8, e.to[1])
	var bolt := box(actors, from, Vector3(0.18 if e.owner == "vehicle" else 0.1, 0.1, 0.55), "ffe5a0" if e.owner == "commander" else "9bffe2")
	if not from.is_equal_approx(to):
		bolt.look_at(to)
	bolts.append({"node": bolt, "life": 0.16, "from": from, "to": to})

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
