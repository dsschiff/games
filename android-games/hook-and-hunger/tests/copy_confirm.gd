extends "res://tests/import_recovery.gd"
class Clipboard extends RefCounted:
	var supported := true
	var accepted := true
	var expected := ""
	var observed := "old unrelated text"
	var delay_frames := 3
	var written_frame := 0
	var puts := 0
	var gets := 0
	var on_available:=Callable()
	var on_put:=Callable()
	var on_get:=Callable()
	func available() -> bool:
		var callback:=on_available; on_available=Callable()
		if callback.is_valid(): callback.call()
		return supported
	func put(text: String) -> bool:
		puts+=1; expected=text; written_frame=Engine.get_process_frames()
		var callback:=on_put; on_put=Callable()
		if callback.is_valid(): callback.call()
		return accepted
	func get_text() -> String:
		gets+=1
		var callback:=on_get; on_get=Callable()
		if callback.is_valid(): callback.call()
		return expected if accepted and Engine.get_process_frames()-written_frame>=delay_frames else observed
var typed_events: Array=[]
func frames(count: int=45) -> void:
	for frame in count: await process_frame
func fake(mode: String) -> Clipboard:
	var port:=Clipboard.new(); port.supported=mode!="unsupported"; port.accepted=mode!="rejected"
	port.delay_frames=100000 if mode=="never" else (0 if mode=="exact" else 3)
	return port
func notice_visible(label: Label,description: String) -> void:
	var node: Node=label.get_parent()
	while node!=null:
		if node is ScrollContainer:
			check(node.get_global_rect().encloses(label.get_global_rect()),description+": acknowledgment is visible after actual touch")
			check(label.size.y>=label.get_minimum_size().y,description+": allocated acknowledgment fits wrapped text")
			return
		node=node.get_parent()
	check(false,"acknowledgment has a scroll owner")
func reveal_text(control: Control) -> void:
	var parent: Node=control.get_parent(); var scroll: ScrollContainer
	while parent!=null:
		if parent is ScrollContainer: scroll=parent; break
		parent=parent.get_parent()
	for attempt in 30:
		if scroll.get_global_rect().encloses(control.get_global_rect()): return
		var wheel:=InputEventMouseButton.new(); wheel.position=root.get_final_transform()*scroll.get_global_rect().get_center()
		wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if control.get_global_rect().get_center().y>scroll.get_global_rect().get_center().y else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed=true; Input.parse_input_event(wheel); Input.flush_buffered_events(); await process_frame
func key_event(code: Key,unicode_value: int=0,control: bool=false) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.unicode=unicode_value; event.ctrl_pressed=control; event.pressed=pressed
		typed_events.append({"keycode":code,"unicode":unicode_value,"control":control,"pressed":pressed})
		Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func run() -> void:
	root.size=Vector2i(720,1280)
	for index in 3:
		var context: Dictionary=full_contexts()[index]
		var io:=fresh_io(context); await open_owner(io); var before:=whole(); var files: Dictionary=io.files.duplicate(true)
		for mode in ["exact","delay","never","rejected","unsupported"]:
			var clipboard:=fake(mode); scene.clipboard_backend=clipboard
			await tap("EXPORT"); var exported: String=scene.transfer.text
			check(S.decode(exported).ok and scene.transfer.has_selection() and scene.transfer.get_selected_text()==exported,"actual Export immediately exposes the exact complete selectable code")
			check(not scene.transfer_status.text.begins_with("Copied"),"no immediate Copy success before the poll interval")
			await frames()
			check(scene.transfer_status.text.begins_with("Copied") if mode in ["exact","delay"] else scene.transfer_status.text.contains("unavailable" if mode=="unsupported" else "not confirmed"),"actual Export distinguishes supported confirmation, timeout, rejected write and unsupported")
			check(clipboard.puts==(0 if mode=="unsupported" else 1) and clipboard.gets<10,"Export sets once and polls within a bounded budget")
			if mode in ["unsupported","rejected"]: check(clipboard.gets==0,"unsupported/rejected requests make no clipboard reads")
			notice_visible(scene.transfer_status,"normal Export / "+mode)
			check(whole()==before and io.files==files,"Export never changes complete state/projectiles/profile/ending/settings or raw slots")
		scene.transfer.text=" "+code(full_contexts()[(index+1)%3])+" "; io.mode="active_after_store"; await tap("IMPORT")
		check(scene.import_pending and scene.paused,"actual unconfirmed Import reaches protected pending view")
		if not scene.import_pending or scene.import_recovery.record.is_empty():
			await finish(); return
		var previous: String=scene.import_recovery.original_code; var incoming: String=scene.import_recovery.incoming_code
		var pending: Dictionary=whole(); var raw: Dictionary=io.files.duplicate(true); var uncertainty: String=scene.import_recovery.message
		check(previous.sha256_text()==scene.import_recovery.record.original and incoming.sha256_text()==scene.import_recovery.record.incoming,"retained byte-exact code identities bind both source choices")
		for viewport in [Vector2i(344,642),Vector2i(690,829),Vector2i(1066,600)]:
			root.size=viewport; await frames(4)
			for imported in [false,true]:
				for mode in ["delay","never","unsupported","rejected"]:
					var port:=fake(mode); scene.clipboard_backend=port; await tap("COPY IMPORTED" if imported else "COPY PREVIOUS"); await frames()
					check(port.expected==(incoming if imported else previous) if mode!="unsupported" else port.puts==0,"actual pending Copy uses exact retained source, not re-encoding live state")
					check(scene.recovery_copy_feedback.text.begins_with("Copied") if mode=="delay" else scene.recovery_copy_feedback.text.contains("unavailable" if mode=="unsupported" else "not confirmed"),"pending Copy reports only exact confirmation with honest timeout/capability")
					notice_visible(scene.recovery_copy_feedback,"pending "+str(viewport)+" / "+mode)
					check(scene.import_pending and scene.paused and whole()==pending and io.files==raw and scene.import_recovery.message==uncertainty,"pending polling/export preserves whole data/raw files and separate recovery uncertainty")
					check(port.puts==(0 if mode=="unsupported" else 1) and port.gets<10,"pending Copy never repeats set or polls forever")
				await tap("VIEW IMPORTED CODE" if imported else "VIEW PREVIOUS CODE"); await frames(3)
				check(scene.recovery_code.visible and not scene.recovery_code.editable and scene.recovery_code.text==(incoming if imported else previous) and scene.recovery_code.get_selected_text()==scene.recovery_code.text,"actual View exposes exact read-only selectable retained code")
				check(scene.recovery_scroll.get_global_rect().encloses(scene.recovery_code.get_global_rect()),"View fallback reaches the short-layout scroll area after guarded layout")
				check(scene.import_pending and whole()==pending and io.files==raw and scene.import_recovery.message==uncertainty,"View keeps all recovery ownership/context/uncertainty")
		root.size=Vector2i(720,1280); await frames(4)
		# A new retained-code request invalidates the earlier target, including reentrant set/get calls.
		for phase in ["put","get"]:
			var port:=fake("delay"); scene.clipboard_backend=port
			var replace:=func(): scene._copy_recovery_code(true)
			if phase=="put": port.on_put=replace
			else: port.on_get=replace
			await tap("COPY PREVIOUS"); await frames()
			check(scene.copy_confirm.expected==incoming and scene.copy_confirm.outcome=="confirmed" and port.puts==2,"reentrant replacement copy owns pending status without stale original acknowledgment: "+phase)
			check(whole()==pending and io.files==raw and scene.import_recovery.message==uncertainty,"replacement Copy still cannot mutate local recovery")
		# A failed explicit choice cancels copying; a late read cannot overwrite its recovery error.
		var port:=fake("never"); scene.clipboard_backend=port; await tap("COPY PREVIOUS"); io.mode="active_verify"; await tap("KEEP PREVIOUS"); await frames()
		check(scene.import_pending and not scene.copy_confirm.pending and not scene.recovery_copy_feedback.text.contains("Waiting"),"explicit unresolved choice cancels copy without releasing pending recovery")
		check(whole()==pending,"failed choice preserves complete live state")
		observations.append({"context":context.name,"previous_bytes":previous.to_utf8_buffer().size(),"incoming_bytes":incoming.to_utf8_buffer().size(),"previous_sha256":previous.sha256_text(),"incoming_sha256":incoming.sha256_text(),"live":whole(),"message":scene.import_recovery.message})
	# A completed choice owns the scene handoff; an outstanding Copy cannot follow it.
	for index in 3:
		for use_import in [false,true]:
			var io:=fresh_io(full_contexts()[index]); await open_owner(io)
			var original:=S.encode(scene.state,scene.settings,0,true,scene.profile)
			var incoming:=code(full_contexts()[(index+1)%3]); scene.transfer.text=incoming; io.mode="active_after_store"; await tap("IMPORT")
			check(scene.import_pending,"choice-after-copy fixture reaches uncertain Import")
			if not scene.import_pending: await finish(); return
			var port:=fake("never"); scene.clipboard_backend=port; await tap("COPY IMPORTED")
			var confirm: RefCounted=scene.copy_confirm; io.mode=""; io.promoted=""
			await tap("RETRY IMPORT" if use_import else "KEEP PREVIOUS"); scene.set_physics_process(false)
			var expected:=S.decode(incoming if use_import else original)
			check(not scene.import_pending and scene.paused and matches(whole(),expected),"actual choice after Copy adopts complete context into fresh paused owner")
			await frames()
			check(not confirm.pending and matches(whole(),expected),"late Copy cannot acknowledge or change replacement owner")
			check(matches(S.read(S.PATH,io),expected) and not io.files.has(T.PATH) and not io.files.has(T.PATH+".tmp"),"copy does not prevent exact verified chosen disk/cleanup")
			materialize(io); await reload_disk(expected,"copy-choice materialized shipping owner")
	# Ordinary local play must not carry an invisible pending confirmation across owner/UI changes.
	for action in ["PASTE","IMPORT","RESUME","FOCUS","BACK","EDIT","TYPE","DESTROY"]:
		var io:=fresh_io(full_contexts()[0]); await open_owner(io); var port:=fake("never"); scene.clipboard_backend=port
		await tap("EXPORT"); var confirm: RefCounted=scene.copy_confirm; var generation: int=confirm.generation
		if action=="PASTE": await tap("PASTE")
		elif action=="IMPORT": scene.transfer.text="invalid"; await tap("IMPORT")
		elif action=="RESUME": await tap("RESUME")
		elif action=="FOCUS": scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		elif action=="BACK": scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		elif action=="EDIT": scene.transfer.text="edited"
		elif action=="TYPE":
			await reveal_text(scene.transfer); await touch_point(scene.transfer.get_global_rect().get_center(),"focus save field")
			check(scene.transfer.has_focus(),"actual touch focuses selectable Export field")
			await key_event(KEY_A,0,true); await key_event(KEY_NONE,120)
			check(scene.transfer.text=="x","actual typed replacement changes selected code")
		else: scene.queue_free(); await frames(3)
		await frames(2)
		check(not confirm.pending and confirm.generation!=generation,"owner/panel changes irrevocably cancel late confirmation: "+action)
		await frames()
		if is_instance_valid(scene): check(not scene.transfer_status.text.begins_with("Copied") and not scene.transfer_status.text.contains("Waiting"),"canceled status cannot claim success or wait forever after reopening")
	for phase in ["put","get"]:
		for destroy in [false,true]:
			var io:=fresh_io(full_contexts()[1]); await open_owner(io); var owner: Node=scene
			var port:=fake("delay"); owner.clipboard_backend=port; var confirm: RefCounted=owner.copy_confirm; var before:=whole()
			var cancel_owner:=func():
				if destroy: owner.queue_free()
				else: owner._toggle_menu()
			if phase=="put": port.on_put=cancel_owner
			else: port.on_get=cancel_owner
			var button: Button
			for candidate in owner.find_children("*","Button",true,false):
				if candidate.text=="EXPORT": button=candidate; break
			await reveal_text(button); await touch_point(button.get_global_rect().get_center(),"reentrant Export "+phase)
			await frames(15)
			check(not confirm.pending and confirm.outcome!="confirmed","in-call owner cancellation/destruction cannot confirm stale copy: "+phase)
			if not destroy:
				check(whole()==before and not owner.transfer_status.text.begins_with("Copied") and not owner.menu.visible,"reentrant close retains whole context and local Resume without late acknowledgment")
	# Unknown cold metadata keeps only read retry; it must not invent exportable choices.
	var unknown:=fresh_io(full_contexts()[0]); unknown.files[T.PATH]="torn"; await open_owner(unknown,false,false)
	check(scene.import_pending and scene.recovery_keep.visible==false and scene.recovery_retry.text=="RETRY RECOVERY READ","unknown recovery remains retry-read-only")
	check(scene.recovery_exports.values().all(func(button): return not button.visible) and not scene.recovery_code.visible,"unknown recovery hides every retained Copy/View control and raw editor")
	await finish()
func finish() -> void:
	if is_instance_valid(scene): scene.free()
	await process_frame
	FileAccess.open(capture_dir.path_join("copy-confirm.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"details":report,"events":events,"typed_events":typed_events,"observations":observations,"scope":"CPU/headless/Dummy owning UI with labelled rule-derived complete legacy/campaign-projectile/arena-parked-ending fixtures and fake clipboard. Actual ScreenTouch and font/control layout, not OS/native clipboard/render/phone acceptance."}))
	print("HOOK_COPY_CONFIRM ",checks," / ",failures); print("SUITE_COMPLETE: ","PASS" if failures==0 else "FAIL"); quit(0 if failures==0 else 1)
