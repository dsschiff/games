extends "res://scripts/main.gd"
const Store = preload("res://scripts/campaign_store.gd")
var host: Node
var recovered_start:=false
func _ready() -> void:
	state = host.ctx.legacy.duplicate(true)
	settings = host.ctx.settings.duplicate(true)
	paused = recovered_start or state.phase == "playing"
	build_world()
	build_ui()
	button(resume_button.get_parent(), "EVACUATION MAP", func(): host.leave_legacy())
	get_viewport().size_changed.connect(layout)
	layout()
	refresh()
	if not recovered_start: persist()

func persist() -> bool:
	if host == null or host.recovery_pending: return false
	host.ctx.legacy = state.duplicate(true)
	host.ctx.settings = settings.duplicate(true)
	var okay: bool = host.persist()
	save_message = "" if okay else "SAVE FAILED — progress is only in memory."
	return okay

func export_code() -> void:
	if recovery_blocked(): return
	host.ctx.legacy = state.duplicate(true)
	host.ctx.settings = settings.duplicate(true)
	var code := Store.encode(host.ctx, int(Store.read(Store.PATH, host.files).revision))
	code_box.text = code
	copy_service.begin(code)
	transfer_status.text = copy_service.feedback

func import_code() -> void:
	if recovery_blocked(): return
	host.begin_import(code_box.text)

func close_transfer() -> void:
	if recovery_blocked(): return
	super.close_transfer()
	if host.ctx.mode == "campaign": host.leave_legacy()

func recovery_blocked() -> bool: return host!=null and host.recovery_pending
func show_recovery() -> void:
	if host!=null: host.show_recovery()
func refresh() -> void:
	if recovery_blocked(): return
	super.refresh()
