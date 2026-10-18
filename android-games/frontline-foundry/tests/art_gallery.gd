extends SceneTree
## Synthetic art inspection only. This is never gameplay or progression evidence.
const Actor = preload("res://scripts/presentation/actor.gd")
var folder := ""
var errors: Array = []
var actors: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1280)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cad2c4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0ead8")
	env.ambient_light_energy = .4
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = .7
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 15, 15)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	var roles := ["commander", "rifle", "runner", "breaker", "ranger", "bulwark", "mortar", "jammer", "sapper", "drill", "carrier", "storm"]
	for index in roles.size():
		var role: String = roles[index]
		var unit := Actor.new()
		world.add_child(unit)
		unit.configure("rifle" if role == "commander" else role, "commander" if role == "commander" else ("ally" if role in ["rifle", "breaker", "ranger"] else "enemy"), 0)
		unit.position = Vector3((index % 3 - 1) * 3.1, 0, (index / 3 - 1.5) * 4.0)
		actors.append(unit)
		var label := Label3D.new()
		world.add_child(label)
		label.text = role.to_upper()
		label.position = unit.position + Vector3(0, 0, 1.4)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = .01
		label.font_size = 26
		label.modulate = Color("253e32")
	var start := Time.get_ticks_msec()
	var elapsed := 0.0
	var captured := false
	while elapsed < 5.0 and Time.get_ticks_msec() - start < 30000:
		await process_frame
		var dt := root.get_process_delta_time()
		elapsed += dt
		for unit in actors:
			unit.pose(dt, Vector3.FORWARD * 1.0, false)
		if elapsed > 1.0 and not captured and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("art-gallery.png"))
			captured = true
	var file := FileAccess.open(folder.path_join("benchmark-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Synthetic art gallery only. Authored runtime rigs under synthetic motion; no real game, state, attacks, progression or acceptance claim", "errors": errors, "roles": roles}, "  "))
	quit(0)
