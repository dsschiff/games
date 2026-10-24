extends SceneTree
const Flow = preload("res://scripts/cloud/game_flow.gd")
const Port = preload("res://scripts/cloud/port.gd")
const Native = preload("res://scripts/cloud/native_port.gd")
const Backup = preload("res://scripts/cloud/backup.gd")
const Store = preload("res://scripts/save_store.gd")
const Journal = preload("res://scripts/import_recovery.gd")
const Copies = preload("res://scripts/cloud/copies.gd")
const C = preload("res://scripts/campaign_rules.gd")
const R = preload("res://scripts/rules.gd")
const D = preload("res://scripts/definitions.gd")
var checks := 0
var failures: Array[String] = []
var events: Array[Dictionary] = []
var folder := ""
class Memory extends RefCounted:
	var files := {}
	var mode := ""
	var promoted := ""
	var reads := 0
	var writes := 0
	var read_count := 0
	func exists(path: String) -> bool: return files.has(path)
	func read_text(path: String) -> String:
		read_count+=1
		if path==promoted and mode=="second_read":
			reads+=1
			if reads>=2: return "unreadable"
		return str(files.get(path,""))
	func write_text(path: String,text: String) -> bool:
		if mode=="archive_failure" and path.begins_with(Copies.PREFIX): return false
		files[path]=text; writes+=1; return true
	func rename(a: String,b: String) -> bool:
		files[b]=files[a]; files.erase(a)
		if b.begins_with(Store.PATH): promoted=b; reads=0
		return true
	func remove(path: String) -> bool: files.erase(path); return true
	func list_paths(prefix: String) -> Array[String]:
		var result: Array[String]=[]
		for path in files:
			if path.begins_with(prefix): result.append(path)
		return result
class FakePort extends Port:
	var calls: Array[Dictionary] = []
	var configured := true
	var cleanups := 0
	var auto_cleanup := true
	func is_configured() -> bool: return configured
	func request(id: String,op: String,args: Dictionary) -> void: calls.append({"id":id,"op":op,"args":args.duplicate(true)})
	func reply(body: Dictionary) -> void: completed.emit(calls.back().id,body)
	func abandon() -> void:
		cleanups+=1
		if auto_cleanup: completed.emit("@abandoned",{"status":"cancelled"})
	func ack(okay: bool=true) -> void: completed.emit("@abandoned",{"status":"cancelled" if okay else "close_failed"})
class Binding extends RefCounted:
	signal completed(id: String,body: String)
	var calls: Array[Dictionary] = []
	var ready := true
	func is_configured() -> bool: return ready
	func request(id: String,op: String,args: String) -> void: calls.append({"id":id,"op":op,"args":JSON.parse_string(args)})
	func cancel(id: String) -> void: calls.append({"id":id,"op":"cancel"})
class OldBinding extends RefCounted:
	signal completed(id: String,body: String)
	var calls := 0
	func is_configured() -> bool: return true
	func request(_id: String,_op: String,_args: String) -> void: calls+=1
class SyncPort extends FakePort:
	var remote_packet := {}
	func request(id: String,op: String,args: Dictionary) -> void:
		super.request(id,op,args)
		completed.emit(id,{"status":"authenticated"} if op=="sign_in" else ({"status":"authenticated","player":"a"} if op=="status" else {"status":"loaded","player":"a","snapshot":remote_packet}))
class Owner extends RefCounted:
	var text := ""
	var restores: Array[String] = []
	func capture() -> String: return text
	func restore(code: String) -> bool: restores.append(code); return true
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): folder=arg.trim_prefix("--report-dir=")
	call_deferred("run")
func check(okay: bool,label: String) -> void:
	checks+=1
	if not okay: failures.append(label); print("FAIL ",label)
func fixture(kind: int) -> String:
	var state: Dictionary = R.fresh() if kind==0 else C.fresh(D.mission(0))
	var career := C.career(); career.attempts=5; career.victories=2; career.legacy_state=R.fresh(); career.legacy_profile=R.profile()
	if kind==2: state.phase="playing"
	return Store.encode(state,R.profile(),{"sound":false,"reduced_effects":kind==0,"note":"whole context"},900-kind,true,career)
func packet(text: String) -> Dictionary:
	var wrapped := Backup.encode(text)
	if not wrapped.ok: check(false,"synthetic fixture must pass owning decoder"); return {}
	return {"data":Marshalls.raw_to_base64(wrapped.text.to_utf8_buffer()),"sha256":wrapped.text.sha256_text()}
func make_case() -> Dictionary:
	var io:=Memory.new(); var owner:=Owner.new(); owner.text=fixture(1); io.files[Store.PATH+"0"]=owner.text
	var port:=FakePort.new(); var flow:=Flow.new(); flow.setup(owner.capture,io,port,owner.restore); flow.open()
	return {"io":io,"owner":owner,"port":port,"flow":flow}
func connect_case(ctx: Dictionary) -> void:
	ctx.flow.connect_account(); ctx.port.reply({"status":"authenticated"}); ctx.port.reply({"status":"authenticated","player":"a"})
	check(ctx.flow.phase=="ready","explicit auth and status produce ready")
func remote(ctx: Dictionary,conflict: bool=false) -> void:
	ctx.flow.check_cloud()
	ctx.port.reply({"status":"conflict","player":"a","conflict":"c1","first":packet(fixture(0)),"second":packet(fixture(2))} if conflict else {"status":"loaded","player":"a","snapshot":packet(fixture(2))})
	check(ctx.flow.phase=="choose","validated remote choices")
func ticks(count: int=2) -> void:
	for i in count: await process_frame
func touch(scene: Node,title: String) -> void:
	var target: Button
	for b in scene.find_children("*","Button",true,false):
		if b.text==title and b.is_visible_in_tree(): target=b; break
	if target==null or target.disabled: check(false,"visible enabled input: "+title); return
	var ancestor: Node=target.get_parent()
	while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
	if ancestor is ScrollContainer: ancestor.ensure_control_visible(target); await ticks()
	for pressed in [true,false]:
		var e:=InputEventScreenTouch.new(); e.index=0; e.position=root.get_final_transform()*target.get_global_rect().get_center(); e.pressed=pressed
		Input.parse_input_event(e); Input.flush_buffered_events(); events.append({"title":title,"pressed":pressed}); await ticks(1)
func boot(io: RefCounted) -> Node:
	var app: Node=load("res://boot.tscn").instantiate(); app.save_io=io; root.add_child(app); current_scene=app; await ticks(); return app
func run() -> void:
	root.size=Vector2i(720,1280)
	check(ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"isolated runtime only")
	if not failures.is_empty(): quit(1); return
	var binding:=Binding.new(); var native:=Native.new(binding); var replies: Array=[]; native.completed.connect(func(id,body): replies.append({"id":id,"body":body}))
	check(native.is_configured() and binding.calls.is_empty(),"pure readiness makes zero SDK requests")
	native.request("read1","read",{"slot":Flow.SLOT,"player":"a"}); check(binding.calls.back().args.player=="a","actual singleton JSON adapter")
	native.abandon(); var cleanup_id: String=binding.calls.back().id
	binding.completed.emit("read1",JSON.stringify({"status":"conflict","player":"a"})); check(replies.is_empty(),"late result suppressed while cleanup owns resources")
	var rival:=Native.new(binding); check(not rival.is_configured(),"cleanup owner retained across modal lifetime")
	binding.completed.emit(cleanup_id,JSON.stringify({"status":"close_failed"})); check(replies.back().body.status=="close_failed" and not rival.is_configured(),"failed cleanup retains owner")
	native.abandon(); binding.completed.emit(binding.calls.back().id,JSON.stringify({"status":"cancelled"})); check(rival.is_configured(),"acknowledged cleanup releases owner")
	binding.ready=false; var before:=binding.calls.size(); rival.request("unconfigured","sign_in",{}); rival.abandon(); check(binding.calls.size()==before,"unconfigured does not request SDK/auth/cleanup")
	for conflict in [false,true]:
		for action in ["restore","backup","resolve"]:
			if action=="backup" and conflict or action=="resolve" and not conflict: continue
			var ctx:=make_case(); connect_case(ctx); remote(ctx,conflict); var raw: Dictionary=ctx.io.files.duplicate(true)
			if action=="restore": ctx.flow.stage_restore(1 if conflict else 0)
			elif action=="backup": ctx.flow.stage_backup()
			else: ctx.flow.stage_resolve(1)
			check(ctx.flow.phase=="confirm" and ctx.port.calls.back().op=="read","selection has no destructive request")
			ctx.flow.confirm(); check(ctx.port.calls.back().op=="status","confirmation revalidates account")
			check(ctx.flow.preserved_ids.size()>=2,"verify local and remote whole copies first")
			ctx.port.reply({"status":"authenticated","player":"a"})
			if action=="restore":
				check(ctx.port.calls.back().op=="status" and ctx.owner.restores.is_empty(),"cleanup followed by final account observation before local handoff")
				ctx.port.reply({"status":"authenticated","player":"a"})
				check(ctx.owner.restores==[fixture(2)] and ctx.port.cleanups==1,"restore hands exact code only to journal owner after cleanup")
			elif action=="backup":
				check(ctx.port.calls.back().op=="write" and ctx.port.calls.back().args.expected_sha256==packet(fixture(2)).sha256,"overwrite expectedhash bound to shown record")
				ctx.port.reply({"status":"submitted","player":"a","sha256":packet(ctx.owner.text).sha256}); check(ctx.flow.phase=="submitted" and ctx.flow.message.contains("cached offline"),"submitted is not server sync")
			else:
				check(ctx.port.calls.back().op=="resolve" and ctx.port.calls.back().args.choice==1,"only explicit existing conflict index")
				ctx.port.reply({"status":"conflict","player":"a","conflict":"c2","first":packet(fixture(1)),"second":packet(fixture(0))}); check(ctx.flow.phase=="choose" and ctx.flow._conflict=="c2","repeated conflict needs fresh explicit choice")
			for path in raw: check(ctx.io.files[path]==raw[path],"no cloud operation writes active local slots")
			for id in ctx.flow.preserved_ids: check(ctx.flow.copies.get_code(id).ok,"whole archived context retrievable")
			ctx.flow.dispose()
	for fault in ["live_change","disk_change","account_change","archive_failure"]:
		var ctx:=make_case(); connect_case(ctx); remote(ctx); ctx.flow.stage_backup()
		if fault=="live_change": ctx.owner.text=fixture(0)
		if fault=="disk_change": ctx.io.files[Store.PATH+"0"]=fixture(0)
		if fault=="archive_failure": ctx.io.mode="archive_failure"
		ctx.flow.confirm()
		if fault=="account_change": ctx.port.reply({"status":"authenticated","player":"b"})
		check(ctx.flow.phase=="error" and ctx.port.calls.back().op!="write","unsafe backup rejected: "+fault); ctx.flow.dispose()
	var ctx:=make_case(); connect_case(ctx); ctx.flow.stage_backup(); ctx.flow.confirm(); ctx.port.reply({"status":"authenticated","player":"a"})
	check(ctx.port.calls.back().args.expected_sha256=="","first backup only creates empty slot")
	ctx.port.reply({"status":"remote_changed","player":"a","remote":packet(fixture(0))}); check(ctx.flow.phase=="choose" and ctx.owner.restores.is_empty(),"existing remote forces comparison")
	ctx.flow.stage_backup(); ctx.flow.confirm(); ctx.port.reply({"status":"authenticated","player":"a"}); check(ctx.port.calls.back().args.expected_sha256==packet(fixture(0)).sha256,"second confirmation targets exact record")
	ctx.flow.cancel(); check(ctx.flow.phase=="closed" and ctx.flow.remote_effect=="unknown","Close releases local play without claiming remote undo"); ctx.port.reply({"status":"write_failed"}); check(ctx.flow.message.contains("may still finish"),"late backup callback cannot change closed local flow"); ctx.flow.dispose()
	ctx=make_case(); connect_case(ctx); ctx.port.auto_cleanup=false; ctx.flow.check_cloud(); ctx.flow.cancel(); check(ctx.flow.phase=="closed","read dismissal immediately releases local owner"); ctx.port.ack(false); check(ctx.flow.phase=="closed","late failed cleanup cannot refreeze local play"); ctx.port.ack(); check(ctx.flow.phase=="closed","late cleanup ack cannot reopen a dismissed flow"); ctx.flow.dispose()
	for kind in [0,1,2]:
		var io:=Memory.new(); io.files[Store.PATH+"0"]=fixture(kind)
		var app:=await boot(io); var scene: Node=app.session; var fake:=FakePort.new(); fake.configured=false; scene.cloud_transport=fake
		scene.open_transfer(); await ticks(); await touch(scene,"OPTIONAL CLOUD / LOCAL COPIES")
		check(scene.cloud_held and scene.paused and fake.calls.is_empty(),"actual unavailable entry has no auth/network")
		var live: String=scene.cloud_capture(); var writes: int=io.writes
		scene.begin(); scene.retry(); scene.toggle_sound(); scene.toggle_effects(); scene.enter_campaign(); scene.save_now(); scene.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(scene.cloud_panel.visible and not scene.menu.visible,"focus-out keeps cloud/cleanup controls unobscured")
		check(scene.cloud_capture()==live and io.writes==writes and scene.cloud_held,"full actual context/lifecycle freeze")
		var kept:=Copies.new(io).keep(fixture((kind+1)%3)); await touch(scene,"LOCAL RECOVERY COPIES"); await touch(scene,"VIEW COPY 1 / "+kept.id.substr(0,12))
		check(scene.cloud_panel.viewing==fixture((kind+1)%3),"offline retrieval/export exact whole code")
		await touch(scene,"USE THIS COPY LOCALLY"); check(scene.cloud_flow.phase=="confirm","archive restore needs confirmation")
		io.promoted=""; io.mode="second_read"; await touch(scene,"CONFIRM LOCAL IMPORT")
		check(scene.import_pending and scene.paused and not scene.cloud_held and Journal.new(io).read().pending,"durable Import owns freeze after uncertain write")
		check(Journal.same_values(Store.decode(scene.cloud_capture()),Store.decode(live)),"old whole live context retained")
		check(not scene.code_edit.visible and scene.notice.text.contains("PREVIOUS WHOLE SAVE") and scene.notice.text.contains("IMPORTED WHOLE SAVE"),"pending decisions prioritize summaries over raw JSON")
		var request_count: int=fake.calls.size()
		await touch(scene,"VIEW / EXPORT RECOVERY COPIES")
		check(scene.cloud_panel.read_only and scene.import_pending,"pending archive viewer cannot release Import freeze")
		var copy_id: String=scene.cloud_flow.copies.list_ids()[0]
		await touch(scene,"VIEW COPY 1 / "+copy_id.substr(0,12))
		check(not scene.cloud_panel.viewing.is_empty() and Store.decode(scene.cloud_panel.viewing).ok,"pending archive exposes full selectable export code")
		await touch(scene,"CLOSE COPIES / KEEP IMPORT PAUSED")
		check(scene.import_pending and scene.paused and fake.calls.size()==request_count,"read-only export leaves journal frozen and makes no account call")
		io.mode=""; scene.finish_import(false); await ticks(5)
		var adopted: Node=current_scene.session
		check(not adopted.import_pending and adopted.paused and Journal.same_values(Store.decode(adopted.cloud_capture()),Store.decode(live)),"verified rollback adopts previous whole context paused")
		current_scene.queue_free(); await ticks()

	# Actual configured UI backup and remote restore; transport remains a labelled fake.
	for conflict in [false,true]:
		var io:=Memory.new(); io.files[Store.PATH+"0"]=fixture(1)
		var app:=await boot(io); var scene: Node=app.session; var fake:=FakePort.new(); scene.cloud_transport=fake
		scene.open_transfer(); await ticks(); await touch(scene,"OPTIONAL CLOUD / LOCAL COPIES")
		check(fake.calls.is_empty(),"configured modal open still makes zero auth requests")
		await touch(scene,"CONNECT PLAY GAMES"); check(fake.calls.back().op=="sign_in","actual Connect explicitly requests sign-in")
		fake.reply({"status":"authenticated"}); fake.reply({"status":"authenticated","player":"a"}); await ticks()
		await touch(scene,"CHECK CLOUD SAVES")
		fake.reply({"status":"conflict","player":"a","conflict":"gui-conflict","first":packet(fixture(0)),"second":packet(fixture(2))} if conflict else {"status":"loaded","player":"a","snapshot":packet(fixture(2))}); await ticks()
		if conflict:
			await touch(scene,"KEEP CLOUD 2 FOR CONFLICT"); await touch(scene,"CONFIRM CLOUD CHOICE")
			fake.reply({"status":"authenticated","player":"a"}); check(fake.calls.back().op=="resolve","actual conflict confirmation dispatches chosen resolve")
			fake.reply({"status":"loaded","player":"a","snapshot":packet(fixture(2))}); await ticks()
		await touch(scene,"BACK UP THIS DEVICE"); await touch(scene,"CONFIRM BACKUP SUBMISSION")
		fake.reply({"status":"authenticated","player":"a"}); check(fake.calls.back().op=="write","actual backup confirmation dispatches write")
		fake.reply({"status":"submitted","player":"a","sha256":packet(scene.cloud_flow.local_code).sha256}); await ticks()
		check(scene.cloud_flow.message.contains("not confirmed"),"UI submission truthfully leaves cross-device acceptance open")
		await touch(scene,"CHECK CLOUD SAVES"); fake.reply({"status":"loaded","player":"a","snapshot":packet(fixture(0))}); await ticks()
		await touch(scene,"RESTORE CLOUD 1 LOCALLY"); await touch(scene,"CONFIRM LOCAL IMPORT")
		fake.reply({"status":"authenticated","player":"a"}); fake.reply({"status":"authenticated","player":"a"}); await ticks(5)
		var adopted: Node=current_scene.session
		check(adopted.paused and not adopted.import_pending and Journal.same_values(Store.decode(adopted.cloud_capture()),Store.decode(fixture(0))),"actual remote restore adopts entire selected save through verified journal")
		current_scene.queue_free(); await ticks()
	# Duplicate cleanup cannot repeat an already accepted restore callback.
	ctx=make_case(); connect_case(ctx); remote(ctx); ctx.flow.stage_restore(0); ctx.flow.confirm(); ctx.port.reply({"status":"authenticated","player":"a"}); ctx.port.reply({"status":"authenticated","player":"a"}); ctx.port.ack()
	check(ctx.owner.restores.size()==1,"duplicate cleanup ack cannot repeat local handoff"); ctx.flow.dispose()

	# Parent-reviewed offline-always boundary: never-ending SDK work cannot trap local play.
	for operation in ["sign_in","read","write","resolve","restore_cleanup"]:
		var io:=Memory.new(); io.files[Store.PATH+"0"]=fixture(1)
		var app:=await boot(io); var scene: Node=app.session; var fake:=FakePort.new(); fake.auto_cleanup=false; scene.cloud_transport=fake
		scene.open_cloud(); await ticks(); await touch(scene,"CONNECT PLAY GAMES")
		if operation!="sign_in":
			fake.reply({"status":"authenticated"}); fake.reply({"status":"authenticated","player":"a"}); await ticks()
		if operation in ["read","resolve","restore_cleanup"]:
			await touch(scene,"CHECK CLOUD SAVES")
		if operation in ["resolve","restore_cleanup"]:
			fake.reply({"status":"conflict","player":"a","conflict":"never","first":packet(fixture(0)),"second":packet(fixture(2))}); await ticks()
		if operation=="write":
			await touch(scene,"BACK UP THIS DEVICE"); await touch(scene,"CONFIRM BACKUP SUBMISSION"); fake.reply({"status":"authenticated","player":"a"}); await ticks()
		if operation=="resolve":
			await touch(scene,"KEEP CLOUD 2 FOR CONFLICT"); await touch(scene,"CONFIRM CLOUD CHOICE"); fake.reply({"status":"authenticated","player":"a"}); await ticks()
		if operation=="restore_cleanup":
			await touch(scene,"RESTORE CLOUD 2 LOCALLY"); await touch(scene,"CONFIRM LOCAL IMPORT"); fake.reply({"status":"authenticated","player":"a"}); await ticks()
		var saved_before_close: String=scene.cloud_capture()
		await touch(scene,"CLOSE / KEEP LOCAL PAUSED")
		check(not scene.cloud_held and scene.paused and not scene.import_pending,"explicit Close releases local owner despite never-finished "+operation)
		if not scene.cloud_held:
			var count: int=io.writes; check(scene.save_now() and io.writes>count,"offline autosave available while native cleanup pending "+operation)
			fake.reply({"status":"authenticated","player":"a"}); fake.ack(); await ticks()
			check(scene.cloud_capture()==saved_before_close and not scene.import_pending,"late native success cannot restore after local Close/autosave "+operation)
		current_scene.queue_free(); await ticks()

	var old_binding:=OldBinding.new(); var old_port:=Native.new(old_binding)
	check(not old_port.is_configured() and old_binding.calls==0,"missing cancel API is unavailable without fallback or auth")
	var cheap:=Memory.new()
	for i in 500: cheap.files[Copies.PREFIX+str(i).sha256_text()]="unreadable"
	var copy_store:=Copies.new(cheap); check(copy_store.list_ids().size()==500 and cheap.read_count==0,"500 archive IDs enumerate without decoding file bodies")
	var physical:=Copies.new(); var real_copy:=physical.keep(fixture(1)); check(real_copy.ok and real_copy.id in physical.list_ids() and physical.get_code(real_copy.id).text==fixture(1),"production file archive enumeration and exact retrieval in isolated user dir")
	# Synchronous callback recursion observes pending/phase before native dispatch.
	var sync_owner:=Owner.new(); sync_owner.text=fixture(1); var sync_io:=Memory.new(); sync_io.files[Store.PATH+"0"]=sync_owner.text
	var sync_port:=SyncPort.new(); sync_port.remote_packet=packet(fixture(0)); var sync_flow:=Flow.new(); sync_flow.setup(sync_owner.capture,sync_io,sync_port,sync_owner.restore); sync_flow.open(); sync_flow.connect_account(); sync_flow.check_cloud(); sync_flow.stage_restore(0); sync_flow.confirm()
	check(sync_flow.phase=="handoff" and sync_owner.restores==[fixture(0)],"synchronous auth/read/cleanup/final status hands off exactly once"); sync_flow.dispose()
	ctx=make_case(); connect_case(ctx); remote(ctx); ctx.port.auto_cleanup=false; ctx.flow.stage_restore(0); ctx.flow.confirm(); ctx.port.reply({"status":"authenticated","player":"a"}); ctx.port.ack(); ctx.port.reply({"status":"authenticated","player":"b"})
	check(ctx.owner.restores.is_empty(),"account change during cleanup rejected at final observation"); ctx.flow.cancel(); ctx.flow.dispose()
	ctx=make_case(); connect_case(ctx); ctx.port.auto_cleanup=false; ctx.flow.check_cloud(); ctx.port.reply({"status":"conflict","player":"b","conflict":"foreign","first":packet(fixture(0)),"second":packet(fixture(2))})
	check(ctx.flow.phase=="closing" and ctx.port.cleanups==1,"rejected-account conflict always asks owning port cleanup before reuse"); ctx.port.ack(); check(ctx.flow.phase=="error","rejected conflict cleanup acknowledgment"); ctx.flow.cancel(); ctx.flow.dispose()
	# The actual singleton bridge retains never-finished cleanup after its modal dies.
	var retained_io:=Memory.new(); retained_io.files[Store.PATH+"0"]=fixture(1)
	var retained_app:=await boot(retained_io); var retained_scene: Node=retained_app.session; var retained_binding:=Binding.new(); var retained_port:=Native.new(retained_binding); retained_scene.cloud_transport=retained_port
	retained_scene.open_cloud(); await ticks(); await touch(retained_scene,"CONNECT PLAY GAMES"); var original_request: String=retained_binding.calls.back().id
	await touch(retained_scene,"CLOSE / KEEP LOCAL PAUSED"); var first_cancel: String=retained_binding.calls.back().id
	check(not retained_scene.cloud_held and Native.owner==retained_port and retained_scene.save_now(),"real port cleanup survives modal and offline save resumes")
	retained_scene.open_cloud(); await ticks(); check(retained_scene.cloud_flow.phase=="cleanup_required","reopen shows independent cleanup busy instead of new auth")
	await touch(retained_scene,"CLOSE / KEEP LOCAL PAUSED"); check(not retained_scene.cloud_held,"reopened busy cleanup can Close locally")
	retained_binding.completed.emit(first_cancel,JSON.stringify({"status":"close_failed","remote_effect":"none"})); retained_scene.cloud_transport=null
	retained_scene.open_cloud(); await ticks(); await touch(retained_scene,"RETRY CLOUD CLEANUP"); var second_cancel: String=retained_binding.calls.back().id
	await touch(retained_scene,"CLOSE / KEEP LOCAL PAUSED"); retained_binding.completed.emit(original_request,JSON.stringify({"status":"authenticated"})); retained_binding.completed.emit(second_cancel,JSON.stringify({"status":"cancelled","remote_effect":"none"})); await ticks()
	check(Native.owner==null and not retained_scene.cloud_held and retained_scene.save_now(),"cleanup failure retry and late success cannot refreeze or adopt local progress")
	current_scene.queue_free(); await ticks()
	var report:={"checks":checks,"failures":failures,"events":events,"limits":"Synthetic whole contexts and native/fault fakes, real GUI ScreenTouch; headless/Dummy, no account/network/clipboard/native/render claim."}
	var output:=FileAccess.open(folder.path_join("cloud-ui.json"),FileAccess.WRITE); output.store_string(JSON.stringify(report)); output.close()
	print("CLOUD_UI ",checks," / ",failures.size()," failures / ",events.size()," touch events"); quit(0 if failures.is_empty() else 1)
