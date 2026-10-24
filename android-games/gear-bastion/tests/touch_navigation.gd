extends "res://tests/import_recovery.gd"
## Synthetic complete contexts and touchscreen capability; real production GUI dispatch.
var baseline := false
var starts := 0
var ends := 0
var activations: Array=[]
var gui_events: Array=[]
var old_emulation := false
func note_start() -> void: starts+=1
func note_end() -> void: ends+=1
func note_pressed(title: String) -> void: activations.append(title)
func note_gui(event: InputEvent) -> void: gui_events.append(event.get_class())
func contact(point: Vector2,pressed: bool,canceled: bool=false) -> void:
 var e:=InputEventScreenTouch.new();e.index=0;e.position=root.get_final_transform()*point;e.pressed=pressed;e.canceled=canceled
 Input.parse_input_event(e);Input.flush_buffered_events();events.append({"kind":"touch","point":str(e.position),"pressed":pressed,"canceled":canceled,"physics":Engine.get_physics_frames()});await physics_frame
func move_contact(point: Vector2,relative: Vector2) -> void:
 var e:=InputEventScreenDrag.new();e.index=0;e.position=root.get_final_transform()*point;e.relative=root.get_final_transform().basis_xform(relative);e.velocity=e.relative*60
 Input.parse_input_event(e);Input.flush_buffered_events();events.append({"kind":"drag","point":str(e.position),"relative":str(e.relative),"physics":Engine.get_physics_frames()});await physics_frame
func control_point(dialog: Window,control: Control) -> Vector2:
 return Vector2(dialog.position)+control.get_global_rect().get_center()
func visible_button(game: Node,down: bool) -> Button:
 var scroll: ScrollContainer=game.dialog_scrolls[game.save_dialog];var area:=scroll.get_global_rect()
 var found: Button
 for child in game.recovery_choices.get_children():
  if child is Button and child.is_visible_in_tree() and area.encloses(child.get_global_rect()):
   if found==null or (child.position.y>found.position.y if not down else child.position.y<found.position.y):found=child
 return found
func swipe(game: Node,delta: float) -> void:
 var target:=visible_button(game,delta>0);check(target!=null,"actual swipe begins on a fully visible production recovery button")
 if target==null:return
 var start:=control_point(game.save_dialog,target);await contact(start,true);var previous:=start
 for i in 20:
  var next:=start+Vector2(0,delta*(i+1)/20.0);await move_contact(next,next-previous);previous=next
 await contact(previous,false);await ticks(18)
func wheel(game: Node,down: bool) -> void:
 var scroll: ScrollContainer=game.dialog_scrolls[game.save_dialog]
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP;e.pressed=true;e.position=root.get_final_transform()*(Vector2(game.save_dialog.position)+scroll.get_global_rect().get_center())
 Input.parse_input_event(e);Input.flush_buffered_events();events.append({"kind":"wheel","down":down});await ticks(3)
func invariant(game: Node,io: JournalFault,before: Dictionary) -> bool:
 return game.recovery_pending and game.paused and game.save_dialog.visible and game.state==before.state and game.settings==before.settings and game.profile==before.profile and io.files==before.files and io.times==before.times and io.write_count==before.writes and io.rename_count==before.renames and game.recovery.record==before.record and game.recovery.original_code==before.original and game.recovery.incoming_code==before.incoming
func run_case(size: Vector2i,kind: int,use_import: bool) -> void:
 root.size=size;var source:=fixture(kind);var target:=fixture(2 if kind==0 else 0,90);var io:=JournalFault.new();io.files[Store.PATH]=source
 var game:=await boot(io)
 await tap(game.get_global_transform_with_canvas()*game.buttons().save.get_center(),"Save")
 game.save_text.text=target;io.unreadable_destination_suffix="bastion-save.json";io.unreadable_after=1
 await dialog_button(game,"Import");check(game.recovery_pending and game.paused and same(live(game),Store.decode(source)),"real uncertain Import preserves complete original context")
 var scroll: ScrollContainer=game.dialog_scrolls[game.save_dialog]
 # Position only the initial witness; every subsequent reach/reverse uses input, never scroll assignment.
 scroll.ensure_control_visible(game.recovery_buttons.retry);await ticks(4)
 starts=0;ends=0;activations=[];gui_events=[]
 scroll.scroll_started.connect(note_start);scroll.scroll_ended.connect(note_end);scroll.gui_input.connect(note_gui)
 for child in game.recovery_choices.get_children():
  if child is Button:child.pressed.connect(note_pressed.bind(child.text))
 var before:={"state":game.state.duplicate(true),"settings":game.settings.duplicate(true),"profile":game.profile.duplicate(true),"files":io.files.duplicate(true),"times":io.times.duplicate(true),"writes":io.write_count,"renames":io.rename_count,"record":game.recovery.record.duplicate(true),"original":game.recovery.original_code,"incoming":game.recovery.incoming_code}
 var top: int=scroll.scroll_vertical;await swipe(game,-180)
 var moved: int=scroll.scroll_vertical
 check(moved>top and starts>0 and ends>0,"actual recovery button-body drag scrolls and ends")
 check(invariant(game,io,before) and activations.is_empty(),"drag preserves exact whole live context, every raw file/code and write counters")
 var wheel_before: int=scroll.scroll_vertical;await wheel(game,wheel_before==0)
 check(scroll.scroll_vertical!=wheel_before and invariant(game,io,before),"real wheel positive control preserves complete pending context")
 observations.append({"size":str(size),"kind":kind,"choice":use_import,"top":top,"after_swipe":moved,"starts":starts,"ends":ends,"gui":gui_events.duplicate(),"whole_before":live(game),"original_code":before.original,"incoming_code":before.incoming,"raw_files":before.files})
 if not baseline:
  for i in 3:await swipe(game,180)
  check(scroll.scroll_vertical==0 and invariant(game,io,before),"reverse button-body swipes reach top without changing whole save")
  var button: Button=game.recovery_buttons.retry;var point:=control_point(game.save_dialog,button)
  await contact(point,true);await contact(point,false,true);await ticks(3)
  check(invariant(game,io,before) and activations.is_empty(),"canceled Retry contact never admits a write or selection")
  await contact(point,true);await move_contact(point+Vector2(0,65),Vector2(0,65));await move_contact(point,Vector2(0,-65));await contact(point,false);await ticks(20)
  check(invariant(game,io,before) and activations.is_empty(),"drag returning inside Retry still cancels activation")
  for i in 3:await swipe(game,-180)
  var last: Button=game.recovery_buttons.view_incoming
  check(scroll.get_global_rect().encloses(last.get_global_rect()),"actual row-body swipes reach last View action")
  await contact(control_point(game.save_dialog,last),true);await contact(control_point(game.save_dialog,last),false);await ticks(3)
  check(game.save_text.text==before.incoming and not game.save_text.editable and activations==["View imported code"],"stationary last-row tap activates exact complete View once")
  check(invariant(game,io,before),"View remains read-only over complete context and every archive")
  for i in 4:await swipe(game,180)
  var choice: Button=game.recovery_buttons.retry if use_import else game.recovery_buttons.previous
  check(scroll.get_global_rect().encloses(choice.get_global_rect()),"reverse swipe reaches requested explicit choice")
  reset_fault(io);await contact(control_point(game.save_dialog,choice),true);await contact(control_point(game.save_dialog,choice),false);await ticks(4)
  var wanted:=Store.decode(target if use_import else before.original)
  check(activations==["View imported code",choice.text] and not game.recovery_pending and game.paused and same(live(game),wanted),"stationary choice selects exactly once with exact whole context paused")
  check(same(Store.read(Store.PATH,io),wanted),"owning Store verifies selected complete context")
  for path in before.files:
   if str(path).begins_with(Copies.PREFIX):check(io.files.get(path)==before.files[path],"explicit choice preserves exact immutable raw archive "+str(path))
  game.queue_free();await ticks(3);var fresh:=await boot(io)
  check(not fresh.recovery_pending and same(live(fresh),wanted),"fresh production owner preserves exact complete selected context")
  fresh.queue_free();await ticks(3)
 else:game.queue_free();await ticks(3)
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg=="--baseline":baseline=true
 old_emulation=Input.emulate_touch_from_mouse;Input.emulate_touch_from_mouse=true
 check(DisplayServer.get_name()=="headless" and DisplayServer.is_touchscreen_available(),"synthetic headless touchscreen capability; not native proof")
 check(ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"all physical data is isolated")
 var sizes:=[Vector2i(600,1066),Vector2i(720,1680),Vector2i(1153,1280),Vector2i(2276,1280)]
 for size in sizes:
  for kind in [0,2]:
   for use_import in [false,true]:
    await run_case(size,kind,use_import)
    if baseline:break
   if baseline:break
  if baseline:break
 Input.emulate_touch_from_mouse=old_emulation;check(Input.emulate_touch_from_mouse==old_emulation,"original touch-emulation capability restored")
 FileAccess.open(folder.path_join("touch-navigation.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"events":events,"scope":"Synthetic complete owning-decoder fixture and storage fault; real Input.parse ScreenTouch/Drag GUI dispatch, restored headless touchscreen capability. No Android/render/OS clipboard/earned progression claim."}))
 print("GEAR_TOUCH ",checks," / ",failures);print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL");quit(0 if failures.is_empty() else 1)
