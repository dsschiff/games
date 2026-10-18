extends RefCounted
## Presentation-only billboard offsets around the actual floating control.
## Authored anchors return exactly on release/pause/resize; no rule coordinates move.
const GAP := 12.0
var records := {}
var placements := {}
var unresolved: Array = []
var last_signature := ""

func restore() -> void:
	for id in records.keys():
		var record: Dictionary = records[id]
		if is_instance_valid(record.label) and record.label.is_inside_tree():
			record.label.global_position = record.anchor
		else:
			records.erase(id)
	placements.clear()
	unresolved.clear()

func reset() -> void:
	restore()
	records.clear()
	last_signature = ""

func update(labels: Array[Label3D], camera: Camera3D, control: Rect2, available: Rect2) -> void:
	var signature := str(control) + str(available) + str(camera.get_camera_transform()) + str(camera.size) + str(camera.h_offset) + str(camera.v_offset)
	var current := {}
	for label in labels:
		var id := label.get_instance_id()
		current[id] = true
		var glyph_key := label.text + str(label.font_size) + str(label.pixel_size) + str(label.outline_size)
		signature += str(id) + glyph_key
		if not records.has(id):
			records[id] = {"label": label, "anchor": label.global_position, "glyph_key": "", "faces": PackedVector3Array()}
		if records[id].glyph_key != glyph_key:
			records[id].faces = label.generate_triangle_mesh().get_faces()
			records[id].glyph_key = glyph_key
	if signature == last_signature:
		return
	restore()
	for id in records.keys():
		if not current.has(id):
			records.erase(id)
	last_signature = signature
	if not control.has_area():
		return
	# Clear the full rectangle, conservatively including the round base, knob's
	# two-pixel extension, soft shadow and padding around actual text geometry.
	var obstacle := control.grow(GAP)
	var rects := {}
	for id in current:
		rects[id] = projected(records[id], camera)
	for id in current:
		var original: Rect2 = rects[id]
		if not original.intersects(obstacle):
			continue
		var deltas: Array[Vector2] = []
		var left := obstacle.position.x - original.end.x - 1
		var right := obstacle.end.x - original.position.x + 1
		var up := obstacle.position.y - original.end.y - 1
		var down := obstacle.end.y - original.position.y + 1
		for x in [0.0, left, right]:
			for y in [0.0, up, down]:
				if x != 0 or y != 0:
					deltas.append(Vector2(x, y))
		# Bounded crowded/corner fallback. Normal placement uses a nearest edge or
		# corner offset without allocating another rendered label/node.
		for row in 7:
			for column in 7:
				var at := available.position + Vector2((available.size.x - original.size.x) * column / 6.0, (available.size.y - original.size.y) * row / 6.0)
				deltas.append(at - original.position)
		deltas.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
		var resolved := false
		for delta in deltas:
			var candidate := Rect2(original.position + delta, original.size)
			if not available.encloses(candidate) or candidate.intersects(obstacle):
				continue
			var other_overlap := false
			for other in rects:
				if other != id and candidate.grow(4).intersects(rects[other]):
					other_overlap = true
					break
			if other_overlap:
				continue
			var anchor: Vector3 = records[id].anchor
			var depth := -camera.to_local(anchor).z
			records[id].label.global_position = camera.project_position(camera.unproject_position(anchor) + delta, depth)
			rects[id] = candidate
			placements[id] = {"label": records[id].label, "anchor": anchor, "before": original, "after": candidate, "pixel_offset": delta}
			resolved = true
			break
		if not resolved:
			unresolved.append(id)

func projected(record: Dictionary, camera: Camera3D) -> Rect2:
	var transform := Transform3D(camera.global_basis, record.anchor)
	var bounds := Rect2()
	var first := true
	for vertex in record.faces:
		var pixel := camera.unproject_position(transform * vertex)
		if first:
			bounds = Rect2(pixel, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(pixel)
	return bounds
