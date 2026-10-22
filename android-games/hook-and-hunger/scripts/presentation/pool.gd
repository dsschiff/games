extends RefCounted
## Bounded inactive reserves. Active rule objects are never culled to meet a cap.
var owner: Node3D
var inactive: Node3D
var reserves := {}
var count := 0
var per_key := 12
var total := 64

func _init(host: Node3D) -> void:
	owner = host
	inactive = Node3D.new()
	inactive.name = "InactiveReserves"
	inactive.hide()
	inactive.process_mode = Node.PROCESS_MODE_DISABLED
	owner.add_child(inactive)

func take(key: String) -> Node3D:
	if not reserves.has(key):
		return null
	var node: Node3D = reserves[key].pop_back()
	count -= 1
	if reserves[key].is_empty():
		reserves.erase(key)
	node.reparent(owner, false)
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.transform = Transform3D.IDENTITY
	node.show()
	return node

func put(key: String, node: Node3D) -> void:
	assert(node.get_parent() != inactive)
	if node.has_method("reset_for_reuse"):
		node.reset_for_reuse()
	if node.has_meta("life"):
		node.set_meta("life", 0.0)
	node.reparent(inactive, false)
	node.transform = Transform3D.IDENTITY
	node.hide()
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if count >= total or (reserves.has(key) and reserves[key].size() >= per_key):
		node.queue_free()
		return
	if not reserves.has(key):
		reserves[key] = []
	reserves[key].append(node)
	count += 1

func clear() -> void:
	reserves.clear()
	count = 0
