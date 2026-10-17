extends SceneTree
const Scene = preload("res://main.tscn")
const Battle = preload("res://scripts/battle_rules.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error(detail)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Actor atlas checks require a rendered viewport")
		quit(1)
		return
	var game := Scene.instantiate()
	game.save_path = "user://actor-render-isolated.json"
	root.add_child(game)
	game.set_process(false)
	for i in 8:
		await process_frame
	check(game.actor_art.atlas != null, "Runtime atlas is baked")
	if game.actor_art.atlas == null:
		quit(1)
		return
	var image: Image = game.actor_art.atlas.get_image()
	for index in game.actor_art.KINDS.size():
		var normal := 0
		var flash := 0
		var colored := 0
		for y in 128:
			for x in 128:
				var p := image.get_pixel(index * 128 + x, y)
				var hit := image.get_pixel(index * 128 + x, y + 128)
				if p.a > 0.1:
					normal += 1
					if hit.a > 0.1 and hit.r > 0.99 and hit.g > 0.99 and hit.b > 0.99:
						flash += 1
					if p.r < 0.9 or p.g < 0.9 or p.b < 0.9:
						colored += 1
		check(normal > 50 and flash == normal and colored > 20, "Colored body and white flash cached for " + game.actor_art.KINDS[index])
	game.state = Battle.initial(1701, "camp_09")
	game.screen = "game"
	Battle.start(game.state)
	for index in game.actor_art.KINDS.size():
		var kind: String = game.actor_art.KINDS[index]
		var unit := Battle.make_unit(game.state, kind, index % 3, index < 3)
		unit.x = 100 + (index % 4) * 130
		unit.y = 255 + (index / 4) * 105
		unit.hp *= 0.6
		unit.flash = 0.1 if index % 2 == 0 else 0.0
		if index < 3:
			game.state.units.append(unit)
		else:
			game.state.enemies.append(unit)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.artifacts/actor-render")
	root.get_texture().get_image().save_png("res://.artifacts/actor-render/all-kinds-flash-health.png")
	game.settings.reduced_effects = true
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/actor-render/reduced-effects.png")
	game.queue_free()
	await process_frame
	print("ACTOR RENDER: ", checks, " checks; ", failures.size(), " failures")
	print("SUITE_COMPLETE: PASS" if failures.is_empty() else "SUITE_COMPLETE: FAIL")
	quit(0 if failures.is_empty() else 1)
