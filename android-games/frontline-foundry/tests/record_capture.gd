extends SceneTree
const S = preload("res://scripts/save_store.gd")
var app: Node
var scene: Node
var folder := ""
var earned_dir := ""
var images := false
var width := 720
var height := 1680
var checks := 0
var failures := 0
var details: Array = []
var events: Array = []
var snapshots: Array = []
var frames: Array = []
var clips: Array = []
var process_tick := 0
var clip := ""
var clip_tick := 0
var clip_process := 0
var last_image_tick := -1
var image_index := 0
var observing := false
var phase := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--earned-dir="): earned_dir=arg.trim_prefix("--earned-dir=")
		if arg.begins_with("--width="): width=int(arg.trim_prefix("--width="))
		if arg.begins_with("--height="): height=int(arg.trim_prefix("--height="))
		if arg=="--capture-images": images=true
	process_frame.connect(func(): process_tick+=1)
	RenderingServer.frame_post_draw.connect(after_draw)
	call_deferred("run")

func check(okay: bool,message: String) -> void:
	checks+=1; details.append({"pass":okay,"message":message})
	if not okay: failures+=1; push_error(message)

func stamp() -> Dictionary:
	return {"physics":Engine.get_physics_frames()-clip_tick,"process":process_tick-clip_process,"physics_absolute":Engine.get_physics_frames(),"process_absolute":process_tick,"time_scale":Engine.time_scale,"wall_usec":Time.get_ticks_usec()}

func whole() -> Dictionary:
	return {"state":scene.state.duplicate(true),"career":scene.career.duplicate(true),"profile":scene.profile.duplicate(true),"settings":scene.settings.duplicate(true)}

func raw_slots() -> Dictionary:
	var result: Dictionary={}
	for suffix in ["0","1","0.tmp","1.tmp"]:
		var path: String=S.PATH+suffix
		if FileAccess.file_exists(path): result[path]=FileAccess.get_file_as_string(path)
	return result

func snapshot(label: String) -> void:
	snapshots.append({"clip":clip,"label":label,"timing":stamp(),"whole":whole(),"raw_slots":raw_slots(),"owning_read":S.read(),"paused":scene.paused,"terminal_text":scene.terminal_detail.text,"journey_visible":scene.journey.visible})

func hold(ticks: int) -> void:
	for tick in ticks: await physics_frame

func tap(text: String) -> void:
	var target: Button
	for button in scene.find_children("*","Button",true,false):
		if button.text==text and button.is_visible_in_tree(): target=button
	check(target!=null and not target.disabled,"actual touch target available: "+text)
	if target==null or target.disabled: return
	var point: Vector2=root.get_final_transform()*target.get_global_rect().get_center()
	for pressed in [true,false]:
		var input:=InputEventScreenTouch.new(); input.index=0; input.position=point; input.pressed=pressed
		events.append({"clip":clip,"timing":stamp(),"kind":"touch","target":text,"pressed":pressed,"position":[point.x,point.y]})
		Input.parse_input_event(input); Input.flush_buffered_events()
		await physics_frame

func wheel(scroll: ScrollContainer) -> void:
	var input:=InputEventMouseButton.new(); input.button_index=MOUSE_BUTTON_WHEEL_DOWN; input.pressed=true
	input.position=root.get_final_transform()*Vector2(scroll.get_global_rect().get_center().x,scroll.get_global_rect().end.y-100)
	events.append({"clip":clip,"timing":stamp(),"kind":"wheel_down","position":[input.position.x,input.position.y]})
	Input.parse_input_event(input); Input.flush_buffered_events()

func after_draw() -> void:
	if not images or not observing or scene==null: return
	var tick: int=Engine.get_physics_frames()-clip_tick
	if tick<2 or tick%2!=0 or tick==last_image_tick: return
	var name: String="%s/frames/%06d.png" % [clip,image_index]
	var timing:=stamp(); timing["delta_physics"]=tick-last_image_tick if last_image_tick>=0 else 2
	var error: int=root.get_texture().get_image().save_png(folder.path_join(name))
	frames.append({"path":name,"clip":clip,"phase":phase,"timing":timing,"save_error":error,"state_time":scene.state.time,"physics_dt":scene.get_physics_process_delta_time()})
	image_index+=1; last_image_tick=tick

func boot_fixture(name: String) -> void:
	if is_instance_valid(app): app.free(); await process_frame
	var slots: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(earned_dir.path_join(name+"-slots.json")))
	check(not slots.is_empty(),"exact genuinely input-earned fixture exists")
	for suffix in ["0","1","0.tmp","1.tmp"]:
		var path: String=S.PATH+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	for path in slots:
		var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(slots[path]); file.close()
	var expected:=S.read(); check(expected.ok,"owning Store accepts exact retained slots before production boot")
	var intake: Dictionary={"label":name,"raw_slots":raw_slots(),"owning_read":expected}
	check(intake.raw_slots==slots,"fixture boundary retains every exact raw slot/path")
	app=load("res://boot.tscn").instantiate(); root.add_child(app); scene=app.session
	await hold(12)
	check(whole()=={"state":expected.state,"career":expected.career,"profile":expected.profile,"settings":expected.settings},"normal production bootstrap preserves complete earned context")
	intake["post_boot_raw_slots"]=raw_slots(); intake["post_boot_whole"]=whole()
	snapshots.append({"clip":clip,"label":"restored earned intake; normal startup save admitted","boundary":intake})

func route(name: String,key: String,campaign: bool) -> void:
	clip=key; phase="restore"; await boot_fixture(name)
	clip_tick=Engine.get_physics_frames(); clip_process=process_tick; last_image_tick=-1; image_index=0
	var start:=stamp(); var before:=whole(); var raw:=raw_slots()
	if images: DirAccess.make_dir_recursive_absolute(folder.path_join(clip+"/frames"))
	observing=true; phase="restored-earned-recap"; snapshot("recap start")
	await hold(180)
	check(whole()==before and raw_slots()==raw,"readonly recap hold preserves complete live context and exact raw slots")
	if campaign:
		phase="admitted-pause-save"; snapshot("before admitted Pause save"); await tap("II"); snapshot("after admitted Pause save")
		check(whole()==before,"existing Pause save changes no live saved meaning")
	# Existing Pause/Resume persist revision writes are admitted; Journey itself is readonly.
	raw=raw_slots(); phase="journey-top"; await tap("JOURNEY / RECORDS"); await hold(120)
	check(scene.journey.visible,"actual touch opens production Journey")
	check(whole()==before and raw_slots()==raw,"Journey open/top preserves exact complete context/raw slots")
	snapshot("Journey top")
	var scroll: ScrollContainer=scene.journey_list.get_parent()
	phase="journey-scroll"
	for index in 40: wheel(scroll); await hold(4)
	await hold(150)
	var last: Control=scene.journey_list.get_child(scene.journey_list.get_child_count()-1)
	check(scroll.get_global_rect().encloses(last.get_global_rect()),"same forty real wheel inputs reach final production Journey row")
	check(whole()==before and raw_slots()==raw,"Journey scroll/bottom preserves exact complete context/raw slots")
	snapshot("Journey bottom")
	phase="journey-close"; await tap("CLOSE"); snapshot("Journey closed before admitted Resume save")
	check(not scene.journey.visible and whole()==before and raw_slots()==raw,"actual Close preserves complete context/raw slots")
	phase="admitted-resume-save"; await tap("RESUME"); snapshot("after admitted Resume save")
	check(whole()==before,"existing Resume save changes no live saved meaning")
	raw=raw_slots(); phase="restored-earned-recap-tail"; await hold(90); snapshot("recap tail before teardown")
	check(whole()==before and raw_slots()==raw,"recap tail preserves complete context/raw path set before teardown")
	observing=false
	var end_tick: int=Engine.get_physics_frames()-clip_tick
	# Route ends before this tick's draw; the final eligible completed draw is earlier.
	var expected_last_tick: int=((end_tick-1)/2)*2
	var expected_images: int=expected_last_tick/2
	if images: check(image_index==expected_images and last_image_tick==expected_last_tick,"exact sampled frame count and final tick include the whole declared capture window")
	clips.append({"clip":clip,"scope":"Restored genuinely input-earned save, not a fresh victory","start":start,"end":stamp(),"ticks":Engine.get_physics_frames()-clip_tick,"images":image_index,"expected_images":expected_images,"expected_last_sampled_tick":expected_last_tick,"fps":30,"source_hz":60})

func run() -> void:
	root.size=Vector2i(width,height); Engine.time_scale=1.0
	check(Engine.physics_ticks_per_second==60,"production physics is60Hz")
	check(not images or DisplayServer.get_name()!="headless","image capture requires coordinator renderer")
	await route("s13-m11-B-terminal","restored-earned-campaign-B",true)
	await route("s16-m07-A-terminal","restored-earned-skirmish",false)
	if images:
		check(not frames.is_empty(),"post-draw observer produced frames")
		check(frames.all(func(frame): return frame.timing.delta_physics==2 and frame.save_error==OK),"every emitted PNG follows two actual physics ticks and saves successfully")
	if is_instance_valid(app): app.free()
	await process_frame; await process_frame
	FileAccess.open(folder.path_join("capture-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details,"events":events,"snapshots":snapshots,"frames":frames,"clips":clips,"viewport":[width,height],"time_scale":Engine.time_scale,"physics_hz":Engine.physics_ticks_per_second,"scope":"Production scene and owning Store, exact restored earned fixtures; actual touch/wheel. CPU mode emits no PNG. Renderer must label clips Restored earned save. Offline fixed60 tick pacing and30fps encode are not measured realtime performance/native/human acceptance."}))
	print("FRONTLINE_RECORD_CAPTURE ",checks," / ",failures)
	print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
