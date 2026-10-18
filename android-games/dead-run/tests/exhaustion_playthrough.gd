extends "res://tests/playthrough.gd"
const Fixture = preload("res://tests/exhaustion_fixture.gd")

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	await click("START RESCUE")
	for survives in [false, true]:
		if not scene.paused:
			await click("II")
		await click("SAVE / TRANSFER")
		var fixture := Fixture.make(survives)
		check(R.valid(fixture), "labelled synthetic GUI-import fixture starts valid; survives=" + str(survives))
		# Fixture code entry only. Import/Resume are real GUI input; no model injection.
		scene.code_box.text = S.encode(fixture, {"sound": false, "reduced_effects": true}, 1)
		await click("IMPORT")
		check(scene.transfer_status.text.begins_with("Imported") and scene.paused and same(scene.state, fixture), "real GUI Import durably accepts entire fixture before Resume")
		check(S.read().ok and same(S.read().state, fixture), "imported boundary fixture is on actual checked disk")
		await snap("boundary-before-" + str(survives))
		await click("CLOSE TRANSFER")
		await click("RESUME")
		await dwell(3)
		check(R.valid(scene.state), "normal engine processing keeps GUI-imported boundary valid")
		if survives:
			check(scene.state.phase == "playing" and scene.state.crew == 4 and scene.state.joined == 9 and scene.state.lost == 8, "surviving contact still receives exactly three crane recruits")
			check(scene.state.side_hp == 0 and scene.state.side_claimed, "surviving same-tick crane payout remains enabled")
			await click("II")
		else:
			check(scene.state.phase == "defeat" and scene.state.crew == 0 and scene.state.joined == 4 and scene.state.lost == 7, "normal processing of fatal contact produces defeat, no revive or payout")
			check(scene.state.side_hp == 1 and not scene.state.side_claimed, "queued crane impact cannot override exhaustion")
			check(scene.overlay.visible and scene.overlay_title.text == "RESCUE LOST", "ordinary refresh renders actual boundary defeat")
		check(S.read().ok and same(S.read().state, scene.state) and scene.save_message.is_empty(), "post-boundary app-written save is valid and matches model")
		await snap("boundary-after-" + str(survives))
		if not survives:
			var fatal_save := S.read()
			scene.queue_free()
			await process_frame
			await process_frame
			scene = load("res://main.tscn").instantiate()
			root.add_child(scene)
			await dwell(5)
			check(scene.state.phase == "defeat" and same(scene.state, fatal_save.state) and S.read().ok, "fatal boundary cold-restores valid defeat without revival or payout")
			await snap("boundary-fatal-restored")
	var saved := S.read()
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	check(scene.paused and same(scene.state, saved.state), "surviving boundary cold-restores checked and paused")
	await snap("boundary-restored")
	write("input-report.json", {"checks": checks, "failures": failures, "details": details, "snapshots": snapshots,
		"scope": "Labelled synthetic VALID import fixtures, not earned routes or reachability proof. Actual engine touch Import/Resume, ordinary simulation, app-written checked disk and unforced terminal rendering. No clipboard access."})
	write("raw-input-events.json", events)
	scene.queue_free()
	await process_frame
	print("EXHAUSTION_GUI: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
