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
var world: Node3D
var presenter: Node3D
var safe_rect := Rect2()
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
var campaign_profile := preload("res://scripts/campaign_rules.gd").profile()
var expedition_button: Button
var world_label_clearance := preload("res://scripts/presentation/label_clearance.gd").new()

func _ready() -> void:
	var saved := S.read()
	if saved.ok:
		state = saved.state
		profile = saved.profile
		settings = saved.settings
		campaign_profile = saved.campaign
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
	if state.schema == 1:
		expedition_button = button(menu, "OPEN EXPEDITION • KEEP LEGACY PASS", open_campaign, 22)
		expedition_button.position = Vector2(24, 650)
		expedition_button.size = Vector2(572, 96)
		menu.size.y = 770
		layout()
	save_now()

func open_campaign() -> void:
	var C = preload("res://scripts/campaign_rules.gd")
	var Cat = preload("res://scripts/campaign_catalog.gd")
	campaign_profile.legacy_snapshot = state.duplicate(true)
	var next: Dictionary = campaign_profile.get("parked", {})
	if next.is_empty():
		next = C.fresh(Cat.definition(mini(campaign_profile.clears.size(), 9)))
	if S.write(next, profile, settings, S.PATH, save_io, false, campaign_profile):
		route_reload()

func route_reload() -> void:
	if get_parent().has_method("reload_saved"):
		get_parent().call_deferred("reload_saved")

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
	if world != null:
		remove_child(world)
		world.queue_free()
	world = preload("res://scripts/presentation/settlement.gd").new()
	add_child(world)
	presenter = world
	presenter.build(state)
	camera = presenter.camera
	avatar = presenter.units.commander
	actors = world
	enemy_nodes.clear()
	coin_nodes.clear()
	pad_nodes.clear()
	tower_nodes.clear()
	bolts.clear()
	if ui != null:
		layout()

func panel(parent: Control, color: String) -> Panel:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.set_corner_radius_all(22)
	style.border_color = Color("52746f")
	style.set_border_width_all(2)
	style.shadow_color = Color("10212a66")
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
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
		style.bg_color = Color("427c6b" if key == "hover" else ("32675f" if key != "disabled" else "34454b"))
		if key == "pressed":
			style.bg_color = Color("b08446")
		style.set_corner_radius_all(16)
		style.set_border_width_all(2)
		style.border_color = Color("b6b68b")
		style.shadow_color = Color("0d202544")
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(key, style)
	b.add_theme_color_override("font_disabled_color", Color("a5b1a9"))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func joystick_disk(diameter: int, fill: Color, border: Color, shadow_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(diameter / 2)
	style.corner_detail = 16
	style.anti_aliasing = true
	style.set_border_width_all(1)
	style.border_color = border
	style.shadow_color = Color(0, 0, 0, shadow_alpha)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	return style

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
	var crest := TextureRect.new()
	crest.name = "Crest"
	crest.texture = preload("res://art/hearth-crest.svg")
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.position = Vector2(21, 10)
	crest.size = Vector2(40, 40)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(crest)
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
	stick_ring = Panel.new()
	stick.add_child(stick_ring)
	stick_ring.add_theme_stylebox_override("panel", joystick_disk(160, Color(.08, .12, .14, .055), Color(.90, .96, .92, .18), .045))
	stick_ring.size = Vector2(160, 160)
	stick_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_knob = Panel.new()
	stick.add_child(stick_knob)
	stick_knob.add_theme_stylebox_override("panel", joystick_disk(64, Color(.88, .95, .90, .50), Color(.95, 1, .97, .45), .08))
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

func _process(_delta: float) -> void:
	update_control_clearance()

func update_control_clearance() -> void:
	if presenter == null or stick == null or camera == null:
		return
	var obstacle := Rect2()
	if stick_id != -1 and stick.is_visible_in_tree() and not paused:
		obstacle = stick_ring.get_global_rect()
	world_label_clearance.update(presenter.essential_labels(), camera, obstacle, presenter.field_rect)

func usable_rect() -> Rect2:
	var area := get_viewport().get_visible_rect()
	if OS.get_name() == "Android":
		var native := DisplayServer.get_display_safe_area()
		if native.size.x > 0 and native.size.y > 0:
			area = get_viewport().get_final_transform().affine_inverse() * Rect2(native)
	return area.grow(-18)

func layout() -> void:
	if ui == null:
		return
	stop_move()
	safe_rect = usable_rect()
	var w := safe_rect.size.x
	var h := safe_rect.size.y
	var origin := safe_rect.position
	var head := ui.get_node("Header") as Panel
	head.position = origin
	head.size = Vector2(w, 184)
	(head.get_child(0) as Label).add_theme_font_size_override("font_size", 32)
	(head.get_child(0) as Label).position = Vector2(72, 8)
	(head.get_child(1) as Label).position = Vector2(72, 50)
	wallet_label.position = Vector2(22, 88)
	wallet_label.add_theme_font_size_override("font_size", 27)
	integrity_label.position = Vector2(245, 92)
	integrity_label.add_theme_font_size_override("font_size", 25)
	wave_label.position = Vector2(22, 143)
	pause_button.position = Vector2(w - 110, 12)
	pause_button.size = Vector2(96, 96)
	guidance.position = origin + Vector2(0, h - 232)
	guidance.size = Vector2(w, 90)
	stick.position = origin + Vector2(20, h - 360)
	build_button.position = origin + Vector2(w - 405, h - 120)
	build_button.size = Vector2(405, 112)
	start_button.position = origin + Vector2(40, h - 120)
	start_button.size = Vector2(w - 80, 112)
	for p in [menu, terminal, transfer]:
		p.size = Vector2(620, 660 if p != terminal else 466)
		p.position = origin + Vector2((w - p.size.x) / 2, (h - p.size.y) / 2)
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
	if expedition_button != null:
		menu.size.y = 770
		menu.position.y = origin.y + (h - menu.size.y) / 2
		(expedition_button as Button).position = Vector2(24, 650)
		(expedition_button as Button).size = Vector2(572, 96)
	if presenter != null:
		presenter.fit(Rect2(origin + Vector2(10, 210), Vector2(w - 20, h - 480)))

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
	if pressed and stick_id == -1 and point.x < size.x * 0.48 and point.y > safe_rect.position.y + 200 and point.y < safe_rect.end.y - 135:
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
		stick.position = Vector2(safe_rect.position.x + 20, h - 378)

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
	var saved := S.write(state, profile, settings, S.PATH, save_io, false, campaign_profile)
	save_problem = not saved
	return saved

func open_transfer() -> void:
	stop_move()
	paused = true
	code_edit.text = S.encode(state, profile, settings, 0, true, campaign_profile)
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
	if not S.write(decoded.state, decoded.profile, decoded.settings, S.PATH, save_io, true, decoded.campaign):
		notice.text = "Storage failed. Current save kept."
		return
	var changed_mode: bool = state.schema != decoded.state.schema
	state = decoded.state
	profile = decoded.profile
	settings = decoded.settings
	campaign_profile = decoded.campaign
	if changed_mode:
		paused = true
		set_physics_process(false)
		set_process_input(false)
		route_reload()
		return
	close_transfer()
	make_world()
	sync_world(0)
	refresh()

func _physics_process(delta: float) -> void:
	if not paused and state.phase == "playing":
		var before: String = state.phase
		var events := R.tick(state, input_vector, delta)
		presenter.queue_events(events, state.time)
		for e in events:
			if e.kind == "shot":
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
	if presenter != null:
		presenter.synchronize(state, paused, dt, settings.reduced_effects)
	pickup_flash = maxf(0, pickup_flash - dt)

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
	world_label_clearance.reset()
	if audio != null:
		audio.stop()
	audio_playback = null
