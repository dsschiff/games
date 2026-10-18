extends Node3D
## Articulated skin poses observe simulation movement and attacks; never schedule combat.
var model: Node3D
var rig: Skeleton3D
var bones := {}
var role := "citizen"
var gait := 0.0
var travel := 0.0
var shot_left := 0.0
var hit_left := 0.0
var work_left := 0.0
var death_time := -1.0
var aim := Vector3.FORWARD
var muzzle: Marker3D
var health: MeshInstance3D
var health_root: Node3D
var hp := 1.0
var max_hp := 1.0
var torso_yaw := 0.0
var mounted := false
static var cache := {}

static func asset(name: String) -> Node3D:
	if not cache.has(name):
		cache[name] = load("res://art/models/" + name + ".glb") as PackedScene
	return cache[name].instantiate()

static func material(color: String, metallic: float = 0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color).srgb_to_linear()
	result.roughness = .79
	result.metallic = metallic
	return result

static var materials := {}
static func finish_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(surface)
			if source is StandardMaterial3D:
				var key := source.get_instance_id()
				if not materials.has(key):
					var m := source.duplicate() as StandardMaterial3D
					m.albedo_color = source.albedo_color.srgb_to_linear()
					materials[key] = m
				node.set_surface_override_material(surface, materials[key])
	for child in node.get_children():
		finish_materials(child)

static func skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := skeleton(child)
		if found != null:
			return found
	return null

func configure(kind: String, phase: float = 0) -> void:
	role = kind
	gait = phase
	model = asset("actor_" + role)
	add_child(model)
	finish_materials(model)
	rig = skeleton(model)
	for i in rig.get_bone_count():
		bones[rig.get_bone_name(i)] = i
	var scale_factor := 1.0
	if role == "swarm":
		scale_factor = .70
	elif role in ["ram", "matriarch", "regent"]:
		scale_factor = 1.48
	elif role == "commander":
		scale_factor = 1.06
	model.scale = Vector3.ONE * scale_factor
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "WeaponTip"
	rig.add_child(attachment)
	muzzle = Marker3D.new()
	muzzle.name = "VisibleWeaponSocket"
	attachment.add_child(muzzle)
	health_root = Node3D.new()
	health_root.position.y = 1.90 * scale_factor
	add_child(health_root)
	var background := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.63, .065, .025)
	background.mesh = mesh
	background.material_override = material("343840")
	health_root.add_child(background)
	health = MeshInstance3D.new()
	var fill := BoxMesh.new()
	fill.size = Vector3(.58, .04, .028)
	health.mesh = fill
	health.material_override = material("edc778")
	health.position = Vector3(0, .0, .02)
	health_root.add_child(health)
	health_root.hide()
	pose(0, Vector3.ZERO, "ready")

func bone(joint: String, angles: Vector3) -> void:
	rig.set_bone_pose_rotation(bones[joint], Quaternion.from_euler(angles))

func update_health(value: float, maximum: float, hydrate: bool) -> void:
	if not hydrate and value < hp:
		hit_left = .24
	hp = value
	max_hp = maximum
	health.scale.x = clampf(hp / maxf(max_hp, 1), .01, 1)
	health.position.x = -.29 * (1 - health.scale.x)
	health_root.visible = hp > 0 and hp < max_hp

func fire(target: Vector3) -> void:
	aim = (target - global_position) * Vector3(1, 0, 1)
	shot_left = .36
	# Apply the attack pose before a same-call muzzle request.
	pose(0, Vector3.ZERO, "playing")

func socket_position() -> Vector3:
	rig.force_update_all_bone_transforms()
	var attachment := muzzle.get_parent() as BoneAttachment3D
	attachment.transform = rig.get_bone_global_pose(bones.WeaponTip)
	attachment.force_update_transform()
	return muzzle.global_position

func reset_transients() -> void:
	shot_left = 0
	hit_left = 0
	work_left = 0
	travel = 0
	torso_yaw = 0
	aim = Vector3.FORWARD
	death_time = -1
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	pose(0, Vector3.ZERO, "ready")

func fall() -> void:
	death_time = 0
	health_root.hide()

func pose(dt: float, velocity: Vector3, phase: String) -> void:
	rig.set_bone_pose_scale(bones.Weapon, Vector3.ONE * .001 if mounted else Vector3.ONE)
	var speed := velocity.length()
	travel = move_toward(travel, minf(speed / 3.2, 1), dt * 7)
	var half_step := maxf(.20 * travel, .025)
	gait += speed * dt * PI / (2 * half_step)
	shot_left = maxf(0, shot_left - dt)
	hit_left = maxf(0, hit_left - dt)
	work_left = maxf(0, work_left - dt)
	var direction := velocity if speed > .08 else (aim if shot_left > 0 else Vector3.ZERO)
	if direction.length_squared() > .001:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1, dt * 14))
	if death_time >= 0:
		death_time += dt
		model.rotation.x = -smoothstep(0, .5, death_time) * 1.45
		model.position.y = .11 * minf(1, death_time / .5)
		bone("ThighL", Vector3(.5, 0, -.24))
		bone("ShinL", Vector3(-1, 0, 0))
		bone("UpperArmL", Vector3(-.6, 0, -.8))
		bone("UpperArmR", Vector3(.3, 0, .6))
		bone("Head", Vector3(.2, 0, .17))
		return
	leg("L", gait, half_step)
	leg("R", gait + PI, half_step)
	var kick := sin(PI * clampf(1 - shot_left / .36, 0, 1)) if shot_left > 0 else 0.0
	var hurt := sin(PI * hit_left / .24)
	var work := sin(PI * work_left / .6) if work_left > 0 else 0.0
	var target_yaw := wrapf(atan2(-aim.x, -aim.z) - rotation.y, -PI, PI) if shot_left > 0 else 0.0
	torso_yaw = lerp_angle(torso_yaw, target_yaw, 1.0 if dt == 0 and shot_left > 0 else minf(1, dt * 18))
	model.position.y = -.035 * travel
	bone("Torso", Vector3(-.055 * travel + hurt * .16, torso_yaw, .025 * sin(gait) * travel))
	bone("Head", Vector3(-kick * .06 + hurt * .10, -.15 * torso_yaw, .015 * sin(gait * .4)))
	bone("Cape", Vector3(.12 * travel, 0, sin(gait) * travel * .06))
	var sword := role not in ["defender", "commander", "mender", "matriarch", "citizen"]
	bone("UpperArmL", Vector3(-sin(gait) * travel * .28 + kick * .12, 0, -.08))
	bone("UpperArmR", Vector3(sin(gait) * travel * .25 - kick * (.85 if sword else .20) - work * .8, 0, .08))
	bone("ForearmL", Vector3(-.08 - kick * .12, 0, 0))
	bone("ForearmR", Vector3(-kick * (.40 if sword else .15) - work * .4, 0, 0))
	bone("Weapon", Vector3(kick * .18, 0, .04 * sin(gait) * travel))
	if role in ["mender", "matriarch"] and shot_left > 0:
		bone("UpperArmR", Vector3(-kick * .65, 0, .2))
	if phase == "victory" and role in ["commander", "citizen", "defender"]:
		bone("UpperArmL", Vector3(-.25, 0, -2.35))
		bone("ForearmL", Vector3(-.55, 0, 0))
		bone("Head", Vector3(0, .08, -.12))

func leg(side: String, cycle: float, half_step: float) -> void:
	var phase := fposmod(cycle, TAU)
	var forward: float
	var lift := 0.0
	if phase < PI:
		forward = lerpf(half_step, -half_step, phase / PI)
	else:
		var swing := (phase - PI) / PI
		forward = lerpf(-half_step, half_step, swing)
		lift = sin(swing * PI) * .15 * travel
	forward *= minf(travel * 8, 1)
	var down := .52 - .035 * travel - lift
	var distance := clampf(Vector2(forward, down).length(), .15, .5199)
	var knee := -acos(clampf((distance * distance - .28 * .28 - .24 * .24) / (2 * .28 * .24), -1, 1))
	var hip := atan2(forward, down) + acos(clampf((.28 * .28 + distance * distance - .24 * .24) / (2 * .28 * distance), -1, 1))
	bone("Thigh" + side, Vector3(hip, 0, 0))
	bone("Shin" + side, Vector3(knee, 0, 0))
	bone("Foot" + side, Vector3(-hip - knee, 0, 0))
