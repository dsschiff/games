extends "res://tests/window_fit.gd"
## First bounded real-time 3D inspection: fresh game, real touch, no injected run.
var run_directory := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="):
			run_directory = arg.trim_prefix("--run-dir=")
	rendered = DisplayServer.get_name() != "headless"
	evidence = run_directory + "/frames"
	call_deferred("run")

func wait_seconds(seconds: float) -> void:
	var stop := Time.get_ticks_msec() + int(seconds*1000)
	while Time.get_ticks_msec() < stop:
		await process_frame

func run() -> void:
	if not rendered or run_directory.is_empty():
		push_error("Rendered inspection needs the coordinator's slot and isolated runner")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(evidence)
	game = Scene.instantiate()
	game.save_path = "user://graphics-inspection.json"
	root.add_child(game)
	await settle()
	await capture("00-map")
	await action("mission0")
	check(game.state.encounter == "camp_01" and game.state.phase == "ready","Actual fresh map starts First Spark")
	await capture("01-ready")
	await move(0,2,1,2)
	await purchase("guard",3,2,2)
	await purchase("drive",1,1)
	check(Gear.powered(game.state.board).size() == game.state.board.size(),"Real placement connects the original 3D network")
	await capture("02-connected")
	await action("begin")
	game.frame_capture.start({"purpose":"first bounded real-time 3D inspection","capture":"stills only; no fixed FPS/movie writer","window":[root.size.x,root.size.y]})
	await wait_seconds(2)
	await capture("03-generator-deployment")
	await wait_seconds(4)
	await capture("04-arch-traversal")
	await wait_seconds(6)
	await capture("05-early-battle")
	check(game.state.produced > 0 and not game.state.enemies.is_empty(),"Actual continuous simulation populated automata and beetle raiders")
	await action("pause")
	var held: String = Saves.encode(game.state,game.settings,0,true,game.profile)
	await capture("06-paused-cover")
	root.size = Vector2i(984,1092)
	await settle()
	await capture("07-paused-inner")
	check(held == Saves.encode(game.state,game.settings,0,true,game.profile),"Real resize preserves the complete paused run")
	await move(1,1,3,1)
	await action("undo")
	await tap(game.cell_center(3,2))
	await action("gate0")
	check(int(game.selected_piece().lane) == 0,"Actual unfolded gate picking follows shared 3D layout")
	await action("pause")
	await wait_seconds(3)
	await capture("08-resumed-inner")
	await action("save")
	await capture("09-transfer")
	await key_back()
	var timing: Dictionary = game.frame_capture.stop()
	var report := {"checks":checks,"failures":failures,"events":events,"whole_run":JSON.parse_string(Saves.encode(game.state,game.settings,0,true,game.profile)),"real_time_sampler":timing,"limits":"Fresh real-input bounded inspection; still review and FPS interpretation remain separate"}
	var file := FileAccess.open(run_directory+"/inspection.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("GRAPHICS_INSPECT: %d checks, %d failures" % [checks,failures.size()])
	print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
