extends "res://tests/campaign_input.gd"
func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	await snap("visual-journey")
	await click(scene.stage_buttons[0].text)
	await click("START RESCUE")
	for i in 1000:
		if i % 12 == 0: drive(Policy.aim(scene.state))
		await physics_frame
	await release()
	check(scene.state.phase == "playing" and scene.state.joined > 0 and C.valid(scene.state), "rendered opening earns recruits and side work through actual drag")
	await snap("visual-road-action")
	await click("II")
	root.size = Vector2i(1000, 1110)
	await dwell(5)
	await snap("visual-inner")
	root.size = Vector2i(720, 1680)
	await dwell(5)
	await snap("visual-tall-cover")
	write_report_campaign("Bounded rendered visual development check only; no clipboard and no full-arc claim.")
	scene.queue_free()
	await process_frame
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
