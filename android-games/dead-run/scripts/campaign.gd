extends "res://scripts/main.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Data = preload("res://scripts/campaign_data.gd")
const Store = preload("res://scripts/campaign_store.gd")
const LegacyView = preload("res://scripts/legacy_view.gd")
const Adapter = preload("res://scripts/presentation/adapter.gd")
var presentation: RefCounted
var hud_back: Panel
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
	# 51 (was 46): the lower chase camera keeps the whole near road and the
	# widest footprint inside the side margins.
	return 51.0

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
	# Lower elevated chase view: the full road width near the squad stays in
	# frame while the road recedes into fog toward a visible horizon.
	camera.position = Vector3(0, 9.5, 8.5)
	camera.look_at(Vector3(0, 0, -14))
	camera.current = true
	frame_camera()
	# Presentation is rebuilt with the world: a fresh adapter on every load,
	# Retry, import and road change clears all transient effects and pools.
	presentation = Adapter.new()
	presentation.build(self, world, actors, state)
	boss_label = presentation.boss_label
	var line := box(world, Vector3(0, .02, 0.85), Vector3(8.7, 0.035, 0.10), Color("ffe6a0"))
	line.material_override = material(Color("ffe6a0"), true)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var caption := label3(world, "RESCUE LINE", Vector3(0, 0.05, 1.25), 25)
	caption.modulate = Color("ffe6a0")
	caption.outline_modulate = Color("2a1d08")
	footprint = box(world, Vector3.ZERO, Vector3.ONE, Color(1.0, 0.85, 0.3, 0.20))
	footprint.material_override = material(Color(1.0, 0.85, 0.3, 0.20), true)
	footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	# Restrained HUD: a translucent strip behind the status text and outlines
	# keep it readable over sky and road without hiding the action.
	hud_back = Panel.new()
	var strip := StyleBoxFlat.new()
	strip.bg_color = Color(0.04, 0.09, 0.13, 0.58)
	strip.set_corner_radius_all(22)
	hud_back.add_theme_stylebox_override("panel", strip)
	hud_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_back)
	hud.move_child(hud_back, 0)
	for l in [title, info, warning, notice]:
		l.add_theme_constant_override("outline_size", 9)
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.07, 0.10, 0.9))
	warning.modulate = Color("ffd77a")
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var pause_style := strip.duplicate()
		pause_style.bg_color = Color(0.04, 0.09, 0.13, 0.72 if state_name == "pressed" else 0.58)
		pause_button.add_theme_stylebox_override(state_name, pause_style)
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
	if is_instance_valid(hud_back):
		var v := get_viewport().get_visible_rect().size
		hud_back.position = Vector2(10, 12)
		hud_back.size = Vector2(v.x - 132, 170)
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
	presentation.sync(state, settings)
	footprint.position = Vector3(state.x, 0.025, 0.6)
	footprint.scale = Vector3(C.half_width(state.crew) * 2, 0.04, 1.9)

func _process(delta: float) -> void:
	if presentation == null: return
	presentation.frame(delta, paused or journey_visible or transfer.visible or ctx.mode == "legacy" or is_instance_valid(legacy_view))
