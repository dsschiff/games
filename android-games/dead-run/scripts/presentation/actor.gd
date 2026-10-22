extends Node3D
## One articulated, rigid-skinned character. Rules own its root position; this
## node only poses bones from rule-derived inputs (ground speed, fire ticks,
## hits, death). Nothing here moves rule state.
const Kit = preload("res://scripts/presentation/kit.gd")
var model: Node3D
var rig: Skeleton3D
var bones := {}
var rest := {}
var key := ""
var scale_factor := 1.0
var stride := .8
var gait := 0.0
var travel := 0.0
var speed := 0.0
var lean := 0.0
var kick_left := 0.0
var hit_left := 0.0
var fall_time := -1.0
var spawn_left := 0.0
var fade := 1.0
var windup := 0.0
var cheer := false
var phase_seed := 0.0
var smooth := Vector3.ZERO
var shadow: MeshInstance3D

func configure(asset: String, kit: RefCounted, size: float, blob: Mesh = null, blob_material: Material = null) -> void:
	key = asset
	scale_factor = size
	model = kit.asset(asset)
	add_child(model)
	model.scale = Vector3.ONE * size
	rig = Kit.skeleton(model)
	for i in rig.get_bone_count():
		bones[rig.get_bone_name(i)] = i
		rest[i] = rig.get_bone_rest(i).basis.get_rotation_quaternion()
	# Hip height sets the distance covered per gait cycle so planted feet
	# travel with the scrolling road instead of skating.
	var hip := .56 * size
	stride = 4.0 * hip * sin(.55)
	if blob != null:
		shadow = MeshInstance3D.new()
		shadow.mesh = blob
		shadow.material_override = blob_material
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadow.position.y = .02
		shadow.scale = Vector3.ONE * size * 1.4
		add_child(shadow)
	reset_for_reuse()

func reset_for_reuse() -> void:
	model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), Vector3.ZERO)
	rig.reset_bone_poses()
	gait = phase_seed
	travel = 0
	speed = 0
	lean = 0
	kick_left = 0
	hit_left = 0
	fall_time = -1
	spawn_left = 0
	fade = 1.0
	windup = 0
	cheer = false
	smooth = Vector3.ZERO
	if shadow != null:
		shadow.visible = true

func bone(name: String, euler: Vector3) -> void:
	var i: int = bones[name]
	rig.set_bone_pose_rotation(i, rest[i] * Quaternion.from_euler(euler))

func muzzle() -> Vector3:
	return rig.global_transform * rig.get_bone_global_pose(bones.Muzzle).origin

func kick() -> void:
	kick_left = .14

func flinch() -> void:
	hit_left = .18

func die() -> void:
	fall_time = 0.0

func spawn() -> void:
	spawn_left = .30

## forward: metres/second the character travels relative to the ground in the
## direction it faces (negative walks backwards). dt is 0 while paused.
func animate(dt: float, forward: float, lateral: float = 0.0, run_style: float = 1.0) -> void:
	speed = forward
	gait += forward * dt / maxf(.05, stride) * TAU
	travel = move_toward(travel, clampf(absf(forward) / 1.6, 0, 1), dt * 6)
	lean = lerpf(lean, clampf(lateral * .09, -.22, .22), 1 - exp(-dt * 10))
	kick_left = maxf(0, kick_left - dt)
	hit_left = maxf(0, hit_left - dt)
	spawn_left = maxf(0, spawn_left - dt)
	smooth = smooth.lerp(Vector3.ZERO, 1 - exp(-dt * 12))
	model.position = smooth
	rig.reset_bone_poses()
	var amp := .55 * travel * run_style
	for side in ["L", "R"]:
		var step := sin(gait + (PI if side == "R" else 0.0))
		var lift := maxf(0, cos(gait + (PI if side == "R" else 0.0)))
		bone("Thigh" + side, Vector3(-step * amp, 0, 0))
		bone("Shin" + side, Vector3(lift * 1.1 * travel * run_style, 0, 0))
		bone("Foot" + side, Vector3(-step * .25 * travel, 0, 0))
	var bounce := absf(sin(gait)) * .035 * travel * run_style
	model.position.y += bounce * scale_factor
	bone("Torso", Vector3(-.10 * travel * run_style, sin(gait) * .10 * travel, lean))
	bone("Head", Vector3(.06 * travel, -sin(gait) * .06 * travel, -lean * .5))
	if spawn_left > 0:
		model.scale = Vector3.ONE * scale_factor * (1.0 - spawn_left / .30 * .6)
	else:
		model.scale = Vector3.ONE * scale_factor * maxf(.001, fade)

func pose_crew(dt: float, forward: float, lateral: float) -> void:
	animate(dt, forward, lateral)
	var recoil := kick_left / .14
	bone("Torso", Vector3(-.10 * travel + .10 * recoil, sin(gait) * .08 * travel, lean))
	bone("Weapon", Vector3(-.18 * recoil, 0, 0))
	bone("ArmR", Vector3(.10 * recoil, 0, 0))
	bone("ArmL", Vector3(.06 * recoil, 0, 0))
	if cheer:
		bone("ArmR", Vector3(-1.9, 0, .2))
		bone("ArmL", Vector3(-1.6, 0, -.3))
		bone("Weapon", Vector3(-1.2, 0, 0))
	_hit_and_fall(dt)

func pose_infected(dt: float, forward: float, role: String, clock: float) -> void:
	var style := 1.25 if role == "runner" else (.75 if role in ["bulwark", "plated"] else 1.0)
	animate(dt, forward, 0.0, style)
	var sway := sin(clock * 2.1 + phase_seed * 3.0)
	match role:
		"runner":
			for side in ["L", "R"]:
				var step := sin(gait + (0.0 if side == "R" else PI))
				bone("Arm" + side, Vector3(step * .9 * travel, 0, 0))
				bone("Forearm" + side, Vector3(-.9, 0, 0))
			bone("Torso", Vector3(-.38 * travel, sin(gait) * .12, 0))
		"spitter":
			bone("Head", Vector3(.55 * windup - .1, 0, 0))
			bone("Torso", Vector3(.25 * windup + .04 * sway, 0, 0))
			for side in ["L", "R"]:
				bone("Arm" + side, Vector3(.15 * sway, 0, .1 if side == "L" else -.1))
		"bulwark":
			bone("Torso", Vector3(-.12 + .05 * sway, sway * .06, 0))
			bone("Weapon", Vector3(.05 * sway, 0, 0))
		"cluster":
			bone("Crest", Vector3(0, clock * 1.4 + phase_seed, 0))
			bone("Torso", Vector3(-.2, sway * .2, 0))
		_:
			for side in ["L", "R"]:
				var reach := sin(clock * 2.6 + phase_seed * 5.0 + (PI if side == "R" else 0.0))
				bone("Arm" + side, Vector3(-.35 + reach * .25, 0, 0))
			bone("Torso", Vector3(-.10 + .06 * sway, sway * .10, sway * .05))
			bone("Head", Vector3(.15, sway * .25, sway * .15))
	_hit_and_fall(dt)

func pose_boss(dt: float, forward: float, kind: String, clock: float, attack: float) -> void:
	animate(dt, forward, 0.0, .8)
	var sway := sin(clock * 1.3)
	if kind == "matron":
		for side in ["L", "R"]:
			var s := 1.0 if side == "L" else -1.0
			bone("Arm" + side, Vector3(-.4 - 1.2 * attack + sway * .2 * s, 0, s * (.3 + .4 * attack)))
			bone("Forearm" + side, Vector3(-.5 * attack, 0, 0))
		bone("Torso", Vector3(.15 * attack, sway * .25, sway * .08))
		bone("Weapon", Vector3(0, 0, -sway * .08))
	else:
		bone("Torso", Vector3(-.35 * attack - .08, sway * .10, 0))
		bone("Head", Vector3(.25 * attack, 0, 0))
		bone("Weapon", Vector3(-.10 * attack, 0, 0))
		for side in ["L", "R"]:
			bone("Arm" + side, Vector3(-.3 - .4 * attack, 0, 0))
	_hit_and_fall(dt)

func _hit_and_fall(dt: float) -> void:
	if hit_left > 0:
		var h := hit_left / .18
		bone("Torso", Vector3(.30 * h, 0, .12 * h * (1.0 if fmod(phase_seed, 2.0) < 1.0 else -1.0)))
		bone("Head", Vector3(.35 * h, 0, 0))
	if fall_time >= 0:
		fall_time += dt
		var f := smoothstep(0.0, .45, fall_time)
		model.rotation.x = f * 1.45
		model.position.y = .06 * scale_factor
		bone("ArmR", Vector3(-1.1 * f, 0, .7 * f))
		bone("ArmL", Vector3(-.9 * f, 0, -.7 * f))
		bone("ThighL", Vector3(-.4 * f, 0, 0))
		bone("ShinR", Vector3(.8 * f, 0, 0))
		if shadow != null:
			shadow.visible = fall_time < .45
