extends Node3D
## Original rigid-weight sculpted meshes; articulated pose is purely cosmetic.
var role := "guard"
var friendly := true
var model: Node3D
var rig: Skeleton3D
var bones: Dictionary = {}
var muzzle: Marker3D
var health: Node3D
var health_fill: MeshInstance3D
var gait := 0.0
var travel := 0.0
var fire_left := 0.0
var hit_left := 0.0
var death_time := -1.0
var aim := Vector3.FORWARD
var humanoid := true
var torso_yaw := 0.0
var rest_nodes: Array[Dictionary] = []
static var materials: Dictionary = {}
static var authored_sockets: Dictionary = {}

func configure(kind: String, ally: bool, offset: float) -> void:
	role = kind
	friendly = ally
	gait = offset
	humanoid = role in ["guard", "ranger", "mortar"]
	model = (load("res://art/models/" + role + ".glb") as PackedScene).instantiate()
	add_child(model)
	finish_materials(model)
	rig = find_skeleton(model)
	assert(rig != null, "Every actor must retain its authored skeletal rig")
	for i in rig.get_bone_count():
		bones[rig.get_bone_name(i)] = i
	var socket := BoneAttachment3D.new()
	socket.bone_name = "Weapon"
	rig.add_child(socket)
	muzzle = Marker3D.new()
	muzzle.name = "ContactSocket"
	socket.add_child(muzzle)
	if authored_sockets.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/manifest.json"))
		for entry in manifest.assets:
			if entry.contact_socket_godot != null:
				var point: Array = entry.contact_socket_godot
				authored_sockets[str(entry.file).get_file().get_basename()] = Vector3(point[0],point[1],point[2])
	var rest_tip: Vector3 = authored_sockets[role]
	# Authored points are model-space; the bone attachment inherits aim/recoil.
	muzzle.position = rig.get_bone_global_rest(bones.Weapon).affine_inverse() * rest_tip
	rotation.y = 0 if ally else PI
	aim = Vector3.FORWARD if ally else Vector3.BACK
	health = Node3D.new()
	health.position.y = 1.70 if humanoid else (1.4 if role in ["captain", "siege", "matriarch"] else .95)
	add_child(health)
	for foreground in [false, true]:
		var n := MeshInstance3D.new()
		var shape := QuadMesh.new()
		shape.size = Vector2(.62 if foreground else .68, .055 if foreground else .09)
		n.mesh = shape
		var mat := material(Color("83d5b1") if friendly else Color("ed8b69")) if foreground else material(Color("27383c"))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		n.material_override = mat
		n.position.z = .006 if foreground else 0
		health.add_child(n)
		if foreground:
			health_fill = n
	health.hide()
	collect_rest_nodes(model)
	collect_rest_nodes(health)
	reset_for_reuse(offset)

func collect_rest_nodes(node: Node3D) -> void:
	rest_nodes.append({"node":node,"transform":node.transform,"visible":node.visible})
	for child in node.get_children():
		if child is Node3D:
			collect_rest_nodes(child)

static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.srgb_to_linear()
	mat.roughness = .75
	return mat

static func finish_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var key := str(source.get_instance_id())
				if not materials.has(key):
					var mat := source.duplicate() as StandardMaterial3D
					mat.albedo_color = source.albedo_color.srgb_to_linear()
					materials[key] = mat
				node.set_surface_override_material(i, materials[key])
	for child in node.get_children():
		finish_materials(child)

func set_health(hp: float, max_hp: float) -> void:
	var fraction := clampf(hp / maxf(1, max_hp), 0, 1)
	health_fill.scale.x = fraction
	health.visible = fraction > 0 and fraction < .995

func fire(destination: Vector3) -> void:
	aim = (destination - global_position) * Vector3(1, 0, 1)
	fire_left = .26 if humanoid else .32
	torso_yaw = wrapf(atan2(-aim.x, -aim.z) - rotation.y, -PI, PI)
	pose(0,Vector3.ZERO,false)
	rig.force_update_all_bone_transforms()
	# BoneAttachment receives the skeleton's deferred notification later in the
	# frame. Synchronize its current pose before an immediate authoritative shot.
	(muzzle.get_parent() as Node3D).transform = rig.get_bone_global_pose(bones.Weapon)

func hit() -> void:
	hit_left = .20

func reset_transients() -> void:
	reset_for_reuse(0)

func reset_for_reuse(offset: float) -> void:
	transform = Transform3D.IDENTITY
	rotation.y = 0 if friendly else PI
	aim = Vector3.FORWARD if friendly else Vector3.BACK
	gait = offset
	fire_left = 0
	hit_left = 0
	travel = 0
	death_time = -1
	torso_yaw = 0
	for entry in rest_nodes:
		entry.node.transform = entry.transform
		entry.node.visible = entry.visible
	for i in rig.get_bone_count():
		rig.reset_bone_pose(i)
	pose(0, Vector3.ZERO, false)
	rig.force_update_all_bone_transforms()
	(muzzle.get_parent() as Node3D).transform = rig.get_bone_global_pose(bones.Weapon)
	health.hide()
	process_mode = Node.PROCESS_MODE_INHERIT
	show()

func bone(name: String, angles: Vector3) -> void:
	if bones.has(name):
		rig.set_bone_pose_rotation(bones[name], Quaternion.from_euler(angles))

func pose(dt: float, velocity: Vector3, victory: bool) -> void:
	var speed := velocity.length()
	travel = move_toward(travel, minf(speed / 1.0, 1), dt * 8)
	var half_step := maxf(.18 * travel, .025)
	gait += speed * dt * PI / (2 * half_step)
	fire_left = maxf(0, fire_left - dt)
	hit_left = maxf(0, hit_left - dt)
	# Authoritative contact is immediate; strike/recoil starts at contact and recovers.
	var kick := sin(PI/2 * clampf(fire_left / (.26 if humanoid else .32), 0, 1))
	var flinch := sin(PI * hit_left / .20)
	if death_time >= 0:
		death_time += dt
		var fall := minf(1, death_time / .60)
		model.rotation.z = fall * (1.45 if humanoid else .75)
		model.position.y = fall * (.10 if humanoid else -.08)
		bone("Head", Vector3(-.25 * fall, 0, 0))
		if humanoid:
			bone("UpperArmL", Vector3(-.9 * fall, 0, -.7 * fall))
			bone("UpperArmR", Vector3(.4 * fall, 0, .8 * fall))
			bone("ShinL", Vector3(-.9 * fall, 0, 0))
		else:
			for side in ["L", "R"]:
				for i in 3:
					bone("Leg" + side + str(i), Vector3(.3 * fall, 0, (-.7 if side == "L" else .7) * fall))
		health.hide()
		return
	var facing := velocity if speed > .08 else (aim if fire_left > 0 else Vector3.ZERO)
	if facing.length_squared() > .001:
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(1, dt * 14))
	var yaw := wrapf(atan2(-aim.x, -aim.z) - rotation.y, -PI, PI) if fire_left > 0 else 0.0
	torso_yaw = lerp_angle(torso_yaw, yaw, minf(1, dt * 18))
	bone("Torso", Vector3(kick * .12 + flinch * .17, torso_yaw, flinch * .07))
	bone("Head", Vector3(-kick * .12, 0, sin(gait * .15) * .02))
	if humanoid:
		leg("L", gait, half_step)
		leg("R", gait + PI, half_step)
		var stride := sin(gait) * travel
		bone("UpperArmL", Vector3(-stride * .18 + kick * .09, 0, 0))
		bone("ForearmL", Vector3(-kick * .10, 0, 0))
		bone("UpperArmR", Vector3(stride * .15 - kick * (.90 if role == "guard" else .12), 0, 0))
		bone("ForearmR", Vector3(kick * (.65 if role == "guard" else .12), 0, 0))
		bone("Weapon", Vector3(-kick * (.45 if role == "guard" else -.12), 0, 0))
		if victory:
			bone("UpperArmL", Vector3(0, 0, -2.4))
			bone("ForearmL", Vector3(-.5, 0, 0))
	else:
		for side in ["L", "R"]:
			for i in 3:
				var sign_side := -1.0 if side == "L" else 1.0
				var cycle: float = gait + (0 if (i + (0 if side == "L" else 1)) % 2 == 0 else PI)
				var sweep := sin(cycle) * .40 * travel
				var lift := maxf(0, cos(cycle)) * .38 * travel
				bone("Leg" + side + str(i), Vector3(lift, sweep, sign_side * lift * .35))
				bone("Tip" + side + str(i), Vector3(-lift * .7, -sweep * .3, sign_side * lift * .3))
		bone("Weapon", Vector3(-kick * .25, 0, kick * .12))
		for side in ["L", "R"]:
			bone("Wing" + side, Vector3(0, 0, sin(gait * 2) * .25))

func leg(side: String, cycle: float, half_step: float) -> void:
	var phase := fposmod(cycle, TAU)
	var forward := lerpf(half_step, -half_step, phase / PI) if phase < PI else lerpf(-half_step, half_step, (phase - PI) / PI)
	var lift := sin((phase - PI) / PI * PI) * .13 * travel if phase >= PI else 0.0
	forward *= minf(travel * 8, 1)
	var down := .51 - lift
	var distance := clampf(Vector2(forward, down).length(), .15, .5099)
	var knee := -acos(clampf((distance * distance - .28*.28 - .23*.23) / (2*.28*.23), -1, 1))
	var hip := atan2(forward, down) + acos(clampf((.28*.28 + distance*distance - .23*.23) / (2*.28*distance), -1, 1))
	bone("Thigh" + side, Vector3(hip, 0, 0))
	bone("Shin" + side, Vector3(knee, 0, 0))
	bone("Foot" + side, Vector3(-hip-knee, 0, 0))
