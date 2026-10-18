extends RefCounted
## Inactive mathematical fixtures; not the approved campaign or source claims.
const V1 = preload("res://scripts/catalog_v1.gd")

static func cases() -> Array:
	return [
		{"id": "prep_shield_key", "name": "A key through glass", "power": 7, "par": 4, "rooms": [
			V1.room("key", "Key loft", 1, 0, [2], {"keys": 1}),
			V1.room("shield", "Shell loft", 2, 0, [3], {"shields": 1, "collapse": ["sun"]}),
			V1.room("sun", "False dawn", 2, 1, [1], {"multiplier": 2, "collapse": ["shield"]}),
			V1.room("door", "Glass gate", 1, 1, [6], {"trap": 20, "key_cost": 1, "requires": ["key"]}),
			V1.room("light", "Glass keeper", 2, 2, [17], {"requires": ["door"], "rescue": true})]},
		{"id": "prep_two_keys", "name": "The patient locksmith", "power": 9, "par": 3, "rooms": [
			V1.room("key", "First key", 1, 0, [4], {"keys": 1}),
			V1.room("chest", "Salt chest", 2, 0, [1], {"key_cost": 1, "requires": ["key"], "treasure": true}),
			V1.room("door", "Archive gate", 1, 1, [8], {"key_cost": 1, "requires": ["key"]}),
			V1.room("spare", "Second key", 2, 1, [15], {"keys": 1, "requires": ["door"]}),
			V1.room("light", "Archive keeper", 2, 2, [20], {"requires": ["door"], "rescue": true})]},
		{"id": "prep_before_seal", "name": "Remember the balcony", "power": 6, "par": 4, "rooms": [
			V1.room("keeper", "Balcony keeper", 1, 0, [1], {"keys": 1}),
			V1.room("bridge", "Falling bridge", 2, 0, [4], {"collapse": ["keeper"]}),
			V1.room("door", "One-way gate", 2, 1, [8], {"key_cost": 1, "requires": ["bridge"]}),
			V1.room("light", "Final lantern", 2, 2, [18], {"requires": ["keeper", "door"], "rescue": true})]},
		{"id": "prep_ordered_glass", "name": "Two voices in glass", "power": 10, "par": 3, "rooms": [
			V1.room("shield", "Shell spirit", 1, 0, [3], {"shields": 1, "collapse": ["sun"]}),
			V1.room("sun", "Sun spirit", 2, 0, [2], {"multiplier": 2, "collapse": ["shield"]}),
			V1.room("pair", "Glass duet", 1, 1, [11, 22], {"trap": 8}),
			V1.room("light", "Duet keeper", 2, 2, [45], {"requires": ["pair"], "rescue": true})]},
		{"id": "prep_spend_shield", "name": "Put down the shell", "power": 8, "par": 4, "rooms": [
			V1.room("guard", "Shell keeper", 1, 0, [2], {"shields": 1, "collapse": ["shortcut"]}),
			V1.room("shortcut", "Bright shortcut", 2, 0, [1], {"collapse": ["guard"]}),
			V1.room("trap", "Glass landing", 1, 1, [3], {"trap": 6, "requires": ["guard"]}),
			V1.room("sun", "Unshielded lens", 2, 1, [3], {"multiplier": 2, "requires": ["guard"]}),
			V1.room("light", "Sun keeper", 2, 2, [30], {"requires": ["sun"], "rescue": true})]},
		{"id": "prep_treasure_budget", "name": "Both kinds of gold", "power": 8, "par": 3, "rooms": [
			V1.room("key", "First key", 1, 0, [5], {"keys": 1}),
			V1.room("door", "Outer gate", 1, 1, [8], {"requires": ["key"]}),
			V1.room("chest", "Sea chest", 2, 1, [1], {"key_cost": 1, "requires": ["door"], "treasure": true}),
			V1.room("spare", "Spare keys", 1, 2, [15], {"key_cost": 1, "keys": 2, "requires": ["door"]}),
			V1.room("light", "Inner keeper", 2, 2, [20], {"key_cost": 1, "requires": ["door"], "rescue": true})]}
	]
