extends RefCounted
## Instance resources belong to one adapter. No static/default mutable cache.
var scenes := {}
var materials := {}
## Presentation grade for the authored GLB materials, keyed by material name.
## The exported bases are deliberately neutral; this warm tropical grade gives
## each creature role its own readable hue and keeps the diver the only saffron.
const GRADE := {
	"Deep ocean rubber": "253a4c", "Diver brass": "e3a640", "Enamel jade": "1fae9d",
	"Visor sea glass": "7fe3e6", "Diver saffron": "ffb526", "Salvaged teak": "8c5a36",
	"Warm limestone": "e8cf98", "Ocean basalt": "6f7f80", "Palm frond": "3e9f4e",
	"Pearl edge": "fff2d2", "Sun coral": "f2705a", "Storm enamel": "8a6fe0",
	"terrain_0": "f0d79f", "terrain_1": "efbf8c", "terrain_2": "e2d3a8", "terrain_3": "ebe0cf",
	"Carapace skitter": "3dbfa6", "Carapace lancer": "3f7fd6", "Carapace spitter": "9ccd3a",
	"Carapace shield": "6d86a6", "Carapace charger": "e2483e", "Carapace tender": "b06ad6",
	"Carapace warden": "3f9c86", "Carapace kiln": "e06a2c", "Carapace twin_sun": "f28a3c",
	"Carapace twin_moon": "5e83e6", "Carapace crown": "9a5ad6", "Carapace bellkeeper": "5aa860"
}

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
					m.albedo_color = Color(GRADE[source.resource_name]) if GRADE.has(source.resource_name) else source.albedo_color.srgb_to_linear()
					m.metallic = minf(m.metallic, .1)
					m.roughness = .82
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
