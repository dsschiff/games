extends Node3D
const Kit = preload("res://scripts/presentation/kit.gd")
const Art = preload("res://scripts/art.gd")
var model: Node3D
var rig: Skeleton3D
var bones := {}
var role := ""
var socket: BoneAttachment3D
var socket_marker: Marker3D
var health: MeshInstance3D
var warning: Node3D
var health_root: Node3D
var gait := 0.0
var travel := 0.0
var hit_left := 0.0
var fall_time := -1.0
var target := Vector3.ZERO
var previous := Vector3.ZERO
var velocity := Vector3.ZERO
var facing := 0.0
var snapshot := {}
var spec := {}
var hp := 100.0
var model_rest := Transform3D.IDENTITY
var scale_factor := 1.0
var identity := ""
var warning_rests := {}

func configure(kind: String, kit: RefCounted) -> void:
	role = kind
	model = kit.asset("actor_" + role)
	add_child(model)
	rig = Kit.skeleton(model)
	for i in rig.get_bone_count():
		bones[rig.get_bone_name(i)] = i
	scale_factor = 1.48 if role in ["bellkeeper", "warden", "kiln", "crown"] else (1.25 if role in ["twin_sun", "twin_moon"] else (.78 if role == "skitter" else 1.0))
	model.scale = Vector3.ONE * scale_factor
	model_rest = model.transform
	socket = BoneAttachment3D.new()
	socket.bone_name = "ChainSocket"
	rig.add_child(socket)
	socket_marker = Marker3D.new()
	socket_marker.name = "CurrentChainHand"
	socket.add_child(socket_marker)
	health_root = Node3D.new()
	health_root.position.y = 2.03 * scale_factor
	add_child(health_root)
	health_root.add_child(Art.box(Vector3(.76, .08, .035), Color("243e4a")))
	health = Art.box(Vector3(.70, .045, .04), Color("efbd80"), Vector3(0, 0, .025))
	health_root.add_child(health)
	warning = Art.warning()
	# Telegraphs live in world space at locked ax/az, never under an animated rig.
	warning.top_level = true
	add_child(warning)
	for child in warning.get_children():
		warning_rests[child.name] = child.transform
	reset_for_reuse()

func reset_for_reuse() -> void:
	transform = Transform3D.IDENTITY
	model.transform = model_rest
	rig.reset_bone_poses()
	gait = 0
	travel = 0
	hit_left = 0
	fall_time = -1
	target = Vector3.ZERO
	previous = Vector3.ZERO
	velocity = Vector3.ZERO
	facing = 0
	snapshot = {}
	spec = {}
	hp = 100
	identity = ""
	health.transform = Transform3D.IDENTITY
	health.position.z = .025
	health_root.hide()
	health_root.transform = Transform3D.IDENTITY
	health_root.position.y = 2.03 * scale_factor
	warning.hide()
	warning.transform = Transform3D.IDENTITY
	for child in warning.get_children():
		child.transform = warning_rests[child.name]
	socket_marker.transform = Transform3D.IDENTITY
	sync_socket()

func capture(data: Dictionary, definition: Dictionary, hydrate: bool, dt: float) -> void:
	var next := Vector3(data.x, 0, data.z)
	velocity = (next - target) / dt if dt > 0 and not hydrate else Vector3.ZERO
	previous = target
	target = next
	if hydrate:
		position = target
	if not hydrate and float(data.hp) < hp:
		hit_left = .20
	hp = data.hp
	snapshot = data.duplicate(true)
	spec = definition.duplicate(true)
	facing = float(data.get("facing", facing))
	health.scale.x = clampf(hp / maxf(1, float(spec.get("hp", 100))), .001, 1)
	health.position.x = -.35 * (1 - health.scale.x)
	health_root.visible = hp > 0 and hp < float(spec.get("hp", 100)) and role != "diver"
	if hydrate:
		rotation.y = facing

func bone(key: String, euler: Vector3) -> void:
	rig.set_bone_pose_rotation(bones[key], Quaternion.from_euler(euler))

func sync_socket() -> Vector3:
	rig.force_update_all_bone_transforms()
	# BoneAttachment's deferred update is too late for same-call chain sampling.
	socket.transform = rig.get_bone_global_pose(bones.ChainSocket)
	socket.force_update_transform()
	return socket_marker.global_position

func fall() -> void:
	fall_time = 0
	health_root.hide()
	warning.hide()

func pose(dt: float, phase: String, strike: float = 0, aiming: Vector3 = Vector3.ZERO) -> void:
	if snapshot.is_empty():
		return
	position = position.lerp(target, 1 - exp(-dt * 36)) if dt > 0 else target
	var speed := velocity.length() if fall_time < 0 and phase == "playing" else 0.0
	travel = move_toward(travel, minf(1, speed / 4), dt * 9)
	gait += speed * dt * 7.6
	hit_left = maxf(0, hit_left - dt)
	var aim := aiming - position
	if role == "diver":
		if strike > 0:
			facing = atan2(-aim.x, -aim.z)
		elif speed > .05:
			facing = atan2(-velocity.x, -velocity.z)
	rotation.y = lerp_angle(rotation.y, facing, 1 - exp(-dt * 18)) if dt > 0 else facing
	rig.reset_bone_poses()
	model.transform = model_rest
	for side in ["L", "R"]:
		var step := sin(gait + (PI if side == "R" else 0))
		bone("Thigh" + side, Vector3(step * .52 * travel, 0, 0))
		bone("Shin" + side, Vector3(maxf(0, -step) * .70 * travel, 0, 0))
		bone("Foot" + side, Vector3(-maxf(0, step) * .17 * travel, 0, 0))
		bone("Arm" + side, Vector3(-step * .22 * travel, 0, -.08 if side == "L" else .08))
		bone("Forearm" + side, Vector3(-.12, 0, 0))
	bone("Torso", Vector3(-.06 * travel, 0, sin(gait) * .035 * travel))
	bone("Tail", Vector3(0, sin(gait) * .16 * travel, 0))
	if role == "diver" and strike > 0:
		var t := clampf((.36 - strike) / .36, 0, 1)
		var wind := sin(t * PI)
		bone("Torso", Vector3(.12 * wind, .55 * sin(t * TAU), -.12 * wind))
		bone("ArmR", Vector3(-.85 * wind, -.40 * sin(t * TAU), .25 * wind))
		bone("ForearmR", Vector3(-.55 * (1 - wind), 0, .15 * wind))
		bone("ArmL", Vector3(-.28 * wind, -.25 * wind, -.32 * wind))
	elif role != "diver":
		var mode: String = str(snapshot.get("mode", "idle"))
		var attack: String = str(snapshot.get("attack", "slam"))
		var wind := 0.0
		if mode == "wind":
			wind = clampf(1 - float(snapshot.clock) / maxf(.01, float(spec.get("wind", 1))), 0, 1)
			bone("Torso", Vector3(.25 * wind, 0, 0))
			bone("ArmR", Vector3(-1.65 * wind, 0, .20 * wind))
			bone("ArmL", Vector3(-1.3 * wind, 0, -.20 * wind))
			bone("Head", Vector3(-.18 * wind, 0, 0))
		elif mode == "recover":
			var recoil := clampf(float(snapshot.clock) / maxf(.01, float(spec.get("recovery", 1))), 0, 1)
			bone("Torso", Vector3(-.38 * recoil, .12 * recoil, 0))
			bone("ArmR", Vector3(.65 * recoil, 0, .10))
			bone("ArmL", Vector3(.42 * recoil, 0, -.10))
		elif mode == "charge":
			bone("Torso", Vector3(-.45, 0, 0))
			bone("Head", Vector3(.20, 0, 0))
		if attack in ["shot", "burst"] and mode == "wind":
			bone("Head", Vector3(.30 * wind, 0, 0))
	if hit_left > 0:
		bone("Torso", Vector3(.22 * hit_left / .20, 0, -.12 * hit_left / .20))
	if fall_time >= 0 or role == "diver" and phase == "defeat":
		fall_time = maxf(0, fall_time) + dt
		model.rotation.x = -smoothstep(0, .48, fall_time) * 1.48
		model.position.y = .09
		bone("ArmR", Vector3(-.45, 0, .65))
		bone("ArmL", Vector3(-.25, 0, -.65))
		bone("ShinR", Vector3(.50, 0, 0))
	elif role == "diver" and phase == "victory":
		bone("ArmL", Vector3(-2.3, 0, -.25))
		bone("ForearmL", Vector3(-.50, 0, 0))
		bone("Head", Vector3(-.14, sin(gait) * .10, 0))
	sync_socket()
