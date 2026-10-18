extends "res://tests/playthrough.gd"
const C = preload("res://scripts/campaign_rules.gd")
const Cat = preload("res://scripts/campaign_catalog.gd")
const Policy = preload("res://tests/campaign_policy.gd")
var game_root: Node
var segment := ""
var checkpoint := ""
var route: Array = []
var saved_segments := {}
var valid_reads := true
var replay_results: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--checkpoint="):
			checkpoint = arg.trim_prefix("--checkpoint=")
		elif arg.begins_with("--segment="):
			segment = arg.trim_prefix("--segment=")
	call_deferred("run")

func load_app() -> void:
	game_root = load("res://main.tscn").instantiate()
	root.add_child(game_root)
	await dwell(4)
	scene = game_root.get_node("Battle")
	dragging_origin = Vector2(110, 850)

func run() -> void:
	root.size = Vector2i(720, 1280)
	if not checkpoint.is_empty():
		# Byte-for-byte installation of a code written by the prior earned route.
		var code := FileAccess.get_file_as_string(checkpoint)
		check(S.decode(code).ok, "declared earned checkpoint checks before normal load")
		var f := FileAccess.open(S.PATH + "0", FileAccess.WRITE)
		f.store_string(code)
		f.close()
	await load_app()
	check(scene.state.schema == 2, "new install/earned campaign loads catalog2 mode")
	await snap("opening")
	if not segment.is_empty():
		if scene.paused:
			await click("RESUME")
		if scene.state.phase == "ready":
			await click("BEGIN WATCH")
		await play_watch(1 if scene.state.definition.stage == 8 else 0, 52.0 if segment == "early" else 42.0)
		if scene.state.phase == "victory":
			await dwell(90)
		await snap("segment-ending")
		finish_report()
		await exit_app()
		return
	check(scene.campaign_profile.clears.is_empty() and scene.profile.attempts == 0, "fresh expedition does not invent prototype/campaign progress")
	await click("BEGIN WATCH")
	for frame in 12000:
		if scene.state.phase != "playing":
			break
		await physics_frame
	check(scene.state.phase == "defeat", "actual idle opening loses naturally from leaks")
	await snap("opening-natural-loss")
	var earned: Dictionary = scene.campaign_profile.duplicate(true)
	await click("RETRY PASS")
	var remaining_supply := 0
	for coin in scene.state.coins:
		remaining_supply += int(coin.value)
	check(scene.state.phase == "playing" and scene.state.spent == 0 and scene.state.wallet + remaining_supply == scene.state.definition.supply and scene.campaign_profile == earned, "actual campaign Retry restores budget while keeping whole earned profile")
	for stage in 10:
		if scene.state.phase == "ready":
			await click("BEGIN WATCH")
		check(scene.state.definition.stage == stage, "actual Next opens map " + str(stage + 1))
		await snap("map%02d-opening" % (stage + 1))
		if stage == 4:
			await move_to(C.pad_point(scene.state.definition, 1), 300)
			await click(scene.action_buttons[2].text)
			check(scene.state.towers[1].family == 2, "actual mistaken remote Beacon investment")
			for frame in 12000:
				if scene.state.phase != "playing":
					break
				await physics_frame
			check(scene.state.phase == "defeat" and scene.state.shots[2] < 10, "wrong-side coverage causes diagnosable natural loss")
			await snap("map05-wrong-road-loss")
			earned = scene.campaign_profile.duplicate(true)
			var pinned: Dictionary = scene.state.definition.duplicate(true)
			await click("RETRY PASS")
			check(scene.campaign_profile == earned and scene.state.definition == pinned, "mistake Retry retains records and exact pinned map")
			# A deliberate paid refit: buy, sell at70%, change coverage/family.
			await gather_supply()
			await move_to(C.pad_point(scene.state.definition, 1), 400)
			await click(scene.action_buttons[0].text)
			var wallet: int = scene.state.wallet
			await click(scene.action_buttons[2].text)
			check(scene.state.refunded == 7 and scene.state.wallet == wallet + 7 and scene.state.towers[1].family == -1, "actual Sell refunds70% and releases occupied pad")
			await snap("map05-paid-refit")
		await play_watch(1 if stage in [4, 8] else 0)
		check(scene.state.phase == "victory", "actual engine-input route clears map " + str(stage + 1))
		check(scene.terminal.visible and scene.terminal_title.text != "REFUGE BREACHED", "natural terminal rendered map " + str(stage + 1))
		check(C.valid(scene.state) and scene.campaign_profile.clears.size() == stage + 1, "valid earned state and unique clear map " + str(stage + 1))
		await snap("map%02d-natural-win" % (stage + 1))
		route.append({"stage": stage, "definition": scene.state.definition.duplicate(true), "time": scene.state.time, "leaks": scene.state.leaked.size(), "ledger": scene.state.ledger.duplicate(true), "shots": scene.state.shots.duplicate(), "profile": scene.campaign_profile.duplicate(true)})
		await dwell(35)
		await click("THE TEN BEACONS" if stage == 9 else "NEXT HEARTH")
	check(scene.ending_panel.visible and scene.campaign_profile.ending, "earned conclusive ten-beacon finale opens through actual input")
	await snap("earned-epilogue")
	await click("BACK TO JOURNEY")
	# Replay options are actual controls, then an unlocked seeded endless watch.
	await click(scene.seed_button.text)
	await click(scene.budget_button.text)
	await click(scene.mirror_button.text)
	await click("SEEDED ENDLESS")
	check(scene.state.definition.endless == 0 and scene.state.definition.seed == 2 and scene.state.definition.mirror and scene.state.definition.budget == 1, "real controls pin seed/budget/mirrored endless options")
	await click("BEGIN WATCH")
	await play_watch(0)
	check(scene.state.phase == "victory" and scene.campaign_profile.endless_best.get("2", 0) == 1 and scene.campaign_profile.clears.size() == 10, "actual seeded endless win earns separate survival record")
	await snap("endless-watch-win")
	await click("NEXT ENDLESS WATCH")
	check(scene.state.definition.endless == 1 and scene.state.definition.seed == 2 and scene.state.definition.mirror, "endless continues next deterministic watch with options retained")
	await click("BEGIN WATCH")
	await click("II")
	var memory := whole_memory()
	await click("JOURNEY / REPLAY")
	check(scene.pause_button.disabled, "Journey blocks the header resume action while modal")
	await tap(scene.pause_button.get_global_rect().get_center(), "disabled modal header")
	await dwell(30)
	check(whole_memory() == memory and scene.journey.visible, "touching modal header cannot resume hidden combat")
	await click(scene.map_buttons[0].text)
	check(scene.confirm_panel.visible and whole_memory() == memory, "active navigation waits for explicit replacement decision")
	await click("KEEP WATCH")
	await click("BACK TO WATCH")
	check(whole_memory() == memory, "Keep Watch preserves complete active run")
	await click("RESUME")
	await click("II")
	await click("JOURNEY / REPLAY")
	await click(scene.map_buttons[8].text)
	check(scene.confirm_panel.visible, "seeded campaign replay explicitly requests active-watch replacement")
	await click("REPLACE WATCH")
	check(scene.state.definition.stage == 8 and scene.state.definition.seed == 2 and scene.state.definition.budget == 1 and scene.state.definition.mirror, "confirmed replay pins selected seed/budget/road options")
	await click("BEGIN WATCH")
	await play_watch(1)
	check(scene.state.phase == "victory" and scene.state.leaked.is_empty() and scene.campaign_profile.records.pass09.leaks == 0, "actual seeded replay earns improved no-leak mastery")
	check(scene.campaign_profile.clears.size() == 10 and scene.campaign_profile.records.pass09.clears == 2, "replay improves record without duplicate campaign clears")
	replay_results.append({"definition": scene.state.definition.duplicate(true), "time": scene.state.time, "leaks": scene.state.leaked.size()})
	await snap("seeded-campaign-no-leak-replay")
	await click("NEXT HEARTH")
	await click("BEGIN WATCH")
	await play_watch(1)
	check(scene.state.phase == "victory" and C.equivalent(scene.state.definition, route[9].definition), "second actual final-map layout wins on the identical funded definition")
	check(scene.state.ledger != route[9].ledger, "actual alternate final layout uses different paid family/fork choices")
	replay_results.append({"definition": scene.state.definition.duplicate(true), "time": scene.state.time, "leaks": scene.state.leaked.size(), "ledger": scene.state.ledger.duplicate(true), "scope": "Second actual input layout on same canonical finale."})
	await snap("alternate-final-layout-natural-win")
	await click("THE TEN BEACONS")
	await click("BACK TO JOURNEY")
	await click(scene.map_buttons[0].text)
	await click("BEGIN WATCH")
	await click("II")
	await click("SAVE / TRANSFER")
	await check_transfer()
	check(valid_reads, "observed earned states remain valid through route")
	finish_report()
	await exit_app()

func play_watch(variant: int, max_seconds: float = 650.0) -> void:
	var began: float = scene.state.time
	var old_actions: int = scene.state.ledger.size()
	var boss_seen := false
	for frame in int(max_seconds * 60):
		if scene.state.phase != "playing" or scene.state.time - began >= max_seconds:
			break
		var plan := Policy.plan(scene.state, variant)
		if plan.affordable and C.position(scene.state).distance_to(plan.goal) < 1.4:
			await release()
			await click(scene.action_buttons[int(plan.choice)].text)
			if scene.state.ledger.size() > old_actions:
				old_actions = scene.state.ledger.size()
				if old_actions in [1, 3, 6, 12]:
					await snap("map%02d-invest%02d" % [int(scene.state.definition.stage) + 1, old_actions])
		else:
			await steer((plan.goal - C.position(scene.state)).limit_length())
			await physics_frame
		if frame % 600 == 0:
			valid_reads = valid_reads and C.valid(scene.state)
		if frame % 1800 == 0:
			print("JOURNEY_PROGRESS map=",scene.state.definition.stage + 1," t=",scene.state.time," gold=",scene.state.wallet," investments=",scene.state.ledger.size()," leaks=",scene.state.leaked.size())
		if segment.is_empty() and scene.state.definition.stage in [5, 9] and scene.state.time >= (157 if scene.state.definition.stage == 5 else 205) and not saved_segments.has(scene.state.definition.stage):
			await checkpoint_segment("middle" if scene.state.definition.stage == 5 else "final")
			if scene.state.definition.stage == 5:
				await active_layout_reload()
	await release()
	await dwell(3)

func checkpoint_segment(name: String) -> void:
	await click("II")
	var disk := S.read()
	check(disk.ok and disk.state.schema == 2 and disk.state.phase == "playing", "earned " + name + " checkpoint written by app")
	if not folder.is_empty() and disk.ok:
		var file := FileAccess.open(folder.path_join(name + "-earned.code"), FileAccess.WRITE)
		file.store_string(FileAccess.get_file_as_string(S.PATH + str(disk.slot)))
		file.close()
	saved_segments[scene.state.definition.stage] = true
	await click("RESUME")

func active_layout_reload() -> void:
	await click("II")
	var memory := whole_memory()
	await dwell(60)
	check(whole_memory() == memory, "active campaign pause freezes whole battle/profile/settings")
	root.size = Vector2i(1000, 1110)
	await dwell(4)
	check(whole_memory() == memory, "active campaign whole state survives inner proportion")
	await snap("middle-active-inner")
	await click("RESUME")
	await click("II")
	memory = whole_memory()
	root.size = Vector2i(720, 1680)
	await dwell(4)
	check(whole_memory() == memory, "active campaign whole state survives tall cover proportion")
	await snap("middle-active-tall-cover")
	root.size = Vector2i(720, 1280)
	await dwell(4)
	var disk := S.read()
	game_root.queue_free()
	await process_frame
	await process_frame
	await load_app()
	check(scene.paused and C.equivalent(scene.state, disk.state) and scene.campaign_profile == disk.campaign, "ordinary cold reload restores pinned middle run and earned profile paused")
	await click("RESUME")

func gather_supply() -> void:
	for frame in 500:
		if scene.state.collected.size() >= 6:
			break
		var goal := C.position(scene.state)
		for c in scene.state.coins:
			if c.id < 6:
				goal = Vector2(c.x, c.z)
		await steer((goal - C.position(scene.state)).limit_length())
		await physics_frame
	await release()

func move_to(goal: Vector2, frames: int) -> void:
	for frame in frames:
		if C.position(scene.state).distance_to(goal) < 1.3:
			break
		await steer((goal - C.position(scene.state)).limit_length())
		await physics_frame
	await release()

func check_transfer() -> void:
	var exported: String = scene.code_edit.text
	check(S.decode(exported).ok, "whole active endless code exports")
	await click("COPY")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		check(DisplayServer.clipboard_get() == exported, "campaign real clipboard exact export")
	await tap(scene.code_edit.get_global_rect().position + Vector2(60, 40))
	check(scene.code_edit.has_focus(), "campaign transfer TextEdit receives real touch focus")
	await key(KEY_END, true)
	await key(KEY_X, false, 88)
	var memory := whole_memory()
	var disk := disk_bytes()
	await click("IMPORT")
	check(whole_memory() == memory and disk_bytes() == disk, "malformed campaign import retains complete memory and disk")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		await click("PASTE")
		check(scene.code_edit.text == exported, "real campaign Paste restores code")
	else:
		# Text staging only for a platform with no clipboard; no earned state edit.
		scene.code_edit.text = exported
	var io := preload("res://tests/fault_files.gd").new()
	for path in [S.PATH + "0", S.PATH + "1"]:
		if FileAccess.file_exists(path):
			io.files[path] = FileAccess.get_file_as_string(path)
	io.fail_rename = true
	scene.save_io = io
	await click("IMPORT")
	check(whole_memory() == memory and disk_bytes() == disk and scene.notice.text.begins_with("Storage failed"), "synthetic storage-failed valid campaign import retains everything")
	scene.save_io = null
	await click("IMPORT")
	check(not scene.transfer.visible and scene.paused and S.read().campaign == S.decode(exported).campaign, "valid campaign import commits whole profile then pauses")
	await key(KEY_ESCAPE)
	check(not scene.paused, "Back resumes underlying imported active watch")
	await click("II")
	await click("SOUND  ON")
	await click("REDUCED EFFECTS  OFF")
	check(not scene.settings.sound and scene.settings.reduced_effects, "campaign settings controls saved")
	await snap("campaign-transfer-settings")

func click(text: String) -> void:
	var target: Button
	for b in scene.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			target = b
	if target != null and scene.journey_list.is_ancestor_of(target):
		for attempt in 40:
			var area: Rect2 = scene.journey_scroll.get_global_rect()
			if area.encloses(target.get_global_rect()):
				break
			var wheel := InputEventMouseButton.new()
			wheel.position = root.get_final_transform() * area.get_center()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if target.get_global_rect().get_center().y > area.get_center().y else MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			Input.parse_input_event(wheel)
			Input.flush_buffered_events()
			events.append({"frame": Engine.get_physics_frames(), "kind": "journey_scroll", "button": wheel.button_index, "position": [wheel.position.x, wheel.position.y]})
			await process_frame
			wheel.pressed = false
			Input.parse_input_event(wheel)
			Input.flush_buffered_events()
			await process_frame
	await super.click(text)

func whole_memory() -> Dictionary:
	return {"state": scene.state.duplicate(true), "legacy_profile": scene.profile.duplicate(true), "campaign_profile": scene.campaign_profile.duplicate(true), "settings": scene.settings.duplicate(true), "paused": scene.paused}

func snap(name: String) -> void:
	print("CAMPAIGN_SNAPSHOT ",name," map=",scene.state.definition.stage + 1," time=",scene.state.time," gold=",scene.state.wallet," ledger=",scene.state.ledger.size())
	snapshots.append({"name": name, "frame": Engine.get_physics_frames(), "live": whole_memory(), "app_written": S.read()})
	if not folder.is_empty():
		var file := FileAccess.open(folder.path_join(name + "-saves.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(disk_bytes(), "  "))
		file.close()
	if DisplayServer.get_name() != "headless" and not folder.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))

func finish_report() -> void:
	if not folder.is_empty():
		var file := FileAccess.open(folder.path_join("campaign-input.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "route": route, "replays": replay_results, "snapshots": snapshots, "segment": segment, "loaded_earned_checkpoint": checkpoint, "scope": "Actual engine ScreenTouch/drag/GUI/key input at fixed60Hz with normal processing. State-read policy, no injected earned economy/progress or forced redraw. Scripted simulation duration is not human timing or measured phone FPS. Declared clip checkpoint is a byte copy from this earned route; storage fault adapters are synthetic."}, "  "))
		file.close()
		file = FileAccess.open(folder.path_join("raw-input.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(events))
		file.close()
	print("CAMPAIGN_INPUT: ",checks," checks, failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures == 0 else "FAIL")

func exit_app() -> void:
	game_root.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
