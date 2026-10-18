extends SceneTree
const S = preload("res://scripts/campaign_store.gd")
var scene: Node
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	for i in 4: await physics_frame
	print("STORE_VALID ", S.valid(scene.ctx), " saved=", S.read().ok, " menu=", scene.journey.visible)
	var okay: bool = S.valid(scene.ctx) and S.read().ok and scene.journey.visible
	scene.queue_free()
	await process_frame
	print("SUITE_COMPLETE: ", "PASS" if okay else "FAIL")
	quit(0 if okay else 1)
