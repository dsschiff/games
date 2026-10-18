extends RefCounted
## Authored routes. v1 remains untouched; IDs, not current indexes, identify saves.
const V1 = preload("res://scripts/catalog_v1.gd")

static func r(id: String, label: String, column: int, floor_index: int, enemies: Array, extra: Dictionary = {}) -> Dictionary:
	return V1.room(id, label, column, floor_index, enemies, extra)

static func puzzle(id: String, title: String, chapter: int, power: int, par: int, lesson: String, rooms: Array, finale: bool = false) -> Dictionary:
	return {"id": id, "name": title, "chapter": chapter, "power": power, "par": par, "lesson": lesson, "story": lesson, "rooms": rooms, "rules": 2, "finale": finale}

static func levels() -> Array:
	var old := V1.levels()
	var first: Dictionary = old[0].duplicate(true)
	first.rules = 2
	var second: Dictionary = old[1].duplicate(true)
	second.rules = 2
	var ferry: Dictionary = old[2].duplicate(true)
	ferry.rules = 2
	var glass: Dictionary = old[3].duplicate(true)
	glass.rules = 2
	glass.finale = true
	return [first, second,
		puzzle("coast_key", "A borrowed key", 0, 6, 3, "A gold key opens one lock, then is gone. Count doors before spending.", [
			r("key", "Key loft", 1, 0, [3], {"keys": 1}), r("door", "Locked stair", 1, 1, [8], {"key_cost": 1, "requires": ["key"]}),
			r("light", "Lock keeper", 2, 2, [16], {"requires": ["door"], "rescue": true})]),
		ferry,
		puzzle("coast_shell", "One shell, one trap", 0, 7, 3, "A shell shield blocks one trap BEFORE its enemies. Without one, subtract the trap first.", [
			r("shield", "Shell guard", 1, 0, [4], {"shields": 1}), r("trap", "Glass landing", 1, 1, [6], {"trap": 8}),
			r("chest", "Sea chest", 2, 0, [1], {"treasure": true}), r("light", "Shell keeper", 2, 2, [16], {"requires": ["trap"], "rescue": true})]),
		puzzle("coast_sun", "Set down the shell", 0, 8, 4, "A sun lens multiplies AFTER combat. It refuses a carried shield: spend that shield at a trap first.", [
			r("guard", "Shell spirit", 1, 0, [2], {"shields": 1}), r("trap", "Glass step", 1, 1, [3], {"trap": 6, "requires": ["guard"]}),
			r("sun", "Sun lens", 2, 1, [3], {"multiplier": 2, "requires": ["guard"]}), r("light", "Sun keeper", 2, 2, [30], {"requires": ["sun"], "rescue": true})]),
		puzzle("coast_tide", "The tide duet", 0, 8, 4, "Put the key through the duet. The second voice listens to your NEW power.", [
			r("key", "Tide key", 1, 0, [3], {"keys": 1}), r("pair", "Tide duet", 1, 1, [10, 18], {"requires": ["key"]}),
			r("door", "Upper lock", 2, 1, [28], {"requires": ["pair"], "key_cost": 1}), r("chest", "Quiet chest", 2, 0, [6], {"treasure": true}),
			r("light", "Tide keeper", 2, 2, [60], {"requires": ["door"], "rescue": true})]),
		puzzle("coast_balcony", "Before the bridge", 0, 6, 4, "A KEEPER room is a rescue along the route. Claim its balcony before a one-way bridge seals it.", [
			r("keeper", "Balcony keeper", 1, 0, [1], {"keys": 1, "keeper": true}), r("bridge", "Falling bridge", 2, 0, [4], {"collapse": ["keeper"]}),
			r("door", "One-way gate", 2, 1, [8], {"key_cost": 1, "requires": ["bridge"]}), r("light", "Lantern bearer", 2, 2, [18], {"requires": ["keeper", "door"], "rescue": true})]),
		glass,
		puzzle("archive_01", "The patient locksmith", 1, 9, 3, "The small chest uses the gate's only key. Reach the second key from inside.", [
			r("key", "First key", 1, 0, [4], {"keys": 1}), r("chest", "Salt chest", 2, 0, [1], {"key_cost": 1, "requires": ["key"], "treasure": true}),
			r("door", "Archive gate", 1, 1, [8], {"key_cost": 1, "requires": ["key"]}), r("spare", "Second key", 2, 1, [15], {"keys": 1, "requires": ["door"]}),
			r("light", "Archive keeper", 2, 2, [20], {"requires": ["door"], "rescue": true})]),
		puzzle("archive_02", "The room that pays", 1, 8, 3, "A locked vault spends one key and yields two. Opening the chest first strands both.", [
			r("key", "Gate key", 1, 0, [5], {"keys": 1}), r("door", "Outer stair", 1, 1, [8], {"requires": ["key"]}),
			r("chest", "Sea chest", 2, 1, [1], {"key_cost": 1, "requires": ["door"], "treasure": true}), r("spare", "Two-key vault", 1, 2, [15], {"key_cost": 1, "keys": 2, "requires": ["door"]}),
			r("light", "Inner keeper", 2, 2, [20], {"key_cost": 1, "requires": ["door"], "rescue": true})]),
		puzzle("archive_03", "Two ferries at dusk", 1, 10, 5, "Both ferry choices look safe. One seals the key, the other preserves a keeper.", [
			r("keeper", "Dusk keeper", 1, 0, [3], {"keeper": true}), r("wrong", "Fast ferry", 2, 0, [1], {"collapse": ["key"]}),
			r("key", "Key ferry", 1, 1, [8], {"keys": 1, "collapse": ["wrong"], "requires": ["keeper"]}), r("door", "Dusk lock", 2, 1, [17], {"requires": ["key"], "key_cost": 1}),
			r("duet", "Evening duet", 1, 2, [20, 35], {"requires": ["door"]}), r("light", "Dusk lantern", 2, 2, [60], {"requires": ["keeper", "duet"], "rescue": true})]),
		puzzle("archive_04", "The reversed chorus", 1, 12, 5, "A promising total hides an impossible first voice. Read the order, not the sum.", [
			r("key", "Choir key", 1, 0, [5], {"keys": 1}), r("bad", "False chorus", 2, 0, [30, 6], {"collapse": ["pair"]}),
			r("pair", "True chorus", 1, 1, [10, 23], {"requires": ["key"], "collapse": ["bad"]}), r("door", "Choir door", 2, 1, [42], {"requires": ["pair"], "key_cost": 1}),
			r("keeper", "Choir keeper", 1, 2, [60], {"requires": ["door"], "keeper": true}), r("light", "Choir lantern", 2, 2, [120], {"requires": ["keeper"], "rescue": true})]),
		puzzle("archive_05", "An expensive shortcut", 1, 11, 5, "Choose the bridge only after visiting the little keeper. The chest is a separate detour.", [
			r("keeper", "Small keeper", 1, 0, [2], {"keeper": true, "keys": 1}), r("bridge", "Quick bridge", 2, 0, [7], {"collapse": ["keeper"]}),
			r("door", "Bridge lock", 2, 1, [18], {"requires": ["bridge"], "key_cost": 1}), r("duet", "Woven chimes", 1, 1, [14, 30], {"requires": ["keeper"]}),
			r("chest", "High chest", 1, 2, [50], {"requires": ["duet"], "treasure": true}), r("light", "Bridge lantern", 2, 2, [72], {"requires": ["keeper", "door", "duet"], "rescue": true})]),
		puzzle("archive_06", "Spend to receive", 1, 10, 5, "Two locked rooms return different keys. Keep one for the final door.", [
			r("key", "Salt key", 1, 0, [6], {"keys": 1}), r("vault", "Key exchange", 1, 1, [12], {"requires": ["key"], "key_cost": 1, "keys": 2}),
			r("chest", "Tiny lock", 2, 0, [1], {"key_cost": 1, "requires": ["key"], "treasure": true}), r("door", "Copper door", 2, 1, [20], {"key_cost": 1, "requires": ["vault"]}),
			r("keeper", "Copper keeper", 1, 2, [40], {"requires": ["door"], "keeper": true}), r("spare", "Copper spare", 1, 3, [20], {"requires": ["keeper"], "keys": 1}), r("light", "Copper lantern", 2, 2, [80], {"requires": ["keeper"], "key_cost": 1, "rescue": true})]),
		puzzle("archive_07", "A promise on each bank", 1, 14, 6, "Rescue both bank keepers before committing their bridges. Each carries half the route.", [
			r("west", "West keeper", 1, 0, [4], {"keeper": true, "keys": 1}), r("east", "East keeper", 2, 0, [7], {"keeper": true, "keys": 1}),
			r("bridge_w", "West bridge", 1, 1, [16], {"collapse": ["west"]}), r("bridge_e", "East bridge", 2, 1, [22], {"collapse": ["east"]}),
			r("door", "Twin lock", 1, 2, [45], {"requires": ["bridge_w", "bridge_e"], "key_cost": 2}), r("light", "Bank lantern", 2, 2, [90], {"requires": ["west", "east", "door"], "rescue": true})]),
		puzzle("archive_08", "Treasure after the toll", 1, 12, 5, "Spend at the toll before buying the chest. A second key is behind the paid door.", [
			r("key", "Toll key", 1, 0, [7], {"keys": 1}), r("chest", "Greedy chest", 2, 0, [1], {"key_cost": 1, "requires": ["key"], "treasure": true}),
			r("toll", "Toll door", 1, 1, [15], {"requires": ["key"], "key_cost": 1}), r("spare", "Toll refund", 2, 1, [23], {"requires": ["toll"], "keys": 1}),
			r("keeper", "Toll keeper", 1, 2, [44], {"requires": ["spare"], "keeper": true}), r("light", "Toll lantern", 2, 2, [90], {"requires": ["keeper"], "rescue": true})]),
		puzzle("archive_09", "The archive closes", 1, 15, 7, "Finale: two rescued keepers, two spent keys and a duet beyond the closing bridge.", [
			r("west", "Index keeper", 1, 0, [5], {"keeper": true, "keys": 1}), r("east", "Map keeper", 2, 0, [9], {"keeper": true, "keys": 1}),
			r("bridge", "Closing bridge", 1, 1, [18], {"collapse": ["west", "east"]}), r("door_a", "First lock", 2, 1, [32], {"requires": ["bridge"], "key_cost": 1}),
			r("pair", "Index duet", 1, 2, [44, 80], {"requires": ["door_a"]}), r("door_b", "Last lock", 2, 2, [120], {"requires": ["pair"], "key_cost": 1}),
			r("light", "Archive lantern", 2, 3, [240], {"requires": ["west", "east", "door_b"], "rescue": true})], true),
		puzzle("glass_01", "A key through glass", 2, 7, 4, "The sun gives quick power but seals the shield. The locked trap still needs protection.", [
			r("key", "Glass key", 1, 0, [2], {"keys": 1}), r("shield", "Shell guard", 2, 0, [3], {"shields": 1, "collapse": ["sun"]}),
			r("sun", "False dawn", 2, 1, [1], {"multiplier": 2, "collapse": ["shield"]}), r("door", "Glass gate", 1, 1, [6], {"trap": 20, "key_cost": 1, "requires": ["key"]}),
			r("light", "Glass lantern", 2, 2, [17], {"requires": ["door"], "rescue": true})]),
		puzzle("glass_02", "Two voices in glass", 2, 10, 3, "Both shell and sun can cross the duet. The unprotected arithmetic changes.", [
			r("shield", "Shell spirit", 1, 0, [3], {"shields": 1, "collapse": ["sun"]}), r("sun", "Sun spirit", 2, 0, [2], {"multiplier": 2, "collapse": ["shield"]}),
			r("pair", "Glass duet", 1, 1, [11, 22], {"trap": 8}), r("light", "Duet lantern", 2, 2, [45], {"requires": ["pair"], "rescue": true})]),
		puzzle("glass_03", "Keep the second shell", 2, 9, 5, "Two traps need two shields. A harmless-looking side trap can waste the second one.", [
			r("shells", "Two shells", 1, 0, [4], {"shields": 2}), r("waste", "Side glass", 2, 0, [1], {"trap": 1, "requires": ["shells"], "treasure": true}),
			r("first", "First glass", 1, 1, [8], {"trap": 30, "requires": ["shells"]}), r("second", "Second glass", 2, 1, [16], {"trap": 35, "requires": ["first"]}),
			r("pair", "Shell duet", 1, 2, [24, 40], {"requires": ["second"]}), r("light", "Shell lantern", 2, 2, [90], {"requires": ["pair"], "rescue": true})]),
		puzzle("glass_04", "A sun after rain", 2, 11, 5, "Use protection, then sunlight. The sun refuses any shield still carried.", [
			r("shell", "Rain shell", 1, 0, [5], {"shields": 1}), r("trap", "Rain glass", 1, 1, [9], {"trap": 25, "requires": ["shell"]}),
			r("sun", "Rain lens", 2, 1, [7], {"multiplier": 2, "requires": ["shell"]}), r("pair", "Rain duet", 1, 2, [40, 75], {"requires": ["sun"]}),
			r("chest", "Dry chest", 2, 0, [8], {"treasure": true}), r("light", "Rain lantern", 2, 2, [150], {"requires": ["trap", "pair"], "rescue": true})]),
		puzzle("glass_05", "The shielded keeper", 2, 12, 6, "Rescue the keeper on the trapped balcony before sealing it. The shield also bars the sun.", [
			r("shell", "Balcony shell", 1, 0, [5], {"shields": 1}), r("keeper", "Glass keeper", 1, 1, [12], {"trap": 40, "keeper": true, "requires": ["shell"], "keys": 1}),
			r("bridge", "Glass bridge", 2, 0, [8], {"collapse": ["keeper"]}), r("sun", "Balcony lens", 2, 1, [16], {"multiplier": 2, "requires": ["bridge"]}),
			r("door", "Balcony lock", 1, 2, [70], {"key_cost": 1, "requires": ["sun"]}), r("light", "Balcony lantern", 2, 2, [150], {"requires": ["keeper", "door"], "rescue": true})]),
		puzzle("glass_06", "A small price in power", 2, 20, 5, "Not every trap needs a shell. Paying a small loss can keep the sun route open.", [
			r("key", "Storm key", 1, 0, [8], {"keys": 1}), r("trap", "Shallow glass", 1, 1, [6], {"trap": 5, "requires": ["key"]}),
			r("sun", "Storm lens", 2, 1, [14], {"multiplier": 2, "requires": ["trap"]}), r("door", "Storm lock", 1, 2, [60], {"key_cost": 1, "requires": ["sun"]}),
			r("shell", "Unneeded shell", 2, 0, [1], {"shields": 1}), r("light", "Storm lantern", 2, 2, [140], {"requires": ["door"], "rescue": true})]),
		puzzle("glass_07", "Sun before the gift", 2, 14, 6, "Take the lens before the keeper's shield. A carried gift can close an earlier route.", [
			r("sun", "Early lens", 1, 0, [6], {"multiplier": 2}), r("keeper", "Gift keeper", 2, 0, [2], {"keeper": true, "shields": 1}),
			r("key", "Gift key", 1, 1, [28], {"requires": ["sun"], "keys": 1}), r("trap", "Gift glass", 2, 1, [40], {"requires": ["key"], "trap": 100}),
			r("door", "Gift lock", 1, 2, [70], {"key_cost": 1, "requires": ["trap"]}), r("light", "Gift lantern", 2, 2, [140], {"requires": ["keeper", "door"], "rescue": true})]),
		puzzle("glass_08", "A chest beyond glass", 2, 16, 5, "Spend both shells on the route; come back for the little trap after you have grown.", [
			r("shells", "Twin shells", 1, 0, [7], {"shields": 2}), r("chest", "Glass chest", 2, 0, [1], {"trap": 8, "treasure": true, "requires": ["shells"]}),
			r("first", "Deep glass", 1, 1, [12], {"trap": 50, "requires": ["shells"]}), r("second", "High glass", 2, 1, [25], {"trap": 70, "requires": ["first"]}),
			r("sun", "Twin lens", 1, 2, [32], {"multiplier": 2, "requires": ["second"]}), r("light", "Twin lantern", 2, 2, [160], {"requires": ["sun"], "rescue": true})]),
		puzzle("glass_09", "The glass meridian", 2, 18, 7, "Finale: save both shells, spend them on the trapped keepers, then enter the sun.", [
			r("shells", "Meridian shells", 1, 0, [8], {"shields": 2}), r("waste", "Glittering stair", 2, 0, [1], {"trap": 1, "requires": ["shells"]}),
			r("west", "West keeper", 1, 1, [16], {"trap": 70, "requires": ["shells"], "keeper": true, "keys": 1}), r("east", "East keeper", 2, 1, [28], {"trap": 90, "requires": ["west"], "keeper": true}),
			r("sun", "Meridian lens", 1, 2, [40], {"multiplier": 2, "requires": ["east"]}), r("door", "Meridian lock", 2, 2, [160], {"key_cost": 1, "requires": ["sun"]}),
			r("light", "Glass meridian", 2, 3, [300], {"requires": ["west", "east", "door"], "rescue": true})], true),
		puzzle("meridian_01", "Leave the keeper awake", 3, 15, 6, "Rescue before sealing. Carry the keeper's shield through the glass, then let it go.", [
			r("keeper", "Sleeping keeper", 1, 0, [6], {"keeper": true, "shields": 1}), r("bridge", "Dawn bridge", 2, 0, [2], {"collapse": ["keeper"]}),
			r("trap", "Dawn glass", 1, 1, [16], {"trap": 60, "requires": ["bridge"]}), r("sun", "Dawn lens", 2, 1, [22], {"multiplier": 2, "requires": ["trap"]}),
			r("pair", "Dawn duet", 1, 2, [80, 150], {"requires": ["sun"]}), r("light", "Dawn lantern", 2, 2, [280], {"requires": ["keeper", "pair"], "rescue": true})]),
		puzzle("meridian_02", "Two keys, one shell", 3, 20, 6, "The vault's two keys are for two doors. The small chest can wait.", [
			r("vault", "Two-key vault", 1, 0, [9], {"keys": 2}), r("shell", "Lock shell", 2, 0, [6], {"shields": 1}),
			r("chest", "Little lock", 2, 1, [1], {"key_cost": 1, "requires": ["vault"], "treasure": true}), r("first", "First door", 1, 1, [24], {"trap": 60, "key_cost": 1, "requires": ["vault"]}),
			r("second", "Second door", 1, 2, [45], {"key_cost": 1, "requires": ["first"]}), r("pair", "Lock duet", 2, 2, [70, 120], {"requires": ["second"]}),
			r("spare", "Last spare", 1, 3, [80], {"keys": 1, "requires": ["second"]}), r("light", "Lock lantern", 2, 3, [240], {"requires": ["pair"], "rescue": true})]),
		puzzle("meridian_03", "The keeper's late gift", 3, 17, 6, "The lens must precede a shielded rescue. Read the gift before choosing your route.", [
			r("sun", "Before-noon lens", 1, 0, [7], {"multiplier": 2}), r("keeper", "Noon keeper", 2, 0, [3], {"keeper": true, "shields": 1, "keys": 1}),
			r("pair", "Noon duet", 1, 1, [30, 55], {"requires": ["sun"]}), r("trap", "Noon glass", 2, 1, [80], {"requires": ["pair"], "trap": 180}),
			r("door", "Noon lock", 1, 2, [150], {"key_cost": 1, "requires": ["trap"]}), r("light", "Noon lantern", 2, 2, [300], {"requires": ["keeper", "door"], "rescue": true})]),
		puzzle("meridian_04", "Power is not a key", 3, 16, 6, "A brilliant ferry gains power and loses the key. Preserve both the keeper and the lock route.", [
			r("wrong", "Bright ferry", 1, 0, [1], {"multiplier": 2, "collapse": ["key"]}), r("key", "Keeper ferry", 2, 0, [10], {"keys": 1, "keeper": true, "collapse": ["wrong"]}),
			r("pair", "Ferry duet", 1, 1, [18, 35], {"requires": ["key"]}), r("door", "Ferry lock", 2, 1, [60], {"key_cost": 1, "requires": ["pair"]}),
			r("sun", "Late lens", 1, 2, [90], {"multiplier": 2, "requires": ["door"]}), r("light", "Ferry lantern", 2, 2, [400], {"requires": ["key", "sun"], "rescue": true})]),
		puzzle("meridian_05", "The shell ledger", 3, 18, 6, "A chest competes for the first shell. Recover enough power to visit it after the route.", [
			r("shells", "Ledger shells", 1, 0, [8], {"shields": 2}), r("chest", "Ledger chest", 2, 0, [1], {"trap": 10, "treasure": true, "requires": ["shells"]}),
			r("first", "Ledger glass", 1, 1, [16], {"trap": 80, "requires": ["shells"]}), r("keeper", "Ledger keeper", 2, 1, [30], {"trap": 100, "keeper": true, "keys": 1, "requires": ["first"]}),
			r("sun", "Ledger lens", 1, 2, [50], {"multiplier": 2, "requires": ["keeper"]}), r("door", "Ledger lock", 2, 2, [180], {"key_cost": 1, "requires": ["sun"]}),
			r("light", "Ledger lantern", 2, 3, [360], {"requires": ["door"], "rescue": true})]),
		puzzle("meridian_06", "The bridge remembers", 3, 20, 7, "Both keepers must leave their banks before the bridge closes. Their gifts pay the route.", [
			r("west", "West keeper", 1, 0, [6], {"keys": 1, "keeper": true}), r("east", "East keeper", 2, 0, [10], {"shields": 1, "keeper": true}),
			r("bridge", "Memory bridge", 1, 1, [18], {"collapse": ["west", "east"]}), r("trap", "Memory glass", 2, 1, [32], {"trap": 100, "requires": ["bridge"]}),
			r("sun", "Memory lens", 1, 2, [50], {"multiplier": 2, "requires": ["trap"]}), r("door", "Memory lock", 2, 2, [220], {"key_cost": 1, "requires": ["sun"]}),
			r("light", "Memory lantern", 2, 3, [440], {"requires": ["west", "east", "door"], "rescue": true})]),
		puzzle("meridian_07", "The long way home", 3, 22, 6, "A late chest costs a detour through the key exchange. Rescue can be faster; treasure can be richer.", [
			r("key", "Home key", 1, 0, [9], {"keys": 1}), r("door", "Home door", 1, 1, [24], {"requires": ["key"], "key_cost": 1}),
			r("refund", "Home exchange", 2, 1, [40], {"keys": 2, "requires": ["door"]}), r("chest", "Home chest", 2, 0, [1], {"key_cost": 1, "requires": ["key"], "treasure": true}),
			r("pair", "Home duet", 1, 2, [65, 110], {"requires": ["door"]}), r("keeper", "Home keeper", 2, 2, [180], {"keeper": true, "requires": ["pair"]}),
			r("light", "Home lantern", 2, 3, [350], {"requires": ["keeper"], "key_cost": 1, "rescue": true})]),
		puzzle("meridian_08", "Before the last tide", 3, 24, 7, "Two shells, one key, a rescued keeper and a sun that must wait. Read the whole tower.", [
			r("shells", "Last shells", 1, 0, [10], {"shields": 2}), r("keeper", "Tide keeper", 2, 0, [6], {"keys": 1, "keeper": true}),
			r("first", "Low tide glass", 1, 1, [24], {"trap": 100, "requires": ["shells"]}), r("second", "High tide glass", 2, 1, [40], {"trap": 130, "requires": ["first"]}),
			r("sun", "Tide lens", 1, 2, [60], {"multiplier": 2, "requires": ["second"]}), r("door", "Tide lock", 2, 2, [260], {"key_cost": 1, "requires": ["sun"]}),
			r("light", "Tide lantern", 2, 3, [500], {"requires": ["keeper", "door"], "rescue": true})]),
		puzzle("meridian_09", "All lanterns rise", 3, 25, 8, "Finale: rescue both keepers before sealing their rooms; spend both shells, then both keys. Bring the coast home.", [
			r("west", "West keeper", 1, 0, [8], {"keys": 1, "shields": 1, "keeper": true}), r("east", "East keeper", 2, 0, [12], {"keys": 1, "shields": 1, "keeper": true}),
			r("bridge", "Final bridge", 1, 1, [22], {"collapse": ["west", "east"]}), r("first", "First seal", 2, 1, [40], {"key_cost": 1, "trap": 150, "requires": ["bridge"]}),
			r("second", "Second seal", 1, 2, [70], {"key_cost": 1, "trap": 200, "requires": ["first"]}), r("sun", "Last lens", 2, 2, [100], {"multiplier": 2, "requires": ["second"]}),
			r("pair", "Last duet", 1, 3, [300, 500], {"requires": ["sun"]}), r("light", "Coast lantern", 2, 3, [1000], {"requires": ["west", "east", "pair"], "rescue": true})], true)
	]
