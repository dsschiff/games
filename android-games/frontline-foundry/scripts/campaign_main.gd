extends "res://scripts/main.gd"
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")
const F = preload("res://scripts/reinforcement_feedback.gd")
var career := C.career()
var support_panel: Panel
var journey: Panel
var seed_panel: Panel
var briefing: Panel
var next_button: Button
var support_button: Button
var ending_label: Label
var record_criteria: Label
var journey_list: VBoxContainer
var seed_label: Label
var seed_value := 137
var seed_style := "mixed"
var hit_flashes := {}
var relay_labels: Array = []
var mark_nodes: Array = []
var whole_world: Node3D
var hq_marker: Node3D
var brief_forecast: Label
var brief_rules: Label
var hq_indicator: Label
var brief_scroll: ScrollContainer

func _ready() -> void:
	var saved := read_startup()
	state = C.fresh(D.mission(0))
	if saved.ok and saved.state.catalog == 2:
		state = saved.state
		profile = saved.profile
		settings = saved.settings
		career = saved.career
		paused = startup_paused or import_pending or state.phase == "playing"
	make_world()
	make_ui()
	get_viewport().size_changed.connect(layout)
	setup_audio()
	layout()
	sync_world(0)
	refresh()
	menu.visible = paused and not import_pending
	save_now()

func make_world() -> void:
	hit_flashes.clear()
	super.make_world()

func make_ui() -> void:
	super.make_ui()
	hq_indicator = label(ui, "", Vector2.ZERO, Vector2(230, 34), 23, "ffe1a0")
	hq_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hq_indicator.add_theme_color_override("font_outline_color", Color("253c35"))
	hq_indicator.add_theme_constant_override("outline_size", 6)
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
	brief_scroll = ScrollContainer.new()
	brief_scroll.position = Vector2(24, 78)
	brief_scroll.size = Vector2(572, 338)
	brief_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	briefing.add_child(brief_scroll)
	var brief_body := VBoxContainer.new()
	brief_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_body.add_theme_constant_override("separation", 22)
	brief_scroll.add_child(brief_body)
	brief_forecast = label(brief_body, "", Vector2.ZERO, Vector2.ZERO, 25)
	brief_rules = label(brief_body, "", Vector2.ZERO, Vector2.ZERO, 23)
	for text in [brief_forecast, brief_rules]:
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		var l := label(support_panel, D.SUPPORT[key].split(": ")[1], Vector2(24, 258 + row * 135), Vector2(572, 33), 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row += 1
	b = button(support_panel, "CLOSE", close_modals)
	b.position = Vector2(24, 585)
	b.size = Vector2(572, 96)
	support_panel.hide()
	journey = panel(ui)
	ending_label = label(journey, "", Vector2(24, 20), Vector2(572, 105), 27, "ffe1a0")
	ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record_criteria = label(journey, F.criteria(), Vector2(24, 132), Vector2(572, 86), 20)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 226)
	scroll.size = Vector2(572, 464)
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
	var seed_help := label(seed_panel, "Same seed and style recreate the encounter.\nFlank: relays and rushers. Siege: mortar crews.\nRecords stay separate from the campaign.", Vector2(24, 410), Vector2(572, 130), 24)
	seed_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	presentation.fit(view)
	# Footer links the last paid weapon to its individual recruit without hiding HQ.
	stick.position.y = view.y - 220
	build_button.position.y = view.y - 165
	guidance.position.y = view.y - 340
	guidance.size.y = 110
	# Edge cues clear the clamped HQ marker as well as the objective text.
	presentation.safe_bottom = view.y - guidance.position.y + 90.0
	guidance.add_theme_font_size_override("font_size", 23)
	if queue_label.get_parent() != ui:
		queue_label.reparent(ui)
	queue_label.position = Vector2(18, view.y - 48)
	queue_label.size = Vector2(view.x - 36, 36)
	queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_label.add_theme_font_size_override("font_size", 22)
	queue_label.add_theme_color_override("font_color", Color("253c35"))
	queue_label.add_theme_color_override("font_outline_color", Color("e3e7d3"))
	queue_label.add_theme_constant_override("outline_size", 4)
	menu.position.y = 235
	menu.size.y = 880
	terminal.size.y = 555
	terminal_detail.size.y = 230
	for child in terminal.get_children():
		if child is Button and child != next_button:
			child.position.y = 325
	next_button.position.y = 435
	terminal_detail.add_theme_font_size_override("font_size", 24)
	terminal_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for p in [support_panel, journey, seed_panel]:
		p.position = Vector2((view.x - 620) / 2, 235)
		p.size = Vector2(620, 710 if p == support_panel else 830)
	briefing.position = Vector2((view.x - 620) / 2, 300)
	briefing.size = Vector2(620, 560)

func stop_move() -> void:
	super.stop_move()
	if stick != null:
		stick.position.y = get_viewport().get_visible_rect().size.y - 220

func begin() -> void:
	if import_pending or cloud_held: return
	state.phase = "playing"
	paused = false
	menu.hide()
	stop_move()
	save_now()
	refresh()

func retry() -> void:
	if import_pending or cloud_held: return
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
	if import_pending or cloud_held: return
	paused = true
	stop_move()
	menu.hide()
	for child in journey_list.get_children():
		child.free()
	ending_label.text = "THE FOUNDRY IS FREE\nTwelve districts liberated. Replay for medals or skirmish." if career.ending else "JOURNEY  %d / 12\nSelecting resets this sortie; earned records stay." % career.clears.size()
	for i in 12:
		var b := button(journey_list, F.campaign_row(i, career), select_mission.bind(i))
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(560, 96)
		b.disabled = i > career.clears.size()
	if not career.skirmishes.is_empty():
		var heading := Label.new(); heading.text = "Skirmish results: latest clear per seed/style"
		heading.add_theme_font_size_override("font_size", 20); journey_list.add_child(heading)
		for key in career.skirmishes:
			var entry := Label.new(); entry.text = F.skirmish_row(key, career.skirmishes[key])
			entry.custom_minimum_size = Vector2(560, 48); entry.add_theme_font_size_override("font_size", 22)
			journey_list.add_child(entry)
	journey.show()
	refresh()

func select_mission(index: int) -> void:
	if import_pending or cloud_held: return
	if index > career.clears.size():
		return
	start_definition(D.mission(index))

func start_definition(definition: Dictionary) -> void:
	if import_pending or cloud_held: return
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
	if import_pending or cloud_held: return
	if state.definition.mode == "campaign" and state.definition.index < 11:
		select_mission(int(state.definition.index) + 1)
	else:
		enter_campaign()

func open_support() -> void:
	if import_pending or cloud_held: return
	paused = true
	stop_move()
	menu.hide()
	support_panel.show()
	refresh()

func choose_support(key: String) -> void:
	if import_pending or cloud_held: return
	if state.support == "none":
		state.planned_support = key
		save_now()
	close_modals()

func open_seed() -> void:
	if import_pending or cloud_held: return
	paused = true
	stop_move()
	menu.hide()
	seed_panel.show()
	seed_label.text = "SEED %06d  /  %s" % [seed_value, seed_style.to_upper()]
	refresh()

func change_seed(amount: int) -> void:
	if import_pending or cloud_held: return
	seed_value = clampi(seed_value + amount, 0, 999999)
	seed_label.text = "SEED %06d  /  %s" % [seed_value, seed_style.to_upper()]

func choose_style(key: String) -> void:
	if import_pending or cloud_held: return
	seed_style = key
	change_seed(0)

func start_seed() -> void:
	if import_pending or cloud_held: return
	start_definition(D.skirmish(seed_value, seed_style))

func close_modals() -> void:
	if import_pending or cloud_held: return
	for p in [support_panel, journey, seed_panel]:
		p.hide()
	menu.visible = state.phase != "ready"
	paused = state.phase != "ready"
	refresh()

func back() -> void:
	if import_pending or cloud_held: return
	if support_panel.visible or journey.visible or seed_panel.visible:
		close_modals()
	else:
		super.back()

func save_now() -> bool:
	if import_pending or cloud_held: return false
	var okay := S.write(state, profile, settings, S.PATH, save_io, false, career)
	save_problem = not okay
	return okay

func open_transfer() -> void:
	if cloud_held: return
	if import_pending: show_import_pending(); return
	super.open_transfer()
	code_edit.text = S.encode(state, profile, settings, 0, true, career)

func copy_code() -> void:
	if import_pending or cloud_held: return
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
	super.import_code()

func current_career() -> Dictionary:
	return career

func adopt_career(value: Dictionary) -> void:
	career = value.duplicate(true)

func _physics_process(delta: float) -> void:
	if not import_pending and not cloud_held and not paused and state.phase == "playing":
		var events := C.tick(state, input_vector, delta)
		presentation.queue_events(events)
		var heard := {}
		for e in events:
			event_log.append({"mission": state.definition.id, "time": state.time, "event": e})
			if e.kind in ["shot", "incoming", "warning", "repair"]:
				if e.kind == "incoming" and not heard.has(e.attack):
					heard[e.attack] = true
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
	wallet_label.text = "SCRAP %d    /    FRONT %d/%d" % [state.wallet, C.active_count(state), d.cap]
	wallet_label.add_theme_font_size_override("font_size", 27)
	status_label.text = "YOU %d / %d    •    HQ %d / %d" % [state.hp, d.commander_hp, state.hq, d.hq]
	status_label.add_theme_font_size_override("font_size", 25)
	wave_label.text = "%d/%d STOPPED  •  %d ESCAPED  •  %.0fs" % [state.killed.size(), d.schedule.size(), state.escaped.size(), state.time]
	if save_problem:
		wave_label.text = "SAVE FAILED • Pause and export a local code"
	queue_label.text = F.crew_line(state)
	queue_label.visible = state.phase == "playing" and not paused
	update_hq_indicator()
	journal.text = "%d / 12 districts  •  %d wins / %d sorties" % [career.clears.size(), career.victories, career.attempts]
	sound_button.text = "SOUND  " + ("ON" if settings.sound else "OFF")
	effects_button.text = "REDUCED EFFECTS  " + ("ON" if settings.reduced_effects else "OFF")
	var modal: bool = transfer.visible or journey.visible or support_panel.visible or seed_panel.visible
	briefing.visible = state.phase == "ready" and not paused and not modal
	brief_forecast.text = d.forecast
	brief_rules.text = "Objective: " + C.objective_text(state) + "\n\nRifle 7: general • Breaker 10: armor\nRanger 10: artillery • Rover 18: groups\nFinite crews. Collect scrap; replace losses."
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
	var objective: String = C.objective_text(state)
	guidance.text = objective.substr(0, 1).to_upper() + objective.substr(1) + "\n" + next
	var advice := F.advice(state, station)
	if not advice.is_empty():
		guidance.text += "\n" + advice
	guidance.visible = state.phase == "playing" and not paused
	terminal.visible = state.phase in ["victory", "defeat"] and not paused
	if terminal.visible:
		terminal_title.text = "FOUNDRY LIBERATED" if career.ending and d.id == "foundry_liberation" and state.phase == "victory" else ("DISTRICT SECURED" if state.phase == "victory" else "SORTIE LOST")
		terminal_title.add_theme_font_size_override("font_size", 31)
		terminal_detail.text = F.recap(state, career)
		next_button.visible = state.phase == "victory"
		next_button.text = "LIBERATION JOURNAL" if d.id == "foundry_liberation" else ("NEXT MISSION" if d.mode == "campaign" else "JOURNEY / RECORDS")
	pause_button.disabled = modal
	guidance.visible = guidance.visible and not terminal.visible
	if import_pending: show_import_pending()

func update_hq_indicator() -> void:
	var point: Vector2 = camera.unproject_position(presentation.hq_socket.global_position)
	var view := get_viewport().get_visible_rect().size
	var bottom := view.y - 390.0
	var clipped := camera.is_position_behind(presentation.hq_socket.global_position) or point.y > bottom
	hq_indicator.position = Vector2(clampf(point.x - 115, 18, view.x - 248), clampf(point.y - 52, 190, bottom))
	hq_indicator.text = ("↓ " if clipped else "") + "HQ %d / %d" % [state.hq, state.definition.hq]
	hq_indicator.visible = state.phase == "playing" and not paused

func sync_world(dt: float) -> void:
	super.sync_world(dt)
