extends SceneTree
## Actual exported triangle/surface regression for the observed coplanar deck.
var checks := 0
var failures: Array[String] = []
var result_path := "res://.artifacts/graphics-production/deck-geometry.json"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="):
			result_path = arg.trim_prefix("--run-dir=")+"/deck-data.json"
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error(detail)

func geometry(node: Node3D, inherited: Transform3D, result: Dictionary) -> void:
	var transform := inherited * node.transform
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(surface)
			var key := str(material.resource_name)
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if not result.has(key):
				result[key] = {"top":-INF,"triangles":[]}
			for vertex in vertices:
				result[key].top = maxf(result[key].top,(transform*vertex).y)
			for i in range(0,indices.size(),3):
				result[key].triangles.append([transform*vertices[indices[i]],transform*vertices[indices[i+1]],transform*vertices[indices[i+2]]])
	for child in node.get_children():
		if child is Node3D:
			geometry(child,transform,result)

func exposed_holes(layers: Dictionary) -> int:
	var count := 0
	for row in 4:
		for column in 5:
			var point := Vector3((column-2)*2,1,(row-1.5)*sqrt(8))
			var blocked := false
			for triangle in layers.DeckEnamel.triangles:
				if Geometry3D.segment_intersects_triangle(point,point-Vector3(0,2,0),triangle[0],triangle[1],triangle[2]) != null:
					blocked = true
					break
			if not blocked:
				count += 1
	return count

func run() -> void:
	var current := (load("res://art/models/foundry_deck.glb") as PackedScene).instantiate() as Node3D
	var layers: Dictionary = {}
	geometry(current,Transform3D.IDENTITY,layers)
	check(layers.has("Iron") and layers.has("DeckEnamel") and layers.has("Brass") and layers.has("SocketRecess"),"Actual exported deck retains distinct bed/floor/rim/recess materials")
	check(float(layers.DeckEnamel.top)-float(layers.Iron.top) > .07,"Actual exported broad floor/bed faces are separated, preventing the observed z-fight")
	check(float(layers.Brass.top) > float(layers.DeckEnamel.top)+.01,"Actual rim is seated above floor without coplanarity")
	check(float(layers.SocketRecess.top) < float(layers.DeckEnamel.top)-.02,"Actual well/conduit floors are below the walking surface")
	var holes := exposed_holes(layers)
	check(holes == 20,"All twenty actual floor socket apertures are open to their recessed wells")
	current.free()
	var sensitivity: Dictionary = {}
	var old_path := "res://.artifacts/graphics-production/deck-129c759.glb"
	if FileAccess.file_exists(old_path):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var code := document.append_from_file(ProjectSettings.globalize_path(old_path),state)
		check(code == OK,"Frozen second-inspection deck loads for old-fail sensitivity")
		if code == OK:
			var old := document.generate_scene(state) as Node3D
			var old_layers: Dictionary = {}
			geometry(old,Transform3D.IDENTITY,old_layers)
			sensitivity = {"bed_top":old_layers.Iron.top,"floor_top":old_layers.DeckEnamel.top,"open_sockets":exposed_holes(old_layers)}
			check(absf(float(old_layers.DeckEnamel.top)-float(old_layers.Iron.top)) < .00001,"Frozen old asset reproduces coplanar broad faces")
			check(int(sensitivity.open_sockets) == 0,"Frozen old solid floor blocks all twenty socket apertures")
			old.free()
	var report := {"checks":checks,"failures":failures,"current":{"bed_top":layers.Iron.top,"floor_top":layers.DeckEnamel.top,"rim_top":layers.Brass.top,"recess_top":layers.SocketRecess.top,"open_sockets":holes},"old_asset_sensitivity":sensitivity,"scope":"CPU exported geometry only; rendered banding closure remains pending"}
	var file := FileAccess.open(result_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("DECK_GEOMETRY: %d checks, %d failures" % [checks,failures.size()])
	print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
