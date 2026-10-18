extends "res://tests/playthrough.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Policy = preload("res://tests/campaign_policy.gd")
var campaign_results: Array = []
var arena_results: Array = []

func run() -> void:
	quit_after_run = false
	await super.run()
	root.size = Vector2i(720, 1280)
	await process_frame
	check(scene.state.schema == 1 and scene.profile.clears == [-1], "shipped prologue remains schema1 and earns first route clear")
	for stage in 12:
		await click("SET SAIL")
		check(scene.state.schema == 2 and int(scene.state.definition.stage) == stage, "actual Set Sail opens passage " + str(stage))
		check(C.valid(scene.state) and scene.profile.stage == stage, "new passage has coherent saved definition/economy")
		checkpoint("stage-%02d-start" % stage)
		if C.cost(scene.state) > 0:
			var wallet_before: int = scene.state.wallet
			var power_before: int = int(C.weapon(scene.state).power)
			var price := C.cost(scene.state)
			await click(scene.buy_button.text)
			check(C.weapon(scene.state).power > power_before and scene.state.wallet == wallet_before - price and scene.state.hp == 100, "real next weapon purchase raises power and debits once")
			check(not scene.gate.visible, "stronger power opens full arena access")
			checkpoint("stage-%02d-purchased" % stage)
		await drive_encounter(stage)
		check(scene.state.phase == "victory" and C.valid(scene.state), "actual-input passage victory " + str(stage))
		check(stage in scene.profile.clears and scene.save_error.is_empty(), "earned clear and save recorded naturally")
		campaign_results.append({"stage": stage, "title": scene.state.definition.title, "time": scene.state.time, "hits": scene.state.hits, "rescues": scene.state.deaths, "wallet": scene.state.wallet, "wave_times": scene.state.wave_times.duplicate()})
		checkpoint("stage-%02d-clear" % stage)
	check(scene.profile.completed and scene.profile.clears.size() == 13, "four-island voyage has conclusive earned completion")
	check(scene.terminal_title.text == "HOMEWARD LIGHTS" and scene.continue_button.text == "HARBOR / REPLAY", "final natural terminal displays ending and replay")
	await snap("campaign-ending")
	for weapon_index in [1, 3]:
		await click("HARBOR / REPLAY")
		for attempt in 4:
			if int(scene.profile.arena_weapon) == weapon_index:
				break
			await click(scene.arena_weapon_button.text)
		await click("SAIL TO ARENA")
		check(scene.state.definition.arena and int(scene.state.tier) == weapon_index, "actual loadout control enters arena with chosen weapon")
		checkpoint("arena-%d-start" % weapon_index)
		await drive_encounter(100 + weapon_index)
		check(scene.state.phase == "victory", "actual seeded arena loadout victory " + str(weapon_index))
		arena_results.append({"seed": scene.state.definition.seed, "weapon": weapon_index, "time": scene.state.time, "hits": scene.state.hits, "rescues": scene.state.deaths})
		await click("RETURN TO HARBOR")
		check(scene.profile.completed and scene.state.definition.stage == 11 and scene.state.phase == "victory", "arena returns to exact earned campaign ending")
	await click("HARBOR / REPLAY")
	await click(scene.arena_seed_button.text)
	var seed: int = scene.profile.arena_seed
	await click("SAIL TO ARENA")
	check(scene.state.definition.seed == seed and seed == 1702, "actual seed button creates a new replay formation")
	await drive_encounter(102)
	check(scene.state.phase == "victory", "second actual replay seed clears")
	arena_results.append({"seed": seed, "weapon": scene.state.tier, "time": scene.state.time, "hits": scene.state.hits, "rescues": scene.state.deaths})
	await snap("arena-natural-victory")
	await click("RETURN TO HARBOR")
	check(scene.profile.arena_scores.size() == 3, "separate seed/loadout efficiency records persist")
	await click("HARBOR / REPLAY")
	await click("Sound")
	await click("Reduced effects")
	check(not scene.settings.sound and scene.settings.reduced_effects, "actual settings buttons update both offline options")
	check(not S.read().settings.sound and S.read().settings.reduced_effects, "settings persist in checked local save")
	var expected_profile: Dictionary = S.read().profile
	scene.queue_free()
	await process_frame
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	check(scene.profile == expected_profile and not scene.settings.sound and scene.settings.reduced_effects, "ordinary cold scene reload retains ending, arena scores and settings")
	if not capture_dir.is_empty():
		var f := FileAccess.open(capture_dir.path_join("full-journey-report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"checks": checks, "failures": failures, "checks_detail": report, "campaign": campaign_results, "arena": arena_results, "profile": scene.profile, "source": "Real Input.parse_input_event for movement, Retry, forge, continuation, menu, seed and loadout controls. No state writes during the route; exact earned checkpoints exported separately.", "timing_limit": "Fixed60Hz simulated policy timing; not human duration, fun, phone touch or FPS evidence."}, "  "))
		f.close()
		f = FileAccess.open(capture_dir.path_join("full-journey-input.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(events))
		f.close()
	print("FULL_JOURNEY_COMPLETE: ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func checkpoint(name: String) -> void:
	if capture_dir.is_empty():
		return
	var f := FileAccess.open(capture_dir.path_join(name + ".json"), FileAccess.WRITE)
	f.store_string(S.encode(scene.state, scene.settings, 0, true, scene.profile))
	f.close()

func drive_encounter(stage: int) -> void:
	var s: Dictionary = scene.state
	var seen_wave := -1
	var resized := false
	for frame in 180000:
		if s.phase == "victory":
			break
		if s.phase == "defeat":
			var wallet_before: int = s.wallet
			var dead_before: Array = s.dead.duplicate()
			var tier_before: int = s.tier
			await snap("stage-%02d-loss-%d" % [stage, s.deaths])
			await click("RETRY")
			check(s.wallet == wallet_before and s.dead == dead_before and s.tier == tier_before and s.hp == 100, "actual campaign Retry retains complete earned economy")
		if int(s.wave) != seen_wave:
			seen_wave = int(s.wave)
			check(C.valid(s) and S.decode(S.encode(s, scene.settings, 0, true, scene.profile)).ok, "wave state/save validation " + str(stage) + ":" + str(seen_wave))
			print("ACTUAL_ROUTE ", stage, " wave", seen_wave, " time", s.time, " hp", s.hp)
			if stage in [0, 6, 11] and seen_wave in [0, 2, 5]:
				checkpoint("stage-%02d-wave-%d" % [stage, seen_wave])
		if stage == 6 and not resized and s.time > 8:
			await release()
			await click("PAUSE")
			await click("EXPORT")
			var exported: String = scene.transfer.text
			var decoded := S.decode(exported)
			await click("IMPORT")
			check(scene.transfer_status.text.begins_with("Imported") and scene.state == decoded.state and scene.profile == decoded.profile, "actual mid-campaign export/import retains whole active definition, state and profile")
			s = scene.state
			var before := JSON.stringify(s)
			root.size = Vector2i(1000, 1110)
			await process_frame
			await process_frame
			check(JSON.stringify(s) == before, "paused cover-to-inner resize preserves whole active encounter")
			check(scene.menu_button.size.y >= 96 and scene.buy_button.size.y >= 96 and scene.menu_button.size.x >= 96, "cover-scaled touch targets retain at least48dp size")
			await click("RESUME")
			for beat in 5:
				await physics_frame
			await snap("middle-unfolded-active")
			await click("PAUSE")
			before = JSON.stringify(s)
			root.size = Vector2i(720, 1280)
			await process_frame
			check(JSON.stringify(s) == before, "inner-to-cover resize preserves whole paused encounter")
			await click("RESUME")
			resized = true
		await steer(Policy.direction(s))
		await physics_frame
