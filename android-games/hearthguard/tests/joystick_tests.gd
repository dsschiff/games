extends "res://tests/presentation_tests.gd"
## Real floating input origins, actual label meshes, no rendered acceptance claim.
const Clearance = preload("res://scripts/presentation/label_clearance.gd")
var scene: Node

func run() -> void:
	for name in ["rules.gd", "campaign_rules.gd", "campaign_catalog.gd", "save_store.gd", "save_files.gd"]:
		check(FileAccess.get_file_as_string("res://scripts/" + name).replace("\r\n", "\n") == FileAccess.get_file_as_string(baseline + name).replace("\r\n", "\n"), "joystick polish preserves rule/save source: " + name)
	var original := FileAccess.get_file_as_string(baseline + "controls-main.gd")
	var current := FileAccess.get_file_as_string("res://scripts/main.gd")
	for method in ["_input", "stop_move", "_physics_process", "save_now"]:
		check(method_source(original, method) == method_source(current, method), "hit regions/origin/delta/timing/save handler byte-equivalent to accepted candidate: " + method)
	root.size = Vector2i(720, 1280)
	var app: Node = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	scene = app.get_node("Battle")
	scene.set_physics_process(false)
	await tap(scene.start_button.get_global_rect().get_center())
	check(scene.state.phase == "playing" and not scene.paused, "real Start input opens joystick test encounter")
	var ring: StyleBoxFlat = scene.stick_ring.get_theme_stylebox("panel")
	var knob: StyleBoxFlat = scene.stick_knob.get_theme_stylebox("panel")
	var circles := true
	for corner in 4:
		circles = circles and ring.get_corner_radius(corner) == 80 and knob.get_corner_radius(corner) == 32
	check(circles and scene.stick_ring.size == Vector2(160, 160) and scene.stick_knob.size == Vector2(64, 64) and ring.corner_detail >= 16 and knob.corner_detail >= 16 and ring.anti_aliasing and knob.anti_aliasing, "actual160/64 control paint has circular half-diameter corner radii and antialiasing")
	check(ring.bg_color.a <= .06 and ring.border_color.a <= .2 and ring.shadow_color.a <= .05 and ring.shadow_size <= 3 and knob.shadow_color.a <= .1, "base has restrained alpha/border/shadow instead of heavy rounded-square styling")
	check(scene.stick.mouse_filter == Control.MOUSE_FILTER_IGNORE and scene.stick_ring.mouse_filter == Control.MOUSE_FILTER_IGNORE and scene.stick_knob.mouse_filter == Control.MOUSE_FILTER_IGNORE, "circular paint does not introduce Control hit regions")
	var profiles := [Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1100, 1400), Vector2i(1600, 1000), Vector2i(2560, 1440)]
	for profile in profiles:
		root.size = profile
		await process_frame
		scene.layout()
		await process_frame
		var price: Label3D = scene.presenter.pad_labels[4]
		var forced: Vector2 = scene.camera.unproject_position(price.global_position)
		forced.x = minf(forced.x, root.get_visible_rect().size.x * .48 - 2)
		forced.y = clampf(forced.y, scene.safe_rect.position.y + 235, scene.safe_rect.end.y - 175)
		for index in 2:
			var origin: Vector2 = Vector2(110, 850) if index == 0 else forced
			var direction := Vector2(.6, -.8) if index == 0 else Vector2(-.6, .8)
			await exercise_origin(origin, direction, profile, index == 0 and profile == Vector2i(720, 1280))
		await tap(scene.pause_button.get_global_rect().get_center())
		check(scene.paused and scene.world_label_clearance.placements.is_empty(), "actual Pause restores authored text anchors at " + str(profile))
		await tap(find_button("RESUME").get_global_rect().get_center())
	var retained_profile: Dictionary = scene.campaign_profile.duplicate(true)
	check(retained_profile.clears.is_empty() and retained_profile.attempts == 0 and scene.profile.attempts == 0, "focused gestures invent no clears/results in either profile")
	app.queue_free()
	await process_frame
	# Eight-pad later layout is a synthetic presentation fixture, never saved or
	# used as earned progression. Test dense label placement at the same origins.
	var view := V.new()
	root.add_child(view)
	view.set_process(false)
	view.build(C.fresh(Cat.definition(9)))
	var clearance := Clearance.new()
	for profile in profiles:
		root.size = profile
		await process_frame
		var logical := root.get_visible_rect().size
		var field := Rect2(28, 228, logical.x - 56, logical.y - 516)
		view.fit(field)
		var labels: Array[Label3D] = view.essential_labels()
		var centers: Array[Vector2] = [Vector2(110, 850), view.camera.unproject_position(labels[4].global_position)]
		for center in centers:
			var control := Rect2(center - Vector2(80, 80), Vector2(160, 160))
			clearance.update(labels, view.camera, control, field)
			var clean := clearance.unresolved.is_empty()
			for label in labels:
				clean = clean and not glyph_rect(label, view.camera).intersects(control.grow(10))
			check(clean, "eight-pad label glyphs clear actual floating control at %s/%s" % [profile, center])
			clearance.update(labels, view.camera, Rect2(), field)
	clearance.reset()
	check(clearance.records.is_empty(), "scene teardown/reset releases label cache references")
	view.queue_free()
	await process_frame
	var file := FileAccess.open(folder.path_join("joystick-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "scope": "CPU style geometry and actual ScreenTouch floating-origin/label geometry/whole-state equivalence across7profiles, plus unsaved8-pad presentation fixture. Visual appearance/readability awaits short original-image rendered review; no broad campaign."}, "\t"))
	file.close()
	print("JOYSTICK_CHECKS ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func exercise_origin(origin: Vector2, direction: Vector2, profile: Vector2i, original_failure: bool) -> void:
	var labels: Array[Label3D] = scene.presenter.essential_labels()
	var anchors := {}
	for label in labels:
		anchors[label.get_instance_id()] = label.global_position
	var before := S.encode(scene.state, scene.profile, scene.settings, 0, true, scene.campaign_profile)
	var control := Rect2(origin - Vector2(80, 80), Vector2(160, 160))
	if original_failure:
		check(glyph_rect(scene.presenter.pad_labels[4], scene.camera).intersects(control), "native720 actual110,850 origin reproduces original Pad5 overlap before correction")
	await touch(origin, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = root.get_final_transform() * (origin + direction * 65)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await process_frame
	scene.update_control_clearance()
	check(scene.stick_origin.distance_to(origin) < .001 and scene.stick_ring.get_global_rect().position.distance_to(control.position) < .001 and scene.input_vector.distance_to(direction) < .001, "real floating origin and unchanged65px delta mapping at %s/%s" % [profile, origin])
	var clear: bool = scene.world_label_clearance.unresolved.is_empty()
	for label in labels:
		var rect := glyph_rect(label, scene.camera)
		clear = clear and not rect.intersects(control.grow(10)) and scene.presenter.field_rect.grow(.2).encloses(rect)
	check(clear, "actual label meshes clear floating base/knob/shadow inside field at %s/%s" % [profile, origin])
	if original_failure:
		check(not scene.world_label_clearance.placements.is_empty(), "Pad5 clearance is geometric relocation, not translucency-only assurance")
	check(before == S.encode(scene.state, scene.profile, scene.settings, 0, true, scene.campaign_profile), "UI/style/label adjustment cannot mutate complete save at %s/%s" % [profile, origin])
	var expected: Dictionary = scene.state.duplicate(true)
	# Native-to-logical event transforms can round Vector2 components. Mapping
	# is asserted above; compare the full rules tick with that actual input.
	C.tick(expected, scene.input_vector, .05)
	scene._physics_process(.05)
	check(C.equivalent(expected, scene.state), "entire actual gameplay tick equals unchanged rules at %s/%s" % [profile, origin])
	await touch(origin, false)
	scene.update_control_clearance()
	var restored: bool = scene.input_vector == Vector2.ZERO and scene.stick_id == -1
	for label in labels:
		restored = restored and label.global_position.is_equal_approx(anchors[label.get_instance_id()])
	check(restored and scene.world_label_clearance.placements.is_empty(), "actual release stops movement and restores every authored label anchor at %s/%s" % [profile, origin])

func glyph_rect(label: Label3D, camera: Camera3D) -> Rect2:
	var transform := Transform3D(camera.global_basis, label.global_position)
	var faces: PackedVector3Array = label.generate_triangle_mesh().get_faces()
	var rect := Rect2(camera.unproject_position(transform * faces[0]), Vector2.ZERO)
	for point in faces:
		rect = rect.expand(camera.unproject_position(transform * point))
	return rect

func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = root.get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = root.get_final_transform() * point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func find_button(caption: String) -> Button:
	for button in scene.find_children("*", "Button", true, false):
		if button.text == caption and button.is_visible_in_tree():
			return button
	return null

func method_source(text: String, method: String) -> String:
	text = text.replace("\r\n", "\n")
	var start := text.find("\nfunc " + method + "(")
	var end := text.find("\nfunc ", start + 1)
	return text.substr(start, text.length() - start if end < 0 else end - start)
