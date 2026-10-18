extends "res://tests/window_fit.gd"
## Actual app input and natural process-loop simulation. Never assigns game state.
var run_directory := ""
var stage := "opening"
var duration := 120.0
var fixed_fps := 0
var native_frames := false
var expected_path := ""
var frame_number := 0
var observations: Array = []
var inputs: Array = []
var start_context: Dictionary = {}
var native_inventory: Array = []
var maximum_allies := 0
var maximum_enemies := 0
var movie_started := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="): run_directory = arg.trim_prefix("--run-dir=")
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
		if arg.begins_with("--seconds="): duration = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--capture-fixed-fps="): fixed_fps = int(arg.trim_prefix("--capture-fixed-fps="))
		if arg.begins_with("--expected-start="): expected_path = arg.trim_prefix("--expected-start=")
		if arg == "--native-frames": native_frames = true
	rendered = DisplayServer.get_name() != "headless"
	evidence = run_directory + "/stills"
	call_deferred("run")

func touch(point: Vector2, pressed: bool) -> void:
	inputs.append({"kind":"touch","point":[point.x,point.y],"pressed":pressed,"frame":frame_number,"simulation":float(game.state.time)})
	await super.touch(point,pressed)

func drag(from: Vector2, to: Vector2) -> void:
	inputs.append({"kind":"drag","from":[from.x,from.y],"to":[to.x,to.y],"frame":frame_number,"simulation":float(game.state.time)})
	await super.drag(from,to)

func action(key: String) -> void:
	inputs.append({"kind":"action","action":key,"frame":frame_number,"simulation":float(game.state.time)})
	await super.action(key)

func context() -> Dictionary:
	return {"active_run":game.state.duplicate(true),"profile":game.profile.duplicate(true),"settings":game.settings.duplicate(true)}

func equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < .000000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not equal(a[i],b[i]): return false
		return true
	return a == b

func wait_play(seconds: float) -> void:
	# Timers use the engine delta. Fixed-rate movies therefore play at ordinary
	# simulation speed even when recording takes longer than real wall time.
	await create_timer(seconds).timeout

func on_frame() -> void:
	if not is_instance_valid(game): return
	frame_number += 1
	maximum_allies = maxi(maximum_allies,game.state.units.size())
	maximum_enemies = maxi(maximum_enemies,game.state.enemies.size())
	if frame_number % 30 == 0:
		var roles: Dictionary = {}
		for unit in game.state.units + game.state.enemies:
			roles[unit.kind] = int(roles.get(unit.kind,0))+1
		observations.append({"frame":frame_number,"simulation":float(game.state.time),"phase":str(game.state.phase),"paused":game.paused,"allies":game.state.units.size(),"enemies":game.state.enemies.size(),"roles":roles,"attacks":game.presentation.attacks_emitted,"impacts":game.presentation.impacts_emitted})
	if native_frames:
		var original: Image = root.get_texture().get_image()
		var size := original.get_size()
		if size.x > 1092 or size.y > 1680:
			check(false,"Native frame exceeds declared evidence canvas; no scaling fallback")
			quit(1)
			return
		var canvas_size := Vector2i(1092,1680) if stage in ["reset","restore"] else Vector2i(720,1680)
		var canvas := Image.create(canvas_size.x,canvas_size.y,false,Image.FORMAT_RGBA8)
		canvas.fill(Color("10161c"))
		var offset := Vector2i((canvas_size.x-size.x)/2,0)
		canvas.blit_rect(original,Rect2i(Vector2i.ZERO,size),offset)
		canvas.save_png(run_directory+"/frames/%06d.png" % (frame_number-1))
		native_inventory.append({"frame":frame_number-1,"native":[size.x,size.y],"offset":[offset.x,offset.y]})

func button_in_dialog(caption: String) -> void:
	for button in game.save_dialog.find_children("*","Button",true,false):
		if button.text == caption:
			await tap(game.to_local(Vector2(game.save_dialog.position)+button.get_global_rect().get_center()))
			return
	check(false,"Missing actual dialog button "+caption)

func save_slots() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(run_directory+"/slots")
	var result: Dictionary = {}
	for suffix in ["", ".bak"]:
		var source: String = ProjectSettings.globalize_path(Saves.PATH+suffix)
		if FileAccess.file_exists(source):
			var destination: String = run_directory+"/slots/bastion-save.json"+str(suffix)
			check(DirAccess.copy_absolute(source,destination)==OK,"Retain actual app-written save slot "+suffix)
			check(FileAccess.get_sha256(source)==FileAccess.get_sha256(destination),"Retained raw slot hash agrees "+suffix)
			result["bastion-save.json"+suffix] = FileAccess.get_sha256(destination)
	return result

func prepare_first() -> void:
	await action("mission0")
	await wait_play(1)
	await move(0,2,1,2)
	await wait_play(.8)
	await purchase("guard",3,2,2)
	await wait_play(.8)
	await purchase("drive",1,1)
	await wait_play(.8)
	await purchase("drive",3,1)
	await wait_play(1)
	check(Gear.powered(game.state.board).size()==game.state.board.size(),"Actual fresh preparation powers the complete foundry")
	await capture("prepared")
	await action("begin")

func play_until(seconds: float, stop_at_terminal: bool = true) -> void:
	var start := float(game.state.time)
	var budget := 0.0
	while float(game.state.time)-start < seconds and (not stop_at_terminal or game.state.phase=="battle"):
		await wait_play(.5)
		budget += .5
		if budget > seconds+10: break

func run() -> void:
	if not rendered or run_directory.is_empty():
		push_error("Motion evidence requires the coordinator's render slot and isolated runner")
		quit(1);return
	DirAccess.make_dir_recursive_absolute(evidence)
	if native_frames: DirAccess.make_dir_recursive_absolute(run_directory+"/frames")
	game = Scene.instantiate()
	root.add_child(game)
	RenderingServer.frame_post_draw.connect(on_frame)
	await settle()
	if not expected_path.is_empty():
		var expected := Saves.decode(FileAccess.get_file_as_string(expected_path))
		check(expected.ok,"Bound authentic starting save validates")
		if expected.ok:
			check(equal(context(),{"active_run":expected.state,"profile":expected.profile,"settings":expected.settings}),"Before any gameplay input, the whole loaded run/profile/settings equal the authentic save")
		if not failures.is_empty():
			finish({});return
	start_context = context()
	await capture("loaded-start")
	if stage == "opening":
		await prepare_first()
		await play_until(duration)
		await capture("opening-outcome")
		if duration >= 125:
			check(game.state.phase=="victory" and "camp_01" in game.profile.cleared,"Actual fresh input reaches earned First Spark victory")
		await wait_play(3)
	elif stage in ["heavy","later","metrics"]:
		await action("resume_run")
		check(game.paused and game.state.phase=="battle","Authentic active run enters the scene paused")
		await capture("paused-start")
		await action("pause")
		if stage == "metrics":
			check(fixed_fps==0 and Engine.get_write_movie_path().is_empty(),"Wall-clock measurement has no fixed-rate/movie writer")
			game.frame_capture.start({"purpose":"separate sustained actual dense encounter","capture":"real-time, no movie writer, no still readback during sampling","fixed_cadence_capture":false,"window":[root.size.x,root.size.y]})
		await play_until(duration)
		var timing: Dictionary = game.frame_capture.stop() if stage=="metrics" else {}
		if game.state.phase=="battle":
			await action("pause")
		else:
			await wait_play(.1)
		await capture("play-outcome")
		check(maximum_allies<=120 and maximum_enemies<=90,"Actual encounter retains original actor caps")
		check(int(game.state.kills)>int(start_context.active_run.kills),"Actual retained run shows consequential combat")
		if stage=="later" and duration>=40:
			check(game.state.phase=="victory" and "camp_09" in game.profile.cleared,"Authentic finale reaches earned victory")
		if stage=="metrics":
			check(int(timing.heavy_frames.frames)>60,"Actual dense encounter yields at least sixty eligible heavy wall-clock samples")
			finish({"real_time_sampler":timing});return
		await wait_play(3)
	elif stage == "reset":
		await action("resume_run")
		check(game.state.phase=="victory","Reset passage begins at genuinely earned prior victory")
		var profile: Dictionary = game.profile.duplicate(true)
		var config: Dictionary = game.state.config.duplicate(true)
		var epoch: int = game.presentation.adapter.epoch
		await wait_play(1)
		await action("begin")
		check(game.state.phase=="ready" and game.state.time==0 and equal(game.state.config,config) and equal(game.profile,profile),"Actual Retry preserves definition/earned profile and resets active attempt")
		check(game.presentation.adapter.epoch>epoch and game.presentation.effects.is_empty() and game.presentation.corpses.is_empty(),"Actual Retry clears old presentation namespace/transients")
		for step in Policy.plan(game.state,"A"):
			if step.has("move"): continue
			var allowed := Gear.buy(game.state.board,step.kind,int(step.x),int(step.y),int(game.state.gold),int(game.state.next_id),str(game.state.encounter),game.state.config)
			if allowed.ok: await purchase(step.kind,int(step.x),int(step.y),int(step.lane))
		await action("begin")
		await wait_play(4)
		await action("pause")
		var held := context()
		await capture("pause-before")
		var before: Image = root.get_texture().get_image()
		await wait_play(1)
		await capture("pause-after")
		check(before.get_data()==root.get_texture().get_image().get_data() and equal(held,context()),"Pause freezes exact rendered pixels and full saved meaning")
		root.size=Vector2i(984,1092)
		await settle();await capture("inner-paused")
		check(equal(held,context()),"Actual unfolded resize preserves entire paused run")
		await move(1,3,0,3)
		check(Gear.at(game.state.board,1,3)<0 and Gear.at(game.state.board,0,3)>=0,"Actual transformed move changes the intermediate board")
		await action("undo")
		check(equal(held,context()),"Actual transformed move/Undo after resize preserves whole context")
		await action("effects")
		check(game.settings.reduced_effects,"Actual menu enables reduced effects")
		await action("pause");await wait_play(3);await action("pause")
		root.size=Vector2i(1092,984)
		await settle();await capture("landscape-paused")
		root.size=Vector2i(720,1680)
		await settle();await capture("cover-parked")
		check(game.paused and equal(profile,game.profile),"Parked active run retains complete earned profile")
	elif stage == "restore":
		await action("resume_run")
		check(game.paused and game.presentation.attacks_emitted==0,"Cold load hydrates paused without phantom shots")
		await capture("cold-paused")
		await wait_play(1)
		await action("pause");await wait_play(4);await action("pause")
		await capture("cold-resumed-parked")
		check(float(game.state.time)>float(start_context.active_run.time),"Real Resume advances the same cold-restored encounter")
	elif stage == "legacy":
		await action("practice")
		check(game.state.encounter=="tutorial" and game.state.config.is_empty(),"Actual map opens legacy practice")
		await action("begin");await wait_play(duration);await action("pause")
		await capture("legacy-live")
		check(game.state.units.size()>0 and game.presentation.actors.size()>0,"Legacy rules feed the shared articulated 3D presentation")
	finish({})

func finish(extra: Dictionary) -> void:
	var slots := save_slots()
	var report := {"stage":stage,"checks":checks,"failures":failures,"pointer_keyboard_events":events,"fixed_fps":fixed_fps,"movie_writer_path":Engine.get_write_movie_path(),"native_padded_frames":native_frames,"frame_count":frame_number,"observations":observations,"inputs":inputs,"start_context":start_context,"end_context":context(),"maximum_allies":maximum_allies,"maximum_enemies":maximum_enemies,"raw_save_slots":slots,"native_inventory":native_inventory,"limits":"Actual app input/process-loop evidence. Fixed-rate movies are not wall-clock/phone performance."}
	report.merge(extra)
	var file := FileAccess.open(run_directory+"/motion-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("GRAPHICS_MOTION: %s %d checks, %d failures, peak %d allies/%d enemies" % [stage,checks,failures.size(),maximum_allies,maximum_enemies])
	print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
	game.free()
	quit(0 if failures.is_empty() else 1)
