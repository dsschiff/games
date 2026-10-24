extends "res://tests/save_reliability.gd"
const Journal=preload("res://scripts/import_recovery.gd")
const Copies=preload("res://scripts/recovery_copies.gd")
class RecoveryFault extends Faults:
	var mode:=""
	var promoted:=""
	var destination_reads:=0
	var one_path:=""
	var one_reads:=0
	var writes:=0
	var active_writes:=0
	var unadmitted:=0
	var guarded:=false
	func read_text(path: String) -> String:
		if path==one_path:
			one_reads+=1
			if one_reads>1: return "one-read window closed"
		if path==promoted and mode in ["read1","read2"]:
			destination_reads+=1
			if destination_reads>=(1 if mode=="read1" else 2): return "unreadable destination"
		if mode=="stage_read" and path==S.PATH+"import-pending.tmp": return "unreadable stage"
		return super.read_text(path)
	func write_text(path: String,code: String) -> bool:
		writes+=1
		if path in [S.PATH+"0.tmp",S.PATH+"1.tmp"]:
			active_writes+=1
			if guarded and not admitted(): unadmitted+=1
		if mode=="archive_write" and path.begins_with(Copies.PREFIX): return false
		if mode=="active_write" and path in [S.PATH+"0.tmp",S.PATH+"1.tmp"]: return false
		if mode=="stage_write" and path==S.PATH+"import-pending.tmp": return false
		return super.write_text(path,code)
	func rename(from: String,to: String) -> bool:
		if mode=="stage_rename" and to==S.PATH+"import-pending": return false
		if mode=="stage_missing" and to==S.PATH+"import-pending": files.erase(from); files.erase(to); return true
		if to in [S.PATH+"0",S.PATH+"1"]:
			if mode=="active_rename": return false
			if mode=="active_missing": files.erase(from); files.erase(to); return true
			if mode=="active_corrupt": files.erase(from); files[to]="torn active destination"; return true
			if mode=="active_stale": files.erase(from); return true
		var okay:=super.rename(from,to)
		if okay and to in [S.PATH+"0",S.PATH+"1"]: promoted=to; destination_reads=0
		return okay
	func remove(path: String) -> bool:
		if mode=="cleanup" or mode=="partial_cleanup" and path==S.PATH+"import-pending.tmp": return false
		files.erase(path); return true
	func admitted() -> bool:
		var found:=false; var record:={}
		for suffix in ["", ".tmp"]:
			var path: String=S.PATH+"import-pending"+suffix
			if not files.has(path): continue
			var parsed:=Journal.decode(read_text(path))
			if not parsed.ok or found and parsed.record!=record: return false
			record=parsed.record; found=true
		if not found: return false
		for id in record.copies:
			if not Copies.new(self).get_code(id).ok: return false
		return true
class BlockedRoot extends "res://scripts/bootstrap.gd":
	var block_adoption:=false
	func adopt_verified(code: String,backend: Variant=null) -> bool:
		return false if block_adoption else super.adopt_verified(code,backend)
func decoded_context(owner: Node) -> Dictionary:
	return {"state":owner.state.duplicate(true),"profile":owner.profile.duplicate(true),"settings":owner.settings.duplicate(true),"campaign":owner.campaign_profile.duplicate(true)}
func exact(a: Dictionary,b: Dictionary) -> bool:
	return a.state==b.state and a.profile==b.profile and a.settings==b.settings and a.campaign==b.campaign
func whole_code(context: Dictionary) -> String: return S.encode(context.state,context.profile,context.settings,1,true,context.campaign)
func reset_fault(io: RecoveryFault) -> void:
	io.mode=""; io.one_path=""; io.one_reads=0; io.promoted=""; io.destination_reads=0; io.fail_write=false; io.fail_rename=false; io.missing_destination=false; io.corrupt_destination=false
func marker_text(record: Dictionary) -> String:
	var payload:=JSON.stringify(record); return JSON.stringify({"payload":payload,"sha256":payload.sha256_text()})
func fixture_io(context: Dictionary) -> RecoveryFault:
	var io:=RecoveryFault.new(); io.files[S.PATH+"0"]=whole_code(context); return io
func open_owner(io: RecoveryFault) -> void:
	await shutdown(); game_root=BlockedRoot.new(); game_root.save_io=io; root.add_child(game_root); await process_frame
	scene=game_root.get_node("Battle"); scene.set_physics_process(false); await process_frame
func action(title: String) -> void:
	var chosen: Button
	for b in scene.find_children("*","Button",true,false):
		if b.text==title and b.is_visible_in_tree() and not b.disabled: chosen=b; break
	check(chosen!=null,"actual reachable action "+title)
	if chosen==null: return
	var parent: Node=chosen.get_parent()
	while parent!=null and not parent is ScrollContainer: parent=parent.get_parent()
	if parent is ScrollContainer: parent.ensure_control_visible(chosen); await process_frame; await process_frame
	check(parent==null or parent.get_global_rect().encloses(chosen.get_global_rect()),"action inside scroll bounds "+title)
	await tap(chosen.get_global_rect().get_center(),title); await process_frame
	if is_instance_valid(game_root) and game_root.has_node("Battle"): scene=game_root.get_node("Battle"); scene.set_physics_process(false)
func records() -> Array:
	var list: Array=[]
	for mode in [1,2]:
		for phase in ["ready","playing","victory","defeat"]:
			var f: Dictionary=fixtures.source
			var context:={"state":f.legacy.duplicate(true) if mode==1 else f.active.duplicate(true),"profile":f.profile.duplicate(true),"settings":f.settings.duplicate(true),"campaign":f.campaign.duplicate(true)}
			if phase=="ready": context.state=R.fresh() if mode==1 else C.fresh(Cat.definition(0))
			elif phase=="victory": context.state=fixtures.incoming.legacy.duplicate(true) if mode==1 else fixtures.incoming.active.duplicate(true)
			elif phase=="defeat":
				context.state=R.fresh() if mode==1 else C.fresh(Cat.definition(0)); context.state.phase="playing"
				for tick in 20000:
					if context.state.phase!="playing": break
					if mode==1: R.tick(context.state,Vector2.ZERO,1.0/60)
					else: C.tick(context.state,Vector2.ZERO,1.0/60)
				if mode==1: R.finish(context.state,context.profile)
				else: C.finish(context.state,context.campaign)
			var d:=S.decode(whole_code(context)); check(d.ok,"complete rule-derived mode/phase fixture validates "+str(mode)+phase)
			list.append(d)
	return list
func freeze(io: RecoveryFault,previous: Dictionary) -> void:
	var files: Dictionary=io.files.duplicate(true); var writes: int=io.writes
	var clock: float=scene.save_clock
	scene.begin(); scene.retry(); scene.build_nearby(); scene.toggle_pause(); scene.back(); scene.toggle_sound(); scene.toggle_effects(); scene.open_campaign(); scene.route_reload(); scene.open_transfer(); scene.close_transfer(); scene.copy_code(); scene.paste_code(); scene.import_code(); scene.save_now(); scene._physics_process(5)
	if scene.has_method("invest"):
		scene.invest(0); scene.arm_action(0); scene.open_journey(); scene.close_journey(); scene.choose_stage(0); scene.choose_endless(); scene.request_definition(Cat.definition(0)); scene.confirm_replace(); scene.cancel_replace(); scene.cycle_seed(); scene.cycle_budget(); scene.cycle_mirror(); scene.next_watch(); scene.show_ending(); scene.close_ending(); scene.return_legacy()
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED); scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var key:=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=true; Input.parse_input_event(key); await process_frame
	key.pressed=false; Input.parse_input_event(key); await process_frame
	check(scene.recovery_pending and scene.paused and exact(decoded_context(scene),previous) and scene.save_clock==clock,"pending freezes complete current context and all mutation/input/lifecycle routes")
	check(io.files==files and io.writes==writes,"pending blocks all autosave/direct/mode/lifecycle writes")
func selected(part: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--part="): return arg=="--part="+part
	return true
func run() -> void:
	root.size=Vector2i(720,1280); fixtures=build_fixtures(); var list:=records()
	for index in (range(list.size()) if selected("matrix") else []):
		for use_import in [false,true]:
			print("MATRIX ",index," / ",use_import)
			var context: Dictionary=list[index]; var target: Dictionary=list[(index+3)%list.size()]
			var io:=fixture_io(context); await open_owner(io)
			if not scene.paused: await action("II")
			await action("SAVE / TRANSFER"); var previous:=decoded_context(scene); var target_code:=whole_code(target)
			scene.code_edit.text=target_code; io.mode="read1"; io.guarded=true; await action("IMPORT")
			check(scene.recovery_pending and scene.paused and exact(decoded_context(scene),previous),"uncertain actual Import retains whole mode/phase owner")
			if not scene.recovery_pending: await shutdown(); quit(1); return
			await freeze(io,previous)
			var original_code: String=scene.recovery.original_code
			await action("VIEW PREVIOUS CODE"); check(scene.recovery_code.text==original_code and not scene.recovery_code.editable,"previous View exposes exact complete retained code")
			await action("VIEW IMPORTED CODE"); check(scene.recovery_code.text==target_code,"incoming View preserves exact intake code")
			reset_fault(io); await open_owner(io)
			check(scene.recovery_pending and scene.paused and exact(decoded_context(scene),previous),"fresh bootstrap binds original before owner initialization/default save")
			await action("RETRY IMPORT" if use_import else "KEEP PREVIOUS WHOLE SAVE")
			var wanted: Dictionary=S.decode(target_code if use_import else original_code)
			check(not scene.recovery_pending and scene.paused and exact(decoded_context(scene),wanted) and exact(S.read(S.PATH,io),wanted),"explicit whole choice adopts correct schema/profile/parked/settings paused and durable")
			check(io.unadmitted==0,"every active Import write had current complete marker/archive admission")
			check(Copies.new(io).get_code(original_code.sha256_text()).get("text")==original_code and Copies.new(io).get_code(target_code.sha256_text()).get("text")==target_code,"both complete original/intake archives remain exact after success")
	if selected("edges"):
		await extra_cases(list)
		await standalone_unknown_choices(list)
	if selected("markers"):
		await marker_cases(list)
		await sole_marker_choices(list)
		await active_destination_choices(list)
	if selected("layout"):
		await copy_layout_cases(list)
		await unknown_to_known_layout(list)
	await shutdown(); await process_frame
	FileAccess.open(folder.path_join("import-recovery.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details,"events":events,"observations":observations,"scope":"Synthetic complete rule-derived legacy/campaign and ready/active/terminal profiles/settings/parked records; actual ScreenTouch/keys, typed storage faults and fresh real bootstrap owners. Cached headless/Dummy, no OS clipboard/native/render/power-loss claim."},"  "))
	print("IMPORT_RECOVERY ",checks," failures=",failures); print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
func extra_cases(list: Array) -> void:
	# Original full live code and all four valid raw candidates are independent.
	var io:=fixture_io(list[1]); await open_owner(io)
	io.mode="active_write"; await action(scene.sound_button.text); var live:=decoded_context(scene)
	check(scene.save_problem and scene.settings.sound!=S.read(S.PATH,io).settings.sound,"actual sound touch creates honest unsaved live settings")
	reset_fault(io); await action("SAVE / TRANSFER")
	var raw: Array[String]=[]
	for slot in 2:
		for suffix in ["", ".tmp"]:
			var d: Dictionary=list[raw.size()]; var code:=S.encode(d.state,d.profile,d.settings,20+raw.size(),true,d.campaign); raw.append(code); io.files[S.PATH+str(slot)+suffix]=code
	var incoming:=whole_code(list[6]); scene.code_edit.text=incoming; io.mode="read1"; await action("IMPORT")
	check(scene.recovery.record.copies.size()==6 and exact(decoded_context(scene),live),"unsaved live settings and all four distinct raw codes preserved before admission")
	for code in raw+[scene.recovery.original_code,incoming]: check(Copies.new(io).get_code(code.sha256_text()).get("text")==code,"all six exact full codes retained")
	# One validated startup decision spans the former bootstrap/owner read window.
	for which in ["marker","original","incoming"]:
		reset_fault(io); var helper:=Journal.new(io); var status:=helper.read(); check(status.ok,"startup context remains recoverable")
		io.one_path=S.PATH+"import-pending" if which=="marker" else Copies.PREFIX+helper.record[which]; io.one_reads=0
		await open_owner(io)
		check(io.one_reads==1 and scene.recovery_pending and exact(decoded_context(scene),live),"single journal/archive bootstrap decision for "+which)
	# Unknown/torn marker and unreadable active state never write a default.
	for kind in ["marker_with_active","marker_without_active","active_unreadable"]:
		var unknown:=RecoveryFault.new()
		if kind!="active_unreadable": unknown.files[S.PATH+"import-pending"]="torn"
		if kind=="marker_with_active": unknown.files[S.PATH+"0"]=whole_code(list[1])
		if kind=="active_unreadable": unknown.files[S.PATH+"0"]="unreadable"
		await open_owner(unknown); var before: Dictionary=unknown.files.duplicate(true)
		check(scene.recovery_pending and scene.paused and not is_instance_valid(scene.world) and scene.recovery_buttons.read.visible,"unknown startup has recovery-only owner and retry-read action")
		for key in scene.recovery_buttons: check(scene.recovery_buttons[key].visible==(key=="read"),"unknown owner does not enumerate copies "+key)
		scene.save_now(); scene.begin(); scene.retry(); scene.toggle_sound(); scene.import_code(); scene._physics_process(5); scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		check(unknown.files==before and unknown.active_writes==0,"unknown owner cannot save defaults or accept gameplay mutations")
		unknown.files.clear(); unknown.files[S.PATH+"0"]=whole_code(list[1]); await action("RETRY RECOVERY READ")
		check(not scene.recovery_pending and scene.paused and exact(decoded_context(scene),list[1]),"explicit readable retry binds full valid active context without default")
	# A failed scene handoff retains its owner; every later retry re-journals.
	var retained:=fixture_io(list[1]); await open_owner(retained); game_root.block_adoption=true
	await action("SAVE / TRANSFER"); var previous:=decoded_context(scene); scene.code_edit.text=whole_code(list[6]); retained.guarded=true; await action("IMPORT")
	check(scene.recovery_pending and not retained.files.has(S.PATH+"import-pending") and exact(decoded_context(scene),previous),"verified cleanup plus failed handoff keeps old full owner frozen")
	retained.mode="stage_write"; var active_count: int=retained.active_writes; await action("RETRY IMPORT")
	check(scene.recovery_pending and retained.active_writes==active_count and retained.unadmitted==0,"retained helper cannot use cleared cached admission")
	reset_fault(retained); game_root.block_adoption=false; await action("RETRY IMPORT")
	check(not scene.recovery_pending and scene.paused and exact(decoded_context(scene),list[6]),"retained helper freshly journals before verified paused handoff")
	# Standalone scene replacement carries its exact injected backend once.
	for source_index in [1,5]:
		await shutdown()
		var standalone_io:=fixture_io(list[source_index])
		game_root=Node3D.new(); game_root.set_script(load("res://scripts/main.gd" if source_index==1 else "res://scripts/campaign_main.gd")); game_root.save_io=standalone_io
		root.add_child(game_root); current_scene=game_root; scene=game_root; await process_frame; await process_frame; scene.set_physics_process(false)
		await action("SAVE / TRANSFER"); var target: Dictionary=list[6 if source_index==1 else 2]; scene.code_edit.text=whole_code(target); standalone_io.mode="read1"; await action("IMPORT")
		check(scene.recovery_pending,"standalone actual Import enters uncertainty before cross-schema choice")
		reset_fault(standalone_io); await action("RETRY IMPORT"); await process_frame; await process_frame
		game_root=current_scene; scene=game_root.get_node("Battle"); scene.set_physics_process(false)
		check(scene.paused and not scene.recovery_pending and exact(decoded_context(scene),target),"standalone cross-schema actual Retry adopts complete chosen context paused")
		check(game_root.save_io==standalone_io and scene.save_io==standalone_io and not has_meta("hearth_verified_context"),"one-shot standalone handoff preserves backend and consumes its metadata")
	# Same-schema standalone legacy adoption keeps every loaded field as well.
	for use_import in [false,true]:
		await shutdown(); var same_io:=fixture_io(list[1]); game_root=load("res://legacy.tscn").instantiate(); game_root.save_io=same_io; root.add_child(game_root); scene=game_root; await process_frame; await process_frame; scene.set_physics_process(false)
		await action("SAVE / TRANSFER"); var standalone_previous:=decoded_context(scene); scene.code_edit.text=whole_code(list[2]); same_io.mode="read1"; await action("IMPORT"); reset_fault(same_io)
		await action("RETRY IMPORT" if use_import else "KEEP PREVIOUS WHOLE SAVE")
		check(not scene.recovery_pending and scene.paused and exact(decoded_context(scene),list[2] if use_import else standalone_previous),"standalone same-schema legacy actual choice preserves full terminal/profile/parked/settings context")
	# Older envelope bytes remain immutable while the unchanged decoder supplies current defaults.
	var historical_payload:=JSON.stringify({"version":1,"revision":4,"committed":true,"state":list[1].state,"profile":list[1].profile,"settings":list[1].settings})
	var historical:=JSON.stringify({"payload":historical_payload,"sha256":historical_payload.sha256_text()})
	var historical_io:=fixture_io(list[5]); await open_owner(historical_io); await action("SAVE / TRANSFER"); scene.code_edit.text=historical; historical_io.mode="read1"; await action("IMPORT")
	check(scene.recovery.incoming_code==historical and Copies.new(historical_io).get_code(historical.sha256_text()).get("text")==historical,"version-one whole intake bytes retained exactly without re-encoding archive")
	reset_fault(historical_io); await action("RETRY IMPORT")
	check(scene.paused and exact(decoded_context(scene),S.decode(historical)),"version-one import adopts owning decoder's exact current full meaning")
func marker_cases(list: Array) -> void:
	var source:=whole_code(list[1]); var incoming:=whole_code(list[6])
	for use_import in [false,true]:
		for fault in ["stage_write","stage_rename","stage_read","archive_write","read1","read2","cleanup","partial_cleanup","torn_base","torn_stage","unreadable_base","conflict_base","conflict_stage","bad_archive","missing_extra","absent_write","checksum","record_extra","archive_identity","active_write","active_rename","active_missing","active_corrupt","active_stale"]:
			var io:=fixture_io(list[1]); io.files[S.PATH+"1"]=whole_code(list[4]); var helper:=Journal.new(io)
			if fault in ["stage_write","stage_rename","stage_read","archive_write"]: io.mode=fault
			var began:=helper.begin(source,incoming)
			if not began.ok:
				check(io.active_writes==0 and began.pending==(fault!="archive_write"),"initial preservation fault cannot mutate active "+fault); continue
			var text: String=io.files[S.PATH+"import-pending"]; var record:=helper.record.duplicate(true)
			if fault=="partial_cleanup": io.files[S.PATH+"import-pending.tmp"]=text; io.mode=fault
			elif fault in ["read1","read2","cleanup","active_write","active_rename","active_missing","active_corrupt","active_stale"]: io.mode=fault
			elif fault in ["torn_base","torn_stage"]: io.files[S.PATH+"import-pending"+(".tmp" if fault=="torn_stage" else "")]="torn"
			elif fault=="unreadable_base": io.one_path=S.PATH+"import-pending"; io.one_reads=1
			elif fault in ["conflict_base","conflict_stage"]:
				var other:=record.duplicate(true); other.original=record.incoming; other.incoming=record.original
				io.files[S.PATH+"import-pending.tmp"]=text
				io.files[S.PATH+"import-pending"+(".tmp" if fault=="conflict_stage" else "")]=marker_text(other)
			elif fault=="bad_archive": io.files[Copies.PREFIX+record.incoming]="corrupt"
			elif fault=="archive_identity": io.files[Copies.PREFIX+record.incoming]=source
			elif fault=="checksum": io.files[S.PATH+"import-pending"]=text.replace("sha256", "checksum")
			elif fault=="record_extra":
				var other:=record.duplicate(true); other.unexpected="conflicting complete record"; io.files[S.PATH+"import-pending.tmp"]=marker_text(other)
			elif fault=="missing_extra":
				for id in record.copies:
					if id not in [record.original,record.incoming]: io.files.erase(Copies.PREFIX+id)
			elif fault=="absent_write": io.files.erase(S.PATH+"import-pending"); io.mode="stage_write"
			var before: Dictionary=io.files.duplicate(true); io.guarded=true
			var result:=helper.resolve(use_import)
			# Keeping the same previous context may verify via a durable prior candidate on read2.
			var allowed: bool=fault=="read2" and not use_import
			check(not result.ok or allowed,"fault cannot claim an unverified choice "+fault+str(use_import))
			check(io.unadmitted==0,"fault never bypasses fresh complete marker/archive admission "+fault)
			if fault in ["torn_base","torn_stage","unreadable_base","conflict_base","conflict_stage","bad_archive","missing_extra","checksum","record_extra","archive_identity"]: check(io.files==before and io.active_writes==0,"unreadable/conflicting evidence is not overwritten/promoted/repaired "+fault)
			if fault.begins_with("active_"):
				check(io.active_writes>0 and io.files[S.PATH+"import-pending"]==before[S.PATH+"import-pending"],"admitted active-write fault retains original marker rather than claiming cleanup "+fault)
				for file in before:
					if file.begins_with(Copies.PREFIX): check(io.files.get(file)==before[file],"active-write fault leaves every full raw archive unchanged "+fault)
			observations.append({"fault":fault,"choice":use_import,"returned":result.ok,"unadmitted":io.unadmitted})
	# Matching sole stage/base reuse cannot consume the last marker on promotion.
	for shape in ["base","stage","both"]:
		var io:=fixture_io(list[1]); var helper:=Journal.new(io); helper.begin(source,incoming)
		var text: String=io.files[S.PATH+"import-pending"]
		if shape=="stage": io.files.erase(S.PATH+"import-pending"); io.files[S.PATH+"import-pending.tmp"]=text
		if shape=="both": io.files[S.PATH+"import-pending.tmp"]=text
		var before: Dictionary=io.files.duplicate(true); io.mode="stage_missing"
		check(helper.persist() and io.files==before,"matching "+shape+" reused byte-exact without destructive promotion")
		helper.read(); io.one_path=S.PATH+"import-pending"+(".tmp" if shape=="stage" else ""); io.one_reads=1
		var loaded:=helper.read()
		check(loaded.ok==(shape=="both") and not helper.journal_ready and helper.original_code==source,"failed preferred read invalidates admission while valid alternate preserves full exports")
func copy_layout_cases(list: Array) -> void:
	check(not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD),"headless copy exercises unsupported branch without OS clipboard calls")
	var layout_index:=-1
	for extent in [Vector2i(450,1000),Vector2i(720,1280),Vector2i(1000,900),Vector2i(900,450)]:
		root.size=extent
		for source in [list[1],list[5]]:
			layout_index+=1
			var skip:=false
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--layout-index=") and int(arg.get_slice("=",1))!=layout_index: skip=true
			if skip: continue
			print("COPY_LAYOUT ",extent," / ",source.state.schema)
			var io:=fixture_io(source); var helper:=Journal.new(io); helper.begin(whole_code(source),whole_code(list[6])); await open_owner(io)
			scene.recovery.message+=" Keep this device and its files while recovery is uncertain. Neither choice changes only one part of your watch; your saved passes, progress and settings move together."; scene.show_recovery(); await process_frame; await process_frame
			var before:=decoded_context(scene); var files: Dictionary=io.files.duplicate(true); var writes: int=io.writes; var issue: String=scene.recovery.message
			check(scene.recovery_feedback.visible and scene.recovery_feedback.size.x>0 and scene.recovery_feedback.size.y>=60,"feedback row allocated at full width before first actual touch")
			for title in ["COPY PREVIOUS CODE","COPY IMPORTED CODE"]:
				await action(title); await process_frame
				check(scene.recovery_feedback.size.y<scene.recovery_panel.size.y,"feedback wrap remains bounded after actual touch")
				check(scene.recovery_feedback.text.begins_with("Clipboard unavailable") and scene.recovery_summary.text.begins_with(issue),"copy feedback is honest and keeps storage explanation separate")
				check(exact(decoded_context(scene),before) and io.files==files and io.writes==writes and scene.recovery_pending,"copy changes no whole context or archive/journal/slot")
				var scroll: ScrollContainer=scene.recovery_panel.get_child(0); check(scroll.get_global_rect().encloses(scene.recovery_feedback.get_global_rect()),"copy acknowledgment fully revealed "+str(extent))
			for key in ["retry","previous","copy_previous","copy_incoming","view_previous","view_incoming"]:
				var b: Button=scene.recovery_buttons[key]; var scroll: ScrollContainer=scene.recovery_panel.get_child(0); scroll.ensure_control_visible(b); await process_frame; await process_frame
				check(b.size.y>=88 and scroll.get_global_rect().encloses(b.get_global_rect()),"summary-first recovery choices remain touch-sized/reachable "+str(extent)+key)

func unknown_to_known_layout(list: Array) -> void:
	for use_import in [false,true]:
		var io:=RecoveryFault.new(); io.files[S.PATH+"import-pending"]="torn"; await open_owner(io)
		check(not scene.recovery_feedback.visible,"unknown owner has no export feedback or archive enumeration")
		io.files.clear(); var journal:=Journal.new(io); journal.begin(whole_code(list[1]),whole_code(list[6]))
		await action("RETRY RECOVERY READ")
		check(scene.recovery_pending and scene.recovery_buttons.copy_previous.visible and scene.recovery_feedback.visible and not is_instance_valid(scene.world),"explicit recovery reread allocates known-owner feedback without creating a world")
		await action("COPY PREVIOUS CODE"); await action("COPY IMPORTED CODE")
		check(scene.recovery_feedback.size.y<scene.recovery_panel.size.y and scene.recovery_feedback.text.begins_with("Clipboard unavailable"),"unknown-to-known actual copy wraps without hiding either choice")
		await action("RETRY IMPORT" if use_import else "KEEP PREVIOUS WHOLE SAVE")
		check(not scene.recovery_pending and scene.paused and exact(decoded_context(scene),list[6] if use_import else list[1]),"unknown-to-known explicit choice adopts validated whole context")

func sole_marker_choices(list: Array) -> void:
	for shape in ["base","stage"]:
		for use_import in [false,true]:
			var io:=fixture_io(list[1]); var helper:=Journal.new(io); helper.begin(whole_code(list[1]),whole_code(list[6]))
			var marker: String=io.files[S.PATH+"import-pending"]
			if shape=="stage": io.files.erase(S.PATH+"import-pending"); io.files[S.PATH+"import-pending.tmp"]=marker
			io.mode="stage_missing"; io.guarded=true; await open_owner(io)
			check(scene.recovery_pending and exact(decoded_context(scene),list[1]),"fresh owner binds exact previous context from sole "+shape)
			await action("RETRY IMPORT" if use_import else "KEEP PREVIOUS WHOLE SAVE")
			check(not scene.recovery_pending and scene.paused and exact(decoded_context(scene),list[6] if use_import else list[1]) and io.unadmitted==0,"actual fresh-owner choice reuses sole marker without destructive promotion "+shape+str(use_import))
	# A corrupt immutable archive is a real retained failure, never silently repaired.
	var io:=fixture_io(list[1]); var code:=whole_code(list[6]); io.files[Copies.PREFIX+code.sha256_text()]="corrupt archive destination"; await open_owner(io); await action("SAVE / TRANSFER")
	var previous:=decoded_context(scene); var files: Dictionary=io.files.duplicate(true); var writes: int=io.active_writes; scene.code_edit.text=code; await action("IMPORT")
	check(not scene.recovery_pending and scene.save_problem and exact(decoded_context(scene),previous) and io.active_writes==writes,"corrupt preexisting intake archive blocks later Import honestly before active mutation")
	check(io.files[Copies.PREFIX+code.sha256_text()]==files[Copies.PREFIX+code.sha256_text()] and scene.notice.text.begins_with("Storage failed before Import"),"failed archive is retained unchanged with explicit failure rather than repaired")

func active_destination_choices(list: Array) -> void:
	for fault in ["active_missing","active_corrupt","active_stale"]:
		for use_import in [false,true]:
			var io:=fixture_io(list[5]); io.files[S.PATH+"1"]=whole_code(list[4]); await open_owner(io); await action("SAVE / TRANSFER")
			var previous:=decoded_context(scene); var intake:=whole_code(list[2]); scene.code_edit.text=intake; io.mode=fault; io.guarded=true; await action("IMPORT")
			check(scene.recovery_pending and scene.paused and exact(decoded_context(scene),previous) and io.active_writes>0 and io.unadmitted==0,"actual Import preserves complete live owner after admitted active destination fault "+fault)
			check(scene.recovery.incoming_code==intake and Copies.new(io).get_code(intake.sha256_text()).get("text")==intake,"active destination failure preserves exact intake separately "+fault)
			reset_fault(io); await open_owner(io)
			check(scene.recovery_pending and exact(decoded_context(scene),previous),"fresh owner after active destination failure binds original "+fault)
			await action("RETRY IMPORT" if use_import else "KEEP PREVIOUS WHOLE SAVE")
			check(scene.paused and not scene.recovery_pending and exact(decoded_context(scene),list[2] if use_import else previous),"explicit choice resolves admitted destination fault as a complete paused context "+fault+str(use_import))

func standalone_unknown_choices(list: Array) -> void:
	for use_import in [false,true]:
		await shutdown(); var io:=RecoveryFault.new(); io.files[S.PATH+"import-pending"]="torn"
		game_root=load("res://legacy.tscn").instantiate(); game_root.save_io=io; root.add_child(game_root); current_scene=game_root; scene=game_root; await process_frame; await process_frame
		check(scene.recovery_pending and not is_instance_valid(scene.ui) and not is_instance_valid(scene.world),"standalone cold unknown legacy owner has only recovery UI")
		io.files.clear(); var helper:=Journal.new(io); helper.begin(whole_code(list[1]),whole_code(list[2])); await action("RETRY RECOVERY READ")
		check(scene.recovery_pending and not is_instance_valid(scene.ui),"standalone unknown-to-known reread keeps placeholder frozen")
		await action("RETRY IMPORT" if use_import else "KEEP PREVIOUS WHOLE SAVE"); await process_frame; await process_frame
		game_root=current_scene
		var adopted: bool=is_instance_valid(game_root) and game_root.has_node("Battle")
		check(adopted,"standalone missing-UI choice uses validated fresh-bootstrap handoff")
		if not adopted: continue
		scene=game_root.get_node("Battle"); scene.set_physics_process(false)
		check(scene.paused and not scene.recovery_pending and exact(decoded_context(scene),list[2] if use_import else list[1]) and is_instance_valid(scene.ui) and is_instance_valid(scene.world),"standalone unknown-to-known whole legacy choice initializes complete UI and world paused")
		check(game_root.save_io==io and scene.save_io==io and not has_meta("hearth_verified_context"),"standalone no-world handoff retains backend and consumes one-shot context")
