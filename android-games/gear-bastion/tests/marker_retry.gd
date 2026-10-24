extends "res://tests/import_recovery.gd"
## Same owner, real touch choices, exact raw archives and actual-file fresh bootstrap.
class MarkerFault extends JournalFault:
	var duplicate_stage := false
	var block_stage_clear := false
	var marker_rename_fault := ""
	var unreadable_marker := ""
	var watch_active := false
	var all_active_unreadable_after := 0
	var active_reads := 0
	var promoted_active := false
	var intended := {}
	var active_attempts: Array=[]
	func read_text(file: String) -> String:
		if file==unreadable_marker: return "temporarily unreadable marker"
		if promoted_active and all_active_unreadable_after>0 and file in [Store.PATH,Store.PATH+".tmp",Store.PATH+".bak",Store.PATH+".bak.tmp"]:
			active_reads+=1
			if active_reads>=all_active_unreadable_after: return "temporarily unreadable active candidates"
		return super.read_text(file)
	func rename(from: String,to: String) -> bool:
		if to==Store.PATH+".import-pending":
			if marker_rename_fault=="missing": files.erase(from); files.erase(to); return true
			if marker_rename_fault=="fail": return false
			var staged: String=files.get(from,"")
			var result:=super.rename(from,to)
			if result and duplicate_stage: files[from]=staged
			return result
		var result:=super.rename(from,to)
		if to==Store.PATH and result: promoted_active=true; active_reads=0
		return result
	func remove(file: String) -> bool:
		if block_stage_clear and file==Store.PATH+".import-pending.tmp": return false
		return super.remove(file)
	func write_text(file: String,text: String) -> bool:
		if watch_active and file in [Store.PATH,Store.PATH+".tmp",Store.PATH+".bak",Store.PATH+".bak.tmp"]:
			var admitted:=false
			for suffix in ["", ".tmp"]:
				var marker: String=Store.PATH+".import-pending"+suffix
				if not exists(marker): continue
				var decoded:=Journal.decode(read_text(marker))
				if not decoded.ok or decoded.record!=intended: admitted=false; break
				admitted=true
			active_attempts.append({"path":file,"admitted":admitted})
		return super.write_text(file,text)

func marker_text(value: Dictionary) -> String:
	var payload:=JSON.stringify(value)
	return JSON.stringify({"payload":payload,"sha256":payload.sha256_text()})
func reset_marker_fault(io: MarkerFault) -> void:
	reset_fault(io); io.duplicate_stage=false; io.block_stage_clear=false; io.marker_rename_fault=""; io.unreadable_marker=""; io.watch_active=false; io.all_active_unreadable_after=0; io.promoted_active=false; io.active_reads=0
func archive_snapshot(io: MarkerFault) -> Dictionary:
	var result:={}
	for file in io.files:
		if str(file).begins_with(Copies.PREFIX): result[file]=io.files[file]
	return result
func archives_equal(io: MarkerFault,wanted: Dictionary) -> bool:
	for file in wanted:
		if io.files.get(file)!=wanted[file]: return false
	return true
func run() -> void:
	check(ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"all physical probes isolated")
	if not failures.is_empty(): quit(1); return
	for scenario in ["stage_consumption","base_survival","base_post_read","cached_torn_base","conflicting_stage_cleanup"]:
		for use_import in [false,true]:
			var io:=MarkerFault.new(); io.files[Store.PATH]=fixture(0,20)
			var game:=await boot(io)
			await tap(game.get_global_transform_with_canvas()*game.buttons().save.get_center(),"Save before marker retry")
			var previous:=live(game); var raw_state: Dictionary=game.state.duplicate(true)
			var raw_codes: Array[String]=[]
			for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
				var code:=fixture(0 if suffix.is_empty() else (1 if suffix!=".bak" else 2),20 if suffix.is_empty() else raw_codes.size())
				io.files[Store.PATH+suffix]=code; raw_codes.append(code)
			var incoming_code:=fixture(2,99); game.save_text.text=incoming_code
			if scenario=="stage_consumption": io.duplicate_stage=true; io.block_stage_clear=true
			else: io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1
			await dialog_button(game,"Import")
			check(game.recovery_pending and game.paused and live(game)==previous and game.state==raw_state,"actual initial uncertainty freezes complete owner "+scenario)
			var record: Dictionary=game.recovery.record.duplicate(true); var text:=marker_text(record)
			var original_code: String=game.recovery.original_code; var archives:=archive_snapshot(io)
			for code in raw_codes+[original_code,incoming_code]:
				check(Copies.new(io).get_code(code.sha256_text()).get("text")==code,"each raw/live/incoming code preserved verbatim before retry")
			reset_marker_fault(io)
			if scenario=="stage_consumption":
				check(not io.files.has(journal_prefix()) and io.files.get(journal_prefix()+".tmp")==text,"actual partial cleanup left sole exact stage")
				io.marker_rename_fault="missing"; io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1
			elif scenario=="base_survival":
				io.marker_rename_fault="missing"; io.fail_suffix=".import-pending.tmp"; io.fail_mode="write"; io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1
			elif scenario=="base_post_read":
				io.all_active_unreadable_after=2
			elif scenario=="cached_torn_base":
				io.files[journal_prefix()]="torn marker"; io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1
			else:
				var conflict:=record.duplicate(true); conflict.original=record.incoming; conflict.incoming=record.original
				io.files[journal_prefix()+".tmp"]=marker_text(conflict); io.block_stage_clear=true
			var marker_before:={}
			for suffix in ["", ".tmp"]:
				if io.files.has(journal_prefix()+suffix): marker_before[suffix]=io.files[journal_prefix()+suffix]
			io.intended=Journal.decode(marker_text(record)).record; io.watch_active=true
			await choose(game,use_import); await ticks()
			check(game.recovery_pending and game.paused and live(game)==previous and game.state==raw_state,"same-owner failed choice never adopts "+scenario+str(use_import))
			check(archives_equal(io,archives) and game.recovery.original_code==original_code and game.recovery.incoming_code==incoming_code,"all immutable whole codes retained across same-owner retry")
			for suffix in marker_before:
				check(io.files.get(journal_prefix()+suffix)==marker_before[suffix],"every sole/conflicting marker byte survives failed retry "+scenario+suffix)
			if scenario in ["cached_torn_base","conflicting_stage_cleanup"]: check(io.active_attempts.is_empty(),"invalid/conflicting marker blocks every active write "+scenario)
			for attempt in io.active_attempts: check(attempt.admitted,"every active write has fresh complete marker admission")
			observations.append({"scenario":scenario,"choice":use_import,"active_attempts":io.active_attempts.duplicate(true),"markers_before":marker_before,"files_after":io.files.duplicate(true),"original":original_code,"incoming":incoming_code,"live":live(game)})
			game.queue_free(); await ticks(); reset_marker_fault(io); materialize(io)
			var cold:=await physical_boot()
			check(cold.recovery_pending and cold.paused,"actual-file fresh owner stays pending after failed retry "+scenario)
			if scenario!="cached_torn_base": check(same(live(cold),previous),"fresh owner restores exact original whole context "+scenario)
			cold.queue_free(); await ticks()
			# Explicitly repair only the injected backend fault, never app metadata.
			io.files[journal_prefix()]=text; io.files.erase(journal_prefix()+".tmp"); materialize(io)
			var recovered:=await physical_boot(); await choose(recovered,use_import); await ticks()
			var wanted: Dictionary=Store.decode(incoming_code) if use_import else previous
			check(not recovered.recovery_pending and recovered.paused and same(live(recovered),wanted) and same(Store.read(),wanted),"fresh owner explicit whole choice succeeds after fault lifted")
			for code in raw_codes+[original_code,incoming_code]: check(Copies.new().get_code(code.sha256_text()).get("text")==code,"all raw whole archives remain exact after final choice")
			recovered.queue_free(); await ticks()
	await typed_contracts()
	var output:={"checks":checks,"failures":failures,"observations":observations,"events":events,"limits":"Synthetic complete decoder-valid records and typed faults; actual ScreenTouch same-owner Retry/Keep and materialized-file fresh owner. CPU/headless/Dummy, no OS kill/native/render/power-loss claim."}
	FileAccess.open(folder.path_join("marker-retry.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("GEAR_MARKER ",checks," / ",failures.size()," failures / ",events.size()," touch events"); quit(0 if failures.is_empty() else 1)

func typed_contracts() -> void:
	var source:=fixture(0); var target:=fixture(2,99)
	for use_import in [false,true]:
		for shape in ["base","stage","both"]:
			var io:=MarkerFault.new(); io.files[Store.PATH]=source
			var helper:=Journal.new(io); check(helper.begin(source,target).ok,"typed transaction begins")
			var text: String=io.files[journal_prefix()]
			if shape=="stage": io.files.erase(journal_prefix()); io.files[journal_prefix()+".tmp"]=text
			if shape=="both": io.files[journal_prefix()+".tmp"]=text
			io.marker_rename_fault="missing"; io.fail_suffix=".import-pending.tmp"; io.fail_mode="write"
			var before: Dictionary=io.files.duplicate(true); var writes: int=io.write_count; var renames: int=io.rename_count
			check(helper.persist() and io.files==before and io.write_count==writes and io.rename_count==renames,"matching "+shape+" is reused without destructive write/promotion")
			io.intended=Journal.decode(marker_text(helper.record)).record; io.watch_active=true
			io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1
			check(not helper.resolve(use_import).ok,"active readback uncertainty remains blocked "+shape)
			for suffix in ["", ".tmp"]:
				if before.has(journal_prefix()+suffix): check(io.files.get(journal_prefix()+suffix)==before[journal_prefix()+suffix],"active uncertainty preserves every matching marker byte")
			for attempt in io.active_attempts: check(attempt.admitted,"typed active write has complete fresh admission")
			reset_marker_fault(io)
			var fresh:=Journal.new(io); check(fresh.read().ok and fresh.original_code==source and fresh.incoming_code==target,"fresh helper reads exact choices after active uncertainty")
			check(fresh.resolve(use_import).ok and same(Store.read(Store.PATH,io),Store.decode(target if use_import else source)),"explicit whole choice resolves after transient read lifted")
		for fault in ["torn_base","torn_stage","checksum","conflict_base","conflict_stage","extra_field","reordered_copies","unreadable_base","unreadable_stage","bad_archive","unreadable_extra_archive","missing_selected_archive","absent_pair_write_fail","absent_pair_rename_fail"]:
			var io:=MarkerFault.new(); io.files[Store.PATH]=source; io.files[Store.PATH+".bak"]=fixture(1,3)
			var helper:=Journal.new(io); check(helper.begin(source,target).ok,"fault transaction starts "+fault)
			var record:=helper.record.duplicate(true); var text: String=io.files[journal_prefix()]
			io.files[journal_prefix()+".tmp"]=text
			if fault=="torn_base": io.files[journal_prefix()]="torn"
			elif fault=="torn_stage": io.files[journal_prefix()+".tmp"]="torn"
			elif fault=="checksum":
				var envelope: Dictionary=JSON.parse_string(text); envelope.sha256="0".repeat(64); io.files[journal_prefix()]=JSON.stringify(envelope)
			elif fault in ["conflict_base","conflict_stage","extra_field","reordered_copies"]:
				var changed:=record.duplicate(true)
				if fault=="extra_field": changed.extra="different complete record"
				elif fault=="reordered_copies": changed.copies.reverse()
				else: changed.original=record.incoming; changed.incoming=record.original
				io.files[journal_prefix()+(".tmp" if fault=="conflict_stage" else "")]=marker_text(changed)
			elif fault.begins_with("unreadable_") and fault!="unreadable_extra_archive": io.unreadable_marker=journal_prefix()+(".tmp" if fault=="unreadable_stage" else "")
			elif fault=="bad_archive": io.files[Copies.PREFIX+record.incoming]="corrupt archived bytes"
			elif fault=="unreadable_extra_archive":
				for id in record.copies:
					if id not in [record.original,record.incoming]: io.unreadable_marker=Copies.PREFIX+id
			elif fault=="missing_selected_archive": io.files.erase(Copies.PREFIX+record.original)
			elif fault.begins_with("absent_pair"):
				io.files.erase(journal_prefix()); io.files.erase(journal_prefix()+".tmp")
				if fault.ends_with("write_fail"): io.fail_suffix=".import-pending.tmp"; io.fail_mode="write"
				else: io.marker_rename_fault="fail"
			var before: Dictionary=io.files.duplicate(true); var archives:=archive_snapshot(io)
			io.intended=Journal.decode(marker_text(record)).record; io.watch_active=true
			check(not helper.resolve(use_import).ok and io.active_attempts.is_empty(),"unverified pair/archive rejects all active writes "+fault+str(use_import))
			check(archives_equal(io,archives) and helper.original_code==source and helper.incoming_code==target,"blocked choice retains whole archive bytes and live exports "+fault)
			if not fault.begins_with("absent_pair"): check(io.files==before,"invalid/conflicting/unreadable evidence is not repaired/deleted "+fault)
			observations.append({"typed_fault":fault,"choice":use_import,"active_attempts":io.active_attempts.duplicate(true),"retained_record":helper.record.duplicate(true)})
	# Missing/corrupt/stale rollback and post-Store read uncertainty preserve admission.
	for use_import in [false,true]:
		for mode in ["missing","corrupt","stale","post_store_read"]:
			var io:=MarkerFault.new(); io.files[Store.PATH]=source; var helper:=Journal.new(io); helper.begin(source,target)
			var text: String=io.files[journal_prefix()]; var archives:=archive_snapshot(io)
			io.watch_active=true; io.intended=Journal.decode(marker_text(helper.record)).record
			if mode=="post_store_read": io.all_active_unreadable_after=2
			else: io.bad_destination_suffix="bastion-save.json"; io.bad_destination_mode=mode; io.stale_destination=source
			check(not helper.resolve(use_import).ok and io.files.get(journal_prefix())==text,"active rollback/readback uncertainty leaves exact marker "+mode)
			check(archives_equal(io,archives) and helper.original_code==source and helper.incoming_code==target,"active uncertainty leaves immutable whole choices "+mode)
			for attempt in io.active_attempts: check(attempt.admitted,"uncertain active candidate was admitted against current complete markers")
			reset_marker_fault(io)
			var fresh:=Journal.new(io); check(fresh.read().ok and fresh.original_code==source,"fresh helper retains original meaning after active uncertainty "+mode)
	# A later failed read invalidates cached admission while retaining export choices.
	for marker in ["torn","absent"]:
		var io:=MarkerFault.new(); io.files[Store.PATH]=source; var helper:=Journal.new(io); helper.begin(source,target)
		if marker=="torn": io.files[journal_prefix()]="torn"
		else: io.files.erase(journal_prefix())
		check(not helper.read().ok and not helper.journal_ready and helper.original_code==source and helper.incoming_code==target,"failed read clears admission but retains immutable full exports "+marker)
	# A retained successful owner cannot reuse its cleared admission.
	for use_import in [false,true]:
		var io:=MarkerFault.new(); io.files[Store.PATH]=source; var helper:=Journal.new(io); helper.begin(source,target)
		check(helper.resolve(use_import).ok and not helper.journal_ready,"verified clear invalidates helper admission")
		io.fail_suffix=".import-pending.tmp"; io.fail_mode="write"; io.watch_active=true; io.intended=Journal.decode(marker_text(helper.record)).record
		check(not helper.resolve(not use_import).ok and io.active_attempts.is_empty(),"retained cleared helper blocks active writes when new journal fails")
		reset_marker_fault(io)
		check(not helper.resolve(not use_import).ok,"torn new marker remains blocked after transient fault is lifted")
		# Fault backend restores the absent pair; app never deletes or repairs it.
		io.files.erase(journal_prefix()+".tmp")
		check(helper.resolve(not use_import).ok and same(Store.read(Store.PATH,io),Store.decode(source if use_import else target)),"retained cleared helper can establish fresh admission and resolve whole opposite choice")
