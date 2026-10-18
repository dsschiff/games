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
var drill_rotor: Node3D
var repair_boom: Node3D
var repair_socket: Marker3D
var charge_dish: Node3D
var repair_left := 0.0
var repair_aim := Vector3.FORWARD
var warning_left := 0.0
var jammed := false
var fire_duration := .19
var palette_materials := {}
var model_cache := {}
var rest_nodes: Array[Dictionary] = []

static func instantiate_model(path: String, cache: Variant = null) -> Node3D:
	if cache == null:
		return (load(path) as PackedScene).instantiate()
	if not cache.has(path):
		cache[path] = load(path) as PackedScene
	return cache[path].instantiate()

func configure(unit_role: String, faction: String, phase: float, models: Variant = null, palettes: Variant = null) -> void:
	model_cache = {} if models == null else models
	palette_materials = {} if palettes == null else palettes
	role = unit_role
	team = faction
	gait = phase
	vehicle = role in ["rover", "vehicle", "drill", "carrier", "storm"]
	var path := VEHICLE if vehicle else MODEL
	if role in ["drill", "carrier", "storm"]:
		path = "res://art/models/vehicle_" + role + ".glb"
	elif role in ["runner", "breaker", "ranger", "bulwark", "mortar", "jammer", "sapper"]:
		path = "res://art/models/soldier_" + role + ".glb"
	model = instantiate_model(path, model_cache)
	fire_duration = .30 if vehicle else (.32 if role == "mortar" else (.25 if role == "breaker" else .19))
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
		drill_rotor = model.find_child("DrillRotor", true, false)
		repair_boom = model.find_child("RepairBoom", true, false)
		charge_dish = model.find_child("ChargeDish", true, false)
		if repair_boom != null:
			repair_socket = Marker3D.new()
			repair_boom.add_child(repair_socket)
			repair_socket.position = Vector3(0, 0, -1.33)
	if role in ["bulwark", "mortar", "jammer", "sapper", "breaker", "ranger"]:
		var kit := instantiate_model("res://art/models/kit_" + role + ".glb", model_cache)
		finish_materials(kit, {}, "kit", palette_materials)
		role_kit = kit
		if rig != null:
			var joint := "ForearmL" if role == "bulwark" else "Torso"
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
		attachment.bone_name = "PrimaryMuzzle" if bones.has("PrimaryMuzzle") else "Weapon"
		rig.add_child(attachment)
		attachment.add_child(muzzle)
		# Rest bones point up: local +Y is up and local -Z is forward.
		muzzle.position = Vector3.ZERO if bones.has("PrimaryMuzzle") else Vector3(0, .01, -.69)
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
	status.position = Vector3(0, 1.65 if not vehicle else (2.0 if role in ["carrier", "storm"] else 1.8), 0)
	status.pixel_size = 0.008
	status.font_size = 26
	status.outline_size = 4
	add_child(status)
	make_health_bar()
	for child in get_children():
		if child is Node3D:
			collect_rest_nodes(child)
	reset_for_reuse(phase)

func collect_rest_nodes(node: Node3D) -> void:
	var entry := {"node": node, "transform": node.transform, "visible": node.visible}
	if node is GeometryInstance3D:
		entry["material_override"] = node.material_override
		entry["material_overlay"] = node.material_overlay
		entry["transparency"] = node.transparency
		entry["layers"] = node.layers
	if node is MeshInstance3D:
		entry["surfaces"] = []
		for surface in node.mesh.get_surface_count():
			entry.surfaces.append(node.get_surface_override_material(surface))
	if node is Label3D:
		entry["modulate"] = node.modulate
		entry["font_size"] = node.font_size
		entry["pixel_size"] = node.pixel_size
		entry["outline_size"] = node.outline_size
	for child in node.get_children():
		if child is Node3D:
			collect_rest_nodes(child)
	rest_nodes.append(entry)

func reset_for_reuse(phase: float) -> void:
	transform = Transform3D.IDENTITY
	gait = phase
	travel = 0
	fire_left = 0
	hit_left = 0
	death_time = -1
	armed = true
	action = "idle"
	aim = Vector3.FORWARD
	equipment_progress = 1
	health_fraction = 1
	torso_yaw = 0
	repair_left = 0
	repair_aim = Vector3.FORWARD
	warning_left = 0
	jammed = false
	for entry in rest_nodes:
		var node: Node3D = entry.node
		node.transform = entry.transform
		node.visible = entry.visible
		if node is GeometryInstance3D:
			node.material_override = entry.material_override
			node.material_overlay = entry.material_overlay
			node.transparency = entry.transparency
			node.layers = entry.layers
		if node is MeshInstance3D:
			for surface in entry.surfaces.size():
				node.set_surface_override_material(surface, entry.surfaces[surface])
		if node is Label3D:
			node.modulate = entry.modulate
			node.font_size = entry.font_size
			node.pixel_size = entry.pixel_size
			node.outline_size = entry.outline_size
	if rig != null:
		for index in rig.get_bone_count():
			rig.reset_bone_pose(index)
	pose(0, Vector3.ZERO, false)
	if rig != null:
		rig.force_update_all_bone_transforms()
		for entry in rest_nodes:
			if entry.node is BoneAttachment3D:
				var attachment: BoneAttachment3D = entry.node
				attachment.transform = rig.get_bone_global_pose(bones[attachment.bone_name])
				attachment.force_update_transform()
	status.text = ""
	health_root.hide()
	process_mode = Node.PROCESS_MODE_INHERIT
	show()

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null

func paint(node: Node, uniform: Color, vest: Color) -> void:
	finish_materials(node, {"Uniform": uniform, "Vest": vest}, team, palette_materials)

static func finish_materials(node: Node, palette: Dictionary = {}, faction: String = "prop", shared: Variant = null) -> void:
	var cache: Dictionary = {} if shared == null else shared
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var swatch: Color = palette.get(source.resource_name, source.albedo_color)
				var key := str(source.get_instance_id()) + ":" + swatch.to_html()
				if not cache.has(key):
					var m := source.duplicate() as StandardMaterial3D
					# Compatibility's imported color path needs the same explicit linear
					# swatch conversion as our runtime materials; verified in play captures.
					m.albedo_color = swatch.srgb_to_linear()
					cache[key] = m
				node.set_surface_override_material(i, cache[key])
	for child in node.get_children():
		finish_materials(child, palette, faction, cache)

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
	warning_left = data.get("warning", 0.0)
	jammed = data.get("jammed", false)
	equipment_progress = data.get("equip", 1.0)
	armed = action != "waiting" and (action != "equipping" or equipment_progress >= 0.85)
	if role_kit != null and role in ["breaker", "ranger"]:
		role_kit.visible = armed
	if barrel != null:
		barrel.visible = armed
	health_fraction = clampf(data.hp / maxf(data.max_hp, 1), 0, 1)
	health_fill.scale.x = health_fraction
	health_root.visible = health_fraction < 0.995 and health_fraction > 0
	status.text = "• • •" if action == "equipping" else ("!" if action == "waiting" and data.get("request", false) else ("×" if jammed else ""))
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
	fire_left = fire_duration
	torso_yaw = wrapf(atan2(-aim.x, -aim.z) - rotation.y, -PI, PI)
	if turret != null:
		turret.rotation.y = torso_yaw

func socket_position() -> Vector3:
	if rig != null:
		rig.force_update_all_bone_transforms()
		var attachment := muzzle.get_parent() as BoneAttachment3D
		# BoneAttachment's skeleton signal updates later on this engine. The skin
		# already uses this pose, so hydrate the attachment before same-call sampling.
		attachment.transform = rig.get_bone_global_pose(bones[attachment.bone_name])
		attachment.force_update_transform()
	return muzzle.global_position

func hit() -> void:
	hit_left = 0.22

func repair(target: Vector3) -> void:
	repair_left = .6
	repair_aim = (target - position) * Vector3(1, 0, 1)

func reset_transients() -> void:
	fire_left = 0
	hit_left = 0
	repair_left = 0
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
	repair_left = maxf(0, repair_left - dt)
	var direction := velocity if speed > .15 else (aim if fire_left > 0 else Vector3.ZERO)
	if direction.length_squared() > 0.001 and death_time < 0:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1, dt * 16))
	if death_time >= 0:
		death_time += dt
		model.rotation.x = -minf(death_time / .55, 1) * (.12 if vehicle else 1.40)
		model.position.y = minf(death_time / .55, 1) * (-.04 if vehicle else .13)
		if vehicle and turret != null:
			turret.rotation.x = minf(death_time / .55, 1) * .18
		bone("ThighL", Vector3(0.65, 0, -0.22))
		bone("ThighR", Vector3(-0.2, 0, 0.3))
		bone("ShinL", Vector3(-1, 0, 0))
		bone("UpperArmL", Vector3(-0.7, 0, -0.6))
		bone("UpperArmR", Vector3(0.4, 0, 0.7))
		status.hide()
		health_root.hide()
		return
	var stride := sin(gait) * 0.63 * travel
	var kick := sin(PI * clampf(fire_left / fire_duration, 0, 1))
	var flinch := sin(PI * hit_left / 0.22)
	if vehicle:
		for wheel in wheels:
			wheel.rotate_x(speed * dt / 0.25)
		if turret != null:
			var angle := wrapf(atan2(-aim.x, -aim.z) - rotation.y, -PI, PI)
			turret.rotation.y = lerp_angle(turret.rotation.y, angle, minf(1, dt * 18))
			turret.rotation.x = -.12 if victory else 0.0
		if barrel != null:
			barrel.position = barrel_rest + Vector3(0, 0, kick * .14)
		model.rotation.z = flinch * 0.04
		if drill_rotor != null:
			drill_rotor.rotate_z(dt * (speed * 5 + (8.0 if warning_left > 0 else .6)))
		if charge_dish != null:
			charge_dish.rotate_y(dt * (2.0 if warning_left > 0 else .25))
		if repair_boom != null:
			repair_boom.rotation.x = -.22 * sin(PI * repair_left / .6)
			var yaw := atan2(-repair_aim.x, -repair_aim.z) - rotation.y
			repair_boom.rotation.y = lerp_angle(repair_boom.rotation.y, yaw, minf(1, dt * 8))
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
	bone("Weapon", Vector3(kick * .12 + (.12 if role == "mortar" else 0), 0, 0))
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
