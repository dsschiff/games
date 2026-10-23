extends SceneTree
const S = preload("res://scripts/save_store.gd")
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")
const P = preload("res://tests/policy.gd")
const F = preload("res://scripts/reinforcement_feedback.gd")
var app: Node
var scene: Node
var folder := ""
var checks := 0
var failures := 0
var details: Array = []
var events: Array = []
var snapshots: Array = []
var touch_active := false
var origin := Vector2(120, 1155)
var movie := false
var clip := ""
var saved_boundaries := {}
var sim_total := 0.0
var sent_touch := 0
var sortie_number := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
		if arg == "--movie-only":
			movie = true
	call_deferred("run")

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(720, 1280)
	Engine.time_scale = 1.0 if movie else 8.0
	app = load("res://boot.tscn").instantiate()
	root.add_child(app)
	await dwell(5)
	scene = app.session
	print("CAMPAIGN_USER_DATA ", OS.get_user_data_dir())
	if movie:
		check(scene.state.catalog == 2, "movie starts from campaign or genuinely earned checkpoint")
		if scene.paused:
			await snap("00-earned-boundary-paused")
			await click("RESUME")
		else:
			await choose_support("relay")
			await click("LAUNCH SORTIE")
		await play_sortie("A", false)
		if scene.career.ending:
			await click("LIBERATION JOURNAL")
			await snap("ending-journal")
		await dwell(90)
	else:
		check(scene.state.phase == "ready" and scene.career.clears.is_empty(), "new campaign starts with zero clears, no injected progress")
		await snap("01-first-brief")
		for index in 12:
			check(scene.state.definition.index == index and scene.state.phase == "ready", "earned next mission " + str(index + 1))
			await choose_support("ward" if index == 11 else "relay")
			await click("LAUNCH SORTIE")
			await play_sortie("A", true)
			if scene.state.phase != "victory":
				break
			check(scene.career.clears.size() == index + 1, "actual victory unlocks exactly one campaign district " + str(index + 1))
			if index < 11:
				await click("NEXT MISSION")
		check(scene.career.ending and scene.career.clears.size() == 12, "all twelve natural wins reach conclusive foundry liberation")
		check(sim_total >= 1800 and sim_total <= 3600, "successful initial arc is 30–60 simulated minutes; human pacing remains unverified")
		if scene.career.ending:
			await click("LIBERATION JOURNAL")
			check(scene.ending_label.text.begins_with("THE FOUNDRY IS FREE"), "actual finale journal displays ending and replay choices")
			await snap("14-liberation-journal")
			await replay_late_and_correct()
			await seed_replay()
			await reliability()
	await release()
	write_report()
	app.queue_free()
	await process_frame
	await process_frame
	print("FRONTLINE_CAMPAIGN_INPUT ", checks, " failures=", failures, " simulated_arc_seconds=", sim_total, " touches=", sent_touch)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func choose_support(key: String) -> void:
	await click("SORTIE KIT / SUPPORT")
	await click(key.to_upper())
	check(scene.state.planned_support == key and scene.state.support == "none", "actual free refit chooses " + key + " before paid local investment")

func play_sortie(variant: String, save_boundaries: bool) -> void:
	sortie_number += 1
	var equipped := false
	var deployed := false
	var attacked := false
	var incoming := false
	var valid_states := true
	var purchase_count := 0
	var index: int = scene.state.definition.index
	var start_time: float = scene.state.time
	var start_hp: float = scene.state.hp
	var max_crowd := 0
	for frame in 12000:
		var s: Dictionary = scene.state
		if s.phase != "playing":
			break
		var choice := P.decide(s, variant)
		if choice.station >= 0 and C.nearby(s) == choice.station and C.can_buy(s, choice.station):
			await release()
			var spent: int = s.spent
			var prior: int = s.purchases.size()
			await click(scene.build_button.text)
			check(s.purchases.size() == prior + 1 and s.spent > spent, "actual contextual purchase " + str(index + 1) + "/" + str(prior + 1))
			if s.purchases.size() == prior:
				break
			purchase_count += 1
			if prior < 3 or s.time > 70:
				await snap("m%02d-purchase-%02d" % [index + 1, prior + 1])
		else:
			await steer((choice.goal - C.position(s)).limit_length())
			await physics_frame
		if not equipped and s.consumed.reduce(func(a, b): return a + b, 0) > 0:
			equipped = true
			check(scene.queue_label.visible and scene.queue_label.text == F.crew_line(s) and "ARMING" in scene.queue_label.text, "paid equipment names its actual arming recruit " + str(index + 1))
			await snap("m%02d-arming" % [index + 1])
		if not deployed and s.recruits.any(func(r): return r.phase == "deploying" and r.waypoint == 1):
			deployed = true
			check(scene.queue_label.text == F.crew_line(s), "gate feedback follows saved individual phase " + str(index + 1))
			await snap("m%02d-through-gate" % [index + 1])
		if not attacked and s.recruits.any(func(r): return r.shots > 0 and r.damage > 0):
			attacked = true
			check(F.contribution(s).contains("led with"), "real crew attack earns ledger-based contribution " + str(index + 1))
			await snap("m%02d-recruit-attacks" % [index + 1])
		if not incoming and s.hq_taken + s.commander_taken + s.recruits.reduce(func(a, r): return a + r.taken, 0.0) > 0:
			incoming = true
			await snap("m%02d-incoming-damage" % [index + 1])
		if frame % 120 == 0:
			valid_states = valid_states and C.valid(s)
			print("CAMPAIGN_PROGRESS m=", index + 1, " time=", s.time, " hp=", s.hp, " hq=", s.hq, " bought=", s.bought, " stopped=", s.killed.size())
		max_crowd = maxi(max_crowd, s.enemies.size())
		if save_boundaries:
			if index == 0 and s.time > 0.5 and not saved_boundaries.has("early"):
				await save_earned("early")
			if index == 7 and s.time >= 130 and not saved_boundaries.has("middle"):
				await save_earned("middle")
			if index == 11 and s.time >= 145 and not saved_boundaries.has("final"):
				await save_earned("final")
	await release()
	await dwell(3)
	check(valid_states and C.valid(scene.state), "earned active/terminal states stay valid " + str(index + 1))
	if variant == "mistake":
		check(scene.state.phase == "defeat" and scene.terminal.visible and scene.terminal_title.text == "SORTIE LOST", "insufficient rifle-only investment naturally loses with readable cause")
	else:
		check(scene.state.phase == "victory" and scene.terminal.visible, "ordinary untouched terminal victory mission " + str(index + 1))
		check(attacked and scene.state.commander_shots > 0, "individual recruits and commander own consequential attacks " + str(index + 1))
		if start_time < 1:
			check(equipped and deployed and purchase_count > 1, "visible equipment/deployment and repeated explicit local purchases " + str(index + 1))
		check(scene.state.definition_hash == D.signature(scene.state.definition), "complete immutable definition remains pinned")
	if variant == "A" and save_boundaries:
		sim_total += scene.state.time
	await snap("m%02d-%s-terminal" % [index + 1, variant])
	if movie:
		await dwell(120)
	print("CAMPAIGN_OUTCOME ", index + 1, " ", variant, " ", scene.state.phase, " time=", scene.state.time, " HQ=", scene.state.hq, " hp=", scene.state.hp, " started_hp=", start_hp, " max_enemies=", max_crowd)

func replay_late_and_correct() -> void:
	await select_journey(10)
	await choose_support("ward")
	await click("LAUNCH SORTIE")
	await play_sortie("B", false)
	check(scene.state.purchases[0].station == 3, "late viable alternative starts with a funded rover rather than rifles")
	await click("RETRY SIEGE")
	check(scene.state.phase == "ready" and scene.career.clears.size() == 12, "actual Retry restocks without erasing whole campaign ending/progress")
	await choose_support("ward")
	await click("LAUNCH SORTIE")
	await play_sortie("mistake", false)
	var before: Dictionary = scene.career.duplicate(true)
	await click("RETRY SIEGE")
	check(scene.career == before and scene.state.spent == 0 and scene.state.bought == [0, 0, 0, 0], "actual failed-choice Retry retains whole career and finite new budget")
	await choose_support("relay")
	await click("LAUNCH SORTIE")
	await play_sortie("A", false)
	check(scene.state.phase == "victory" and scene.state.purchases[0].station == 0 and scene.state.bought[1] > 0 and scene.state.bought[2] > 0, "actual refit/specialist correction improves failed late choice to victory")

func select_journey(index: int) -> void:
	if not scene.journey.visible:
		await click("II")
		await click("JOURNEY / RECORDS")
	var scroll: ScrollContainer = scene.journey_list.get_parent()
	for i in 15:
		var e := InputEventMouseButton.new()
		e.position = root.get_final_transform() * scroll.get_global_rect().get_center()
		e.button_index = MOUSE_BUTTON_WHEEL_DOWN
		e.pressed = true
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "journey_scroll", "position": [e.position.x, e.position.y]})
		await process_frame
	var target: Button = scene.journey_list.get_child(index)
	# Wheel up until the requested real button is inside the clipping rectangle.
	for i in 20:
		if scroll.get_global_rect().encloses(target.get_global_rect()):
			break
		var e := InputEventMouseButton.new()
		e.position = root.get_final_transform() * scroll.get_global_rect().get_center()
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame
	await tap(target.get_global_rect().get_center(), target.text)
	check(scene.state.definition.index == index and scene.state.phase == "ready", "actual Journey selection opens earned late replay")

func seed_replay() -> void:
	await click("II")
	await click("SEEDED SKIRMISH")
	await click("SEED +1")
	await click("FLANK")
	await click("START SKIRMISH")
	var pinned: Dictionary = scene.state.definition.duplicate(true)
	check(pinned.mode == "skirmish" and pinned.seed == 138 and pinned.style == "flank", "real seed/style GUI chooses deterministic replay definition")
	await choose_support("relay")
	await click("LAUNCH SORTIE")
	await play_sortie("A", false)
	var clears: Dictionary = scene.career.clears.duplicate(true)
	check(scene.career.skirmishes.has("138:flank") and scene.career.clears.size() == 12, "seeded victory recorded separately from twelve campaign clears")
	await click("RETRY SIEGE")
	check(D.same(scene.state.definition, pinned) and scene.career.clears == clears, "actual seeded Retry keeps exact complete generated snapshot and separate career")

func reliability() -> void:
	await click("II")
	await click("SOUND  ON")
	await click("REDUCED EFFECTS  OFF")
	await click("SAVE / TRANSFER")
	var before := whole()
	var disk := disk_bytes()
	await tap(scene.code_edit.get_global_rect().position + Vector2(60, 60), "TextEdit")
	check(scene.code_edit.has_focus(), "actual touch focuses TextEdit in campaign")
	await key(KEY_END, true)
	await key(KEY_X, false, 88)
	await click("IMPORT")
	check(whole() == before and disk_bytes() == disk, "invalid campaign Import retains whole run/career/legacy profile/settings and durable bytes")
	await key(KEY_ESCAPE)
	check(scene.paused and not scene.transfer.visible, "Back closes campaign transfer first")
	root.size = Vector2i(1154, 1280)
	await dwell(3)
	check(whole() == before, "inner proportion resize preserves whole paused career and active definition")
	await snap("platform-inner-paused")
	root.size = Vector2i(720, 1680)
	await dwell(3)
	check(whole() == before, "tall cover proportion resize preserves whole paused state")
	await snap("platform-tall-paused")
	root.size = Vector2i(720, 1280)
	await dwell(3)
	await key(KEY_ESCAPE)
	check(not scene.paused, "Back resumes without quitting")
	await snap("final-career")
	await click("LAUNCH SORTIE")
	await dwell(30)
	await click("II")
	await snap("final-active-paused")

func save_earned(name: String) -> void:
	await release()
	await click("II")
	var path := folder.path_join("earned-" + name)
	DirAccess.make_dir_recursive_absolute(path)
	for filename in disk_bytes():
		var f := FileAccess.open(path.path_join(filename.get_file()), FileAccess.WRITE)
		f.store_string(disk_bytes()[filename])
	var f := FileAccess.open(path.path_join("boundary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope": "Genuinely input-earned app-written active save, paused through GUI; no injected progress", "frame": Engine.get_physics_frames(), "saved": S.read()}, "  "))
	saved_boundaries[name] = path
	await click("RESUME")

func whole() -> Dictionary:
	return {"state": scene.state.duplicate(true), "career": scene.career.duplicate(true), "profile": scene.profile.duplicate(true), "settings": scene.settings.duplicate(true)}

func disk_bytes() -> Dictionary:
	var result := {}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(slot) + suffix
			if FileAccess.file_exists(path):
				result[path] = FileAccess.get_file_as_string(path)
	return result

func dwell(frames: int) -> void:
	for i in frames:
		await physics_frame

func steer(direction: Vector2) -> void:
	if not touch_active:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * origin
		e.pressed = true
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "stick_press", "position": [e.position.x, e.position.y]})
		touch_active = true
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = root.get_final_transform() * (origin + direction * 65)
	e.relative = direction * 65
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	events.append({"frame": Engine.get_physics_frames(), "time": scene.state.time, "mission": scene.state.definition.id, "kind": "stick_drag", "position": [e.position.x, e.position.y]})

func release() -> void:
	if touch_active:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * origin
		e.pressed = false
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "stick_release", "position": [e.position.x, e.position.y]})
		touch_active = false
	await process_frame

func click(text: String) -> void:
	await process_frame
	var target: Button
	for b in scene.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			target = b
	if target == null or target.disabled:
		check(false, "missing/disabled real button " + text)
		return
	await tap(target.get_global_rect().get_center(), text)

func tap(point: Vector2, target: String) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * point
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "gui_press" if pressed else "gui_release", "target": target, "position": [e.position.x, e.position.y]})
		if pressed:
			sent_touch += 1
		await process_frame

func key(code: int, ctrl: bool = false, unicode_value: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.ctrl_pressed = ctrl
		e.unicode = unicode_value
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "key", "key": code, "ctrl": ctrl, "unicode": unicode_value, "pressed": pressed})
		await process_frame

func snap(name: String) -> void:
	if folder.is_empty():
		return
	name = "s%02d-%s" % [sortie_number, name]
	snapshots.append({"name": name, "frame": Engine.get_physics_frames(), "live": whole(), "app_written": S.read()})
	var f := FileAccess.open(folder.path_join(name + "-slots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(disk_bytes(), "  "))
	f.close()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))

func write_report() -> void:
	if folder.is_empty():
		return
	for pair in [["input-report.json", {"checks": checks, "failures": failures, "details": details, "snapshots": snapshots, "simulated_arc_seconds": sim_total, "touch_taps": sent_touch, "earned_boundaries": saved_boundaries, "scope": "Actual engine ScreenTouch/GUI/key input; read-only state policy; ordinary processing. 8x engine time scale for full desktop route, 1x for movies. No injected progress/economy, gameplay-handler calls or forced terminal redraw. Desktop clipboard deliberately untouched pending coordinator reservation."}], ["raw-input-events.json", events], ["combat-events.json", scene.event_log]]:
		var f := FileAccess.open(folder.path_join(pair[0]), FileAccess.WRITE)
		f.store_string(JSON.stringify(pair[1], "  " if pair[0] == "input-report.json" else ""))
