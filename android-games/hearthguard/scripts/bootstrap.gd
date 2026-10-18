extends Node3D
const S = preload("res://scripts/save_store.gd")

func _ready() -> void:
	reload_saved()

func reload_saved() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var saved := S.read()
	var scene := Node3D.new()
	scene.set_script(load("res://scripts/main.gd" if saved.ok and saved.state.schema == 1 else "res://scripts/campaign_main.gd"))
	scene.name = "Battle"
	add_child(scene)
