extends SceneTree
const Scene = preload("res://main.tscn")
const S = preload("res://scripts/save_store.gd")
const Challenge = preload("res://scripts/challenge_v1.gd")
const T = preload("res://scripts/import_recovery.gd")
const Copies = preload("res://scripts/recovery_copies.gd")
const Fault = preload("res://tests/fault_files.gd")
var folder := ""
var checks := 0
var failures: Array[String] = []
var events: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var game: Node
var part := "all"
class IO extends Fault:
	var promoted := ""
	var fail_destination := false
	var active_writes := 0
	var mode := ""
	var blocked: Array[String] = []
	var destination_reads := 0
	var active_reads := 0
	var read_after := 0
	var once_path := ""
	var once_reads := 0
	func rename(from: String,to: String) -> bool:
		var okay:=super.rename(from,to)
		if to==S.PATH: promoted=to; destination_reads=0
		if to==T.PATH:
			if mode=="journal_missing": files.erase(to)
			elif mode=="journal_corrupt": files[to]="torn"
			elif mode=="partial_cleanup": files[from]=files[to]
		if to.begins_with(Copies.PREFIX) and not to.ends_with(".tmp"):
			if mode=="archive_missing": files.erase(to)
			elif mode=="archive_corrupt": files[to]="torn"
		return okay
	func read_text(path: String) -> String:
		if path in [S.PATH,S.PATH+".tmp",S.PATH+".bak",S.PATH+".bak.tmp"]: active_reads+=1
		if path in blocked: return "unreadable"
		if path==once_path:
			once_reads+=1
			if once_reads>1: return "one read window closed"
		if path==promoted:
			destination_reads+=1
			if fail_destination or read_after>0 and destination_reads>=read_after: return "temporarily unreadable"
		return super.read_text(path)
	func write_text(path: String,text: String) -> bool:
		if path in [S.PATH+".tmp",S.PATH+".bak.tmp"]: active_writes+=1
		if mode=="archive_write" and path.begins_with(Copies.PREFIX): return false
		if path==T.PATH+".tmp" and mode in ["journal_write","journal_flush"]:
			files[path]=text if mode=="journal_flush" else "torn"; return false
		return super.write_text(path,text)
	func remove(path: String) -> bool:
		if mode=="cleanup_failure" or mode=="partial_cleanup" and path.ends_with(".tmp"): return false
		if mode=="cleanup_lie": return true
		files.erase(path); return true
class Clipboard extends RefCounted:
	var enabled := true
	var accepted := true
	var wrong := false
	var text := ""
	var writes := 0
	var reads := 0
	var on_read := Callable()
	func available() -> bool: return enabled
	func put(value: String) -> bool: writes+=1; text=value; return accepted
	func get_text() -> String:
		reads+=1
		if on_read.is_valid(): on_read.call()
		return "different code" if wrong else text
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--part="): part=arg.trim_prefix("--part=")
	root.size=Vector2i(600,1066); call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); printerr("FAIL: "+label)
func fixture(kind: int) -> Dictionary:
	var original: Dictionary=S.decode(FileAccess.get_file_as_string("res://tests/fixtures/save-commit-before.json")).data
	if kind in [1,2]:
		var bundle: Dictionary=Challenge.generate("key",137,{"weave":0,"treasure":true}).bundle
		original.challenge_run={"bundle":bundle,"actions":[bundle.witness[0]],"used_undo":true}
		original.challenge_records=[{"key":Challenge.validate(bundle).key,"version":bundle.version,"family":bundle.family,"seed":bundle.seed,"options":bundle.options.duplicate(true),"best":bundle.witness.size(),"medals":1,"fallback":bundle.fallback}]
		original.kind="challenge" if kind==1 else "campaign"
	if kind==3: original=S.decode(FileAccess.get_file_as_string("res://tests/fixtures/code1-active-route.json")).data
	original.settings["note"]="whole fixture "+str(kind)
	original.settings.sound=kind%2==0; original.settings.reduced_effects=kind%2==1
	return S.decode(S.encode(original)).data
func meaning(value: Dictionary) -> Dictionary:
	var result: Dictionary=value.duplicate(true); result.erase("revision"); result.erase("recoverable"); return result
func ticks(count: int=2) -> void:
	for frame in count: await process_frame
func boot(io: Variant=null) -> void:
	game=Scene.instantiate(); game.save_io=io; root.add_child(game); current_scene=game; await ticks()
func stop() -> void:
	game.queue_free(); await ticks()
func touch(id: String) -> void:
	check(game.buttons().has(id),"actual visible control "+id)
	if not game.buttons().has(id): return
	var point: Vector2=root.get_final_transform()*game.to_global(game.buttons()[id].get_center())
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new(); event.index=0; event.position=point; event.pressed=pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); events.append({"target":id,"pressed":pressed}); await ticks(1)
func materialize(io: IO) -> void:
	var user:=ProjectSettings.globalize_path("user://")
	check(user.replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"isolated real-file bootstrap data")
	for file in DirAccess.get_files_at(user):
		if file.begins_with("tower-save") or file.begins_with("tower-import-") or file.begins_with("tower-recovery-copy-"): DirAccess.remove_absolute(user.path_join(file))
	for path in io.files:
		var output:=FileAccess.open(path,FileAccess.WRITE); output.store_string(io.files[path]); output.close()
func capture() -> Dictionary:
	return {"data":game.data.duplicate(true),"state":game.state.duplicate(true),"pending":game.pending.duplicate(true),"beat":game.beat,"phase":game.phase,"selected":game.selected,"pending_room":game.pending_room}
func same_live(before: Dictionary) -> bool:
	return capture()==before
func reset_fault(io: IO) -> void:
	io.mode=""; io.promoted=""; io.fail_destination=false; io.read_after=0; io.blocked.clear(); io.fail_suffix=""; io.fail_mode=""
func keep_codes(io: IO) -> Array[String]:
	var result: Array[String]=[]
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if io.files.has(S.PATH+suffix): result.append(io.files[S.PATH+suffix])
	return result
func seed_io(kind: int) -> IO:
	var io:=IO.new()
	for index in 4:
		var value:=fixture(kind); value.revision=5+index; value.recoverable=index!=1
		io.files[S.PATH+["", ".tmp", ".bak", ".bak.tmp"][index]]=S.encode(value)
	return io
func ui_touch(id: String) -> void:
	var button: Button=game.recovery_buttons[id]
	check(button.is_visible_in_tree() and not button.disabled,"visible recovery choice "+id)
	for step in 35:
		if game.recovery_scroll.get_global_rect().encloses(button.get_global_rect()): break
		var wheel:=InputEventMouseButton.new(); wheel.position=root.get_final_transform()*game.recovery_scroll.get_global_rect().get_center()
		wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if button.get_global_rect().get_center().y>game.recovery_scroll.get_global_rect().get_center().y else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed=true; Input.parse_input_event(wheel); Input.flush_buffered_events(); await ticks(1)
	check(game.recovery_scroll.get_global_rect().encloses(button.get_global_rect()),"recovery choice reachable through engine scroll "+id)
	var point: Vector2=root.get_final_transform()*button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new(); event.index=0; event.position=point; event.pressed=pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); events.append({"target":id,"pressed":pressed}); await ticks(1)
func frozen(io: IO,before: Dictionary) -> void:
	var files: Dictionary=io.files.duplicate(true); var writes:=io.active_writes
	for id in ["retry","undo","map","sound","effects","close_transfer","resume","generate","next","enter"]: game.action(id)
	game.back(); game.start_challenge("key",44,{"weave":0,"treasure":true}); game.persist(); game.award(); game._process(10.0)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT); game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await ticks(3)
	check(game.import_pending and game.paused and same_live(before),"pending preserves all live data, elapsed beat, selection and unfinished room through mutators/lifecycle")
	check(io.files==files and io.active_writes==writes,"pending blocks normal saves before active mutation")
func run() -> void:
	if part in ["all","core"]:
		for original_kind in [0,1,2,3]:
			for use_import in [false,true]:
				var io:=seed_io(original_kind); await boot(io)
				game.data.settings.note="unsaved full setting "+str(original_kind)
				await touch("settings"); await touch("transfer"); var before:=capture(); var code: String=" \n"+S.encode(fixture((original_kind+1)%4))+" \n"
				var original_code:=S.encode(game.data); var raw:=keep_codes(io); game.editor.text=code; io.fail_destination=true; await touch("import")
				check(game.import_pending and game.paused and same_live(before),"actual Import retains whole original after unconfirmed primary read")
				check(game.recovery_summary.text.contains("PREVIOUS COMPLETE SAVE") and not game.recovery_code.visible,"summary-first recovery hides raw code")
				for text in raw+[original_code,code]: check(game.import_recovery.copies.get_code(text.sha256_text()).get("text")==text,"exact raw/live/intake code retained before active write")
				await frozen(io,before); reset_fault(io)
				await stop(); materialize(io); await boot()
				check(game.import_pending and game.paused and meaning(game.data)==meaning(before.data),"fresh materialized production owner selects complete original before play/default save")
				await ui_touch("retry" if use_import else "previous")
				var wanted: Dictionary=S.decode(code).data if use_import else before.data
				check(not game.import_pending and game.paused and meaning(game.data)==meaning(wanted) and meaning(S.read().data)==meaning(wanted),"explicit actual choice synchronously adopts complete verified live/disk meaning paused")
				check(not T.new().read().pending,"choice verifies both marker artifacts absent")
				await stop(); await boot(); check(not game.import_pending and meaning(game.data)==meaning(wanted),"settled cold owner retains complete chosen campaign/challenge/parked data")
				await stop()
	if part in ["all","animation"]:
		for use_import in [false,true]:
			var io:=IO.new(); io.files[S.PATH]=S.encode(fixture(3)); await boot(io)
			game.action("resume"); var point: Vector2=root.get_final_transform()*game.to_global(game.room_rect(game.level.rooms[1]).get_center())
			# Pick an actually available next room from the pinned replay.
			var selected: String=""
			for room in game.level.rooms:
				if not room.id in game.state.claimed and game.Rules.step(game.level,game.state,room.id).get("ok",false): selected=room.id; break
			check(not selected.is_empty(),"pinned active route has an executable next room")
			point=root.get_final_transform()*game.to_global(game.room_rect(game.Rules.find_room(game.level,selected)).get_center())
			var event:=InputEventScreenTouch.new(); event.index=0; event.position=point; event.pressed=true; Input.parse_input_event(event); Input.flush_buffered_events(); await ticks(1)
			event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); Input.flush_buffered_events(); await ticks(1)
			await touch("enter"); check(not game.pending.is_empty() and game.beat<.9,"actual room input admits an unfinished animation")
			await touch("settings"); await touch("transfer"); var before:=capture(); game.editor.text=S.encode(fixture(1)); io.fail_destination=true; await touch("import")
			await frozen(io,before); await ui_touch("retry" if use_import else "previous"); check(game.import_pending and same_live(before),"failed actual choice preserves original unfinished room and every live field")
			reset_fault(io); await ui_touch("retry" if use_import else "previous")
			var wanted: Dictionary=fixture(1) if use_import else before.data
			check(not game.import_pending and game.paused and game.pending.is_empty() and game.beat==0 and game.selected=="" and meaning(game.data)==meaning(wanted),"only verified choice cancels uncommitted animation under existing cold semantics")
			var actions: Dictionary=game.data.duplicate(true); game.action("resume"); game._process(10)
			check(game.data==actions,"no old animation completion appends into adopted action history")
			await stop()
	if part in ["all","bootstrap"]:
		for fault in ["torn_base","torn_stage","missing_original","invalid_incoming"]:
			var io:=seed_io(1); var helper:=T.new(io); helper.begin(S.encode(fixture(1)),S.encode(fixture(3)))
			if fault=="torn_base": io.files[T.PATH]="torn"
			elif fault=="torn_stage": io.files[T.PATH+".tmp"]="torn"; io.files.erase(T.PATH)
			elif fault=="missing_original": io.files.erase(Copies.PREFIX+helper.record.original)
			else: io.files[Copies.PREFIX+helper.record.incoming]="torn"
			io.active_reads=0; var before: Dictionary=io.files.duplicate(true); await boot(io)
			check(game.import_pending and game.paused and game.state.is_empty() and not game.view.visible,"unknown recovery never loads an ordinary/default run: "+fault)
			check(io.active_reads==0 and io.files==before and io.active_writes==0,"unknown recovery does not inspect or write active candidates beneath journal: "+fault)
			check(game.recovery_buttons.read.visible and not game.recovery_buttons.retry.visible and not game.recovery_buttons.copy_previous.visible and not game.recovery_code.visible,"unknown recovery offers read retry without unsafe choice/code export")
			await frozen(io,capture()); await stop()
		var transient:=seed_io(1); var transient_helper:=T.new(transient); transient_helper.begin(S.encode(fixture(1)),S.encode(fixture(3))); transient.blocked.append(T.PATH)
		await boot(transient); check(game.state.is_empty() and game.import_pending,"transient unreadable journal starts blocked without ordinary selection")
		transient.blocked.clear(); await ui_touch("read")
		check(game.import_pending and game.paused and meaning(game.data)==meaning(fixture(1)) and game.recovery_buttons.previous.visible,"actual recovery read retry binds complete original without resolving or saving")
		await stop()
		for once_original in [false,true]:
			var io:=seed_io(1); var helper:=T.new(io); helper.begin(S.encode(fixture(1)),S.encode(fixture(3)))
			io.once_path=Copies.PREFIX+helper.record.original if once_original else T.PATH; io.active_reads=0; await boot(io)
			check(game.import_pending and meaning(game.data)==meaning(fixture(1)) and io.once_reads==1 and io.active_reads==0,"startup binds a single validated journal/archive decision without a second read")
			await stop()
		# Preserve byte-exact schema1 intake, while the owning decoder selects its canonical schema3 meaning.
		var io:=seed_io(1); var old: String=FileAccess.get_file_as_string("res://tests/fixtures/code1-active-route.json"); var helper:=T.new(io)
		check(helper.begin(S.encode(fixture(1)),old).ok and helper.incoming_code==old and helper.copies.get_code(old.sha256_text()).text==old,"legacy raw intake remains immutable byte-exact rather than re-encoded")
		materialize(io); await boot(); await ui_touch("retry")
		check(not game.import_pending and game.paused and meaning(game.data)==meaning(S.decode(old).data),"shipping owner adopts owning-decoder complete legacy meaning only after explicit verified choice")
		await stop()
	if part in ["all","copies"]:
		for viewport in [Vector2i(344,642),Vector2i(690,829),Vector2i(1066,600)]:
			root.size=viewport
			var io:=seed_io(1); await boot(io); await touch("settings"); await touch("transfer"); game.editor.text=" "+S.encode(fixture(3))+" "; io.fail_destination=true; await touch("import")
			var before:=capture(); var files: Dictionary=io.files.duplicate(true); var transaction_message: String=game.import_recovery.message
			for use_import in [false,true]:
				var expected: String=game.import_recovery.incoming_code if use_import else game.import_recovery.original_code
				for mode in ["exact","unavailable","rejected","different","invalid"]:
					var clipboard:=Clipboard.new(); clipboard.enabled=mode!="unavailable"; clipboard.accepted=mode!="rejected"; clipboard.wrong=mode=="different"; game.recovery_copy_backend=clipboard
					if mode=="invalid":
						if use_import: game.import_recovery.incoming_code="bad"
						else: game.import_recovery.original_code="bad"
					await ui_touch("copy_incoming" if use_import else "copy_previous")
					if mode=="invalid":
						if use_import: game.import_recovery.incoming_code=expected
						else: game.import_recovery.original_code=expected
					check(clipboard.text==expected if mode not in ["unavailable","invalid"] else clipboard.writes==0,"direct copy uses exact immutable source code without OS clipboard")
					check(game.recovery_copy_feedback.text.contains("copied and checked") if mode=="exact" else not game.recovery_copy_feedback.text.contains("copied and checked"),"copy success requires exact readback and accepted write")
					check(game.recovery_scroll.get_global_rect().encloses(game.recovery_copy_feedback.get_global_rect()),"actual copy acknowledgment visible after touch at "+str(viewport)+" / "+mode)
					check(game.recovery_copy_feedback.size.y>=game.recovery_copy_feedback.get_minimum_size().y,"allocated acknowledgment fits wrapped text")
					check(game.import_pending and same_live(before) and io.files==files and game.import_recovery.message==transaction_message,"copy feedback never replaces write uncertainty or changes complete contexts/files")
				await ui_touch("view_incoming" if use_import else "view_previous"); await ticks(2)
				check(game.recovery_code.visible and not game.recovery_code.editable and game.recovery_code.text==expected and game.import_pending,"View fallback displays complete read-only code and preserves freeze")
				observations.append({"viewport":str(viewport),"incoming":use_import,"scroll":str(game.recovery_scroll.get_global_rect()),"code":str(game.recovery_code.get_global_rect()),"scroll_vertical":game.recovery_scroll.scroll_vertical})
				check(game.recovery_scroll.get_global_rect().encloses(game.recovery_code.get_global_rect()),"View fallback brought into visible scroll area")
			game.recovery_copy_backend=null; await ui_touch("copy_previous"); check(game.recovery_copy_feedback.text.contains("Clipboard unavailable"),"headless production capability guard never touches OS clipboard")
			await stop()
		root.size=Vector2i(600,1066)
		var io:=seed_io(1); await boot(io); io.fail_destination=true; game.begin_import(S.encode(fixture(3)))
		# Synchronous fake reentry represents a clipboard callback relinquishing recovery ownership.
		var clipboard:=Clipboard.new(); game.recovery_copy_backend=clipboard; reset_fault(io); clipboard.on_read=game.finish_import.bind(false)
		await ui_touch("copy_previous")
		check(not game.import_pending and game.paused and not game.recovery_copy_feedback.text.contains("copied and checked"),"late copy acknowledgment cannot overwrite a synchronously completed recovery choice")
		await stop()
	if part in ["all","faults"]:
		for fault in ["archive_write","archive_missing","archive_corrupt","journal_write","journal_flush","journal_missing","journal_corrupt","primary_missing","primary_corrupt","primary_stale","read1","read2","cleanup_failure","cleanup_lie","partial_cleanup"]:
			var io:=seed_io(1); var previous:=fixture(1); var original:=S.encode(previous); var incoming:=S.encode(fixture(3)); io.mode=fault
			if fault.begins_with("primary_"):
				io.mode=""; io.fail_suffix=S.PATH+".tmp"; io.fail_mode={"primary_missing":"rename_missing","primary_corrupt":"rename_corrupt","primary_stale":"rename_wrong_valid"}[fault]; io.rename_replacement=S.encode(fixture(0))
			if fault in ["read1","read2"]: io.mode=""; io.read_after=1 if fault=="read1" else 2
			var helper:=T.new(io); var began:=helper.begin(original,incoming); var result: Dictionary=helper.resolve(true) if began.ok else {"ok":false}
			check(not result.ok,"fault cannot claim verified whole Import: "+fault)
			check(not began.pending and io.active_writes==0 if fault.begins_with("archive") else began.pending,"preservation precedes active mutation; uncertainty retains ownership: "+fault)
			reset_fault(io); materialize(io); await boot()
			var marker:=T.new().read()
			check(game.import_pending and game.paused if marker.pending else meaning(game.data)==meaning(previous),"fault bootstrap never runs/saves a default context: "+fault)
			if marker.ok:
				check(meaning(game.data)==meaning(previous),"readable pending loads full original at fault boundary")
				await ui_touch("previous"); check(not game.import_pending and meaning(game.data)==meaning(previous),"explicit verified rollback after transient boundary")
			await stop()
	if part in ["all","admission"]:
		var source:=S.encode(fixture(1)); var target:=S.encode(fixture(3))
		for stage in [false,true]:
			for choice in [false,true]:
				var io:=seed_io(1); var helper:=T.new(io); helper.begin(source,target); io.mode="partial_cleanup" if stage else "cleanup_failure"
				if stage: io.files[T.PATH+".tmp"]=io.files[T.PATH]
				check(not helper.resolve(true).ok,"verified incoming remains pending after cleanup failure")
				io.mode="journal_missing"; check(helper.resolve(choice).ok and T.same(S.read(S.PATH,io),S.decode(target if choice else source)),"matching sole marker reused non-destructively for either choice")
				check(not helper.journal_ready,"verified clear invalidates retained helper admission")
				io.mode=""; io.read_after=1; check(not helper.resolve(not choice).ok and io.files.has(T.PATH),"retained helper recreates marker before later uncertain write")
		for first_intended in [false,true]:
			var io:=seed_io(1); var helper:=T.new(io); helper.begin(source,target); var intended: String=io.files[T.PATH]
			var other_io:=IO.new(); var other:=T.new(other_io); other.begin(S.encode(fixture(0)),S.encode(fixture(2)))
			for path in other_io.files:
				if path.begins_with(Copies.PREFIX): io.files[path]=other_io.files[path]
			io.files[T.PATH]=intended if first_intended else other_io.files[T.PATH]; io.files[T.PATH+".tmp"]=other_io.files[T.PATH] if first_intended else intended; io.mode="partial_cleanup"
			var before: Dictionary=io.files.duplicate(true); var writes:=io.active_writes
			check(not helper.resolve(true).ok and io.files==before and io.active_writes==writes,"every existing record must agree in both conflict orders before cleanup/write")
		for fault in ["invalid","unreadable","missing","archive","copies_list"]:
			var io:=seed_io(1); var helper:=T.new(io); helper.begin(source,target); io.read_after=2; helper.resolve(true); reset_fault(io)
			if fault=="invalid": io.files[T.PATH]="torn"
			elif fault=="unreadable": io.blocked.append(T.PATH)
			elif fault=="missing": io.files.erase(T.PATH); io.mode="journal_missing"
			elif fault=="archive": io.files[Copies.PREFIX+helper.record.copies.back()]="torn"
			else:
				var changed: Dictionary=helper.record.duplicate(true); changed.copies=[changed.original,changed.incoming]; var payload:=JSON.stringify(changed); io.files[T.PATH]=JSON.stringify({"payload":payload,"sha256":payload.sha256_text()})
			var before: Dictionary=io.files.duplicate(true); var writes:=io.active_writes
			check(not helper.resolve(false).ok and io.files==before and io.active_writes==writes,"same owner freshly validates all markers/archives after write uncertainty: "+fault)
		for both in [false,true]:
			var io:=seed_io(1); var helper:=T.new(io); helper.begin(source,target)
			if both: io.files[T.PATH+".tmp"]=io.files[T.PATH]
			var writes:=io.active_writes; var renames:=io.rename_count
			check(helper.persist() and io.active_writes==writes and io.rename_count==renames,"matching existing marker pair/base admits without rewriting or consuming either")
		for stage in [false,true]:
			for fault in ["unreadable","invalid"]:
				var io:=seed_io(1); var helper:=T.new(io); helper.begin(source,target)
				if stage: io.files[T.PATH+".tmp"]=io.files[T.PATH]
				var path: String=T.PATH+(".tmp" if stage else "")
				if fault=="unreadable": io.blocked.append(path)
				else: io.files[path]="torn"
				io.mode="journal_missing"; var before: Dictionary=io.files.duplicate(true); var writes:=io.active_writes
				check(not helper.resolve(false).ok and io.files==before and io.active_writes==writes,"any unreadable/torn present marker blocks unsafe replacement and active mutation")
		var archive_io:=seed_io(1); var archive_helper:=T.new(archive_io); archive_helper.begin(source,target)
		for id in archive_helper.record.copies:
			var path: String=Copies.PREFIX+id; var text: String=archive_io.files[path]; archive_io.files[path]="torn"
			var before: Dictionary=archive_io.files.duplicate(true); var writes:=archive_io.active_writes
			check(not archive_helper.resolve(true).ok and archive_io.files==before and archive_io.active_writes==writes,"every retained whole code including parked challenge/raw candidates is revalidated")
			archive_io.files[path]=text
		var io:=IO.new(); var helper:=T.new(io); helper.begin(source,target); io.files[T.PATH]="torn"; check(not helper.read().ok and not helper.journal_ready,"failed reread cannot leave stale readiness")
	FileAccess.open(folder.path_join("import-recovery.json"),FileAccess.WRITE).store_string(JSON.stringify({"part":part,"checks":checks,"failures":failures,"events":events,"observations":observations,"scope":"CPU/headless/Dummy; actual touch and same-process materialized production owners; earned campaign fixture plus labelled synthetic challenge/parked variants. Fake clipboard only; no OS/native/power-loss/render acceptance."}))
	print("TOWER_IMPORT_RECOVERY ",part," / ",checks," / ",failures.size()); if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
