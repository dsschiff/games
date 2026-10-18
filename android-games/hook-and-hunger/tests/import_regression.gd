extends SceneTree
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
var scene: Node
var failures := 0
var checks := 0

func _initialize() -> void:
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
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(100, 600)
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(175, 600)
	Input.parse_input_event(drag)
	for frame in 30:
		await physics_frame
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame
	await click("PAUSE")
	var before := JSON.stringify(scene.state)
	check(scene.state.x > 1, "current progress created by real movement")
	var bad := R.fresh()
	bad.dead = [0, 1, 2, 3, 4]
	bad.collected = [0, 1, 2, 3]
	bad.wallet = 28
	bad.enemies = bad.enemies.filter(func(e: Dictionary) -> bool: return int(e.id) > 4)
	bad.drops = [{"id": 4, "x": 0.0, "z": -20.0}]
	check(not R.valid(bad), "tier0 required salvage behind power gate rejected")
	check(not S.decode(S.encode(bad, scene.settings, 0)).ok, "checked envelope cannot bypass per-pen drop validation")
	scene.transfer.text = S.encode(bad, scene.settings, 0)
	await click("IMPORT")
	check(scene.transfer_status.text.begins_with("Invalid save"), "actual Import UI rejects malformed reachable economy")
	check(JSON.stringify(scene.state) == before, "rejected import leaves entire current state unchanged")
	check(JSON.stringify(S.read().state) == before, "rejected import leaves persisted current progress unchanged")
	bad.drops[0].z = -3.8
	check(R.valid(bad), "same earned ledger accepts reachable drop in correct pen")
	var second_pen := bad.duplicate(true)
	second_pen.drops[0] = {"id": 4, "x": 0.0, "z": -10.0}
	check(not R.valid(second_pen), "tier0 drop in any second-pen location rejected")
	print("HOOK_IMPORT_REGRESSION: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func click(text: String) -> void:
	for b in scene.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			await reveal(b)
			for pressed in [true, false]:
				var e := InputEventMouseButton.new()
				e.position = b.get_global_rect().get_center()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = pressed
				Input.parse_input_event(e)
				await process_frame
			return
	check(false, "missing button " + text)

func check(okay: bool, text: String) -> void:
	checks += 1
	if not okay:
		failures += 1
		push_error(text)

func reveal(button: Button) -> void:
	if not scene.menu.is_ancestor_of(button):
		return
	var scroll = scene.menu.find_children("*", "ScrollContainer", true, false)[0]
	for attempt in 20:
		var point := button.get_global_rect().get_center()
		var area: Rect2 = scroll.get_global_rect()
		if area.has_point(point):
			return
		var wheel := InputEventMouseButton.new()
		wheel.position = area.get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if point.y > area.end.y else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		Input.parse_input_event(wheel)
		await process_frame
