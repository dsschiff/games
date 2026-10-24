extends Node3D
const Rules = preload("res://scripts/engine.gd")
const Campaign = preload("res://scripts/campaign_rules.gd")
const Data = preload("res://scripts/campaign_data.gd")
const Store = preload("res://scripts/save_store.gd")
const Presentation = preload("res://scripts/presentation/adapter.gd")
var presentation: Node3D
var ui_root: Control
var top_panel: PanelContainer

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
var save_io: Variant = null
var camera: Camera3D
var player: Node3D
var weapon_node: Node3D
var preview: Node3D
var gate: Node3D
var pad_ring: MeshInstance3D
var reach_ring: MeshInstance3D
var actors := {}
var drops := {}
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
	var loaded := Store.read(Store.PATH, save_io)
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
	presentation = Presentation.new()
	add_child(presentation)
	presentation.build(state)
	camera = presentation.island.camera
	player = presentation.player
	preview = presentation.island.preview
	gate = presentation.island.gate
	pad_ring = presentation.island.pad
	reach_ring = presentation.reach
	actors = presentation.actors
	drops = presentation.drops
	projectiles = presentation.projectiles
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
	ui_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	stick = preload("res://scripts/stick.gd").new()
	stick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stick)
	var top := PanelContainer.new()
	top_panel = top
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

func _input(event: InputEvent) -> void:
	# A tracked finger can finish over a GUI panel. Releases must reach movement
	# ownership before the GUI consumes them; new presses still use unhandled input.
	if event is InputEventScreenTouch and not event.pressed and event.index == finger:
		_stop()
	elif event is InputEventScreenDrag and event.index == finger and dragging and not paused:
		movement = (event.position - drag_start) / 75.0
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and finger == -1 and dragging:
		_stop()

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
	presentation.present(delta)
	_layout()

func _sync() -> void:
	var p := Rules.position(state)
	var viewport := get_viewport().get_visible_rect().size
	# Close tilted follow: the full weapon reach always fits across the narrow
	# axis at the diver's depth; otherwise the camera stays near and heroic.
	var half_wide := atan(tan(deg_to_rad(camera.fov * .5)) * maxf(.3, viewport.x / viewport.y))
	var distance := maxf(20.5, (float(Rules.weapon(state).reach) + .45) / tan(half_wide))
	var focus := Vector3(p.x, 0, p.y - 2.2)
	camera.position = focus + Vector3(0, sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0))) * distance
	camera.look_at(focus)
	presentation.reduced = settings.reduced_effects
	presentation.set_paused(paused, state)
	presentation.capture(state)
	shown_tier = int(state.tier)
	weapon_node = presentation.weapons[shown_tier]
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
		presentation.hydrate(state)
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
		elif not Store.write(imported.state, imported.settings, Store.PATH, save_io, true, imported.profile):
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
	var okay := Store.write(state, settings, Store.PATH, save_io, false, profile)
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

func _layout() -> void:
	if not is_instance_valid(ui_root):
		return
	var extent := get_viewport().get_visible_rect().size
	var safe := Rect2(Vector2.ZERO, extent)
	if DisplayServer.get_name() != "headless" and OS.get_name() == "Android":
		var physical := Rect2(DisplayServer.get_display_safe_area())
		var inverse := get_viewport().get_screen_transform().affine_inverse()
		if physical.size.x > 0 and physical.size.y > 0:
			safe = Rect2(inverse * physical.position, physical.size / get_viewport().get_screen_transform().get_scale()).intersection(safe)
	var left := maxf(24, safe.position.x + 18)
	var right := maxf(24, extent.x - safe.end.x + 18)
	var upper := maxf(24, safe.position.y + 16)
	var lower := maxf(24, extent.y - safe.end.y + 16)
	top_panel.offset_left = left
	top_panel.offset_right = -right
	top_panel.offset_top = upper
	bottom_panel.offset_left = left
	bottom_panel.offset_right = -right
	bottom_panel.offset_bottom = -lower
	var dock := buy_button.visible
	bottom_panel.offset_top = -lower - (194 if dock else 90)
	var width := minf(680, safe.size.x - 48)
	var height := minf(820, safe.size.y - 64)
	menu.offset_left = safe.get_center().x - extent.x * .5 - width * .5
	menu.offset_right = menu.offset_left + width
	menu.offset_top = safe.get_center().y - extent.y * .5 - height * .5
	menu.offset_bottom = menu.offset_top + height
	terminal.offset_left = safe.get_center().x - extent.x * .5 - minf(640, safe.size.x - 48) * .5
	terminal.offset_right = terminal.offset_left + minf(640, safe.size.x - 48)
	terminal.offset_top = -minf(540, safe.size.y - 64) * .5
	terminal.offset_bottom = -terminal.offset_top
	var base_y := bottom_panel.get_rect().position.y
	notice.offset_left = maxf(220, left)
	notice.offset_right = -right
	notice.offset_top = base_y - extent.y - 136
	notice.offset_bottom = base_y - extent.y - 12
	stick.active = dragging
	stick.origin = drag_start
	stick.direction = movement
	stick.rest_origin = Vector2(left + 86, base_y - 82)
	stick.queue_redraw()
	# Dock signs have a fixed modeled anchor, but their screen labels clear both
	# the rest stick and the actual floating control, including resized canvases.
	var sign: Label3D = presentation.island.dock_label
	sign.position = Vector3(0, 2.55, 6.8)
	var origin: Vector2 = drag_start if dragging else stick.rest_origin
	var projected := camera.unproject_position(sign.global_position)
	if projected.distance_to(origin) < 170:
		sign.position.x = 2.6
