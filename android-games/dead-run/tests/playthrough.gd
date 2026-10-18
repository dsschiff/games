extends SceneTree
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const F = preload("res://tests/fault_files.gd")
var scene: Node
var folder := ""
var checks := 0
var failures := 0
var details: Array = []
var events: Array = []
var snapshots: Array = []
var touching := false
var origin := Vector2.ZERO
var origin_x := 0.0
var movie := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
		if arg == "--movie-only":
			movie = true
	call_deferred("run")

func check(okay: bool, label: String) -> void:
	checks += 1
	details.append({"pass": okay, "label": label})
	if not okay:
		failures += 1
		print("FAIL ", label)

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	check(scene.state.phase == "ready" and S.read().ok, "fresh isolated app stores a checked ready state")
	await snap("01-ready")
	await click("START RESCUE")
	check(scene.state.phase == "playing", "touch Start launches automatic road simulation")
	var valid_ticks := true
	while scene.state.phase == "playing":
		await physics_frame
		valid_ticks = valid_ticks and R.valid(scene.state)
	check(valid_ticks, "untouched natural route always has valid state")
	check(scene.state.phase == "defeat" and scene.state.crew == 0 and scene.state.leaks > 0, "natural infected leaks deplete squad without injected progress")
	check(scene.overlay.visible and scene.overlay_title.text == "RESCUE LOST", "normal process renders actual defeat")
	await snap("02-natural-loss")
	await dwell(70)
	await click("RETRY BRIDGE")
	check(scene.state.phase == "playing" and scene.state.tick < 10 and scene.state.crew == 3 and scene.state.side_hp == 120 and scene.state.shots == 0, "actual immediate Retry resets full encounter")
	await snap("03-retry")
	var gained := false
	var side_work := false
	var harmed := false
	var crane_done := false
	var field_saved := false
	var last_target := 999.0
	var min_hp := 120
	var side_pause_hp := -1
	var side_paused := false
	var forward_window_hp := -1
	var forward_window_kills := -1
	valid_ticks = true
	for frame in 3400:
		if scene.state.phase != "playing":
			break
		var s: Dictionary = scene.state
		var target := 0.0
		if s.tick < 535:
			target = 0.0
		elif s.tick < 750:
			target = -2.65
		elif s.tick < 830:
			target = 0.0
		elif s.tick < 964:
			target = -2.65
		elif s.tick < 1024:
			target = 2.1
		elif s.tick < 1065:
			target = 1.0
		else:
			var closest := 35.0
			for e in s.enemies:
				if s.tick >= e.born and not e.resolved and e.z < closest:
					closest = e.z
					target = e.x
			if s.tick >= 2160 and s.final_hp > 0 and closest > 6:
				target = 0.0
			elif s.side_hp > 0 and closest > 8:
				target = -2.65
		if absf(target - last_target) > 0.01:
			await steer(target)
			last_target = target
		await physics_frame
		valid_ticks = valid_ticks and R.valid(scene.state)
		if not gained and s.gates[0].crossed:
			gained = true
			check(s.gates[0].applied == 6 and s.crew == 9, "shot-altered first gate crosses once and grows formation 3 to 9")
			await snap("04-recruits-join")
		if not side_work and s.side_hits >= 35:
			side_work = true
			check(s.tick > 600 and s.enemies.any(func(e): return s.tick >= e.born and not e.resolved), "sustained large-side-target fire during approaching ordinary infected")
			await snap("05-side-target-under-fire")
		if s.side_hp < min_hp:
			min_hp = s.side_hp
		if not crane_done and s.side_claimed:
			crane_done = true
			await snap("06-crane-riggers-join")
		if s.tick == 1000:
			side_pause_hp = s.side_hp
		if forward_window_hp == -1 and s.tick >= 795:
			forward_window_hp = s.side_hp
			forward_window_kills = s.kills
		if not side_paused and s.tick >= 825:
			side_paused = true
			check(s.side_hp == forward_window_hp and s.side_hp > 0 and s.kills > forward_window_kills, "switching forward stops unfinished crane damage while suppressing infected")
			await snap("05b-forward-fire-tradeoff")
		if not harmed and s.gates[1].crossed:
			harmed = true
			check(s.gates[1].applied < 0 and s.crew > 0, "harmful signed crossing visibly removes crew while remaining survivable")
			await snap("07-harmful-crossing")
		if not movie and not field_saved and s.tick >= 1150:
			field_saved = true
			await release()
			await platform_checks()
			last_target = 999
		if s.tick == 2165:
			await snap("08-final-pressure")
		if frame % 600 == 0:
			print("ROUTE ", s.tick, " crew=", s.crew, " crane=", s.side_hp, " gate2=", s.gates[1].value, " killed=", s.kills, " leaks=", s.leaks)
	await release()
	check(valid_ticks, "every touch-driven winning-route tick validates")
	check(gained and side_work and harmed and crane_done, "formation growth / sustained side fire / riggers / harmful crossing chain")
	check(side_paused and side_pause_hp >= 0 and scene.state.gate_hits > 0, "side-target work competes with forward gate fire")
	check(scene.state.phase == "victory" and scene.state.crew > 0 and scene.state.final_hp == 0, "actual engine touch reaches natural objective victory")
	check(scene.overlay.visible and scene.overlay_title.text == "CONVOY EVACUATED", "normal process renders untouched victory")
	await snap("09-objective-victory")
	await dwell(80)
	if not movie:
		await terminal_restore()
	await snap("final")
	var report := {"checks": checks, "failures": failures, "details": details, "snapshots": snapshots,
		"scope": "Actual engine ScreenTouch/ScreenDrag/keyboard through normal 60Hz processing. Policies read state only; no gameplay handler calls, injected progress or forced terminal redraws. Storage fault adapter is a labelled synthetic fixture. Desktop ratios are not phone folding, IME, sound audibility or measured FPS/fun."}
	write("input-report.json", report)
	write("raw-input-events.json", events)
	scene.queue_free()
	await process_frame
	print("INPUT: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func platform_checks() -> void:
	await click("II")
	check(scene.paused, "actual active Pause")
	var before: Dictionary = scene.state.duplicate(true)
	await dwell(80)
	check(scene.state == before, "pause freezes entire active model")
	await click("SOUND: ON")
	await click("REDUCED EFFECTS: OFF")
	check(not scene.settings.sound and scene.settings.reduced_effects, "actual settings touch persists both values")
	var write_fault := F.new()
	write_fault.fail_write = true
	scene.files = write_fault
	await click("SOUND: OFF")
	check(scene.save_message.begins_with("SAVE FAILED") and scene.notice.text.begins_with("SAVE FAILED"), "synthetic ordinary storage failure is visible and never claims saved")
	scene.files = null
	await click("SOUND: ON")
	check(scene.save_message.is_empty() and not S.read().settings.sound, "next real settings save clears failure only after checked storage")
	await click("SAVE / TRANSFER")
	await click("EXPORT / COPY")
	var code: String = scene.code_box.text
	check(S.decode(code).ok, "Export produces checked portable code")
	check(scene.transfer_status.text in ["Copied checked rescue save.", "Clipboard unavailable. Select and copy the code manually."], "Export gives verified clipboard success or honest unavailable feedback")
	var clip_equal := DisplayServer.get_name() != "headless" and DisplayServer.clipboard_get() == code
	write("clipboard-result.json", {"display_server": DisplayServer.get_name(), "feedback": scene.transfer_status.text, "equal": clip_equal})
	if clip_equal:
		await click("PASTE")
		check(scene.code_box.text == code, "actual Paste reads same clipboard bytes")
	print("TEXT_RECT ", scene.code_box.get_global_rect(), " transfer=", scene.transfer.get_global_rect())
	await snap("platform-transfer")
	await tap(scene.code_box.get_global_rect().position + Vector2(30, 30))
	check(scene.code_box.has_focus(), "engine emulated touch mouse focuses TextEdit")
	await key(KEY_A, true)
	await key(KEY_X, false, 120)
	check(scene.code_box.text == "x", "real key input replaces transfer text")
	var disk_before := S.read()
	await click("IMPORT")
	check(scene.state == before and S.read().revision == disk_before.revision, "invalid UI import preserves active memory and durable slot")
	# Code entry is a labelled transfer fixture, not earned gameplay injection.
	scene.code_box.text = code
	var io := F.new()
	scene.files = io
	io.fail_rename = true
	await click("IMPORT")
	check(scene.state == before and scene.transfer_status.text.begins_with("Import could not"), "synthetic failed durable promotion leaves memory unchanged")
	scene.files = null
	await click("IMPORT")
	check(S.read().ok and scene.paused and scene.transfer_status.text.begins_with("Imported"), "actual Import durably promotes before resume")
	await key(KEY_ESCAPE)
	check(not scene.transfer.visible and scene.paused, "Back closes transfer before pause")
	await key(KEY_ESCAPE)
	check(not scene.paused, "second Back resumes")
	await click("II")
	before = scene.state.duplicate(true)
	root.size = Vector2i(1000, 1110)
	await dwell(5)
	check(scene.state == before, "unfolded-like ratio preserves entire paused model")
	await snap("platform-inner")
	await click("RESUME")
	await click("II")
	root.size = Vector2i(720, 1680)
	await dwell(5)
	await snap("platform-tall-cover")
	await click("RESUME")
	await click("II")
	root.size = Vector2i(720, 1280)
	await dwell(4)
	var saved := S.read()
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	check(scene.paused and same(scene.state, saved.state) and scene.settings == saved.settings, "cold active scene restore retains whole checked model and settings, starts paused")
	var restored: Dictionary = scene.state.duplicate(true)
	await dwell(60)
	check(scene.state == restored, "restored active run waits for explicit Resume")
	await click("RESUME")
	await snap("platform-active-restored")

func terminal_restore() -> void:
	var saved := S.read()
	check(saved.ok and saved.state.phase == "victory", "app wrote checked objective terminal save")
	scene.queue_free()
	await process_frame
	await process_frame
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await dwell(5)
	check(same(scene.state, saved.state) and scene.settings == saved.settings, "terminal cold scene restore retains full model/settings")

func same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for k in a:
			if not b.has(k) or not same(a[k], b[k]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same(a[i], b[i]): return false
		return true
	if a is float and b is float: return absf(a - b) < 0.000000001
	return a == b

func dwell(frames: int) -> void:
	for i in frames:
		await physics_frame

func steer(x: float) -> void:
	await release()
	origin = Vector2(root.get_visible_rect().size.x * 0.5, root.get_visible_rect().size.y * 0.76)
	origin_x = scene.state.x
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = root.get_final_transform() * origin
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	events.append({"frame": Engine.get_physics_frames(), "kind": "world_press", "position": [press.position.x, press.position.y], "index": 0})
	touching = true
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = root.get_final_transform() * (origin + Vector2((x - origin_x) / 9.0 * root.get_visible_rect().size.x, 0))
	drag.relative = Vector2((x - origin_x) / 9.0 * root.get_visible_rect().size.x, 0)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	events.append({"frame": Engine.get_physics_frames(), "tick": scene.state.tick, "kind": "world_drag", "index": 0, "position": [drag.position.x, drag.position.y], "desired_x": x})

func release() -> void:
	if touching:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * origin
		e.pressed = false
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "world_release", "position": [e.position.x, e.position.y], "index": 0})
		touching = false
	await process_frame

func click(value: String) -> void:
	await process_frame
	var found: Button
	for b in scene.find_children("*", "Button", true, false):
		if b.text == value and b.is_visible_in_tree():
			found = b
	if found == null:
		check(false, "missing actual UI " + value)
		return
	await tap(found.get_global_rect().get_center(), value)

func tap(p: Vector2, target: String = "TextEdit") -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * p
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "gui_touch", "index": 0, "position": [e.position.x, e.position.y], "pressed": pressed, "target": target})
		await process_frame

func key(code: int, ctrl: bool = false, unicode_value: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.ctrl_pressed = ctrl
		e.unicode = unicode_value
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		events.append({"frame": Engine.get_physics_frames(), "kind": "key", "key": code, "unicode": unicode_value, "ctrl": ctrl, "pressed": pressed})
		await process_frame

func snap(name: String) -> void:
	print("SNAPSHOT ", name, " tick=", scene.state.tick, " crew=", scene.state.crew, " side=", scene.state.side_hp, " phase=", scene.state.phase)
	snapshots.append({"name": name, "frame": Engine.get_physics_frames(), "state": scene.state.duplicate(true), "settings": scene.settings.duplicate(true), "app_written": S.read()})
	var raw := {}
	for i in 2:
		for suffix in ["", ".tmp"]:
			var p: String = S.PATH + str(i) + suffix
			if FileAccess.file_exists(p): raw[p] = FileAccess.get_file_as_string(p)
	write(name + "-slots.json", raw)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(name + ".png"))

func write(name: String, data: Variant) -> void:
	var file := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ", true, true))
	file.close()
