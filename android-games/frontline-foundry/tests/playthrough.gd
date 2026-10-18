extends SceneTree
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const Faults = preload("res://tests/fault_files.gd")
var scene: Node
var folder := ""
var checks := 0
var failures := 0
var details: Array = []
var events: Array = []
var snapshots: Array = []
var combat_events: Array = []
var touch_active := false
var dragging_origin := Vector2(120, 1155)
var movie_only := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		if arg == "--movie-only":
			movie_only = true
	call_deferred("run")

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(8)
	print("ISOLATED_USER_DATA ", OS.get_user_data_dir())
	check(scene.state.phase == "ready" and scene.profile.attempts == 0, "fresh app and bootstrap, no injected progress")
	await snap("01-ready")
	await click("BREAK THE SIEGE")
	check(scene.state.phase == "playing", "real ScreenTouch begins siege")
	if not movie_only:
		await travel_until_terminal(Vector2(4.3, 5.5))
		check(scene.state.phase == "defeat" and scene.state.hq == 0 and scene.state.hp == 100, "natural HQ leak defeat through ordinary processing")
		check(scene.terminal.visible and scene.terminal_title.text == "FOUNDRY LOST", "natural HQ defeat actually displayed")
		await snap("02-hq-defeat")
		await retry_checked("03-retry-hq")
	await win_route()
	if not movie_only:
		await transfer_and_lifecycle()
	await retry_checked("15-retry-win")
	await travel_until_terminal(Vector2(-1.7, -5.7))
	check(scene.state.phase == "defeat" and scene.state.hp == 0 and scene.state.hq > 0, "actual movement to enemy fire causes independent commander defeat")
	check(scene.terminal.visible and scene.terminal_title.text == "FOUNDRY LOST", "natural commander defeat displayed without forced redraw")
	await snap("16-commander-defeat")
	await dwell(80)
	await retry_checked("17-immediate-retry")
	await dwell(35)
	await snap("18-final")
	write_report()
	if not folder.is_empty():
		var f := FileAccess.open(folder.path_join("combat-events.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(combat_events + scene.event_log))
	scene.queue_free()
	await process_frame
	await process_frame
	print("FRONTLINE_INPUT ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func travel_until_terminal(goal: Vector2) -> void:
	for frame in 7000:
		if scene.state.phase != "playing":
			break
		await steer((goal - R.position(scene.state)).limit_length())
		await physics_frame
	await release()
	await dwell(3)

func retry_checked(name: String) -> void:
	var p: Dictionary = scene.profile.duplicate(true)
	var settings: Dictionary = scene.settings.duplicate(true)
	await click("RETRY SIEGE")
	check(scene.state.phase == "playing" and scene.state.hp == 100 and scene.state.hq == 120 and scene.state.wallet == 8 and scene.state.spent == 0 and scene.state.consumed == [0, 0] and scene.state.killed.is_empty(), "actual immediate Retry restores finite budget, HQ, commander and queues")
	check(scene.profile == p and scene.settings == settings, "Retry preserves whole earned profile and settings")
	await snap(name)

func win_route() -> void:
	var equip := false
	var departing := false
	var attacks := false
	var rover := false
	var pickup := false
	var armor := false
	var commander_fired := false
	var valid_ticks := true
	for frame in 6500:
		var s: Dictionary = scene.state
		if s.phase != "playing":
			break
		var goal := Vector2(0, 1.4)
		var pad := -1
		if not s.pads[0] and s.commander_shots < 3:
			goal = Vector2(-1.7, -3.3)
		elif not s.pads[0]:
			goal = R.PADS[0]
			pad = 0
		elif not s.pads[1] and s.wallet >= 14:
			goal = R.PADS[1]
			pad = 1
		elif not s.pads[1] and not s.coins.is_empty():
			goal = Vector2(s.coins[0].x, s.coins[0].z)
		if pad >= 0 and R.nearby_pad(s) == pad:
			await release()
			await snap("05-before-rifles" if pad == 0 else "09-before-rover")
			var old_spent: int = s.spent
			await click(scene.build_button.text)
			check(s.pads[pad] and s.spent == old_spent + R.COSTS[pad], "explicit contextual ScreenTouch spends exact station price " + str(pad))
			if not s.pads[pad]:
				print("INPUT_BUY_FAILURE ", JSON.stringify(scene.state), " ui=", scene.build_button.get_global_rect())
				break
			await snap("06-rifle-station" if pad == 0 else "10-rover-station")
		else:
			await steer((goal - R.position(s)).limit_length())
			await physics_frame
		if not commander_fired and s.commander_shots > 0:
			commander_fired = true
			check(not s.pads[0] and s.commander_shots > 0, "commander's own nearby fire precedes station investment")
			await snap("04-commander-fire")
		if not equip and s.recruits[0].phase == "equipping":
			equip = true
			check(s.stock[0] == 2 and s.consumed[0] == 1, "first recruit visibly equips one owned rifle token")
			await snap("07-visible-arming")
		if not departing and s.recruits[0].phase == "deploying":
			departing = true
			await snap("08-departure")
		if not attacks and s.recruits[0].shots > 0:
			attacks = true
			check(s.recruits[0].damage > 0, "recruit owns real attacks and independently damages enemy")
			await snap("08b-recruit-combat")
			if not movie_only:
				await active_lifecycle()
		if not pickup and s.collected.size() >= 2:
			pickup = true
			await snap("08c-earned-scrap")
		if not rover and s.recruits[3].shots > 0:
			rover = true
			check(s.recruits[3].damage > 0 and s.consumed[1] == 1, "rover departs workshop and its cannon damages own target")
			await snap("11-vehicle-combat")
		if not armor and s.enemies.any(func(e): return e.armored):
			armor = true
			await snap("12-armored-siege")
		valid_ticks = valid_ticks and R.valid(scene.state)
		if frame % 600 == 0:
			print("INPUT_PROGRESS ", frame, " t=", s.time, " wallet=", s.wallet, " pads=", s.pads, " hp=", s.hp)
	await release()
	await dwell(3)
	check(equip and departing and attacks and pickup and rover and armor, "complete movement, fighting, equipment, queue, reward, vehicle and armor chain")
	check(valid_ticks, "every input-earned route tick stays structurally/economically valid")
	check(scene.state.commander_shots >= 3 and scene.state.pads == [true, true], "commander fights before returning to both investments")
	check(scene.state.phase == "victory" and scene.state.killed.size() >= 8, "actual-input reinforcement route reaches natural objective victory")
	check(scene.terminal.visible and scene.terminal_title.text == "SIEGE BROKEN", "untouched natural victory rendered by ordinary processing")
	await snap("13-natural-victory")
	await dwell(100)

func active_lifecycle() -> void:
	await release()
	await click("II")
	var before := whole_memory()
	await dwell(50)
	check(whole_memory() == before, "pause freezes entire active state")
	root.size = Vector2i(1154, 1280)
	await dwell(4)
	check(whole_memory() == before, "inner display proportions preserve active battle")
	await snap("08d-active-inner-paused")
	root.size = Vector2i(720, 1680)
	await dwell(4)
	check(whole_memory() == before, "tall cover proportions preserve whole active battle")
	await snap("08e-active-tall-paused")
	root.size = Vector2i(720, 1280)
	await dwell(4)
	var saved := S.read()
	check(saved.ok, "active app-written checkpoint valid before scene reload")
	combat_events.append_array(scene.event_log)
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(4)
	check(scene.paused and scene.state == saved.state and scene.profile == saved.profile and scene.settings == saved.settings, "scene reload restores exact whole app-written active state, paused")
	await dwell(50)
	check(scene.state == saved.state, "restored active state stays frozen until explicit Resume")
	await click("RESUME")
	check(not scene.paused, "actual Resume continues restored battle")

func transfer_and_lifecycle() -> void:
	await click("II")
	await click("SOUND  ON")
	await click("REDUCED EFFECTS  OFF")
	check(not scene.settings.sound and scene.settings.reduced_effects, "real settings buttons persist sound/effects choices")
	await click("SAVE / TRANSFER")
	await click("EXPORT")
	var original: String = scene.code_edit.text
	check(S.decode(original).ok, "Export creates complete checked local code")
	if DisplayServer.get_name() != "headless":
		check(DisplayServer.clipboard_get() == original and scene.notice.text == "Code copied.", "Export directly copies exact complete code with honest feedback")
	await tap(scene.code_edit.get_global_rect().position + Vector2(80, 50))
	check(scene.code_edit.has_focus(), "actual ScreenTouch gives TextEdit focus via mouse emulation")
	await key(KEY_END, true)
	await key(KEY_X, false, 88)
	check(scene.code_edit.text.ends_with("X") and scene.code_edit.text != original, "real focused keyboard edits touched code")
	var memory := whole_memory()
	var disk := disk_bytes()
	await click("IMPORT")
	check(whole_memory() == memory and disk_bytes() == disk, "invalid Import retains entire progress/settings and all durable bytes")
	await snap("14-invalid-import")
	if DisplayServer.get_name() != "headless":
		await click("PASTE")
		check(scene.code_edit.text == original, "actual Paste restores exact original exported code")
	else:
		# Clipboard does not exist on headless DisplayServer. Fixture only, not clipboard proof.
		scene.code_edit.text = original
	var faults := Faults.new()
	faults.files = disk.duplicate(true)
	faults.fail_rename = true
	scene.save_io = faults
	await click("IMPORT")
	check(whole_memory() == memory and disk_bytes() == disk and scene.transfer.visible, "synthetic storage rename failure preserves whole current memory and real disk")
	scene.save_io = null
	await click("IMPORT")
	check(not scene.transfer.visible and scene.paused and S.decode(original).state == scene.state, "valid Import commits whole decoded progress then remains paused")
	await key(KEY_ESCAPE)
	check(not scene.paused and not scene.menu.visible, "desktop Back equivalent closes pause without exiting")
	await click("II")
	await click("SAVE / TRANSFER")
	await key(KEY_ESCAPE)
	check(not scene.transfer.visible and scene.paused and scene.menu.visible, "Back closes transfer first and retains paused menu")
	await key(KEY_ESCAPE)
	check(not scene.paused, "second Back resumes, explicit native quit disabled in project")

func whole_memory() -> Dictionary:
	return {"state": scene.state.duplicate(true), "profile": scene.profile.duplicate(true), "settings": scene.settings.duplicate(true), "paused": scene.paused}

func disk_bytes() -> Dictionary:
	var d := {}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(slot) + suffix
			if FileAccess.file_exists(path):
				d[path] = FileAccess.get_file_as_string(path)
	return d

func dwell(frames: int) -> void:
	for frame in frames:
		await physics_frame

func steer(direction: Vector2) -> void:
	if not touch_active:
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = root.get_final_transform() * dragging_origin
		press.pressed = true
		Input.parse_input_event(press)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "stick_press", "index": 0, "position": [press.position.x, press.position.y]})
		touch_active = true
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = root.get_final_transform() * (dragging_origin + direction * 65)
	drag.relative = direction * 65
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	events.append({"frame": Engine.get_physics_frames(), "time": scene.state.time, "kind": "stick_drag", "index": 0, "position": [drag.position.x, drag.position.y]})

func release() -> void:
	if touch_active:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = root.get_final_transform() * dragging_origin
		event.pressed = false
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "stick_release", "index": 0, "position": [event.position.x, event.position.y]})
		touch_active = false
	await process_frame

func click(text: String) -> void:
	await process_frame
	var found: Button
	for b in scene.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			found = b
	if found == null or found.disabled:
		check(false, "missing or disabled actual UI: " + text)
		return
	await tap(found.get_global_rect().get_center(), text)

func tap(point: Vector2, target: String = "TextEdit") -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * point
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "gui_press" if pressed else "gui_release", "index": 0, "target": target, "position": [e.position.x, e.position.y]})
		await process_frame

func key(code: int, ctrl: bool = false, unicode_value: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.unicode = unicode_value
		e.ctrl_pressed = ctrl
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "key", "key": code, "unicode": unicode_value, "ctrl": ctrl, "pressed": pressed})
		await process_frame

func snap(name: String) -> void:
	print("INPUT_SNAPSHOT ", name, " t=", scene.state.time, " scrap=", scene.state.wallet, " killed=", scene.state.killed.size(), " pads=", scene.state.pads)
	snapshots.append({"name": name, "frame": Engine.get_physics_frames(), "live": whole_memory(), "app_written": S.read()})
	if not folder.is_empty():
		var f := FileAccess.open(folder.path_join(name + "-saves.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(disk_bytes(), "  "))
		f.close()
	if DisplayServer.get_name() != "headless" and not folder.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))

func write_report() -> void:
	if folder.is_empty():
		return
	var f := FileAccess.open(folder.path_join("input-report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "snapshots": snapshots, "scope": "Engine ScreenTouch/drag/key input and normal processing at fixed60Hz. No injected earned economy or terminal redraw. In-memory storage-fault adapter is synthetic and separately labelled. Desktop window ratios only, not physical folding/FPS/fun."}, "  "))
	f.close()
	f = FileAccess.open(folder.path_join("raw-input-events.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(events))
	f.close()
