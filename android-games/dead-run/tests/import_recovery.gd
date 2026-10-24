extends "res://tests/save_recovery.gd"
const Journal=preload("res://scripts/import_recovery.gd")
const Copies=preload("res://scripts/recovery_copies.gd")
class JournalFault extends Fault:
	var mode:=""
	var one_path:=""
	var one_reads:=0
	func read_text(path: String) -> String:
		if mode in ["one_read","retry_unreadable"] and path==one_path:
			one_reads+=1
			if one_reads>1: return "unreadable"
		if mode=="journal_read" and path.ends_with("import-pending.tmp"): return "unreadable"
		return super.read_text(path)
	func write_text(path: String,code: String) -> bool:
		if mode=="archive_failure" and path.begins_with(Copies.PREFIX): return false
		if path.ends_with("import-pending.tmp") and mode in ["journal_write","journal_flush","journal_readback"]:
			files[path]=code.left(10) if mode!="journal_flush" else code; return mode=="journal_readback"
		return super.write_text(path,code)
	func rename(from: String,to: String) -> bool:
		if mode=="journal_rename" and to.ends_with("import-pending"): return false
		var okay:=super.rename(from,to)
		if to.ends_with("import-pending"):
			if mode in ["journal_missing","retry_unreadable"]: files.erase(to)
			elif mode=="journal_corrupt": files[to]="torn"
		if to.begins_with(Copies.PREFIX) and not to.ends_with(".tmp"):
			if mode=="archive_missing": files.erase(to)
			elif mode=="archive_corrupt": files[to]="torn"
			elif mode=="archive_stale": files[to]=stale_code
		return okay
	func remove(path: String) -> bool:
		if mode=="cleanup_failure" or (mode=="partial_cleanup" and path.ends_with("import-pending.tmp")): return false
		if mode=="cleanup_lie": return true
		return super.remove(path)
class Blocking extends JournalFault:
	var block_next:=false
	var entered:=Semaphore.new()
	var released:=Semaphore.new()
	var timeline: Array[String]=[]
	var freeze_observed:=false
	func write_text(path: String,code: String) -> bool:
		if path==Store.PATH+"0.tmp" or path==Store.PATH+"1.tmp":
			if block_next:
				block_next=false; entered.post(); released.wait(); timeline.append("worker")
			else: timeline.append("active")
		elif path.begins_with(Copies.PREFIX): timeline.append("archive")
		elif path.ends_with("import-pending.tmp"): timeline.append("journal")
		return super.write_text(path,code)
class Probe extends "res://scripts/campaign.gd":
	var observe_join:=false
	func finish_autosave(wait: bool) -> void:
		if observe_join and wait and autosave_task>=0:
			files.freeze_observed=recovery_pending and paused and (not is_instance_valid(legacy_view) or (legacy_view.paused and legacy_view.recovery_blocked()))
			files.timeline.append("freeze"); observe_join=false; files.released.post()
		super.finish_autosave(wait)
func reset_fault(io: JournalFault) -> void:
	io.mode=""; io.unreadable_after=0; io.promoted=""; io.destination_mode=""; io.fail_write=false; io.fail_rename=false; io.corrupt_readback=false
func marker() -> String: return Store.PATH+"import-pending"
func materialize(io: JournalFault) -> void:
	var user:=ProjectSettings.globalize_path("user://")
	check(user.replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"materialized files remain under isolated test user data")
	for name in DirAccess.get_files_at(user):
		if name.begins_with("dead-run-save-") or name.begins_with("dead-run-recovery-copy-"): DirAccess.remove_absolute(user.path_join(name))
	for path in io.files:
		var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(io.files[path]); file.close()
func physical_boot() -> Node:
	var game: Node=load("res://campaign.tscn").instantiate(); root.add_child(game); current_scene=game; game.set_physics_process(false)
	if is_instance_valid(game.legacy_view): game.legacy_view.set_physics_process(false)
	await ticks(); return game
func frozen_check(game: Node,io: JournalFault,before: Dictionary) -> void:
	var raw: Dictionary=io.files.duplicate(true)
	game.choose_weapon("rivet"); game.open_journey(); game.select_road(1); game.confirm_selection(); game.load_road(0); game.start_run(); game.next_road(); game.enter_legacy(); game.leave_legacy(); game.toggle_sound(); game.toggle_effects(); game.toggle_pause(); game.close_transfer(); game.paste_code(); game.export_code(); game.autosave(); game.persist(); game._physics_process(5); game._process(5); game.back(); game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	if is_instance_valid(game.legacy_view):
		var child: Node=game.legacy_view
		child.toggle_sound(); child.toggle_effects(); child.start_run(); child.toggle_pause(); child.persist(); child.export_code(); child.paste_code(); child.close_transfer(); child._physics_process(5); child.back(); child.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.recovery_pending and game.paused and same(live(game),before),"pending freezes complete live context across host/child mutation routes")
	check(io.files==raw and game.autosave_task<0,"pending blocks sync/worker/lifecycle saves before input mutation")
func section(name: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--part="): return arg=="--part="+name
	return true
func run() -> void:
	check(ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"isolated data only")
	if not failures.is_empty(): quit(1); return
	for original_kind in (([0] if "--quick" in OS.get_cmdline_user_args() else [0,1,2]) if section("matrix") else []):
		for incoming_kind in ([0] if "--quick" in OS.get_cmdline_user_args() else [0,1,2]):
			for use_import in ([false] if "--quick" in OS.get_cmdline_user_args() else [false,true]):
				print("RECOVERY_CASE ",original_kind," / ",incoming_kind," / ",use_import," begin ",Time.get_ticks_msec())
				var io:=JournalFault.new(); io.files[Store.PATH+"0"]=fixture(original_kind)
				var game:=await boot(io); await click(game,"SAVE / TRANSFER"); var before:=live(game); var target:=fixture(incoming_kind,99)
				ui(game).code_box.text=target; io.unreadable_after=1; await click(game,"IMPORT")
				check(game.recovery_pending and game.paused and same(live(game),before),"uncertain GUI Import retains whole original with both bullet bodies")
				check(game.recovery_panel.visible and not game.recovery_code.visible and game.recovery_summary.text.contains("PREVIOUS WHOLE SAVE") and game.recovery_summary.text.contains("IMPORTED WHOLE SAVE"),"pending summaries lead; raw code is hidden")
				frozen_check(game,io,before); print("RECOVERY_POINT frozen ",Time.get_ticks_msec())
				await click(game,"VIEW / EXPORT PREVIOUS CODE"); check(game.recovery_code.text==game.recovery.original_code and not game.recovery_code.editable,"previous export exposes exact full readonly code")
				await click(game,"VIEW / EXPORT IMPORTED CODE"); check(game.recovery_code.text==target and game.recovery_pending,"imported readonly view retains ownership")
				game.queue_free(); await ticks(); reset_fault(io); materialize(io); var cold:=await physical_boot(); print("RECOVERY_POINT reopened ",Time.get_ticks_msec())
				check(cold.recovery_pending and cold.paused and same(live(cold),before),"fresh materialized owner chooses original full journey before default/upgrade/write")
				await click(cold,"RETRY IMPORT" if use_import else "KEEP PREVIOUS WHOLE SAVE"); await ticks(); print("RECOVERY_POINT chosen ",Time.get_ticks_msec())
				var wanted: Dictionary=Store.decode(target) if use_import else before
				check(not cold.recovery_pending and cold.paused and same(live(cold),wanted) and (not is_instance_valid(cold.legacy_view) or cold.legacy_view.paused),"choice synchronously adopts exact full live context and both owners paused before teardown")
				check(same(Store.read(),wanted) and not FileAccess.file_exists(marker()) and not FileAccess.file_exists(marker()+".tmp"),"choice verifies complete disk context before marker absence")
				cold.queue_free(); await ticks(); var settled:=await physical_boot()
				check(not settled.recovery_pending and same(live(settled),wanted),"settled fresh owner retains chosen whole meaning and bullet identities")
				settled.queue_free(); await ticks(); print("RECOVERY_POINT settled ",Time.get_ticks_msec())
	for fault in ([] if "--quick" in OS.get_cmdline_user_args() or not section("faults") else ["archive_failure","archive_missing","archive_corrupt","archive_stale","journal_write","journal_flush","journal_readback","journal_rename","journal_missing","journal_corrupt","journal_read","active_missing","active_corrupt","active_stale","read1","read2","cleanup_failure","cleanup_lie"]):
		var io:=JournalFault.new(); io.files[Store.PATH+"0"]=fixture(2); io.stale_code=fixture(0,1)
		if fault.begins_with("active_"): io.destination_mode=fault.trim_prefix("active_")
		elif fault.begins_with("read"): io.unreadable_after=1 if fault=="read1" else 2
		else: io.mode=fault
		var helper:=Journal.new(io); var began:=helper.begin(fixture(2),fixture(1,99)); var result: Dictionary=helper.resolve(true) if began.ok else {"ok":false}
		check(not result.ok,"fault cannot claim verified Import: "+fault)
		if fault.begins_with("archive_"): check(not began.pending and io.files[Store.PATH+"0"]==fixture(2),"failed complete preservation stops before active mutation: "+fault)
		else: check(began.pending,"transaction uncertainty retains ownership: "+fault)
		reset_fault(io); materialize(io); var cold:=await physical_boot(); var present:=FileAccess.file_exists(marker()) or FileAccess.file_exists(marker()+".tmp")
		check((cold.recovery_pending and cold.paused) if present else same(live(cold),Store.decode(fixture(2))),"fresh bootstrap cannot silently adopt unconfirmed/default context: "+fault)
		if cold.recovery_pending and cold.recovery_status.ok:
			check(same(live(cold),Store.decode(fixture(2))),"readable marker binds complete original: "+fault)
			await click(cold,"KEEP PREVIOUS WHOLE SAVE"); check(not cold.recovery_pending and same(live(cold),Store.decode(fixture(2))),"verified explicit rollback from "+fault)
		cold.queue_free(); await ticks()
	if section("worker"):
		for kind in [1,2]:
			var io:=Blocking.new(); io.files[Store.PATH+"0"]=fixture(kind)
			var game:=Probe.new(); game.files=io; root.add_child(game); current_scene=game; game.set_physics_process(false)
			if is_instance_valid(game.legacy_view): game.legacy_view.set_physics_process(false)
			await ticks(); await click(game,"SAVE / TRANSFER"); ui(game).code_box.text=fixture(1,99)
			io.timeline.clear(); io.block_next=true; game.autosave(); var admitted:=false
			for frame in 300:
				if io.entered.try_wait(): admitted=true; break
				await ticks(1)
			check(admitted and game.autosave_task>=0,"real admitted Store worker held before its actual mutation")
			game.observe_join=true; await click(game,"IMPORT")
			check(io.freeze_observed and game.autosave_task<0,"actual Import from host/legacy freezes both before joining worker")
			check(io.timeline.find("freeze")<io.timeline.find("worker") and io.timeline.find("worker")<io.timeline.find("archive") and io.timeline.find("archive")<io.timeline.find("journal"),"real worker completion precedes first archive and journal mutation")
			check(not game.recovery_pending and game.paused and same(live(game),Store.decode(fixture(1,99))),"worker-drained actual Import adopts whole selected context once")
			observations.append({"kind":"actual_worker_barrier","source_view":"legacy" if kind==2 else "campaign","freeze_seen":io.freeze_observed,"timeline":io.timeline.duplicate(),"joined_task":game.autosave_task<0,"selected_code_sha256":fixture(1,99).sha256_text()})
			print("AUTOSAVE_BARRIER ",JSON.stringify(observations.back()))
			await ticks(4); game.autosave(); game.finish_autosave(true)
			check(same(Store.read(Store.PATH,io),Store.decode(fixture(1,99))) and same(live(game),Store.decode(fixture(1,99))),"no late old worker or resumed autosave overwrites imported full context")
			game.queue_free(); await ticks()
	if section("edges"):
		# Distinct live, four raw slots, byte-exact catalog1 intake and upgraded selection.
		var intake: Dictionary=Store.decode(fixture(0)).context; var Catalog1=load("res://scripts/catalog1_rules.gd")
		intake.campaign=Catalog1.fresh(5,"lance"); var intake_code:=Store.encode(intake,99)
		var selection: Dictionary=intake.duplicate(true); check(Store.upgrade(selection),"existing ready-catalog upgrade selects current rules without mutating intake")
		var selected_code:=Store.encode(selection,99); var io:=JournalFault.new(); var raw: Array[String]=[]
		for slot in 2:
			for suffix in ["", ".tmp"]:
				var code:=fixture(raw.size()%3,20+raw.size()); raw.append(code); io.files[Store.PATH+str(slot)+suffix]=code
		var helper:=Journal.new(io); var live_code:=fixture(2,0)
		check(helper.begin(live_code,selected_code,intake_code).ok and helper.record.copies.size()==7,"seven distinct complete codes preserved before active write")
		for code in raw+[live_code,intake_code,selected_code]: check(Copies.new(io).get_code(code.sha256_text()).text==code,"raw/live/intake/selected code retained byte-exact")
		check(helper.resolve(true).ok and same(Store.read(Store.PATH,io),Store.decode(selected_code)),"explicit selected upgrade commits exact intended whole context")
		for code in raw+[live_code,intake_code,selected_code]: check(Copies.new(io).get_code(code.sha256_text()).text==code,"all seven codes remain retrievable after commit")
		# Actual unsaved settings from either owner must survive interruption and rollback.
		for kind in [1,2]:
			var unsaved_io:=JournalFault.new(); unsaved_io.files[Store.PATH+"0"]=fixture(kind)
			var game:=await boot(unsaved_io); unsaved_io.fail_write=true
			await click(game,"SOUND: ON" if ui(game).settings.sound else "SOUND: OFF")
			var before:=live(game); check(not same(before,Store.read(Store.PATH,unsaved_io)),"actual settings input creates an unsaved whole host/child context")
			await click(game,"SAVE / TRANSFER"); unsaved_io.fail_write=false; ui(game).code_box.text=fixture(0,99); unsaved_io.unreadable_after=1; await click(game,"IMPORT")
			game.queue_free(); await ticks(); reset_fault(unsaved_io); materialize(unsaved_io); var cold:=await physical_boot()
			check(cold.recovery_pending and same(live(cold),before),"cold pending restores unsaved full original, including child settings and bullets")
			await click(cold,"KEEP PREVIOUS WHOLE SAVE"); check(not cold.recovery_pending and same(live(cold),before) and same(Store.read(),before),"explicit rollback commits unsaved whole original before adoption")
			cold.queue_free(); await ticks()
		# Torn/missing records or archives block play/default writes; every startup reads once.
		for fault in ["base_torn","stage_torn","both_torn","archive_torn","archive_absent","journal_unreadable"]:
			var blocked_io:=JournalFault.new(); blocked_io.files[Store.PATH+"0"]=fixture(1); var blocked_helper:=Journal.new(blocked_io); blocked_helper.begin(fixture(2),fixture(0,99))
			if fault in ["base_torn","both_torn"]: blocked_io.files[marker()]="torn"
			if fault in ["stage_torn","both_torn"]:
				blocked_io.files[marker()+".tmp"]="torn"
				if fault=="stage_torn": blocked_io.files.erase(marker())
			if fault=="archive_torn": blocked_io.files[Copies.PREFIX+blocked_helper.record.original]="torn"
			if fault=="archive_absent": blocked_io.files.erase(Copies.PREFIX+blocked_helper.record.original)
			if fault=="journal_unreadable": blocked_io.mode="one_read"; blocked_io.one_path=marker(); blocked_io.one_reads=1
			var blocked:=await boot(blocked_io); var previous: Dictionary=blocked_io.files.duplicate(true)
			check(blocked.recovery_pending and blocked.paused and not blocked.recovery_status.ok,"unknown pending cannot select default or higher incoming context: "+fault)
			blocked.start_run(); blocked.enter_legacy(); blocked.toggle_sound(); blocked.toggle_effects(); blocked.persist(); blocked.autosave(); blocked._physics_process(10); blocked.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			check(blocked_io.files==previous and blocked.recovery_pending,"unknown pending cannot mutate/default-save: "+fault)
			blocked.queue_free(); await ticks()
		for kind in ["journal","archive"]:
			var once_io:=JournalFault.new(); once_io.files[Store.PATH+"0"]=fixture(1); var once_helper:=Journal.new(once_io); once_helper.begin(fixture(2),fixture(0,99))
			once_io.mode="one_read"; once_io.one_path=marker() if kind=="journal" else Copies.PREFIX+once_helper.record.original
			var once:=await boot(once_io); check(once.recovery_pending and same(live(once),Store.decode(fixture(2))) and once_io.one_reads==1,"one validated startup decision binds full context without rereading "+kind)
			once.queue_free(); await ticks()
		var partial_io:=JournalFault.new(); partial_io.files[Store.PATH+"0"]=fixture(2); var partial:=Journal.new(partial_io); partial.begin(fixture(2),fixture(0,99)); partial_io.files[marker()+".tmp"]=partial_io.files[marker()]; partial_io.mode="partial_cleanup"
		check(not partial.resolve(true).ok and not partial_io.files.has(marker()) and partial_io.files.has(marker()+".tmp"),"partial cleanup retains stage marker and cannot claim adoption")
		reset_fault(partial_io); materialize(partial_io); var partial_cold:=await physical_boot(); check(partial_cold.recovery_pending and same(live(partial_cold),Store.decode(fixture(2))),"partial cleanup reopens complete original from retained stage")
		await click(partial_cold,"RETRY IMPORT"); check(not partial_cold.recovery_pending and same(live(partial_cold),Store.decode(fixture(0,99))),"stage recovery explicitly finishes selected whole Import")
		partial_cold.queue_free(); await ticks()
		var retain_io:=JournalFault.new(); retain_io.files[Store.PATH+"0"]=fixture(2); var retained:=Journal.new(retain_io); retained.begin(fixture(2),fixture(0,99)); check(retained.resolve(true).ok and not retained.journal_ready,"successful clear invalidates retained helper admission")
		retain_io.unreadable_after=1; check(not retained.resolve(false).ok and retain_io.files.has(marker()),"retained helper recreates marker before later uncertain active write")
		reset_fault(retain_io); materialize(retain_io); var retained_cold:=await physical_boot(); check(retained_cold.recovery_pending and same(live(retained_cold),Store.decode(fixture(2))),"retained helper interruption reopens original whole context")
		retained_cold.queue_free(); await ticks()
	if section("marker_retry"):
		for retained_stage in [false,true]:
			for promotion_fault in ["journal_missing","journal_corrupt"]:
				var io:=JournalFault.new(); var before:=fixture(2); var target:=fixture(1,99)
				io.files[Store.PATH+"0"]=before; var helper:=Journal.new(io); check(helper.begin(before,target).ok,"retry case preserves complete sources before first active write")
				if retained_stage: io.files[marker()+".tmp"]=io.files[marker()]
				io.mode="partial_cleanup" if retained_stage else "cleanup_failure"
				check(not helper.resolve(true).ok and same(Store.read(Store.PATH,io),Store.decode(target)),"first verified incoming write stays pending after cleanup failure")
				var retained_path:=marker()+".tmp" if retained_stage else marker(); var retained_text: String=io.files[retained_path]
				io.mode=promotion_fault; var result:=helper.resolve(false)
				check(result.ok or io.files.get(retained_path)==retained_text,"retry never consumes the sole verified matching marker before rollback")
				reset_fault(io); materialize(io); var cold:=await physical_boot()
				check(same(live(cold),Store.decode(before)) and (not result.ok or not cold.recovery_pending),"fresh owner retains complete previous context after explicit rollback retry")
				if not result.ok: check(cold.recovery_pending and cold.paused,"uncertain rollback remains visibly pending")
				cold.queue_free(); await ticks()
		for retained_stage in [false,true]:
			var io:=JournalFault.new(); var before:=fixture(2); io.files[Store.PATH+"0"]=before; var helper:=Journal.new(io); helper.begin(before,fixture(1,99))
			if retained_stage: io.files[marker()+".tmp"]=io.files[marker()]
			io.mode="partial_cleanup" if retained_stage else "cleanup_failure"; helper.resolve(true)
			io.mode="journal_missing"; io.unreadable_after=1
			check(not helper.resolve(false).ok,"reused marker retains ownership when rollback destination read is uncertain")
			reset_fault(io); materialize(io); var cold:=await physical_boot()
			check(cold.recovery_pending and cold.paused and same(live(cold),Store.decode(before)),"uncertain reused-marker rollback cold-boots pending with exact original")
			await click(cold,"KEEP PREVIOUS WHOLE SAVE")
			check(not cold.recovery_pending and cold.paused and same(live(cold),Store.decode(before)) and same(Store.read(),Store.decode(before)),"actual Keep Previous completes verified rollback after retry-marker uncertainty")
			cold.queue_free(); await ticks()
		for intended_first in [false,true]:
			var io:=JournalFault.new(); var helper:=Journal.new(io); helper.begin(fixture(2),fixture(1,99)); var intended: String=io.files[marker()]
			var other:=Journal.new(io,false,Store.PATH+"other-"); other.begin(fixture(0),fixture(1,88)); var unrelated: String=io.files[other.path]
			io.files[marker()]=intended if intended_first else unrelated; io.files[marker()+".tmp"]=unrelated if intended_first else intended
			var prior: Dictionary=io.files.duplicate(true)
			check(not helper.persist() and io.files==prior,"every existing artifact must match intended before marker reuse")
			if intended_first:
				io.mode="partial_cleanup"; check(not helper.resolve(true).ok and io.files==prior,"conflicting later stage cannot become authoritative after partial cleanup")
				reset_fault(io); materialize(io); var cold:=await physical_boot()
				check(cold.recovery_pending and same(live(cold),Store.decode(fixture(2))),"conflicting later-stage retry retains intended original through fresh bootstrap")
				cold.queue_free(); await ticks()
		for retained_stage in [false,true]:
			var io:=JournalFault.new(); var before:=fixture(2); io.files[Store.PATH+"0"]=before; var helper:=Journal.new(io); helper.begin(before,fixture(1,99))
			if retained_stage: io.files[marker()+".tmp"]=io.files[marker()]
			io.mode="partial_cleanup" if retained_stage else "cleanup_failure"; helper.resolve(true)
			var retained_path:=marker()+".tmp" if retained_stage else marker(); var prior: Dictionary=io.files.duplicate(true)
			io.mode="retry_unreadable"; io.one_path=retained_path; io.one_reads=1
			check(not helper.persist() and io.files==prior,"transient unreadable sole marker cannot be consumed by retry staging")
			reset_fault(io); materialize(io); var cold:=await physical_boot()
			check(cold.recovery_pending and cold.paused and same(live(cold),Store.decode(before)),"transient marker reread preserves original whole bootstrap")
			cold.queue_free(); await ticks()
		for changed in ["torn","missing","unreadable","conflicting"]:
			var stale_io:=JournalFault.new(); stale_io.files[Store.PATH+"0"]=fixture(2); var stale_helper:=Journal.new(stale_io); stale_helper.begin(fixture(2),fixture(1,99)); stale_io.unreadable_after=1
			check(not stale_helper.resolve(true).ok,"active destination uncertainty retains journal owner for admission recheck")
			reset_fault(stale_io)
			if changed=="torn": stale_io.files[marker()]="torn"
			elif changed=="missing": stale_io.files.erase(marker()); stale_io.mode="journal_missing"
			elif changed=="unreadable": stale_io.mode="one_read"; stale_io.one_path=marker(); stale_io.one_reads=1
			else:
				var other:=Journal.new(stale_io,false,Store.PATH+"other-"); other.begin(fixture(0),fixture(1,88)); stale_io.files[marker()]=stale_io.files[other.path]
			var stale_prior: Dictionary=stale_io.files.duplicate(true)
			check(not stale_helper.resolve(false).ok and stale_io.files==stale_prior,"each retry revalidates marker before active mutation: "+changed)
		var reread_io:=JournalFault.new(); var reread_helper:=Journal.new(reread_io); reread_helper.begin(fixture(2),fixture(1,99)); reread_io.files[marker()]="torn"
		check(not reread_helper.read().ok and not reread_helper.journal_ready,"failed read cannot retain stale journal readiness")
		for existing in ["absent","invalid","unrelated"]:
			var io:=JournalFault.new(); var helper:=Journal.new(io); helper.begin(fixture(2),fixture(1,99)); var intended: Dictionary=helper.record.duplicate(true)
			if existing=="absent": io.files.erase(marker())
			elif existing=="invalid": io.files[marker()]="torn"
			else:
				var other:=Journal.new(JournalFault.new()); other.begin(fixture(0),fixture(1,88)); io.files[marker()]=other.io.files[marker()]
			io.mode="journal_write"; check(not helper.persist() and helper.record==intended,"missing/invalid/unrelated marker cannot authorize unsafe reuse: "+existing)
		var io:=JournalFault.new(); var helper:=Journal.new(io); helper.begin(fixture(2),fixture(1,99)); io.mode="cleanup_failure"; helper.resolve(true)
		io.files[Copies.PREFIX+helper.record.original]="torn"; var prior_files: Dictionary=io.files.duplicate(true)
		check(not helper.resolve(false).ok and io.files==prior_files,"reused marker still requires every complete archived code before active write")
	if section("phase"):
		for phase in ["ready","playing","terminal"]:
			var incoming: Dictionary=Store.decode(fixture(2)).context; incoming.campaign=C.fresh(0,incoming.loadout)
			if phase=="ready": incoming.legacy=R.fresh()
			elif phase=="terminal":
				while incoming.legacy.phase=="playing": R.step(incoming.legacy)
			var code:=Store.encode(incoming,99); var io:=JournalFault.new(); io.files[Store.PATH+"0"]=fixture(1)
			var game:=await boot(io); await click(game,"SAVE / TRANSFER"); ui(game).code_box.text=code; await click(game,"IMPORT")
			check(not game.recovery_pending and game.paused and game.legacy_view.paused and same(live(game),Store.decode(code)) and same(Store.read(Store.PATH,io),Store.decode(code)),"active legacy phase import retains full paused live and durable meaning")
			var expected: String={"ready":"Start","playing":"Resume","terminal":"Retry"}[phase]
			check(game.legacy_view.transfer_status.text.contains(expected+" when ready."),"legacy success guidance follows active phase despite parked ready campaign: "+phase)
			game.queue_free(); await ticks()
	if section("formats"):
		# Prototype format can resume in shipping owner; prototype rejects full journey marker.
		var old_ctx: Dictionary=Store.decode(fixture(2)).context; var old_code:=Old.encode(old_ctx.legacy,old_ctx.settings,22)
		var old_target:=Old.encode(Store.decode(fixture(1)).context.legacy,{"sound":true,"reduced_effects":true},33)
		var old_io:=JournalFault.new(); old_io.files[Store.PATH+"0"]=old_code; var old_helper:=Journal.new(old_io,true); old_helper.begin(old_code,old_target); old_io.unreadable_after=1; old_helper.resolve(true)
		reset_fault(old_io); materialize(old_io); var migrated:=await physical_boot()
		var raw_old:=Store.decode(old_code); var normalized_old:=Store.decode(Store.encode(raw_old.context,0)); var current_live:=live(migrated)
		observations.append({"kind":"legacy_format_diagnostic","raw_ctx_equals_owning_decode":migrated.ctx==raw_old.context,"live_equals_raw":same(current_live,raw_old),"live_equals_owning_normalized":same(current_live,normalized_old),"meaning_equal":preload("res://scripts/campaign_data.gd").same(current_live.context,raw_old.context),"actual_context":migrated.ctx,"expected_context":raw_old.context})
		print("FORMAT_DIAGNOSTIC ",observations.back().raw_ctx_equals_owning_decode," / ",observations.back().live_equals_owning_normalized," / ",observations.back().meaning_equal)
		check(migrated.recovery_pending and migrated.paused and migrated.ctx==raw_old.context and same(live(migrated),normalized_old),"shipping owner binds interrupted raw schema1 marker without default or upgrade")
		await click(migrated,"RETRY IMPORT"); check(not migrated.recovery_pending and migrated.paused and migrated.ctx==Store.decode(old_target).context and same(live(migrated),Store.decode(Store.encode(Store.decode(old_target).context,0))) and same(Store.read(),Store.decode(old_target)),"shipping owner resolves raw schema1 whole migration with both views paused")
		migrated.queue_free(); await ticks()
		for use_import in [false,true]:
			var v1_io:=JournalFault.new(); v1_io.files[Store.PATH+"0"]=old_code; var v1_helper:=Journal.new(v1_io,true); v1_helper.begin(old_code,old_target)
			var prototype: Node=load("res://main.tscn").instantiate(); prototype.files=v1_io; root.add_child(prototype); prototype.set_physics_process(false); await ticks()
			check(prototype.recovery_pending and prototype.state==Store.decode(old_code).context.legacy,"raw schema1 prototype binds original bullets/settings")
			for button in prototype.recovery_panel.find_children("*","Button",true,false):
				if button.text==("RETRY IMPORT" if use_import else "KEEP PREVIOUS WHOLE SAVE"):
					button.get_parent().get_parent().ensure_control_visible(button); await ticks(); await tap(button.get_global_rect().get_center(),button.text); break
			var wanted: Dictionary=Store.decode(old_target if use_import else old_code)
			check(not prototype.recovery_pending and prototype.paused and prototype.state==wanted.context.legacy and prototype.settings==wanted.context.settings and same(Store.read(Store.PATH,v1_io),wanted),"raw schema1 prototype verified choice retains exact full supported meaning")
			prototype.queue_free(); await ticks()
		var gate_io:=JournalFault.new(); gate_io.files[Store.PATH+"0"]=old_code; var journey_helper:=Journal.new(gate_io); journey_helper.begin(fixture(2),fixture(0,99)); var gate_raw: Dictionary=gate_io.files.duplicate(true)
		var gated: Node=load("res://main.tscn").instantiate(); gated.files=gate_io; root.add_child(gated); gated.set_physics_process(false); await ticks()
		check(gated.recovery_pending and not gated.recovery_status.ok and gate_io.files==gate_raw,"standalone v1 owner fails closed on journey-format marker without dropping whole context")
		gated.start_run(); gated.toggle_sound(); gated.persist(); check(gate_io.files==gate_raw,"format-gated prototype cannot overwrite journey/default")
		gated.queue_free(); await ticks()
	if section("compatibility"):
		# Genuine code4 app-owned active slots are retained as migration-only inputs.
		var genuine_path:="res://tests/fixtures/code4-midroad/dead-run-save-"
		var genuine:=Store.read(genuine_path); check(genuine.ok and C.catalog1(genuine.context.campaign) and genuine.context.campaign.phase=="playing","genuine code4 fixture remains an active pinned catalog1 road")
		var genuine_code:=FileAccess.get_file_as_string(genuine_path+str(genuine.slot))
		var io:=JournalFault.new(); io.files[Store.PATH+"0"]=fixture(2); var game:=await boot(io); await click(game,"SAVE / TRANSFER"); ui(game).code_box.text=genuine_code; io.unreadable_after=1; await click(game,"IMPORT")
		check(game.recovery_pending and Copies.new(io).get_code(genuine_code.sha256_text()).text==genuine_code,"genuine old active intake archived byte-exact through actual legacy Import")
		reset_fault(io); await click(game,"RETRY IMPORT"); check(not game.recovery_pending and game.paused and same(live(game),genuine) and C.catalog1(game.state),"explicit old active import retains full code4 rules, bullets, profile and both bodies")
		check(same(Store.read(Store.PATH,io),genuine),"genuine old active imported context is fully durable before adoption")
		game.queue_free(); await ticks()
		# Existing ready upgrade is selected separately and its exact intake remains retrievable.
		var incoming: Dictionary=Store.decode(fixture(0)).context; var Catalog1=load("res://scripts/catalog1_rules.gd"); incoming.campaign=Catalog1.fresh(5,"lance")
		var intake:=Store.encode(incoming,99); var chosen: Dictionary=incoming.duplicate(true); Store.upgrade(chosen)
		var upgrade_io:=JournalFault.new(); upgrade_io.files[Store.PATH+"0"]=fixture(2); var upgraded:=await boot(upgrade_io); await click(upgraded,"SAVE / TRANSFER"); ui(upgraded).code_box.text=intake; await click(upgraded,"IMPORT")
		check(not upgraded.recovery_pending and upgraded.paused and same(live(upgraded),Store.decode(Store.encode(chosen,0))) and not C.catalog1(upgraded.state),"actual accepted ready intake retains existing upgrade policy and whole selected context")
		check(Copies.new(upgrade_io).get_code(intake.sha256_text()).text==intake,"actual ready upgrade preserves byte-exact original intake separately")
		upgraded.queue_free(); await ticks()
		var Policy=load("res://tests/campaign_policy.gd")
		for wins in [false,true]:
			var terminal: Dictionary=Store.decode(fixture(1)).context; terminal.campaign=C.fresh(0,"rivet"); terminal.campaign.phase="playing"
			while terminal.campaign.phase=="playing":
				if wins and terminal.campaign.tick%12==0: C.steer(terminal.campaign,Policy.aim(terminal.campaign,"rescue"))
				C.step(terminal.campaign)
			Store.award(terminal)
			check(terminal.campaign.phase==("victory" if wins else "defeat") and Store.valid(terminal),"terminal fixture is derived by actual rules/policy, not phase injection")
			var code:=Store.encode(terminal,31); var terminal_io:=JournalFault.new(); terminal_io.files[Store.PATH+"0"]=code; var terminal_helper:=Journal.new(terminal_io); terminal_helper.begin(code,fixture(0,99)); terminal_io.unreadable_after=1; terminal_helper.resolve(true)
			reset_fault(terminal_io); materialize(terminal_io); var cold:=await physical_boot(); check(cold.recovery_pending and same(live(cold),Store.decode(code)),"pending terminal original retains all ledgers/rewards before selection")
			await click(cold,"KEEP PREVIOUS WHOLE SAVE"); check(not cold.recovery_pending and cold.paused and same(live(cold),Store.decode(code)) and cold.transfer_status.text.contains("Retry"),"terminal whole recovery adopts paused with phase-aware Retry feedback")
			cold.queue_free(); await ticks()
	var output:={"checks":checks,"failures":failures,"events":events,"observations":observations,"limits":"Synthetic complete records, typed faults, actual touch and same-process real-file fresh owners; not OS kill/native/power-loss/render proof."}
	var file:=FileAccess.open(folder.path_join("import-recovery.json"),FileAccess.WRITE); file.store_string(JSON.stringify(output)); file.close()
	print("DEAD_IMPORT_RECOVERY ",checks," / ",failures.size()," failures / ",events.size()," events"); quit(0 if failures.is_empty() else 1)
