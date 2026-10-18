extends RefCounted
## Instance resources belong to one adapter. No static/default mutable cache.
var scenes := {}
var materials := {}

func asset(key: String) -> Node3D:
	if not scenes.has(key):
		scenes[key] = load("res://art/models/" + key + ".glb") as PackedScene
	var node: Node3D = scenes[key].instantiate()
	_finish(node)
	return node

func _finish(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var key := source.get_instance_id()
				if not materials.has(key):
					var m := source.duplicate() as StandardMaterial3D
					m.albedo_color = source.albedo_color.srgb_to_linear()
					materials[key] = m
				node.set_surface_override_material(i, materials[key])
	for child in node.get_children():
		_finish(child)

func clear() -> void:
	scenes.clear()
	materials.clear()

static func skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := skeleton(child)
		if found != null:
			return found
	return null

static func bounds(node: Node3D, relative: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is MeshInstance3D:
			var box: AABB = (relative.global_transform.affine_inverse() * current.global_transform) * current.get_aabb()
			result = result.merge(box) if found else box
			found = true
		pending.append_array(current.get_children())
	return result
