extends Node3D
const S = preload("res://scripts/save_store.gd")
const Recovery = preload("res://scripts/import_recovery.gd")
var save_io: Variant=null
func _ready() -> void:
	if get_tree().has_meta("hearth_verified_context"):
		var handoff: Variant=get_tree().get_meta("hearth_verified_context"); get_tree().remove_meta("hearth_verified_context")
		if handoff is Dictionary and handoff.get("code") is String and adopt_verified(handoff.code,handoff.get("backend")): return
		var helper:=Recovery.new(save_io); helper.message="The selected save cannot be read. Play and saves stay paused. Retry recovery."
		replace_owner({"ok":false},helper,{"pending":true,"ok":false},true,true,true)
	else: reload_saved()
func reload_saved() -> void:
	var helper:=Recovery.new(save_io); var status:=helper.read()
	var saved: Dictionary=status.original if status.ok else (S.read(S.PATH,save_io) if not status.pending else {"ok":false})
	var blocked: bool=status.pending or (not saved.ok and helper.active_present())
	if blocked and not status.pending: helper.message="Local saves cannot be read. Play and saves stay paused. Retry reading recovery. Keep the app installed to retain its files."
	replace_owner(saved,helper,status,blocked,blocked,blocked)
func adopt_verified(code: String,backend: Variant=null) -> bool:
	var saved:=S.decode(code)
	if not saved.ok: return false
	save_io=backend
	return replace_owner(saved,Recovery.new(save_io),{"pending":false,"ok":false},false,true,true)
func replace_owner(saved: Dictionary,helper: RefCounted,status: Dictionary,blocked: bool,force_pause: bool,skip_save: bool) -> bool:
	var scene:=Node3D.new()
	scene.set_script(load("res://scripts/main.gd" if saved.ok and saved.state.schema==1 else "res://scripts/campaign_main.gd"))
	scene.save_io=save_io; scene.recovery=helper; scene.recovery_status=status
	scene.boot_context=saved.duplicate(true); scene.boot_bound=true; scene.recovery_pending=blocked
	scene.force_boot_pause=force_pause; scene.skip_boot_save=skip_save
	# Keep the prior owner frozen until its fully initialized replacement exists.
	var previous:=get_children(); add_child(scene)
	if not scene.boot_ok:
		remove_child(scene); scene.queue_free(); return false
	for child in previous: remove_child(child); child.queue_free()
	scene.name="Battle"
	return true
