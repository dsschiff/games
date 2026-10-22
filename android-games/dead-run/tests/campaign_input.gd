extends "res://tests/playthrough.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Store = preload("res://scripts/campaign_store.gd")
const Data = preload("res://scripts/campaign_data.gd")
const Policy = preload("res://tests/campaign_policy.gd")
const Boundary = preload("res://tests/campaign_boundary.gd")
var outcomes: Array = []
var simulated_ticks := 0
var driven_ticks := 0
var checkpoint_dirs: Array = []
var weapon_used := {}
var prior_aim := 999.0
var opening_only := false
var road_metrics := {}

func _initialize() -> void:
	super._initialize()
	opening_only = "--opening-only" in OS.get_cmdline_user_args()

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(6)
	check(scene.journey.visible and scene.ctx.profile.clears.is_empty(), "fresh app opens 24-road journey with no fabricated progress")
	await snap("journey-fresh")
	await click(scene.stage_buttons[0].text)
	await click("START RESCUE")
	check(scene.state.phase == "playing" and scene.state.weapon == "rivet", "actual touch selects first road and begins proportional-drag firefight")
	while scene.state.phase == "playing": await physics_frame
	check(scene.state.phase == "defeat" and scene.state.crew == 0 and scene.state.leaks > 0 and scene.state.notice.contains("Rescue-line leak"), "diagnosable unattended forward-only choice naturally loses to line leaks")
	check(Store.read().ok and Store.read().context.campaign.phase == "defeat", "bad-choice loss is checked and stored")
	await snap("bad-choice-line-loss")
	var selected: Dictionary = scene.state.definition.duplicate(true)
	await click("RETRY ROAD")
	check(scene.state.phase == "playing" and Data.same(scene.state.definition, selected) and scene.state.weapon == "rivet" and scene.state.crew == 5, "actual Retry preserves exact selected definition/loadout and restores initial crew")
	for index in 24:
		if index > 0:
			if not scene.journey_visible: await click("EVACUATION MAP")
			await click(["RIVET", "LANCE", "FAN"][index % 3])
			await click(scene.stage_buttons[index].text)
			if index in [5, 11, 17, 23]: await save_earned_checkpoint("stage-%02d-ready" % (index + 1))
			await click("START RESCUE")
		var won := await play_road("rescue-harm" if index == 0 else "rescue", index in [0, 11, 23])
		check(won, "actual engine input clears authored road %02d" % (index + 1))
		if not won:
			await snap("failed-road-%02d" % (index + 1))
			break
		check(scene.ctx.profile.clears.size() == index + 1 and scene.state.rewarded and Store.read().ok, "one coherent app-written clear/reward at road %02d" % (index + 1))
		if index == 0: check(scene.state.gates[2].applied < 0 and scene.state.gates[2].delta < 0, "intentional ordinary-road harmful crossing visibly loses crew and remains survivable")
		outcomes.append({"index": index, "weapon": scene.state.weapon, "tick": scene.state.tick, "crew": scene.state.crew, "joined": scene.state.joined, "lost": scene.state.lost, "kills": scene.state.kills, "leaks": scene.state.leaks, "sides": scene.state.sides.duplicate(true), "metrics": road_metrics.duplicate(true)})
		weapon_used[scene.state.weapon] = true
		await snap("road-%02d-victory" % (index + 1))
		print("EARNED_ROAD ", index + 1, " /24 crew=", scene.state.crew, " killed=", scene.state.kills, " lost=", scene.state.lost, " weapon=", scene.state.weapon)
		if index == 0: await active_platform_and_legacy()
		if opening_only: break
	if not opening_only:
		check(scene.ctx.profile.ending and scene.ctx.profile.clears.size() == 24 and scene.overlay_title.text == "LAST FERRY AWAY", "complete earned arc reaches conclusive evacuation ending")
		check(weapon_used.size() == 3, "whole journey uses all three meaningfully distinct weapon families")
	if scene.ctx.profile.ending:
		await snap("ending-earned")
		await alternate_late_choices()
		await seeded_replay()
		await synthetic_boundary_imports()
	await snap("final-campaign")
	write_report_campaign(("Opening-only development route. " if opening_only else "Complete actual engine input journey. ") + "Policies only read state and send touch/drag/wheel/key events. No gameplay handlers or earned-progress injection. Synthetic boundary imports are separate and labelled. Scene restores are desktop checks, not Android lifecycle. Simulation duration is not measured human pacing/fun.")
	scene.queue_free()
	await process_frame
	print("CAMPAIGN_INPUT ", checks, " failures=", failures, " driven_ticks=", driven_ticks)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func play_road(priority: String = "rescue", captures: bool = false) -> bool:
	prior_aim = 999
	road_metrics = {"peak_visible_infected": 0, "piercing_multi_hit_seen": false, "fan_drift_seen": false}
	var all_valid := true
	var seen_gain := false
	var seen_side := false
	var seen_harm := false
	var seen_boss := false
	var seen_telegraph := false
	var seen_negative := false
	var last_tick: int = scene.state.tick
	for frame in 9000:
		if scene.state.phase != "playing": break
		if frame % 12 == 0:
			var target := Policy.aim(scene.state, priority)
			if absf(target - prior_aim) > 0.025:
				drive(target)
				prior_aim = target
		await physics_frame
		driven_ticks += scene.state.tick - last_tick
		last_tick = scene.state.tick
		if frame % 60 == 0: all_valid = all_valid and C.valid(scene.state)
		if frame % 30 == 0:
			var visible := 0
			for i in scene.state.enemies.size():
				if scene.state.tick >= scene.state.definition.enemies[i].born and not scene.state.enemies[i].resolved: visible += 1
			road_metrics.peak_visible_infected = maxi(road_metrics.peak_visible_infected, visible)
			for b in scene.state.bullets:
				road_metrics.piercing_multi_hit_seen = road_metrics.piercing_multi_hit_seen or b.hit_ids.size() >= 2
				road_metrics.fan_drift_seen = road_metrics.fan_drift_seen or b.dx != 0
		if captures and not seen_gain and scene.state.joined > 0:
			seen_gain = true
			await snap("stage-%02d-formation-gain" % (scene.state.definition.index + 1))
		if captures and not seen_side and scene.state.sides[0].hp < scene.state.definition.sides[0].hp:
			seen_side = true
			await snap("stage-%02d-roadside-pressure" % (scene.state.definition.index + 1))
		if captures and not seen_harm and scene.state.lost > 0:
			seen_harm = true
			await snap("stage-%02d-consequence" % (scene.state.definition.index + 1))
		if captures and not seen_negative and scene.state.gates.any(func(g): return g.crossed and g.applied < 0):
			seen_negative = true
			await snap("stage-%02d-negative-gate-crossing" % (scene.state.definition.index + 1))
		if captures and not seen_boss and scene.state.tick >= scene.state.definition.boss.born:
			seen_boss = true
			await snap("stage-%02d-final-threat" % (scene.state.definition.index + 1))
		if captures and not seen_telegraph and scene.state.hazards.any(func(h): return not h.resolved):
			seen_telegraph = true
			await snap("stage-%02d-telegraph" % (scene.state.definition.index + 1))
	await release()
	check(all_valid and C.valid(scene.state), "driven road owned projectiles/formation/once-only counters validate " + str(scene.state.definition.index + 1))
	return scene.state.phase == "victory"

func drive(x: float) -> void:
	var size := root.get_visible_rect().size
	if not touching:
		origin = Vector2(size.x * 0.5, size.y * 0.76)
		origin_x = scene.state.x
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = root.get_final_transform() * origin
		press.pressed = true
		Input.parse_input_event(press)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "world_press", "index": 0, "position": [press.position.x, press.position.y]})
		touching = true
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = root.get_final_transform() * (origin + Vector2((x - origin_x) / 9.0 * size.x, 0))
	drag.relative = Vector2((x - origin_x) / 9.0 * size.x, 0)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	events.append({"frame": Engine.get_physics_frames(), "tick": scene.state.tick, "road": scene.state.definition.index, "kind": "world_drag", "index": 0, "desired_x": x, "position": [drag.position.x, drag.position.y]})

func click(value: String) -> void:
	await process_frame
	var found: Button
	for b in scene.find_children("*", "Button", true, false):
		if b.text == value and b.is_visible_in_tree(): found = b
	if found == null:
		check(false, "missing UI " + value)
		return
	var scroller: Node = found.get_parent()
	while scroller != null and not scroller is ScrollContainer: scroller = scroller.get_parent()
	if scroller != null:
		for i in 90:
			var rect: Rect2 = scroller.get_global_rect()
			var point := found.get_global_rect().get_center()
			if point.y > rect.position.y + 20 and point.y < rect.end.y - 20: break
			var wheel := InputEventMouseButton.new()
			wheel.position = root.get_final_transform() * rect.get_center()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if point.y >= rect.end.y - 20 else MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			Input.parse_input_event(wheel)
			Input.flush_buffered_events()
			events.append({"frame": Engine.get_physics_frames(), "kind": "menu_wheel", "button": wheel.button_index, "position": [wheel.position.x, wheel.position.y]})
			await process_frame
	await tap(found.get_global_rect().get_center(), value)

func active_platform_and_legacy() -> void:
	# Earned first victory -> start a replay through real GUI, then park it active.
	await click("RETRY ROAD")
	await dwell(140)
	await release()
	await click("II")
	var before: Dictionary = scene.ctx.duplicate(true)
	await dwell(50)
	check(Data.same(scene.ctx, before), "active pause freezes full campaign/parked legacy/profile/settings")
	root.size = Vector2i(1000, 1110)
	await dwell(3)
	check(Data.same(scene.ctx, before), "whole active context survives inner aspect")
	await snap("campaign-active-inner")
	root.size = Vector2i(720, 1680)
	await dwell(3)
	check(Data.same(scene.ctx, before), "whole active context survives tall cover aspect")
	await snap("campaign-active-cover")
	root.size = Vector2i(720, 1280)
	await dwell(3)
	await click("SAVE / TRANSFER")
	# Deliberately invalid text entry uses actual key events; no clipboard requested.
	await tap(scene.code_box.get_global_rect().position + Vector2(20, 20))
	await key(KEY_A, true)
	await key(KEY_X, false, 120)
	var saved := Store.read()
	await click("IMPORT")
	check(scene.transfer_status.text.begins_with("Invalid") and Data.same(scene.ctx, before) and Store.read().revision == saved.revision, "actual invalid text Import preserves entire live and durable context")
	await key(KEY_ESCAPE)
	check(not scene.transfer.visible and scene.paused, "Back closes transfer before campaign pause")
	await click("EVACUATION MAP")
	await click("LEGACY CANAL BRIDGE")
	await dwell(5)
	check(scene.ctx.mode == "legacy" and is_instance_valid(scene.legacy_view) and Data.same(scene.ctx.campaign, before.campaign), "legacy view parks the whole active campaign without invented legacy actions")
	# Root remains authoritative for legacy play; this only exercises real return UI.
	var legacy: Node = scene.legacy_view
	var previous_scene := scene
	scene = legacy
	await click("II")
	await click("SAVE / TRANSFER")
	var portable := Store.encode(previous_scene.ctx, Store.read().revision)
	scene.code_box.text = portable
	await click("IMPORT")
	check(scene.transfer_status.text.begins_with("Imported") and previous_scene.ctx.profile.clears.size() == 1 and Data.same(previous_scene.ctx.campaign, before.campaign), "legacy transfer preserves earned campaign and parked run in schema2")
	await click("CLOSE TRANSFER")
	await click("EVACUATION MAP")
	scene = previous_scene
	await dwell(5)
	check(scene.ctx.mode == "campaign" and Data.same(scene.state, before.campaign), "real legacy return preserves active campaign snapshot")
	# Reload only app-written checked bytes, then leave active replay via explicit map confirmation.
	saved = Store.read()
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	check(scene.paused and Data.same(scene.ctx, saved.context), "whole active schema2 context cold-restores paused")
	await click("EVACUATION MAP")
	await click(scene.stage_buttons[1].text)
	check(scene.pending_road == 1, "changing a genuinely active road requires explicit abandon confirmation")
	await click("ABANDON CURRENT ROAD · LOAD 02")
	# Main loop will revisit this ready map; selecting it again is harmless GUI setup.
	check(scene.state.phase == "ready" and scene.state.definition.index == 1, "actual abandon confirmation loads selected next definition")
	await click("EVACUATION MAP")

func alternate_late_choices() -> void:
	var results: Array = [{"priority": "rescue", "weapon": outcomes[21].weapon, "crew": outcomes[21].crew, "lost": outcomes[21].lost, "sides": outcomes[21].sides, "scope": "Primary earned journey, same late Twin Piers definition"}]
	for choice in [["line", "RIVET"], ["rescue", "LANCE"], ["line", "FAN"]]:
		var priority: String = choice[0]
		await click("EVACUATION MAP")
		await click(choice[1])
		await click(scene.stage_buttons[21].text)
		await click("START RESCUE")
		var start_event := events.size()
		check(await play_road(priority), "same late Twin Piers definition wins with priority " + priority)
		results.append({"priority": priority, "weapon": scene.state.weapon, "crew": scene.state.crew, "lost": scene.state.lost, "shots": scene.state.shots, "sides": scene.state.sides.duplicate(true), "events": events.size() - start_event})
		await snap("late-alternative-" + priority + "-" + scene.state.weapon)
	check(results[0].weapon == results[1].weapon and results[0].sides[0].claimed_at != results[1].sides[0].claimed_at, "same late definition and weapon supports two viable roadside priorities with different rescue timing")
	check(results[2].weapon != results[3].weapon and results[2].shots != results[3].shots, "late Lance and Fan wins use different piercing/coverage schedules")
	write("late-alternatives.json", results)

func seeded_replay() -> void:
	await click("EVACUATION MAP")
	await click("FAN")
	await click("SEEDED FERRY EVACUATION")
	check(scene.state.definition.replay and scene.state.definition.seed == 61723, "real map selects deterministic seeded replay after ending")
	await click("START RESCUE")
	check(await play_road("line"), "actual engine input wins seeded final evacuation")
	check(scene.ctx.profile.replays.size() == 1 and scene.ctx.profile.clears.size() == 24, "seeded result ledger stays separate from authored clears")
	await snap("seeded-replay-victory")

func synthetic_boundary_imports() -> void:
	for survives in [false, true]:
		if not scene.paused: await click("II")
		await click("SAVE / TRANSFER")
		var candidate: Dictionary = scene.ctx.duplicate(true)
		candidate.campaign = Boundary.make(survives)
		check(Store.valid(candidate), "synthetic campaign boundary context is valid before GUI Import")
		scene.code_box.text = Store.encode(candidate, 1)
		await click("IMPORT")
		check(scene.transfer_status.text.begins_with("Imported") and scene.paused, "labelled synthetic boundary uses real durable GUI Import")
		await click("CLOSE TRANSFER")
		await click("RESUME")
		await dwell(3)
		if survives:
			check(scene.state.phase == "playing" and scene.state.crew == 7 and scene.state.sides[0].claimed, "ordinary campaign processing grants only surviving boundary payout")
			await click("II")
		else: check(scene.state.phase == "defeat" and scene.state.crew == 0 and not scene.state.sides[0].claimed, "ordinary campaign exhaustion precedes queued payout")
		check(Store.read().ok and Data.same(Store.read().context.campaign, scene.state), "boundary remains app-written/save-valid after normal processing")
		await snap("campaign-synthetic-boundary-" + str(survives))

func save_earned_checkpoint(name: String) -> void:
	var dest := folder.path_join("earned-checkpoints").path_join(name)
	DirAccess.make_dir_recursive_absolute(dest)
	var saved := Store.read()
	check(saved.ok and Data.same(saved.context.campaign, scene.state), "earned checkpoint comes from current app-written stable bytes " + name)
	for i in 2:
		var path := Store.PATH + str(i)
		if FileAccess.file_exists(path):
			var f := FileAccess.open(dest.path_join("dead-run-save-" + str(i)), FileAccess.WRITE)
			f.store_string(FileAccess.get_file_as_string(path))
			f.close()
	checkpoint_dirs.append({"name": name, "path": dest, "context": saved.context, "scope": "Real prior GUI campaign clears; explicit separate movie-load boundary, not one uninterrupted recording."})

func snap(name: String) -> void:
	print("CAMPAIGN_SNAPSHOT ", name, " road=", scene.state.definition.index + 1, " tick=", scene.state.tick, " crew=", scene.state.crew, " phase=", scene.state.phase)
	snapshots.append({"name": name, "frame": Engine.get_physics_frames(), "context": scene.ctx.duplicate(true), "app_written": Store.read()})
	var raw := {}
	for i in 2:
		for suffix in ["", ".tmp"]:
			var path: String = Store.PATH + str(i) + suffix
			if FileAccess.file_exists(path): raw[path] = FileAccess.get_file_as_string(path)
	write(name + "-slots.json", raw)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))

func write_report_campaign(scope: String) -> void:
	write("input-report.json", {"checks": checks, "failures": failures, "details": details, "snapshots": snapshots, "outcomes": outcomes, "driven_ticks": driven_ticks, "scope": scope})
	write("raw-input-events.json", events)
	write("earned-checkpoints.json", checkpoint_dirs)
