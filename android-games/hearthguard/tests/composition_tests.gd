extends "res://tests/presentation_tests.gd"
## Focused response to original root-first-inspect native still. No renderer.

func run() -> void:
	for name in ["rules.gd", "campaign_rules.gd", "campaign_catalog.gd", "save_store.gd", "save_files.gd"]:
		check(FileAccess.get_file_as_string("res://scripts/" + name).replace("\r\n", "\n") == FileAccess.get_file_as_string(baseline + name).replace("\r\n", "\n"), "composition preserves baseline rules/save source: " + name)
	var profiles := [Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1100, 1400), Vector2i(1600, 1000), Vector2i(2560, 1440)]
	for stage in 10:
		var state := C.fresh(Cat.definition(stage))
		var whole := state.duplicate(true)
		var view := V.new()
		root.add_child(view)
		view.set_process(false)
		view.build(state)
		state.towers[0].family = 0
		view.synchronize(state, false, 0)
		await process_frame
		var road := view.get_node("RoadLane0") as MeshInstance3D
		check(front_sign(road.mesh) * front_sign(BoxMesh.new()) > 0, "road front faces match upward-facing Godot reference mesh map " + str(stage + 1))
		var protected := AABB(Vector3(-5.2, -.01, -7.99), Vector3(10.4, 3, 15.19))
		var physical_clear := true
		for record in view.bounds_records:
			physical_clear = physical_clear and not (record.bounds as AABB).intersects(protected)
		check(physical_clear, "varied shoulder clusters preserve complete traversable actor bounds map " + str(stage + 1))
		var clusters: Array = view.region.clusters
		check(clusters.size() == 3 and absf(clusters[0][1] - clusters[1][1]) > 3 and absf(clusters[1][1] - clusters[2][1]) > 3 and clusters[0][2] != clusters[1][2], "regional clusters have distinct angles and separated quiet gaps map " + str(stage + 1))
		for size in profiles:
			root.size = size
			await process_frame
			var logical := root.get_visible_rect().size
			var field := Rect2(Vector2(28, 228), Vector2(logical.x - 56, logical.y - 516))
			view.fit(field)
			var clipped := false
			var intrusion := false
			var forbidden := [Rect2(0, 0, logical.x, 210), Rect2(0, logical.y - 160, logical.x, 160), Rect2(38, logical.y - 378, 160, 160)]
			for record in view.bounds_records:
				var silhouette: Rect2 = view.projected_bounds(bounds_points(record.bounds))
				clipped = clipped or not field.grow(.2).encloses(silhouette)
				for control_rect in forbidden:
					if silhouette.intersects(control_rect):
						intrusion = true
						print("COMPOSITION_INTRUSION ", stage + 1, " ", size, " ", record.asset, " ", silhouette)
			check(not clipped and not intrusion, "full scenery silhouettes fit scenic shoulders and clear HUD/actions/joystick map %d at %s" % [stage + 1, size])
			var price: Label3D = view.pad_labels[1]
			var tower: Label3D = view.towers[0].title
			var price_pixels := label_pixels(view, price)
			var tower_pixels := label_pixels(view, tower)
			print("ESSENTIAL_LABEL_PIXELS map=", stage + 1, " profile=", size, " price=", price_pixels, " type=", tower_pixels)
			check(price_pixels.y >= 32 and tower_pixels.y >= 16, "essential price/type glyph bounds remain cover-legible in projection map %d at %s" % [stage + 1, size])
		check(C.equivalent(whole.definition, state.definition) and state.time == 0, "composition never alters pinned definition or simulation time map " + str(stage + 1))
		view.queue_free()
		await process_frame
	var app: Node = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var scene: Node = app.get_node("Battle")
	scene.set_physics_process(false)
	for size in profiles:
		root.size = size
		await process_frame
		scene.layout()
		var header: Panel = scene.ui.get_node("Header")
		var crest: TextureRect = header.get_node("Crest")
		var title := header.get_child(0) as Label
		var subtitle := header.get_child(1) as Label
		check(crest.size == Vector2(40, 40) and not crest.get_global_rect().intersects(title.get_global_rect()) and not crest.get_global_rect().intersects(subtitle.get_global_rect()), "actual crest bounds clear both header text rows at " + str(size))
	app.queue_free()
	await process_frame
	var f := FileAccess.open(folder.path_join("composition-report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "scope": "CPU projected silhouettes, label mesh bounds, header layout and road winding; lighting/color/visual quality still require second rendered inspection"}, "\t"))
	f.close()
	print("COMPOSITION_CHECKS ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func label_pixels(view: Node3D, label: Label3D) -> Vector2:
	var billboard := Transform3D(view.camera.global_basis, label.global_position)
	var points: Array[Vector3] = []
	# Label3D.get_aabb() expands billboard bounds into a cube for culling; its
	# height is not text height. Sample the actual generated text collision mesh.
	for point in label.generate_triangle_mesh().get_faces():
		points.append(billboard * point)
	return view.projected_bounds(points).size

func front_sign(mesh: Mesh) -> float:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var a: int = indices[i]
		var b: int = indices[i + 1]
		var c: int = indices[i + 2]
		if normals[a].dot(Vector3.UP) > .99:
			return (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(Vector3.UP)
	return 0
