extends Node3D
const S = preload("res://scripts/save_store.gd")
const ImportRecovery = preload("res://scripts/import_recovery.gd")
var save_io: Variant = null
var session: Node3D

func _ready() -> void:
	var recovery := ImportRecovery.new(save_io)
	var had_handoff := get_tree().has_meta("frontline_import_context")
	var handed: Variant = get_tree().get_meta("frontline_import_context") if had_handoff else null
	if get_tree().has_meta("frontline_import_context"): get_tree().remove_meta("frontline_import_context")
	var verified_handoff := {"ok":false}
	if handed is Dictionary:
		var payload := JSON.stringify(handed)
		verified_handoff = S.decode(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
	var has_handoff: bool = verified_handoff.ok
	if had_handoff and not has_handoff:
		blocked_view("The verified import handoff could not be read. Play and local saving stay paused. Retry recovery.")
		return
	var pending: Dictionary = {"pending":false,"ok":false} if has_handoff else recovery.read()
	var saved: Dictionary = verified_handoff.duplicate(true) if has_handoff else (pending.original if pending.ok else S.read(S.PATH,save_io))
	if pending.pending and not pending.ok and not saved.ok:
		blocked_view(recovery.message)
		return
	var script: Script = load("res://scripts/main.gd") if saved.ok and saved.state.catalog == 1 else load("res://scripts/campaign_main.gd")
	session = Node3D.new()
	session.set_script(script)
	session.name = "Session"
	session.save_io = save_io
	session.startup_bound = true
	session.startup_context = saved.duplicate(true)
	session.startup_status = pending.duplicate(true)
	session.startup_paused = has_handoff
	session.import_recovery = recovery
	add_child(session)

func reload_session() -> void:
	for child in get_children(): child.queue_free()
	session = null
	await get_tree().process_frame
	_ready()

func blocked_view(message: String) -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(40,200); box.size = Vector2(640,400)
	var text := Label.new(); text.text = message
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size",24); box.add_child(text)
	var retry := Button.new(); retry.text = "RETRY RECOVERY READ"; retry.custom_minimum_size = Vector2(620,96)
	retry.pressed.connect(reload_session); box.add_child(retry); add_child(box)
