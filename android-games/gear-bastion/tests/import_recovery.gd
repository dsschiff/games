extends "res://tests/save_recovery.gd"
const Journal = preload("res://scripts/import_recovery.gd")
const Copies = preload("res://scripts/recovery_copies.gd")
class JournalFault extends Fault:
	var local_mode := ""
	var one_path := ""
	var one_reads := 0
	func read_text(path: String) -> String:
		if local_mode=="one_read" and path==one_path:
			one_reads+=1
			if one_reads>1: return "unreadable"
		if local_mode=="journal_stage_read" and path.ends_with(".import-pending.tmp"): return "unreadable"
		return super.read_text(path)
	func write_text(path: String,text: String) -> bool:
		if local_mode=="archive_failure" and path.begins_with(Copies.PREFIX): return false
		return super.write_text(path,text)
	func remove(path: String) -> bool:
		if local_mode=="cleanup_failure" or (local_mode=="partial_cleanup" and path.ends_with(".import-pending.tmp")): return false
		if local_mode=="cleanup_lie": return true
		return super.remove(path)
func hold_check(game: Node,io: JournalFault,original: Dictionary) -> void:
	var writes: int=io.write_count; var prior_profile: Dictionary=game.profile.duplicate(true); var prior_settings: Dictionary=game.settings.duplicate(true)
	var old_undo: Array=game.undo_board.duplicate(true); var old_speed: int=game.speed
	game.retry(); game.start_mission("tutorial"); game.request_mission("camp_01"); game.act("begin"); game.act("mute"); game.act("effects"); game.act("undo"); game.act("tutorial"); game.act("map")
	game.press(game.cell_center(2,1)); game.release(game.cell_center(1,1)); game.advance(30); game.persist(); game._process(6); game.notification(Node.NOTIFICATION_APPLICATION_PAUSED); game.handle_back()
	check(game.recovery_pending and game.paused and same(live(game),original),"pending freezes whole state/profile/settings across every mutation route")
	check(io.write_count==writes and game.profile==prior_profile and game.settings==prior_settings and game.undo_board==old_undo and game.speed==old_speed,"pending blocks paused autosave/lifecycle and retains undo/speed")
func reset_fault(io: JournalFault) -> void:
	io.local_mode=""; io.fail_suffix=""; io.fail_mode=""; io.bad_destination_suffix=""; io.bad_destination_mode=""; io.unreadable_after=0; io.promoted=""
func materialize(io: JournalFault) -> void:
	var user:=ProjectSettings.globalize_path("user://")
	check(user.replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"materialized bootstrap remains in isolated data")
	for name in DirAccess.get_files_at(user):
		if name.begins_with("bastion-save.json") or name.begins_with("gear-recovery-copy-"): DirAccess.remove_absolute(user.path_join(name))
	for path in io.files:
		var f:=FileAccess.open(path,FileAccess.WRITE); f.store_string(io.files[path]); f.close()
func physical_boot() -> Node:
	var game: Node=load("res://main.tscn").instantiate(); root.add_child(game); current_scene=game; await ticks(); return game
func journal_prefix() -> String: return Store.PATH+".import-pending"
func choose(game: Node,use_import: bool) -> void:
	await dialog_button(game,"Retry Import" if use_import else "Keep previous whole save")
func run() -> void:
	check(ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"all physical data stays isolated")
	if not failures.is_empty(): quit(1); return
	for original_kind in [0,1,2]:
		for incoming_kind in [0,1,2]:
			for use_import in [false,true]:
				var source:=fixture(original_kind); var target:=fixture(incoming_kind,90)
				var io:=JournalFault.new(); io.files[Store.PATH]=source
				var game:=await boot(io); await tap(game.get_global_transform_with_canvas()*game.buttons().save.get_center(),"Save")
				var before:=live(game); game.undo_board=game.state.board.duplicate(true); game.speed=2
				game.save_text.text=target; io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1
				await dialog_button(game,"Import")
				check(game.recovery_pending and game.paused and same(live(game),before),"uncertain actual import retains full original context")
				check(not game.save_text.visible and game.recovery_summary.text.contains("PREVIOUS WHOLE SAVE") and game.recovery_summary.text.contains("IMPORTED WHOLE SAVE"),"pending whole-save summaries lead instead of raw code")
				hold_check(game,io,before)
				await dialog_button(game,"View previous code"); check(game.save_text.text==game.recovery.original_code and not game.save_text.editable,"previous exact full code export is read-only")
				await dialog_button(game,"View imported code"); check(game.save_text.text==target and not game.save_text.editable,"incoming exact full code export is read-only")
				game.queue_free(); await ticks(); reset_fault(io); materialize(io)
				var cold:=await physical_boot()
				check(cold.recovery_pending and cold.paused and same(live(cold),before),"materialized-file fresh bootstrap chooses whole journal original")
				await choose(cold,use_import); await ticks()
				var wanted: Dictionary=Store.decode(target) if use_import else before
				check(not cold.recovery_pending and cold.paused and same(live(cold),wanted),"actual explicit choice adopts full verified context immediately")
				check(same(Store.read(),wanted) and not FileAccess.file_exists(journal_prefix()) and not FileAccess.file_exists(journal_prefix()+".tmp"),"chosen full disk context verified before recovery marker disappears")
				cold.queue_free(); await ticks(); var settled:=await physical_boot()
				check(not settled.recovery_pending and same(live(settled),wanted),"settled cold bootstrap retains chosen full context")
				settled.queue_free(); await ticks()
	for fault in ["archive_failure","journal_rename","journal_missing","journal_corrupt","journal_stage_read","active_missing","active_corrupt","active_stale","active_read1","active_read2","cleanup_failure","cleanup_lie"]:
		var io:=JournalFault.new(); var source:=fixture(0); var target:=fixture(2,90); io.files[Store.PATH]=source
		if fault in ["archive_failure","journal_stage_read","cleanup_failure","cleanup_lie"]: io.local_mode=fault
		if fault=="journal_rename": io.fail_suffix=".import-pending.tmp"; io.fail_mode="rename"
		if fault in ["journal_missing","journal_corrupt"]: io.bad_destination_suffix=".import-pending"; io.bad_destination_mode=fault.trim_prefix("journal_")
		if fault in ["active_missing","active_corrupt","active_stale"]: io.bad_destination_suffix="bastion-save.json"; io.bad_destination_mode=fault.trim_prefix("active_"); io.stale_destination=fixture(1,1)
		if fault in ["active_read1","active_read2"]: io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1 if fault=="active_read1" else 2
		var helper:=Journal.new(io); var began:=helper.begin(source,target)
		var result: Dictionary=helper.resolve(true) if began.ok else {"ok":false}
		check(not result.ok,"fault cannot claim verified choice: "+fault)
		if fault=="archive_failure": check(not began.pending and io.files[Store.PATH]==source,"failed preservation stops before marker/active writes")
		else: check(began.pending,"uncertain transaction remains pending: "+fault)
		reset_fault(io); materialize(io); var cold:=await physical_boot()
		var marker: bool=FileAccess.file_exists(journal_prefix()) or FileAccess.file_exists(journal_prefix()+".tmp")
		check((cold.recovery_pending and cold.paused) if marker else (not cold.recovery_pending and same(live(cold),Store.decode(source))),"fresh bootstrap never silently adopts unconfirmed incoming/default: "+fault)
		if cold.recovery_pending and cold.recovery_status.ok:
			check(same(live(cold),Store.decode(source)),"readable pending restores original whole context: "+fault)
			await choose(cold,false); check(not cold.recovery_pending and same(live(cold),Store.decode(source)),"explicit rollback verifies whole original: "+fault)
		cold.queue_free(); await ticks()
	# Live unsaved settings are distinct from every raw candidate and incoming code.
	var all_io:=JournalFault.new(); var raw_codes: Array[String]=[]
	for slot in ["", ".tmp", ".bak", ".bak.tmp"]:
		var raw:=fixture(raw_codes.size()%3,11+raw_codes.size()); raw_codes.append(raw); all_io.files[Store.PATH+slot]=raw
	var live_code:=fixture(0,0); var incoming_code:=fixture(2,99)
	var all_helper:=Journal.new(all_io); check(all_helper.begin(live_code,incoming_code).ok and all_helper.record.copies.size()==6,"journal preserves whole live, incoming and all four distinct valid raw slots")
	for code in raw_codes+[live_code,incoming_code]:
		var archived:=Copies.new(all_io).get_code(code.sha256_text()); check(archived.ok and archived.text==code,"raw full code archived exactly before active mutation")
	check(all_helper.resolve(true).ok,"all-slot preservation allows a verified explicit import")
	for code in raw_codes+[live_code,incoming_code]: check(Copies.new(all_io).get_code(code.sha256_text()).text==code,"all prior raw full codes remain retrievable after import")
	var unsaved_io:=JournalFault.new(); unsaved_io.files[Store.PATH]=fixture(1); var unsaved:=await boot(unsaved_io)
	await tap(unsaved.get_global_transform_with_canvas()*unsaved.buttons().resume_run.get_center(),"Resume saved run")
	unsaved_io.fail_suffix=".bak.tmp"; unsaved_io.fail_mode="write"
	await tap(unsaved.get_global_transform_with_canvas()*unsaved.buttons().menu.get_center(),"Menu unsaved")
	var mute: Button=unsaved.menu_dialog.find_child("Action_mute",true,false)
	await tap(Vector2(unsaved.menu_dialog.position)+mute.get_global_rect().get_center(),"Sound unsaved")
	var unsaved_context:=live(unsaved); check(not same(unsaved_context,Store.read(Store.PATH,unsaved_io)) and unsaved.save_failed,"actual settings input creates honest unsaved whole live context under storage failure")
	await tap(unsaved.get_global_transform_with_canvas()*unsaved.buttons().menu.get_center(),"Menu export unsaved")
	var export_button: Button=unsaved.menu_dialog.find_child("Action_save",true,false)
	await tap(Vector2(unsaved.menu_dialog.position)+export_button.get_global_rect().get_center(),"Save unsaved")
	reset_fault(unsaved_io)
	unsaved.save_text.text=fixture(2,99); unsaved_io.unreadable_destination_suffix="bastion-save.json"; unsaved_io.unreadable_after=1
	await dialog_button(unsaved,"Import"); check(unsaved.recovery_pending and same(live(unsaved),unsaved_context),"uncertain Import retains unsaved settings together with state and profile")
	unsaved.queue_free(); await ticks(); reset_fault(unsaved_io); materialize(unsaved_io); var unsaved_cold:=await physical_boot()
	check(unsaved_cold.recovery_pending and same(live(unsaved_cold),unsaved_context),"fresh bootstrap restores the archived unsaved live context, not prior disk settings")
	await choose(unsaved_cold,false); check(not unsaved_cold.recovery_pending and same(Store.read(),unsaved_context) and same(live(unsaved_cold),unsaved_context),"Keep Previous commits exact unsaved whole context before adoption")
	unsaved_cold.queue_free(); await ticks()
	# Torn or temporarily unreadable markers/archives fail closed without default writes.
	for fault in ["base_torn","stage_torn","both_torn","archive_torn","archive_missing","journal_unreadable"]:
		var blocked_io:=JournalFault.new(); blocked_io.files[Store.PATH]=fixture(1)
		var blocked_helper:=Journal.new(blocked_io); blocked_helper.begin(fixture(0),fixture(2,99))
		if fault=="base_torn": blocked_io.files[journal_prefix()]="torn"
		if fault=="stage_torn": blocked_io.files[journal_prefix()+".tmp"]="torn"; blocked_io.files.erase(journal_prefix())
		if fault=="both_torn": blocked_io.files[journal_prefix()]="torn"; blocked_io.files[journal_prefix()+".tmp"]="torn"
		if fault=="archive_torn": blocked_io.files[Copies.PREFIX+blocked_helper.record.original]="torn"
		if fault=="archive_missing": blocked_io.files.erase(Copies.PREFIX+blocked_helper.record.original)
		if fault=="journal_unreadable": blocked_io.local_mode="one_read"; blocked_io.one_path=journal_prefix(); blocked_io.one_reads=1
		var blocked:=await boot(blocked_io); var old_files: Dictionary=blocked_io.files.duplicate(true)
		check(blocked.recovery_pending and blocked.paused and not blocked.recovery_status.ok,"torn/unreadable recovery blocks ordinary startup: "+fault)
		blocked.act("begin"); blocked.act("mute"); blocked.retry(); blocked.start_mission("camp_01"); blocked.persist(); blocked._process(6); blocked.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		check(blocked_io.files==old_files and blocked.recovery_pending and blocked.paused,"unknown recovery never writes a default or enables continuation: "+fault)
		blocked.queue_free(); await ticks()
	# All journal stage failures happen before any active slot mutation.
	for stage_fault in ["write","flush","readback","rename"]:
		var stage_io:=JournalFault.new(); stage_io.files[Store.PATH]=fixture(0); stage_io.fail_suffix=".import-pending.tmp"; stage_io.fail_mode=stage_fault
		var stage_helper:=Journal.new(stage_io); var result:=stage_helper.begin(fixture(0),fixture(2,99))
		check(result.pending and not result.ok and stage_io.files[Store.PATH]==fixture(0),"journal stage fault cannot mutate active: "+stage_fault)
		reset_fault(stage_io); materialize(stage_io); var stage_cold:=await physical_boot()
		check(stage_cold.recovery_pending and stage_cold.paused,"materialized journal-stage uncertainty remains blocked: "+stage_fault)
		stage_cold.queue_free(); await ticks()
	# Cleanup may remove primary marker but must retain its valid stage and block adoption.
	var partial_io:=JournalFault.new(); partial_io.files[Store.PATH]=fixture(0); var partial_helper:=Journal.new(partial_io)
	partial_helper.begin(fixture(0),fixture(2,99)); partial_io.files[journal_prefix()+".tmp"]=partial_io.files[journal_prefix()]; partial_io.local_mode="partial_cleanup"
	check(not partial_helper.resolve(true).ok and not partial_io.files.has(journal_prefix()) and partial_io.files.has(journal_prefix()+".tmp"),"partial cleanup cannot claim success after removing only primary marker")
	reset_fault(partial_io); materialize(partial_io); var partial_cold:=await physical_boot()
	check(partial_cold.recovery_pending and same(live(partial_cold),Store.decode(fixture(0))),"fresh bootstrap uses retained stage after partial cleanup")
	await choose(partial_cold,true); check(not partial_cold.recovery_pending and same(live(partial_cold),Store.decode(fixture(2,99))),"stage-marker recovery can explicitly finish verified Import")
	partial_cold.queue_free(); await ticks()
	# Supported legacy schema3 and Iron Trial plus real-rule terminal states retain whole meaning.
	var terminal:=Store.decode(fixture(2)); var Policy=load("res://tests/campaign_policies.gd")
	var special_codes: Array[String]=[]
	for win in [false,true]:
		var special:=Battle.initial(1701,"camp_01")
		if win: Policy.apply(special,"A")
		Battle.start(special)
		while special.phase=="battle": Battle.tick(special,Battle.STEP)
		check(special.phase==("victory" if win else "defeat"),"terminal recovery fixture derived by actual rules, not phase injection")
		special_codes.append(Store.encode(special,terminal.settings,4,true,terminal.profile))
	var legacy: Dictionary=JSON.parse_string(fixture(0)); legacy.version=3; legacy.state=legacy.active_run; legacy.erase("active_run")
	special_codes.append(JSON.stringify(legacy)); special_codes.append(Store.encode(Battle.initial(1701,"iron_trial"),terminal.settings,4,true,terminal.profile))
	for code in special_codes:
		check(Store.decode(code).ok,"supported special whole context validates before recovery")
		var special_io:=JournalFault.new(); special_io.files[Store.PATH]=code; var special_helper:=Journal.new(special_io)
		special_helper.begin(code,fixture(1,99)); special_io.unreadable_destination_suffix="bastion-save.json"; special_io.unreadable_after=1; special_helper.resolve(true)
		reset_fault(special_io); materialize(special_io); var special_cold:=await physical_boot()
		check(special_cold.recovery_pending and same(live(special_cold),Store.decode(code)),"special terminal/practice/schema3 original survives uncertain imported primary")
		await choose(special_cold,false); check(special_cold.paused and same(live(special_cold),Store.decode(code)) and same(Store.read(),Store.decode(code)),"special previous whole meaning is verified before synchronous adoption")
		special_cold.queue_free(); await ticks()
	for dimensions in [Vector2i(1080,2520),Vector2i(1968,2184),Vector2i(2184,1968)]:
		root.size=dimensions
		var fit_io:=JournalFault.new(); fit_io.files[Store.PATH]=fixture(0); var fit_helper:=Journal.new(fit_io); fit_helper.begin(fixture(0),fixture(2,99))
		var fit:=await boot(fit_io); var view:=root.get_visible_rect().size; fit.safe_area_override=Rect2(25,40,view.x-60,view.y-90); fit.refresh_layout(); fit.show_recovery(); await ticks()
		check(fit.usable.encloses(Rect2(Vector2(fit.save_dialog.position),Vector2(fit.save_dialog.size))),"CPU recovery modal client fits emulated inset cover/inner/landscape")
		await dialog_button(fit,"View imported code"); check(fit.save_text.text==fixture(2,99) and fit.recovery_pending,"scrolled code view remains reachable in CPU inset layout")
		await choose(fit,false); check(not fit.recovery_pending and fit.paused and same(live(fit),Store.decode(fixture(0))),"actual recovery choice is reachable after code view in CPU inset layout")
		fit.queue_free(); await ticks()
	root.size=Vector2i(600,1066)
	# A sole backup-stage promotion with a transient read must restore exact bytes.
	for mode in ["missing","corrupt","stale","unreadable"]:
		var io:=JournalFault.new(); var source:=fixture(0); io.files[Store.PATH+".bak.tmp"]=source
		if mode=="unreadable": io.unreadable_destination_suffix=".bak"; io.unreadable_after=1
		else: io.bad_destination_suffix=".bak"; io.bad_destination_mode=mode; io.stale_destination=fixture(1,1)
		var target:=Store.decode(fixture(2)); check(not Store.write(target.state,target.settings,Store.PATH,io,false,target.profile),"bad sole-stage backup promotion returns false: "+mode)
		reset_fault(io); check(io.files.get(Store.PATH+".bak.tmp")==source and same(Store.read(Store.PATH,io),Store.decode(source)),"exact consumed sole stage restored and cold-readable: "+mode)
	# Single successful journal/archive read window binds startup without rereads.
	for file_kind in ["journal","archive"]:
		var io:=JournalFault.new(); io.files[Store.PATH]=fixture(2)
		var helper:=Journal.new(io); helper.begin(fixture(0),fixture(2,90))
		io.local_mode="one_read"; io.one_path=journal_prefix() if file_kind=="journal" else Copies.PREFIX+helper.record.original
		var game:=await boot(io)
		check(game.recovery_pending and game.paused and same(live(game),Store.decode(fixture(0))) and io.one_reads==1,"one startup decision binds context without rereading "+file_kind)
		game.queue_free(); await ticks()
	# Marker/cleanup uncertainty and retained-helper admission must be idempotent.
	var io:=JournalFault.new(); io.files[Store.PATH]=fixture(0); var helper:=Journal.new(io); helper.begin(fixture(0),fixture(2,90)); check(helper.resolve(true).ok and not helper.journal_ready,"successful clear invalidates admission to future active writes")
	io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1
	check(not helper.resolve(false).ok and io.files.has(journal_prefix()),"retained helper re-establishes marker before another uncertain write")
	reset_fault(io); materialize(io); var reopened:=await physical_boot(); check(reopened.recovery_pending and same(live(reopened),Store.decode(fixture(0))),"retained helper uncertainty survives fresh bootstrap")
	reopened.queue_free(); await ticks()
	var output:={"checks":checks,"failures":failures,"events":events,"limits":"Synthetic full schema4 contexts, typed faults, actual ScreenTouch, materialized-file bootstrap; not OS-kill/native/power-loss/render proof."}
	var f:=FileAccess.open(folder.path_join("import-recovery.json"),FileAccess.WRITE); f.store_string(JSON.stringify(output)); f.close()
	print("GEAR_IMPORT_RECOVERY ",checks," / ",failures.size()," failures / ",events.size()," touch events"); quit(0 if failures.is_empty() else 1)
