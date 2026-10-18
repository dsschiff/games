extends "res://scripts/main.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Cat = preload("res://scripts/campaign_catalog.gd")
var world: Node3D
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
	var saved := S.read()
	if saved.ok:
		state = saved.state
		profile = saved.profile
		settings = saved.settings
		campaign_profile = saved.campaign
	else:
		state = C.fresh(Cat.definition(0))
	read_options()
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
	if world != null:
		remove_child(world)
		world.queue_free()
	enemy_nodes.clear()
	coin_nodes.clear()
	pad_nodes.clear()
	tower_nodes.clear()
	bolts.clear()
	built_signature = ""
	world = Node3D.new()
	add_child(world)
	var d: Dictionary = state.definition
	var palettes := [["63775a", "cfa76c", "b4c7a5"], ["416d68", "92ac91", "6d938e"], ["59747e", "bbc2b0", "d2dfda"]]
	var colors: Array = palettes[int(d.region)]
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("142b38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("badbdc")
	env.ambient_light_energy = 0.4
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	world.add_child(sun)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23
	camera.position = Vector3(0, 19, 17)
	camera.look_at(Vector3(0, 0, -0.4))
	camera.current = true
	box(world, Vector3(0, -0.42, 0), Vector3(11.2, 0.8, 22), colors[0])
	box(world, Vector3(0, -0.88, 0), Vector3(11.5, 0.4, 22.4), "243c43")
	for lane in int(d.lanes):
		for i in 51:
			var z := -10 + i * 0.4
			cylinder(world, Vector3(Cat.road_x(d, lane, z), 0.03, z), 0.62 if d.lanes == 2 else 0.8, 0.1, colors[1])
	for side in [-1, 1]:
		for i in 13:
			var z := -9.5 + i * 1.6
			box(world, Vector3(side * 5.0, 0.1, z), Vector3(0.6, 0.5, 1.05), colors[2])
			if i % 3 == 0:
				cylinder(world, Vector3(side * 5.0, 0.9, z), 0.6, 1.5, "264f4c" if d.region < 2 else "a5c5cc", 0.02)
	for i in d.pads.size():
		var p := C.pad_point(d, i)
		var pad := Node3D.new()
		world.add_child(pad)
		pad.position = Vector3(p.x, 0, p.y)
		cylinder(pad, Vector3(0, 0.12, 0), 0.73, 0.22, "dbbd7b")
		cylinder(pad, Vector3(0, 0.25, 0), 0.62, 0.1, "29494e")
		var price := label3(pad, "%d / 9+" % (i + 1), Vector3(0, 0.75, 0), "ffe292", 36)
		price.name = "Price"
		pad_nodes.append(pad)
		var tower := Node3D.new()
		pad.add_child(tower)
		tower_nodes.append(tower)
	for x in [-2.4, 2.4]:
		box(world, Vector3(x, 0.75, 8.6), Vector3(1, 1.5, 0.9), "b8935f")
		cylinder(world, Vector3(x, 1.85, 8.6), 0.72, 0.8, "33727a", 0.02)
	box(world, Vector3(0, 0.8, 8.6), Vector3(3.8, 1.5, 0.5), "51746e")
	label3(world, "HEARTH REFUGE", Vector3(0, 2.3, 8.6), "ffe4ad", 36)
	avatar = Node3D.new()
	world.add_child(avatar)
	cylinder(avatar, Vector3(0, 0.4, 0), 0.27, 0.7, "28bdba", 0.18)
	cylinder(avatar, Vector3(0, 0.88, 0), 0.2, 0.28, "f6c798")
	box(avatar, Vector3(0, 1.08, 0), Vector3(0.46, 0.12, 0.35), "e4bc6c")
	for x in [-0.2, 0.2]:
		box(avatar, Vector3(x, 1.2, 0), Vector3(0.07, 0.24, 0.09), "e4bc6c")
	cylinder(avatar, Vector3(0.32, 0.8, 0), 0.12, 0.25, "fff5b6")
	actors = Node3D.new()
	world.add_child(actors)
	var ring := TorusMesh.new()
	ring.inner_radius = 4.9
	ring.outer_radius = 5.0
	ring.rings = 40
	ring.ring_segments = 5
	range_ring = mesh(world, ring, Vector3.ZERO, "96dfcd")
	range_ring.visible = false

func draw_tower(node: Node3D, t: Dictionary) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
	if t.family < 0:
		return
	var accent: String = ["efcd74", "df8c58", "78e4e4"][int(t.family)]
	cylinder(node, Vector3(0, 0.65, 0), 0.4, 0.9, "a87b55", 0.32)
	if t.family == 0:
		box(node, Vector3(0, 1.25, 0), Vector3(1.18, 0.15, 0.16), accent)
		box(node, Vector3(0, 1.25, -0.15), Vector3(0.13, 0.15, 0.8), "253b44")
	elif t.family == 1:
		cylinder(node, Vector3(0, 0.65, 0), 0.55, 0.85, "384d57")
		var barrel := cylinder(node, Vector3(0, 1.1, -0.15), 0.34, 0.8, accent)
		barrel.rotation_degrees.x = -35
		cylinder(node, Vector3(0, 1.4, -0.35), 0.25, 0.04, "202d36")
	else:
		cylinder(node, Vector3(0, 1.2, 0), 0.4, 1.05, accent, 0.03)
		for x in [-0.45, 0.45]:
			cylinder(node, Vector3(x, 0.9, 0), 0.15, 0.7, "b5f2e7", 0.02)
	if t.fork > 0:
		for x in [-0.42, 0.42]:
			box(node, Vector3(x, 0.5, 0.4), Vector3(0.15, 0.35, 0.15), accent)
	var name: String = Cat.FAMILIES[int(t.family)] if t.fork == 0 else Cat.FORKS[int(t.family)][int(t.fork) - 1]
	label3(node, name, Vector3(0, 1.9, 0), accent, 29).name = "TowerName"

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
	var size := get_viewport().get_visible_rect().size
	var w := size.x
	var h := size.y
	for i in 3:
		action_buttons[i].position = Vector2(18 + i * (w - 42) / 3, h - 160)
		action_buttons[i].size = Vector2((w - 60) / 3, 112)
	guidance.position = Vector2(10, h - 280)
	guidance.size = Vector2(w - 20, 90)
	stick.position = Vector2(30, h - 460)
	terminal.size.y = 575
	next_button.position = Vector2(24, 336)
	next_button.size = Vector2(572, 96)
	for child in terminal.get_children():
		if child is Button and child.text == "PAUSE / LOG":
			child.position.y = 444
	journey.position = Vector2((w - 660) / 2, 245)
	journey.size = Vector2(660, minf(920, h - 270))
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
	confirm_panel.position = Vector2((w - 620) / 2, 400)
	confirm_panel.size = Vector2(620, 430)
	for child in confirm_panel.get_children():
		if child is Button:
			child.size = Vector2(576, 96)
	ending_panel.position = Vector2((w - 640) / 2, 280)
	ending_panel.size = Vector2(640, 650)
	for child in ending_panel.get_children():
		if child is Button:
			child.size = Vector2(588, 96)

func refresh() -> void:
	if action_buttons.is_empty():
		return
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
	action_latches[choice] = action_context() if not paused and state.phase == "playing" else ""

func stop_move() -> void:
	super.stop_move()
	if stick != null:
		stick.position = Vector2(30, get_viewport().get_visible_rect().size.y - 460)

func begin() -> void:
	state.phase = "playing"
	paused = false
	save_now()
	refresh()

func retry() -> void:
	state = C.fresh(state.definition)
	state.phase = "playing"
	paused = false
	stop_move()
	menu.hide()
	save_now()
	sync_world(0)
	refresh()

func open_journey() -> void:
	paused = true
	stop_move()
	journey.show()
	refresh()

func close_journey() -> void:
	journey.hide()
	menu.show()
	paused = true

func choose_stage(stage: int) -> void:
	if stage > campaign_profile.clears.size():
		return
	request_definition(Cat.definition(stage, seed_option, budget_option, mirror_option))

func choose_endless() -> void:
	if campaign_profile.ending:
		request_definition(Cat.definition(9, seed_option, budget_option, mirror_option, 0))

func request_definition(d: Dictionary) -> void:
	pending = d
	if state.phase == "playing":
		confirm_panel.show()
	else:
		confirm_replace()

func confirm_replace() -> void:
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
	pending = {}
	confirm_panel.hide()

func cycle_seed() -> void:
	seed_option = seed_option % 1000000 + 1
	refresh()

func read_options() -> void:
	seed_option = int(state.definition.seed)
	budget_option = int(state.definition.budget)
	mirror_option = state.definition.mirror

func cycle_budget() -> void:
	budget_option = 1 if budget_option == 0 else (-1 if budget_option == 1 else 0)
	refresh()

func cycle_mirror() -> void:
	mirror_option = not mirror_option
	refresh()

func next_watch() -> void:
	var d: Dictionary = state.definition
	if d.endless >= 0:
		request_definition(Cat.definition(9, d.seed, d.budget, d.mirror, mini(1000, int(d.endless) + 1)))
	elif d.stage < 9:
		request_definition(Cat.definition(int(d.stage) + 1))
	else:
		show_ending()

func show_ending() -> void:
	if campaign_profile.ending:
		paused = true
		stop_move()
		ending_panel.show()

func close_ending() -> void:
	ending_panel.hide()
	open_journey()

func return_legacy() -> void:
	if campaign_profile.legacy_snapshot.is_empty():
		return
	campaign_profile.parked = state.duplicate(true)
	if S.write(campaign_profile.legacy_snapshot, profile, settings, S.PATH, save_io, false, campaign_profile):
		route_reload()

func back() -> void:
	if confirm_panel.visible:
		cancel_replace()
	elif ending_panel.visible:
		close_ending()
	elif journey.visible:
		close_journey()
	else:
		super.back()

func import_code() -> void:
	var decoded := S.decode(code_edit.text)
	if not decoded.ok:
		notice.text = "Invalid code. Current save kept."
		return
	if not S.write(decoded.state, decoded.profile, decoded.settings, S.PATH, save_io, true, decoded.campaign):
		notice.text = "Storage failed. Current save kept."
		return
	if decoded.state.schema == 1:
		route_reload()
		return
	state = decoded.state
	profile = decoded.profile
	settings = decoded.settings
	campaign_profile = decoded.campaign
	read_options()
	close_transfer()
	make_world()
	sync_world(0)
	refresh()

func _physics_process(delta: float) -> void:
	if not is_node_ready() or world == null:
		return
	if not paused and state.phase == "playing":
		var events := C.tick(state, input_vector, delta)
		for e in events:
			if e.kind == "shot":
				campaign_bolt(e)
				tone([180, 105, 430][int(e.family)], 0.025)
			elif e.kind == "heal" and not settings.reduced_effects:
				impact(Vector3(e.x, 0.1, e.z), 1.0, "9fde9e")
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
	avatar.position = Vector3(state.x, 0.15, state.z)
	var signature := ""
	for t in state.towers:
		signature += "%d:%d;" % [t.family, t.fork]
	if signature != built_signature:
		built_signature = signature
		for i in state.towers.size():
			draw_tower(tower_nodes[i], state.towers[i])
			(pad_nodes[i].get_node("Price") as Label3D).visible = state.towers[i].family < 0
	for i in state.towers.size():
		var t: Dictionary = state.towers[i]
		if t.family >= 0:
			var title := tower_nodes[i].get_node("TowerName") as Label3D
			title.text = "SILENCED" if t.jam > 0 else (Cat.FAMILIES[int(t.family)] if t.fork == 0 else Cat.FORKS[int(t.family)][int(t.fork) - 1])
			title.modulate = Color("ff8c79" if t.jam > 0 else ["efcd74", "df8c58", "78e4e4"][int(t.family)])
	var near := C.nearby(state)
	range_ring.visible = near >= 0 and state.towers[near].family >= 0 and not paused
	if range_ring.visible:
		var r: float = state.definition.families[int(state.towers[near].family)].stats[int(state.towers[near].fork)].range
		range_ring.scale = Vector3.ONE * r / 5
		var p := C.pad_point(state.definition, near)
		range_ring.position = Vector3(p.x, 0.17, p.y)
	var alive := {}
	for e in state.enemies:
		var id := int(e.id)
		alive[id] = true
		var spec: Dictionary = state.definition.roster[id]
		if not enemy_nodes.has(id):
			var n := Node3D.new()
			actors.add_child(n)
			var role: String = spec.role
			var color: String = {"raider": "cd704e", "runner": "e6b452", "armor": "7f8197", "swarm": "b67a98", "mender": "8ebf72", "shade": "9875c0", "ram": "b58b60", "matriarch": "a56c9c", "regent": "c7dce0"}[role]
			cylinder(n, Vector3(0, 0.33, 0), 0.22, 0.6, color, 0.12)
			cylinder(n, Vector3(0, 0.73, 0), 0.19, 0.25, color)
			if role == "armor":
				box(n, Vector3(0, 0.5, 0.12), Vector3(0.55, 0.5, 0.23), "b4b7c7")
			elif role == "runner":
				cylinder(n, Vector3(0, 0.94, 0), 0.25, 0.3, color, 0.01)
			elif role == "mender":
				box(n, Vector3(0.3, 0.6, 0), Vector3(0.1, 1, 0.1), "c8f098")
			elif role == "swarm":
				n.scale = Vector3.ONE * 0.72
			elif role in ["ram", "matriarch", "regent"]:
				n.scale = Vector3.ONE * 1.7
				if role == "ram":
					box(n, Vector3(0, 0.5, 0.25), Vector3(0.9, 0.7, 0.4), color)
				elif role == "matriarch":
					for x in [-0.5, 0.5]:
						cylinder(n, Vector3(x, 0.4, 0), 0.35, 0.6, color, 0)
				else:
					for x in [-0.3, 0, 0.3]:
						cylinder(n, Vector3(x, 1.1, 0), 0.12, 0.6, "b9f6f1", 0)
				label3(n, role.to_upper(), Vector3(0, 1.75, 0), "ffdc9d", 26)
			var health := box(n, Vector3(0, 1.18, 0), Vector3(0.55, 0.07, 0.1), "ffe2a4")
			health.name = "Health"
			enemy_nodes[id] = n
		var n: Node3D = enemy_nodes[id]
		var p := C.point(state.definition, e)
		n.position = Vector3(p.x, 0.15, p.y)
		n.get_node("Health").scale.x = maxf(0.05, e.hp / spec.hp)
		n.get_node("Health").material_override.albedo_color = Color("81dfe4" if e.slow > 0 else "ffe2a4")
	for id in enemy_nodes.keys():
		if not alive.has(id):
			enemy_nodes[id].queue_free()
			enemy_nodes.erase(id)
	var groups := {}
	for c in state.coins:
		var key := "%d:%d" % [roundi(c.x), roundi(c.z)]
		if not groups.has(key):
			groups[key] = {"x": c.x, "z": c.z, "value": 0}
		groups[key].value += c.value
	for key in groups:
		if not coin_nodes.has(key):
			var n := Node3D.new()
			actors.add_child(n)
			var coin := cylinder(n, Vector3(0, 0.35, 0), 0.23, 0.1, "ffce55")
			coin.rotation_degrees.x = 72
			var value := label3(n, "", Vector3(0, 0.85, 0), "ffdc85", 29)
			value.name = "Value"
			coin_nodes[key] = n
		var n: Node3D = coin_nodes[key]
		n.position = Vector3(groups[key].x, 0.1 + (0.06 * sin(state.time * 4 + groups[key].z) if not settings.reduced_effects else 0.0), groups[key].z)
		(n.get_node("Value") as Label3D).text = str(int(groups[key].value))
	for key in coin_nodes.keys():
		if not groups.has(key):
			coin_nodes[key].queue_free()
			coin_nodes.erase(key)
	for i in range(bolts.size() - 1, -1, -1):
		bolts[i].life -= dt
		if bolts[i].life <= 0:
			bolts[i].node.queue_free()
			bolts.remove_at(i)
		else:
			var fraction: float = 1 - bolts[i].life / 0.25
			bolts[i].node.position = bolts[i].from.lerp(bolts[i].to, fraction)
			if bolts[i].family == 1:
				bolts[i].node.position.y += sin(fraction * PI) * 1.5

func campaign_bolt(e: Dictionary) -> void:
	var p := C.pad_point(state.definition, int(e.pad))
	var from := Vector3(p.x, 1.3, p.y)
	var to := Vector3(e.x, 0.7, e.z)
	var node := box(actors, from, Vector3(0.12, 0.12, 0.5), ["ffdf8b", "f09e64", "8df6f1"][int(e.family)])
	if not from.is_equal_approx(to):
		node.look_at(to)
	bolts.append({"node": node, "life": 0.25, "from": from, "to": to, "family": e.family})
	if e.area > 0 and not settings.reduced_effects:
		impact(Vector3(e.x, 0.12, e.z), e.area, "e3ba86" if e.family == 1 else "87e7dd")

func impact(at: Vector3, radius: float, color: String) -> void:
	var node := cylinder(actors, at, radius, 0.025, color)
	var material: StandardMaterial3D = node.material_override
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.25
	bolts.append({"node": node, "life": 0.25, "from": at, "to": at, "family": 3})
