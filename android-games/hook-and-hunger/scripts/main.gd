extends Node3D
const Rules = preload("res://scripts/engine.gd")
const Campaign = preload("res://scripts/campaign_rules.gd")
const Data = preload("res://scripts/campaign_data.gd")
const Store = preload("res://scripts/save_store.gd")
const Art = preload("res://scripts/art.gd")

var state := Rules.fresh()
var profile := Campaign.profile()
var settings := {"sound": true, "reduced_effects": false}
var paused := false
var dragging := false
var finger := -1
var drag_start := Vector2.ZERO
var movement := Vector2.ZERO
var save_clock := 0.0
var save_error := ""
var camera: Camera3D
var player: Node3D
var weapon_node: Node3D
var preview: Node3D
var gate: Node3D
var pad_ring: MeshInstance3D
var reach_ring: MeshInstance3D
var actors := {}
var drops := {}
var chain: Array[MeshInstance3D] = []
var shown_tier := -1
var last_dead := 0
var last_hp := 100.0
var audio: AudioStreamPlayer
var sound_cache := {}
var status: Label
var title: Label
var objective: Label
var notice: Label
var health: ProgressBar
var buy_button: Button
var bottom_panel: PanelContainer
var menu_button: Button
var terminal: PanelContainer
var terminal_title: Label
var terminal_body: Label
var retry_button: Button
var menu: PanelContainer
var transfer: TextEdit
var transfer_status: Label
var sound_toggle: CheckButton
var effects_toggle: CheckButton
var stick: Control
var phase_seen := ""
var continue_button: Button
var arena_panel: VBoxContainer
var arena_seed_button: Button
var arena_weapon_button: Button
var projectiles := {}
var world_clock := 0.0

func _ready() -> void:
	var loaded := Store.read()
	if loaded.ok:
		state = loaded.state
		settings = loaded.settings
		profile = loaded.profile
		paused = state.phase == "playing"
	last_dead = state.dead.size()
	last_hp = state.hp
	_world()
	_ui()
	menu.visible = paused
	_sync()

func _world() -> void:
	if state.schema == 2:
		_campaign_world()
		return
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0b293b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("badbdc")
	environment.environment.ambient_light_energy = 0.4
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, -10)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.5
	add_child(camera)
	add_child(Art.box(Vector3(150, 0.2, 160), Color("165064"), Vector3(0, -1.2, -10)))
	for pen in 2:
		var center_z := 1.2 if pen == 0 else -13.5
		add_child(Art.box(Vector3(12.7, 1.2, 15.2 if pen == 0 else 13), Color("204453"), Vector3(0, -0.6, center_z)))
		add_child(Art.box(Vector3(12.3, 0.25, 14.8 if pen == 0 else 12.6), Color("7d9690") if pen == 0 else Color("69878b"), Vector3(0, 0, center_z)))
		for side in [-1, 1]:
			for z in range(-6 if pen == 0 else -20, 9 if pen == 0 else -6, 2):
				add_child(Art.box(Vector3(0.22, 0.8, 0.22), Color("466979"), Vector3(side * 6.1, 0.4, z)))
			add_child(Art.box(Vector3(0.12, 0.12, 14.4 if pen == 0 else 12.4), Color("7e9697"), Vector3(side * 6.1, 0.7, center_z)))
	for side in [-1, 1]:
		add_child(Art.box(Vector3(4.2, 0.6, 0.3), Color("456e7b"), Vector3(side * 4.0, 0.4, -6.5)))
	gate = Node3D.new()
	gate.position = Vector3(0, 0, -6.5)
	add_child(gate)
	for x in [-1.3, 0, 1.3]:
		gate.add_child(Art.box(Vector3(0.2, 1.9, 0.2), Color("efaa78"), Vector3(x, 1, 0)))
	gate.add_child(Art.box(Vector3(3.4, 0.2, 0.2), Color("efaa78"), Vector3(0, 1.75, 0)))
	gate.add_child(Art.label("POWER 200", Vector3(0, 2.5, 0), 44))
	for obstacle in Rules.obstacles(state):
		var rock := Art.cylinder(obstacle.z, 0.9, Color("4c7b82"), Vector3(obstacle.x, 0.45, obstacle.y), obstacle.z * 0.65)
		add_child(rock)
		var crystal := Art.cylinder(0.3, 1.4, Color("7cddd2"), Vector3(obstacle.x, 1.1, obstacle.y), 0)
		crystal.rotation.z = 0.24
		add_child(crystal)
	for i in 38:
		var side := -1 if i % 2 == 0 else 1
		var z := -23.0 + i * 0.9
		var tuft := Art.cylinder(0.24, 0.5 + (i % 3) * 0.2, Color("28797d"), Vector3(side * (7.0 + (i % 4) * 0.6), -0.6, z), 0.05)
		add_child(tuft)
	pad_ring = Art.ring(1.55, Color("80eed1"))
	pad_ring.position = Vector3(0, 0.18, 6.8)
	add_child(pad_ring)
	add_child(Art.cylinder(0.8, 0.35, Color("365a65"), Vector3(0, 0.18, 6.8)))
	preview = Art.blade(1)
	preview.position = Vector3(0, 1.1, 6.8)
	preview.rotation_degrees.x = 60
	add_child(preview)
	add_child(Art.label("FORGE\n36 SALVAGE", Vector3(-2.9, 1.4, 7.0), 25))
	player = Art.diver()
	add_child(player)
	reach_ring = Art.ring(2.5, Color("faf0d6"))
	reach_ring.position.y = 0.16
	add_child(reach_ring)
	for i in 14:
		var link := Art.ring(0.095, Color("263f54"))
		link.rotation_degrees.x = 90
		add_child(link)
		chain.append(link)
	audio = AudioStreamPlayer.new()
	add_child(audio)

func _panel(color: Color = Color("102d40")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _label(text: String, size: int, color: Color = Color("fff0d5")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, parent: Node, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 100)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color("092f3b"))
	b.add_theme_color_override("font_hover_color", Color("092f3b"))
	b.add_theme_color_override("font_pressed_color", Color("092f3b"))
	b.add_theme_stylebox_override("normal", _panel(Color("8ce7d0")))
	b.add_theme_stylebox_override("hover", _panel(Color("b2f5df")))
	b.add_theme_stylebox_override("pressed", _panel(Color("e4b477")))
	b.add_theme_stylebox_override("disabled", _panel(Color("51717b")))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	stick = preload("res://scripts/stick.gd").new()
	stick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stick)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 30
	top.add_theme_stylebox_override("panel", _panel())
	root.add_child(top)
	var box := VBoxContainer.new()
	top.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	title = _label("HOOK & HUNGER", 29)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	menu_button = _button("PAUSE", row, _toggle_menu)
	status = _label("", 26, Color("8ce7d0"))
	box.add_child(status)
	health = ProgressBar.new()
	health.custom_minimum_size.y = 13
	health.show_percentage = false
	health.add_theme_stylebox_override("background", _panel(Color("2b4859")))
	health.add_theme_stylebox_override("fill", _panel(Color("84e3c0")))
	box.add_child(health)
	var bottom := PanelContainer.new()
	bottom_panel = bottom
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -222
	bottom.offset_bottom = -28
	bottom.add_theme_stylebox_override("panel", _panel())
	root.add_child(bottom)
	var bottom_box := VBoxContainer.new()
	bottom.add_child(bottom_box)
	objective = _label("", 26)
	bottom_box.add_child(objective)
	buy_button = _button("", bottom_box, _buy)
	notice = _label("", 26, Color("ffe0a4"))
	notice.add_theme_stylebox_override("normal", _panel(Color(0.04, 0.14, 0.2, 0.94)))
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notice.offset_left = 220
	notice.offset_right = -24
	notice.offset_top = -365
	notice.offset_bottom = -235
	root.add_child(notice)
	terminal = PanelContainer.new()
	terminal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	terminal.offset_left = -300
	terminal.offset_right = 300
	terminal.offset_top = -205
	terminal.offset_bottom = 205
	terminal.add_theme_stylebox_override("panel", _panel(Color("123447")))
	root.add_child(terminal)
	var terminal_box := VBoxContainer.new()
	terminal.add_child(terminal_box)
	terminal_title = _label("", 38, Color("8ce7d0"))
	terminal_box.add_child(terminal_title)
	terminal_body = _label("", 25)
	terminal_box.add_child(terminal_body)
	retry_button = _button("RETRY", terminal_box, _retry)
	continue_button = _button("SET SAIL", terminal_box, _continue)
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -310
	menu.offset_right = 310
	menu.offset_top = -365
	menu.offset_bottom = 365
	menu.add_theme_stylebox_override("panel", _panel())
	root.add_child(menu)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(options)
	options.add_child(_label("DOCK LOG • PAUSED", 32))
	_button("RESUME", options, _toggle_menu)
	var sound := CheckButton.new()
	sound.text = "Sound"
	sound.button_pressed = settings.sound
	sound.custom_minimum_size.y = 100
	sound.add_theme_font_size_override("font_size", 25)
	sound.toggled.connect(func(value: bool) -> void: settings.sound = value; _save())
	options.add_child(sound)
	sound_toggle = sound
	var effects := CheckButton.new()
	effects.text = "Reduced effects"
	effects.button_pressed = settings.reduced_effects
	effects.custom_minimum_size.y = 100
	effects.add_theme_font_size_override("font_size", 25)
	effects.toggled.connect(func(value: bool) -> void: settings.reduced_effects = value; _save())
	options.add_child(effects)
	effects_toggle = effects
	options.add_child(_label("Drag to move. Nearby attacks are automatic.\nLeave solid circles; step inside hollow rings. Sidestep lines. Rocks stop shots.\nUse the dock to buy power or repair.", 26))
	arena_panel = VBoxContainer.new()
	options.add_child(arena_panel)
	arena_panel.add_child(_label("HARBOR ARENA • REPLAY", 30))
	arena_seed_button = _button("", arena_panel, _cycle_seed)
	arena_weapon_button = _button("", arena_panel, _cycle_weapon)
	_button("SAIL TO ARENA", arena_panel, _arena)
	transfer = TextEdit.new()
	transfer.placeholder_text = "Local save code • export or paste here"
	transfer.custom_minimum_size = Vector2(0, 85)
	transfer.add_theme_font_size_override("font_size", 17)
	options.add_child(transfer)
	var transfer_row := HBoxContainer.new()
	options.add_child(transfer_row)
	for text in ["EXPORT", "PASTE", "IMPORT"]:
		var b := _button(text, transfer_row, _transfer.bind(text))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transfer_status = _label("Two local recovery slots. No account or connection.", 26)
	options.add_child(transfer_status)
	menu.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Native text controls need touch-to-mouse emulation; world movement owns
	# the original finger events and must not process their mouse copies.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if paused or state.phase != "playing":
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			dragging = true
			drag_start = event.position
		elif not event.pressed and event.index == finger:
			_stop()
	elif event is InputEventScreenDrag and event.index == finger:
		movement = (event.position - drag_start) / 75.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		drag_start = event.position
		movement = Vector2.ZERO
	elif event is InputEventMouseMotion and dragging:
		movement = (event.position - drag_start) / 75.0

func _stop() -> void:
	dragging = false
	finger = -1
	movement = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not paused:
		var keys := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		Rules.step(state, movement if dragging else keys, delta)
		save_clock += delta
		if save_clock >= 2.0:
			save_clock = 0
			_save()
	_sync()

func _process(delta: float) -> void:
	world_clock += delta
	if not settings.reduced_effects:
		preview.rotation.y += delta * 0.7

func _sync() -> void:
	var p := Rules.position(state)
	var viewport := get_viewport().get_visible_rect().size
	camera.size = maxf(16.5 if state.schema == 1 else 17.7, 2.0 * (float(Rules.weapon(state).reach) + 1.0) / maxf(0.3, viewport.x / viewport.y))
	player.position = Vector3(p.x, 0.15, p.y)
	if movement.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(movement.x, movement.y), 0.2)
	camera.position = Vector3(p.x, 23, p.y + 17)
	camera.look_at(Vector3(p.x, 0, p.y - 3.0))
	if shown_tier != int(state.tier):
		shown_tier = int(state.tier)
		if weapon_node != null:
			weapon_node.queue_free()
		weapon_node = Art.blade(shown_tier)
		add_child(weapon_node)
		var circle := TorusMesh.new()
		circle.inner_radius = float(Rules.weapon(state).reach) - 0.025
		circle.outer_radius = float(Rules.weapon(state).reach) + 0.025
		circle.rings = 48
		circle.ring_segments = 6
		reach_ring.mesh = circle
		reach_ring.material_override = Art.material(Color("a9c6b4"))
	preview.visible = state.tier == 0 if state.schema == 1 else Rules.cost(state) > 0
	gate.visible = state.tier == 0 if state.schema == 1 else int(state.tier) < int(state.definition.required_tier)
	pad_ring.visible = true
	reach_ring.position = Vector3(p.x, 0.16, p.y)
	var hand := Vector3(p.x + 0.35, 1.05, p.y + 0.15)
	var end := hand + Vector3(0.65, -0.1, 0.4)
	if state.strike > 0:
		var t: float = (0.36 - float(state.strike)) / 0.36
		var extension := sin(t * PI)
		end = hand.lerp(Vector3(state.strike_x, 0.8, state.strike_z), extension)
	weapon_node.position = end
	weapon_node.rotation.y = atan2(end.x - hand.x, end.z - hand.z) + PI / 2
	for i in chain.size():
		chain[i].visible = state.strike > 0
		chain[i].position = hand.lerp(end, float(i) / (chain.size() - 1))
		chain[i].rotation.y = float(i % 2) * PI / 2
	var alive := {}
	for e in Rules.active(state):
		var id := int(e.id)
		alive[id] = true
		var spec: Dictionary = Rules.roster(state)[id]
		if not actors.has(id):
			var n := Art.creature(str(spec.role))
			add_child(n)
			var warning: Node3D = Art.ring(float(spec.range), Color("f77764")) if state.schema == 1 else Art.warning()
			warning.name = "Warning"
			warning.position.y = 0.18
			n.add_child(warning)
			var boss: bool = (id == 7) if state.schema == 1 else bool(spec.boss)
			var label := Art.label("", Vector3(0, 3.1 if boss else 2.1, 0), 28 if boss else 25)
			label.name = "Health"
			n.add_child(label)
			actors[id] = n
		var actor: Node3D = actors[id]
		actor.position = Vector3(e.x, 0.15, e.z)
		actor.rotation.y = atan2(p.x - e.x, p.y - e.z) if state.schema == 1 else float(e.facing)
		actor.scale = Vector3.ONE * (1.06 if e.flash > 0 and not settings.reduced_effects else 1.0)
		actor.get_node("Warning").visible = e.mode == "wind"
		actor.get_node("Health").text = (("BELLKEEPER " if id == 7 else "") if state.schema == 1 else (str(spec.role).replace("_", " ").to_upper() + " ")) + str(int(e.hp))
		if state.schema == 2:
			var warning := actor.get_node("Warning")
			warning.get_node("Solid").visible = e.attack == "slam"
			warning.get_node("Outer").visible = e.attack == "ring"
			warning.get_node("Inner").visible = e.attack == "ring"
			warning.get_node("Line").visible = e.attack in ["line", "charge", "shot", "burst"]
			warning.get_node("Left").visible = e.attack == "burst" or bool(spec.boss) and e.attack == "shot"
			warning.get_node("Right").visible = warning.get_node("Left").visible
	for id in actors.keys():
		if not alive.has(id):
			actors[id].queue_free()
			actors.erase(id)
	var drop_ids := {}
	for drop in state.drops:
		var id := int(drop.id)
		drop_ids[id] = true
		if not drops.has(id):
			var n := Art.cylinder(0.28, 0.65, Color("ffe09b"), Vector3.ZERO, 0)
			add_child(n)
			n.add_child(Art.label("+" + str(Rules.roster(state)[id].reward), Vector3(0, 0.8, 0), 28))
			drops[id] = n
		drops[id].position = Vector3(drop.x, 0.4, drop.z)
		drops[id].rotation.y = world_clock
	for id in drops.keys():
		if not drop_ids.has(id):
			drops[id].queue_free()
			drops.erase(id)
	if state.schema == 2:
		var ids := {}
		for shot in state.projectiles:
			var id := int(shot.id)
			ids[id] = true
			if not projectiles.has(id):
				var ball := Art.sphere(0.21, Color("ffb181"))
				add_child(ball)
				projectiles[id] = ball
			projectiles[id].position = Vector3(shot.x, 0.65, shot.z)
		for id in projectiles.keys():
			if not ids.has(id):
				projectiles[id].queue_free()
				projectiles.erase(id)
	status.text = "HULL %d  •  POWER %d  •  SALVAGE %d" % [ceili(state.hp), int(Rules.weapon(state).power), int(state.wallet)]
	health.value = state.hp
	if state.schema == 1:
		title.text = "HOOK & HUNGER"
		objective.text = "01 / SALTGLASS QUARRY   •   %d / 5 shoal cleared" % mini(5, state.dead.size()) if state.tier == 0 else "02 / BELLKEEPER'S PEN   •   use reach, leave red circles"
		buy_button.disabled = not (state.tier == 0 and int(state.wallet) >= Rules.cost(state) and p.distance_to(Rules.pad(state)) <= 1.8 and state.phase == "playing")
		buy_button.text = "FORGE TIDECUTTER • 36 • FULL HEAL" if state.tier == 0 else "TIDECUTTER • 32 DAMAGE • 3.6m REACH • CLEAVE"
		if state.tier == 0 and state.wallet >= Rules.cost(state) and p.distance_to(Rules.pad(state)) > 1.8:
			buy_button.text = "RETURN TO THE MINT FORGE ↓ • 36"
		notice.text = save_error if not save_error.is_empty() else (state.notice if state.notice_left > 0 else ("Drag to move\nAutomatic chain strikes" if state.tier == 0 else "Lure the Bellkeeper.\nStrike from its outer reach."))
	stick.active = dragging
	stick.origin = drag_start
	stick.direction = movement
	stick.queue_redraw()
	terminal.visible = state.phase != "playing" and not menu.visible
	terminal_title.text = "BEACON RESTORED" if state.phase == "victory" else "HULL BREACHED"
	terminal_body.text = "The Bellkeeper is silent. Saltglass beacon burns again.\n%d salvage recovered • %d rescues\nYour diver returns safely to the harbor." % [int(state.wallet), int(state.deaths)] if state.phase == "victory" else "Your weapon, salvage and defeated foes are retained. Recover at the safe dock and finish the pen."
	retry_button.visible = state.phase == "defeat"
	continue_button.visible = state.phase == "victory"
	continue_button.text = "SET SAIL"
	arena_panel.visible = profile.completed
	arena_seed_button.text = "ARENA SEED " + str(profile.arena_seed)
	arena_weapon_button.text = "LOADOUT: " + str(Data.WEAPONS[int(profile.arena_weapon)].name)
	if state.schema == 2:
		_campaign_ui(p)
	var dock_action: bool = state.phase == "playing" and p.distance_to(Rules.pad(state)) <= 1.8 and (state.schema == 2 or state.tier == 0)
	buy_button.visible = dock_action
	bottom_panel.offset_top = -222 if dock_action else -105
	notice.offset_top = -365 if dock_action else -235
	notice.offset_bottom = -235 if dock_action else -117
	if not dock_action and state.phase == "playing" and state.hp < 45:
		objective.text += " • DOCK: FREE REPAIR" if state.schema == 2 else " • DOCK: FORGE / HEAL"
	if phase_seen != state.phase:
		phase_seen = state.phase
		if state.phase != "playing":
			_stop()
			Campaign.record(profile, state)
			_save()
	if last_dead != state.dead.size():
		last_dead = state.dead.size()
		_tone(620)
	if state.hp < last_hp:
		_tone(115)
	last_hp = state.hp

func _campaign_ui(p: Vector2) -> void:
	var d: Dictionary = state.definition
	title.text = str(d.island)
	objective.text = "%02d/12 %s • WAVE %d/%d" % [int(d.stage) + 1, d.title, int(state.wave) + 1, int(d.waves)]
	var price := Rules.cost(state)
	buy_button.disabled = not (state.phase == "playing" and p.distance_to(Rules.pad(state)) <= 1.8 and int(state.wallet) >= price)
	buy_button.text = "FORGE %s • %d • HEAL" % [d.weapons[int(state.tier) + 1].name, price] if price > 0 else "DOCK REPAIR • FREE • FULL HULL"
	if p.distance_to(Rules.pad(state)) > 1.8:
		buy_button.text = "RETURN TO DOCK ↓ " + ("FORGE • " + str(price) if price > 0 else "REPAIR")
	notice.text = save_error if not save_error.is_empty() else (state.notice if state.notice_left > 0 else d.lesson)
	if state.blocked > 0:
		notice.text = "FRONT ARMOR • bait a swing, then flank during recovery"
	terminal_title.text = "PASSAGE RESTORED" if state.phase == "victory" else "HULL BREACHED"
	terminal_body.text = "%s is clear.\n%d salvage • %d hits • %d rescues\nThe next harbor passage is open." % [d.title, state.wallet, state.hits, state.deaths] if state.phase == "victory" else "Your weapon, earned salvage and cleared foes are retained. Surviving foes recover their hull."
	if int(d.stage) == 11 and not d.arena:
		terminal_title.text = "HOMEWARD LIGHTS" if state.phase == "victory" else "HULL BREACHED"
		if state.phase == "victory":
			terminal_body.text = "All four beacons burn. The fleet sails home through Glasswater.\nYour voyage is complete. The harbor arena is open for new seeds and loadouts."
		continue_button.text = "HARBOR / REPLAY"
	if d.arena:
		objective.text = "ARENA %d • %s • WAVE %d/%d" % [d.seed, Rules.weapon(state).name, int(state.wave) + 1, d.waves]
		continue_button.text = "RETURN TO HARBOR"

func _campaign_world() -> void:
	var nodes := preload("res://scripts/campaign_world.gd").build(self, state)
	camera = nodes.camera
	player = nodes.player
	preview = nodes.preview
	gate = nodes.gate
	pad_ring = nodes.pad
	reach_ring = nodes.reach
	chain = nodes.chain
	audio = AudioStreamPlayer.new()
	add_child(audio)

func _rebuild() -> void:
	_stop()
	for child in get_children():
		if child is Node3D:
			child.free()
	if is_instance_valid(audio):
		audio.stop()
		audio.free()
	actors.clear()
	drops.clear()
	projectiles.clear()
	chain.clear()
	weapon_node = null
	shown_tier = -1
	phase_seen = ""
	last_dead = state.dead.size()
	last_hp = state.hp
	_world()

func _continue() -> void:
	if state.phase != "victory":
		return
	Campaign.record(profile, state)
	if state.schema == 2 and state.definition.arena:
		state = profile.ending.duplicate(true)
		profile.ending = {}
	elif int(profile.stage) == 11:
		paused = true
		menu.visible = true
		_sync()
		_save()
		return
	else:
		profile.stage += 1
		state = Campaign.fresh(int(profile.stage), int(state.tier), int(state.wallet))
	paused = false
	menu.visible = false
	_rebuild()
	_sync()
	_save()

func _cycle_seed() -> void:
	profile.arena_seed = 1701 + (int(profile.arena_seed) - 1700) % 20
	_sync()
	_save()

func _cycle_weapon() -> void:
	profile.arena_weapon = 1 + int(profile.arena_weapon) % 3
	_sync()
	_save()

func _arena() -> void:
	if not profile.completed or state.schema == 2 and state.definition.arena:
		return
	profile.ending = state.duplicate(true)
	state = Campaign.fresh(11, int(profile.arena_weapon), 0, int(profile.arena_seed), true)
	paused = false
	menu.visible = false
	_rebuild()
	_sync()
	_save()

func _buy() -> void:
	if Rules.purchase(state):
		_tone(880)
		_save()
	_sync()

func _retry() -> void:
	if Rules.retry(state):
		_stop()
		_save()
	_sync()

func _toggle_menu() -> void:
	paused = not paused
	menu.visible = paused
	menu_button.text = "MENU" if paused else "PAUSE"
	_stop()
	_save()
	_sync()

func _transfer(action: String) -> void:
	if action == "EXPORT":
		transfer.text = Store.encode(state, settings, 0, true, profile)
		transfer.select_all()
		if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			DisplayServer.clipboard_set(transfer.text)
			transfer_status.text = "Copied save code to clipboard. Keep a private backup." if DisplayServer.clipboard_get() == transfer.text else "Exported in this field. Clipboard unavailable; copy the selected code."
		else:
			transfer_status.text = "Exported in this field. Clipboard unavailable on this display."
	elif action == "PASTE":
		if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			transfer.text = DisplayServer.clipboard_get()
		else:
			transfer_status.text = "Clipboard unavailable on this display. Type a save code here."
	else:
		var imported := Store.decode(transfer.text)
		if not imported.ok:
			transfer_status.text = "Invalid save. Current progress retained."
		elif not Store.write(imported.state, imported.settings, Store.PATH, null, true, imported.profile):
			transfer_status.text = "Storage failed. Current progress retained."
		else:
			state = imported.state
			profile = imported.profile
			_rebuild()
			settings = imported.settings
			sound_toggle.set_pressed_no_signal(settings.sound)
			effects_toggle.set_pressed_no_signal(settings.reduced_effects)
			transfer_status.text = "Imported. Resume when ready."
			_sync()

func _save() -> bool:
	var okay := Store.write(state, settings, Store.PATH, null, false, profile)
	save_error = "" if okay else "SAVE FAILED • progress is still in memory. Export a copy."
	return okay

func _tone(frequency: int) -> void:
	if not settings.sound or DisplayServer.get_name() == "headless":
		return
	if not sound_cache.has(frequency):
		var data := PackedByteArray()
		data.resize(4410)
		for i in 2205:
			var sample := sin(float(i) / 22050 * frequency * TAU) * pow(1.0 - float(i) / 2205, 2) * 2500
			data.encode_s16(i * 2, int(sample))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		sound_cache[frequency] = stream
	audio.stream = sound_cache[frequency]
	audio.play()

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
	sound_cache.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not is_instance_valid(menu):
			return
		paused = true
		menu.visible = true
		_stop()
		_save()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()
