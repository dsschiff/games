extends "res://tests/window_fit.gd"
## Real GUI input and normal _process ticks. No calls to advance/Battle.tick,
## no injected game outcomes, no clipboard, and synthetic Home is labeled.
var cases: Array = []
var run_directory := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="): run_directory = arg.trim_prefix("--run-dir=")
	root.size = Vector2i(720, 1280)
	call_deferred("run")

func make_case(name: String) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = Scene.instantiate()
	game.save_path = "user://ready-phase-" + name + ".json"
	root.add_child(game)
	await settle()
	await action("mission0")
	# Actual drag connects the starter generator; spending is unnecessary.
	await move(0, 2, 1, 2)
	check(game.state.phase == "ready" and game.state.time == 0, name + ": GUI preparation remains ready")

func settle_ticks(count: int) -> void:
	for i in count: await process_frame

func whole_state() -> String:
	return Saves.encode(game.state, game.settings, 0, true, game.profile)

func same_saved(left: String, right: String) -> bool:
	var a := Saves.decode(left)
	var b := Saves.decode(right)
	return a.ok and b.ok and a.state == b.state and a.settings == b.settings and a.profile == b.profile

func run() -> void:
	for route in ["menu", "help", "save", "home", "map", "pause"]:
		await make_case(route)
		var before := whole_state()
		if route == "home":
			game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		elif route == "map":
			await key_back()
			await action("resume_run")
		elif route == "pause":
			await action("pause")
		else:
			await action(route)
			await key_back()
		check(whole_state() == before, route + ": ready board/gold/profile preserved through utility/lifecycle path")
		await action("begin")
		check(game.state.phase == "battle" and not game.paused, route + ": ONE Begin starts a live battle")
		await settle_ticks(480)
		check(game.state.time > 7.5 and game.state.produced > 0 and not game.state.enemies.is_empty(), route + ": normal process advances time, spawns enemies and produces defenders without Resume")
		cases.append({"route":route,"time":game.state.time,"produced":game.state.produced,"phase":game.state.phase,"paused":game.paused})
	await active_lifecycle()
	await natural_terminal()
	var output := {"checks":checks,"failures":failures,"events":events,"pointer_events":pointer_events,"key_events":key_events,"cases":cases,"scope":"Actual Godot GUI touches/drag and normal process loop; notifications and scene reload are synthetic desktop lifecycle, not Android Home/cold evidence. No fabricated progress or direct rule stepping."}
	var file := FileAccess.open(run_directory.path_join("phase-data.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"  ")); file.close()
	game.queue_free()
	await process_frame
	print("READY_PHASE_INPUT: ",checks," checks; ",failures.size()," failures; ",events," events")
	print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func active_lifecycle() -> void:
	await make_case("active")
	await action("begin")
	await settle_ticks(120)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.paused and game.state.phase == "battle", "active Home pauses the running battle")
	var before := whole_state()
	await settle_ticks(120)
	check(whole_state() == before, "active Home preserves whole board/gold/units/profile while waiting")
	var path: String = game.save_path
	game.queue_free()
	await process_frame
	await process_frame
	game = Scene.instantiate()
	game.save_path = path
	root.add_child(game)
	await settle()
	check(game.paused and same_saved(whole_state(), before), "actual app-written cold scene restore retains whole active state and starts paused")
	await action("resume_run")
	await settle_ticks(60)
	check(game.paused and same_saved(whole_state(), before), "map return still waits for active Resume")
	await action("pause")
	await settle_ticks(60)
	check(not game.paused and game.state.time > 2.5, "explicit active Resume naturally continues restored battle")

func natural_terminal() -> void:
	await make_case("victory")
	# A known first-road build is assembled exclusively with GUI touch/drag.
	for step in Policy.plan(game.state,"A"):
		if step.has("kind"):
			var allowed := Gear.buy(game.state.board,step.kind,int(step.x),int(step.y),int(game.state.gold),int(game.state.next_id),game.state.encounter,game.state.config)
			if allowed.ok: await purchase(step.kind,int(step.x),int(step.y),int(step.lane))
	await action("begin")
	for i in 18000:
		if game.state.phase != "battle": break
		await process_frame
	check(game.state.phase == "victory" and game.profile.cleared == ["camp_01"], "actual process and GUI build naturally earn first-road victory")
	var profile_before: Dictionary = game.profile.duplicate(true)
	var definition_before: Dictionary = game.state.config.duplicate(true)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await action("menu")
	await key_back()
	await action("begin")
	check(game.state.phase == "ready" and not game.paused and game.profile == profile_before and game.state.config == definition_before, "terminal Home/Menu then Retry resets attempt while retaining full earned profile and pinned encounter")
	await action("begin")
	await settle_ticks(60)
	check(game.state.phase == "battle" and game.state.time > 0.8 and not game.paused, "one Begin after Retry naturally advances without an extra Resume")
	# Retry restored the disconnected starter, which now loses naturally.
	for i in 12000:
		if game.state.phase != "battle": break
		await process_frame
	check(game.state.phase == "defeat" and game.profile == profile_before, "natural failed Retry attempt retains the whole earned profile")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await action("save")
	await key_back()
	await action("begin")
	check(game.state.phase == "ready" and not game.paused and game.profile == profile_before and game.state.config == definition_before, "defeat Home/Save then Retry preserves profile and pinned encounter")
	await action("begin")
	await settle_ticks(60)
	check(game.state.time > 0.8 and game.state.phase == "battle" and not game.paused, "one Begin after defeat Retry naturally advances")

