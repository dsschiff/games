extends "res://tests/import_recovery.gd"
class Owner extends "res://scripts/main.gd":
	var note_rows: Array[Dictionary]=[]
	var recording:=false
	func lines(value: String,at: Vector2,width: float,size: int,color: Color=Color("f4eee3"),max_lines: int=3,line_height: float=0.0) -> void:
		recording=transfer and value==note and size==19
		super.lines(value,at,width,size,color,max_lines,line_height); recording=false
	func text_at(value: String,at: Vector2,size: int,color: Color=Color("f4eee3")) -> void:
		if recording: note_rows.append({"text":value,"at":at,"size":size})
		super.text_at(value,at,size,color)
	func _draw() -> void:
		note_rows.clear(); super._draw()
func boot(io: Variant=null) -> void:
	game=Owner.new(); game.save_io=io; root.add_child(game); current_scene=game; await ticks()
class Port extends RefCounted:
	var supported:=true
	var accepted:=true
	var puts:=0
	var gets:=0
	var text:=""
	var delay:=3
	var written:=0
	var on_available:=Callable()
	var on_put:=Callable()
	var on_get:=Callable()
	func available() -> bool:
		var callback:=on_available; on_available=Callable()
		if callback.is_valid(): callback.call()
		return supported
	func put(value: String) -> bool:
		puts+=1; text=value; written=Engine.get_process_frames()
		var callback:=on_put; on_put=Callable()
		if callback.is_valid(): callback.call()
		return accepted and supported
	func get_text() -> String:
		gets+=1
		var callback:=on_get; on_get=Callable()
		if callback.is_valid(): callback.call()
		return text if Engine.get_process_frames()-written>=delay else "unrelated clipboard text"
func port(mode: String) -> Port:
	var value:=Port.new(); value.supported=mode!="unsupported"; value.accepted=mode!="rejected"; value.delay=100000 if mode=="never" else (0 if mode=="exact" else 3)
	return value
func run() -> void:
	for kind in [0,1,2,3]:
		for mode in ["exact","delay","never","unsupported","rejected"]:
			var io:=seed_io(kind); await boot(io); await touch("settings"); await touch("transfer")
			var before:=capture(); var raw: Dictionary=io.files.duplicate(true); var backend:=port(mode); game.clipboard_backend=backend
			await touch("copy"); var code: String=game.editor.text
			check(not game.note.to_lower().contains("copied"),"normal Copy never claims success before exact confirmation: "+mode)
			await ticks(45)
			check(game.note.contains("checked") if mode in ["exact","delay"] else game.note.to_lower().contains("unavailable" if mode=="unsupported" else "not confirmed"),"normal Copy distinguishes confirmed/unconfirmed/unavailable: "+mode)
			check(game.editor.visible and game.editor.text==code and S.decode(code).ok and game.editor.has_selection() and game.editor.get_selected_text()==code,"manual full code remains readable and selected after Copy")
			check(backend.puts==(0 if mode=="unsupported" else 1) and backend.gets<10,"single write and bounded reads; unsupported makes no clipboard requests")
			if mode in ["unsupported","rejected"]: check(backend.gets==0,"unsupported/rejected cannot read clipboard")
			for viewport in [Vector2i(344,642),Vector2i(690,829),Vector2i(1066,600)]:
				root.size=viewport; game.queue_redraw(); await ticks(3)
				check(game.note_rows.size()>0 and game.note_rows.size()<=3,"real status stays within the three-line transfer block")
				for row in game.note_rows:
					var rect:=Rect2(row.at-Vector2(0,game.font.get_ascent(19)),Vector2(game.font.get_string_size(row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x,game.font.get_height(19)))
					check(Rect2(42,892,516,174).encloses(rect) and not game.buttons().close_transfer.intersects(rect),"actual status font cells fit below Return")
					check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(root.get_final_transform()*game.global_transform*rect),"status remains on cover/inner/wide canvas")
			check(same_live(before) and io.files==raw,"copy preserves full pinned campaign/challenge/parked/settings/profile and raw files")
			await stop()
	root.size=Vector2i(600,1066)
	# In-call normal Copy replacement must own feedback even if the code is identical.
	for phase in ["available","put","get"]:
		for action_name in ["replace","close","destroy","edit"]:
			var io:=seed_io(1); await boot(io); await touch("settings"); await touch("transfer")
			var owner: Node=game; var before:=capture(); var raw: Dictionary=io.files.duplicate(true); var backend:=port("delay"); owner.clipboard_backend=backend; var helper: RefCounted=owner.normal_copy
			var callback:=func():
				if action_name=="replace": owner.action("copy")
				elif action_name=="close": owner.action("close_transfer")
				elif action_name=="edit": owner.editor.text="new in-call editor text"
				else: owner.queue_free()
			if phase=="available": backend.on_available=callback
			elif phase=="put": backend.on_put=callback
			else: backend.on_get=callback
			await touch("copy"); await ticks(45)
			if action_name=="replace": check(helper.outcome=="confirmed" and backend.puts==(1 if phase=="available" else 2),"same-text newer Copy owns its generation through reentrant "+phase)
			else: check(not helper.pending and helper.outcome!="confirmed","in-call close/destruction cannot confirm stale owner: "+phase)
			check(io.files==raw,"reentrant clipboard request never writes a save")
			if is_instance_valid(game): check(same_live(before),"reentrant clipboard request preserves complete live context"); await stop()
	# Clipboard reads for Paste are also external/reentrant, never assign after owner/code generation changes.
	for phase in ["available","get"]:
		for action_name in ["replace","close","destroy","edit"]:
			var io:=seed_io(2); await boot(io); await touch("settings"); await touch("transfer")
			var owner: Node=game; var original: String=owner.editor.text; var backend:=port("exact"); backend.text="pasted replacement"; owner.clipboard_backend=backend
			var callback:=func():
				if action_name=="replace": owner.action("copy")
				elif action_name=="close": owner.action("close_transfer")
				elif action_name=="edit": owner.editor.text="new in-call editor text"
				else: owner.queue_free()
			if phase=="available": backend.on_available=callback
			else: backend.on_get=callback
			await touch("paste"); await ticks(45)
			if is_instance_valid(game):
				check(game.editor.text==("new in-call editor text" if action_name=="edit" else original),"Paste cannot overwrite editor after in-call "+action_name+" / "+phase)
				if action_name=="replace": check(game.normal_copy.outcome=="confirmed","new Copy remains authoritative during stale Paste")
				await stop()
	for supported in [false,true]:
		var io:=seed_io(2); await boot(io); await touch("settings"); await touch("transfer")
		var backend:=port("exact"); backend.supported=supported; backend.text=""; game.clipboard_backend=backend; var original: String=game.editor.text
		await touch("paste")
		check(game.editor.text==("" if supported else original),"supported empty Paste retains existing behavior; unsupported retains selected manual code")
		check(backend.gets==(1 if supported else 0) and backend.puts==0,"Paste checks capability and never writes clipboard")
		await stop()
	# External calls can invalidate only the editor while the owner survives.
	for action_name in ["copy","paste"]:
		for phase in ["available","get"]:
			for replace_editor in [false,true]:
				var io:=seed_io(2); await boot(io); await touch("settings"); await touch("transfer")
				var owner: Node=game; var before:=capture(); var raw: Dictionary=io.files.duplicate(true); var backend:=port("delay"); game.clipboard_backend=backend
				var callback:=func():
					owner.editor.free()
					if replace_editor:
						owner.editor=TextEdit.new(); owner.editor.text="replacement editor"; owner.add_child(owner.editor)
				if phase=="available": backend.on_available=callback
				else: backend.on_get=callback
				await touch(action_name); await ticks(45)
				check(not game.normal_copy.pending and not game.note.contains("checked save code") and not game.note.contains("Waiting"),"freed/replaced editor cannot receive stale Copy acknowledgment")
				if replace_editor: check(game.editor.text=="replacement editor","stale read never changes a replacement editor")
				else: check(not is_instance_valid(game.editor),"freed editor is not dereferenced after external callback")
				check(same_live(before) and io.files==raw,"editor-only destruction/replacement preserves whole live/save context")
				await stop()
	for action_name in ["edit","typed","paste","import","direct_import","return","back","focus","destroy"]:
		var io:=seed_io(1); await boot(io); await touch("settings"); await touch("transfer")
		var backend:=port("never"); game.clipboard_backend=backend; await touch("copy"); var helper: RefCounted=game.normal_copy
		if action_name=="edit": game.editor.text="edited"
		elif action_name=="typed":
			var point: Vector2=root.get_final_transform()*game.to_global(game.editor.get_rect().get_center())
			for pressed in [true,false]:
				var event:=InputEventScreenTouch.new(); event.position=point; event.pressed=pressed; Input.parse_input_event(event); Input.flush_buffered_events(); events.append({"target":"editor","pressed":pressed}); await ticks(1)
			for key in [KEY_A,KEY_X]:
				for pressed in [true,false]:
					var event:=InputEventKey.new(); event.keycode=key; event.ctrl_pressed=key==KEY_A; event.unicode=120 if key==KEY_X else 0; event.pressed=pressed; Input.parse_input_event(event); Input.flush_buffered_events(); events.append({"target":"typed","key":key,"pressed":pressed}); await ticks(1)
			check(game.editor.text=="x","actual touch and typed replacement edit selected save text")
		elif action_name=="paste": await touch("paste")
		elif action_name=="import": game.editor.text="invalid"; await touch("import")
		elif action_name=="direct_import": game.begin_import("invalid")
		elif action_name=="return": await touch("close_transfer")
		elif action_name=="back": game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		elif action_name=="focus": game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		else: game.queue_free()
		await ticks(45)
		check(not helper.pending and helper.outcome!="confirmed","changed code/menu/lifecycle/owner cancels late acknowledgment: "+action_name)
		if is_instance_valid(game):
			check(not game.note.contains("Waiting") and not game.note.contains("checked save code"),"canceled normal Copy cannot leave waiting or late success")
			await stop()
	# A pending Import retains sole adoption authority; normal Copy cannot release or change it.
	var io:=seed_io(1); await boot(io); await touch("settings"); await touch("transfer")
	var backend:=port("never"); game.clipboard_backend=backend; await touch("copy"); var helper: RefCounted=game.normal_copy
	game.editor.text=S.encode(fixture(2)); io.fail_destination=true; await touch("import")
	check(game.import_pending and game.paused and not helper.pending,"Import admission cancels normal Copy and transfers freeze to unchanged journal")
	var pending:=capture(); var raw: Dictionary=io.files.duplicate(true)
	game.start_normal_copy(); await ticks(45)
	check(same_live(pending) and io.files==raw and game.import_pending,"normal Copy cannot mutate or bypass pending recovery")
	reset_fault(io); await ui_touch("previous"); var restored: Dictionary=game.data.duplicate(true)
	check(not game.import_pending and game.paused and not helper.pending,"verified Keep Previous remains paused without stale Copy")
	await stop(); materialize(io); game=Scene.instantiate(); root.add_child(game); current_scene=game; await ticks(3)
	check(meaning(game.data)==meaning(restored),"uninstrumented materialized shipping owner preserves whole resolved save")
	await stop()
	FileAccess.open(folder.path_join("copy-confirm.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"events":events,"observations":observations,"scope":"CPU/Dummy actual shipping input with labelled validated campaign/challenge/parked fixtures and fake clipboard; not native/render/OS clipboard."}))
	print("TOWER_COPY_CONFIRM ",checks," / ",failures.size()); if failures.is_empty(): print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)
