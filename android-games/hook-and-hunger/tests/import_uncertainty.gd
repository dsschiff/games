extends "res://tests/save_commit.gd"

class Uncertain extends RefCounted:
	var files := {}
	var promoted := ""
	var unreadable := false
	func exists(path: String) -> bool: return files.has(path)
	func read_text(path: String) -> String:
		if unreadable and path == promoted: return "temporarily unreadable"
		return str(files.get(path,""))
	func write_text(path: String,text: String) -> bool:
		files[path]=text; return true
	func rename(from: String,to: String) -> bool:
		files[to]=files[from]; files.erase(from)
		if to in [S.PATH+"0",S.PATH+"1"]: promoted=to
		return true
	func remove(path: String) -> bool: files.erase(path); return true

func run() -> void:
	root.size=Vector2i(720,1280)
	for original in contexts():
		for incoming in contexts():
			var io := Uncertain.new()
			check(S.write(original.state,original.settings,S.PATH,io,false,original.profile),"seed previous whole context")
			await load_live(io)
			var previous := whole()
			scene.transfer.text=code(incoming)
			io.unreadable=true
			await click("IMPORT")
			var label: String=original.name+" to "+incoming.name
			check(whole()==previous,"uncertain Import retains exact live fields: "+label)
			check(scene.get("import_pending")==true,"uncertain Import enters pending recovery: "+label)
			check(not scene.transfer_status.text.contains("Current progress retained"),"uncertain Import avoids false disk-retention claim: "+label)
			io.unreadable=false
			observations.append({"case":label,"status":scene.transfer_status.text,"live":whole(),"selected_after_reads_recover":S.read(S.PATH,io)})
			materialize(io)
			await reload_disk(S.decode(code(original)),"uncertain Import original context: "+label)
	if is_instance_valid(scene): scene.free()
	await process_frame
	FileAccess.open(capture_dir.path_join("import-uncertainty.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"events":events,"observations":observations,"scope":"Synthetic validated complete contexts and transient fault backend; actual Import mouse events and materialized-file reload in same headless process, not Android/process-kill/physical fault."},"  "))
	print("IMPORT_UNCERTAINTY ",checks," failures=",failures)
	print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)

func load_live(io: RefCounted) -> void:
	await super.load_live(io)
	current_scene = scene

func materialize(io: RefCounted) -> void:
	var user := ProjectSettings.globalize_path("user://")
	check(user.replace("\\","/").to_lower().begins_with(capture_dir.replace("\\","/").to_lower()),"materialized recovery files stay inside isolated capture directory")
	for name in DirAccess.get_files_at(user):
		if name.begins_with("hook-save") or name.begins_with("hook-import-pending") or name.begins_with("hook-recovery-copy-"):
			DirAccess.remove_absolute(user.path_join(name))
	for path in io.files:
		check(str(path).begins_with("user://hook-"),"fixture path is Hook scoped")
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(io.files[path]); file.flush(); file.close()
