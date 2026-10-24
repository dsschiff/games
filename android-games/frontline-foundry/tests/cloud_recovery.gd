extends SceneTree
const Recovery = preload("res://scripts/cloud/recovery.gd")
const Backup = preload("res://scripts/cloud/backup.gd")
const Port = preload("res://scripts/cloud/port.gd")
const Store = preload("res://scripts/save_store.gd")
const Files = preload("res://tests/fault_files.gd")
const C = preload("res://scripts/campaign_rules.gd")
const R = preload("res://scripts/rules.gd")
const D = preload("res://scripts/definitions.gd")
var checks := 0
var failures: Array[String] = []
var folder := ""
var local_import_boundary: Array[Dictionary] = []

class FakePort extends Port:
	var calls: Array[Dictionary] = []
	var abandoned := false
	var reply_on_abandon := {}
	func is_configured() -> bool: return true
	func request(id: String, operation: String, arguments: Dictionary) -> void:
		calls.append({"id":id,"operation":operation,"arguments":arguments.duplicate(true)})
	func reply(body: Dictionary) -> void: completed.emit(calls.back().id,body)
	func abandon() -> void:
		abandoned = true
		if not reply_on_abandon.is_empty(): reply(reply_on_abandon)

class PostCommitFiles extends Files:
	var transient := false
	var prefix := "test-save-"
	var promoted := false
	var destination_reads := 0
	var fail_from_read := 3
	func rename(from: String,to: String) -> bool:
		var okay: bool = super.rename(from,to)
		if okay and to.begins_with(prefix): promoted = true; destination_reads = 0
		return okay
	func read_text(path: String) -> String:
		if transient and promoted and path==prefix+"1":
			destination_reads += 1
			if destination_reads>=fail_from_read: return "unreadable"
		return super.read_text(path)

class Owner extends RefCounted:
	var live := {}
	var held := false
	var paused := true
	var releases := 0
	var adopted := 0
	var safe_adoption := false
	var defer_adoption := false
	var io: RefCounted
	func capture() -> Dictionary:
		return {"paused":paused,"text":Store.encode(live.state,live.profile,live.settings,int(live.revision),true,live.career)}
	func hold() -> bool:
		if held or not paused: return false
		held = true; return true
	func release() -> void: held = false; releases += 1
	func adopt(decoded: Dictionary) -> Dictionary:
		if defer_adoption: return {}
		safe_adoption = held and paused and Recovery.same_values(Store.read("test-save-",io),decoded)
		live = decoded.duplicate(true); adopted += 1
		return live.duplicate(true)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): folder = arg.trim_prefix("--report-dir=")
	call_deferred("run")
func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label); print("FAIL ",label)
func fixture(kind: int,revision: int = 1) -> String:
	# Synthetic decoder-valid contexts; no earned progress or real cloud claims.
	var state: Dictionary = R.fresh() if kind == 0 else C.fresh(D.mission(0))
	if kind == 2: state.phase = "playing"
	var career := C.career(); career.attempts = 2
	career.legacy_state = R.fresh(); career.legacy_profile = R.profile()
	career.skirmishes["17:mixed"] = {"medal":2,"seconds":32.5,"kills":3,"spent":18,"seed":17,"style":"mixed"}
	return Store.encode(state,R.profile(),{"sound":kind%2==0,"reduced_effects":kind%2!=0,"note":"完整 🌍 "+str(kind)},revision,true,career)
func packet(text: String) -> Dictionary:
	var wrapped := Backup.encode(text)
	return {"data":Marshalls.raw_to_base64(wrapped.text.to_utf8_buffer()),"sha256":wrapped.text.sha256_text()}
func create_case(kind: int = 1,configured: bool = true,post_commit: bool = false) -> Dictionary:
	var io: RefCounted = PostCommitFiles.new() if post_commit else Files.new(); var text := fixture(kind,900); io.files["test-save-0"] = text
	var owner := Owner.new(); owner.live = Store.decode(text); owner.io = io
	var port: Port = FakePort.new() if configured else Port.new()
	var recovery := Recovery.new(); root.add_child(recovery)
	recovery.setup(owner.capture,io,port,"test-save-",owner.hold,owner.release,owner.adopt)
	return {"io":io,"text":text,"owner":owner,"port":port,"recovery":recovery}
func connected(ctx: Dictionary) -> void:
	check(ctx.recovery.open(),"open paused context")
	check(ctx.owner.held and ctx.port.calls.is_empty(),"owner frozen before explicit auth")
	check(ctx.recovery.connect_account(),"explicit connect")
	ctx.port.reply({"status":"authenticated"}); ctx.port.reply({"status":"authenticated","player":"player-a"})
	check(ctx.recovery.phase==Recovery.Phase.READY,"authenticated status")
func compared(ctx: Dictionary,remote: Array[String]) -> void:
	connected(ctx); check(ctx.recovery.check_backup(),"explicit cloud read")
	if remote.size()==2: ctx.port.reply({"status":"conflict","player":"player-a","conflict":"conflict-1","first":packet(remote[0]),"second":packet(remote[1])})
	else: ctx.port.reply({"status":"loaded","player":"player-a","snapshot":packet(remote[0])})
	check(ctx.recovery.phase==Recovery.Phase.CHOOSE and ctx.owner.adopted==0 and ctx.owner.held,"compare without mutation, remain frozen")
	check(ctx.io.files["test-save-0"]==ctx.text,"comparison preserves exact old bytes")
func confirm(ctx: Dictionary,index: int = 0) -> void:
	check(ctx.recovery.stage_restore(index) and ctx.owner.adopted==0,"selection alone cannot adopt")
	check(ctx.recovery.confirm_restore() and ctx.owner.held and ctx.port.calls.back().operation=="status","separate confirmation revalidates account while frozen")
func dispose(ctx: Dictionary) -> void:
	ctx.recovery.free()
	check(not ctx.owner.held,"dispose releases freeze")
	if ctx.port is FakePort: check(ctx.port.abandoned,"transport abandonment requested")
func finish_cleanup(ctx: Dictionary) -> void:
	if ctx.port.calls.back().operation=="discard_conflict": ctx.port.reply({"status":"discarded"})
func codec_tests() -> void:
	var shared: GDScript = load(ProjectSettings.globalize_path("res://../shared/play-cloud/cloud_backup.gd"))
	check(shared!=null,"load actual shared contract only in tests")
	for kind in 3:
		var text := fixture(kind); check(Store.decode(text).ok,"synthetic fixture decoder-valid")
		var local := Backup.encode(text); var other: Dictionary = shared.encode(Backup.PACKAGE,text,Store.decode)
		check(local==other,"identical shared/local envelope bytes")
		check(Recovery.same_values(shared.decode(Backup.PACKAGE,local.text,Store.decode).decoded,Store.decode(text)),"shared accepts local complete save")
		check(Backup.decode(other.text).save==text and Backup.snapshot(packet(text)).save==text,"local accepts shared/native exact save")
	var good: String = Backup.encode(fixture(1)).text; var raw: Dictionary = JSON.parse_string(good)
	for field in ["format","package","sha256","save"]:
		var bad := raw.duplicate(true); bad[field] = 2 if field=="format" else "wrong"
		check(not Backup.decode(JSON.stringify(bad)).ok and not shared.decode(Backup.PACKAGE,JSON.stringify(bad),Store.decode).ok,"both reject altered "+field)
	var future: Dictionary = JSON.parse_string(fixture(1)); var payload: Dictionary = JSON.parse_string(future.payload)
	payload.version = 99; future.payload = JSON.stringify(payload); future.sha256 = future.payload.sha256_text()
	var text := JSON.stringify(future); var outer := raw.duplicate(true); outer.save = text; outer.sha256 = text.sha256_text()
	check(not Backup.encode(text).ok and not shared.encode(Backup.PACKAGE,text,Store.decode).ok,"future own save version rejected on encode")
	check(not Backup.decode(JSON.stringify(outer)).ok and not shared.decode(Backup.PACKAGE,JSON.stringify(outer),Store.decode).ok,"future version rejected inside valid wrapper")
	for bad in ["",good.left(good.length()-1),"[]","null","x".repeat(Backup.MAX_BYTES+1),"完整".repeat(1000000)]:
		check(not Backup.decode(bad).ok and not shared.decode(Backup.PACKAGE,bad,Store.decode).ok,"both reject malformed/byte-limit envelope")
	for data in ["$===","A","AAAA=","A==A","A".repeat(3866672)]: check(not Backup.snapshot({"data":data,"sha256":"0".repeat(64)}).ok,"invalid/oversized base64")
	for bytes in [PackedByteArray([255]),PackedByteArray([237,160,128]),PackedByteArray([192,128]),PackedByteArray([244,144,128,128]),PackedByteArray([226,130])]:
		var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
		check(not Backup.snapshot({"data":Marshalls.raw_to_base64(bytes),"sha256":hash.finish().hex_encode()}).ok,"reject malformed UTF8 before conversion")
	check(Backup.utf8_valid("ASCII 完整 🌍".to_utf8_buffer()),"accept valid UTF8")
	var mismatch := packet(fixture(1)); mismatch.sha256 = "0".repeat(64)
	check(not Backup.snapshot(mismatch).ok,"require native byte checksum")
func existing_import_boundary() -> void:
	# Handler-unit reproduction, not actual touch input or a native/process restart.
	for kind in [0,1]:
		var io := PostCommitFiles.new(); io.prefix = Store.PATH
		var old := fixture(kind,900); var remote := Store.decode(fixture(kind,1))
		remote.settings.sound = not remote.settings.sound
		var code := Store.encode(remote.state,remote.profile,remote.settings,1,true,remote.career)
		io.files[Store.PATH+"0"] = old; io.transient = true; io.fail_from_read = 2
		var scene := Node3D.new()
		scene.set_script(load("res://scripts/main.gd" if kind==0 else "res://scripts/campaign_main.gd"))
		scene.state = Store.decode(old).state; scene.profile = Store.decode(old).profile; scene.settings = Store.decode(old).settings
		if kind==1: scene.career = Store.decode(old).career
		scene.save_io = io; scene.code_edit = TextEdit.new(); scene.notice = Label.new(); scene.code_edit.text = code
		scene.import_code()
		check(scene.notice.text=="Storage failed. Entire current save kept.","existing import reports false write")
		check(scene.settings==Store.decode(old).settings,"existing import keeps old live settings after false")
		io.transient = false
		var live_disk_diverge: bool = Store.read(Store.PATH,io).settings!=scene.settings
		check(live_disk_diverge,"KNOWN BOUNDARY existing import cold selection differs after transient verification fault")
		var cold_path := folder.path_join("known-import-"+str(kind)+"-")
		for slot in 2:
			var output := FileAccess.open(cold_path+str(slot),FileAccess.WRITE)
			output.store_string(io.files[Store.PATH+str(slot)]); output.close()
		check(Store.read(cold_path).settings!=scene.settings,"real file Store.read reproduces immediate cold selection divergence")
		local_import_boundary.append({"catalog":1 if kind==0 else 2,"handler":"main.import_code" if kind==0 else "campaign_main.import_code","fault":"rename succeeds, second destination read temporarily unreadable","status":scene.notice.text,"live_old":true,"cold_selects_remote":true,"scope":"Existing-handler call plus production Store.read from materialized files; no production fix, actual touch, process restart or native proof."})
		scene.code_edit.free(); scene.notice.free(); scene.free()

func run() -> void:
	codec_tests()
	existing_import_boundary()
	var dormant := create_case(1,false)
	check(dormant.recovery.open() and dormant.recovery.phase==Recovery.Phase.NOT_CONFIGURED,"default is explicitly not configured")
	check(not dormant.recovery.connect_account() and not dormant.owner.held and dormant.owner.adopted==0,"no implicit auth/adoption/freeze in unconfigured mode"); dispose(dormant)
	for kind in 3:
		for remote_kind in 3:
			for choice_index in 2:
				var ctx := create_case(kind); var remotes: Array[String] = [fixture(remote_kind,1),fixture((remote_kind+1)%3,999999)]
				ctx.io.files["test-save-1"] = fixture(kind,899)
				ctx.io.files["test-save-1.tmp"] = fixture((kind+1)%3,898)
				compared(ctx,remotes)
				check(ctx.recovery.summaries().cloud.size()==2,"present both choices without revision ranking")
				check(ctx.recovery.summaries().cloud[0].code==remotes[0] and ctx.recovery.summaries().cloud[0].id==remotes[0].sha256_text(),"exact whole record and identity available before choice")
				confirm(ctx,choice_index); ctx.port.reply({"status":"authenticated","player":"player-a"})
				check(ctx.owner.adopted==1 and ctx.owner.safe_adoption,"adopt exactly once while frozen after durable commit")
				check(Recovery.same_values(ctx.owner.live,Store.decode(remotes[choice_index])) and Recovery.same_values(Store.read("test-save-",ctx.io),Store.decode(remotes[choice_index])),"entire explicitly selected live/disk context without revision ranking")
				check(not ctx.owner.held and ctx.owner.releases==1 and ctx.owner.paused,"success releases freeze once, keeps paused")
				var ids: Array = ctx.recovery.preserved_ids.duplicate()
				var prior_live: String = Store.encode(Store.decode(ctx.text).state,Store.decode(ctx.text).profile,Store.decode(ctx.text).settings,900,true,Store.decode(ctx.text).career)
				var originals: Array[String] = [prior_live,ctx.text,fixture(kind,899),fixture((kind+1)%3,898),remotes[0],remotes[1]]
				check(ids.size()==6,"preserve live, all valid raw slots/temps and both remote versions")
				for original in originals: check(ctx.recovery.copies.get_code(original.sha256_text()).text==original,"retrievable complete opaque copy")
				for step in 4: check(Store.write(ctx.owner.live.state,ctx.owner.live.profile,ctx.owner.live.settings,"test-save-",ctx.io,false,ctx.owner.live.career),"later autosave")
				check(ctx.recovery.copies.get_code(ctx.text.sha256_text()).text==ctx.text,"original survives rotating slots")
				finish_cleanup(ctx); check(ctx.recovery.phase==Recovery.Phase.RESTORED,"resource discard acknowledged")
				for call in ctx.port.calls: check(call.operation not in ["resolve","write"],"never upload or resolve cloud")
				dispose(ctx)
	for fault in ["fail_write","fail_rename","missing_destination","corrupt_destination","commit_missing","commit_corrupt","commit_stale"]:
		var ctx := create_case()
		if fault=="commit_stale": ctx.io.files["test-save-1"] = fixture(2,899)
		compared(ctx,[fixture(0)]); confirm(ctx)
		if fault.begins_with("commit_"):
			for code in [ctx.text,ctx.owner.capture().text,fixture(0)]+([fixture(2,899)] if fault=="commit_stale" else []): check(ctx.recovery.copies.keep(code).ok,"preverify archives to isolate Store promotion")
			ctx.io.set("missing_destination" if fault in ["commit_missing","commit_stale"] else "corrupt_destination",true)
		else: ctx.io.set(fault,true)
		ctx.port.reply({"status":"authenticated","player":"player-a"})
		check(ctx.owner.adopted==0 and Recovery.same_values(ctx.owner.live,Store.decode(ctx.text)),"retain entire live context: "+fault)
		check(ctx.io.files["test-save-0"]==ctx.text and Recovery.same_values(Store.read("test-save-",ctx.io),Store.decode(ctx.text)),"retain newest old exact readable source: "+fault)
		if fault.begins_with("commit_"):
			check(ctx.recovery.phase==Recovery.Phase.RECOVERY_REQUIRED and ctx.owner.held and not "Restore committed" in ctx.recovery.message,"unconfirmed write blocks old-live autosave: "+fault)
			check(not ctx.recovery.retry_adoption() and ctx.owner.held and ctx.owner.adopted==0,"failed verified-write retry remains blocked")
			ctx.io.missing_destination = false; ctx.io.corrupt_destination = false
			check(ctx.recovery.retry_adoption() and ctx.owner.safe_adoption and not ctx.owner.held,"explicit verified-write retry completes safely")
		else: check(ctx.recovery.phase==Recovery.Phase.ERROR and not ctx.owner.held and not "Restore committed" in ctx.recovery.message,"preservation failure releases freeze without success: "+fault)
		dispose(ctx)
	for mutation in ["settings","live_state","disk_revision","account","unpaused"]:
		var ctx := create_case(); compared(ctx,[fixture(2)]); confirm(ctx)
		if mutation=="settings": ctx.owner.live.settings.sound = not ctx.owner.live.settings.sound
		if mutation=="live_state": ctx.owner.live.state.phase = "playing"
		if mutation=="disk_revision": ctx.io.files["test-save-0"] = fixture(1,901)
		if mutation=="unpaused": ctx.owner.paused = false
		var before: Dictionary = ctx.owner.live.duplicate(true)
		ctx.port.reply({"status":"authenticated","player":"player-b" if mutation=="account" else "player-a"})
		check(ctx.owner.adopted==0 and ctx.owner.live==before and not ctx.owner.held and ctx.recovery.phase==Recovery.Phase.ERROR,"stale context/account rejected: "+mutation); dispose(ctx)
	for stage in ["sign_in","read","verify"]:
		var ctx := create_case()
		if stage=="sign_in": ctx.recovery.open(); ctx.recovery.connect_account()
		elif stage=="read": connected(ctx); ctx.recovery.check_backup()
		else: compared(ctx,[fixture(0)]); confirm(ctx)
		var old_id: String = ctx.port.calls.back().id; ctx.recovery.cancel()
		check(not ctx.owner.held and not ctx.recovery.open(),"cancel releases freeze, blocks overlap: "+stage)
		if stage=="read":
			ctx.port.reply({"status":"conflict","player":"player-a","conflict":"late-conflict","first":packet(fixture(0)),"second":packet(fixture(2))}); finish_cleanup(ctx)
		else: ctx.port.reply({"status":"authenticated","player":"player-a"})
		check(ctx.owner.adopted==0 and ctx.recovery.phase==Recovery.Phase.CLOSED,"late result ignored after cancel: "+stage)
		check(ctx.recovery.open(),"reopen only after draining prior request")
		ctx.port.completed.emit(old_id,{"status":"authenticated","player":"player-a"})
		check(ctx.owner.adopted==0 and ctx.recovery.phase==Recovery.Phase.SIGNED_OUT,"duplicate callback ignored")
		ctx.recovery.cancel(); dispose(ctx)
	for invalid in ["unpaused","invalid_live","invalid_cloud","unsigned","missing_freeze","missing_adoption"]:
		var ctx := create_case()
		if invalid=="unpaused": ctx.owner.paused = false
		if invalid=="invalid_live": ctx.owner.live.settings.sound = "wrong"
		if invalid=="missing_freeze": ctx.recovery._hold = Callable()
		if invalid=="missing_adoption": ctx.recovery._adopt = Callable()
		if invalid in ["unpaused","invalid_live","missing_freeze","missing_adoption"]:
			check(not ctx.recovery.open() and ctx.port.calls.is_empty() and not ctx.owner.held,"invalid owner cannot start auth: "+invalid)
		else:
			connected(ctx); ctx.recovery.check_backup()
			if invalid=="invalid_cloud": ctx.port.reply({"status":"loaded","player":"player-a","snapshot":{"data":"@@@@","sha256":"0".repeat(64)}})
			else: ctx.port.reply({"status":"signed_out"})
			check(ctx.recovery.phase==Recovery.Phase.ERROR and not ctx.owner.held and ctx.owner.adopted==0,"invalid remote releases freeze: "+invalid)
		dispose(ctx)
	var not_setup := Recovery.new(); root.add_child(not_setup)
	check(not not_setup.open() and not_setup.phase==Recovery.Phase.ERROR,"missing owner configuration fails closed")
	not_setup.free()
	var setup_again := create_case(); connected(setup_again)
	check(not setup_again.recovery.setup(Callable()) and setup_again.owner.held,"reconfiguration cannot orphan an active owner/port")
	setup_again.recovery.cancel(); dispose(setup_again)
	var deferred_signal := create_case()
	deferred_signal.recovery._adopt = Callable()
	deferred_signal.recovery.restore_committed.connect(deferred_signal.owner.adopt,CONNECT_DEFERRED)
	check(not deferred_signal.recovery.open() and deferred_signal.port.calls.is_empty(),"deferred signal connection cannot substitute for required synchronous adoption")
	dispose(deferred_signal)
	var mismatch := create_case(); connected(mismatch); mismatch.recovery.check_backup()
	mismatch.port.reply({"status":"conflict","player":"player-b","conflict":"wrong-owner","first":packet(fixture(0)),"second":packet(fixture(2))})
	check(mismatch.owner.adopted==0 and not mismatch.owner.held and mismatch.port.calls.back().operation=="discard_conflict" and mismatch.port.calls.back().arguments.player=="player-b","rejected account conflict discarded through returned resource owner")
	check(not mismatch.recovery.open(),"rejected resources block reuse until cleanup")
	mismatch.port.reply({"status":"discarded"}); check(mismatch.recovery.open(),"discard acknowledgment permits new explicit flow")
	mismatch.recovery.cancel(); dispose(mismatch)
	for uncertainty in ["readback","write_verification","deferred_adoption"]:
		var ctx := create_case(1,true,true); compared(ctx,[fixture(0)]); confirm(ctx)
		if uncertainty in ["readback","write_verification"]: ctx.io.transient = true
		if uncertainty=="write_verification": ctx.io.fail_from_read = 2
		else: ctx.owner.defer_adoption = true
		ctx.port.reply({"status":"authenticated","player":"player-a"})
		check(ctx.recovery.phase==Recovery.Phase.RECOVERY_REQUIRED and ctx.owner.held and ctx.owner.adopted==0,"post-commit uncertainty retains recovery freeze: "+uncertainty)
		check(not ctx.recovery.open(),"uncertain commit cannot restart flow")
		ctx.recovery.cancel(); check(ctx.owner.held and ctx.recovery.phase==Recovery.Phase.RECOVERY_REQUIRED,"cancel cannot release uncertain committed state")
		ctx.io.transient = false; ctx.owner.defer_adoption = false
		check(ctx.recovery.retry_adoption() and ctx.owner.safe_adoption and not ctx.owner.held,"explicit reread/adoption resolves uncertainty: "+uncertainty)
		dispose(ctx)
	var blocked := create_case(1,true,true); compared(blocked,[fixture(0)]); confirm(blocked)
	blocked.io.transient = true; blocked.port.reply({"status":"authenticated","player":"player-a"}); blocked.recovery.free()
	check(blocked.owner.held and blocked.port.abandoned and blocked.owner.adopted==0,"destroy does not release unresolved post-commit owner freeze")
	blocked.owner.release() # Test owner teardown, not a recovery action.
	var cleanup := create_case(); compared(cleanup,[fixture(0),fixture(2)])
	cleanup.recovery.cancel(); cleanup.port.reply({"status":"error"})
	check(not cleanup.recovery.open() and not cleanup.owner.held,"cleanup failure blocks reuse without gameplay freeze")
	cleanup.recovery.cancel(); cleanup.port.reply({"status":"discarded"})
	check(cleanup.recovery.open(),"cleanup retry recovers"); cleanup.recovery.cancel(); dispose(cleanup)
	var destroyed := create_case(); connected(destroyed); destroyed.recovery.check_backup()
	var orphan: String = destroyed.port.calls.back().id
	destroyed.port.reply_on_abandon = {"status":"loaded","player":"player-a","snapshot":packet(fixture(0))}
	destroyed.recovery.free()
	destroyed.port.completed.emit(orphan,{"status":"loaded","player":"player-a","snapshot":packet(fixture(0))})
	check(destroyed.port.abandoned and not destroyed.owner.held and destroyed.owner.adopted==0,"destruction abandons resources, late callback cannot adopt")
	var replacement := create_case(); connected(replacement); replacement.recovery.check_backup()
	replacement.port.completed.emit(orphan,{"status":"loaded","player":"player-a","snapshot":packet(fixture(0))})
	check(replacement.recovery.phase==Recovery.Phase.READING and replacement.owner.adopted==0,"prior instance callback cannot match replacement request")
	replacement.recovery.cancel(); replacement.port.reply({"status":"unavailable"}); dispose(replacement)
	if not folder.is_empty():
		var output := FileAccess.open(folder.path_join("cloud-recovery.json"),FileAccess.WRITE)
		output.store_string(JSON.stringify({"checks":checks,"failures":failures,"known_local_import_boundary":local_import_boundary,"scope":"CPU-only dormant adapter, synthetic contexts and fake async port; no UI/native/auth/network"},"  ")); output.close()
	print("CLOUD_RECOVERY ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
