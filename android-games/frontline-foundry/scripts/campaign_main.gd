extends "res://scripts/main.gd"
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")
var career := C.career()
var support_panel: Panel
var journey: Panel
var seed_panel: Panel
var briefing: Panel
var next_button: Button
var support_button: Button
var ending_label: Label
var journey_list: VBoxContainer
var seed_label: Label
var seed_value := 137
var seed_style := "mixed"
var hit_flashes := {}
var relay_labels: Array = []
var mark_nodes: Array = []
var whole_world: Node3D
var hq_marker: Node3D

func _ready() -> void:
	var saved := S.read()
	state = C.fresh(D.mission(0))
	if saved.ok and saved.state.catalog == 2:
		state = saved.state
		profile = saved.profile
		settings = saved.settings
		career = saved.career
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
	if whole_world != null:
		whole_world.queue_free()
	whole_world = Node3D.new()
	add_child(whole_world)
	pad_labels.clear()
	station_nodes.clear()
	recruit_nodes.clear()
	enemy_nodes.clear()
	coin_nodes.clear()
	relay_labels.clear()
	mark_nodes.clear()
	bolts.clear()
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("142b3b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e0f5f0")
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	whole_world.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -25, 0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	whole_world.add_child(sun)
	camera = Camera3D.new()
	whole_world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 19, 16)
	camera.look_at(Vector3(0, 0, 0.8))
	camera.current = true
	var district := int(state.definition.index)
	box(whole_world, Vector3(0, -0.3, -0.1), Vector3(11.2, 0.6, 15.2), ["567c7e", "6e7586", "64786d", "86765f"][district % 4])
	box(whole_world, Vector3(0, -0.65, -0.1), Vector3(11.5, 0.3, 15.5), "25394e")
	box(whole_world, Vector3(0, 0.015, -3.9), Vector3(10.4, 0.03, 6.2), ["afbea7", "b5b4b0", "b0bdb8", "c6b69a"][district % 4])
	for x in [-3.5, 0.0, 3.5]:
		box(whole_world, Vector3(x, 0.045, -3.2), Vector3(0.65, 0.03, 6.4), "869c98")
	for side in [-1, 1]:
		# The only opaque front boundary has a clear central deployment gate.
		for i in 4:
			box(whole_world, Vector3(side * (1.5 + i * 0.9), 0.3, -0.35), Vector3(0.8, 0.55, 0.6), "d9c79b")
		for i in 6:
			box(whole_world, Vector3(side * 5.2, 0.25, -6 + i * 2.3), Vector3(0.25, 0.5, 0.7), "adc8c0")
		var landmark_z := -5.6 + (district % 3) * 0.6
		box(whole_world, Vector3(side * 4.7, 0.4, landmark_z), Vector3(0.65, 0.8, 0.7), "5c7779")
	hq_marker = Node3D.new()
	whole_world.add_child(hq_marker)
	hq_marker.position = Vector3(0, 0, 6.1)
	box(hq_marker, Vector3(0, 0.6, 0), Vector3(3.2, 1.2, 0.9), "2b7975")
	box(hq_marker, Vector3(0, 1.3, 0), Vector3(3.5, 0.2, 1.1), "52a98f")
	label3(hq_marker, "HQ", Vector3(0, 1.9, 0), "d5fff2", 28)
	cylinder(whole_world, Vector3(0, 0.35, 0.6), 0.28, 0.65, "526778")
	box(whole_world, Vector3(0, 0.8, 0.3), Vector3(0.14, 0.14, 0.6), "e7cb7c")
	for i in 5:
		var p := D.pad(state.definition, i)
		box(whole_world, Vector3(p.x, 0.08, p.y), Vector3(1.45, 0.16, 1.1), "d2ba72")
		box(whole_world, Vector3(p.x, 0.18, p.y), Vector3(1.25, 0.1, 0.9), "275c60")
		var station := Node3D.new()
		whole_world.add_child(station)
		station.position = Vector3(p.x, 0.22, p.y)
		box(station, Vector3(0, 0.3, 0), Vector3(0.8, 0.45, 0.4), "3b9e8d")
		box(station, Vector3(0, 0.6, 0), Vector3(0.9, 0.1, 0.6), "e2cb83")
		station_nodes.append(station)
		var l := label3(whole_world, "", Vector3(p.x, 1.4, p.y - 0.3), "ffe1a0", 28)
		pad_labels.append(l)
	for i in state.definition.relays.size():
		var point := Vector2(state.definition.relays[i][0], state.definition.relays[i][1])
		cylinder(whole_world, Vector3(point.x, 0.05, point.y), 0.7, 0.1, "7289a6")
		box(whole_world, Vector3(point.x, 0.8, point.y), Vector3(0.1, 1.6, 0.1), "d2e0d5")
		var l := label3(whole_world, "RELAY", Vector3(point.x, 2, point.y), "bce9ff", 29)
		relay_labels.append(l)
	actors = Node3D.new()
	whole_world.add_child(actors)
	avatar = soldier(actors, "e4b55e")
	cylinder(avatar, Vector3(0, 0.02, 0), 0.45, 0.04, "ffe393")
	for r in state.recruits:
		var n: Node3D
		if r.role == "rover":
			n = Node3D.new()
			actors.add_child(n)
			box(n, Vector3(0, 0.4, 0), Vector3(0.85, 0.6, 1.2), "329585")
			for x in [-0.5, 0.5]:
				box(n, Vector3(x, 0.2, 0), Vector3(0.25, 0.35, 1.4), "273944")
			var gun := box(n, Vector3(0, 0.85, -0.4), Vector3(0.2, 0.2, 1.25), "e2cb83")
			gun.name = "Weapon"
		else:
			n = soldier(actors, {"rifle": "35a995", "breaker": "a68e54", "ranger": "5299b5"}[r.role])
			if r.role == "breaker":
				box(n, Vector3(-0.3, 0.6, 0), Vector3(0.35, 0.3, 0.65), "ddbc6f")
			if r.role == "ranger":
				box(n, Vector3(0.35, 0.7, -0.35), Vector3(0.1, 0.1, 0.7), "829fbe")
		var l := label3(n, "", Vector3(0, 1.55, 0), "c4ffec", 24)
		l.name = "Status"
		recruit_nodes.append(n)

func make_ui() -> void:
	super.make_ui()
	for child in menu.get_children():
		if child is Button and child.text == "BEGIN CAMPAIGN":
			child.free()
		elif child is Button and child.text == "SAVE / TRANSFER":
			child.set_meta("row", 6)
	support_button = button(menu, "SORTIE KIT / SUPPORT", open_support)
	support_button.set_meta("row", 3)
	var b := button(menu, "JOURNEY / RECORDS", enter_campaign)
	b.set_meta("row", 4)
	b = button(menu, "SEEDED SKIRMISH", open_seed)
	b.set_meta("row", 5)
	guidance.add_theme_font_size_override("font_size", 24)
	next_button = button(terminal, "NEXT MISSION", next_mission)
	next_button.position = Vector2(24, 395)
	next_button.size = Vector2(572, 96)
	briefing = panel(ui)
	label(briefing, "SORTIE BRIEF", Vector2(24, 18), Vector2(560, 45), 32, "ffe1a0")
	var text := label(briefing, state.definition.forecast, Vector2(24, 75), Vector2(560, 150), 27)
	text.name = "Forecast"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text = label(briefing, "", Vector2(24, 240), Vector2(560, 180), 25)
	text.name = "Rules"
	text.add_theme_font_size_override("font_size", 24)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b = button(briefing, "SORTIE KIT / SUPPORT", open_support)
	b.position = Vector2(24, 440)
	b.size = Vector2(572, 96)
	support_panel = panel(ui)
	label(support_panel, "CHOOSE ONE SUPPORT", Vector2(24, 20), Vector2(560, 45), 32, "ffe1a0")
	label(support_panel, "Selection is free. Build at the center pad for 14.\nOne building per sortie; Retry permits a new kit.", Vector2(24, 70), Vector2(572, 80), 24)
	var row := 0
	for key in D.SUPPORT:
		b = button(support_panel, key.to_upper(), choose_support.bind(key))
		b.position = Vector2(24, 160 + row * 135)
		b.size = Vector2(572, 96)
		var l := label(support_panel, D.SUPPORT[key].split(": ")[1], Vector2(24, 258 + row * 135), Vector2(572, 33), 21)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row += 1
	b = button(support_panel, "CLOSE", close_modals)
	b.position = Vector2(24, 585)
	b.size = Vector2(572, 96)
	support_panel.hide()
	journey = panel(ui)
	ending_label = label(journey, "", Vector2(24, 20), Vector2(572, 105), 27, "ffe1a0")
	ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 135)
	scroll.size = Vector2(572, 555)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journey.add_child(scroll)
	journey_list = VBoxContainer.new()
	journey_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journey_list.add_theme_constant_override("separation", 8)
	scroll.add_child(journey_list)
	b = button(journey, "CLOSE", close_modals)
	b.position = Vector2(24, 710)
	b.size = Vector2(572, 96)
	journey.hide()
	seed_panel = panel(ui)
	label(seed_panel, "DETERMINISTIC SKIRMISH", Vector2(24, 20), Vector2(572, 45), 30, "ffe1a0")
	seed_label = label(seed_panel, "", Vector2(24, 80), Vector2(572, 70), 32)
	for spec in [["SEED -1", -1], ["SEED +1", 1]]:
		b = button(seed_panel, spec[0], change_seed.bind(spec[1]))
		b.position = Vector2(24 if spec[1] == -1 else 320, 160)
		b.size = Vector2(276, 96)
	row = 0
	for key in ["mixed", "flank", "siege"]:
		b = button(seed_panel, key.to_upper(), choose_style.bind(key))
		b.position = Vector2(24 + row * 194, 280)
		b.size = Vector2(184, 96)
		row += 1
	label(seed_panel, "Same seed/style pins the full encounter.\nFlank: relays and rushers. Siege: mortar crews.\nRecords stay separate from the campaign.", Vector2(24, 410), Vector2(572, 130), 25)
	b = button(seed_panel, "START SKIRMISH", start_seed)
	b.position = Vector2(24, 560)
	b.size = Vector2(572, 96)
	b = button(seed_panel, "CLOSE", close_modals)
	b.position = Vector2(24, 675)
	b.size = Vector2(572, 96)
	seed_panel.hide()

func layout() -> void:
	if support_panel == null:
		return
	super.layout()
	var view := get_viewport().get_visible_rect().size
	camera.size = maxf(21, 12.4 * view.y / view.x)
	menu.position.y = 235
	menu.size.y = 880
	terminal.size.y = 515
	terminal_detail.add_theme_font_size_override("font_size", 24)
	for p in [support_panel, journey, seed_panel]:
		p.position = Vector2((view.x - 620) / 2, 235)
		p.size = Vector2(620, 710 if p == support_panel else 830)
	briefing.position = Vector2((view.x - 620) / 2, 300)
	briefing.size = Vector2(620, 560)

func begin() -> void:
	state.phase = "playing"
	paused = false
	menu.hide()
	stop_move()
	save_now()
	refresh()

func retry() -> void:
	var support: String = state.planned_support
	state = C.fresh(state.definition)
	state.planned_support = support
	paused = false
	stop_move()
	menu.hide()
	terminal.hide()
	make_world()
	layout()
	save_now()
	refresh()

func build_nearby() -> void:
	if not paused and C.buy(state, C.nearby(state)):
		tone(480, 0.18)
		save_now()
		refresh()

func enter_campaign() -> void:
	paused = true
	stop_move()
	menu.hide()
	for child in journey_list.get_children():
		child.free()
	ending_label.text = "THE FOUNDRY IS FREE\nTwelve districts liberated. Replay for medals or skirmish." if career.ending else "JOURNEY  %d / 12\nSelecting resets this sortie; earned records stay." % career.clears.size()
	for i in 12:
		var id: String = D.IDS[i]
		var medal := int(career.clears.get(id, 0))
		var b := button(journey_list, "%02d  %s   %s" % [i + 1, D.TITLES[i], "*".repeat(medal)], select_mission.bind(i))
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(560, 96)
		b.disabled = i > career.clears.size()
	journey.show()
	refresh()

func select_mission(index: int) -> void:
	if index > career.clears.size():
		return
	start_definition(D.mission(index))

func start_definition(definition: Dictionary) -> void:
	state = C.fresh(definition)
	paused = false
	stop_move()
	for p in [menu, journey, support_panel, seed_panel, transfer]:
		p.hide()
	make_world()
	layout()
	save_now()
	refresh()

func next_mission() -> void:
	if state.definition.mode == "campaign" and state.definition.index < 11:
		select_mission(int(state.definition.index) + 1)
	else:
		enter_campaign()

func open_support() -> void:
	paused = true
	stop_move()
	menu.hide()
	support_panel.show()
	refresh()

func choose_support(key: String) -> void:
	if state.support == "none":
		state.planned_support = key
		save_now()
	close_modals()

func open_seed() -> void:
	paused = true
	stop_move()
	menu.hide()
	seed_panel.show()
	seed_label.text = "SEED %06d  /  %s" % [seed_value, seed_style.to_upper()]
	refresh()

func change_seed(amount: int) -> void:
	seed_value = clampi(seed_value + amount, 0, 999999)
	seed_label.text = "SEED %06d  /  %s" % [seed_value, seed_style.to_upper()]

func choose_style(key: String) -> void:
	seed_style = key
	change_seed(0)

func start_seed() -> void:
	start_definition(D.skirmish(seed_value, seed_style))

func close_modals() -> void:
	for p in [support_panel, journey, seed_panel]:
		p.hide()
	menu.visible = state.phase != "ready"
	paused = state.phase != "ready"
	refresh()

func back() -> void:
	if support_panel.visible or journey.visible or seed_panel.visible:
		close_modals()
	else:
		super.back()

func save_now() -> bool:
	var okay := S.write(state, profile, settings, S.PATH, save_io, false, career)
	save_problem = not okay
	return okay

func open_transfer() -> void:
	super.open_transfer()
	code_edit.text = S.encode(state, profile, settings, 0, true, career)

func copy_code() -> void:
	code_edit.text = S.encode(state, profile, settings, 0, true, career)
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		code_edit.select_all()
		notice.text = "Clipboard unavailable. Select and copy the code."
		return
	DisplayServer.clipboard_set(code_edit.text)
	code_edit.select_all()
	notice.text = "Checking clipboard..."
	# Windows clipboard history can briefly hold the newly written clipboard open.
	await get_tree().create_timer(0.08, true, false, true).timeout
	notice.text = "Code copied." if DisplayServer.clipboard_get() == code_edit.text else "Copy unconfirmed. Select and copy the code."

func import_code() -> void:
	var decoded := S.decode(code_edit.text)
	if not decoded.ok:
		notice.text = "Invalid code. Entire current save kept."
		return
	if not S.write(decoded.state, decoded.profile, decoded.settings, S.PATH, save_io, true, decoded.career):
		notice.text = "Storage failed. Entire current save kept."
		return
	if decoded.state.catalog == 1:
		get_tree().change_scene_to_file("res://boot.tscn")
		return
	state = decoded.state
	profile = decoded.profile
	settings = decoded.settings
	career = decoded.career
	make_world()
	layout()
	close_transfer()
	sync_world(0)
	refresh()

func _physics_process(delta: float) -> void:
	if not paused and state.phase == "playing":
		var events := C.tick(state, input_vector, delta)
		for e in events:
			event_log.append({"mission": state.definition.id, "time": state.time, "event": e})
			if e.kind in ["shot", "incoming", "warning", "repair"]:
				make_bolt(e)
				if e.kind == "incoming":
					hit_flashes[int(e.recipient)] = 0.2
					tone(100, 0.07)
			elif e.kind == "equip":
				tone(420, 0.12)
			elif e.kind == "pickup":
				tone(780, 0.07)
		if state.phase != "playing":
			C.finish(state, career)
			save_now()
			tone(550 if state.phase == "victory" else 90, 0.4)
		save_clock += delta
		if save_clock >= 1:
			save_clock = 0
			save_now()
	sync_world(delta if not paused else 0)
	refresh()
	fill_audio()

func refresh() -> void:
	if support_panel == null:
		return
	var d: Dictionary = state.definition
	(head.get_child(0) as Label).text = "%02d  %s" % [int(d.index) + 1, d.title.to_upper()] if d.mode == "campaign" else d.title.to_upper()
	(head.get_child(0) as Label).add_theme_font_size_override("font_size", 25)
	wallet_label.text = "SCRAP %d    /    KIT %s" % [state.wallet, state.planned_support.to_upper()]
	wallet_label.add_theme_font_size_override("font_size", 27)
	status_label.text = "YOU %d / %d    •    HQ %d / %d" % [state.hp, d.commander_hp, state.hq, d.hq]
	status_label.add_theme_font_size_override("font_size", 25)
	wave_label.text = "%d/%d STOPPED  •  %d ESCAPED  •  %.0fs" % [state.killed.size(), d.schedule.size(), state.escaped.size(), state.time]
	if save_problem:
		wave_label.text = "SAVE FAILED • Pause and export a local code"
	queue_label.text = "FRONT %d/%d   •   EQUIPPED %d   •   %s" % [C.active_count(state), d.cap, state.consumed.reduce(func(a, b): return a + b, 0), state.support.to_upper()]
	journal.text = "%d / 12 districts  •  %d wins / %d sorties" % [career.clears.size(), career.victories, career.attempts]
	sound_button.text = "SOUND  " + ("ON" if settings.sound else "OFF")
	effects_button.text = "REDUCED EFFECTS  " + ("ON" if settings.reduced_effects else "OFF")
	var modal: bool = transfer.visible or journey.visible or support_panel.visible or seed_panel.visible
	briefing.visible = state.phase == "ready" and not paused and not modal
	(briefing.get_node("Forecast") as Label).text = d.forecast
	(briefing.get_node("Rules") as Label).text = "Objective: " + C.objective_text(state) + "\n\nRifle 7: general • Breaker 10: armor\nRanger 10: artillery • Rover 18: groups\nFinite crews. Collect scrap; replace losses."
	start_button.visible = state.phase == "ready" and not paused and not modal
	start_button.text = "LAUNCH SORTIE"
	stick.visible = state.phase == "playing" and not paused
	build_button.visible = state.phase == "playing" and not paused
	var station := C.nearby(state)
	build_button.disabled = not C.can_buy(state, station)
	if station == 4:
		build_button.text = "BUILD %s • 14" % state.planned_support.to_upper() if state.support == "none" else "SUPPORT BUILT"
	elif station >= 0:
		var role: String = D.ROLES[station]
		build_button.text = "EQUIP %s • %d" % [role.to_upper(), d.unit[role].cost]
		if role not in d.available:
			build_button.text = "ROLE IN NEXT DISTRICT"
		elif state.bought[station] == d.pool[station]:
			build_button.text = "CREW POOL EXHAUSTED"
		elif C.active_count(state) >= d.cap:
			build_button.text = "FRONT FULL • %d" % d.cap
	else:
		build_button.text = "APPROACH EQUIPMENT"
	var next := "All reinforcements have arrived"
	if state.spawned < d.schedule.size():
		var arrival: Dictionary = d.schedule[int(state.spawned)]
		next = "Next: %s in %.0fs" % [arrival.role.to_upper(), maxf(0, arrival.at - state.time)]
	guidance.text = C.objective_text(state).capitalize() + "\n" + next
	guidance.visible = state.phase == "playing" and not paused
	terminal.visible = state.phase in ["victory", "defeat"] and not paused
	if terminal.visible:
		terminal_title.text = "FOUNDRY LIBERATED" if career.ending and d.id == "foundry_liberation" and state.phase == "victory" else ("DISTRICT SECURED" if state.phase == "victory" else "SORTIE LOST")
		terminal_title.add_theme_font_size_override("font_size", 31)
		terminal_detail.text = "%s\n%d stopped / %d escaped • %.0fs\nScrap spent %d • crews equipped %d\n%s" % [state.cause, state.killed.size(), state.escaped.size(), state.time, state.spent, state.consumed.reduce(func(a, b): return a + b, 0), "Mortars/Storm: Rangers, Breakers and Ward help." if state.last_hurt in ["mortar", "storm"] else "Retry restocks crews. Refit support before Launch."]
		next_button.visible = state.phase == "victory"
		next_button.text = "LIBERATION JOURNAL" if d.id == "foundry_liberation" else ("NEXT MISSION" if d.mode == "campaign" else "JOURNEY / RECORDS")
	pause_button.disabled = modal
	guidance.visible = guidance.visible and not terminal.visible

func sync_world(dt: float) -> void:
	if actors == null:
		return
	avatar.position = Vector3(state.x, 0.08, state.z)
	avatar.scale = Vector3.ONE * (1.12 if hit_flashes.get(-1, 0) > 0 and not settings.reduced_effects else 1.0)
	hq_marker.scale = Vector3.ONE * (1.04 if hit_flashes.get(-2, 0) > 0 and not settings.reduced_effects else 1.0)
	for id in hit_flashes.keys():
		hit_flashes[id] = maxf(0, hit_flashes[id] - dt)
	for i in 5:
		var price: int = state.definition.support_cost if i == 4 else state.definition.unit[D.ROLES[i]].cost
		pad_labels[i].text = (state.planned_support.left(4).to_upper() if i == 4 else D.ROLES[i].to_upper()) + " " + str(price)
		station_nodes[i].visible = state.support != "none" if i == 4 else state.bought[i] > 0
	for r in state.recruits:
		var n: Node3D = recruit_nodes[int(r.id)]
		var role_index: int = D.ROLES.find(r.role)
		var head_waiting := true
		for other in state.recruits:
			if other.role == r.role and other.id < r.id and other.phase == "waiting":
				head_waiting = false
		n.visible = r.phase != "fallen" and r.role in state.definition.available
		n.position = Vector3(r.x, 0.1, r.z)
		n.scale = Vector3.ONE * (1.1 if hit_flashes.get(int(r.id), 0) > 0 and not settings.reduced_effects else 1.0)
		n.get_node("Weapon").visible = r.phase != "waiting"
		var status: Label3D = n.get_node("Status")
		status.text = ("?" if head_waiting else "") if r.phase == "waiting" else ("ARMING" if r.phase == "equipping" else (str(int(ceil(r.hp))) if r.phase == "fighting" else ""))
		status.visible = r.phase != "waiting" or head_waiting
		if r.phase == "fighting":
			status.position = Vector3(-0.32 if int(r.slot) % 2 == 0 else 0.32, 1.55, 0)
	for i in relay_labels.size():
		relay_labels[i].text = "RELAY %d%%" % int(100 * state.captures[i] / state.definition.capture_seconds)
	var alive := {}
	for e in state.enemies:
		var id := int(e.id)
		alive[id] = true
		if not enemy_nodes.has(id):
			var n := Node3D.new()
			actors.add_child(n)
			var boss: bool = e.role in ["drill", "carrier", "storm"]
			var body := Vector3(1.2, 1.1, 1.4) if boss else Vector3(0.6, 0.6, 0.65)
			box(n, Vector3(0, body.y * 0.5, 0), body, {"drone": "ad5a4a", "runner": "d18b50", "bulwark": "8a607b", "mortar": "9d7955", "sapper": "b45562", "jammer": "877cb5", "drill": "6e556b", "carrier": "755b81", "storm": "8c648b"}[e.role])
			if e.role in ["mortar", "storm"]:
				box(n, Vector3(0, body.y + 0.1, -0.25), Vector3(0.2, 0.2, 0.8), "e5c798")
			if e.role == "jammer":
				cylinder(n, Vector3(0, 1.0, 0), 0.35, 0.1, "c4a8f0")
			if e.role == "drill":
				cylinder(n, Vector3(0, 0.7, 0.7), 0.4, 0.7, "e2b087")
			if e.role == "carrier":
				box(n, Vector3(0, 1.4, 0), Vector3(0.7, 0.25, 0.5), "a4c3b2")
			var l := label3(n, "", Vector3(0, body.y + 0.5, 0), "ffe1b8", 24 if not boss else 31)
			l.name = "Health"
			enemy_nodes[id] = n
		var n: Node3D = enemy_nodes[id]
		n.position = Vector3(e.x, 0.1, e.z)
		(n.get_node("Health") as Label3D).text = (e.role.to_upper() + "\n" if e.role not in ["drone", "runner"] else "") + str(int(ceil(e.hp)))
	for id in enemy_nodes.keys():
		if not alive.has(id):
			enemy_nodes[id].queue_free()
			enemy_nodes.erase(id)
	var loose := {}
	for coin in state.coins:
		var id := int(coin.id)
		loose[id] = true
		if not coin_nodes.has(id):
			var n := Node3D.new()
			actors.add_child(n)
			cylinder(n, Vector3(0, 0.25, 0), 0.27, 0.12, "d9b54d")
			label3(n, "+" + str(int(coin.value)), Vector3(0, 0.9, 0), "ffe594", 26)
			coin_nodes[id] = n
		coin_nodes[id].position = Vector3(coin.x, 0.15, coin.z)
	for id in coin_nodes.keys():
		if not loose.has(id):
			coin_nodes[id].queue_free()
			coin_nodes.erase(id)
	for n in mark_nodes:
		n.queue_free()
	mark_nodes.clear()
	for mark in state.marks:
		var n := cylinder(actors, Vector3(mark.x, 0.06, mark.z), 1.25, 0.07, "b95365")
		mark_nodes.append(n)
	for i in range(bolts.size() - 1, -1, -1):
		bolts[i].life -= dt
		if bolts[i].life <= 0:
			bolts[i].node.queue_free()
			bolts.remove_at(i)
		else:
			bolts[i].node.position = bolts[i].from.lerp(bolts[i].to, 1 - bolts[i].life / 0.2)

func make_bolt(e: Dictionary) -> void:
	var from := Vector3(e.from[0], 0.9, e.from[1])
	var to := Vector3(e.to[0], 0.8, e.to[1])
	var color := "ed817c" if e.owner == "enemy" else ("a3b8ef" if e.owner == "carrier" else ("ffe69b" if e.owner == "commander" else "a4eed7"))
	var n := box(actors, from, Vector3(0.13, 0.13, 0.5), color)
	if not from.is_equal_approx(to):
		n.look_at(to)
	bolts.append({"node": n, "life": 0.2, "from": from, "to": to})
