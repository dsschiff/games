extends SceneTree
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
var scene: Node
var checks := 0
var failures := 0
var report: Array = []
var events: Array = []
var snapshots: Array = []
var capture_dir := ""
var loss_done := false
var saw_chain := false
var saw_contact := false
var chain_frame := false
var hit_frame := false
var gate_frame := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1280)
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path: String = S.PATH + str(slot) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await snap("01-dock")
	await dwell(60)
	var start := R.position(scene.state)
	await steer(Vector2(0, -1))
	for frame in 45:
		await physics_frame
	check(R.position(scene.state).distance_to(start) > 2, "touch drag moves original diver")
	await release()
	var stop := R.position(scene.state)
	for frame in 5:
		await physics_frame
	check(R.position(scene.state).is_equal_approx(stop), "release stops movement")
	await click("PAUSE")
	var elapsed: float = scene.state.time
	for frame in 8:
		await physics_frame
	check(scene.state.time == elapsed and scene.paused, "pause freezes combat")
	await click("RESUME")
	# A bad approach takes real damage before a later visible full-heal purchase.
	for frame in 1500:
		if scene.state.hp < 100 or scene.state.phase != "playing":
			break
		var p := R.position(scene.state)
		await steer((Vector2(0, -2.0) - p).limit_length())
		await physics_frame
	check(scene.state.phase == "playing" and scene.state.hp < 100, "close approach takes real telegraphed damage")
	await snap("02-wounded-shoal")
	# A position policy drives only actual engine touch events, never state writes.
	for frame in 18000:
		if scene.state.phase != "playing":
			break
		var s: Dictionary = scene.state
		var direction := policy(s)
		await steer(direction)
		await physics_frame
		if s.strike > 0.15 and s.strike < 0.2:
			saw_chain = true
			if not chain_frame:
				chain_frame = true
				await snap("04-chain-extension")
		if not s.drops.is_empty() and not hit_frame:
			hit_frame = true
			await snap("05-salvage-drop")
		if int(s.tier) == 0 and int(s.wallet) >= R.COST and R.position(s).distance_to(R.PAD) <= 1.7:
			await release()
			await snap("06-before-purchase")
			await dwell(60)
			var hp_before: float = s.hp
			var wallet_before: int = s.wallet
			await click("FORGE TIDECUTTER • 36 • FULL HEAL")
			check(s.tier == 1 and s.wallet == wallet_before - 36 and s.hp == 100, "actual forge button buys power, debits and heals")
			check(scene.shown_tier == 1 and not scene.gate.visible, "weapon mesh and power gate change naturally")
			check(hp_before < 100 and s.hp == 100, "actual purchase restores damaged hull")
			await snap("07-upgrade-payoff")
			await dwell(90)
		if s.tier == 1 and not loss_done:
			await release()
			for bad_frame in 3000:
				if s.phase != "playing":
					break
				var goal := Vector2(0, -8.2)
				if s.z < -7.4:
					for e in s.enemies:
						if int(e.id) == 7:
							goal = Vector2(e.x, e.z)
				await steer((goal - R.position(s)).limit_length())
				await physics_frame
			check(s.phase == "defeat", "natural bad boss positioning loses")
			await snap("08-natural-defeat")
			await dwell(60)
			var dead: Array = s.dead.duplicate()
			var wallet: int = s.wallet
			await click("RETRY")
			check(s.phase == "playing" and s.hp == 100 and s.tier == 1, "visible Retry restores hull and purchased weapon")
			check(s.dead == dead and s.wallet == wallet, "Retry retains earned enemy and currency ledger")
			loss_done = true
			await snap("09-retry-upgraded")
			await dwell(30)
		if s.z < -8 and not gate_frame:
			gate_frame = true
			await snap("10-stronger-pen")
		if frame % 1800 == 0:
			print("INPUT_PROGRESS ", frame, " ", s.phase, " tier=", s.tier, " dead=", s.dead, " hp=", s.hp, " at=", R.position(s))
	await release()
	check(scene.state.phase == "victory", "positioning policy reaches natural boss victory")
	check(saw_chain and hit_frame and gate_frame, "actual input reaches chain, drop and upgraded pen")
	check(scene.terminal.visible and scene.terminal_title.text == "BEACON RESTORED", "natural terminal UI displays win without forced redraw")
	check(R.valid(scene.state), "terminal economy and active state remain valid")
	await snap("11-natural-victory")
	await dwell(90)
	await click("PAUSE")
	await click("EXPORT")
	var exported: String = scene.transfer.text
	check(S.decode(exported).ok and scene.save_error.is_empty(), "real export and durable save available")
	await click("IMPORT")
	check(scene.transfer_status.text.begins_with("Imported"), "export imports through real paused UI")
	var final_dead: Array = scene.state.dead.duplicate()
	scene.queue_free()
	await process_frame
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	check(scene.state.phase == "victory" and scene.state.dead == final_dead, "ordinary reload preserves earned victory")
	root.size = Vector2i(1000, 1110)
	await process_frame
	await snap("12-unfolded-victory")
	check(scene.buy_button.get_global_rect().end.x <= root.size.x and scene.menu_button.get_global_rect().end.x <= root.size.x, "unfolded resize retains buttons within viewport")
	if not capture_dir.is_empty():
		var f := FileAccess.open(capture_dir.path_join("input-report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"checks": checks, "failures": failures, "checks_detail": report, "state": scene.state, "snapshots": snapshots, "scope": "Godot fixed 60Hz actual Input.parse_input_event touch and GUI mouse; no phone timing claim"}, "  "))
		f.close()
		f = FileAccess.open(capture_dir.path_join("raw-input-events.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(events))
		f.close()
	print("HOOK_INPUT: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)

func dwell(frames: int) -> void:
	for frame in frames:
		await physics_frame

func policy(s: Dictionary) -> Vector2:
	var p := R.position(s)
	if s.tier == 0 and (s.dead.size() >= 5 or s.wallet >= R.COST):
		if not s.drops.is_empty():
			return (Vector2(s.drops[0].x, s.drops[0].z) - p).limit_length()
		return (R.PAD - p).limit_length()
	var enemy: Dictionary = {}
	var nearest := 10000.0
	for e in s.enemies:
		if int(R.ROSTER[int(e.id)].pen) != int(s.tier):
			continue
		var distance := p.distance_to(Vector2(e.x, e.z))
		if distance < nearest:
			enemy = e
			nearest = distance
	if enemy.is_empty():
		return Vector2.ZERO
	if s.tier == 1 and p.y > -7.4:
		return (Vector2(0, -8.2) - p).limit_length()
	var q := Vector2(enemy.x, enemy.z)
	var desired: float = float(R.weapon(s).reach) - 0.22
	var vector := Vector2.ZERO
	if nearest > desired:
		vector = (q - p).normalized()
	elif nearest < desired - 0.25:
		vector = (p - q).normalized()
	for e in s.enemies:
		if e.mode == "wind":
			var center := Vector2(e.ax, e.az)
			if p.distance_to(center) < float(R.ROSTER[int(e.id)].range) + 0.8:
				vector += (p - center).normalized() * 2.5
	for obstacle in R.OBSTACLES:
		var center := Vector2(obstacle.x, obstacle.y)
		if p.distance_to(center) < obstacle.z + 0.8 and vector.dot(center - p) > 0:
			vector += Vector2(-(center - p).y, (center - p).x).normalized() * 1.8
	return vector.limit_length()

func steer(direction: Vector2) -> void:
	if not scene.dragging:
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = Vector2(120, 900)
		press.pressed = true
		Input.parse_input_event(press)
		events.append({"time": scene.state.time, "kind": "touch_press", "position": [press.position.x, press.position.y]})
		await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(120, 900) + direction * 75
	drag.relative = direction * 75
	Input.parse_input_event(drag)
	events.append({"time": scene.state.time, "kind": "touch_drag", "position": [drag.position.x, drag.position.y]})

func release() -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = Vector2(120, 900)
	event.pressed = false
	Input.parse_input_event(event)
	events.append({"time": scene.state.time, "kind": "touch_release", "position": [event.position.x, event.position.y]})
	await process_frame

func click(text: String) -> void:
	var target: Button
	for b in scene.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			target = b
	if target == null:
		check(false, "visible button missing: " + text)
		return
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = target.get_global_rect().get_center()
		event.pressed = pressed
		Input.parse_input_event(event)
		events.append({"time": scene.state.time, "kind": "mouse_press" if pressed else "mouse_release", "button": text, "position": [event.position.x, event.position.y]})
		await process_frame

func snap(name: String) -> void:
	print("INPUT_SNAPSHOT ", name, " time=", scene.state.time, " dead=", scene.state.dead, " tier=", scene.state.tier)
	snapshots.append({"name": name, "state": scene.state.duplicate(true)})
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func check(okay: bool, message: String) -> void:
	checks += 1
	report.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)
