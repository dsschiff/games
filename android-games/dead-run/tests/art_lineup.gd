extends SceneTree
## Rendered art inspection: every kit actor in rest and articulated poses.
## Development evidence only; not gameplay.
const Kit = preload("res://scripts/presentation/kit.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
var folder := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(720, 1280)
	var world := Node3D.new()
	root.add_child(world)
	var kit := Kit.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("8fb6c4")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("dfe9f2")
	env.environment.ambient_light_energy = .40
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = .30
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	floor.mesh.size = Vector2(40, 40)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("6b7078")
	floor.material_override = fm
	world.add_child(floor)
	var cam := Camera3D.new()
	world.add_child(cam)
	var actors: Array = []
	var rows := [["actor_crew", "actor_crew", "actor_crew", "actor_crew"],
		["actor_drifter", "actor_runner", "actor_plated", "actor_spitter"],
		["actor_cluster", "actor_bulwark", "boss_ram", "boss_matron"]]
	for r in rows.size():
		for c in rows[r].size():
			var a := Actor.new()
			world.add_child(a)
			a.configure(rows[r][c], kit, 1.0)
			a.position = Vector3(-3.3 + c * 2.2, 0, -r * 2.6)
			a.rotation.y = PI * .25 if r > 0 else -PI * .25 * float(c)
			actors.append(a)
	# Pose: crew0 rest, crew1 running mid-stride, crew2 recoil, crew3 dying.
	for frame in 30:
		for i in actors.size():
			var a = actors[i]
			if i == 0: a.rig.reset_bone_poses()
			elif i == 1: a.gait = 1.2; a.pose_crew(0.0, 1.9, 0)
			elif i == 2: a.kick(); a.pose_crew(0.0, 0.0, 0)
			elif i == 3:
				if frame == 0: a.die()
				a.pose_crew(.03, 0, 0)
			else: a.gait = 1.0 + i; a.travel = 1.0; a.pose_infected(0.0, 1.5, a.key.trim_prefix("actor_"), 1.0)
		await process_frame
	for view in [["front", Vector3(0, 4.5, 7.5), Vector3(0, .8, -2.6)], ["side", Vector3(9, 3.5, -2.6), Vector3(0, .8, -2.6)]]:
		cam.position = view[1]
		cam.look_at(view[2])
		for i in 4: await process_frame
		var image := root.get_texture().get_image()
		image.save_png(folder.path_join("lineup-" + view[0] + ".png"))
	print("SUITE_COMPLETE: PASS")
	quit(0)
