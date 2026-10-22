extends RefCounted
## Loads the original Blender kit. Instance resources belong to one adapter;
## no static/default mutable cache survives a rebuild.
## Every GLB exports one vertex-coloured "Palette" mesh and optionally one
## unshaded "Glow" mesh, so actors and props cost one or two draw calls.
var scenes := {}
var materials := {}
var meshes := {}

func asset(key: String) -> Node3D:
	if not scenes.has(key):
		scenes[key] = load("res://art/models/" + key + ".glb") as PackedScene
	var node: Node3D = scenes[key].instantiate()
	_finish(node)
	return node

func material(kind: String) -> StandardMaterial3D:
	if not materials.has(kind):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.albedo_color = Color.WHITE
		m.roughness = .86
		m.metallic = 0
		if kind == "Glow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materials[kind] = m
	return materials[kind]

func _finish(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(i)
			var kind := "Glow" if source != null and source.resource_name == "Glow" else "Palette"
			node.set_surface_override_material(i, material(kind))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _is_glow(node) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_finish(child)

func _is_glow(node: MeshInstance3D) -> bool:
	return node.mesh.get_surface_count() == 1 and node.get_surface_override_material(0) == materials.get("Glow")

## Static (unskinned) meshes of a prop with their transforms relative to the
## asset root, for MultiMesh scenery layers.
func parts(key: String) -> Array:
	if not meshes.has(key):
		var root := asset(key)
		var out: Array = []
		var pending: Array[Node] = [root]
		while not pending.is_empty():
			var current: Node = pending.pop_back()
			if current is MeshInstance3D and current.skin == null:
				var xf := Transform3D.IDENTITY
				var walk: Node = current
				while walk != root:
					xf = (walk as Node3D).transform * xf
					walk = walk.get_parent()
				out.append({"mesh": current.mesh, "transform": xf, "material": current.get_surface_override_material(0)})
			pending.append_array(current.get_children())
		root.free()
		meshes[key] = out
	return meshes[key]

func clear() -> void:
	scenes.clear()
	materials.clear()
	meshes.clear()

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
