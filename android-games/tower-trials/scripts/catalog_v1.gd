extends RefCounted
## Introductory addition is source-supported; all route/resource rules are original.

static func room(id: String, name: String, column: int, floor_index: int, enemies: Array, extra: Dictionary = {}) -> Dictionary:
	var value := {"id": id, "name": name, "column": column, "floor": floor_index, "enemies": enemies, "requires": [], "key_cost": 0, "keys": 0, "shields": 0, "trap": 0, "multiplier": 1, "collapse": [], "treasure": false, "rescue": false}
	value.merge(extra, true)
	return value

static func levels() -> Array:
	return [
		{"id": "watch_01", "name": "The first light", "chapter": 0, "power": 3, "par": 4, "lesson": "Tap a room to preview. Power must be GREATER. Equal power loses.", "story": "Carry the dawn lantern up the abandoned watch.", "rooms": [
			room("bell", "Low bell", 1, 0, [2]),
			room("rope", "Rope loft", 1, 1, [3]),
			room("clock", "Clock room", 1, 2, [5]),
			room("light", "Dawn keeper", 2, 2, [11], {"requires": ["bell", "rope", "clock"], "rescue": true})]},
		{"id": "watch_02", "name": "Two chimes", "chapter": 0, "power": 5, "par": 4, "lesson": "Two spirits fight LEFT TO RIGHT. Add the first before checking the second.", "story": "The chimes answer each other. Order changes the outcome.", "rooms": [
			room("pair", "Twin chimes", 1, 0, [3, 7]),
			room("reverse", "Wrong refrain", 2, 0, [7, 3], {"treasure": true}),
			room("loft", "Bell loft", 1, 1, [12], {"requires": ["pair"]}),
			room("star", "Star chest", 2, 1, [8], {"requires": ["pair"], "treasure": true}),
			room("light", "Chime keeper", 2, 2, [25], {"requires": ["loft"], "rescue": true})]},
		{"id": "watch_03", "name": "The key ferry", "chapter": 0, "power": 8, "par": 3, "lesson": "A dashed bridge is ONE WAY: claiming either ferry collapses the other.", "story": "The smallest spirit guards no key. Read both ferries first.", "rooms": [
			room("easy", "Empty ferry", 1, 0, [1], {"collapse": ["key"]}),
			room("key", "Key ferry", 2, 0, [6], {"keys": 1, "collapse": ["easy"]}),
			room("door", "Sea gate", 2, 1, [10], {"key_cost": 1, "requires": ["key"]}),
			room("light", "Ferry keeper", 2, 2, [20], {"requires": ["door"], "rescue": true})]},
		{"id": "watch_04", "name": "Glass causeway", "chapter": 0, "power": 7, "par": 4, "lesson": "A shield blocks ONE trap. A carried shield bars the sun multiplier.", "story": "Two routes cross the glass. Pick protection or the sun.", "rooms": [
			room("shield", "Shell guard", 1, 0, [4], {"shields": 1, "collapse": ["sun"]}),
			room("sun", "Sun lens", 2, 0, [2], {"multiplier": 2, "collapse": ["shield"]}),
			room("trap", "Glass stair", 1, 1, [6], {"trap": 8}),
			room("loft", "Salt loft", 2, 1, [12]),
			room("light", "Glass keeper", 2, 2, [27], {"requires_any": ["trap", "loft"], "rescue": true})]}
	]

static func by_id(id: String) -> Dictionary:
	for level in levels():
		if level.id == id:
			return level
	return {}
