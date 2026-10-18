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
var touch_active := false
var dragging_origin := Vector2(120, 970)
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
	await dwell(4)
	print("ISOLATED_USER_DATA ", OS.get_user_data_dir())
	check(scene.state.phase == "ready" and scene.profile.attempts == 0, "fresh isolated app, no injected progress")
	await snap("01-ready")
	await click("DEFEND THE PASS")
	check(scene.state.phase == "playing", "actual engine touch begins wave")
	if not movie_only:
		for frame in 3400:
			if scene.state.phase != "playing":
				break
			await physics_frame
		await dwell(3)
		check(scene.state.phase == "defeat" and scene.state.integrity == 0 and scene.state.leaked.size() == 4, "natural untouched leak-driven loss")
		check(scene.terminal.visible and scene.terminal_title.text == "REFUGE BREACHED", "loss appears under normal processing, no forced redraw")
		await snap("02-natural-defeat")
		await dwell(70)
		var earned: Dictionary = scene.profile.duplicate(true)
		await click("RETRY PASS")
		check(scene.state.phase == "playing" and scene.state.wallet == 0 and scene.state.spent == 0 and scene.state.pads == [0, 0] and scene.state.coins.size() == 5 and scene.state.enemies.is_empty(), "actual Retry restores complete finite battle budget")
		check(scene.profile == earned and scene.profile.attempts == 1, "Retry retains whole earned profile without farm currency")
		await snap("03-actual-retry")
	var first_pickup := false
	var first_build := false
	var fired := false
	var reward := false
	var second := false
	var valid_ticks := true
	var start := R.position(scene.state)
	for frame in 6000:
		if scene.state.phase != "playing":
			break
		var s: Dictionary = scene.state
		var goal := R.position(s)
		var pad := -1
		if s.pads[0] == 0 and s.wallet >= 5:
			goal = R.PADS[0]
			pad = 0
		elif s.pads[0] == 1 and s.pads[1] == 0 and s.wallet >= 15:
			goal = R.PADS[1]
			pad = 1
		elif not s.coins.is_empty():
			var nearest := INF
			for c in s.coins:
				var q := Vector2(c.x, c.z)
				var d := R.position(s).distance_to(q)
				if d < nearest:
					nearest = d
					goal = q
		if pad >= 0 and R.position(s).distance_to(goal) <= 1.42:
			await release()
			await snap("05-before-bolt" if pad == 0 else "09-before-heavy")
			await dwell(35)
			var old_wallet: int = scene.state.wallet
			await click(scene.build_button.text)
			check(scene.state.pads[pad] == 1 and scene.state.spent == (5 if pad == 0 else 20), "actual contextual touch constructs priced tower " + str(pad))
			check(scene.state.wallet <= old_wallet and scene.state.wallet >= old_wallet - R.COSTS[pad], "purchase visibly debits wallet " + str(pad))
			if pad == 0:
				first_build = true
				await snap("06-bolt-constructed")
				if not movie_only:
					await active_pause_and_reload()
			else:
				second = true
				await snap("10-heavy-investment")
			await dwell(55)
		else:
			await steer((goal - R.position(s)).limit_length())
			await physics_frame
		if not first_pickup and s.wallet > 0:
			first_pickup = true
			check(R.position(s).distance_to(start) > 0.05, "floating stick moves avatar into original loose gold")
			await snap("04-pickup-wallet")
		if not fired and s.shots > 0:
			fired = true
			await snap("07-visible-firing")
		if not reward and s.killed.size() > 0 and not s.coins.is_empty():
			reward = true
			await snap("08-earned-road-gold")
		valid_ticks = valid_ticks and R.valid(s)
		if movie_only and second:
			await release()
			await dwell(240)
			break
		if frame % 600 == 0:
			print("INPUT_PROGRESS ", frame, " t=", s.time, " gold=", s.wallet, " pads=", s.pads, " stopped=", s.killed.size(), " leaks=", s.leaked.size())
	await release()
	await dwell(3)
	check(first_pickup and first_build and fired and reward and second, "complete pickup-wallet-build-firing-reward-second-investment chain")
	check(valid_ticks, "every earned active state passed structural and economy checks")
	if not movie_only:
		check(scene.state.phase == "victory" and scene.state.integrity > 0, "actual-input defense reaches natural victory")
		check(scene.terminal.visible and scene.terminal_title.text == "THE HEARTH HOLDS", "untouched natural victory is rendered")
		check(scene.profile.attempts == 2 and scene.profile.wins == 1, "loss and victory earned ledger coherent")
		await snap("11-natural-victory")
		await transfer_and_layout()
	await snap("final")
	write_report()
	scene.queue_free()
	await process_frame
	await process_frame
	print("HEARTH_INPUT: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func transfer_and_layout() -> void:
	await click("PAUSE / LOG")
	check(scene.paused, "terminal pause/log receives touch")
	var before: Dictionary = scene.state.duplicate(true)
	await dwell(30)
	check(scene.state == before, "pause freezes whole battle")
	await click("SOUND  ON")
	await click("REDUCED EFFECTS  OFF")
	check(not scene.settings.sound and scene.settings.reduced_effects, "actual settings controls persist")
	await click("SAVE / TRANSFER")
	var original: String = scene.code_edit.text
	check(S.decode(original).ok, "export contains checked complete state and profile")
	await click("COPY")
	if DisplayServer.get_name() != "headless":
		check(DisplayServer.clipboard_get() == original, "real desktop clipboard receives exported code")
	await tap(scene.code_edit.get_global_rect().position + Vector2(80, 50))
	check(scene.code_edit.has_focus(), "real ScreenTouch gives TextEdit touch focus")
	await key(KEY_END, true)
	await key(KEY_X, false, 88)
	check(scene.code_edit.text != original and scene.code_edit.text.ends_with("X"), "actual key input edits touched code")
	var memory := whole_memory()
	var disk := disk_bytes()
	await click("IMPORT")
	check(whole_memory() == memory and disk_bytes() == disk, "invalid import preserves entire current memory and durable bytes")
	await snap("12-invalid-import-retention")
	# Restore text through real clipboard UI; headless platform has no clipboard.
	if DisplayServer.get_name() == "headless":
		await key(KEY_A, true)
		await key(KEY_BACKSPACE)
		await key(KEY_Z, true)
		await key(KEY_Z, true)
	else:
		await click("PASTE")
		check(scene.code_edit.text == original, "Paste restores exact exported code")
	if scene.code_edit.text != original:
		# Headless platform cannot prove clipboard; this fixture stages valid text only.
		scene.code_edit.text = original
	var faults := Faults.new()
	for path in [S.PATH + "0", S.PATH + "1"]:
		if FileAccess.file_exists(path):
			faults.files[path] = FileAccess.get_file_as_string(path)
	faults.fail_rename = true
	scene.save_io = faults
	memory = whole_memory()
	disk = disk_bytes()
	await click("IMPORT")
	check(scene.transfer.visible and scene.notice.text.begins_with("Storage failed"), "valid GUI import reports storage failure")
	check(whole_memory() == memory and disk_bytes() == disk, "failed save import preserves entire live memory and real durable bytes")
	scene.save_io = null
	await click("IMPORT")
	check(not scene.transfer.visible and scene.paused, "valid import commits then returns paused")
	check(S.read().state == S.decode(original).state and S.read().profile == S.decode(original).profile, "imported whole durable state matches export")
	await click("SAVE / TRANSFER")
	await key(KEY_ESCAPE)
	check(not scene.transfer.visible and scene.paused, "Back closes transfer first")
	await key(KEY_ESCAPE)
	check(not scene.paused, "next Back resumes underlying battle")
	await click("PAUSE / LOG")
	memory = whole_memory()
	root.size = Vector2i(1000, 1110)
	await dwell(4)
	check(whole_memory() == memory, "whole state survives inner-screen proportion resize while paused")
	await snap("13-inner-paused")
	await click("RESUME")
	check(not scene.paused, "inner proportion Resume receives actual touch")
	await snap("14-inner-victory")
	await click("PAUSE / LOG")
	root.size = Vector2i(720, 1680)
	await dwell(4)
	await snap("15-tall-cover-paused")
	await click("RESUME")
	check(not scene.paused, "tall cover proportion Resume receives touch")
	check(scene.pause_button.size.x >= 96 and scene.pause_button.size.y >= 96 and scene.build_button.size.y >= 96, "control dimensions reach 48dp on 360dp-wide cover")
	await snap("16-tall-cover-victory")
	var saved := S.read()
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(4)
	check(scene.state == saved.state and scene.profile == saved.profile and scene.settings == saved.settings, "ordinary reload preserves complete earned victory/profile/settings")
	check(S.decode(FileAccess.get_file_as_string(S.PATH + str(S.read().slot))).ok, "app-written cold load envelope checks")

func active_pause_and_reload() -> void:
	await click("II")
	check(scene.paused and scene.state.phase == "playing", "Pause receives touch during a genuinely active battle")
	var before := whole_memory()
	await dwell(90)
	check(whole_memory() == before, "active pause freezes movement, spawns, cooldowns, economy and profile")
	root.size = Vector2i(1000, 1110)
	await dwell(4)
	check(whole_memory() == before, "active whole memory survives inner-screen proportion resize")
	await snap("06a-active-inner-paused")
	await click("RESUME")
	check(not scene.paused and scene.state.phase == "playing", "inner-screen active Resume works")
	await snap("06b-active-inner")
	await click("II")
	before = whole_memory()
	root.size = Vector2i(720, 1680)
	await dwell(4)
	check(whole_memory() == before, "active whole memory survives tall-cover proportion resize")
	await click("RESUME")
	check(not scene.paused, "tall-cover active Resume works")
	await snap("06c-active-tall-cover")
	await click("II")
	root.size = Vector2i(720, 1280)
	await dwell(4)
	var saved := S.read()
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(4)
	check(scene.paused and scene.state == saved.state and scene.profile == saved.profile and scene.settings == saved.settings, "ordinary active reload preserves whole app-written run and starts paused")
	await dwell(90)
	check(scene.state == saved.state, "cold active run never advances before explicit Resume")
	await click("RESUME")
	check(not scene.paused, "cold active run resumes through actual touch")
	await snap("06d-active-reloaded")

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
	print("INPUT_SNAPSHOT ", name, " t=", scene.state.time, " gold=", scene.state.wallet, " killed=", scene.state.killed.size(), " pads=", scene.state.pads)
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
