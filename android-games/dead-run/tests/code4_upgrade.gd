extends "res://tests/campaign_input.gd"
## Desktop install-over check of a GENUINE code4 save. run_desktop.py copies
## the two app-written code4 slot files from tests/fixtures/code4-midroad into
## this run's isolated app data before the code5 scene starts. The road was
## simulated by the unmodified code4 project; its profile clears are a
## labelled fixture. Steering replays code4's recorded [tick, aim] pairs.
const Catalog1Data = preload("res://scripts/catalog1_data.gd")

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	var s: Dictionary = scene.state
	check(C.catalog1(s) and s.phase == "playing" and s.tick == 1500 and s.weapon == "lance" and scene.paused, "code5 opens the code4 road in progress paused, under its own catalog1 rules")
	check(Data.same(s.definition, Catalog1Data.stage(6)) and scene.ctx.profile.clears == [0, 1, 2, 3, 4, 5] and scene.ctx.settings.reduced_effects and not scene.ctx.settings.sound and scene.ctx.loadout == "lance", "pinned definition, clears, medals, settings and loadout all survive install-over")
	check(scene.info.text.begins_with("CREW %d / 20" % s.crew), "HUD shows the code4 road's own crew cap")
	await snap("code4-midroad-restored")
	var cont: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/code4-midroad/continuation.json"))
	var steers := {}
	for pair in cont.steers: steers[int(pair[0])] = float(pair[1])
	if steers.has(scene.state.tick): C.steer(scene.state, steers[scene.state.tick])
	var revision: int = Store.read().revision
	await click("RESUME")
	var autosaved := false
	var all_valid := true
	for frame in 4000:
		if scene.state.phase != "playing": break
		await physics_frame
		if steers.has(scene.state.tick): C.steer(scene.state, steers[scene.state.tick])
		if frame % 300 == 0: all_valid = all_valid and C.valid(scene.state)
		if frame % 30 == 0 and Store.read().revision > revision: autosaved = true
	check(all_valid and autosaved and scene.save_message.is_empty(), "background autosaves keep writing checked saves during the catalog1 road")
	var final: Dictionary = Store.integers(cont.final)
	final.rewarded = scene.state.rewarded
	check(Data.same(Store.integers(scene.state.duplicate(true)), final), "the real scene finishes the code4 road exactly as code4 did (%s, crew %d)" % [scene.state.phase, scene.state.crew])
	check(scene.state.phase == "victory" and scene.ctx.profile.clears.size() == 7 and Store.read().ok and Store.read().context.profile.clears.size() == 7, "finishing it earns the next clear on checked disk")
	await snap("code4-road-finished")
	await click("RETRY ROAD")
	check(not C.catalog1(scene.state) and scene.state.definition.catalog == Data.CATALOG and scene.state.definition.index == 6 and scene.state.weapon == "lance" and scene.state.phase == "playing" and scene.state.crew == 5, "Retry starts the same road and weapon under the horde rules")
	check(scene.info.text.begins_with("CREW 5 / %d" % Data.CAP), "HUD shows the horde crew cap after Retry")
	await click("II")
	var saved := Store.read()
	check(saved.ok and Data.same(saved.context.campaign, scene.state) and saved.context.profile.clears.size() == 7, "upgraded road and earned profile are on checked disk")
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	check(scene.paused and Data.same(scene.ctx, saved.context), "cold restart restores the upgraded road paused")
	await snap("code4-upgraded-restored")
	write("input-report.json", {"checks": checks, "failures": failures, "details": details, "snapshots": snapshots,
		"scope": "Genuine code4 app-written slots (road from unmodified code4 project; profile clears labelled fixture). Desktop install-over, not Android update."})
	scene.queue_free()
	await process_frame
	print("CODE4_UPGRADE ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
