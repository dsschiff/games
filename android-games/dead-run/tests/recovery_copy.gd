extends "res://tests/import_recovery.gd"
## Exact whole-context read-only export controls; actual touch, no OS clipboard simulation.
class CopyFault extends JournalFault:
	var writes:=0
	var renames:=0
	var removes:=0
	func write_text(path: String,code: String) -> bool:
		writes+=1; return super.write_text(path,code)
	func rename(from: String,to: String) -> bool:
		renames+=1; return super.rename(from,to)
	func remove(path: String) -> bool:
		removes+=1; return super.remove(path)
func own_ui(game: Node) -> Node:
	var child: Node=game.get("legacy_view")
	return game if game.recovery_pending or not is_instance_valid(child) else child
func touch_button(game: Node,title: String) -> void:
	for b in own_ui(game).hud.find_children("*","Button",true,false):
		if b.text==title and b.is_visible_in_tree() and not b.disabled:
			var parent: Node=b.get_parent()
			while parent!=null and not parent is ScrollContainer: parent=parent.get_parent()
			if parent is ScrollContainer: parent.ensure_control_visible(b); await ticks()
			await tap(b.get_global_rect().get_center(),title); return
	check(false,"actual visible recovery control "+title)
func snapshot(game: Node) -> Dictionary:
	var value:={"state":game.state.duplicate(true),"settings":game.settings.duplicate(true)}
	var context: Variant=game.get("ctx")
	if context is Dictionary: value.context=context.duplicate(true)
	var child: Node=game.get("legacy_view")
	if is_instance_valid(child): value.child_state=child.state.duplicate(true); value.child_settings=child.settings.duplicate(true)
	return value
func owner_boot(io: CopyFault,standalone: bool) -> Node:
	if not standalone: return await boot(io)
	var game: Node=load("res://main.tscn").instantiate(); game.files=io; root.add_child(game); current_scene=game; game.set_physics_process(false); await ticks(); return game
func portable(kind: int,standalone: bool) -> String:
	if not standalone: return fixture(kind,99)
	var d:=Store.decode(fixture(kind)); return Old.encode(d.context.legacy,d.context.settings,99)
func run() -> void:
	check(DisplayServer.get_name()=="headless" and not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD),"headless probe cannot call unsupported OS clipboard")
	check(ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"all data isolated")
	if not failures.is_empty(): quit(1); return
	for extent in [Vector2i(450,1000),Vector2i(720,1280),Vector2i(1000,900),Vector2i(900,450)]:
		root.size=extent
		for kind in [1,2,3]:
			var standalone: bool=kind==3; var source:=portable(1 if standalone else kind,standalone)
			var target:=portable(2 if standalone or kind==1 else 1,standalone)
			var io:=CopyFault.new(); io.files[Store.PATH+"0"]=source
			var game:=await owner_boot(io,standalone); await touch_button(game,"SAVE / TRANSFER")
			own_ui(game).code_box.text=target; io.unreadable_after=1; await touch_button(game,"IMPORT"); await ticks()
			var before:=snapshot(game); var files: Dictionary=io.files.duplicate(true)
			var counts:=[io.writes,io.renames,io.removes]; var record: Dictionary=game.recovery.record.duplicate(true)
			var previous_code: String=game.recovery.original_code; var imported_code: String=game.recovery.incoming_code; var issue: String=game.recovery.message
			check(game.recovery_pending and game.paused and not previous_code.is_empty() and imported_code==target,"actual Import retains known whole codes under pending owner")
			var child: Node=game.get("legacy_view")
			check(not is_instance_valid(child) or child.paused and child.recovery_blocked(),"legacy child remains frozen with its host")
			for key in ["copy_previous","copy_incoming"]:
				check(game.recovery_buttons.has(key),"explicit pending code-copy control "+key)
				if not game.recovery_buttons.has(key): continue
				var b: Button=game.recovery_buttons[key]; var scroll: ScrollContainer=game.recovery_panel.get_child(0)
				scroll.ensure_control_visible(b); await ticks()
				check(scroll.get_global_rect().encloses(b.get_global_rect()) and b.size.y>=88,"copy target is touch-sized and scroll-reachable "+str(extent)+key)
				game.recovery_code.text="display text is not the archive source"
				await touch_button(game,b.text); await ticks()
				check(game.recovery_copy_feedback.text.begins_with("Clipboard unavailable") and not game.recovery_copy_feedback.text.contains("copied"),"unsupported clipboard reports no false success")
				check(scroll.get_global_rect().encloses(game.recovery_copy_feedback.get_global_rect()),"separate copy feedback revealed after actual touch")
				check(game.recovery_summary.text.begins_with(issue) and not game.recovery_code.visible,"original storage explanation and summary-first layout preserved")
				check(game.recovery_pending and game.paused and snapshot(game)==before,"copy never adopts/resumes or changes whole live contexts")
				check(io.files==files and [io.writes,io.renames,io.removes]==counts,"copy never writes any slot/archive/journal byte")
				check(game.recovery.record==record and game.recovery.original_code==previous_code and game.recovery.incoming_code==imported_code,"copy retains exact validated strings and pending decision")
			if game.recovery_buttons.has("copy_previous"):
				var scroll: ScrollContainer=game.recovery_panel.get_child(0)
				for key in ["retry","previous","copy_previous","copy_incoming","view_previous","view_incoming"]:
					var b: Button=game.recovery_buttons[key]; scroll.ensure_control_visible(b); await ticks()
					check(scroll.get_global_rect().encloses(b.get_global_rect()) and b.size.y>=88,"every choice reachable after long copy feedback "+key+str(extent))
				await touch_button(game,"VIEW / EXPORT PREVIOUS CODE")
				check(game.recovery_code.text==previous_code and not game.recovery_code.editable,"previous View fallback is exact and read-only")
				await touch_button(game,"VIEW / EXPORT IMPORTED CODE")
				check(game.recovery_code.text==imported_code and not game.recovery_code.editable,"imported View fallback is exact and read-only")
				check(snapshot(game)==before and io.files==files and [io.writes,io.renames,io.removes]==counts,"View fallback leaves full live/storage context unchanged")
				game.recovery.original_code=""; game.show_recovery(); await ticks()
				check(game.recovery_buttons.copy_previous.disabled and not game.recovery_buttons.copy_incoming.disabled,"individual unavailable code cannot export empty data")
				game.recovery.original_code=previous_code; game.show_recovery(); await ticks(); reset_fault(io)
				var use_import: bool=kind==1
				await touch_button(game,"RETRY IMPORT" if use_import else "KEEP PREVIOUS WHOLE SAVE"); await ticks()
				check(not game.recovery_pending and game.paused and game.recovery_copy_feedback.text.is_empty(),"explicit choice remains reachable and clears copy feedback")
				if standalone:
					var wanted: Dictionary=Store.decode(imported_code if use_import else previous_code).context
					check(game.state==wanted.legacy and game.settings==wanted.settings and same(Store.read(Store.PATH,io),Store.decode(imported_code if use_import else previous_code)),"standalone legacy choice preserves whole selected save and durable readback")
				else: check(same(live(game),Store.decode(imported_code if use_import else previous_code)) and same(Store.read(Store.PATH,io),Store.decode(imported_code if use_import else previous_code)),"host/legacy whole selected context matches durable readback")
			observations.append({"size":[extent.x,extent.y],"kind":kind,"original_sha256":previous_code.sha256_text(),"incoming_sha256":imported_code.sha256_text(),"record":record})
			game.queue_free(); await ticks()
		for standalone in [false,true]:
			var io:=CopyFault.new(); io.files[Store.PATH+"0"]=portable(1,standalone); io.files[marker()]="damaged recovery marker"
			var game:=await owner_boot(io,standalone); var before:=snapshot(game); var files: Dictionary=io.files.duplicate(true); var counts:=[io.writes,io.renames,io.removes]
			check(game.recovery_pending and game.paused and game.recovery.record.is_empty(),"cold unknown marker remains blocked without enumerated choices")
			for key in game.recovery_buttons: check(game.recovery_buttons[key].visible==(key=="read"),"unknown marker offers retry-read only "+key)
			await touch_button(game,"RETRY RECOVERY READ"); await ticks()
			check(game.recovery_pending and snapshot(game)==before and io.files==files and [io.writes,io.renames,io.removes]==counts,"unknown retry read cannot write/adopt/default or enumerate archives")
			game.queue_free(); await ticks()
	var output:={"checks":checks,"failures":failures,"events":events,"observations":observations,"limits":"Synthetic complete contexts and typed backend; actual ScreenTouch/scroll geometry for campaign host, legacy child and standalone legacy. CPU/headless/Dummy unsupported clipboard branch only; no OS clipboard or native/render/phone claim."}
	FileAccess.open(folder.path_join("recovery-copy.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("DEAD_COPY ",checks," / ",failures.size()," failures / ",events.size()," touch events"); quit(0 if failures.is_empty() else 1)
