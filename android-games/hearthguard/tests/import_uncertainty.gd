extends "res://tests/save_reliability.gd"
class Uncertain extends Faults:
	var unreadable:=true
	var promoted:=""
	func read_text(path: String) -> String:
		if unreadable and path==promoted: return "temporarily unreadable destination"
		return super.read_text(path)
	func rename(from: String,to: String) -> bool:
		var okay:=super.rename(from,to)
		if okay and to in [S.PATH+"0",S.PATH+"1"]: promoted=to
		return okay
func run() -> void:
	root.size=Vector2i(720,1280); fixtures=build_fixtures()
	for mode in [1,2]:
		for target_mode in [1,2]:
			if not ("--case="+str(mode)+"-"+str(target_mode)) in OS.get_cmdline_user_args(): continue
			await load_fixture(mode); await click("SAVE / TRANSFER")
			var io:=Uncertain.new()
			for path in disk_bytes(): io.files[path]=FileAccess.get_file_as_string(path)
			scene.save_io=io; var before:=whole_memory(); var incoming:=code_for(fixtures.incoming,target_mode)
			scene.code_edit.text=incoming; await click("IMPORT"); await dwell(2)
			var claim: String=scene.notice.text
			if scene.get("recovery_pending")==true: claim=scene.recovery.message
			check(whole_memory()==before,"uncertain real Import retains every current live value")
			check(scene.get("recovery_pending")==true,"uncertain real Import owns an explicit pending decision")
			io.unreadable=false; var selected:=S.read(S.PATH,io)
			check(not (same_context(selected,S.decode(incoming)) and claim.contains("Current save kept")),"uncertain promoted incoming never claims current whole save kept")
			observations.append({"source_mode":mode,"target_mode":target_mode,"claim":claim,"previous":before,"incoming":incoming,"selected_when_readable":selected})
			materialize_fault(io); await shutdown()
			game_root=ReloadWatch.new(); root.add_child(game_root); await dwell(3); scene=game_root.get_node("Battle")
			check(scene.get("recovery_pending")==true and live_matches(S.decode(code_for(fixtures.source,mode))),"actual-file fresh owner restores original under pending ownership")
			await shutdown()
	FileAccess.open(folder.path_join("import-uncertainty.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details,"events":events,"observations":observations,"scope":"Synthetic complete rule-derived legacy/campaign/profile/settings/parked records; actual ScreenTouch Import and materialized-file fresh owner. Cached headless/Dummy, no native/power-loss/render claim."},"  "))
	print("IMPORT_UNCERTAINTY ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
