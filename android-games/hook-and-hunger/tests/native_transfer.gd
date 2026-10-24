extends "res://tests/playthrough.gd"
var presses := {}
var watched := {}
var fallback_count := 0
var clipboard_covered := false
var transfer_result := {}

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
	await movement_check()
	await tap_button("PAUSE")
	check(scene.paused and scene.menu.visible, "native Pause touch opens menu once")
	if not scene.paused:
		fallback_count += 1
		await click("PAUSE")
	clipboard_covered = DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	if clipboard_covered:
		# Replace unrelated clipboard data before testing this app's export.
		DisplayServer.clipboard_set("HOOK_NATIVE_TRANSFER_SENTINEL")
	await tap_button("EXPORT")
	if scene.transfer.text.is_empty():
		fallback_count += 1
		await click("EXPORT")
	var exported: String = scene.transfer.text
	var decoded := S.decode(exported)
	check(decoded.ok, "Export populates a valid checked save code")
	check(scene.transfer.has_selection() and scene.transfer.get_selected_text() == exported, "Export selects the whole valid code")
	if clipboard_covered:
		check(DisplayServer.clipboard_get() == exported, "Export directly copies the exact valid code to native clipboard")
		check(scene.transfer_status.text.begins_with("Copied"), "Export visibly acknowledges copied code")
	await reveal_control(scene.transfer)
	await touch_at(scene.transfer.get_global_rect().get_center())
	check(scene.transfer.has_focus() and root.gui_get_focus_owner() == scene.transfer, "real ScreenTouch focuses TextEdit without programmatic focus")
	await select_all()
	var invalid := "INVALID Ω漢🙂"
	await type_unicode(invalid)
	check(scene.transfer.text == invalid, "focused TextEdit receives typed Unicode replacement")
	check(not S.decode(scene.transfer.text).ok, "typed field contents are invalid before Import")
	await snap("typed-unicode-invalid")
	var before_state := JSON.stringify(scene.state)
	var before_profile := JSON.stringify(scene.profile)
	var before_settings := JSON.stringify(scene.settings)
	var before_disk := S.read()
	await tap_button("IMPORT")
	check(scene.transfer_status.text.begins_with("Invalid save"), "native Import rejects the actual typed field contents")
	check(JSON.stringify(scene.state) == before_state, "invalid native import retains whole in-memory state")
	check(JSON.stringify(scene.profile) == before_profile, "invalid native import retains whole in-memory profile")
	check(JSON.stringify(scene.settings) == before_settings, "invalid native import retains in-memory settings")
	var rejected_disk := S.read()
	check(rejected_disk.ok and rejected_disk.state == before_disk.state and rejected_disk.profile == before_disk.profile and rejected_disk.settings == before_disk.settings, "invalid native import retains whole on-disk gameplay/profile/settings")
	check(rejected_disk.revision == before_disk.revision, "invalid native import does not silently reimport the old valid code")
	await reveal_control(scene.transfer_status)
	await snap("native-invalid-rejected")
	if clipboard_covered:
		check(DisplayServer.clipboard_get() == exported, "typing invalid text leaves the exported clipboard backup intact")
		await tap_button("PASTE")
		check(scene.transfer.text == exported and S.decode(scene.transfer.text).ok, "native Paste restores the exact exported valid code")
	else:
		# Headless DisplayServer has no clipboard. Retype via the same native
		# editing path; only the rendered suite claims Export/Paste coverage.
		await reveal_control(scene.transfer)
		await touch_at(scene.transfer.get_global_rect().get_center())
		await select_all()
		await type_unicode(exported)
		check(scene.transfer.text == exported, "headless native typing restores valid code without pretending clipboard coverage")
	var revision_before: int = S.read().revision
	await tap_button("IMPORT")
	var imported := S.read()
	check(scene.transfer_status.text.begins_with("Imported"), "native Import accepts restored valid code")
	check(imported.ok and imported.revision > revision_before, "valid native import commits a fresh durable write")
	check(scene.state == decoded.state and scene.profile == decoded.profile and scene.settings == decoded.settings, "valid native import preserves the whole exported gameplay/profile/settings")
	check(imported.state == decoded.state and imported.profile == decoded.profile and imported.settings == decoded.settings, "valid native import readback preserves the whole exported data")
	await reveal_control(scene.transfer_status)
	await snap("native-valid-imported")
	await tap_button("RESUME")
	check(not scene.paused and not scene.menu.visible, "native Resume touch closes menu once")
	await movement_check()
	check(fallback_count == 0, "native flow needed no mouse-click recovery")
	transfer_result = {"clipboard_covered": clipboard_covered, "export_sha256": exported.sha256_text(), "invalid_typed_unicode": invalid, "rejected_revision": rejected_disk.revision, "imported_revision": imported.revision, "fallback_count": fallback_count, "scope": "Real ScreenTouch focus and native key Unicode events, no TextEdit assignment/grab_focus. Rendered display covers real clipboard; headless explicitly substitutes typing for unsupported clipboard."}
	if not capture_dir.is_empty():
		var f := FileAccess.open(capture_dir.path_join("native-transfer.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"checks": checks, "failures": failures, "checks_detail": report, "result": transfer_result, "events": events, "snapshots": snapshots}, "  "))
		f.close()
	print("NATIVE_TRANSFER: ", checks, " checks; failures=", failures, " clipboard=", clipboard_covered)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func movement_check() -> void:
	var start: float = scene.state.x
	await finger_event(Vector2(140, 900), true, 7)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = root.get_final_transform() * Vector2(215, 900)
	drag.relative = Vector2(75, 0)
	Input.parse_input_event(drag)
	await process_frame
	for frame in 12:
		await physics_frame
	check(scene.state.x > start + 0.3 and scene.finger == 7, "real touch drag moves the diver with its owning finger")
	var original_start: Vector2 = scene.drag_start
	var original_movement: Vector2 = scene.movement
	var emulated := InputEventMouseMotion.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.position = root.get_final_transform() * Vector2(300, 700)
	emulated.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(emulated)
	await process_frame
	check(scene.drag_start == original_start and scene.movement == original_movement, "duplicate emulated mouse motion cannot redirect world touch movement")
	var release_mouse := InputEventMouseButton.new()
	release_mouse.device = InputEvent.DEVICE_ID_EMULATION
	release_mouse.button_index = MOUSE_BUTTON_LEFT
	release_mouse.position = emulated.position
	release_mouse.pressed = false
	Input.parse_input_event(release_mouse)
	await process_frame
	check(scene.dragging and scene.finger == 7, "duplicate emulated mouse release cannot stop the real finger")
	await finger_event(Vector2(215, 900), false, 7)
	var stopped: float = scene.state.x
	for frame in 5:
		await physics_frame
	check(not scene.dragging and scene.movement == Vector2.ZERO and is_equal_approx(scene.state.x, stopped), "real finger release stops movement")

func tap_button(text: String) -> void:
	if not is_instance_valid(current_scene): current_scene = scene
	if text == "IMPORT": current_scene = scene
	await process_frame
	await process_frame
	var button: Button
	for b in scene.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			button = b
	if button == null:
		check(false, "missing native button " + text)
		return
	var id := button.get_instance_id()
	if not watched.has(id):
		watched[id] = true
		presses[id] = 0
		button.pressed.connect(func() -> void: presses[id] += 1)
	await reveal_control(button)
	var before: int = presses[id]
	await touch_at(button.get_global_rect().get_center())
	check(int(presses[id]) == before + 1, "native " + text + " tap invokes exactly one GUI action")

	if current_scene == null: await scene_changed
	if is_instance_valid(current_scene) and current_scene != scene: scene = current_scene

func reveal_control(control: Control) -> void:
	var scroll: ScrollContainer = scene.menu.find_children("*", "ScrollContainer", true, false)[0]
	for attempt in 30:
		var area := scroll.get_global_rect()
		if area.encloses(control.get_global_rect()):
			await process_frame
			return
		var wheel := InputEventMouseButton.new()
		wheel.position = root.get_final_transform() * area.get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if control.get_global_rect().get_center().y > area.end.y else MOUSE_BUTTON_WHEEL_UP
		for pressed in [true, false]:
			wheel.pressed = pressed
			Input.parse_input_event(wheel)
			await process_frame

func touch_at(point: Vector2) -> void:
	await finger_event(point, true, 0)
	await finger_event(point, false, 0)
	await process_frame

func finger_event(point: Vector2, pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	events.append({"kind": "native_touch", "index": index, "pressed": pressed, "position": [event.position.x, event.position.y]})
	await process_frame

func select_all() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_A
		event.ctrl_pressed = true
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func type_unicode(text: String) -> void:
	for i in text.length():
		for pressed in [true, false]:
			var event := InputEventKey.new()
			event.unicode = text.unicode_at(i)
			event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame
	events.append({"kind": "typed_unicode", "length": text.length(), "sha256": text.sha256_text()})
