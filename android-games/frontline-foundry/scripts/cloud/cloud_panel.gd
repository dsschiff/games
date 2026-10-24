extends PanelContainer
## Optional account actions and local recovery copies; no automatic connection.
const Flow = preload("res://scripts/cloud/game_flow.gd")
const Store = preload("res://scripts/save_store.gd")
var flow: Flow
var body: VBoxContainer
var page := 0
var viewing := ""
var view_title := ""
var archives := false
var read_only := false
var close_view: Callable

func setup(controller: Flow) -> void:
	flow = controller
	flow.changed.connect(rebuild)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12); scroll.add_child(body)
	add_theme_stylebox_override("panel",_style())

func _style() -> StyleBoxFlat:
	var value := StyleBoxFlat.new(); value.bg_color = Color("253c35"); value.content_margin_left=22; value.content_margin_right=22; value.content_margin_top=18; value.content_margin_bottom=18
	return value

func text(value: String, big: bool=false) -> void:
	var line := Label.new(); line.text=value; line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal=Control.SIZE_EXPAND_FILL; line.add_theme_font_size_override("font_size",28 if big else 23); body.add_child(line)

func action(title: String, callback: Callable, disabled: bool=false) -> void:
	var button := Button.new(); button.text=title; button.custom_minimum_size=Vector2(0,96); button.add_theme_font_size_override("font_size",23)
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; button.disabled=disabled; button.pressed.connect(callback); body.add_child(button)

func rebuild() -> void:
	if body==null: return
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	text("OPTIONAL CLOUD / LOCAL COPIES",true)
	text(flow.message)
	if flow.remote_effect=="unknown": text("A cloud operation may still complete after closing. Closing keeps local play available; it does not undo a cloud submission.")
	if not viewing.is_empty() and flow.phase!="confirm":
		text(view_title,true)
		var edit := TextEdit.new(); edit.text=viewing; edit.editable=false; edit.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
		edit.custom_minimum_size.y=210; edit.add_theme_font_size_override("font_size",20); body.add_child(edit)
		text("Complete local save code. Select and copy it to export; no clipboard access is required by this panel.")
		action("BACK TO SAVES",close_code)
		if archives and not read_only and flow.phase not in ["busy","closing","cleanup_required","handoff"]: action("USE THIS COPY LOCALLY",flow.stage_archive.bind(viewing))
	elif archives and flow.phase!="confirm":
		text("LOCAL RECOVERY COPIES",true)
		text("Complete copies retained by local Import and optional cloud actions. These files stay on this device; they are not proof of online backup.")
		var ids := flow.copies.list_ids()
		if ids.is_empty(): text("No readable retained copies on this device yet.")
		var start := mini(page*12,maxi(0,ids.size()-1))
		for i in range(start,mini(ids.size(),start+12)):
			var kept := flow.copies.get_code(ids[i])
			if kept.ok: action("VIEW COPY "+str(i+1)+" / "+ids[i].substr(0,12),show_code.bind(kept.text,"LOCAL COPY / "+ids[i]))
			else: text("Unreadable retained copy / "+ids[i].substr(0,12)+". Kept unchanged.")
		if start+12<ids.size(): action("MORE LOCAL COPIES",next_page)
		if not read_only: action("BACK TO CLOUD",close_archives)
	elif flow.phase=="confirm":
		if not flow._restore_code.is_empty() and flow._action=="restore": text("Selected: "+Flow.describe(Store.decode(flow._restore_code))+"\nSHA256 "+flow._restore_code.sha256_text())
		elif flow._action=="resolve" and flow._selected>=0: text("Selected cloud copy: "+Flow.describe(flow.choices[flow._selected].decoded)+"\nSHA256 "+flow.choices[flow._selected].save.sha256_text())
		else:
			text("This device: "+Flow.describe(Store.decode(flow.local_code))+"\nSHA256 "+flow.local_code.sha256_text())
			if flow.choices.size()==1: text("Cloud record to replace: "+Flow.describe(flow.choices[0].decoded)+"\nSHA256 "+flow.choices[0].save.sha256_text())
		text("Whole context includes profile, settings, campaign and parked legacy progress. Another device may change the cloud save during this check. A submitted backup can be cached offline.")
		action("CONFIRM "+{"restore":"LOCAL IMPORT","backup":"BACKUP SUBMISSION","resolve":"CLOUD CHOICE"}.get(flow._action,"CHOICE"),flow.confirm)
		action("BACK WITHOUT CHANGES",flow.decline)
	else:
		if not flow.local_code.is_empty():
			text("THIS DEVICE\n"+Flow.describe(Store.decode(flow.local_code)))
			action("VIEW / EXPORT THIS DEVICE",show_code.bind(flow.local_code,"THIS DEVICE"),flow.phase in ["busy","closing","cleanup_required","handoff"])
		if flow.phase=="connect": action("CONNECT PLAY GAMES",flow.connect_account)
		if flow.phase in ["ready","choose","submitted","error"] and not flow.player.is_empty() and flow._conflict.is_empty():
			action("CHECK CLOUD SAVES",flow.check_cloud)
			action("BACK UP THIS DEVICE",flow.stage_backup)
		if flow.phase=="choose":
			for i in flow.choices.size():
				var choice: Dictionary = flow.choices[i]
				text("CLOUD COPY "+str(i+1)+"\n"+Flow.describe(choice.decoded)+"\nSAVE SHA256 "+choice.save.sha256_text())
				action("VIEW / EXPORT CLOUD "+str(i+1),show_code.bind(choice.save,"CLOUD COPY "+str(i+1)))
				action("RESTORE CLOUD "+str(i+1)+" LOCALLY",flow.stage_restore.bind(i))
				if not flow._conflict.is_empty(): action("KEEP CLOUD "+str(i+1)+" FOR CONFLICT",flow.stage_resolve.bind(i))
		if flow.phase=="cleanup_required": action("RETRY CLOUD CLEANUP",flow.retry_cleanup)
		if flow.phase not in ["busy","closing","cleanup_required","handoff"]: action("LOCAL RECOVERY COPIES",open_archives)
	if read_only:
		action("CLOSE COPIES / KEEP IMPORT PAUSED",close_view)
	elif flow.phase!="handoff":
		action("CLOSE / KEEP LOCAL PAUSED",flow.cancel)

func show_code(code: String,title: String) -> void:
	viewing=code; view_title=title; rebuild()
func close_code() -> void:
	viewing=""; rebuild()
func open_archives() -> void:
	archives=true; page=0; rebuild()
func close_archives() -> void:
	archives=false; rebuild()
func next_page() -> void:
	page+=1; rebuild()
