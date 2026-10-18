extends Node3D
## Presentation only. Root follows snapshots; this rig never drives rules.
const MODEL := "res://art/models/soldier.glb"
const VEHICLE := "res://art/models/rover.glb"
var rig: Skeleton3D
var model: Node3D
var bones := {}
var role := "rifle"
var team := "ally"
var gait := 0.0
var travel := 0.0
var fire_left := 0.0
var hit_left := 0.0
var death_time := -1.0
var armed := true
var action := "idle"
var aim := Vector3.FORWARD
var equipment_progress := 1.0
var status: Label3D
var vehicle := false
var wheels: Array[Node3D] = []
var muzzle: Marker3D
var health_root: Node3D
var health_fill: MeshInstance3D
var health_fraction := 1.0
var torso_yaw := 0.0
var turret: Node3D
var barrel: Node3D
var barrel_rest := Vector3.ZERO
var role_kit: Node3D
static var palette_materials := {}

func configure(unit_role: String, faction: String, phase: float) -> void:
	role = unit_role
	team = faction
	gait = phase
	vehicle = role in ["rover", "vehicle", "drill", "carrier", "storm"]
	model = (load(VEHICLE if vehicle else MODEL) as PackedScene).instantiate()
	add_child(model)
	rig = find_skeleton(model)
	if rig != null:
		for i in rig.get_bone_count():
			bones[rig.get_bone_name(i)] = i
	var uniform := Color("edc546") if team == "commander" else (Color("d75f54") if team == "enemy" else Color("83ac67"))
	var vest := Color("bc952d") if team == "commander" else (Color("a14c3c") if team == "enemy" else Color("648549"))
	paint(model, uniform, vest)
	if vehicle:
		collect_wheels(model)
		turret = model.find_child("TurretPivot", true, false)
		barrel = model.find_child("Cannon", true, false)
		if barrel != null:
			barrel_rest = barrel.position
		if team == "enemy":
			model.scale = Vector3(1.25, 1.1, 1.5) if role == "drill" else Vector3(1.45, 1.4, 1.7)
		if role == "drill":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.03
			cone.bottom_radius = 0.32
			cone.height = 0.7
			var drill := MeshInstance3D.new()
			drill.mesh = cone
			drill.rotation.x = -PI / 2
			drill.position = Vector3(0, 0.5, -1.25)
			drill.material_override = material(Color("bec6b9"))
			model.add_child(drill)
	if role in ["bulwark", "mortar", "jammer", "sapper", "breaker", "ranger", "storm", "carrier"]:
		var kit := (load("res://art/models/kit_" + role + ".glb") as PackedScene).instantiate()
		finish_materials(kit, {}, "kit")
		role_kit = kit
		if rig != null:
			var joint := "Weapon" if role == "ranger" else ("ForearmL" if role in ["bulwark", "breaker"] else "Torso")
			var attachment := BoneAttachment3D.new()
			attachment.bone_name = joint
			rig.add_child(attachment)
			attachment.add_child(kit)
			kit.transform = rig.get_bone_global_rest(bones[joint]).affine_inverse()
		else:
			model.add_child(kit)
	muzzle = Marker3D.new()
	muzzle.name = "MuzzleSocket"
	if rig != null:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = "Weapon"
		rig.add_child(attachment)
		attachment.add_child(muzzle)
		# Rest bones point up: local +Y is up and local -Z is forward.
		muzzle.position = Vector3(0, 0.01, -0.69)
	elif barrel is MeshInstance3D:
		barrel.add_child(muzzle)
		# The authored cannon's local -Y cap points forward. Inherit its turret
		# rotation, model scale and recoil instead of emitting from hull-forward.
		var bounds := (barrel as MeshInstance3D).mesh.get_aabb()
		muzzle.position = Vector3(bounds.get_center().x, bounds.position.y - .015, bounds.get_center().z)
	else:
		add_child(muzzle)
		muzzle.position = Vector3(0, 0.86, -1)
	status = Label3D.new()
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.position = Vector3(0, 1.65 if not vehicle else 1.8, 0)
	status.pixel_size = 0.008
	status.font_size = 26
	status.outline_size = 4
	add_child(status)
	make_health_bar()
	pose(0, Vector3.ZERO, false)

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null

func paint(node: Node, uniform: Color, vest: Color) -> void:
	finish_materials(node, {"Uniform": uniform, "Vest": vest}, team)

static func finish_materials(node: Node, palette: Dictionary = {}, faction: String = "prop") -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var key := faction + ":" + str(source.get_instance_id())
				if not palette_materials.has(key):
					var m := source.duplicate() as StandardMaterial3D
					# Compatibility's imported color path needs the same explicit linear
					# swatch conversion as our runtime materials; verified in play captures.
					m.albedo_color = (palette.get(source.resource_name, source.albedo_color) as Color).srgb_to_linear()
					palette_materials[key] = m
				node.set_surface_override_material(i, palette_materials[key])
	for child in node.get_children():
		finish_materials(child, palette, faction)

func collect_wheels(node: Node) -> void:
	if node is Node3D and node.name.begins_with("Wheel"):
		wheels.append(node)
	for child in node.get_children():
		collect_wheels(child)

static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.srgb_to_linear()
	m.roughness = 0.8
	return m

func make_health_bar() -> void:
	health_root = Node3D.new()
	health_root.position.y = 1.50 if not vehicle else 1.62
	add_child(health_root)
	for foreground in [false, true]:
		var n := MeshInstance3D.new()
		var shape := QuadMesh.new()
		shape.size = Vector2(0.60 if foreground else 0.66, 0.055 if foreground else 0.095)
		n.mesh = shape
		var m := material(Color("ef6150") if team == "enemy" else Color("98d060")) if foreground else material(Color("293d38"))
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		n.material_override = m
		n.position.z = 0.005 if foreground else 0
		health_root.add_child(n)
		if foreground:
			health_fill = n

func set_snapshot(data: Dictionary, hydrate: bool = false) -> void:
	action = data.phase
	equipment_progress = data.get("equip", 1.0)
	armed = action != "waiting" and (action != "equipping" or equipment_progress >= 0.85)
	if role_kit != null and role in ["breaker", "ranger"]:
		role_kit.visible = armed
	if barrel != null:
		barrel.visible = armed
	health_fraction = clampf(data.hp / maxf(data.max_hp, 1), 0, 1)
	health_fill.scale.x = health_fraction
	health_root.visible = health_fraction < 0.995 and health_fraction > 0
	status.text = "• • •" if action == "equipping" else ("+" if action == "waiting" else "")
	status.modulate = Color("ffdf78") if action == "equipping" else Color("dae8c4")
	if action == "fallen":
		if hydrate:
			death_time = 1.0
		elif death_time < 0:
			death_time = 0.0
	if hydrate:
		fire_left = 0
		hit_left = 0
		travel = 0
		pose(0, Vector3.ZERO, false)

func fire(target: Vector3) -> void:
	aim = (target - position) * Vector3(1, 0, 1)
	fire_left = 0.19 if not vehicle else 0.30
	torso_yaw = wrapf(atan2(-aim.x, -aim.z) - rotation.y, -PI, PI)
	if turret != null:
		turret.rotation.y = torso_yaw

func hit() -> void:
	hit_left = 0.22

func reset_transients() -> void:
	fire_left = 0
	hit_left = 0
	travel = 0

func bone(name: String, angles: Vector3) -> void:
	if rig != null and bones.has(name):
		rig.set_bone_pose_rotation(bones[name], Quaternion.from_euler(angles))

func pose(dt: float, velocity: Vector3, victory: bool) -> void:
	var speed := velocity.length()
	travel = move_toward(travel, minf(speed / 2.8, 1.2), dt * 8)
	var step_half := maxf(.18 * travel, .025)
	gait += speed * dt * PI / (2 * step_half)
	fire_left = maxf(0, fire_left - dt)
	hit_left = maxf(0, hit_left - dt)
	var direction := velocity if speed > .15 else (aim if fire_left > 0 else Vector3.ZERO)
	if direction.length_squared() > 0.001 and death_time < 0:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1, dt * 16))
	if death_time >= 0:
		death_time += dt
		model.rotation.x = -minf(death_time / 0.55, 1) * 1.40
		model.position.y = minf(death_time / 0.55, 1) * 0.13
		bone("ThighL", Vector3(0.65, 0, -0.22))
		bone("ThighR", Vector3(-0.2, 0, 0.3))
		bone("ShinL", Vector3(-1, 0, 0))
		bone("UpperArmL", Vector3(-0.7, 0, -0.6))
		bone("UpperArmR", Vector3(0.4, 0, 0.7))
		status.hide()
		health_root.hide()
		return
	var stride := sin(gait) * 0.63 * travel
	var kick := sin(PI * clampf(fire_left / 0.19, 0, 1))
	var flinch := sin(PI * hit_left / 0.22)
	if vehicle:
		for wheel in wheels:
			wheel.rotate_x(speed * dt / 0.25)
		if turret != null:
			var angle := wrapf(atan2(-aim.x, -aim.z) - rotation.y, -PI, PI)
			turret.rotation.y = lerp_angle(turret.rotation.y, angle, minf(1, dt * 18))
		if barrel != null:
			barrel.position = barrel_rest + Vector3(0, 0, kick * .14)
		model.rotation.z = flinch * 0.04
		return
	# Analytic two-link gait: stance travels backward at root speed, keeping the
	# planted boot near its world contact; swing clears ground and returns forward.
	model.position.y = -.05 * travel
	leg("L", gait, step_half)
	leg("R", gait + PI, step_half)
	var equip_lift := sin(equipment_progress * PI) * 0.6 if action == "equipping" else 0.0
	var target_yaw := wrapf(atan2(-aim.x, -aim.z) - rotation.y, -PI, PI) if fire_left > 0 else 0.0
	torso_yaw = lerp_angle(torso_yaw, target_yaw, minf(1, dt * 18))
	bone("Torso", Vector3(-0.04 * travel + kick * 0.09 + flinch * 0.18, torso_yaw, stride * 0.025))
	bone("Head", Vector3(-kick * 0.08, 0, sin(gait * 0.3) * 0.025))
	bone("UpperArmL", Vector3(-stride * 0.08 - equip_lift + kick * 0.08, 0, 0))
	bone("UpperArmR", Vector3(stride * 0.08 + kick * 0.12, 0, 0))
	bone("ForearmL", Vector3(-equip_lift + kick * 0.05, 0, 0))
	bone("ForearmR", Vector3(kick * 0.08, 0, 0))
	bone("Weapon", Vector3(kick * 0.12, 0, 0))
	if victory:
		bone("UpperArmL", Vector3(0, 0, -2.5))
		bone("ForearmL", Vector3(-0.65, 0, 0))
		bone("Head", Vector3(0, 0, -0.10))
	if rig != null and bones.has("Weapon"):
		var index: int = bones.Weapon
		rig.set_bone_pose_scale(index, Vector3.ONE if armed else Vector3.ONE * 0.001)

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
	var down := .51 - .05 * travel - lift
	var distance := clampf(Vector2(forward, down).length(), .15, .5099)
	var knee := -acos(clampf((distance * distance - .28 * .28 - .23 * .23) / (2 * .28 * .23), -1, 1))
	var hip := atan2(forward, down) + acos(clampf((.28 * .28 + distance * distance - .23 * .23) / (2 * .28 * distance), -1, 1))
	bone("Thigh" + side, Vector3(hip, 0, 0))
	bone("Shin" + side, Vector3(knee, 0, 0))
	bone("Foot" + side, Vector3(-hip - knee, 0, 0))
