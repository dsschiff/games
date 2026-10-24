extends "res://tests/campaign_input.gd"
var earned_dir:=""
var baseline:=false
var fixture_only:=false
var evidence: Array=[]
var geometry: Array=[]
var typed_cases: Array=[]
func boot_earned(name: String) -> void:
	if is_instance_valid(app): app.free(); await process_frame
	var path:=earned_dir.path_join(name+"-slots.json")
	var slots: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(not slots.is_empty(),"retained genuine input-earned slots exist: "+name)
	for suffix in ["0","1","0.tmp","1.tmp"]:
		var target: String=S.PATH+suffix
		if FileAccess.file_exists(target): DirAccess.remove_absolute(target)
	for target in slots:
		var file:=FileAccess.open(target,FileAccess.WRITE); file.store_string(slots[target]); file.close()
	var expected:=S.read(); check(expected.ok,"owning decoder accepts exact earned fixture")
	app=load("res://boot.tscn").instantiate(); root.add_child(app); scene=app.session; await dwell(3)
	check(whole()=={"state":expected.state,"career":expected.career,"profile":expected.profile,"settings":expected.settings},"fresh production owner preserves complete earned state/profile/career/settings")
func feedback(label: String) -> void:
	var text: String=scene.terminal_detail.text
	check(text.contains("This sortie"),label+": current sortie is explicitly separate")
	check(text.contains("207.12") and text.contains("206.50"),label+": slower earned result and retained record times are both visible")
func inspect_feedback(label: String,stress_text: String="") -> void:
	var before:=whole(); var raw:=disk_bytes(); var attempts: int=scene.career.attempts
	var processing: bool=scene.is_physics_processing()
	if not stress_text.is_empty(): scene.set_physics_process(false)
	for viewport in [Vector2i(720,1680),Vector2i(1153,1280),Vector2i(2276,1280)]:
		root.size=viewport; await dwell(3)
		for repeat in 3: scene.refresh()
		if not stress_text.is_empty(): scene.terminal_detail.text=stress_text; await dwell(3)
		var body: Label=scene.terminal_detail; var font: Font=body.get_theme_font("font"); var size:=body.get_theme_font_size("font_size")
		if not stress_text.is_empty(): check(body.text==stress_text,label+": measured text is the actual typed stress output, not overwritten by frame refresh")
		var lines: int=body.get_line_count(); var height: float=lines*font.get_height(size)+maxi(0,lines-1)*body.get_theme_constant("line_spacing")
		check(height<=body.size.y and body.get_minimum_size().y<=body.size.y,label+": actual wrapped font rows fit effective recap body")
		check(body.position==Vector2(24,85) and body.size==Vector2(570,230),label+": existing effective230px body retained")
		for button in scene.terminal.find_children("*","Button",true,false):
			check(not body.get_global_rect().intersects(button.get_global_rect()),label+": recap stays clear of unchanged terminal controls")
		check(not body.text.to_lower().contains("new record") and not body.text.to_lower().contains("newly"),label+": reload cannot invent newly-earned claims")
		geometry.append({"label":label,"viewport":str(viewport),"rows":lines,"font_size":size,"font_height":font.get_height(size),"paint_height":height,"body":str(body.get_global_rect()),"text":body.text})
		check(whole()==before and disk_bytes()==raw and scene.career.attempts==attempts,label+": repeated presentation/resize preserves exact complete context and raw slots")
	root.size=Vector2i(720,1280); await dwell(3)
	evidence.append({"label":label,"whole":whole(),"text":stress_text if not stress_text.is_empty() else scene.terminal_detail.text,"raw_slots":disk_bytes()})
	scene.set_physics_process(processing); scene.refresh()
func inspect_journey() -> void:
	var before:=whole()
	await click("II"); await click("JOURNEY / RECORDS")
	check(whole()==before,"admitted Pause save/navigation preserves full live context")
	var raw:=disk_bytes()
	check(scene.record_criteria.text.contains("no escapes") and scene.record_criteria.text.contains("60%") and scene.record_criteria.text.contains("50%"),"Journey explains the exact ordered medal thresholds")
	for viewport in [Vector2i(720,1680),Vector2i(1153,1280),Vector2i(2276,1280)]:
		root.size=viewport; await dwell(3)
		var scroll: ScrollContainer=scene.journey_list.get_parent(); var criteria: Label=scene.record_criteria
		check(criteria.get_minimum_size().y<=criteria.size.y and criteria.get_minimum_size().x<=criteria.size.x and criteria.get_global_rect().end.y<scroll.get_global_rect().position.y,"actual criteria font fits above the Journey list")
		for child in scene.journey_list.get_children():
			if child is Button: check(child.get_minimum_size().y<=child.size.y and child.get_minimum_size().x<=child.size.x,"actual multiline mission/record button text fits unchanged row")
		check(whole()==before and disk_bytes()==raw,"Journey record queries/resize leave whole progress and raw slots unchanged")
	var row: Button=scene.journey_list.get_child(10)
	check(row.text.contains("Last Supply") and row.text.contains("Record 3/3") and row.text.contains("206.50"),"earned Journey row names retained medal and associated record time")
	var lower: Dictionary=scene.career.duplicate(true); lower.records[D.IDS[10]].medal=2; lower.records[D.IDS[10]].seconds=10000.0
	var original_text: String=row.text; row.text=F.campaign_row(10,lower); await dwell(3)
	check(row.text.contains("Earned 3/3") and row.text.contains("Record 2/3 | 10000.00s"),"actual Journey row separates cumulative stars and lower-record time")
	check(row.get_minimum_size().x<=row.size.x and row.get_minimum_size().y<=row.size.y,"maximum record time and separate cumulative/record text fit real button")
	row.text=original_text
	check(whole()==before and disk_bytes()==raw,"typed row-text stress never changes/adopts/saves its synthetic record")
	root.size=Vector2i(720,1280); await dwell(3); await click("CLOSE"); await click("RESUME")
func cold(label: String) -> void:
	var expected:=whole(); var before_code:=S.encode(scene.state,scene.profile,scene.settings,0,true,scene.career); var before_decoded:=S.decode(before_code)
	app.free(); await process_frame
	app=load("res://boot.tscn").instantiate(); root.add_child(app); scene=app.session; await dwell(3)
	var after_code:=S.encode(scene.state,scene.profile,scene.settings,0,true,scene.career); var after_decoded:=S.decode(after_code)
	check(before_decoded.ok and after_decoded.ok and before_decoded==after_decoded,label+": exact owning-decoder normalized complete exported contexts survive cold owner")
	evidence.append({"label":label+" cold normalization","before_whole":expected,"after_whole":whole(),"before_code":before_code,"after_code":after_code,"before_decoded":before_decoded,"after_decoded":after_decoded,"scope":"Both complete contexts serialized by owning Store at export revision0 then decoded exactly; normal bootstrap slot revision writes are admitted separately, no epsilon or field removal."})
	check(not scene.terminal_detail.text.to_lower().contains("new"),label+": cold terminal shows result without re-award claim")
func boundaries() -> void:
	# Labelled typed classification controls; never written/adopted as earned saves.
	var template: Dictionary=scene.state.duplicate(true)
	for spec in [[72.0,1.0,0,3],[71.99,105.0,0,2],[120.0,105.0,1,2],[71.99,104.99,0,1]]:
		var typed: Dictionary=template.duplicate(true); typed.phase="victory"; typed.recorded=false; typed.hp=spec[0]; typed.hq=spec[1]; typed.escaped=[] if spec[2]==0 else [0]
		var career:=C.career(); C.finish(typed,career)
		check(F.sortie_medal(typed)==spec[3] and career.records[typed.definition.id].medal==spec[3],"presentation matches existing rule hierarchy at independent60%/50%/escape boundary")
		typed_cases.append({"scope":"Typed presentation classification only, not an earned or valid full save","hp":spec[0],"hq":spec[1],"escaped":spec[2],"expected":spec[3]})
func stress() -> void:
	var original:=whole(); var raw:=disk_bytes(); var typed: Dictionary=scene.state.duplicate(true); var records: Dictionary=scene.career.duplicate(true)
	typed.definition= D.skirmish(999999,"siege"); typed.time=10000.0; typed.spent=1000; typed.support="recovery"; typed.support_used=200.0
	for recruit in typed.recruits: recruit.damage=100000.0
	records.skirmishes["999999:siege"]={"medal":3,"seconds":10000.0,"kills":30,"spent":1000,"seed":999999,"style":"siege"}
	for cause in ["Commander lost to bulwark","HQ breached by carrier","Unusual retained failure: WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"]:
		typed.phase="defeat"; typed.cause=cause
		await inspect_feedback("typed longest "+cause,F.recap(typed,records))
	typed.support="ward"; typed.prevented=100000.0
	await inspect_feedback("typed maximum Ward ledger",F.recap(typed,records))
	typed.time=9999.0; typed.recorded=false; var prior: Dictionary=records.skirmishes.duplicate(true); C.finish(typed,records)
	check(records.skirmishes==prior and F.recap(typed,records).contains("Latest clear 999999:siege | 3/3 | 10000.00s") and F.recap(typed,records).contains("This sortie defeat | 9999.00s"),"failed skirmish keeps the earlier latest CLEAR and its own time, never a latest-defeat or best claim")
	check(whole()==original and disk_bytes()==raw,"typed font stress never changes/adopts/saves its synthetic state")
	# Rule-emitted objective failures on labelled state copies, never adopted or saved.
	for spec in [["relay","Unmet: capture both relays"],["liberate","Unmet: both relays + Storm Engine"],["salvage","Unmet: all 3 field caches"],["silence","Unmet: every mortar crew"],["boss","Unmet: siege boss"],["hold","Unmet: stop "]]:
		var failed: Dictionary=C.fresh(D.mission(11)); failed.definition.objective=spec[0]
		failed.phase="playing"; failed.time=10000.0; failed.spawned=failed.definition.schedule.size(); failed.enemies=[]; failed.marks=[]; failed.killed=[]
		failed.escaped=failed.definition.schedule.map(func(e): return e.id)
		C.step(failed,Vector2.ZERO,0.0,[])
		var cause: String=failed.cause; var full: Dictionary=failed.duplicate(true)
		check(failed.phase=="defeat" and cause=="Objective incomplete: "+C.objective_text(failed),"actual rule step emits labelled "+spec[0]+" objective failure")
		check(F.defeat_line(failed).begins_with(spec[1]),"recap retains the concrete "+spec[0]+" mission requirement")
		await inspect_feedback("rule-emitted "+spec[0]+" objective",F.recap(failed,records))
		check(failed==full and failed.cause==cause,"presentation leaves full rule-emitted cause and state unchanged")
	var unusual: Dictionary=typed.duplicate(true); unusual.cause="Objective incomplete: an unusual retained instruction that differs from the pinned objective"
	check(F.defeat_line(unusual).begins_with("Objective incomplete: an unusual") and F.defeat_line(unusual).ends_with("..."),"unusual imported objective cause retains its own prefix rather than inventing pinned instructions")
	check(F.defeat_line({"cause":"Commander lost to bulwark","definition":typed.definition})=="Commander lost to bulwark" and F.defeat_line({"cause":"HQ breached by carrier","definition":typed.definition})=="HQ breached by carrier","ordinary Commander/HQ failure preserves the actual last threat")
	var lower: Dictionary=scene.career.duplicate(true); var id: String=scene.state.definition.id
	lower.records[id].medal=2; lower.records[id].seconds=10000.0
	check(C.valid_career(lower),"record-below-cumulative edge is valid under existing owning career validator")
	check(F.record_line(scene.state,lower).contains("record 2/3 | 10000.00s") and not F.record_line(scene.state,lower).contains("record 3/3"),"record stars are paired with their own time, never cumulative earned stars")
	var row:=F.campaign_row(int(scene.state.definition.index),lower)
	check(row.contains("Earned 3/3") and row.contains("Record 2/3 | 10000.00s"),"Journey separates cumulative earned stars from lower record medal/time")
	scene.refresh()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--earned-dir="): earned_dir=arg.trim_prefix("--earned-dir=")
		if arg=="--baseline": baseline=true
		if arg=="--fixture-only": fixture_only=true
	root.size=Vector2i(720,1280); Engine.time_scale=8.0
	await boot_earned("s13-m11-B-terminal")
	feedback("retained earned slower B")
	if baseline: await finish(); return
	check(scene.terminal_detail.text.contains("Ward prevented 170.1"),"support contribution uses saved prevented-damage ledger")
	await inspect_feedback("retained genuine B")
	await inspect_journey()
	await cold("retained genuine B")
	if fixture_only:
		boundaries(); await stress(); await finish(); return
	# Full new ScreenTouch/joystick policy route from the genuine earned career.
	await select_journey(10); await choose_support("ward"); await click("LAUNCH SORTIE"); await play_sortie("B",false)
	feedback("actual slower B replay"); await inspect_feedback("actual B replay")
	await click("RETRY SIEGE"); await choose_support("ward"); await click("LAUNCH SORTIE"); await play_sortie("mistake",false)
	check(scene.terminal_detail.text.contains("This sortie defeat") and scene.terminal_detail.text.contains("Campaign record 3/3") and scene.terminal_detail.text.contains("206.50"),"actual loss does not relabel retained record as current result")
	await inspect_feedback("actual rifle-only loss"); var career: Dictionary=scene.career.duplicate(true)
	await click("RETRY SIEGE"); check(scene.career==career and scene.state.spent==0,"actual Retry keeps exact earned career while restocking the attempt")
	await choose_support("relay"); await click("LAUNCH SORTIE"); await play_sortie("A",false)
	check(scene.state.phase=="victory" and scene.state.support=="relay" and scene.terminal_detail.text.contains("This sortie 3/3"),"actual refit correction earns its own presented result")
	await inspect_feedback("actual corrected A"); boundaries(); await stress(); await cold("new corrected A")
	await boot_earned("s16-m07-A-terminal")
	check(scene.terminal_detail.text.contains("Latest clear 138:flank") and not scene.terminal_detail.text.contains("Campaign record") and not scene.terminal_detail.text.to_lower().contains("best"),"genuine skirmish outcome names exact seed/style as latest rather than best")
	var before:=whole(); var raw:=disk_bytes(); await click("JOURNEY / RECORDS")
	check(scene.journey_list.get_children().any(func(child): return child is Label and child.text.contains("Latest clear 138:flank")),"Journey makes the saved latest skirmish result readable")
	check(whole()==before and disk_bytes()==raw,"showing skirmish records preserves campaign and all saved context")
	var scroll: ScrollContainer=scene.journey_list.get_parent(); var entry: Label=scene.journey_list.get_child(scene.journey_list.get_child_count()-1)
	for attempt in 40:
		if scroll.get_global_rect().encloses(entry.get_global_rect()): break
		var wheel:=InputEventMouseButton.new(); wheel.position=root.get_final_transform()*scroll.get_global_rect().get_center(); wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true
		Input.parse_input_event(wheel); Input.flush_buffered_events(); events.append({"kind":"latest_clear_scroll","position":str(wheel.position)}); await process_frame
	check(scroll.get_global_rect().encloses(entry.get_global_rect()),"actual wheel input reaches the last latest-clear row")
	check(entry.get_minimum_size().x<=entry.size.x and entry.get_minimum_size().y<=entry.size.y,"last skirmish record font fits its visible row")
	await click("CLOSE"); check(not scene.journey.visible,"unchanged Journey Close remains reachable after the last row")
	await finish()
func finish() -> void:
	if is_instance_valid(app): app.free()
	await process_frame; await process_frame
	FileAccess.open(folder.path_join("record-feedback.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details,"events":events,"snapshots":snapshots,"evidence":evidence,"geometry":geometry,"typed_cases":typed_cases,"scope":"CPU/Dummy; exact retained genuine input-earned contexts materialized into isolated files, fresh production boot. No new earned progression claimed for fixture loading; no renderer/native/clipboard/fun proof."}))
	print("FRONTLINE_RECORD_FEEDBACK ",checks," / ",failures)
	print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
