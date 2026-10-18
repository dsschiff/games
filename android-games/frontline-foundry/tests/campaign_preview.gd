extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1280)
	var app: Node = load("res://boot.tscn").instantiate()
	root.add_child(app)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			root.get_texture().get_image().save_png(arg.trim_prefix("--preview="))
	app.queue_free()
	await process_frame
	await process_frame
	quit()
