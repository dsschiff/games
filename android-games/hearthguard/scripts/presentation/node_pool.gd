extends RefCounted
## Scene-owned inactive reserves only. Active actors/effects are never capped.
var owner: Node3D
var inactive: Node3D
var reserves := {}
var reserve_count := 0
var per_key_cap: int
var total_cap: int

func _init(scene: Node3D, label: String, per_key: int, total: int) -> void:
	owner = scene
	per_key_cap = per_key
	total_cap = total
	inactive = Node3D.new()
	inactive.name = label
	inactive.hide()
	inactive.process_mode = Node.PROCESS_MODE_DISABLED
	owner.add_child(inactive)

func take(key: String) -> Node3D:
	if not reserves.has(key):
		return null
	var node: Node3D = reserves[key].pop_back()
	reserve_count -= 1
	if reserves[key].is_empty():
		reserves.erase(key)
	node.reparent(owner, false)
	node.transform = Transform3D.IDENTITY
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.show()
	return node

func put(key: String, node: Node3D) -> void:
	assert(node.get_parent() != inactive, "Cannot return an inactive instance twice")
	node.reparent(inactive, false)
	node.transform = Transform3D.IDENTITY
	node.hide()
	node.process_mode = Node.PROCESS_MODE_DISABLED
	var count: int = reserves[key].size() if reserves.has(key) else 0
	if reserve_count >= total_cap or count >= per_key_cap:
		node.queue_free()
		return
	if not reserves.has(key):
		reserves[key] = []
	reserves[key].append(node)
	reserve_count += 1

func clear() -> void:
	for batch in reserves.values():
		for node in batch:
			node.queue_free()
	reserves.clear()
	reserve_count = 0
