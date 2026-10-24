extends "res://tests/record_capture.gd"
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")
var native_dir := ""
var baseline := false
var gui_events: Array=[]
var scroll_starts := 0
var scroll_ends := 0
var activations: Array=[]

func all_raw() -> Dictionary:
	var files: Dictionary={}
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("frontline-"): files[name]=FileAccess.get_file_as_bytes("user://"+name).hex_encode()
	return files

func capture(label: String) -> void:
	snapshots.append({"label":label,"whole":whole(),"raw_all":all_raw(),"viewport":str(root.size),"scroll":scene.journey_list.get_parent().scroll_vertical if scene.journey_list!=null else -1,"journey":scene.journey.visible,"starts":scroll_starts,"ends":scroll_ends})

func boot_native() -> void:
	if is_instance_valid(app): app.free(); await process_frame
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("frontline-"): DirAccess.remove_absolute("user://"+name)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(native_dir.path_join("capture.json")))
	for item in manifest.files:
		var source: String=native_dir.path_join(item.name); var bytes:=FileAccess.get_file_as_bytes(source)
		check(bytes.size()==item.bytes and FileAccess.get_sha256(source)==item.sha256,"authentic native retained file "+item.name)
		var output:=FileAccess.open("user://"+item.name,FileAccess.WRITE); output.store_buffer(bytes); output.close()
	check(all_raw().size()==15,"all fifteen native retained raw files materialized exactly")
	var saved:=S.read(); check(saved.ok and saved.state.phase!="playing","native fixture owning decoder and terminal boundary valid")
	app=load("res://boot.tscn").instantiate(); root.add_child(app); scene=app.session; await hold(4)
	check(whole()=={"state":saved.state,"career":saved.career,"profile":saved.profile,"settings":saved.settings},"normal native-fixture bootstrap preserves complete state/profile/settings/career")

func listen() -> void:
	var scroll: ScrollContainer=scene.journey_list.get_parent()
	scroll_starts=0; scroll_ends=0
	if not scroll.scroll_started.is_connected(note_start): scroll.scroll_started.connect(note_start)
	if not scroll.scroll_ended.is_connected(note_end): scroll.scroll_ended.connect(note_end)
	if not scroll.gui_input.is_connected(note_gui): scroll.gui_input.connect(note_gui)
	for child in scene.journey_list.get_children():
		if child is Button: child.pressed.connect(record_activation.bind(child.get_index()))

func note_start() -> void: scroll_starts+=1
func note_end() -> void: scroll_ends+=1
func note_gui(event: InputEvent) -> void:
	gui_events.append({"class":event.get_class(),"device":event.device,"physics":Engine.get_physics_frames(),"scroll":scene.journey_list.get_parent().scroll_vertical})

func record_activation(index: int) -> void:
	activations.append({"row":index,"physics":Engine.get_physics_frames()})

func touch(point: Vector2,pressed: bool,canceled: bool=false) -> void:
	var event:=InputEventScreenTouch.new(); event.index=0; event.position=root.get_final_transform()*point; event.pressed=pressed; event.canceled=canceled
	events.append({"kind":"touch","position":str(event.position),"pressed":pressed,"canceled":canceled,"physics":Engine.get_physics_frames()})
	Input.parse_input_event(event); Input.flush_buffered_events(); await physics_frame

func move_touch(point: Vector2,relative: Vector2) -> void:
	var event:=InputEventScreenDrag.new(); event.index=0; event.position=root.get_final_transform()*point; event.relative=root.get_final_transform().basis_xform(relative); event.velocity=event.relative*60
	events.append({"kind":"drag","position":str(event.position),"relative":str(event.relative),"physics":Engine.get_physics_frames()})
	Input.parse_input_event(event); Input.flush_buffered_events(); await physics_frame

func swipe(delta: float) -> void:
	var scroll: ScrollContainer=scene.journey_list.get_parent(); var rect:=scroll.get_global_rect()
	var start:=Vector2(rect.get_center().x+100,rect.end.y-90 if delta<0 else rect.position.y+90)
	await touch(start,true)
	var previous:=start
	for frame in 39:
		var point:=start+Vector2(0,delta*(frame+1)/39.0); await move_touch(point,point-previous); previous=point
	await touch(previous,false); await hold(12)

func open_journey() -> void:
	if not scene.menu.visible: await tap("II")
	await tap("JOURNEY / RECORDS"); await hold(3); listen()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--native-dir="): native_dir=arg.trim_prefix("--native-dir=")
		if arg=="--baseline": baseline=true
	root.size=Vector2i(720,1680); Engine.time_scale=1
	Input.emulate_touch_from_mouse=true
	check(DisplayServer.get_name()=="headless" and DisplayServer.is_touchscreen_available(),"headless real-engine touchscreen-emulation seam active; not native Android")
	for viewport in [Vector2i(720,1680),Vector2i(1153,1280),Vector2i(2276,1280)]:
		root.size=viewport; await hold(3); await run_case()
		if baseline: return
	await finish_touch()

func run_case() -> void:
	await boot_native(); await open_journey()
	var initial_activations: int=activations.size()
	var before:=whole(); var raw:=all_raw(); capture("native materialized baseline")
	for repeat in 3: await swipe(-340)
	capture("three row-body swipes")
	var scroll: ScrollContainer=scene.journey_list.get_parent(); var last: Control=scene.journey_list.get_child(11)
	check(scroll.scroll_vertical>0,"actual row-body touch drags advance production ScrollContainer")
	check(scroll_starts>0,"production scroller receives drag and emits scroll_started")
	check(scroll.get_global_rect().encloses(last.get_global_rect()),"three actual swipes reach mission12 without assigning scroll properties")
	check(scene.journey.visible and whole()==before and all_raw()==raw,"drag from disabled rows never selects/resets or writes any of fifteen files")
	var wheel_before: int=scroll.scroll_vertical
	var wheel_event:=InputEventMouseButton.new(); wheel_event.pressed=true; wheel_event.button_index=MOUSE_BUTTON_WHEEL_UP if wheel_before>0 else MOUSE_BUTTON_WHEEL_DOWN; wheel_event.position=root.get_final_transform()*scroll.get_global_rect().get_center()
	Input.parse_input_event(wheel_event); Input.flush_buffered_events(); await hold(2)
	check(scroll.scroll_vertical!=wheel_before and whole()==before and all_raw()==raw,"real mouse-wheel positive control scrolls without saved-context changes")
	if baseline: await finish_touch(); return
	await tap("CLOSE"); check(not scene.journey.visible and whole()==before and all_raw()==raw,"Close keeps entire saved context and all raw files")
	await open_journey(); raw=all_raw()
	for repeat in 3: await swipe(340)
	check(scroll.scroll_vertical==0 and whole()==before and all_raw()==raw,"actual reverse swipes return retained Journey offset to top without writes")
	var disabled: Button=scene.journey_list.get_child(2); check(disabled.disabled,"native saved progress keeps future row disabled")
	await touch(disabled.get_global_rect().get_center(),true); await touch(disabled.get_global_rect().get_center(),false)
	check(scene.journey.visible and whole()==before and all_raw()==raw,"stationary disabled-row tap cannot select or save")
	var enabled: Button=scene.journey_list.get_child(0); var point:=enabled.get_global_rect().get_center()
	await touch(point,true); await touch(point,false,true)
	check(scene.journey.visible and whole()==before and all_raw()==raw,"canceled enabled-row contact cannot select or save")
	await touch(point,true); await move_touch(point+Vector2(0,70),Vector2(0,70)); await move_touch(point,Vector2(0,-70)); await touch(point,false); await hold(20)
	check(scene.journey.visible and whole()==before and all_raw()==raw and activations.size()==initial_activations,"drag returning inside enabled row cancels selection without any pressed signal")
	var key:=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=true; Input.parse_input_event(key); Input.flush_buffered_events(); await hold(2)
	key.pressed=false; Input.parse_input_event(key); Input.flush_buffered_events(); await physics_frame
	check(not scene.journey.visible and whole()==before and all_raw()==raw,"actual Back key closes Journey without saved-context changes")
	await open_journey(); raw=all_raw()
	for repeat in 3: await swipe(340)
	check(scroll.scroll_vertical==0,"actual reverse swipes recover top after adversarial drag inertia")
	enabled=scene.journey_list.get_child(0); point=enabled.get_global_rect().get_center(); await touch(point,true); await touch(point,false)
	check(activations.size()==initial_activations+1 and activations.back().row==0,"stationary tap emits exactly one requested row activation")
	check(not scene.journey.visible and scene.state==C.fresh(D.mission(0)),"stationary enabled-row touch selects exactly requested mission with existing reset semantics")
	check(scene.career==before.career and scene.profile==before.profile and scene.settings==before.settings,"actual selection preserves exact career/profile/settings")
	var after_raw:=all_raw(); check(after_raw.size()==raw.size(),"explicit selection keeps complete retained-file path set")
	for name in raw:
		if not name.begins_with("frontline-save-"): check(after_raw.get(name)==raw[name],"explicit selection retains exact archived code "+name)
	var expected:=whole(); var verified:=S.read()
	var expected_saved:=S.decode(S.encode(expected.state,expected.profile,expected.settings,0,true,expected.career)); var verified_saved:=S.decode(S.encode(verified.state,verified.profile,verified.settings,0,true,verified.career))
	check(verified.ok and expected_saved==verified_saved,"owning Store read verifies exact complete normalized selected mission context")
	capture("explicit mission selection; normal save admitted")
	app.free(); await process_frame; app=load("res://boot.tscn").instantiate(); root.add_child(app); scene=app.session; await hold(3)
	var wanted:=S.decode(S.encode(expected.state,expected.profile,expected.settings,0,true,expected.career)); var actual:=S.decode(S.encode(scene.state,scene.profile,scene.settings,0,true,scene.career))
	check(wanted.ok and wanted==actual,"fresh production owner keeps exact complete Store-normalized selected context")
	capture("fresh owner after actual selection; startup save admitted")

func finish_touch() -> void:
	if is_instance_valid(app): app.free()
	await process_frame; await process_frame
	FileAccess.open(folder.path_join("journey-touch.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details,"events":events,"snapshots":snapshots,"gui_events":gui_events,"row_activations":activations,"scroll_starts":scroll_starts,"scroll_ends":scroll_ends,"scope":"Actual Input.parse touch/drag and GUI dispatch in headless real-engine touchscreen emulation. Materialized authentic native15-file context, normal production boot. No native/render/clipboard; no direct scroll property or selection handler invocation."}))
	print("FRONTLINE_JOURNEY_TOUCH ",checks," / ",failures); print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
