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
var pad_nodes: Array = []
var tower_nodes: Array = []
var enemy_nodes := {}
var coin_nodes := {}
var bolts: Array = []
var ui: Control
var wallet_label: Label
var integrity_label: Label
var wave_label: Label
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
var stick_ring: Panel
var stick_knob: Panel
var save_clock := 0.0
var audio: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var tone_clock := 0.0
var tone_pitch := 0.0
var save_io: Variant = null
var pickup_flash := 0.0
var last_wallet := 0
var save_problem := false

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
	if paused:
		menu.show()
	save_now()

func mat(color: String, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.8
	m.metallic = metallic
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

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: String, top: float = -1) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = 12
	return mesh(parent, shape, pos, color)

func label3(parent: Node3D, text: String, pos: Vector3, color: String, size: int = 55) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.009
	l.modulate = Color(color)
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	parent.add_child(l)
	return l

func make_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("152b38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5e4e3")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_color = Color("ffe1a0")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23
	camera.position = Vector3(0, 19, 17)
	camera.look_at(Vector3(0, 0, -0.4))
	camera.current = true
	box(self, Vector3(0, -0.42, 0), Vector3(11, 0.8, 22), "557768")
	box(self, Vector3(0, -0.86, 0), Vector3(11.4, 0.4, 22.3), "263e40")
	# Overlapping low-poly road segments create an original winding ridge route.
	for i in 51:
		var z := -10.0 + i * 0.4
		cylinder(self, Vector3(R.road_x(z), 0.03, z), 0.87, 0.1, "ae976e")
	for side in [-1, 1]:
		for i in 13:
			var z := -9.5 + i * 1.6
			var x: float = side * (4.9 + sin(i * 1.7) * 0.2)
			box(self, Vector3(x, 0.12, z), Vector3(0.8, 0.5 + (i % 3) * 0.13, 1.15), "a8c6bd")
			if i % 3 == 0:
				cylinder(self, Vector3(x, 1.0, z), 0.6, 1.8, "244e46", 0.03)
	for i in R.PADS.size():
		var p: Vector2 = R.PADS[i]
		var pad := Node3D.new()
		add_child(pad)
		pad.position = Vector3(p.x, 0, p.y)
		cylinder(pad, Vector3(0, 0.08, 0), 0.95, 0.16, "f0cb71")
		cylinder(pad, Vector3(0, 0.18, 0), 0.82, 0.10, "294c51")
		for j in 8:
			var angle := j * TAU / 8
			box(pad, Vector3(sin(angle) * 0.88, 0.25, cos(angle) * 0.88), Vector3(0.12, 0.13, 0.12), "ffe7aa")
		label3(pad, str(R.COSTS[i]) + " GOLD", Vector3(0, 0.7, 0), "ffdf8b", 52)
		pad_nodes.append(pad)
		var tower := Node3D.new()
		pad.add_child(tower)
		cylinder(tower, Vector3(0, 0.6, 0), 0.54, 1.0, "b48055", 0.42)
		box(tower, Vector3(0, 1.22, 0), Vector3(1.05, 0.23, 0.95), "eee0b1")
		box(tower, Vector3(0, 1.55, 0), Vector3(1.38, 0.16, 0.18), "2c4247")
		box(tower, Vector3(0, 1.55, -0.25), Vector3(0.14, 0.16, 1.0), "e0b96a")
		label3(tower, "BOLT" if i == 0 else "HEAVY", Vector3(0, 2.05, 0), "b7f8e4", 40)
		tower_nodes.append(tower)
	# Refuge gate: the road terminates here, with integrity also in the fixed HUD.
	for x in [-2.1, 2.1]:
		box(self, Vector3(x, 0.85, 8.5), Vector3(1.2, 1.7, 1.1), "c49b63")
		cylinder(self, Vector3(x, 2.0, 8.5), 0.84, 0.8, "34666b", 0.05)
	box(self, Vector3(0, 1.0, 8.65), Vector3(3.1, 1.8, 0.5), "496f6d")
	label3(self, "HEARTH REFUGE", Vector3(0, 2.6, 8.5), "fff0c4", 45)
	label3(self, "ASH COLUMN", Vector3(0, 0.4, -9.8), "ffd0b1", 42)
	avatar = Node3D.new()
	add_child(avatar)
	cylinder(avatar, Vector3(0, 0.44, 0), 0.34, 0.75, "37b5b1", 0.20)
	cylinder(avatar, Vector3(0, 0.95, 0), 0.24, 0.32, "f6d5a0")
	box(avatar, Vector3(0, 1.14, 0), Vector3(0.55, 0.12, 0.4), "e4c377")
	for x in [-0.23, 0.23]:
		box(avatar, Vector3(x, 1.31, 0), Vector3(0.09, 0.3, 0.10), "e4c377")
	box(avatar, Vector3(0.38, 0.6, -0.1), Vector3(0.13, 0.65, 0.13), "eacb75")
	cylinder(avatar, Vector3(0.38, 0.95, -0.1), 0.13, 0.23, "fff2ae")
	label3(avatar, "WARDEN", Vector3(0, 1.8, 0), "c3fff2", 34)
	actors = Node3D.new()
	add_child(actors)

func panel(parent: Control, color: String) -> Panel:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.set_corner_radius_all(22)
	style.border_color = Color("52746f")
	style.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

func text_label(parent: Control, text: String, font_size: int, color: String = "f7edce") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(color))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Control, text: String, action: Callable, font_size: int = 27) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	for key in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("32675f" if key != "disabled" else "34454b")
		if key == "pressed":
			style.bg_color = Color("b08446")
		style.set_corner_radius_all(16)
		style.set_border_width_all(2)
		style.border_color = Color("b6b68b")
		b.add_theme_stylebox_override(key, style)
	b.add_theme_color_override("font_disabled_color", Color("a5b1a9"))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var header := panel(ui, "142e3bef")
	header.name = "Header"
	text_label(header, "HEARTHGUARD", 38).position = Vector2(20, 10)
	text_label(header, "01 / THE COPPER PASS", 20, "86b7af").position = Vector2(22, 60)
	wallet_label = text_label(header, "GOLD  0", 31, "ffda7e")
	wallet_label.position = Vector2(22, 103)
	integrity_label = text_label(header, "REFUGE  8 / 8", 27)
	integrity_label.position = Vector2(245, 108)
	wave_label = text_label(header, "", 23, "c6ded3")
	wave_label.position = Vector2(22, 159)
	pause_button = button(header, "II", toggle_pause, 30)
	guidance = text_label(ui, "", 24)
	guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guidance.add_theme_color_override("font_shadow_color", Color("10242b"))
	guidance.add_theme_constant_override("shadow_outline_size", 8)
	build_button = button(ui, "", build_nearby, 28)
	start_button = button(ui, "DEFEND THE PASS", begin, 29)
	stick = Control.new()
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(stick)
	stick_ring = panel(stick, "193b4777")
	stick_ring.size = Vector2(160, 160)
	stick_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_knob = panel(stick, "8bdacaaa")
	stick_knob.size = Vector2(64, 64)
	stick_knob.position = Vector2(48, 48)
	stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = panel(ui, "102d3bfa")
	menu.name = "Pause"
	text_label(menu, "PASS WATCH / PAUSED", 33).position = Vector2(24, 20)
	journal = text_label(menu, "", 24, "c1ded0")
	journal.position = Vector2(24, 77)
	button(menu, "RESUME", toggle_pause).set_meta("row", 0)
	sound_button = button(menu, "", toggle_sound)
	sound_button.set_meta("row", 1)
	effects_button = button(menu, "", toggle_effects)
	effects_button.set_meta("row", 2)
	button(menu, "SAVE / TRANSFER", open_transfer).set_meta("row", 3)
	text_label(menu, "Retry restocks this battle.\nYour results and settings stay.", 23, "a5c0b8").position = Vector2(24, 555)
	menu.hide()
	terminal = panel(ui, "142e3bf5")
	terminal_title = text_label(terminal, "", 36, "ffdc88")
	terminal_title.position = Vector2(24, 24)
	terminal_detail = text_label(terminal, "", 24)
	terminal_detail.position = Vector2(24, 88)
	button(terminal, "RETRY PASS", retry).position = Vector2(24, 228)
	button(terminal, "PAUSE / LOG", toggle_pause).position = Vector2(24, 336)
	terminal.hide()
	transfer = panel(ui, "112c3bfc")
	text_label(transfer, "LOCAL SAVE TRANSFER", 31).position = Vector2(22, 20)
	code_edit = TextEdit.new()
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code_edit.add_theme_font_size_override("font_size", 20)
	transfer.add_child(code_edit)
	notice = text_label(transfer, "Copy the code somewhere safe.", 22)
	notice.position = Vector2(22, 395)
	button(transfer, "COPY", copy_code).set_meta("transfer", 0)
	button(transfer, "PASTE", paste_code).set_meta("transfer", 1)
	button(transfer, "IMPORT", import_code).set_meta("transfer", 2)
	button(transfer, "BACK", close_transfer).set_meta("transfer", 3)
	transfer.hide()

func layout() -> void:
	if ui == null:
		return
	var size := get_viewport().get_visible_rect().size
	# At a 360dp-wide display the 720 logical canvas has 96px minimum controls.
	var w := size.x
	var h := size.y
	var head := ui.get_node("Header") as Panel
	head.position = Vector2(18, 22)
	head.size = Vector2(w - 36, 207)
	pause_button.position = Vector2(w - 144, 15)
	pause_button.size = Vector2(96, 96)
	guidance.position = Vector2(12, h - 326)
	guidance.size = Vector2(w - 24, 76)
	stick.position = Vector2(42, h - 205)
	build_button.position = Vector2(w - 435, h - 204)
	build_button.size = Vector2(405, 112)
	start_button.position = Vector2(70, h - 202)
	start_button.size = Vector2(w - 140, 112)
	for p in [menu, terminal, transfer]:
		p.position = Vector2((w - 620) / 2, 270 if p != terminal else h * 0.34)
		p.size = Vector2(620, 660 if p != terminal else 466)
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
			child.position = Vector2(22 + (n % 2) * 295, 445 + (n / 2) * 105)
			child.size = Vector2(281, 96)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		back()
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
	var size := get_viewport().get_visible_rect().size
	if pressed and stick_id == -1 and point.x < size.x * 0.48 and point.y > 250:
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
		var h := get_viewport().get_visible_rect().size.y
		stick.position = Vector2(42, h - 205)

func begin() -> void:
	state.phase = "playing"
	stop_move()
	save_now()
	refresh()

func build_nearby() -> void:
	if paused:
		return
	var pad := R.nearby_pad(state)
	if R.buy(state, pad):
		tone(380, 0.22)
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
	if settings.sound:
		tone(660, 0.15)

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
	code_edit.text = S.encode(state, profile, settings, 0)
	notice.text = "Local code only. Import replaces this save."
	transfer.show()

func close_transfer() -> void:
	transfer.hide()
	code_edit.release_focus()
	menu.show()
	paused = true
	refresh()

func copy_code() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		code_edit.select_all()
		notice.text = "Select and copy the code on this device."
		return
	DisplayServer.clipboard_set(code_edit.text)
	code_edit.select_all()
	notice.text = "Code copied." if DisplayServer.clipboard_get() == code_edit.text else "Clipboard unavailable. Select and copy the code."

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
		notice.text = "Invalid code. Current save kept."
		return
	if not S.write(decoded.state, decoded.profile, decoded.settings, S.PATH, save_io, true):
		notice.text = "Storage failed. Current save kept."
		return
	state = decoded.state
	profile = decoded.profile
	settings = decoded.settings
	close_transfer()
	sync_world(0)
	refresh()

func _physics_process(delta: float) -> void:
	if not paused and state.phase == "playing":
		var before: String = state.phase
		var events := R.tick(state, input_vector, delta)
		for e in events:
			if e.kind == "shot":
				make_bolt(e.pad, e.z)
				if settings.sound:
					tone(165 + e.pad * 70, 0.04)
			elif e.kind == "pickup":
				pickup_flash = 0.45
				tone(800, 0.09)
			elif e.kind == "leak":
				tone(90, 0.24)
		if before == "playing" and state.phase != "playing":
			R.finish(state, profile)
			save_now()
			tone(520 if state.phase == "victory" else 120, 0.5)
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
	wallet_label.text = "GOLD  " + str(int(state.wallet)) + ("  +" if pickup_flash > 0 else "")
	integrity_label.text = "REFUGE  " + str(int(state.integrity)) + " / 8"
	var remaining: int = R.TOTAL - state.killed.size() - state.leaked.size()
	wave_label.text = "%d / 20 STOPPED    •    %d INCOMING" % [state.killed.size(), remaining]
	if save_problem:
		wave_label.text = "SAVE FAILED • Pause to export a local code"
	journal.text = "Wins %d  /  Best %d stopped  /  Attempts %d" % [profile.wins, profile.best_kills, profile.attempts]
	sound_button.text = "SOUND  " + ("ON" if settings.sound else "OFF")
	effects_button.text = "REDUCED EFFECTS  " + ("ON" if settings.reduced_effects else "OFF")
	start_button.visible = state.phase == "ready" and not paused
	stick.visible = state.phase == "playing" and not paused
	build_button.visible = state.phase == "playing" and not paused
	var nearby := R.nearby_pad(state)
	var build_disabled := true
	if nearby >= 0:
		if state.pads[nearby] == 1:
			build_button.text = "TOWER ACTIVE"
		else:
			build_button.text = "BUILD %s • %d" % ["BOLT" if nearby == 0 else "HEAVY", R.COSTS[nearby]]
			build_disabled = state.wallet < R.COSTS[nearby]
	else:
		build_button.text = "APPROACH A PAD"
	build_button.disabled = build_disabled
	if state.phase == "ready":
		guidance.text = "Move with your left thumb.\nGather 5 loose gold → build a Bolt tower."
	elif state.pads[0] == 0:
		guidance.text = "Gather the gold trail, then approach the 5 pad.\nTap Build to spend. Crossing a pad spends nothing."
	elif state.pads[1] == 0:
		guidance.text = "Collect gold beside the road.\n15 gold builds HEAVY downstream: double damage."
	else:
		guidance.text = "Two towers hold the pass.\nHeavy stops armored raiders near the refuge."
	terminal.visible = state.phase in ["victory", "defeat"] and not paused
	if terminal.visible:
		terminal_title.text = "THE HEARTH HOLDS" if state.phase == "victory" else "REFUGE BREACHED"
		terminal_detail.text = "%d stopped  •  %d leaked  •  %.0fs\n%s\nRetry restocks gold and resets towers." % [state.killed.size(), state.leaked.size(), state.time, "No-leak seal earned!" if state.phase == "victory" and state.leaked.is_empty() else "Build coverage before raiders reach the gate."]
	guidance.visible = not paused and not terminal.visible
	pause_button.disabled = transfer.visible

func sync_world(dt: float) -> void:
	avatar.position = Vector3(state.x, 0.15, state.z)
	if not settings.reduced_effects and input_vector.length() > 0.1 and not paused:
		avatar.rotation.z = sin(state.time * 13) * 0.07
	else:
		avatar.rotation.z = 0
	for i in 2:
		tower_nodes[i].visible = state.pads[i] == 1
		(pad_nodes[i].get_child(10) as Label3D).visible = state.pads[i] == 0
	var alive := {}
	for e in state.enemies:
		var id := int(e.id)
		alive[id] = true
		if not enemy_nodes.has(id):
			var n := Node3D.new()
			actors.add_child(n)
			cylinder(n, Vector3(0, 0.36, 0), 0.27, 0.65, "d47051" if id < 10 else "7c788a", 0.18)
			cylinder(n, Vector3(0, 0.79, 0), 0.22, 0.28, "e6ac83")
			cylinder(n, Vector3(0, 0.98, 0), 0.32, 0.2, "653b48", 0.08)
			var hp := label3(n, "", Vector3(0, 1.35, 0), "ffd8a7", 32)
			hp.name = "Health"
			enemy_nodes[id] = n
		var n: Node3D = enemy_nodes[id]
		n.position = Vector3(R.road_x(e.z), 0.14, e.z)
		(n.get_node("Health") as Label3D).text = str(int(e.hp))
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
			var coin := cylinder(n, Vector3(0, 0.45, 0), 0.26, 0.10, "ffce55")
			coin.rotation_degrees.x = 75
			label3(n, str(int(c.value)), Vector3(0, 1, 0), "ffe092", 35)
			coin_nodes[id] = n
		var n: Node3D = coin_nodes[id]
		n.position = Vector3(c.x, 0.18 + (0.08 * sin(state.time * 4 + id) if not settings.reduced_effects else 0.0), c.z)
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
			bolts[i].node.position = bolts[i].from.lerp(bolts[i].to, 1 - bolts[i].life / 0.18)
	pickup_flash = maxf(0, pickup_flash - dt)

func make_bolt(pad: int, z: float) -> void:
	var p: Vector2 = R.PADS[pad]
	var from := Vector3(p.x, 1.6, p.y)
	var to := Vector3(R.road_x(z), 0.8, z)
	var bolt := box(actors, from, Vector3(0.13, 0.13, 0.65), "fff1af")
	bolt.look_at(to)
	bolts.append({"node": bolt, "life": 0.18, "from": from, "to": to})

func setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	audio = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.12
	audio.stream = generator
	audio.volume_db = -18
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
	audio_playback = null
