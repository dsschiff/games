extends "res://tests/input_base.gd"
## Rendered tour for visual review: opening watch, a full courier encounter,
## a mid-chapter key/bridge/trap board, a late chapter, the tall watch at the
## final rescue and the ending. Progress is seeded through the app's own save
## format; every room move after that is actual touch input resolved by the
## game's natural updates. Frames go to .artifacts/graphics/tour/<label>/.
## User args: -- --label=<name> --size=720x1280
const Content = preload("res://scripts/content.gd")
var label := "current"
var size := Vector2i(720, 1280)
var log: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	rendered = DisplayServer.get_name() != "headless"
	folder = "res://.artifacts/graphics/tour/" + label
	test_path = "user://tower-graphics-tour.json"
	call_deferred("run")

func shot(id: String) -> void:
	await wait_frames(1)
	if rendered:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(image.save_png(folder + "/" + id + ".png") == OK, "Saved tour frame " + id)
		log.append({"id": id, "image": [image.get_width(), image.get_height()], "level": game.data.level_id, "power": game.state.power, "claimed": game.state.claimed.size(), "pending": not game.pending.is_empty(), "beat": game.beat})
	captures.append(id)

func seed_level(index: int) -> void:
	if game != null:
		game.queue_free()
		await wait_frames(2)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: DirAccess.remove_absolute(test_path + suffix)
	var data := Saves.fresh()
	var all := Content.levels()
	for i in index:
		data.profile[all[i].id] = {"best": int(all[i].par), "medals": 1}
	data.level = index
	data.level_id = all[index].id
	check(Saves.write(data, test_path), "Seeded save for " + all[index].id)
	await create_game()
	root.size = size
	await wait_frames(4)

func step_to(id: String) -> void:
	await choose(id)
	await action("enter")
	await wait_frames(70)

func feature_score(level: Dictionary) -> int:
	var score := 0
	for room in level.rooms:
		if int(room.key_cost) > 0: score += 2
		if not room.collapse.is_empty(): score += 3
		if int(room.trap) > 0: score += 2
		if room.enemies.size() > 1: score += 1
	return score

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	# Opening watch and one full encounter at fixed 60 fps.
	await seed_level(0)
	await shot("01-opening")
	var route: Array = Rules.solve(game.level, game.state).route
	await choose(route[0])
	await shot("02-opening-selected")
	await action("enter")
	for pair in [[8, "03-encounter-walk"], [16, "04-encounter-arrive"], [10, "05-encounter-strike"], [10, "06-encounter-fall"], [8, "07-encounter-absorb"], [6, "08-claim-pop"], [24, "09-claim-settled"]]:
		await wait_frames(int(pair[0]) - 1)
		await shot(pair[1])
	await wait_frames(40)
	# Mid-chapter: the richest key/bridge/trap board in chapters 2-3.
	var all := Content.levels()
	var best := 9
	for i in range(9, 27):
		if feature_score(all[i]) > feature_score(all[best]): best = i
	await seed_level(best)
	route = Rules.solve(game.level, game.state).route
	await step_to(route[0])
	if route.size() > 2: await step_to(route[1])
	var open: Array = game.level.rooms.filter(func(room): return Rules.blocked(game.state, room) == "")
	if not open.is_empty(): await choose(open[0].id)
	await shot("10-mid-chapter-%s" % game.data.level_id)
	# Late chapter.
	await seed_level(31)
	route = Rules.solve(game.level, game.state).route
	for i in mini(2, route.size() - 1): await step_to(route[i])
	await shot("11-late-%s" % game.data.level_id)
	# Tall watch: the final watch just before and after its rescue.
	await seed_level(35)
	route = Rules.solve(game.level, game.state).route
	for i in route.size() - 1: await step_to(route[i])
	await shot("12-tall-watch-before-final")
	await choose(route[route.size() - 1])
	await action("enter")
	await wait_frames(30)
	await shot("13-final-clash")
	await wait_frames(34)
	await shot("14-final-claim-pop")
	await wait_frames(30)
	await shot("15-final-rescued")
	await action("next")
	await wait_frames(20)
	check(game.screen == "ending", "Final Next opens the ending")
	await shot("16-ending")
	await wait_frames(60)
	await shot("17-ending-later")
	var file := FileAccess.open(folder + "/tour.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "taps": taps, "size": [size.x, size.y], "frames": log, "mid_level": all[best].id}, "\t"))
	file.close()
	print("TOWER TOUR %s: %d checks; %d failures; %d frames" % [label, checks, failures.size(), captures.size()])
	game.queue_free()
	await wait_frames(3)
	if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
