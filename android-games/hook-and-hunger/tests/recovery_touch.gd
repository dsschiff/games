extends "res://tests/copy_confirm.gd"
## Real GUI touch routing; labelled complete fixtures and fake clipboard, never OS calls.
class TouchFault extends Faults:
 var write_calls := 0
 var rename_calls := 0
 var remove_calls := 0
 func write_text(path: String,text: String) -> bool:
  write_calls+=1;return super.write_text(path,text)
 func rename(from: String,to: String) -> bool:
  rename_calls+=1;return super.rename(from,to)
 func remove(path: String) -> bool:
  remove_calls+=1;return super.remove(path)
func fresh_io(context: Dictionary) -> Faults:
 var prior:=super.fresh_io(context);var io:=TouchFault.new();io.files=prior.files.duplicate(true);return io
var touch_before := false
var starts := 0
var ends := 0
var activations: Array=[]
var routed: Array=[]
func started() -> void: starts+=1
func ended() -> void: ends+=1
func activated(title: String) -> void: activations.append(title)
func routed_event(event: InputEvent) -> void: routed.append(event.get_class())
func hold(count: int=3) -> void:
 for i in count: await process_frame
func contact(point: Vector2,pressed: bool,canceled: bool=false) -> void:
 var event:=InputEventScreenTouch.new();event.index=0;event.position=root.get_final_transform()*point;event.pressed=pressed;event.canceled=canceled
 Input.parse_input_event(event);Input.flush_buffered_events();events.append({"kind":"touch","position":str(event.position),"pressed":pressed,"canceled":canceled,"physics":Engine.get_physics_frames()});await physics_frame
func move_contact(point: Vector2,relative: Vector2) -> void:
 var event:=InputEventScreenDrag.new();event.index=0;event.position=root.get_final_transform()*point;event.relative=root.get_final_transform().basis_xform(relative);event.velocity=event.relative*60
 Input.parse_input_event(event);Input.flush_buffered_events();events.append({"kind":"drag","position":str(event.position),"relative":str(event.relative),"physics":Engine.get_physics_frames()});await physics_frame
func recovery_buttons() -> Array:
 return [scene.recovery_retry,scene.recovery_keep]+scene.recovery_exports.values()
func row_button(down: bool) -> Button:
 var area: Rect2=scene.recovery_scroll.get_global_rect();var found: Button
 for row in recovery_buttons():
  if row.is_visible_in_tree() and area.encloses(row.get_global_rect()):
   if found==null or (row.position.y<found.position.y if down else row.position.y>found.position.y):found=row
 return found
func swipe(delta: float,target: Button=null) -> void:
 if target==null:target=row_button(delta>0)
 check(target!=null,"swipe starts on an actual fully visible recovery button")
 if target==null:return
 var old_starts:=starts;var old_ends:=ends
 var point:=target.get_global_rect().get_center();await contact(point,true);var previous:=point
 for i in 24:
  var next:=point+Vector2(0,delta*(i+1)/24.0);await move_contact(next,next-previous);previous=next
 await contact(previous,false);await hold(2)
 for frame in 120:
  if starts==old_starts or ends>old_ends:break
  await process_frame
func wheel(down: bool) -> void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP;event.pressed=true;event.position=root.get_final_transform()*scene.recovery_scroll.get_global_rect().get_center()
 Input.parse_input_event(event);Input.flush_buffered_events();events.append({"kind":"wheel","down":down});await hold()
func reach(target: Button) -> void:
 for i in 10:
  if scene.recovery_scroll.get_global_rect().encloses(target.get_global_rect()):break
  await swipe(180 if target.get_global_rect().get_center().y<scene.recovery_scroll.get_global_rect().get_center().y else -180)
 check(scene.recovery_scroll.get_global_rect().encloses(target.get_global_rect()),"touch row drags reach "+target.text)
func pending_before(io: Faults) -> Dictionary:
 return {"whole":whole(),"files":io.files.duplicate(true),"writes":io.active_writes,"all_writes":io.write_calls,"renames":io.rename_calls,"removes":io.remove_calls,"unadmitted":io.markerless_writes,"record":scene.import_recovery.record.duplicate(true),"original":scene.import_recovery.original_code,"incoming":scene.import_recovery.incoming_code,"message":scene.import_recovery.message}
func same_pending(io: Faults,before: Dictionary) -> bool:
 return scene.import_pending and scene.paused and scene.recovery_layer.visible and whole()==before.whole and io.files==before.files and io.active_writes==before.writes and io.write_calls==before.all_writes and io.rename_calls==before.renames and io.remove_calls==before.removes and io.markerless_writes==before.unadmitted and scene.import_recovery.record==before.record and scene.import_recovery.original_code==before.original and scene.import_recovery.incoming_code==before.incoming and scene.import_recovery.message==before.message
func run_case(size: Vector2i,index: int,use_import: bool) -> void:
 root.size=size;var list:=full_contexts();var context: Dictionary=list[index];var io:=fresh_io(context);await open_owner(io)
 var initial:=whole();scene.transfer.text=code(list[(index+1)%3]);io.mode="active_after_store";await tap("IMPORT")
 check(scene.import_pending and scene.paused and whole()==initial,"actual uncertain Import freezes exact original "+context.name)
 # Initial witness setup only; every subsequent reach is through actual row touch events.
 scene.recovery_scroll.ensure_control_visible(scene.recovery_retry);await hold(4)
 starts=0;ends=0;activations=[];routed=[]
 scene.recovery_scroll.scroll_started.connect(started);scene.recovery_scroll.scroll_ended.connect(ended);scene.recovery_scroll.gui_input.connect(routed_event)
 for button in recovery_buttons():button.pressed.connect(activated.bind(button.text))
 var before:=pending_before(io);var top: int=scene.recovery_scroll.scroll_vertical
 await swipe(-220,scene.recovery_retry)
 var after: int=scene.recovery_scroll.scroll_vertical
 check(after>top and starts>0 and ends>0,"Retry button-body touchscreen swipe advances production scroller and ends")
 check(same_pending(io,before) and activations.is_empty(),"row swipe preserves every live field, parked ending, settings, raw candidate/archive and write counter")
 var wheel_before: int=scene.recovery_scroll.scroll_vertical;await wheel(wheel_before==0)
 check(scene.recovery_scroll.scroll_vertical!=wheel_before and same_pending(io,before),"real mouse wheel positive control preserves complete pending context")
 observations.append({"size":str(size),"source":context.name,"choice":use_import,"top":top,"after":after,"starts":starts,"ends":ends,"routed":routed.duplicate(),"before":before})
 if failures>0:return
 for i in 5:await swipe(180)
 check(scene.recovery_scroll.scroll_vertical==0 and same_pending(io,before),"reverse button-body touch returns top without choosing")
 var keep: Button=scene.recovery_keep;keep.disabled=true;var disabled_before:=activations.size()
 await contact(keep.get_global_rect().get_center(),true);await contact(keep.get_global_rect().get_center(),false);await hold()
 check(activations.size()==disabled_before and same_pending(io,before),"disabled recovery row cannot activate")
 var disabled_scroll: int=scene.recovery_scroll.scroll_vertical
 await swipe(-180,keep)
 check(scene.recovery_scroll.scroll_vertical>disabled_scroll and same_pending(io,before) and activations.is_empty(),"disabled row drag scrolls without choice or state write")
 keep.disabled=false
 for i in 5:await swipe(180)
 var point: Vector2=scene.recovery_retry.get_global_rect().get_center();await contact(point,true);await contact(point,false,true);await hold()
 check(activations.is_empty() and same_pending(io,before),"canceled Retry release never writes or activates")
 await contact(point,true);await move_contact(point+Vector2(0,65),Vector2(0,65));await move_contact(point,Vector2(0,-65));await contact(point,false);await hold(20)
 check(activations.is_empty() and same_pending(io,before),"drag returning inside Retry remains canceled")
 for imported in [false,true]:
  var name: String="COPY IMPORTED" if imported else "COPY PREVIOUS";var button: Button=scene.recovery_exports[name];await reach(button)
  var port:=fake("delay");scene.clipboard_backend=port;var count:=activations.size()
  await contact(button.get_global_rect().get_center(),true);await contact(button.get_global_rect().get_center(),false);await frames()
  check(activations.size()==count+1 and activations.back()==name and port.puts==1 and port.expected==(before.incoming if imported else before.original),"stationary Copy tap once exports exact retained code to fake port")
  check(port.gets>0 and port.gets<10 and scene.copy_confirm.outcome=="confirmed" and scene.recovery_copy_feedback.text.begins_with("Copied"),"existing bounded confirmation protocol retains exact fake readback")
  check(same_pending(io,before),"Copy and acknowledgment remain entirely read-only with original uncertainty")
  name="VIEW IMPORTED CODE" if imported else "VIEW PREVIOUS CODE";button=scene.recovery_exports[name];await reach(button);count=activations.size()
  await contact(button.get_global_rect().get_center(),true);await contact(button.get_global_rect().get_center(),false);await frames(4)
  check(activations.size()==count+1 and activations.back()==name and scene.recovery_code.visible and not scene.recovery_code.editable and scene.recovery_code.text==(before.incoming if imported else before.original) and scene.recovery_code.get_selected_text()==scene.recovery_code.text,"stationary View tap once exposes exact complete selectable read-only archive")
  check(same_pending(io,before),"View preserves all full contexts, archive bytes and pending uncertainty")
 var choice: Button=scene.recovery_retry if use_import else scene.recovery_keep;await reach(choice)
 var count:=activations.size();var label: String=choice.text;var expected:=S.decode(before.incoming if use_import else before.original)
 io.mode="";io.promoted="";await contact(choice.get_global_rect().get_center(),true);await contact(choice.get_global_rect().get_center(),false)
 if current_scene==null:await scene_changed
 if current_scene!=scene:scene=current_scene
 scene.set_physics_process(false);await hold(3)
 check(activations.size()==count+1 and activations.back()==label and not scene.import_pending and scene.paused and matches(whole(),expected),"stationary Keep/Retry once hands exact selected whole code to fresh paused owner")
 check(matches(S.read(S.PATH,io),expected) and not io.files.has(T.PATH) and not io.files.has(T.PATH+".tmp"),"selected complete Store context verified before marker cleanup")
 for path in before.files:
  if str(path).begins_with(Copies.PREFIX):check(io.files.get(path)==before.files[path],"explicit choice keeps exact immutable archive "+str(path))
 materialize(io);await reload_disk(expected,"touch choice "+context.name);scene.set_physics_process(false)
 check(matches(whole(),expected),"normal cold decoder preserves every selected projectile/profile/ending/settings field")
func run() -> void:
 check(ResourceUID.id_to_text(ResourceUID.text_to_id("uid://ed457ojjk"))=="uid://ed457ojjk","new test UID is canonical")
 touch_before=Input.emulate_touch_from_mouse;Input.emulate_touch_from_mouse=true
 check(DisplayServer.get_name()=="headless" and DisplayServer.is_touchscreen_available(),"synthetic headless touchscreen capability, not Android proof")
 for size in [Vector2i(720,1280),Vector2i(344,642),Vector2i(690,829),Vector2i(1066,600)]:
  for index in 3:
   for use_import in [false,true]:
    await run_case(size,index,use_import)
    if failures>0:await finish();return
 await finish()
func finish() -> void:
 Input.emulate_touch_from_mouse=touch_before;check(Input.emulate_touch_from_mouse==touch_before,"original touchscreen emulation restored")
 if is_instance_valid(scene):scene.free()
 await process_frame;await process_frame
 FileAccess.open(capture_dir.path_join("recovery-touch.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"events":events,"observations":observations,"scope":"Real Input.parse ScreenTouch/Drag GUI dispatch over production recovery rows, synthetic headless touchscreen capability restored; owning-rule complete legacy/campaign-projectile/arena-parked-ending fixtures and fault/fake clipboard. No OS clipboard/Android/render/earned route claim."}))
 print("HOOK_RECOVERY_TOUCH ",checks," / ",failures);print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL");quit(0 if failures==0 else 1)
