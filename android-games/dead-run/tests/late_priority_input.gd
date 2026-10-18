extends "res://tests/campaign_input.gd"
const Late = preload("res://tests/late_priority.gd")
func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	check(scene.ctx.profile.ending and scene.ctx.profile.clears.size() == 24 and scene.state.phase == "victory", "follow-up loads the real source-bound app-written ending checkpoint")
	var records: Array = []
	var definition := {}
	for priority in ["left-riggers-first", "right-pump-first"]:
		await click("EVACUATION MAP")
		await click("RIVET")
		await click(scene.stage_buttons[21].text)
		if definition.is_empty(): definition = scene.state.definition.duplicate(true)
		check(Data.same(definition, scene.state.definition) and scene.state.weapon == "rivet", "opposite priorities use identical late definition and same Rivet weapon")
		await click("START RESCUE")
		prior_aim = 999
		var valid := true
		for frame in 6500:
			if scene.state.phase != "playing": break
			if frame % 12 == 0:
				var target := Late.aim(scene.state, priority)
				if absf(target - prior_aim) > 0.025:
					drive(target)
					prior_aim = target
			await physics_frame
			if frame % 60 == 0: valid = valid and C.valid(scene.state)
		await release()
		check(valid and scene.state.phase == "victory" and Store.read().ok, "actual engine input wins with priority " + priority)
		check(scene.state.sides.all(func(side): return side.claimed), "both roadside outcomes remain achievable " + priority)
		records.append({"priority": priority, "weapon": scene.state.weapon, "sides": scene.state.sides.duplicate(true), "crew": scene.state.crew, "lost": scene.state.lost, "kills": scene.state.kills, "definition": scene.state.definition.duplicate(true)})
		await snap("true-late-priority-" + priority)
	check(records[0].sides[0].claimed_at < records[0].sides[1].claimed_at and records[1].sides[1].claimed_at < records[1].sides[0].claimed_at, "same late road/weapon supports opposite successful target orders, not just timing jitter")
	check(scene.ctx.profile.clears.size() == 24, "late comparisons do not duplicate campaign progression")
	write("opposite-late-priorities.json", records)
	write_report_campaign("Headless actual engine input follow-up from exact app-written earned ending bytes. Same catalog1 Twin Piers/Rivet, opposite roadside target orders. No game state/progress injection or direct gameplay handler calls. Supplements the full115-check journey; initial rescue/line comparison had only timing differences and is not claimed as opposite orders. No clipboard/foreground use.")
	scene.queue_free()
	await process_frame
	print("OPPOSITE_PRIORITIES ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
