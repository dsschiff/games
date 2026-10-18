extends "res://tests/campaign_playthrough.gd"
## Fixed-rate desktop movie replay of a genuine input-suite save, not FPS evidence.
func run() -> void:
	var which := "early"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			which = arg.trim_prefix("--capture=")
	var source := FileAccess.get_file_as_string(motion_directory + "/" + which + ".json")
	var packet := Saves.decode(source)
	if not packet.ok:
		push_error("Missing or invalid actual-input capture state: " + which)
		quit(1)
		return
	await create_game()
	game.state = packet.state
	game.profile = packet.profile
	game.settings = packet.settings
	game.screen = "game"
	game.paused = false
	game.clock = float(game.state.time)
	var before_produced: int = game.state.produced
	var before_kills: int = game.state.kills
	for frame_index in 360:
		game.clock += 1.0 / 30.0
		game.advance(1.0 / 30.0)
		game.queue_redraw()
		await process_frame
	check(game.state.produced > before_produced, "Movie includes real generated reinforcements")
	check(game.state.kills > before_kills, "Movie includes real battlefield engagements")
	check(game.state.units.size() <= 120, "Movie retains bounded army")
	print("MOTION ", which, ": produced=", game.state.produced - before_produced, " kills=", game.state.kills - before_kills, " scope=fixed30fps desktop replay of input-generated snapshot; no phone/FPS acceptance")
	game.queue_free()
	await process_frame
	print("SUITE_COMPLETE: PASS" if failures.is_empty() else "SUITE_COMPLETE: FAIL")
	quit(0 if failures.is_empty() else 1)
