extends "res://tests/legacy_playthrough.gd"
const Content = preload("res://scripts/campaign_data.gd")
const Profile = preload("res://scripts/campaign_profile.gd")
const Policy = preload("res://tests/campaign_policies.gd")
var journey: Array = []
var replay_results: Array = []
var decision_results: Array = []
var motion_directory := "res://.artifacts/campaign-pressure-motion"

func _initialize() -> void:
	super._initialize()
	evidence = "res://.artifacts/campaign-pressure-input" + ("/headless" if DisplayServer.get_name() == "headless" else "")

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

func action(key: String) -> void:
	if game.buttons().has(key):
		await tap(game.buttons()[key].get_center())
		return
	await tap(game.buttons().menu.get_center())
	var button: Button = game.menu_dialog.find_child("Action_" + key, true, false)
	check(button != null, "Menu contains " + key)
	if button != null:
		await tap(Vector2(game.menu_dialog.position) + button.get_global_rect().get_center())

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
			var allowed := Gear.buy(game.state.board, step.kind, int(step.x), int(step.y), int(game.state.gold), int(game.state.next_id), game.state.encounter, game.state.config)
			if allowed.ok:
				await purchase(step.kind, int(step.x), int(step.y), int(step.lane))

func confirm_transition(accept: bool) -> void:
	var button: Button = game.abandon_dialog.get_ok_button() if accept else game.abandon_dialog.get_cancel_button()
	await tap(Vector2(game.abandon_dialog.position) + button.get_global_rect().get_center())

func motion_snapshot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(motion_directory)
	var file := FileAccess.open(motion_directory + "/" + name + ".json", FileAccess.WRITE)
	file.store_string(Saves.encode(game.state, game.settings, 0, true, game.profile))
	file.close()

func outcome() -> Dictionary:
	return {"phase": game.state.phase, "seconds": game.state.time, "wall": game.state.wall, "losses": game.state.losses, "spent": game.state.spent, "gold": game.state.gold, "produced": game.state.produced, "cap_seconds": game.state.cap_time, "medals": game.profile.medals.get(game.state.encounter, 0)}

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
	var first_mistake := outcome()
	await action("begin")
	check(game.state.phase == "ready" and game.state.wall == game.state.config.wall, "Campaign retry resets only the active run")
	for chapter in 9:
		var id: String = Content.IDS[chapter]
		check(game.state.encounter == id, "Navigation reached " + id)
		var plan := "A" if chapter % 2 == 0 else "B"
		var mistaken: Dictionary = first_mistake
		if chapter > 0:
			var policy: String = ["starter", "ranger", "guard", "guard", "ranger", "guard", "A", "splash", "guard"][chapter]
			await steps(Policy.plan(game.state, policy))
			await action("begin")
			for segment in 125:
				if policy == "splash":
					await steps(Policy.adaptations(game.state, policy))
				await advance(4)
				if game.state.phase != "battle":
					break
			mistaken = outcome()
			check(game.state.phase != "battle", "Mistake witness reaches a bounded outcome at " + id)
			await frame("%02d-mistake" % (chapter + 2))
			await action("begin")
		await steps(Policy.plan(game.state, plan))
		check(Gear.powered(game.state.board).size() == game.state.board.size(), "Input preparation fully powers " + id)
		await frame("%02d-prepared" % (chapter + 2))
		await action("begin")
		if chapter == 0:
			await advance(8)
			motion_snapshot("early")
			await key_back()
			check(game.paused and game.screen == "game", "Back first pauses and saves battle")
			await key_back()
			check(game.screen == "map", "Second Back opens journey while keeping run")
			await action("resume_run")
			check(game.paused and game.state.phase == "battle", "Map resume keeps battle paused")
			await action("menu")
			await key_back()
			check(not game.menu_dialog.visible and game.screen == "game" and game.paused, "Back closes utility menu before leaving paused defense")
			await action("save")
			await key_back()
			check(not game.save_dialog.visible and game.screen == "game", "Back closes save modal before navigation")
			await action("pause")
		var boss_snapshot := false
		for segment in 110:
			await steps(Policy.adaptations(game.state, plan))
			await advance(4)
			if segment == 8 and chapter in [0, 4, 8]:
				await frame("%02d-live" % (chapter + 2))
				if chapter == 4:
					motion_snapshot("middle")
			if chapter == 8 and game.state.boss_spawned and game.state.phase == "battle" and not boss_snapshot:
				motion_snapshot("final-boss")
				await frame("10-final-boss")
				boss_snapshot = true
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
		var corrected := outcome()
		var saved_resources: bool = int(corrected.spent) + 6 <= int(mistaken.spent) and float(corrected.wall) >= float(mistaken.wall) and float(corrected.seconds) <= float(mistaken.seconds) * 1.05
		var improved: bool = mistaken.phase != "victory" or float(corrected.wall) > float(mistaken.wall) + 1 or int(corrected.losses) < int(mistaken.losses) * 0.8 or float(corrected.seconds) < float(mistaken.seconds) * 0.9 or saved_resources
		check(improved, "Retry correction improves outcome, wall or efficiency at " + id)
		var explanation: String = ["Connect the stopped starter and fund production", "Screen unshielded rangers", "Add ranged damage against captain armor", "Use splash and ranged support through dense packs", "Protect rangers on the broken flanks", "Use ranged damage to shorten siege attrition", "Reallocate future production with the shifting fronts", "Use a focused ranger refit instead of expensive splash and drive expansion", "Keep a mixed army through the final assault"][chapter]
		decision_results.append({"id": id, "decision": explanation, "mistake": mistaken, "correction": corrected, "improved": improved, "scope": "actual input, Retry preparation correction; simulated time accelerated"})
		print("INPUT DECISION ", JSON.stringify(decision_results.back()))
		print("INPUT JOURNEY ", journey.back())
		await frame("%02d-victory" % (chapter + 2))
		await action("next")
	check(game.profile.cleared.size() == 9 and game.screen == "ending", "Full actual-input arc reaches ending with all nine clears")
	await frame("12-ending")
	motion_snapshot("ending")
	if game.profile.cleared.size() == 9:
		await action("challenges")
		check(game.screen == "challenges", "Ending unlocks curated replay menu")
		await frame("13-challenges")
		for slot in 3:
			await action("challenge%d" % slot)
			var replay_id: String = game.state.encounter
			var replay_policy := "A" if slot == 0 else "B"
			await steps(Policy.plan(game.state, replay_policy))
			await action("begin")
			for segment in 110:
				await steps(Policy.adaptations(game.state, replay_policy))
				await advance(4)
				if game.state.phase != "battle":
					break
			var key := replay_id + ":" + str(1729 + slot)
			check(game.state.phase == "victory" and game.profile.challenge_clears.has(key) and game.profile.cleared.size() == 9, "Actual-input reduced-budget replay clear recorded separately for " + replay_id)
			replay_results.append({"id": replay_id, "seed": game.state.seed, "policy": replay_policy, "phase": game.state.phase, "wall": game.state.wall, "seconds": game.state.time, "medals": game.profile.challenge_clears.get(key, 0)})
			await frame("14-replay-%d" % slot)
			await action("next")
			check(game.screen == "challenges", "Replay victory returns to trials without starting another campaign encounter")
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
	var report := {"checks": checks, "failures": failures, "pointer_events": pointer_events, "keyboard_events": key_events, "journey": journey, "decisions": decision_results, "replays": replay_results, "simulated_combat_seconds": total, "result": "passed" if failures.is_empty() else "failed", "scope": "actual input; simulation time accelerated; not human/phone acceptance"}
	var file := FileAccess.open(evidence + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("CAMPAIGN INPUT: ", checks, " checks; ", journey.size(), " clears; ", total, " combat seconds; ", failures.size(), " failures")
	print("SUITE_COMPLETE: PASS" if failures.is_empty() else "SUITE_COMPLETE: FAIL")
	game.audio.stop()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
