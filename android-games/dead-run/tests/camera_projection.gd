extends SceneTree
const C = preload("res://scripts/campaign_rules.gd")
const R = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
var details: Array = []
var records: Array = []
var folder := ""
var viewport: SubViewport

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func check(okay: bool, label: String) -> void:
	checks += 1
	details.append({"pass": okay, "label": label})
	if not okay:
		failures += 1
		print("FAIL ", label)

func corners(bounds: AABB, transform: Transform3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in 8: points.append(transform * bounds.get_endpoint(i))
	return points

func mesh_points(node: Node) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if node is MeshInstance3D:
		points.append_array(corners(node.mesh.get_aabb(), node.global_transform))
	for child in node.get_children(): points.append_array(mesh_points(child))
	return points

func matrix(camera: Camera3D) -> Array:
	var p := camera.get_camera_projection()
	return [p.x, p.y, p.z, p.w].map(func(v): return [v.x, v.y, v.z, v.w])

func envelope(camera: Camera3D, groups: Dictionary, label: String) -> Dictionary:
	var result := {}
	var size := viewport.get_visible_rect().size
	for name in groups:
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var in_frustum := true
		for point in groups[name]:
			var screen: Vector2 = camera.unproject_position(point) / size
			low = low.min(screen)
			high = high.max(screen)
			in_frustum = in_frustum and camera.is_position_in_frustum(point)
		var fits: bool = in_frustum and low.x >= 0.015 and high.x <= 0.985 and low.y >= 0.02 and high.y <= 0.90
		check(fits, label + " " + name + " complete with side/top/bottom margins")
		result[name] = {"min": [low.x, low.y], "max": [high.x, high.y], "points": groups[name].size(), "in_frustum": in_frustum, "margin_pass": fits}
	return result

func line_points(scene: Node, camera: Camera3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var parent: Node = scene.world if scene.get("world") != null else scene
	for node in parent.get_children():
		if node is MeshInstance3D and node.mesh is BoxMesh and node.mesh.size.x > 8 and node.mesh.size.z < 0.15:
			points.append_array(mesh_points(node))
		if node is Label3D and node.text == "RESCUE LINE":
			var bounds: AABB = node.get_aabb()
			check(bounds.size.x > 0 and bounds.size.y > 0, "real rescue caption has nonempty font bounds")
			# Label3D billboarding happens at render time; use its real font AABB in
			# the camera-facing basis rather than its unrotated scene-node basis.
			for i in 8:
				var q := bounds.get_endpoint(i)
				points.append(node.global_position + camera.global_basis.x * q.x + camera.global_basis.y * q.y)
	check(points.size() == 16, "actual line mesh and billboard caption both included")
	return points

func test_scene(scene: Node, kind: String) -> void:
	scene.set_physics_process(false)
	scene.paused = true
	var original: Dictionary = scene.state.duplicate(true)
	# Campaign authored FOV changed 46 -> 51 with the graphics chase camera.
	var authored := 51.0 if kind == "campaign" else 58.0
	var portrait_projections := {}
	var camera_pose: Transform3D = scene.camera.global_transform
	var counts := [5, 20] if kind == "campaign" else [3, 5, 12]
	var weapons := ["rivet", "lance", "fan"] if kind == "campaign" else ["legacy"]
	for weapon in weapons:
		if kind == "campaign":
			viewport.size = Vector2i(1968, 2184)
			await process_frame
			scene.state = C.fresh(23, weapon)
			scene.build_world()
			var creation := matrix(scene.camera)
			scene.layout()
			check(creation == matrix(scene.camera), "campaign rebuilt camera already fitted before layout")
		for size in [Vector2i(1080, 2400), Vector2i(1080, 2520), Vector2i(1968, 2184)]:
			viewport.size = size
			await process_frame
			var automatic := matrix(scene.camera)
			scene.layout()
			check(automatic == matrix(scene.camera), kind + " actual resize signal already fits camera before manual layout")
			check(scene.camera.global_transform == camera_pose, kind + " camera pose unchanged")
			var baseline := Camera3D.new()
			viewport.add_child(baseline)
			baseline.global_transform = scene.camera.global_transform
			baseline.keep_aspect = Camera3D.KEEP_WIDTH
			baseline.fov = authored
			if size.x == 1080:
				check(matrix(scene.camera) == matrix(baseline), kind + " exact original portrait projection " + str(size))
				portrait_projections[str(size)] = matrix(scene.camera)
			for count in counts:
				for side in [-1, 0, 1]:
					scene.state.crew = count
					var half: float = C.half_width(count) if kind == "campaign" else R.half_width(count)
					scene.state.x = side * (4.35 - half)
					scene.refresh()
					var crew: Array[Vector3] = []
					for i in count:
						var person: Node3D = scene.actors["crew" + str(i)]
						# Include both bob extrema, all authored parts and recruit rings.
						for height in [0.04, 0.08 if kind == "campaign" else 0.085]:
							person.position.y = height
							crew.append_array(mesh_points(person))
					var threats: Array[Vector3] = []
					for i in scene.state.enemies.size():
						var actor: Node3D = scene.actors["enemy" + str(i)]
						if kind == "campaign" and scene.state.definition.enemies[i].role not in ["drifter", "bulwark"]: continue
						for x in [-2.65, 0.0, 2.65]:
							for z in [-6.0, -0.1]:
								actor.position = Vector3(x, 0.04, z)
								threats.append_array(mesh_points(actor))
						if kind != "campaign": break
					var groups := {"crew": crew, "footprint": mesh_points(scene.footprint), "rescue_line_and_caption": line_points(scene, scene.camera), "near_threats": threats,
						"near_road_envelope": corners(AABB(Vector3(-4.35, 0, -6), Vector3(8.7, 2.0, 6)), Transform3D.IDENTITY)}
					var label: String = kind + "/" + weapon + "/" + str(size) + "/crew" + str(count) + "/edge" + str(side)
					var bounds := envelope(scene.camera, groups, label)
					records.append({"kind": kind, "weapon": weapon, "size": [size.x, size.y], "crew": count, "edge": side, "x": scene.state.x, "fov": scene.camera.fov, "matrix": matrix(scene.camera), "groups": bounds})
			baseline.queue_free()
			await process_frame
	# Repeated actual resize signals plus layout calls must not accumulate FOV.
	for i in 4:
		for size in [Vector2i(1080, 2400), Vector2i(1968, 2184), Vector2i(1080, 2520)]:
			viewport.size = size
			await process_frame
			scene.layout()
			var before := matrix(scene.camera)
			for repeat in 6: scene.layout()
			check(before == matrix(scene.camera), kind + " repeated layout does not compound FOV")
			if size.x == 1080: check(matrix(scene.camera) == portrait_projections[str(size)], kind + " exact portrait round trip")
	scene.state = original
	if kind == "campaign": scene.ctx.campaign = original
	scene.refresh()
	var before: Dictionary = scene.state.duplicate(true)
	viewport.size = Vector2i(1968, 2184)
	await process_frame
	scene.layout()
	check(scene.state == before, kind + " resize preserves every state field")

func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1080, 2400)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var scene: Node = load("res://campaign.tscn").instantiate()
	viewport.add_child(scene)
	await test_scene(scene, "campaign")
	# Restore the valid host before entering the actual parked legacy child.
	scene.ctx.campaign = scene.state
	scene.enter_legacy()
	await test_scene(scene.legacy_view, "legacy-bridge")
	scene.queue_free()
	await process_frame
	var standalone: Node = load("res://main.tscn").instantiate()
	viewport.add_child(standalone)
	await test_scene(standalone, "legacy-standalone")
	standalone.queue_free()
	await process_frame
	var f := FileAccess.open(folder.path_join("rules-report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "projections": records, "scope": "Pure headless real Camera3D/SubViewport projection/frustum and authored mesh/font geometry. Synthetic crew/lateral/weapon/threat geometry fixtures, not earned gameplay, rendered pixels or physical Fold7 evidence."}, "  ", true, true))
	f.close()
	print("CAMERA_PROJECTION ", checks, " failures=", failures, " envelopes=", records.size())
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
