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
	var buttons: Array[Node] = scene.find_children("*", "Button", true, false)
	var restart := _button(buttons, "RESTART")
	await _click(restart)
	for cell in range(5):
		await _click(scene.board.get_child(cell))
	_check(scene.state["pads"].size() == 5, "five pointer placements reached game rules")
	var run := _button(buttons, "RUN WAVE")
	for wave in range(8):
		await _click(run)
	_check(scene.state["result"] == "victory", "pointer-controlled playthrough wins")
	await _capture()
	_check(scene.save_error.is_empty(), "ordinary gameplay reported successful save")
	scene = await _reload(scene)
	_check(scene.state["result"] == "victory" and scene.state["pads"].size() == 5, "ordinary gameplay save restores without test fixture writes")
	_write("user://probe-save.json.tmp", JSON.stringify(scene.state))
	_write("user://probe-save.json", JSON.stringify(load("res://rules.gd").initial_state()))
	scene = await _reload(scene)
	_check(scene.state["result"] == "victory" and scene.state["pads"].size() == 5, "new temporary progress takes precedence over older valid primary")
	_write("user://probe-save.json.tmp", JSON.stringify(scene.state))
	_write("user://probe-save.json", "corrupt interrupted primary")
	scene = await _reload(scene)
	_check(scene.state["result"] == "victory" and scene.state["pads"].size() == 5, "valid temporary save recovers corrupt primary after interruption")
	buttons = scene.find_children("*", "Button", true, false)
	await _click(_button(buttons, "RESTART"))
	await _click(_button(buttons, "PAUSE / RESUME"))
	await _click(_button(buttons, "RUN WAVE"))
	_check(scene.state["wave"] == 0, "paused wave button cannot advance simulation")
	await _click(_button(buttons, "PAUSE / RESUME"))
	for wave in range(8):
		await _click(_button(buttons, "RUN WAVE"))
	_check(scene.state["result"] == "defeat", "pointer-controlled undefended playthrough loses")
	await _click(_button(buttons, "RESTART"))
	_check(scene.state["wave"] == 0 and scene.state["health"] == 100, "restart restores playable state")
	print("PROBE_2D_INPUT_PLAYTHROUGH: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _reload(scene: Node) -> Node:
	scene.queue_free()
	await process_frame
	var replacement = load("res://main.tscn").instantiate()
	root.add_child(replacement)
	await process_frame
	return replacement

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "fixture storage available")
	if file != null:
		file.store_string(text)
		file.close()

func _button(buttons: Array[Node], text: String) -> Button:
	for node in buttons:
		if node.text == text:
			return node as Button
	return null

func _click(button: Button) -> void:
	if button == null:
		_check(false, "missing test button")
		return
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	Input.parse_input_event(motion)
	await process_frame
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
