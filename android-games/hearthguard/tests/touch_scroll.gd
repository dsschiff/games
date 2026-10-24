extends "res://tests/import_recovery.gd"
var original_touch := false
var original_mouse := false
var measures: Array=[]
var dispatch: Array=[]
var activations: Array=[]
var scroll_events := 0
var baseline := false

func scroll_started() -> void: scroll_events+=1
func activated(name: String) -> void: activations.append({"text":name,"frame":Engine.get_physics_frames()})
func watch(scroll: ScrollContainer) -> void:
	if not scroll.scroll_started.is_connected(scroll_started): scroll.scroll_started.connect(scroll_started)
	for child in scroll.get_child(0).get_children():
		if child is Button and not child.pressed.is_connected(activated.bind(child.text)): child.pressed.connect(activated.bind(child.text))
func full() -> Dictionary:
	return {"live":decoded_context(scene),"files":scene.save_io.files.duplicate(true),"record":scene.recovery.record.duplicate(true),"original_code":scene.recovery.original_code,"incoming_code":scene.recovery.incoming_code,"replacement":scene.pending.duplicate(true) if scene.get("pending")!=null else {},"paused":scene.paused,"recovery_pending":scene.recovery_pending,"options":[scene.seed_option,scene.budget_option,scene.mirror_option],"save_clock":scene.save_clock}
func stable(before: Dictionary) -> bool: return full()==before
func press(point: Vector2,down: bool,canceled: bool=false) -> void:
	var event:=InputEventScreenTouch.new(); event.index=0; event.position=root.get_final_transform()*point; event.pressed=down; event.canceled=canceled
	dispatch.append({"class":"touch","point":str(event.position),"pressed":down,"canceled":canceled,"frame":Engine.get_physics_frames()}); Input.parse_input_event(event); Input.flush_buffered_events(); await physics_frame
func motion(point: Vector2,relative: Vector2) -> void:
	var event:=InputEventScreenDrag.new(); event.index=0; event.position=root.get_final_transform()*point; event.relative=root.get_final_transform().basis_xform(relative); event.velocity=event.relative*60
	dispatch.append({"class":"drag","point":str(event.position),"relative":str(event.relative),"frame":Engine.get_physics_frames()}); Input.parse_input_event(event); Input.flush_buffered_events(); await physics_frame
func actual(title: String) -> void:
	var target: Button
	for button in scene.find_children("*","Button",true,false):
		if button.text==title and button.is_visible_in_tree() and not button.disabled: target=button
	check(target!=null,"actual visible button "+title)
	if target==null: return
	var ancestor: Node=target.get_parent()
	while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
	check(ancestor==null or ancestor.get_global_rect().encloses(target.get_global_rect()),"actual button entirely inside scroll clip "+title)
	await press(target.get_global_rect().get_center(),true); await press(target.get_global_rect().get_center(),false); await process_frame
func wheel(scroll: ScrollContainer,up: bool=false) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN; event.pressed=true; event.position=root.get_final_transform()*scroll.get_global_rect().get_center()
	dispatch.append({"class":"wheel","up":up,"frame":Engine.get_physics_frames()}); Input.parse_input_event(event); Input.flush_buffered_events(); await physics_frame
func row(scroll: ScrollContainer) -> Button:
	for child in scroll.get_child(0).get_children():
		if child is Button and child.is_visible_in_tree() and scroll.get_global_rect().encloses(child.get_global_rect()): return child
	return null
func swipe_from(button: Button,amount: float) -> void:
	var point:=button.get_global_rect().get_center(); var previous:=point
	await press(point,true)
	for tick in 30:
		var next:=point+Vector2(0,amount*(tick+1)/30.0); await motion(next,next-previous); previous=next
	await press(previous,false); await dwell(10)
func probe(name: String,scroll: ScrollContainer) -> void:
	await dwell(3); watch(scroll)
	var bar:=scroll.get_v_scroll_bar(); var overflow: float=bar.max_value-bar.page
	var before:=full(); var offset:=scroll.scroll_vertical; var signals:=scroll_events
	var target:=row(scroll)
	for step in 20:
		if target!=null: break
		await wheel(scroll); target=row(scroll)
	check(target!=null,name+": a real selectable row is in the visible scroller")
	if target==null: return
	offset=scroll.scroll_vertical
	var amount:=minf(260,scroll.size.y*0.45)
	if offset>=overflow-1: amount=-amount
	await swipe_from(target,-amount)
	var moved: bool=scroll.scroll_vertical!=offset
	measures.append({"name":name,"viewport":str(root.size),"viewport_height":scroll.size.y,"content_extent":bar.max_value,"page":bar.page,"overflow":overflow,"before_offset":offset,"after_offset":scroll.scroll_vertical,"row":target.text,"row_filter":target.mouse_filter,"started":scroll_events-signals,"whole_before":before,"whole_after":full()})
	if overflow>1: check(moved,name+": actual row-body drag scrolls overflowing content")
	check(stable(before),name+": readonly drag preserves full live/saved/pending/code bytes")
	# Positive control uses engine wheel dispatch, never assigns offset or calls a handler.
	var prior:=scroll.scroll_vertical; await wheel(scroll,prior>0)
	if overflow>1: check(scroll.scroll_vertical!=prior,name+": wheel proves actual scroll content can move")
	check(stable(before),name+": wheel also preserves all saved meaning")

func button_named(title: String) -> Button:
	for button in scene.find_children("*","Button",true,false):
		if button.text==title: return button
	return null
func reach(scroll: ScrollContainer,target: Button) -> void:
	await dwell(60) # Let admitted kinetic scrolling settle before a new navigation gesture.
	for step in 45:
		if scroll.get_global_rect().encloses(target.get_global_rect()): break
		await wheel(scroll,target.get_global_rect().get_center().y<scroll.get_global_rect().get_center().y)
	await dwell(3)
	check(scroll.get_global_rect().encloses(target.get_global_rect()),"real wheel navigation reaches "+target.text)
func back_input() -> void:
	for down in [true,false]:
		var event:=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=down
		dispatch.append({"class":"back","pressed":down,"frame":Engine.get_physics_frames()}); Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func canceled_touch(scroll: ScrollContainer,target: Button,name: String) -> void:
	await reach(scroll,target); var before:=full(); var count:=activations.size(); var p:=target.get_global_rect().get_center()
	await press(p,true); await press(p,false,true); await dwell(3)
	check(activations.size()==count,name+": CANCEL emits no button action")
	check(stable(before),name+": CANCEL preserves complete live/raw/journal/codes/options")
func return_drag(scroll: ScrollContainer,target: Button,name: String,canceled: bool=false) -> void:
	await reach(scroll,target); var before:=full(); var count:=activations.size(); var p:=target.get_global_rect().get_center(); var previous:=p
	await press(p,true)
	for tick in 15:
		var next:=p+Vector2(0,-160.0*(tick+1)/15.0); await motion(next,next-previous); previous=next
	# Return the contact to the *current* original row, after the scroller owns it.
	for tick in 15:
		var next:=previous.lerp(target.get_global_rect().get_center(),1.0/(15-tick)); await motion(next,next-previous); previous=next
	var release:=target.get_global_rect().get_center(); await motion(release,release-previous); await press(release,false,canceled); await dwell(5)
	check(activations.size()==count,name+": drag ending inside original row emits no action")
	check(stable(before),name+": drag-return preserves whole live/raw/pending/code state")
func journey_checks() -> void:
	await actual("JOURNEY / REPLAY"); var scroll: ScrollContainer=scene.journey_scroll
	await probe("Journey",scroll)
	var enabled: Button=scroll.get_child(0).get_child(0)
	await return_drag(scroll,enabled,"Journey enabled row")
	await canceled_touch(scroll,enabled,"Journey enabled row")
	await return_drag(scroll,enabled,"Journey canceled drag-return",true)
	var disabled: Button
	for child in scroll.get_child(0).get_children():
		if child is Button and child.disabled: disabled=child; break
	check(disabled!=null,"typed retained progress has an authored locked row")
	if disabled!=null:
		await reach(scroll,disabled); var locked_before:=full(); var count:=activations.size(); var p:=disabled.get_global_rect().get_center()
		await press(p,true); await press(p,false); await dwell(3)
		check(activations.size()==count and stable(locked_before),"disabled row stationary tap neither selects nor mutates")
		await return_drag(scroll,disabled,"Journey disabled row")
	await reach(scroll,enabled); var before:=full(); var count:=activations.size()
	await actual(enabled.text)
	check(activations.size()==count+1 and scene.confirm_panel.visible and not scene.pending.is_empty(),"stationary enabled row selects exactly once and opens existing active-watch confirmation")
	var selected:=full(); selected.replacement={}
	check(selected==before,"selection does not reset active watch or change any complete save/context")
	await actual("KEEP WATCH")
	check(not scene.confirm_panel.visible and stable(before),"existing KEEP WATCH cancels selection without reset/write")
	await reach(scroll,scroll.get_child(0).get_child(scroll.get_child(0).get_child_count()-1))
	check(stable(before),"last Journey row reachable without selection or saved mutation")
	await back_input()
	check(not scene.journey.visible and scene.menu.visible and stable(before),"Back closes Journey without selecting or changing full context")
	await actual("JOURNEY / REPLAY"); await actual("BACK TO WATCH")
	check(not scene.journey.visible and scene.menu.visible and stable(before),"stationary Close returns to Watch with exact context and bytes")
func recovery_checks(io: RecoveryFault) -> void:
	await actual("SAVE / TRANSFER"); scene.code_edit.text=code_for(fixtures.incoming,2); io.mode="active_write"; await actual("IMPORT"); await dwell(3)
	check(scene.recovery_pending and scene.paused and not scene.recovery.record.is_empty(),"actual Import establishes known pending whole-save recovery on injected active-write failure")
	var scroll: ScrollContainer=scene.recovery_panel.get_child(0)
	await probe("Recovery summary",scroll)
	# Only read-only View controls are tapped. No clipboard API is called.
	var target: Button=scene.recovery_buttons.view_previous
	await reach(scroll,target); var before:=full(); var count:=activations.size()
	await actual(target.text); await dwell(3)
	check(activations.size()==count+1 and scene.recovery_code.text==scene.recovery.original_code and not scene.recovery_code.editable,"stationary View Previous acts once and exposes exact readonly retained code")
	check(stable(before),"View Previous preserves all live/save/pending/journal/code bytes")
	await probe("Recovery with code",scroll)
	await return_drag(scroll,target,"Recovery retained View row")
	await canceled_touch(scroll,scene.recovery_buttons.retry,"Recovery Retry row")
	await return_drag(scroll,scene.recovery_buttons.retry,"Recovery canceled Retry drag-return",true)
	await reach(scroll,scene.recovery_buttons.view_incoming); count=activations.size(); before=full()
	await actual("VIEW IMPORTED CODE"); await dwell(3)
	check(activations.size()==count+1 and scene.recovery_code.text==scene.recovery.incoming_code and not scene.recovery_code.editable,"stationary View Imported acts once and retains exact immutable intake code")
	check(stable(before),"View Imported preserves complete live/context/files/record/codes")
	for title in ["RETRY IMPORT","KEEP PREVIOUS WHOLE SAVE"]:
		await reach(scroll,button_named(title)); before=full(); count=activations.size(); var writes:=io.active_writes
		await actual(title); await dwell(3)
		check(activations.size()==count+1 and io.active_writes==writes+1,"stationary recovery choice dispatches exactly once through owning Store "+title)
		check(scene.recovery_pending and scene.paused and stable(before),"failed explicit choice retains whole pending context/codes/journal/bytes "+title)
	await back_input()
	check(scene.recovery_pending and scene.paused and scene.recovery_panel.is_visible_in_tree() and stable(before),"Back cannot close/unfreeze pending recovery or alter its retained data")
	check(button_named("BACK TO WATCH").mouse_filter==Control.MOUSE_FILTER_STOP and scene.seed_button.mouse_filter==Control.MOUSE_FILTER_STOP,"non-column controls retain existing STOP semantics")
func run() -> void:
	original_touch=Input.emulate_touch_from_mouse; original_mouse=Input.emulate_mouse_from_touch
	Input.emulate_touch_from_mouse=true
	fixtures=build_fixtures()
	check(DisplayServer.get_name()=="headless" and DisplayServer.is_touchscreen_available(),"process-local real-engine touchscreen emulation, not native hardware")
	for viewport in [Vector2i(720,1280),Vector2i(720,1680),Vector2i(1153,1280),Vector2i(2276,1280)]:
		root.size=viewport
		var context:=S.decode(code_for(fixtures.source,2)); var io:=fixture_io(context)
		await open_owner(io); await journey_checks(); await recovery_checks(io)
	await finish_touch()
func finish_touch() -> void:
	await shutdown(); await process_frame
	Input.emulate_touch_from_mouse=original_touch; Input.emulate_mouse_from_touch=original_mouse
	check(Input.emulate_touch_from_mouse==original_touch and Input.emulate_mouse_from_touch==original_mouse,"both synthetic input capability properties restored")
	FileAccess.open(folder.path_join("touch-scroll.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details,"dispatch":dispatch,"measures":measures,"activations":activations,"scope":"Actual GUI pointer dispatch with restored process-local headless touchscreen emulation. Typed complete rule-derived state/profile/settings/parked contexts and injected Import failure, no earned-play/native/clipboard/render claim."}))
	print("HEARTH_TOUCH_SCROLL ",checks," / ",failures); print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
