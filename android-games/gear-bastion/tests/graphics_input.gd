extends "res://tests/window_fit.gd"
## Focused integration smoke; retain the full code7 fit evidence separately.

func _initialize() -> void:
	rendered = DisplayServer.get_name() != "headless"
	evidence = "res://.artifacts/graphics-production/input" + ("/rendered" if rendered else "/headless")
	root.size = Vector2i(600,1066)
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	game = Scene.instantiate()
	game.save_path = "user://graphics-input-isolated.json"
	game.save_backend = FaultFiles.new()
	root.add_child(game)
	game.set_process(false)
	await settle()
	check(is_instance_valid(game.presentation),"Actual main scene owns the imported 3D presentation")
	for dimensions in [Vector2i(1080,2520),Vector2i(1968,2184),Vector2i(2184,1968)]:
		root.size = dimensions
		await settle()
		await input_case("3d-%dx%d" % [dimensions.x,dimensions.y],false)
		check(game.presentation.actors.size() > 0,"Actual input produced modeled live troops/raiders")
		check(game.presentation.arches.size() == 3,"Main scene retains three original modeled arches")
		var held: String = Saves.encode(game.state,game.settings,0,true,game.profile)
		await touch(game.cell_center(1,2),true)
		root.size = Vector2i(dimensions.y,dimensions.x)
		await settle()
		await touch(game.cell_center(0,2),false)
		check(held == Saves.encode(game.state,game.settings,0,true,game.profile),"3D resize cancels stale input and preserves whole run")
		for y in 4:
			for x in 5:
				var point: Vector2 = game.cell_center(x,y)
				check(game.presentation.world_to_canvas(game.presentation.canvas_to_world(point)).distance_to(point) < .01,"Main safe-canvas camera projection matches actual socket picking")
	await transfer_case()
	game.state = Battle.initial(1701,"iron_trial")
	game.reset_presentation()
	await input_case("3d-legacy",true)
	game.retry()
	check(game.presentation.adapter.current.is_empty() and game.presentation.effects.is_empty() and game.presentation.corpses.is_empty(),"Actual Retry resets presentation namespace, transient effects and old actors")
	var report := {"checks":checks,"failures":failures,"events":events,"samples":samples,"rendered":rendered}
	var file := FileAccess.open(evidence+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("GRAPHICS_INPUT: %d checks, %d failures, %d events" % [checks,failures.size(),events])
	print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
