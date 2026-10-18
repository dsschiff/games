extends "res://scripts/main.gd"
const Store = preload("res://scripts/campaign_store.gd")
var host: Node
func _ready() -> void:
	state = host.ctx.legacy.duplicate(true)
	settings = host.ctx.settings.duplicate(true)
	paused = state.phase == "playing"
	build_world()
	build_ui()
	button(resume_button.get_parent(), "EVACUATION MAP", func(): host.leave_legacy())
	get_viewport().size_changed.connect(layout)
	layout()
	refresh()
	persist()

func persist() -> bool:
	if host == null: return false
	host.ctx.legacy = state.duplicate(true)
	host.ctx.settings = settings.duplicate(true)
	var okay: bool = host.persist()
	save_message = "" if okay else "SAVE FAILED — progress is only in memory."
	return okay

func export_code() -> void:
	host.ctx.legacy = state.duplicate(true)
	host.ctx.settings = settings.duplicate(true)
	var code := Store.encode(host.ctx, int(Store.read(Store.PATH, host.files).revision))
	code_box.text = code
	copy_service.begin(code)
	transfer_status.text = copy_service.feedback

func import_code() -> void:
	copy_service.cancel()
	var saved := Store.decode(code_box.text)
	if not saved.ok:
		transfer_status.text = "Invalid code. Journey unchanged."
		return
	var io: Variant = files if files != null else host.files
	if not Store.write(saved.context, Store.PATH, io, true):
		transfer_status.text = "Import could not be stored. Journey unchanged."
		return
	host.ctx = saved.context
	host.state = host.ctx.campaign
	host.settings = host.ctx.settings
	state = host.ctx.legacy.duplicate(true)
	settings = host.ctx.settings.duplicate(true)
	paused = true
	host.paused = true
	host.build_world()
	host.world.hide()
	host.hud.hide()
	camera.current = true
	transfer_status.text = "Imported and stored. Close, then Resume."
	save_message = ""
	refresh()

func close_transfer() -> void:
	super.close_transfer()
	if host.ctx.mode == "campaign": host.leave_legacy()
