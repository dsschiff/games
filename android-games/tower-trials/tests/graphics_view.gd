extends "res://tests/input_base.gd"
## 3D presentation checks: model/rule-snapshot correspondence, 3D/2D
## alignment at several window shapes, selection and flight tint/motion,
## native Back (pause, map, resume) and resize while paused. Uses actual
## touch input and the same Back request path as back_policy.gd.
## Rendered runs also save frames and sample lit chamber interiors.
const TowerView = preload("res://scripts/presentation/tower_view.gd")
## Includes the overhaul's cover 1080x2520, inner 1968x2184 and native 1080x2400.
const SIZES := [Vector2i(600, 1066), Vector2i(480, 1040), Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1080, 2400), Vector2i(960, 900), Vector2i(1600, 900), Vector2i(600, 1066)]
var back_requests := 0

func _initialize() -> void:
	rendered = DisplayServer.get_name() != "headless"
	folder = "res://.artifacts/graphics/" + ("rendered" if rendered else "headless")
	test_path = "user://tower-graphics-test.json"
	call_deferred("run")

func native_back() -> void:
	root.go_back_requested.emit()
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	back_requests += 1
	await wait_frames(3)

func screen_of(world: Vector3) -> Vector2:
	return game.view.camera.unproject_position(world)

func expected(point: Vector2) -> Vector2:
	return game.get_global_transform() * point

func aligned(label: String) -> void:
	var view: Node3D = game.view
	var worst := 0.0
	for room in game.level.rooms:
		if room.id in game.state.collapsed and not room.id in game.state.claimed:
			continue
		var entry: Dictionary = view.room_nodes[room.id]
		worst = maxf(worst, screen_of(entry.node.global_position).distance_to(expected(game.room_rect(room).get_center())))
	check(worst <= 1.5, "%s: room fronts align with 2D labels (worst %.2f px)" % [label, worst])
	var roof: Vector2 = screen_of(view.home_roof.global_position)
	var top := Vector2(89, 692.0 - game.state.claimed.size() * game.home_stride())
	check(roof.distance_to(expected(top)) <= 1.5, label + ": home roof sits on the 2D watch top")
	check(screen_of(view.courier_base).distance_to(expected(game.courier_point() + Vector2(0, 32))) <= 1.5, label + ": courier rest anchor sits on the 2D watch")
	if not game.pending.is_empty() and not game.data.settings.reduced_effects and game.beat > 0.9 * view.TRAVEL:
		var room_rect: Rect2 = game.room_rect(Rules.find_room(game.level, game.pending_room))
		var feet: Vector2 = screen_of(view.courier.global_position)
		var box := Rect2(expected(room_rect.position), expected(room_rect.end) - expected(room_rect.position))
		check(box.has_point(feet), label + ": courier fights inside the chosen chamber")
	elif game.pending.is_empty() and view.settled():
		check(screen_of(view.courier.global_position).distance_to(expected(game.courier_point() + Vector2(0, 32))) <= 1.5, label + ": settled courier stands on the watch anchor")

func correspondence(label: String) -> void:
	var view: Node3D = game.view
	check(view.board.visible == (game.screen == "game"), label + ": board shown only on the route screen")
	if game.screen != "game":
		return
	check(view.room_nodes.size() == game.level.rooms.size(), label + ": one room model per rule room")
	var enemies := 0
	for room in game.level.rooms:
		enemies += room.enemies.size()
		var entry: Dictionary = view.room_nodes[room.id]
		var shown := 0
		for spirit in entry.spirits:
			if spirit.node.visible: shown += 1
		var cleared: bool = room.id in game.state.claimed or room.id in game.state.collapsed
		check(shown == (0 if cleared else room.enemies.size()), label + ": spirits match enemies in " + room.id)
		var tint: Color = entry.tint
		if room.id in game.state.claimed:
			check(tint == TowerView.TINT_CLAIMED, label + ": claimed tint " + room.id)
		elif room.id in game.state.collapsed:
			check(tint == TowerView.TINT_COLLAPSED, label + ": collapsed tint " + room.id)
		elif room.id == game.selected:
			check(tint == TowerView.TINT_SELECTED, label + ": selected tint " + room.id)
	check(view.spirits.size() == enemies, label + ": spirit pool equals rule enemy count")
	var floors := 0
	for node in view.home_nodes:
		if node.visible: floors += 1
	check(floors == game.state.claimed.size() + 1, label + ": home watch floors equal claimed rooms + 1")

func sample(label: String) -> void:
	await wait_frames(2)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(folder + "/" + label + ".png") == OK, "Saved render " + label)
	captures.append(label)
	if game.screen != "game":
		return
	var stretch := root.get_final_transform()
	var bright := 0
	var total := 0
	for room in game.level.rooms:
		if room.id in game.state.claimed or room.id in game.state.collapsed or Rules.blocked(game.state, room) != "":
			continue
		var rect: Rect2 = game.room_rect(room)
		# Open chambers are lit interiors: at least a quarter of a 7x5 probe
		# grid across the interior (between badges and name plaque) must read
		# as lit plaster or window light, not dark or blown-out flat white.
		var lit := 0
		var white := 0
		for gx in 7:
			for gy in 5:
				var local := rect.position + Vector2(24 + gx * 22, 44 + gy * (rect.size.y - 74) / 4.0)
				var pixel := Vector2i(stretch * expected(local)).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
				var color := image.get_pixelv(pixel)
				if color.get_luminance() > 0.45: lit += 1
				if color.r > .97 and color.g > .97 and color.b > .97: white += 1
		total += 1
		if lit >= 9 and white <= 3: bright += 1
	check(total == 0 or bright == total, "%s: open chambers render as lit, unclipped interiors, %d/%d" % [label, bright, total])

func shapes(prefix: String) -> void:
	for size in SIZES:
		root.size = size
		await wait_frames(4)
		var label := "%s-%dx%d" % [prefix, size.x, size.y]
		correspondence(label)
		if game.screen == "game":
			aligned(label)
		if rendered:
			await sample(label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: DirAccess.remove_absolute(test_path + suffix)
	await create_game()
	check(game.view != null and game.view.is_inside_tree(), "3D presentation is attached")
	check(game.view.camera.current, "Presentation camera is current")
	await shapes("fresh")
	var room: Dictionary = game.level.rooms.filter(func(item): return Rules.blocked(game.state, item) == "")[0]
	await choose(room.id)
	correspondence("selected")
	var power_before: int = game.state.power
	await action("enter")
	await wait_frames(27)
	check(not game.pending.is_empty(), "Courier flight is pending mid-move")
	if not game.data.settings.reduced_effects:
		check(game.view.courier.position.distance_to(game.view.at(game.home_point() + Vector2(0, 32), .3)) > 0.3, "3D courier leaves the home watch during flight")
	aligned("flight")
	if rendered:
		await sample("flight")
	await wait_frames(40)
	check(game.pending.is_empty() and game.state.power != power_before, "Rule resolved the move through natural updates")
	check(game.buttons().has("undo"), "Undo is available immediately while the return animation plays")
	for i in 90:
		if game.view.settled(): break
		await wait_frames(1)
	check(game.view.settled(), "Post-move presentation settles within 1.5 s")
	correspondence("after-move")
	aligned("after-move")
	var before: Dictionary = game.state.duplicate(true)
	await native_back()
	check(game.paused and game.screen == "game" and game.view.frozen, "First Back pauses; presentation frozen")
	root.size = Vector2i(960, 900)
	await wait_frames(4)
	aligned("paused-resized")
	if rendered:
		await sample("paused-resized")
	await native_back()
	check(game.screen == "map" and not game.view.board.visible, "Second Back opens Journey and hides the 3D board")
	if rendered:
		await sample("journey")
	await action("resume")
	await wait_frames(3)
	check(game.screen == "game" and game.view.board.visible and game.state == before, "Resume restores board and identical state")
	correspondence("resumed")
	await shapes("resumed")
	var file := FileAccess.open(folder + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "touch_taps": taps, "back_requests": back_requests, "captures": captures, "sizes": SIZES.map(func(s): return [s.x, s.y]), "scope": "Desktop Godot window; Back via go_back_requested + WM_GO_BACK_REQUEST; not Android hardware/gesture evidence"}, "\t"))
	file.close()
	print("TOWER GRAPHICS: %d checks; %d failures; %d taps; %d back requests" % [checks, failures.size(), taps, back_requests])
	game.queue_free()
	await wait_frames(3)
	if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
