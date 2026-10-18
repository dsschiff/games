extends Node3D
const S = preload("res://scripts/save_store.gd")
var session: Node3D

func _ready() -> void:
	var saved := S.read()
	var script: Script = load("res://scripts/main.gd") if saved.ok and saved.state.catalog == 1 else load("res://scripts/campaign_main.gd")
	session = Node3D.new()
	session.set_script(script)
	session.name = "Session"
	add_child(session)

func reload_session() -> void:
	session.queue_free()
	await get_tree().process_frame
	_ready()
