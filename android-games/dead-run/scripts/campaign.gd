extends "res://scripts/main.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Data = preload("res://scripts/campaign_data.gd")
const Store = preload("res://scripts/campaign_store.gd")
const LegacyView = preload("res://scripts/legacy_view.gd")
var ctx := Store.fresh()
var world: Node3D
var journey: PanelContainer
var journey_col: VBoxContainer
var stage_buttons: Array[Button] = []
var weapon_buttons: Array[Button] = []
var next_button: Button
var map_button: Button
var journey_return: Button
var abandon_button: Button
var pending_road := -1
var journey_visible := true
var seed_input: SpinBox
var replay_button: Button
var journey_heading: Label
var side_labels: Array[Label3D] = []
var enemy_bars: Array[MeshInstance3D] = []
var hazard_nodes: Array[MeshInstance3D] = []
var boss_label: Label3D
var legacy_view: Node

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	var saved := Store.read(Store.PATH, files)
	if saved.ok: ctx = saved.context
	state = ctx.campaign
	settings = ctx.settings
	paused = state.phase == "playing"
	journey_visible = not saved.ok
	build_world()
	build_ui()
	get_viewport().size_changed.connect(layout)
	layout()
	refresh()
	persist()
	if ctx.mode == "legacy": enter_legacy()

func button(parent: Node, value: String, action: Callable) -> Button:
	var b := super.button(parent, value, action)
	b.custom_minimum_size.y = 96
	return b

func camera_base_fov() -> float:
	return 46.0

func build_world() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = Node3D.new()
	add_child(world)
	actors.clear()
	gate_labels.clear()
	side_labels.clear()
	enemy_bars.clear()
	bullet_nodes.clear()
	hazard_nodes.clear()
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 12, 8)
	camera.look_at(Vector3(0, 0, -12))
	camera.current = true
	frame_camera()
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_energy = 1.3
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = [Color("284450"), Color("3b354c"), Color("193d49"), Color("3c3a4c")][state.definition.district]
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b5d4d9")
	env.environment.ambient_light_energy = 0.75
	world.add_child(env)
	var road_color: Color = [Color("637c7c"), Color("726576"), Color("426e79"), Color("626a80")][state.definition.district]
	box(world, Vector3(0, -0.3, -26), Vector3(9.3, 0.5, 76), road_color)
	for x in [-4.85, 4.85]:
		box(world, Vector3(x, 0.05, -26), Vector3(0.30, 0.5, 76), Color("b2aa91"))
		box(world, Vector3(x, 1.0, -26), Vector3(0.10, 0.10, 76), Color("f0c581"))
		for i in 27:
			box(world, Vector3(x, 0.65, -i * 2.7), Vector3(0.08, 1.25, 0.12), Color("9baba5"))
		for i in 9:
			var building := box(world, Vector3(x * 2 + (i % 2), 2.0, -i * 8 - 12), Vector3(3, 4 + i % 3, 4), road_color.darkened(0.25))
			building.rotation_degrees.y = (i % 2) * 12
			box(world, building.position + Vector3(0, 1, 2.03), Vector3(2, 0.5, 0.04), Color("dda878"))
	for i in 28:
		actors["mark" + str(i)] = box(world, Vector3(0, -0.035, -i * 2.5), Vector3(0.10, 0.04, 0.85), Color("f3d092"))
	box(world, Vector3(0, -0.01, 0.85), Vector3(8.7, 0.035, 0.10), Color("ffe6a0"))
	label3(world, "RESCUE LINE", Vector3(0, 0.05, 1.5), 25)
	for i in 20:
		var p := person()
		if state.weapon == "lance": box(p, Vector3(0.15, 0.58, -0.49), Vector3(0.11, 0.11, 0.65), Color("a1bce2"))
		if state.weapon == "fan":
			for x in [0.04, 0.23]: box(p, Vector3(x, 0.58, -0.37), Vector3(0.10, 0.10, 0.45), Color("e8b17b"))
		var ring := MeshInstance3D.new()
		ring.name = "JoinRing"
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.18
		ring_mesh.outer_radius = 0.23
		ring_mesh.rings = 12
		ring_mesh.ring_segments = 6
		ring.mesh = ring_mesh
		ring.material_override = material(Color("ffe6a0"), true)
		p.add_child(ring)
		ring.position.y = 0.025
		world.add_child(p)
		actors["crew" + str(i)] = p
	for i in state.enemies.size():
		var ed: Dictionary = state.definition.enemies[i]
		var p := person(true)
		if ed.role in ["plated", "bulwark"]:
			box(p, Vector3(0, 0.55, 0.29), Vector3(0.55, 0.62, 0.12), Color("6a8da4"))
		if ed.role == "runner": p.scale = Vector3(0.8, 1.05, 0.8)
		if ed.role == "cluster": p.scale = Vector3(0.72, 0.8, 0.72)
		if ed.role == "bulwark": p.scale = Vector3(1.35, 1.4, 1.25)
		if ed.role == "spitter": ball(p, Vector3(0, 0.55, -0.3), 0.3, Color("e9ba59"))
		world.add_child(p)
		actors["enemy" + str(i)] = p
		enemy_bars.append(box(p, Vector3(0, 1.3, 0), Vector3(0.5, 0.06, 0.10), Color("ffc57a")))
	for g in state.definition.gates:
		var p := Node3D.new()
		world.add_child(p)
		for x in [-g.width, g.width]: box(p, Vector3(x, 0.85, 0), Vector3(0.13, 1.7, 0.15), Color("ffc884"))
		box(p, Vector3(0, 1.65, 0), Vector3(g.width * 2 + 0.13, 0.12, 0.15), Color("ffc884"))
		box(p, Vector3(0, 0.04, 0), Vector3(g.width * 2, 0.06, 0.25), Color("eabd78"))
		gate_labels.append(label3(p, "", Vector3(0, 2.0, 0), 78))
		actors["gate" + str(g.id)] = p
	for t in state.definition.sides:
		var p := Node3D.new()
		world.add_child(p)
		box(p, Vector3(0, 0.35, 0), Vector3(1.7, 0.7, 1.6), Color("b98052"))
		box(p, Vector3(-0.65, 1.8, 0), Vector3(0.20, 3, 0.25), Color("d5a35d"))
		box(p, Vector3(0, 3.1, 0), Vector3(1.8, 0.22, 0.25), Color("d5a35d"))
		ball(p, Vector3(0.18, 1.9, 0), 0.75, Color("7baca8") if t.kind == "pump" else Color("aa759e"))
		for x in [-0.5, 0.5]: ball(p, Vector3(x, 2.5, 0), 0.23, Color("c9d47a"))
		side_labels.append(label3(p, "", Vector3(0, 3.8, 0), 36))
		actors["side" + str(t.id)] = p
	for o in state.definition.obstacles:
		var p := Node3D.new()
		world.add_child(p)
		box(p, Vector3(0, 0.6, 0), Vector3(o.width * 2, 1.2, 1.5), Color("ce855e"))
		label3(p, "CART\n−3", Vector3(0, 1.7, 0), 36)
		actors["obstacle" + str(o.id)] = p
	var boss := Node3D.new()
	world.add_child(boss)
	var kind: int = state.definition.boss.kind
	box(boss, Vector3(0, 0.8, 0), Vector3(2.4, 1.6, 1.7), Color("a66b89") if kind else Color("ce8059"))
	for x in [-0.9, 0.0, 0.9]: ball(boss, Vector3(x, 1.7, 0), 0.46, Color("c2ce78"))
	if kind == 1: box(boss, Vector3(0, 2.4, 0), Vector3(3.0, 0.18, 0.25), Color("d6a56a"))
	if kind == 2: box(boss, Vector3(0, 1, 1), Vector3(1.2, 2.0, 0.16), Color("79a0b7"))
	if kind == 3: ball(boss, Vector3(0, 2.7, 0), 0.85, Color("c096b9"))
	if kind == 4:
		for i in 2:
			var arm := box(world, Vector3.ZERO, Vector3(1.6, 2.1, 1.5), Color("bd8972"))
			actors["arm" + str(i)] = arm
	boss_label = label3(boss, "", Vector3(0, 3.9 if kind else 2.6, 0), 36)
	actors.boss = boss
	footprint = box(world, Vector3.ZERO, Vector3.ONE, Color(1.0, 0.85, 0.3, 0.34))
	for i in 220:
		var p := box(world, Vector3.ZERO, Vector3(0.055, 0.055, 0.46), Color("a1fff1"))
		p.material_override = material(Color("a1fff1"), true)
		bullet_nodes.append(p)
	for i in 40:
		hazard_nodes.append(box(world, Vector3.ZERO, Vector3.ONE, Color(1, 0.42, 0.17, 0.43)))
	if not is_instance_valid(tone):
		tone = AudioStreamPlayer.new()
		add_child(tone)
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_8_BITS
		wav.mix_rate = 22050
		var data := PackedByteArray()
		for i in 900: data.append(int(128 + sin(i * 0.19) * 19 * (1.0 - float(i) / 900)))
		wav.data = data
		tone.stream = wav
		tone.volume_db = -18

func build_ui() -> void:
	super.build_ui()
	var col := resume_button.get_parent()
	next_button = button(col, "NEXT ROAD", next_road)
	col.move_child(next_button, 3)
	map_button = button(col, "EVACUATION MAP", open_journey)
	journey = panel()
	var scroll := ScrollContainer.new()
	journey.add_child(scroll)
	journey_col = VBoxContainer.new()
	journey_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journey_col.add_theme_constant_override("separation", 12)
	scroll.add_child(journey_col)
	journey_heading = text(journey_col, "EVACUATION ROAD", 34)
	text(journey_col, "Restore four districts. Choose a tool for the next road.", 24)
	var weapons := HBoxContainer.new()
	journey_col.add_child(weapons)
	for weapon in Data.WEAPONS:
		var b := button(weapons, Data.WEAPONS[weapon].title, func(): choose_weapon(weapon))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("weapon", weapon)
		weapon_buttons.append(b)
	var hint := text(journey_col, "", 23)
	hint.name = "WeaponHint"
	journey_return = button(journey_col, "RETURN TO ROAD", func(): journey_visible = false; refresh())
	abandon_button = button(journey_col, "LOAD SELECTED ROAD", confirm_selection)
	button(journey_col, "LEGACY CANAL BRIDGE", enter_legacy)
	for i in 24:
		var b := button(journey_col, "", func(): select_road(i))
		b.add_theme_font_size_override("font_size", 24)
		stage_buttons.append(b)
	seed_input = SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 999999
	seed_input.value = 61723
	seed_input.custom_minimum_size.y = 96
	seed_input.add_theme_font_size_override("font_size", 26)
	journey_col.add_child(seed_input)
	replay_button = button(journey_col, "SEEDED FERRY EVACUATION", func(): load_road(23, int(seed_input.value)))

func layout() -> void:
	super.layout()
	if is_instance_valid(journey):
		var size := get_viewport().get_visible_rect().size
		journey.position = Vector2(maxf(16, (size.x - 680) / 2), 180)
		journey.size = Vector2(minf(size.x - 32, 680), size.y - 205)

func choose_weapon(weapon: String) -> void:
	ctx.loadout = weapon
	persist()
	refresh()

func open_journey() -> void:
	paused = true
	drag_index = -1
	journey_visible = true
	pending_road = -1
	persist()
	refresh()

func select_road(index: int) -> void:
	if index > ctx.profile.clears.size(): return
	if state.phase == "playing" and state.tick > 0:
		pending_road = index
		refresh()
	else: load_road(index)

func confirm_selection() -> void:
	if pending_road >= 0: load_road(pending_road)

func load_road(index: int, seed: int = 0) -> void:
	if (seed == 0 and index > ctx.profile.clears.size()) or (seed > 0 and not ctx.profile.ending): return
	state = C.fresh(index, ctx.loadout, seed)
	ctx.campaign = state
	ctx.mode = "campaign"
	paused = false
	journey_visible = false
	pending_road = -1
	build_world()
	persist()
	refresh()

func start_run() -> void:
	# Retry preserves the exact selected snapshot/options, independently of map loadout.
	state = C.fresh(state.definition.index, state.weapon, state.definition.seed)
	state.phase = "playing"
	ctx.campaign = state
	paused = false
	journey_visible = false
	drag_index = -1
	build_world()
	persist()
	refresh()

func next_road() -> void:
	if state.phase == "victory" and not state.definition.replay and state.definition.index < 23:
		load_road(state.definition.index + 1)

func persist() -> bool:
	ctx.campaign = state
	if ctx.mode == "campaign": ctx.settings = settings
	var okay := Store.write(ctx, Store.PATH, files)
	save_message = "" if okay else "SAVE FAILED — progress is only in memory. Free storage, then retry Save."
	return okay

func enter_legacy() -> void:
	if is_instance_valid(legacy_view): return
	paused = true
	ctx.mode = "legacy"
	persist()
	hud.hide()
	world.hide()
	legacy_view = LegacyView.new()
	legacy_view.host = self
	add_child(legacy_view)

func leave_legacy() -> void:
	if is_instance_valid(legacy_view):
		legacy_view.persist()
		legacy_view.queue_free()
	ctx.mode = "campaign"
	settings = ctx.settings
	paused = true
	journey_visible = true
	hud.show()
	world.show()
	camera.current = true
	persist()
	refresh()

func export_code() -> void:
	var code := Store.encode(ctx, int(Store.read(Store.PATH, files).revision))
	code_box.text = code
	copy_service.begin(code)
	transfer_status.text = copy_service.feedback

func import_code() -> void:
	copy_service.cancel()
	var saved := Store.decode(code_box.text)
	if not saved.ok:
		transfer_status.text = "Invalid code. Journey unchanged."
		return
	if not Store.write(saved.context, Store.PATH, files, true):
		transfer_status.text = "Import could not be stored. Journey unchanged."
		return
	ctx = saved.context
	state = ctx.campaign
	settings = ctx.settings
	paused = true
	journey_visible = false
	build_world()
	transfer_status.text = "Imported and stored. Close, then Resume."
	save_message = ""
	refresh()

func close_transfer() -> void:
	super.close_transfer()
	if ctx.mode == "legacy": enter_legacy()

func back() -> void:
	if ctx.mode == "legacy" or is_instance_valid(legacy_view): return
	if transfer.visible: close_transfer()
	elif journey_visible:
		journey_visible = false
		refresh()
	else: toggle_pause()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(legacy_view) and ctx.mode != "legacy": super._input(event)

func _unhandled_input(event: InputEvent) -> void:
	if ctx.mode == "legacy" or state.phase != "playing" or paused or journey_visible or transfer.visible: return
	var size := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and drag_index == -1 and event.position.y > 250 and event.position.y < size.y - 130:
			drag_index = event.index
			anchor = event.position
			anchor_x = state.x
		elif not event.pressed and event.index == drag_index: drag_index = -1
	elif event is InputEventScreenDrag and event.index == drag_index:
		C.steer(state, anchor_x + (event.position.x - anchor.x) / size.x * 9.0)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_drag = event.pressed and event.position.y > 250 and event.position.y < size.y - 130
		anchor = event.position
		anchor_x = state.x
	elif event is InputEventMouseMotion and mouse_drag and event.device != InputEvent.DEVICE_ID_EMULATION:
		C.steer(state, anchor_x + (event.position.x - anchor.x) / size.x * 9.0)

func _physics_process(delta: float) -> void:
	if ctx.mode == "legacy" or is_instance_valid(legacy_view): return
	if copy_service.poll(delta) and transfer.visible: transfer_status.text = copy_service.feedback
	var before: String = state.phase
	if not paused and not journey_visible: C.step(state)
	if state.phase == "victory": Store.award(ctx)
	if state.phase != before or (state.phase == "playing" and not paused and state.tick % 120 == 0): persist()
	if settings.sound and not paused and state.phase == "playing" and state.tick % state.definition.weapons[state.weapon].period == 0: tone.play()
	refresh()

func refresh() -> void:
	if hud == null: return
	var d: Dictionary = state.definition
	title.text = "%02d  %s" % [d.index + 1, d.title.to_upper()]
	title.add_theme_font_size_override("font_size", 27)
	info.text = "CREW %d / 20   ·   %s   ·   %d%%\n%s  ·  %d / 24 roads restored" % [state.crew, Data.WEAPONS[state.weapon].title, state.tick * 100 / d.duration, Data.DISTRICTS[d.district], ctx.profile.clears.size()]
	notice.text = save_message if not save_message.is_empty() else state.notice
	warning.text = "Drag sideways · fit the whole gold footprint through gaps"
	for i in state.gates.size():
		if state.tick >= d.gates[i].born and not state.gates[i].crossed and state.gates[i].z < 6:
			warning.text = "GATE %+d in %.1fs · overlap applies its sign once" % [state.gates[i].value, state.gates[i].z / d.speed]
	for i in state.obstacles.size():
		if state.tick >= d.obstacles[i].born and not state.obstacles[i].crossed and state.obstacles[i].z < 7: warning.text = "CART AHEAD · leave room for the whole crew"
	for h in state.hazards:
		if not h.resolved: warning.text = "%s in %.1fs · leave the orange lane" % [h.label.to_upper(), maxf(0, h.fire - state.tick) / 60.0]
	if state.tick >= d.boss.born and not state.boss.dead:
		if d.boss.kind == 4: warning.text = "FERRY EATER · arms %d / %d · core %d" % [state.boss.arms[0], state.boss.arms[1], state.boss.hp]
		elif d.boss.kind == 2: warning.text = "TOLL RAM %d · flanks or Lance bypass its shield" % state.boss.hp
	overlay.visible = (paused or state.phase != "playing") and not journey_visible
	overlay_title.text = ("LAST FERRY AWAY" if ctx.profile.ending and d.index == 23 and state.phase == "victory" and not d.replay else {"ready": "PREPARE THE ROAD", "playing": "RESCUE PAUSED", "victory": "ROAD RESTORED", "defeat": "RESCUE LOST"}[state.phase])
	overlay_body.text = (d.hint + "\nDrag sideways. Fire is automatic. Shoot gates to improve their number; cross once to gain or lose crew. " + Data.WEAPONS[state.weapon].hint) if state.phase == "ready" else state.notice + "\n" + save_message
	if ctx.profile.ending and d.index == 23 and state.phase == "victory" and not d.replay:
		overlay_body.text = "The canal, market and reservoirs are clear. Your crew holds the last pier as the final ferry departs. All 24 evacuation roads are restored. Replay any road, rescue every rigger, or choose a seeded ferry run."
	start_button.visible = state.phase == "ready"
	resume_button.visible = paused
	retry_button.text = "RETRY ROAD"
	retry_button.visible = state.phase in ["victory", "defeat"]
	next_button.visible = state.phase == "victory" and d.index < 23 and not d.replay
	sound_button.text = "SOUND: " + ("ON" if settings.sound else "OFF")
	effects_button.text = "REDUCED EFFECTS: " + ("ON" if settings.reduced_effects else "OFF")
	journey.visible = journey_visible and not transfer.visible
	journey_heading.text = "EVACUATION ROAD · %d / 24" % ctx.profile.clears.size()
	journey_return.visible = state.phase == "playing"
	abandon_button.visible = pending_road >= 0
	if pending_road >= 0: abandon_button.text = "ABANDON CURRENT ROAD · LOAD %02d" % (pending_road + 1)
	journey_col.get_node("WeaponHint").text = Data.WEAPONS[ctx.loadout].hint
	for b in weapon_buttons: b.button_pressed = b.get_meta("weapon") == ctx.loadout; b.modulate = Color("ffdc94") if b.get_meta("weapon") == ctx.loadout else Color.WHITE
	for i in 24:
		stage_buttons[i].text = "%02d  %s\n%s%s" % [i + 1, Data.ROWS[i][0], Data.DISTRICTS[i / 6], " · RESTORED" if i in ctx.profile.clears else ""]
		stage_buttons[i].disabled = i > ctx.profile.clears.size()
	replay_button.disabled = not ctx.profile.ending
	seed_input.editable = ctx.profile.ending
	for i in 20:
		var p: Node3D = actors["crew" + str(i)]
		p.visible = i < state.crew
		if p.visible:
			var q := C.offset(i, state.crew)
			p.position = Vector3(state.x + q.x, 0.04 + (absf(sin(state.tick * 0.18 + i)) * 0.04 if not settings.reduced_effects else 0.0), q.y)
			p.get_node("JoinRing").visible = state.tick - state.gain_tick < 60 and not settings.reduced_effects
	for i in state.enemies.size():
		var e: Dictionary = state.enemies[i]
		var p: Node3D = actors["enemy" + str(i)]
		p.visible = state.tick >= d.enemies[i].born and not e.resolved
		if p.visible:
			p.position = Vector3(d.enemies[i].x, 0.04, -e.z)
			enemy_bars[i].scale.x = float(e.hp + e.armor) / (d.enemies[i].hp + d.enemies[i].armor)
	for i in state.gates.size():
		var g: Dictionary = state.gates[i]
		var p: Node3D = actors["gate" + str(i)]
		p.visible = state.tick >= d.gates[i].born and not g.crossed
		p.position = Vector3(d.gates[i].x, 0, -g.z)
		gate_labels[i].text = "%+d" % g.value
		gate_labels[i].modulate = Color("8affe0") if g.value >= 0 else Color("ffaaa1")
	for i in state.sides.size():
		var t: Dictionary = d.sides[i]
		var p: Node3D = actors["side" + str(i)]
		p.visible = state.tick >= t.born and state.tick <= t.until and not state.sides[i].claimed
		p.position = Vector3(t.x, 0, -t.z)
		side_labels[i].text = ("FLOOD PUMP" if t.kind == "pump" else "RIGGING CRANE") + "\n%d / %d\n+3 CREW" % [state.sides[i].hp, t.hp]
	for i in state.obstacles.size():
		var o: Dictionary = state.obstacles[i]
		var p: Node3D = actors["obstacle" + str(i)]
		p.visible = state.tick >= d.obstacles[i].born and not o.crossed
		p.position = Vector3(d.obstacles[i].x, 0, -o.z)
	actors.boss.visible = state.tick >= d.boss.born and not state.boss.dead
	actors.boss.position = Vector3(state.boss.x, 0, -state.boss.z)
	boss_label.text = "%s\n%d / %d" % [d.boss.title.to_upper(), state.boss.hp, d.boss.hp]
	if d.boss.kind == 4:
		for i in 2:
			actors["arm" + str(i)].visible = state.tick >= d.boss.born and state.boss.arms[i] > 0
			actors["arm" + str(i)].position = Vector3(-2.3 if i == 0 else 2.3, 1.05, -state.boss.z)
	footprint.position = Vector3(state.x, 0.025, 0.6)
	footprint.scale = Vector3(C.half_width(state.crew) * 2, 0.04, 1.9)
	for i in bullet_nodes.size():
		bullet_nodes[i].visible = i < state.bullets.size()
		if i < state.bullets.size(): bullet_nodes[i].position = Vector3(state.bullets[i].x, 0.62, -state.bullets[i].z)
	var active: Array = state.hazards.filter(func(h): return not h.resolved or (not h.cancelled and state.tick >= h.fire and state.tick - h.fire < 15))
	for i in hazard_nodes.size():
		hazard_nodes[i].visible = i < active.size()
		if i < active.size():
			hazard_nodes[i].position = Vector3(active[i].x, 0.05, 0)
			hazard_nodes[i].scale = Vector3(active[i].width * 2, 0.05, 3.5)
			(hazard_nodes[i].material_override as StandardMaterial3D).albedo_color = Color(1, 0.15, 0.10, 0.65) if state.tick >= active[i].fire else Color(1, 0.60, 0.15, 0.43)
	for i in 28: actors["mark" + str(i)].position.z = -fposmod(i * 2.5 - state.tick / 60.0 * d.speed, 70)
