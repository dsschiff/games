extends "res://tests/playthrough.gd"
const Content = preload("res://scripts/campaign_data.gd")
const Profile = preload("res://scripts/campaign_profile.gd")
const Policy = preload("res://tests/campaign_policies.gd")
var journey: Array = []

func _initialize() -> void:
	super._initialize()
	evidence = "res://.artifacts/campaign-input" + ("/headless" if DisplayServer.get_name() == "headless" else "")

func create_game() -> void:
	game = Scene.instantiate()
	game.save_path = "user://campaign-input.json"
	root.add_child(game)
	game.set_process(false)
	await process_frame

func key_back() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	key_events += 1
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func steps(actions: Array) -> void:
	for step in actions:
		if step.has("move"):
			for p in game.state.board:
				if int(p.id) == int(step.move):
					await move(int(p.x), int(p.y), int(step.x), int(step.y))
					break
		elif step.has("refit"):
			await tap(game.cell_center(int(step.x), int(step.y)))
			await action("refit")
		elif step.has("gate"):
			await tap(game.cell_center(int(step.x), int(step.y)))
			await action("gate%d" % int(step.gate))
		else:
			await purchase(step.kind, int(step.x), int(step.y), int(step.lane))

func confirm_transition(accept: bool) -> void:
	var button: Button = game.abandon_dialog.get_ok_button() if accept else game.abandon_dialog.get_cancel_button()
	await tap(Vector2(game.abandon_dialog.position) + button.get_global_rect().get_center())

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		DirAccess.remove_absolute("user://campaign-input.json" + suffix)
	await create_game()
	check(game.screen == "map" and game.profile.cleared.is_empty(), "Fresh journey opens map with no synthetic clears")
	await frame("00-journey-map")
	await action("mission8")
	check(game.state.encounter == "camp_01" and game.screen == "map", "Locked finale cannot be entered")
	await action("mission0")
	check(game.screen == "game" and game.state.encounter == "camp_01", "Actual map tap starts first foundry")
	# Lose with the unchanged disconnected starter, then retry immediately.
	await action("begin")
	await advance(60)
	check(game.state.phase == "defeat" and game.profile.cleared.is_empty(), "Failed first defense cannot unlock progression")
	await frame("01-first-defeat")
	await action("begin")
	check(game.state.phase == "ready" and game.state.wall == game.state.config.wall, "Campaign retry resets only the active run")
	for chapter in 9:
		var id: String = Content.IDS[chapter]
		check(game.state.encounter == id, "Navigation reached " + id)
		var plan := "A" if chapter % 2 == 0 else "B"
		await steps(Policy.plan(game.state, plan))
		check(Gear.powered(game.state.board).size() == game.state.board.size(), "Input preparation fully powers " + id)
		await frame("%02d-prepared" % (chapter + 2))
		await action("begin")
		if chapter == 0:
			await advance(8)
			await key_back()
			check(game.paused and game.screen == "game", "Back first pauses and saves battle")
			await key_back()
			check(game.screen == "map", "Second Back opens journey while keeping run")
			await action("resume_run")
			check(game.paused and game.state.phase == "battle", "Map resume keeps battle paused")
			await action("save")
			await key_back()
			check(not game.save_dialog.visible and game.screen == "game", "Back closes save modal before navigation")
			await action("pause")
		for segment in 110:
			await steps(Policy.adaptations(game.state, plan))
			await advance(4)
			if segment == 8 and chapter in [0, 4, 8]:
				await frame("%02d-live" % (chapter + 2))
			if segment == 10 and chapter == 4:
				await action("save")
				var source: String = game.save_text.text
				var packet := Saves.decode(source)
				check(packet.ok, "Portable campaign save validates: " + str(packet.get("message", "valid")))
				if not packet.ok:
					quit(1)
					return
				check(packet.profile.cleared.size() == 4, "Portable save contains profile and active run separately")
				if DisplayServer.get_name() != "headless":
					await type_save(source)
					await dialog_action("Import")
					check(game.paused and game.profile.cleared.size() == 4 and game.state.encounter == id, "Actual import preserves mid-arc profile and active content snapshot")
				else:
					await key_back()
				var time_before: float = game.state.time
				game.queue_free()
				await process_frame
				await create_game()
				check(game.profile.cleared.size() == 4 and is_equal_approx(float(game.state.time), time_before), "Cold scene reload preserves mid-campaign run and profile")
				await action("resume_run")
				await action("pause")
			if game.state.phase != "battle":
				break
		check(game.state.phase == "victory", "Actual-input campaign victory at " + id)
		if game.state.phase != "victory":
			break
		check(id in game.profile.cleared and Profile.accessible(game.profile, Content.IDS[mini(chapter + 1, 8)]), "Victory unlocks next foundry")
		journey.append({"id": id, "policy": plan, "seconds": game.state.time, "wall": game.state.wall, "losses": game.state.losses, "spent": game.state.spent, "cap_seconds": game.state.cap_time})
		print("INPUT JOURNEY ", journey.back())
		await frame("%02d-victory" % (chapter + 2))
		await action("next")
	check(game.profile.cleared.size() == 9 and game.screen == "ending", "Full actual-input arc reaches ending with all nine clears")
	await frame("12-ending")
	if game.profile.cleared.size() == 9:
		await action("challenges")
		check(game.screen == "challenges", "Ending unlocks curated replay menu")
		await frame("13-challenges")
		await action("challenge0")
		check(bool(game.state.config.challenge) and game.state.seed == 1729, "Seeded challenge uses explicit versioned run config")
		await steps(Policy.plan(game.state, "A"))
		await move(1, 1, 1, 0)
		check(not game.undo_board.is_empty() and game.state.next_id > 6, "Practice regression has campaign-only IDs and a pending undo")
		await action("begin")
		await action("map")
		var before_practice: String = Saves.encode(game.state, game.settings, 0, true, game.profile)
		await action("practice")
		check(game.abandon_dialog.visible, "Practice asks before replacing an active defense")
		await confirm_transition(false)
		check(Saves.encode(game.state, game.settings, 0, true, game.profile) == before_practice and not game.undo_board.is_empty(), "Cancel preserves active defense and undo exactly")
		await action("practice")
		await confirm_transition(true)
		check(game.state.encounter == "tutorial" and game.undo_board.is_empty() and game.profile.cleared.size() == 9, "Confirmed practice resets transient undo while retaining campaign progress")
		await action("undo")
		check(Saves.decode(Saves.encode(game.state, game.settings, 0, true, game.profile)).ok and game.persist(), "Practice then Undo remains valid and normally saveable")
	var total := 0.0
	for entry in journey:
		total += float(entry.seconds)
	var report := {"checks": checks, "failures": failures, "pointer_events": pointer_events, "keyboard_events": key_events, "journey": journey, "simulated_combat_seconds": total, "result": "passed" if failures.is_empty() else "failed", "scope": "actual input; simulation time accelerated; not human/phone acceptance"}
	var file := FileAccess.open(evidence + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("CAMPAIGN INPUT: ", checks, " checks; ", journey.size(), " clears; ", total, " combat seconds; ", failures.size(), " failures")
	print("SUITE_COMPLETE: PASS" if failures.is_empty() else "SUITE_COMPLETE: FAIL")
	quit(0 if failures.is_empty() else 1)
