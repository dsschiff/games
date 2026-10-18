extends Node3D
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const Copy = preload("res://scripts/copy_confirm.gd")
const CAMERA_PORTRAIT_ASPECT := 1080.0 / 2400.0
var copy_service := Copy.new()
var state := R.fresh()
var settings := {"sound": true, "reduced_effects": false}
var paused := false
var files: Variant = null
var save_message := ""
var drag_index := -1
var anchor := Vector2.ZERO
var anchor_x := 0.0
var mouse_drag := false
var camera: Camera3D
var actors: Dictionary = {}
var gate_labels: Array[Label3D] = []
var bullet_nodes: Array[MeshInstance3D] = []
var footprint: MeshInstance3D
var side_label: Label3D
var final_label: Label3D
var hud: Control
var title: Label
var info: Label
var warning: Label
var notice: Label
var pause_button: Button
var overlay: PanelContainer
var overlay_title: Label
var overlay_body: Label
var start_button: Button
var resume_button: Button
var retry_button: Button
var sound_button: Button
var effects_button: Button
var transfer: PanelContainer
var code_box: TextEdit
var transfer_status: Label
var tone: AudioStreamPlayer
var previous_crew := 3

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	var saved := S.read(S.PATH, files)
	if saved.ok:
		state = saved.state
		settings = saved.settings
		paused = state.phase == "playing"
	build_world()
	build_ui()
	get_viewport().size_changed.connect(layout)
	layout()
	refresh()
	persist()

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if color.a < 1:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node

func ball(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node

func label3(parent: Node3D, text: String, pos: Vector3, size: int = 64) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font_size = size
	node.pixel_size = 0.014
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	node.outline_size = 12
	parent.add_child(node)
	node.position = pos
	return node

func person(infected: bool = false) -> Node3D:
	var p := Node3D.new()
	var suit := Color("7f8962") if infected else Color("35b6b1")
	box(p, Vector3(0, 0.43, 0), Vector3(0.30, 0.42, 0.25), suit)
	ball(p, Vector3(0, 0.84, 0), 0.19, Color("ad69a3") if infected else Color("ffb44f"))
	for x in [-0.09, 0.09]:
		box(p, Vector3(x, 0.15, 0), Vector3(0.10, 0.3, 0.12), Color("263c4d"))
	if infected:
		for x in [-0.18, 0.12]:
			ball(p, Vector3(x, 0.97, 0), 0.14, Color("b6c85d"))
		box(p, Vector3(0, 0.58, 0.22), Vector3(0.55, 0.12, 0.17), suit)
	else:
		box(p, Vector3(0.15, 0.57, -0.29), Vector3(0.13, 0.12, 0.55), Color("263c4d"))
		box(p, Vector3(0, 0.44, -0.14), Vector3(0.12, 0.23, 0.025), Color("ffdc8a"))
	return p

func build_world() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 13, 9)
	camera.look_at(Vector3(0, 0, -16))
	camera.current = true
	frame_camera()
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-50, -20, 0)
	sun.light_energy = 1.25
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("153641")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a1c4ce")
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	box(self, Vector3(0, -0.4, -13), Vector3(9.4, 0.6, 44), Color("536a72"))
	box(self, Vector3(-5.2, -0.25, -13), Vector3(0.55, 1.0, 44), Color("84998e"))
	box(self, Vector3(5.2, -0.25, -13), Vector3(0.55, 1.0, 44), Color("84998e"))
	for i in 20:
		var marker := box(self, Vector3(0, -0.08, -i * 2.5), Vector3(0.12, 0.04, 1.0), Color("dec18a"))
		actors["mark" + str(i)] = marker
		for x in [-5.2, 5.2]:
			box(self, Vector3(x, 1.3, -i * 3.0), Vector3(0.13, 2.6, 0.15), Color("84998e"))
	for x in [-5.3, 5.3]:
		box(self, Vector3(x, 1.9, -13), Vector3(0.10, 0.10, 42), Color("e4b968"))
	box(self, Vector3(0, -0.05, 0.7), Vector3(8.8, 0.02, 0.14), Color("efbc66"))
	label3(self, "RESCUE LINE", Vector3(0, 0.05, 1.4), 27)
	for i in R.CAP:
		var p := person()
		add_child(p)
		actors["crew" + str(i)] = p
	for e in state.enemies:
		var p := person(true)
		add_child(p)
		actors["enemy" + str(e.id)] = p
	for i in 2:
		var gate := Node3D.new()
		add_child(gate)
		for x in [-0.9, 0.9]:
			box(gate, Vector3(x, 0.85, 0), Vector3(0.15, 1.7, 0.22), Color("ffc875"))
		box(gate, Vector3(0, 1.65, 0), Vector3(2.0, 0.12, 0.22), Color("ffc875"))
		box(gate, Vector3(0, 0.035, 0), Vector3(1.8, 0.05, 0.25), Color("f0a4a0"))
		gate_labels.append(label3(gate, "", Vector3(0, 2.0, 0), 78))
		actors["gate" + str(i)] = gate
	var crane := Node3D.new()
	add_child(crane)
	crane.position = Vector3(-2.65, 0, -12)
	box(crane, Vector3(0, 0.3, 0), Vector3(1.85, 0.6, 2), Color("b87949"))
	box(crane, Vector3(-0.7, 2.0, 0), Vector3(0.24, 3.4, 0.4), Color("cd9959"))
	box(crane, Vector3(0, 3.5, 0), Vector3(2.1, 0.25, 0.4), Color("cd9959"))
	ball(crane, Vector3(0.2, 1.9, 0), 0.82, Color("916891"))
	for x in [-0.5, 0.5]:
		ball(crane, Vector3(x, 2.65, 0), 0.3, Color("bacb70"))
	side_label = label3(crane, "", Vector3(0, 4.2, 0), 37)
	actors.side = crane
	var final := Node3D.new()
	add_child(final)
	box(final, Vector3(0, 0.6, 0), Vector3(2.4, 1.2, 1), Color("d47e51"))
	for x in [-0.8, 0.0, 0.8]:
		ball(final, Vector3(x, 1.5, 0), 0.45, Color("a77e9c"))
	final_label = label3(final, "", Vector3(0, 2.5, 0), 42)
	actors.final = final
	footprint = box(self, Vector3.ZERO, Vector3.ONE, Color(1, 0.82, 0.25, 0.30))
	for i in 180:
		var b := box(self, Vector3.ZERO, Vector3(0.055, 0.055, 0.42), Color("a2fff0"))
		b.material_override = material(Color("a2fff0"), true)
		bullet_nodes.append(b)
	tone = AudioStreamPlayer.new()
	add_child(tone)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	for i in 1300:
		bytes.append(int(128 + sin(float(i) * 0.18) * 22.0 * (1.0 - float(i) / 1300)))
	wav.data = bytes
	tone.stream = wav
	tone.volume_db = -16

func text(parent: Node, value: String, size: int = 25) -> Label:
	var l := Label.new()
	l.text = value
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Node, value: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = Vector2(0, 88)
	b.add_theme_font_size_override("font_size", 27)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17313e")
	style.border_color = Color("d6ab69")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", style)
	hud.add_child(p)
	return p

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	title = text(hud, "DEAD RUN  /  CANAL BRIDGE", 31)
	info = text(hud, "", 26)
	warning = text(hud, "", 26)
	warning.modulate = Color("ffdb88")
	notice = text(hud, "", 25)
	pause_button = button(hud, "II", toggle_pause)
	overlay = panel()
	var scroll := ScrollContainer.new()
	overlay.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)
	overlay_title = text(col, "", 36)
	overlay_body = text(col, "", 25)
	start_button = button(col, "START RESCUE", start_run)
	resume_button = button(col, "RESUME", toggle_pause)
	retry_button = button(col, "RETRY BRIDGE", start_run)
	sound_button = button(col, "", func(): settings.sound = not settings.sound; persist(); refresh())
	effects_button = button(col, "", func(): settings.reduced_effects = not settings.reduced_effects; persist(); refresh())
	button(col, "SAVE / TRANSFER", open_transfer)
	transfer = panel()
	# A fixed Control keeps long portable codes from growing the panel off-screen.
	var tcol := Control.new()
	transfer.add_child(tcol)
	text(tcol, "PORTABLE RESCUE", 32).set_meta("transfer_row", "title")
	text(tcol, "Export copies your journey and parked bridge. Import replaces both only after checked storage.", 23).set_meta("transfer_row", "help")
	code_box = TextEdit.new()
	code_box.custom_minimum_size = Vector2(0, 160)
	code_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code_box.virtual_keyboard_enabled = true
	code_box.add_theme_font_size_override("font_size", 22)
	code_box.text_changed.connect(func(): copy_service.cancel())
	tcol.add_child(code_box)
	button(tcol, "EXPORT / COPY", export_code).set_meta("transfer_row", 0)
	button(tcol, "PASTE", paste_code).set_meta("transfer_row", 1)
	button(tcol, "IMPORT", import_code).set_meta("transfer_row", 2)
	transfer_status = text(tcol, "", 22)
	button(tcol, "CLOSE TRANSFER", close_transfer).set_meta("transfer_row", 3)
	transfer.visible = false

func camera_base_fov() -> float:
	return 58.0

func frame_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	var expansion := maxf(1.0, size.x / maxf(1.0, size.y) / CAMERA_PORTRAIT_ASPECT)
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = camera_base_fov()
	# Wider displays retain native portrait vertical coverage and reveal more sides.
	# Always derive from the authored FOV, never the previous resize result.
	if expansion > 1.0:
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(camera_base_fov()) * 0.5) * expansion))

func layout() -> void:
	var v := get_viewport().get_visible_rect().size
	title.position = Vector2(20, 26)
	title.size = Vector2(v.x - 140, 50)
	info.position = Vector2(18, 92)
	info.size = Vector2(v.x - 36, 80)
	warning.position = Vector2(24, 178)
	warning.size = Vector2(v.x - 48, 76)
	notice.position = Vector2(24, v.y - 135)
	notice.size = Vector2(v.x - 48, 110)
	pause_button.position = Vector2(v.x - 112, 20)
	pause_button.size = Vector2(92, 92)
	overlay.position = Vector2(maxf(18, (v.x - 650) / 2), 265)
	overlay.size = Vector2(minf(v.x - 36, 650), maxf(320, minf(760, v.y - 300)))
	transfer.position = Vector2(maxf(12, (v.x - 680) / 2), 80)
	transfer.size = Vector2(minf(v.x - 24, 680), maxf(500, v.y - 110))
	var tw := transfer.size.x - 44
	var th := transfer.size.y - 36
	code_box.position = Vector2(0, 150)
	code_box.size = Vector2(tw, maxf(160, th - 490))
	transfer_status.position = Vector2(0, th - 306)
	transfer_status.size = Vector2(tw, 88)
	for child in code_box.get_parent().get_children():
		if not child.has_meta("transfer_row"):
			continue
		var row: Variant = child.get_meta("transfer_row")
		if row is String:
			child.position = Vector2(0, 0 if row == "title" else 55)
			child.size = Vector2(tw, 55 if row == "title" else 86)
		else:
			child.position = Vector2(int(row) % 2 * (tw + 12) / 2, th - 200 + (int(row) / 2) * 100)
			child.size = Vector2((tw - 12) / 2, 88)
	frame_camera()

func start_run() -> void:
	state = R.fresh()
	state.phase = "playing"
	paused = false
	drag_index = -1
	persist()
	refresh()

func persist() -> bool:
	var okay := S.write(state, settings, S.PATH, files)
	save_message = "" if okay else "SAVE FAILED — progress is only in memory. Free storage and retry Save."
	return okay

func toggle_pause() -> void:
	paused = not paused
	drag_index = -1
	mouse_drag = false
	persist()
	refresh()

func open_transfer() -> void:
	paused = true
	drag_index = -1
	transfer.visible = true
	transfer_status.text = ""
	persist()
	refresh()

func close_transfer() -> void:
	copy_service.cancel()
	transfer.visible = false
	code_box.release_focus()
	refresh()

func export_code() -> void:
	var code := S.encode(state, settings, int(S.read(S.PATH, files).revision))
	code_box.text = code
	copy_service.begin(code)
	transfer_status.text = copy_service.feedback

func paste_code() -> void:
	copy_service.cancel()
	if DisplayServer.get_name() == "headless":
		transfer_status.text = "Clipboard is empty or unavailable."
		return
	code_box.text = DisplayServer.clipboard_get()
	transfer_status.text = "Pasted. Review and Import." if not code_box.text.is_empty() else "Clipboard is empty or unavailable."

func import_code() -> void:
	copy_service.cancel()
	var d := S.decode(code_box.text)
	if not d.ok:
		transfer_status.text = "Invalid code. Current rescue unchanged."
		return
	if not S.write(d.state, d.settings, S.PATH, files, true):
		transfer_status.text = "Import could not be stored. Current rescue unchanged."
		return
	state = d.state
	settings = d.settings
	paused = true
	transfer_status.text = "Imported and stored. Close, then Resume."
	save_message = ""
	refresh()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()
	if what == NOTIFICATION_APPLICATION_PAUSED:
		paused = true
		drag_index = -1
		persist()
		refresh()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		paused = true
		persist()
		refresh()

func back() -> void:
	if transfer.visible:
		close_transfer()
	else:
		toggle_pause()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if state.phase != "playing" or paused or transfer.visible:
		return
	var v := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and drag_index == -1 and event.position.y > 250 and event.position.y < v.y - 130:
			drag_index = event.index
			anchor = event.position
			anchor_x = state.x
		elif not event.pressed and event.index == drag_index:
			drag_index = -1
	elif event is InputEventScreenDrag and event.index == drag_index:
		R.steer(state, anchor_x + (event.position.x - anchor.x) / v.x * 9.0)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_drag = event.pressed and event.position.y > 250 and event.position.y < v.y - 130
		anchor = event.position
		anchor_x = state.x
	elif event is InputEventMouseMotion and mouse_drag and event.device != InputEvent.DEVICE_ID_EMULATION:
		R.steer(state, anchor_x + (event.position.x - anchor.x) / v.x * 9.0)

func _physics_process(_delta: float) -> void:
	if copy_service.poll(_delta) and transfer.visible:
		transfer_status.text = copy_service.feedback
	var before: String = state.phase
	var crossed: bool = state.gates[0].crossed
	if not paused:
		R.step(state)
	if state.phase != before or state.gates[0].crossed != crossed or (state.phase == "playing" and not paused and state.tick % 120 == 0):
		persist()
	if settings.sound and not paused and state.phase == "playing" and state.tick % 30 == 0:
		tone.play()
	refresh()

func refresh() -> void:
	if hud == null:
		return
	info.text = "CREW %d / %d    •    BRIDGE %d%%\nCrane %d    |    Rescue line leaks %d" % [state.crew, R.CAP, state.tick * 100 / R.END_TICK, state.side_hp, state.leaks]
	notice.text = save_message if not save_message.is_empty() else state.notice
	warning.text = "Drag sideways • gold footprint shows contact width"
	for g in state.gates:
		if not g.crossed and g.z < 5:
			warning.text = "GATE %+d in %.1fs • overlap gold footprint = cross" % [g.value, g.z / R.SPEED]
	for e in state.enemies:
		if state.tick >= e.born and not e.resolved and e.z < 4:
			warning.text = "INFECTED AT LINE • contact -2, escaped -1 crew"
	if state.tick > 2160 and state.final_hp > 0:
		warning.text = "FINAL BLOCKADE %d • aim centre before it reaches the line" % state.final_hp
	overlay.visible = paused or state.phase != "playing"
	overlay_title.text = {"ready": "OPEN THE CANAL BRIDGE", "playing": "RESCUE PAUSED", "victory": "CONVOY EVACUATED", "defeat": "RESCUE LOST"}[state.phase]
	overlay_body.text = ("One finger drags the crew sideways. Fire is automatic.\nEach bullet adds 1 to a gate (max +6); overlapping it applies the signed result once.\nCrane: 120 hits earns 3 riggers, but fire there leaves approaching infected unsuppressed. Clear the final centre barricade and survive 50 seconds.") if state.phase == "ready" else state.notice + "\n" + save_message
	start_button.visible = state.phase == "ready"
	resume_button.visible = paused
	retry_button.visible = state.phase in ["victory", "defeat"]
	sound_button.text = "SOUND: " + ("ON" if settings.sound else "OFF")
	effects_button.text = "REDUCED EFFECTS: " + ("ON" if settings.reduced_effects else "OFF")
	for i in R.CAP:
		var p: Node3D = actors["crew" + str(i)]
		p.visible = i < state.crew
		if p.visible:
			var q := R.offset(i, state.crew)
			p.position = Vector3(state.x + q.x, 0.04, q.y)
			if not settings.reduced_effects:
				p.position.y += absf(sin(state.tick * 0.18 + i)) * 0.045
	for e in state.enemies:
		var p: Node3D = actors["enemy" + str(e.id)]
		p.visible = state.tick >= e.born and not e.resolved
		p.position = Vector3(e.x, 0.04, -e.z)
		p.rotation.y = sin(state.tick * 0.1 + e.id) * 0.12 if not settings.reduced_effects else 0.0
	for i in 2:
		var g: Dictionary = state.gates[i]
		var p: Node3D = actors["gate" + str(i)]
		p.visible = not g.crossed
		p.position = Vector3(g.x, 0, -g.z)
		gate_labels[i].text = "%+d" % g.value
		gate_labels[i].modulate = Color("7cffe2") if g.value >= 0 else Color("ff9b91")
	actors.side.visible = state.side_hp > 0
	side_label.text = "SPORE CRANE\n%d / 120\n+3 RIGGERS" % state.side_hp
	actors.final.visible = state.tick >= 2160 and state.final_hp > 0
	actors.final.position = Vector3(0, 0, -(20.0 - maxf(0, state.tick - 2160) / 60.0 * R.SPEED))
	final_label.text = "EVAC BARRICADE\n%d" % state.final_hp
	footprint.position = Vector3(state.x, 0.015, 0.45)
	footprint.scale = Vector3(R.half_width(state.crew) * 2, 0.025, 1.6)
	for i in bullet_nodes.size():
		bullet_nodes[i].visible = i < state.bullets.size()
		if i < state.bullets.size():
			bullet_nodes[i].position = Vector3(state.bullets[i].x, 0.58, -state.bullets[i].z)
	for i in 20:
		actors["mark" + str(i)].position.z = -fposmod(i * 2.5 - state.tick / 60.0 * R.SPEED, 45)
