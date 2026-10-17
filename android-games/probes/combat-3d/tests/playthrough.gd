extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(720, 1280)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await _click(scene, "RESTART")
	var start: float = scene.state["x"]
	var press := InputEventScreenTouch.new()
	press.position = Vector2(360, 700)
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(460, 700)
	drag.relative = Vector2(100, 0)
	Input.parse_input_event(drag)
	for frame in range(30):
		await physics_frame
	_check(scene.state["x"] > start + 0.5, "screen drag moves 3D character")
	var release := InputEventScreenTouch.new()
	release.position = Vector2(460, 700)
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frame
	var stopped: float = scene.state["x"]
	for frame in range(10):
		await physics_frame
	_check(is_equal_approx(scene.state["x"], stopped), "touch release stops movement")
	await _click(scene, "PAUSE")
	var elapsed: float = scene.state["elapsed"]
	for frame in range(10):
		await physics_frame
	_check(is_equal_approx(scene.state["elapsed"], elapsed), "pause freezes elapsed simulation")
	await _click(scene, "PAUSE")
	for frame in range(9000):
		if scene.state["result"] != "playing":
			break
		await physics_frame
	_check(scene.state["result"] == "victory", "complete automatic-fire encounter reaches victory")
	await _capture()
	await _click(scene, "PAUSE")
	var kills: int = int(scene.state["kills"])
	scene.queue_free()
	await process_frame
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.state["kills"] == kills and scene.state["result"] == "victory", "victory and encounter restore from disk")
	await _click(scene, "RESTART")
	_check(scene.state["kills"] == 0 and scene.state["health"] == 100, "restart creates a playable encounter")
	print("PROBE_3D_INPUT_PLAYTHROUGH: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)

func _click(scene: Node, text: String) -> void:
	var target: Button
	for button in scene.find_children("*", "Button", true, false):
		if button.text == text:
			target = button
	if target == null:
		_check(false, "missing button " + text)
		return
	var at := target.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.position = at
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.position = at
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
