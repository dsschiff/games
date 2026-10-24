extends SceneTree
const S = preload("res://scripts/save_store.gd")
const T = preload("res://scripts/import_recovery.gd")
const C = preload("res://scripts/campaign_rules.gd")
const R = preload("res://scripts/rules.gd")
const D = preload("res://scripts/definitions.gd")
var checks := 0
var failures: Array[String] = []
var folder := ""
var events: Array[Dictionary] = []
var cases: Array[Dictionary] = []
class Fault extends RefCounted:
	var files := {}
	var mode := ""
	var promoted := ""
	var reads := 0
	var active_writes := 0
	var once_path := ""
	var once_reads := 0
	func exists(path: String) -> bool: return files.has(path)
	func read_text(path: String) -> String:
		if mode=="once" and path==once_path:
			once_reads+=1
			if once_reads>1: return "unreadable"
		if mode=="journal_stage_read" and path==T.PATH+".tmp": return "unreadable"
		if path==promoted and mode in ["active_second_read","active_after_store"]:
			reads += 1
			if reads >= (2 if mode=="active_second_read" else 3): return "unreadable"
		return str(files.get(path,""))
	func write_text(path: String,text: String) -> bool:
		if path.begins_with(S.PATH): active_writes += 1
		if mode=="archive_write" and path.begins_with("user://frontline-cloud-copy-"): return false
		files[path] = text
		return true
	func rename(from: String,to: String) -> bool:
		var phase := "active" if to.begins_with(S.PATH) else ("journal" if to==T.PATH else "archive")
		if mode==phase+"_rename": return false
		if mode==phase+"_missing": files.erase(from); return true
		if mode==phase+"_corrupt": files[to]="torn"; files.erase(from); return true
		if mode=="active_stale" and phase=="active": files.erase(from); return true
		files[to] = files[from]; files.erase(from)
		if phase=="active": promoted=to; reads=0
		return true
	func remove(path: String) -> bool:
		if mode=="clear_failure": return false
		if mode=="clear_lie": return true
		files.erase(path); return true
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): folder=arg.trim_prefix("--report-dir=")
	call_deferred("run")
func check(okay: bool,label: String) -> void:
	checks+=1
	if not okay: failures.append(label); print("FAIL ",label)
func fixture(kind: int) -> String:
	var p := R.profile(); p.attempts=5; p.wins=2; p.best_kills=9
	var c := C.career(); c.attempts=3; c.victories=1
	c.clears[D.IDS[0]]=2; c.records[D.IDS[0]]={"medal":2,"seconds":30.5,"kills":4,"spent":18,"seed":0,"style":"authored"}
	c.legacy_state=R.fresh(); c.legacy_profile=p.duplicate(true)
	c.skirmishes["17:mixed"]={"medal":1,"seconds":40.5,"kills":2,"spent":10,"seed":17,"style":"mixed"}
	var s: Dictionary = R.fresh() if kind in [0,3] else C.fresh(D.mission(0))
	if kind in [2,3]: s.phase="playing"
	if kind==4:
		s.phase="playing"
		for frame in 10000:
			C.tick(s,Vector2.ZERO,.05)
			if s.phase in ["victory","defeat"]: C.finish(s,c); break
	return S.encode(s,p,{"sound":kind%2==0,"reduced_effects":kind%2==1,"note":"whole context "+str(kind)},900,true,c)
func ticks(count: int=2) -> void:
	for frame in count: await process_frame
func boot(io: RefCounted=null) -> Node:
	var app: Node = load("res://boot.tscn").instantiate()
	app.save_io=io; root.add_child(app); current_scene=app; await ticks()
	return app
func stop(app: Node) -> void:
	app.queue_free(); await ticks()
func touch(scene: Node,text: String) -> void:
	var found: Button
	for b in scene.find_children("*","Button",true,false):
		if b.text==text and b.is_visible_in_tree(): found=b; break
	if found==null or found.disabled: check(false,"actual visible enabled control "+text); return
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new(); event.index=0; event.position=root.get_final_transform()*found.get_global_rect().get_center(); event.pressed=pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
		events.append({"target":text,"pressed":pressed,"position":[event.position.x,event.position.y]})
		await ticks(1)
func live(scene: Node) -> Dictionary:
	return S.decode(S.encode(scene.state,scene.profile,scene.settings,0,true,scene.current_career()))
func assert_frozen(scene: Node,io: Fault,before: Dictionary) -> void:
	var writes := io.active_writes
	scene.begin(); scene.retry(); scene.toggle_pause(); scene.toggle_sound(); scene.toggle_effects(); scene.enter_campaign(); scene.close_transfer(); scene.back()
	scene.save_now(); scene.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(scene.import_pending and scene.paused and T.same_values(live(scene),before),"pending keeps full live context and all mode/settings/continuation paths frozen")
	check(io.active_writes==writes,"pending blocks autosaves and lifecycle writes")
func materialize(io: Fault) -> void:
	var user := ProjectSettings.globalize_path("user://")
	check(user.replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"physical save proof stays inside isolated artifact data")
	for file in DirAccess.get_files_at(user):
		if file.begins_with("frontline-save-") or file.begins_with("frontline-import-pending") or file.begins_with("frontline-cloud-copy-"):
			DirAccess.remove_absolute(user.path_join(file))
	for path in io.files:
		var output := FileAccess.open(path,FileAccess.WRITE); output.store_string(io.files[path]); output.close()
func raw_slots() -> Dictionary:
	var result := {}
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var path := S.PATH+str(slot)+str(suffix)
			if FileAccess.file_exists(path): result[path]=FileAccess.get_file_as_string(path)
	return result
func run() -> void:
	root.size=Vector2i(720,1280)
	var own_user := ProjectSettings.globalize_path("user://").replace("\\","/").to_lower()
	if not own_user.begins_with(folder.replace("\\","/").to_lower()):
		check(false,"Refusing physical bootstrap outside isolated artifact runtime data")
		quit(1); return
	for a in 5: check(S.decode(fixture(a)).ok,"synthetic full-context fixture valid")
	for original_kind in [0,1,2,3]:
		for target_kind in [0,1,2,3]:
			for use_import in [true,false]:
				print("CASE ",original_kind," -> ",target_kind," import=",use_import)
				var io := Fault.new(); io.files[S.PATH+"0"]=fixture(original_kind)
				var app: Node = await boot(io); var scene: Node=app.session
				if not scene.paused: await touch(scene,"II")
				await touch(scene,"SAVE / TRANSFER")
				var before := live(scene); var code := fixture(target_kind)
				scene.code_edit.text=code # Explicit synthetic code entry; actual Import/choice buttons below.
				io.mode="active_second_read"
				await touch(scene,"IMPORT")
				check(scene.import_pending and scene.transfer.visible,"transient post-rename false becomes visible pending recovery")
				assert_frozen(scene,io,before)
				var local_id: String=scene.import_recovery.record.original
				var remote_id: String=scene.import_recovery.record.incoming
				check(T.same_values(S.decode(scene.import_recovery.copies.get_code(local_id).text),before) and scene.import_recovery.copies.get_code(remote_id).text==code,"both entire contexts preserved before active write")
				await stop(app); io.mode=""; materialize(io)
				var physical_before:=raw_slots(); app=await boot(); scene=app.session
				check(scene.import_pending and scene.paused and T.same_values(live(scene),before),"fresh production bootstrap loads original catalog/full context paused despite higher imported slot")
				check(raw_slots()==physical_before,"fresh pending bootstrap does not autosave selected/default/old context")
				for dimensions in [Vector2i(720,1680),Vector2i(1153,1280),Vector2i(2276,1280)]:
					root.size=dimensions; await ticks()
					check(scene.transfer.get_global_rect().encloses(scene.notice.get_global_rect()),"pending recovery text bounds stay inside panel")
					check(scene.notice.get_minimum_size().y<=scene.notice.size.y+1,"pending recovery label text fits its allocated height")
					for b in scene.transfer_buttons:
						if b.visible: check(scene.transfer.get_global_rect().encloses(b.get_global_rect()),"recovery choice bounds stay inside panel")
				root.size=Vector2i(720,1280); await ticks()
				await touch(scene,"RETRY IMPORT" if use_import else "KEEP PREVIOUS")
				await ticks(4)
				# Cross-catalog changes replace the root scene; normal Godot scene changes require current_scene.
				var expected := S.decode(code) if use_import else before
				check(T.same_values(S.read(),expected),"explicit retry/rollback verified whole disk meaning")
				check(current_scene!=null and current_scene.session.paused and not current_scene.session.import_pending and T.same_values(live(current_scene.session),expected),"resolved live owner immediately adopts exact full context paused before destruction")
				check(not T.new().read().pending,"journal cleared only after verified choice")
				if is_instance_valid(app): await stop(app)
				if current_scene!=null and is_instance_valid(current_scene): await stop(current_scene)
				app=await boot(); scene=app.session
				check(not scene.import_pending and T.same_values(live(scene),expected),"settled cold bootstrap restores exact chosen full context")
				await stop(app)
				cases.append({"original":original_kind,"incoming":target_kind,"choice":"import" if use_import else "previous","scope":"synthetic complete contexts; real engine touch; materialized-file fresh production bootstrap, not OS kill/native"})
	for mode in ["journal_ready","archive_write","journal_rename","journal_missing","journal_corrupt","journal_stage_read","active_rename","active_missing","active_corrupt","active_stale","active_after_store","clear_failure","clear_lie"]:
		var io := Fault.new(); io.files[S.PATH+"0"]=fixture(1)
		var helper := T.new(io); var old := fixture(1); var incoming := fixture(0)
		io.mode=mode; var started:=helper.begin(old,incoming)
		var result: Dictionary={"ok":false}
		if started.pending and started.ok and mode!="journal_ready": result=helper.resolve(true)
		check(not result.ok,"fault cannot claim completed import: "+mode)
		check(io.files[S.PATH+"0"]==old,"fault retains newest original raw slot: "+mode)
		if mode.begins_with("journal_"): check(io.active_writes==0,"journal promotion/stage fault prevents active write: "+mode)
		io.mode=""; materialize(io)
		var marker_present: bool=FileAccess.file_exists(T.PATH) or FileAccess.file_exists(T.PATH+".tmp")
		var slots_before:=raw_slots()
		var cold: Node=await boot()
		check(cold.session.import_pending==marker_present and T.same_values(live(cold.session),S.decode(old)),"fault-boundary fresh bootstrap retains whole original context: "+mode)
		if marker_present: check(cold.session.paused and raw_slots()==slots_before,"pending fault-boundary bootstrap cannot autosave: "+mode)
		await stop(cold)
		if mode=="archive_write": check(not started.pending,"preservation failure happens before transaction")
		else:
			check(not helper.record.is_empty(),"complete identities retained for explicit retry: "+mode)
			io.mode=""
			check(helper.resolve(false).ok and T.same_values(S.read(S.PATH,io),S.decode(old)),"verified rollback recovers from fault: "+mode)
			check(not T.new(io).read().pending,"rollback settles marker: "+mode)
	# Preserve unsaved live settings separately from older raw disk context.
	var unsaved_io:=Fault.new(); unsaved_io.files[S.PATH+"0"]=fixture(1)
	var unsaved_app: Node=await boot(unsaved_io); var unsaved_scene: Node=unsaved_app.session
	await touch(unsaved_scene,"II")
	unsaved_io.mode="active_missing"; await touch(unsaved_scene,"SOUND  OFF")
	var unsaved_context:=live(unsaved_scene)
	check(unsaved_context.settings.sound!=S.read(S.PATH,unsaved_io).settings.sound,"synthetic storage fault leaves actual toggled setting unsaved")
	unsaved_io.mode=""; await touch(unsaved_scene,"SAVE / TRANSFER")
	unsaved_scene.code_edit.text=fixture(0); unsaved_io.mode="active_second_read"
	await touch(unsaved_scene,"IMPORT")
	check(unsaved_scene.import_pending and T.same_values(live(unsaved_scene),unsaved_context),"pending import keeps complete unsaved live context")
	await stop(unsaved_app); unsaved_io.mode=""; materialize(unsaved_io)
	unsaved_app=await boot(); unsaved_scene=unsaved_app.session
	check(T.same_values(live(unsaved_scene),unsaved_context) and unsaved_scene.paused,"fresh pending bootstrap recovers unsaved full live context rather than prior raw settings")
	await touch(unsaved_scene,"KEEP PREVIOUS"); await ticks(4)
	check(current_scene.session.paused and T.same_values(live(current_scene.session),unsaved_context) and T.same_values(S.read(),unsaved_context),"explicit rollback durably restores unsaved full context and adopts paused")
	await stop(current_scene)
	# Retained helper models a failed scene handoff after a successful choice.
	var reused_io:=Fault.new(); reused_io.files[S.PATH+"0"]=fixture(1)
	var reused:=T.new(reused_io); reused.begin(fixture(1),fixture(0))
	check(reused.resolve(true).ok,"first resolved choice verified before simulated failed handoff")
	check(not reused.journal_ready,"successful cleanup invalidates journal admission for a retained owner")
	reused_io.mode="active_second_read"
	check(not reused.resolve(true).ok,"retained owner second choice can become uncertain")
	reused_io.mode=""; materialize(reused_io)
	check(T.new().read().pending,"second write after failed handoff re-establishes durable pending journal")
	var reused_app: Node=await boot()
	check(reused_app.session.import_pending and reused_app.session.paused and T.same_values(live(reused_app.session),S.decode(fixture(1))),"second uncertain choice fresh bootstrap stays on full original context paused")
	await stop(reused_app)
	for once_kind in ["journal","original_archive"]:
		for original_kind in [0,1]:
			var io := Fault.new(); io.files[S.PATH+"0"]=fixture(original_kind)
			var helper := T.new(io); helper.begin(fixture(original_kind),fixture(1-original_kind))
			io.mode="active_second_read"; helper.resolve(true)
			io.mode="once"; io.once_path=T.PATH if once_kind=="journal" else "user://frontline-cloud-copy-"+helper.record.original
			var writes:=io.active_writes
			var app: Node=await boot(io)
			check(app.session.import_pending and app.session.paused and T.same_values(live(app.session),S.decode(fixture(original_kind))),"single validated startup decision survives later unreadable "+once_kind)
			check(io.once_reads==1 and io.active_writes==writes,"Session does not independently reread bootstrap recovery source")
			await stop(app)
	set_meta("frontline_import_context",{"state":{}})
	var invalid_handoff: Node=await boot()
	check(invalid_handoff.session==null and not has_meta("frontline_import_context"),"invalid one-shot handoff rejected/consumed without default bootstrap")
	await stop(invalid_handoff)
	var terminal_files:=Fault.new(); terminal_files.files[S.PATH+"0"]=fixture(4); materialize(terminal_files)
	var terminal:=S.read()
	set_meta("frontline_import_context",terminal.duplicate(true))
	var terminal_app: Node=await boot()
	check(terminal_app.session.paused and not terminal_app.session.import_pending and T.same_values(live(terminal_app.session),terminal),"verified terminal handoff adopts entire context paused before any continuation")
	await stop(terminal_app)
	var corrupt := Fault.new(); corrupt.files[T.PATH]="torn"; corrupt.files[S.PATH+"0"]=fixture(0)
	var blocked: Node=await boot(corrupt)
	check(blocked.session.import_pending and blocked.session.paused and corrupt.active_writes==0,"unreadable marker cannot silently resume/autosave")
	await stop(blocked)
	var missing := Fault.new(); missing.files[T.PATH]="torn"
	blocked=await boot(missing)
	check(blocked.session==null and missing.active_writes==0,"unreadable marker with no safe context never bootstraps default game")
	await stop(blocked)
	var output:=FileAccess.open(folder.path_join("import-recovery.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"raw_inputs":events,"scope":"CPU/headless/Dummy; synthetic full contexts and explicit fault backend; real ScreenTouch; process-style bootstrap from materialized files, no OS-kill/native/render acceptance"},"  ")); output.close()
	print("IMPORT_RECOVERY ",checks," checks / ",failures.size()," failures")
	await ticks(3); quit(0 if failures.is_empty() else 1)
