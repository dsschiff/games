extends "res://scripts/main.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Cat = preload("res://scripts/campaign_catalog.gd")
var action_buttons: Array = []
var journey: Panel
var journey_scroll: ScrollContainer
var journey_list: VBoxContainer
var next_button: Button
var seed_button: Button
var budget_button: Button
var mirror_button: Button
var confirm_panel: Panel
var ending_panel: Panel
var pending := {}
var seed_option := 1
var budget_option := 0
var mirror_option := false
var range_ring: MeshInstance3D
var built_signature := ""
var map_buttons: Array = []
var endless_button: Button
var legacy_button: Button
var ending_journey_button: Button
var seen_terminal := false
var action_latches := ["", "", ""]

func _ready() -> void:
	var saved := initial_save()
	if recovery_pending and not saved.ok:
		recovery_only(); return
	if saved.ok:
		state = saved.state
		profile = saved.profile
		settings = saved.settings
		campaign_profile = saved.campaign
	else:
		state = C.fresh(Cat.definition(0))
	read_options()
	paused = force_boot_pause or recovery_pending or state.phase == "playing"
	make_world()
	make_ui()
	get_viewport().size_changed.connect(layout)
	setup_audio()
	layout()
	sync_world(0)
	build_recovery_ui()
	refresh()
	menu.visible = paused
	if not skip_boot_save and not recovery_pending: save_now()
	boot_ok=true

func make_world() -> void:
	super.make_world()

func make_ui() -> void:
	super.make_ui()
	for child in menu.get_children():
		if child is Label and child.text.begins_with("Retry restocks"):
			child.hide()
	button(menu, "JOURNEY / REPLAY", open_journey).set_meta("row", 4)
	build_button.hide()
	for choice in 3:
		var b := button(ui, "", invest.bind(choice), 26)
		b.button_down.connect(arm_action.bind(choice))
		action_buttons.append(b)
	next_button = button(terminal, "NEXT WATCH", next_watch, 26)
	journey = panel(ui, "102d3bfc")
	text_label(journey, "TEN HEARTHS / JOURNEY", 30).position = Vector2(22, 18)
	journey_scroll = ScrollContainer.new()
	journey.add_child(journey_scroll)
	journey_list = VBoxContainer.new()
	journey_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journey_list.add_theme_constant_override("separation", 10)
	journey_scroll.add_child(journey_list)
	for stage in 10:
		var b := button(journey_list, "", choose_stage.bind(stage), 22)
		b.custom_minimum_size = Vector2(600, 96)
		map_buttons.append(b)
	endless_button = button(journey_list, "SEEDED ENDLESS", choose_endless, 24)
	endless_button.custom_minimum_size = Vector2(600, 96)
	ending_journey_button = button(journey_list, "THE TEN BEACONS / ENDING", show_ending, 23)
	ending_journey_button.custom_minimum_size = Vector2(600, 96)
	legacy_button = button(journey_list, "RETURN TO LEGACY PASS", return_legacy, 23)
	legacy_button.custom_minimum_size = Vector2(600, 96)
	seed_button = button(journey, "", cycle_seed, 22)
	budget_button = button(journey, "", cycle_budget, 22)
	mirror_button = button(journey, "", cycle_mirror, 22)
	button(journey, "BACK TO WATCH", close_journey, 24).set_meta("journey_back", true)
	journey.hide()
	confirm_panel = panel(ui, "18353ffe")
	text_label(confirm_panel, "REPLACE THIS ACTIVE WATCH?", 29).position = Vector2(22, 22)
	text_label(confirm_panel, "This battle's budget and towers reset.\nEarned clears, records and settings stay.", 23).position = Vector2(22, 90)
	button(confirm_panel, "REPLACE WATCH", confirm_replace).position = Vector2(22, 200)
	button(confirm_panel, "KEEP WATCH", cancel_replace).position = Vector2(22, 310)
	confirm_panel.hide()
	ending_panel = panel(ui, "15333ffc")
	text_label(ending_panel, "THE TEN BEACONS", 37, "ffdb89").position = Vector2(26, 25)
	text_label(ending_panel, "The Ash Regent falls at the last refuge.\n\nCopper lamps answer across the March.\nFen lanterns rise above the water.\nGlasswind's watchfires burn again.\n\nTen hearths held. The roads are yours.\n\nReturn for no-leak seals, lean budgets,\nmirrored roads and seeded endless watches.", 25).position = Vector2(26, 100)
	button(ending_panel, "BACK TO JOURNEY", close_ending).position = Vector2(26, 510)
	ending_panel.hide()

func layout() -> void:
	super.layout()
	if journey == null:
		return
	var w := safe_rect.size.x
	var h := safe_rect.size.y
	var origin := safe_rect.position
	for i in 3:
		action_buttons[i].position = origin + Vector2(i * (w + 6) / 3, h - 120)
		action_buttons[i].size = Vector2((w - 12) / 3, 112)
	guidance.position = origin + Vector2(0, h - 232)
	guidance.size = Vector2(w, 90)
	stick.position = origin + Vector2(20, h - 360)
	terminal.size.y = 575
	terminal.position.y = origin.y + (h - terminal.size.y) / 2
	next_button.position = Vector2(24, 336)
	next_button.size = Vector2(572, 96)
	for child in terminal.get_children():
		if child is Button and child.text == "PAUSE / LOG":
			child.position.y = 444
	journey.size = Vector2(660, minf(920, h - 60))
	journey.position = origin + Vector2((w - 660) / 2, (h - journey.size.y) / 2)
	journey_scroll.position = Vector2(20, 76)
	journey_scroll.size = Vector2(620, journey.size.y - 320)
	seed_button.position = Vector2(20, journey.size.y - 225)
	seed_button.size = Vector2(300, 96)
	budget_button.position = Vector2(338, journey.size.y - 225)
	budget_button.size = Vector2(300, 96)
	mirror_button.position = Vector2(20, journey.size.y - 116)
	mirror_button.size = Vector2(300, 96)
	for child in journey.get_children():
		if child.has_meta("journey_back"):
			child.position = Vector2(338, journey.size.y - 116)
			child.size = Vector2(300, 96)
	confirm_panel.size = Vector2(620, 430)
	confirm_panel.position = origin + Vector2((w - 620) / 2, (h - 430) / 2)
	for child in confirm_panel.get_children():
		if child is Button:
			child.size = Vector2(576, 96)
	ending_panel.size = Vector2(640, 650)
	ending_panel.position = origin + Vector2((w - 640) / 2, (h - 650) / 2)
	for child in ending_panel.get_children():
		if child is Button:
			child.size = Vector2(588, 96)

func refresh() -> void:
	if recovery_pending: show_recovery(); return
	if action_buttons.is_empty():
		return
	refresh_resume_action()
	var d: Dictionary = state.definition
	var head := ui.get_node("Header")
	(head.get_child(1) as Label).text = "%02d / %s • %s" % [int(d.stage) + 1, Cat.REGIONS[int(d.region)], str(d.title).to_upper()]
	(head.get_child(1) as Label).add_theme_font_size_override("font_size", 18)
	wallet_label.text = "GOLD  %d" % state.wallet
	integrity_label.text = "REFUGE  %d / %d" % [state.integrity, d.integrity]
	var next_threat: String = "COLUMN EXHAUSTED"
	if state.spawned < d.roster.size():
		var next: Dictionary = d.roster[int(state.spawned)]
		next_threat = "NEXT: " + str(next.role).to_upper()
		if d.lanes == 2:
			next_threat += " / " + ("L" if (next.lane == 0) != d.mirror else "R")
	wave_label.text = "%d / %d STOPPED • %s" % [state.killed.size(), d.roster.size(), next_threat]
	wave_label.add_theme_font_size_override("font_size", 21)
	if save_problem:
		wave_label.text = "SAVE FAILED • Pause to export"
	var seals := 0
	for record in campaign_profile.records.values():
		if record.leaks == 0:
			seals += 1
	journal.text = "%d / 10 hearths • %d no-leak seals • %d wins" % [campaign_profile.clears.size(), seals, campaign_profile.wins]
	sound_button.text = "SOUND  " + ("ON" if settings.sound else "OFF")
	effects_button.text = "REDUCED EFFECTS  " + ("ON" if settings.reduced_effects else "OFF")
	start_button.text = "BEGIN WATCH"
	start_button.visible = state.phase == "ready" and not paused
	build_button.hide()
	stick.visible = state.phase == "playing" and not paused
	var near := C.nearby(state)
	for i in 3:
		var b: Button = action_buttons[i]
		b.visible = state.phase == "playing" and not paused
		var disabled := near < 0
		b.text = "APPROACH\nA PAD"
		if near >= 0:
			var t: Dictionary = state.towers[near]
			if t.family < 0:
				b.text = "BUILD %s\n%d GOLD" % [d.families[i].name, d.families[i].price]
				disabled = state.wallet < d.families[i].price
			elif i == 2:
				b.text = "SELL TOWER\n+%d GOLD" % floori(t.invested * 0.7)
			elif t.fork == 0:
				b.text = "%s\n%d GOLD" % [d.families[int(t.family)].fork_names[i], d.families[int(t.family)].upgrades[i]]
				disabled = state.wallet < d.families[int(t.family)].upgrades[i]
			else:
				b.text = "TARGET: %s\nTAP TO CYCLE" % ["FIRST", "STRONG", "WEAK"][int(t.priority)] if i == 0 else "FORK LOCKED\nSELL TO REFIT"
				disabled = i == 1
			b.modulate = Color(["ffe1a1", "ffb69a", "a6f1e4"][i])
		b.disabled = disabled
	var boss_text := ""
	for e in state.enemies:
		var spec: Dictionary = d.roster[int(e.id)]
		if spec.role in ["ram", "matriarch", "regent"]:
			boss_text = {"ram": "RAM: armor + cycling shield. Pierce / Siege.", "matriarch": "MATRIARCH: heals its column. Burst / Scatter.", "regent": "REGENT: switches roads and silences nearby towers."}[spec.role]
	guidance.text = boss_text + "\nCollect nearby gold • explicit buys • sell returns 70%." if not boss_text.is_empty() else ("Move left thumb • collect gold • tap a priced action.\nBolt: armor forks / Mortar: groups / Beacon: shades + slow.")
	guidance.add_theme_font_size_override("font_size", 21)
	if near >= 0 and state.towers[near].family >= 0 and boss_text.is_empty():
		var tower: Dictionary = state.towers[near]
		guidance.text = "Pad %d • %s • range %.1f\n%s" % [near + 1, Cat.FAMILIES[int(tower.family)], d.families[int(tower.family)].stats[int(tower.fork)].range, ["Pierce ignores armor • Volley strikes two targets", "Siege pierces armor • Scatter blasts wider groups", "Prism chains magic • Winter slows a whole cluster"][int(tower.family)]]
	terminal.visible = state.phase in ["victory", "defeat"] and not paused
	if terminal.visible:
		terminal_title.text = "HEARTH %d HELD" % (int(d.stage) + 1) if state.phase == "victory" else "REFUGE BREACHED"
		if state.phase == "victory" and d.stage == 9 and d.endless < 0:
			terminal_title.text = "THE REGENT FALLS"
		var lesson := "NO-LEAK SEAL" if state.leaked.is_empty() and state.phase == "victory" else "Refit coverage, burst groups or slow the fast road."
		if not state.leaked.is_empty():
			var leak: Dictionary = d.roster[int(state.leaked.back())]
			lesson = "Last leak: " + str(leak.role).to_upper() + (" • switching road" if leak.role == "regent" else (" • left road" if (leak.lane == 0) != d.mirror else " • right road"))
		terminal_detail.text = "%d stopped • %d leaked • %.0fs\n%s\nRetry restocks this pinned watch. Records stay." % [state.killed.size(), state.leaked.size(), state.time, lesson]
	next_button.visible = state.phase == "victory"
	next_button.text = "NEXT ENDLESS WATCH" if d.endless >= 0 else ("THE TEN BEACONS" if d.stage == 9 else "NEXT HEARTH")
	guidance.visible = not paused and not terminal.visible
	for i in 10:
		map_buttons[i].disabled = i > campaign_profile.clears.size()
		var record: Dictionary = campaign_profile.records.get("pass%02d" % (i + 1), {})
		map_buttons[i].text = "%02d  %s%s" % [i + 1, Cat.TITLES[i].to_upper(), " • SEAL" if not record.is_empty() and record.leaks == 0 else (" • HELD" if not record.is_empty() else "")]
	endless_button.disabled = not campaign_profile.ending
	ending_journey_button.disabled = not campaign_profile.ending
	legacy_button.disabled = campaign_profile.legacy_snapshot.is_empty()
	seed_button.text = "SEED  %d" % seed_option
	budget_button.text = "BUDGET  " + ["STANDARD", "RICH +3", "LEAN −3"][budget_option if budget_option >= 0 else 2]
	mirror_button.text = "ROADS  " + ("MIRRORED" if mirror_option else "ORIGINAL")
	pause_button.disabled = transfer.visible or journey.visible or confirm_panel.visible or ending_panel.visible

func invest(choice: int) -> void:
	if recovery_pending: return
	var latched: String = action_latches[choice]
	action_latches[choice] = ""
	if not paused and not latched.is_empty() and latched == action_context() and C.action(state, C.nearby(state), choice):
		tone(420 + choice * 100, 0.1)
		save_now()
		refresh()

func action_context() -> String:
	var near := C.nearby(state)
	if near < 0:
		return ""
	var t: Dictionary = state.towers[near]
	return "%d:%d:%d:%d:%d" % [near, t.family, t.fork, t.invested, t.priority]

func arm_action(choice: int) -> void:
	if recovery_pending: return
	action_latches[choice] = action_context() if not paused and state.phase == "playing" else ""

func stop_move() -> void:
	super.stop_move()
	if stick != null:
		stick.position = safe_rect.position + Vector2(20, safe_rect.size.y - 360)

func begin() -> void:
	if recovery_pending: return
	state.phase = "playing"
	paused = false
	save_now()
	refresh()

func retry() -> void:
	if recovery_pending: return
	state = C.fresh(state.definition)
	state.phase = "playing"
	paused = false
	stop_move()
	menu.hide()
	save_now()
	sync_world(0)
	refresh()

func open_journey() -> void:
	if recovery_pending: return
	paused = true
	stop_move()
	journey.show()
	refresh()

func close_journey() -> void:
	if recovery_pending: return
	journey.hide()
	menu.show()
	paused = true

func choose_stage(stage: int) -> void:
	if recovery_pending: return
	if stage > campaign_profile.clears.size():
		return
	request_definition(Cat.definition(stage, seed_option, budget_option, mirror_option))

func choose_endless() -> void:
	if recovery_pending: return
	if campaign_profile.ending:
		request_definition(Cat.definition(9, seed_option, budget_option, mirror_option, 0))

func request_definition(d: Dictionary) -> void:
	if recovery_pending: return
	pending = d
	if state.phase == "playing":
		confirm_panel.show()
	else:
		confirm_replace()

func confirm_replace() -> void:
	if recovery_pending: return
	state = C.fresh(pending)
	read_options()
	pending = {}
	paused = false
	stop_move()
	menu.hide()
	journey.hide()
	confirm_panel.hide()
	make_world()
	save_now()
	refresh()

func cancel_replace() -> void:
	if recovery_pending: return
	pending = {}
	confirm_panel.hide()

func cycle_seed() -> void:
	if recovery_pending: return
	seed_option = seed_option % 1000000 + 1
	refresh()

func read_options() -> void:
	seed_option = int(state.definition.seed)
	budget_option = int(state.definition.budget)
	mirror_option = state.definition.mirror

func cycle_budget() -> void:
	if recovery_pending: return
	budget_option = 1 if budget_option == 0 else (-1 if budget_option == 1 else 0)
	refresh()

func cycle_mirror() -> void:
	if recovery_pending: return
	mirror_option = not mirror_option
	refresh()

func next_watch() -> void:
	if recovery_pending: return
	var d: Dictionary = state.definition
	if d.endless >= 0:
		request_definition(Cat.definition(9, d.seed, d.budget, d.mirror, mini(1000, int(d.endless) + 1)))
	elif d.stage < 9:
		request_definition(Cat.definition(int(d.stage) + 1))
	else:
		show_ending()

func show_ending() -> void:
	if recovery_pending: return
	if campaign_profile.ending:
		paused = true
		stop_move()
		ending_panel.show()

func close_ending() -> void:
	if recovery_pending: return
	ending_panel.hide()
	open_journey()

func return_legacy() -> void:
	if recovery_pending: return
	if campaign_profile.legacy_snapshot.is_empty():
		return
	var staged := campaign_profile.duplicate(true)
	staged.parked = state.duplicate(true)
	save_problem = not S.write(staged.legacy_snapshot, profile, settings, S.PATH, save_io, true, staged)
	if not save_problem:
		campaign_profile = staged
		route_reload()
	refresh()

func back() -> void:
	if recovery_pending: return
	if confirm_panel.visible:
		cancel_replace()
	elif ending_panel.visible:
		close_ending()
	elif journey.visible:
		close_journey()
	else:
		super.back()

func import_code() -> void:
	if recovery_pending: return
	begin_import(code_edit.text)

func _physics_process(delta: float) -> void:
	if recovery_pending: return
	if not is_node_ready() or world == null:
		return
	if not paused and state.phase == "playing":
		var events := C.tick(state, input_vector, delta)
		presenter.queue_events(events, state.time)
		for e in events:
			if e.kind == "shot":
				tone([180, 105, 430][int(e.family)], 0.025)
			elif e.kind == "pickup":
				tone(700, 0.05)
			elif e.kind == "leak":
				tone(90, 0.2)
		if state.phase != "playing":
			C.finish(state, campaign_profile)
			save_now()
			tone(550 if state.phase == "victory" else 110, 0.4)
		save_clock += delta
		if save_clock >= 2:
			save_clock = 0
			save_now()
	sync_world(delta if not paused else 0)
	refresh()
	fill_audio()

func sync_world(dt: float) -> void:
	super.sync_world(dt)
