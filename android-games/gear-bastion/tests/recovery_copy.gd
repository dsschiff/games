extends "res://tests/import_recovery.gd"
## Actual touch on pending-copy controls; headless deliberately cannot verify OS clipboard.
func run() -> void:
	check(DisplayServer.get_name()=="headless" and not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD),"CPU probe never invokes unsupported OS clipboard")
	check(ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(folder.replace("\\","/").to_lower()),"isolated user data")
	if not failures.is_empty(): quit(1); return
	for size in [Vector2i(1080,2520),Vector2i(1968,2184),Vector2i(2184,1968),Vector2i(800,450)]:
		root.size=size
		for kind in [0,2,3]:
			var source:=fixture(0 if kind==0 else 2)
			if kind==3:
				var terminal:=Store.decode(source); terminal.state.phase="defeat"
				source=Store.encode(terminal.state,terminal.settings,17,true,terminal.profile)
			var target:=fixture(1,99); var io:=JournalFault.new(); io.files[Store.PATH]=source
			check(Store.decode(source).ok,"complete source validates "+str(kind))
			var game:=await boot(io)
			game.safe_area_override=Rect2(25,40,size.x-60,size.y-90); game.refresh_layout()
			await tap(game.get_global_transform_with_canvas()*game.buttons().save.get_center(),"Save")
			game.save_text.text=target; io.unreadable_destination_suffix="bastion-save.json"; io.unreadable_after=1
			await dialog_button(game,"Import"); await ticks()
			var prior:=live(game); var raw_state: Dictionary=game.state.duplicate(true); var files:=io.files.duplicate(true); var times:=io.times.duplicate(true)
			var writes:=io.write_count; var renames:=io.rename_count; var record: Dictionary=game.recovery.record.duplicate(true)
			var original_code: String=game.recovery.original_code; var incoming_code: String=game.recovery.incoming_code
			var issue: String=game.recovery.message
			check(game.recovery_pending and game.paused and same(prior,Store.decode(source)),"actual uncertain Import is frozen whole context")
			for key in ["copy_previous","copy_incoming"]:
				check(game.recovery_buttons.has(key),"explicit pending touch control "+key)
				if not game.recovery_buttons.has(key): continue
				var b: Button=game.recovery_buttons[key]
				game.dialog_scrolls[game.save_dialog].ensure_control_visible(b); await ticks()
				var scroll: ScrollContainer=game.dialog_scrolls[game.save_dialog]
				check(b.size.y>=80 and scroll.get_global_rect().encloses(b.get_global_rect()),"copy target is touch-sized and scroll-reachable "+str(size)+key)
				await dialog_button(game,b.text); await ticks()
				check(game.recovery_copy_feedback.text.contains("Clipboard unavailable") and not game.recovery_copy_feedback.text.contains("copied"),"unsupported clipboard gives honest feedback "+key)
				check(game.recovery_summary.text.begins_with(issue) and not game.save_text.visible,"copy preserves failure explanation and summary-first layout")
				check(game.recovery_pending and game.paused and live(game)==prior and game.state==raw_state,"copy preserves complete live context "+key)
				check(io.files==files and io.times==times and io.write_count==writes and io.rename_count==renames,"copy has zero archive/journal/slot mutations "+key)
				check(game.recovery.record==record and game.recovery.original_code==original_code and game.recovery.incoming_code==incoming_code,"copy retains immutable exact archived strings and decision "+key)
				check(not game.save_action_row.visible and not game.save_dialog.get_ok_button().visible,"unsafe import controls and dismissal remain hidden")
				observations.append({"size":[size.x,size.y],"kind":kind,"action":b.text,"button":[b.position.x,b.position.y,b.size.x,b.size.y],"feedback":game.recovery_copy_feedback.text,"original_sha256":original_code.sha256_text(),"imported_sha256":incoming_code.sha256_text()})
			if game.recovery_buttons.has("copy_previous"):
				check(game.recovery_summary.position.y<game.recovery_copy_feedback.position.y and game.recovery_copy_feedback.position.y<game.recovery_choices.position.y,"summary and separate copy feedback precede choices")
				for key in ["retry","previous","copy_previous","copy_incoming","view_previous","view_incoming"]:
					var b: Button=game.recovery_buttons[key]
					game.dialog_scrolls[game.save_dialog].ensure_control_visible(b); await ticks()
					check(game.dialog_scrolls[game.save_dialog].get_global_rect().encloses(b.get_global_rect()) and b.size.y>=80,"all choices reachable after longest unsupported feedback "+str(size)+key)
				await dialog_button(game,"View previous code")
				check(game.save_text.text==original_code and not game.save_text.editable,"previous View fallback remains complete and read-only after Copy")
				await dialog_button(game,"View imported code")
				check(game.save_text.text==incoming_code and not game.save_text.editable,"imported View fallback remains complete and read-only after Copy")
				check(live(game)==prior and game.state==raw_state and io.files==files and io.times==times and io.write_count==writes and io.rename_count==renames,"view fallback also leaves all whole context and storage unchanged")
				game.recovery.original_code=""; game.show_recovery(); await ticks()
				check(game.recovery_buttons.copy_previous.disabled and not game.recovery_buttons.copy_incoming.disabled,"unavailable individual archive cannot be copied")
				game.recovery.original_code=original_code
				game.recovery.record={}; game.show_recovery(); await ticks()
				check(not game.recovery_buttons.copy_previous.visible and not game.recovery_buttons.copy_incoming.visible and game.recovery_buttons.read.visible,"unknown recovery never offers empty/default copies")
				game.recovery.record=record; game.show_recovery(); await ticks(); reset_fault(io)
				await choose(game,kind==2); await ticks()
				check(not game.recovery_pending and game.paused and same(live(game),Store.decode(target) if kind==2 else prior),"explicit choice still adopts the selected whole context after copy/view")
				check(not game.recovery_copy_feedback.visible and game.recovery_copy_feedback.text.is_empty(),"resolved recovery clears only copy feedback")
			game.queue_free(); await ticks()
	var output:={"checks":checks,"failures":failures,"observations":observations,"events":events,"limits":"Synthetic full contexts and faults, actual ScreenTouch/scroll geometry, CPU/headless/Dummy unsupported clipboard only. Native exact clipboard readback remains separate."}
	var f:=FileAccess.open(folder.path_join("recovery-copy.json"),FileAccess.WRITE); f.store_string(JSON.stringify(output)); f.close()
	print("GEAR_COPY ",checks," / ",failures.size()," failures / ",events.size()," touch events"); quit(0 if failures.is_empty() else 1)
