extends "res://tests/campaign_input.gd"
var segment := "early"
func _initialize() -> void:
	super._initialize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(40)
	if segment == "early":
		check(scene.ctx.profile.clears.is_empty() and scene.journey.visible, "early clip starts with a fresh empty journey")
		await click(scene.stage_buttons[0].text)
	else:
		var expected := 11 if segment == "middle" else 23
		check(scene.state.definition.index == expected and scene.state.phase == "ready" and scene.ctx.profile.clears.size() == expected, "separate clip loads exact genuinely earned ready checkpoint, no invented progress")
	await snap("segment-" + segment + "-start")
	await dwell(75)
	await click("START RESCUE")
	check(await play_road("rescue-harm" if segment == "early" else "rescue", true), "continuous " + segment + " road reaches natural objective victory")
	if segment == "early": check(scene.state.gates[2].applied < 0, "early continuous route deliberately demonstrates a survivable negative gate")
	await dwell(120)
	await snap("segment-" + segment + "-victory")
	if segment == "final": check(scene.ctx.profile.ending and scene.overlay_title.text == "LAST FERRY AWAY", "final clip reaches earned evacuation ending")
	write_report_campaign("Continuous actual-input " + segment + " road recording. Middle/final are SEPARATE explicit loads of ready checkpoints earned by the source-bound complete GUI journey; not one uninterrupted campaign recording or human pacing measurement. No direct handlers/model injection/forced terminal redraws. No clipboard access.")
	scene.queue_free()
	await process_frame
	print("MOVIE_SEGMENT ", segment, " checks=", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
