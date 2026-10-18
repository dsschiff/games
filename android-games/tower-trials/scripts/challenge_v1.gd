extends RefCounted
## Versioned deterministic grammars. Active runs always use their saved snapshot.
const Rules = preload("res://scripts/rules.gd")
const Rooms = preload("res://scripts/catalog_v1.gd")
const VERSION := 1
const FAMILIES := ["key", "shell", "rescue", "finale"]
const MAX_ATTEMPTS := 4
const MAX_VISITS := 1024
const MAX_QUEUE := 4096
const MAX_RECORDS := 256
static var verified: Dictionary = {}
static var generation_calls := 0

static func options_valid(options: Variant) -> bool:
	return options is Dictionary and options.size() == 2 and options.has("weave") and options.has("treasure") and whole(options.weave, 0, 3) and options.treasure is bool

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == int(value) and int(value) >= low and int(value) <= high

static func identity(family: String, seed_value: int, options: Dictionary) -> String:
	return "challenge_v1_%s_%d_%d_%d" % [family, seed_value, int(options.weave), 1 if options.treasure else 0]

static func room(id: String, enemies: Array, extra: Dictionary = {}) -> Dictionary:
	return Rooms.room(id, {"wrong": "Quick ferry", "light": "Lantern keeper"}.get(id, id.replace("_", " ").capitalize()), 1, 0, enemies, extra)

static func search(level: Dictionary, start: Dictionary = {}, treasure: bool = false, budget: int = MAX_VISITS) -> Dictionary:
	var queue: Array = [{"state": Rules.initial(level) if start.is_empty() else start, "route": []}]
	var seen: Dictionary = {}
	var cursor := 0
	while cursor < queue.size() and cursor < mini(MAX_VISITS, maxi(0, budget)):
		var node: Dictionary = queue[cursor]
		cursor += 1
		if node.state.status == "won" and (not treasure or node.state.treasure > 0):
			return {"ok": true, "route": node.route, "visited": cursor, "exhausted": false}
		var key := Rules.signature(node.state)
		if seen.has(key): continue
		seen[key] = true
		for candidate in level.rooms:
			var result := Rules.step(level, node.state, candidate.id)
			if result.ok and result.state.status != "lost":
				if queue.size() >= MAX_QUEUE:
					return {"ok": false, "route": [], "visited": cursor, "exhausted": true}
				queue.append({"state": result.state, "route": node.route + [candidate.id]})
	return {"ok": false, "route": [], "visited": cursor, "exhausted": cursor < queue.size()}

static func grammar(family: String, variant: int, treasure: bool) -> Dictionary:
	var rooms: Array = []
	var bad: Array = []
	var power := 8
	if family == "key":
		rooms = [room("key", [6], {"keys": 1}), room("wrong", [1], {"collapse": ["key"]}), room("door", [10], {"key_cost": 1, "requires": ["key"]}), room("light", [20], {"requires": ["door"], "rescue": true})]
		bad = ["wrong"]
		if variant == 1:
			rooms.append(room("landing", [3]))
			rooms[0].requires = ["landing"]
			rooms[2].enemies = [10, 4]
			bad = ["wrong", "landing"]
		elif variant == 2:
			rooms[2].keys = 2
			rooms[2].enemies = [10, 18]
			rooms.append(room("upper_lock", [16], {"requires": ["door"], "key_cost": 1}))
			rooms[3].requires = ["upper_lock"]
			rooms[3].key_cost = 1
		elif variant == 3:
			rooms.append(room("exchange", [9], {"requires": ["key"], "key_cost": 1, "keys": 3}))
			rooms[2].requires = ["exchange"]
			rooms[3].key_cost = 1
		if treasure:
			rooms.append(room("chest", [1], {"requires": ["key"] if variant == 3 else ["door"], "key_cost": 1 if variant == 3 else 0, "treasure": true}))
	elif family == "shell":
		power = 10
		rooms = [room("shell", [3], {"shields": 1, "collapse": ["sun"]}), room("sun", [2], {"multiplier": 2, "collapse": ["shell"]}), room("glass", [11, 22], {"trap": 30}), room("light", [45], {"requires": ["glass"], "rescue": true})]
		bad = ["sun", "glass"]
		if variant == 1:
			rooms[0].shields = 2
			rooms[2].enemies = [8]
			rooms[2].requires = ["shell"]
			rooms.append(room("high_glass", [16], {"trap": 50, "requires": ["glass"]}))
			rooms[3].requires = ["high_glass"]
			rooms[3].enemies = [36]
			bad = ["sun"]
		elif variant == 2:
			rooms[2].keys = 1
			rooms.append(room("late_lens", [7], {"requires": ["glass"], "multiplier": 2}))
			rooms[3].requires = ["late_lens"]
			rooms[3].key_cost = 1
			rooms[3].enemies = [90]
		elif variant == 3:
			rooms = [room("lens", [2], {"multiplier": 2}), room("gift", [3], {"keeper": true, "shields": 1}), room("glass", [18, 30], {"trap": 40, "requires": ["lens"]}), room("light", [60], {"requires": ["gift", "glass"], "rescue": true})]
			rooms.append(room("chime", [1], {"requires": ["gift"]}))
			bad = ["gift", "chime"]
		if treasure:
			rooms.append(room("chest", [1], {"requires": ["high_glass"] if variant == 1 else ["glass"], "treasure": true}))
	elif family == "rescue":
		rooms = [room("keeper", [2], {"keeper": true, "keys": 1}), room("bridge", [1], {"collapse": ["keeper"]}), room("door", [6], {"key_cost": 1, "requires": ["bridge"]}), room("light", [14], {"requires": ["keeper", "door"], "rescue": true})]
		bad = ["bridge"]
		if variant == 1:
			rooms.append(room("sibling", [3], {"keeper": true, "shields": 1}))
			rooms[1].collapse.append("sibling")
			rooms[2].trap = 30
			rooms[3].requires.append("sibling")
		elif variant == 2:
			rooms.append(room("balcony", [3], {"requires": ["keeper"]}))
			rooms[1].collapse.append("balcony")
			rooms[3].requires.append("balcony")
		elif variant == 3:
			rooms.append(room("sibling", [3], {"keeper": true, "keys": 1}))
			rooms.append(room("east_bridge", [4], {"collapse": ["sibling"]}))
			rooms[2].requires.append("east_bridge")
			rooms[2].key_cost = 2
			rooms[3].requires.append("sibling")
			rooms[3].enemies = [24]
			bad = ["bridge", "sibling", "east_bridge"]
		if treasure:
			rooms.append(room("chest", [1], {"requires": ["keeper"] if variant == 2 else ["door"], "treasure": true}))
			if variant == 2: rooms[1].collapse.append("chest")
	elif family == "finale":
		power = 12
		rooms = [room("west", [4], {"keeper": true, "keys": 1, "shields": 1}), room("east", [6], {"keeper": true, "keys": 1, "shields": 1}), room("bridge", [2], {"collapse": ["west", "east"]}), room("first_seal", [15, 25], {"requires": ["bridge"], "key_cost": 1, "trap": 40}), room("second_seal", [40], {"requires": ["first_seal"], "key_cost": 1, "trap": 100}), room("lens", [30], {"requires": ["second_seal"], "multiplier": 2}), room("light", [200], {"requires": ["west", "east", "lens"], "rescue": true})]
		bad = ["bridge"]
		if variant == 1:
			rooms[3].enemies = [15]
			rooms[4].enemies = [25, 50]
		elif variant == 2:
			rooms[0].keys = 2
			rooms[0].shields = 0
			rooms[1].keys = 0
			rooms[1].shields = 2
		elif variant == 3:
			rooms[5].enemies = [2]
			rooms[5].requires = []
			rooms[3].enemies = [25, 15]
			rooms[6].requires = ["west", "east", "second_seal", "lens"]
			rooms[6].enemies = [110]
			bad = ["bridge", "lens"]
		if treasure:
			rooms.append(room("chest", [1], {"requires": [] if variant == 0 else ["second_seal"], "treasure": true}))
			if variant == 0: bad = ["bridge", "chest"]
	return {"power": power, "rooms": rooms, "bad_route": bad}

static func candidate(family: String, seed_value: int, options: Dictionary, attempt: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + FAMILIES.find(family) * 7919 + attempt * 104729
	var variant := (seed_value % 4 + int(options.weave) + attempt) % 4
	var built := grammar(family, variant, options.treasure)
	var factor := rng.randi_range(1, 3)
	var cells: Array = range(8)
	for i in range(7, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	for i in built.rooms.size():
		var value: Dictionary = built.rooms[i]
		value.column = int(cells[i]) % 2 + 1
		value.floor = int(cells[i]) / 2
		value.enemies = value.enemies.map(func(enemy): return int(enemy) * factor)
		value.trap *= factor
	var title: String = ["Borrowed keys", "Glass and sunlight", "Keepers at the fork", "The woven seals"][FAMILIES.find(family)]
	var level := {"id": identity(family, seed_value, options), "name": title, "chapter": 0, "power": built.power * factor, "par": 8, "lesson": "Read all gifts, locks and sealed routes. Tap a forecast for every step. Retry keeps this exact puzzle.", "story": "A new watch, the same visible rules.", "rooms": built.rooms, "rules": 2, "finale": false}
	var win := search(level)
	var medal := search(level, {}, options.treasure)
	if not win.ok or not medal.ok:
		return {}
	level.par = win.route.size()
	return {"version": VERSION, "family": family, "seed": seed_value, "options": options.duplicate(true), "snapshot": level, "witness": win.route, "medal_witness": medal.route, "bad_route": built.bad_route, "fallback": false}

static func generate(family: String, seed_value: int, options: Dictionary, attempts: int = MAX_ATTEMPTS) -> Dictionary:
	generation_calls += 1
	if not family in FAMILIES or not whole(seed_value, 0, 2147483647) or not options_valid(options):
		return {"ok": false, "message": "Choose a supported family, seed and options"}
	for attempt in mini(MAX_ATTEMPTS, maxi(0, attempts)):
		var bundle := candidate(family, seed_value, options, attempt)
		if not bundle.is_empty() and validate(bundle).ok:
			return {"ok": true, "bundle": bundle, "attempts": attempt + 1}
	# The fixed grammar is independently tested for all four fallback families.
	var fallback := candidate(family, 0, {"weave": 0, "treasure": true}, 0)
	if fallback.is_empty(): return {"ok": false, "message": "Verified fallback unavailable"}
	fallback.seed = seed_value
	fallback.options = options.duplicate(true)
	fallback.snapshot.id = identity(family, seed_value, options)
	fallback.fallback = true
	if not options.treasure:
		for value in fallback.snapshot.rooms: value.treasure = false
		fallback.medal_witness = fallback.witness.duplicate()
	var checked := validate(fallback)
	return {"ok": checked.ok, "bundle": fallback, "attempts": mini(MAX_ATTEMPTS, maxi(0, attempts)), "message": "Verified fallback used" if checked.ok else "No verified puzzle available"}

static func printable(value: Variant, limit: int) -> bool:
	return value is String and not value.is_empty() and value.length() <= limit and not RegEx.create_from_string("[\\x00-\\x1f\\x7f]").search(value)

static func route_state(level: Dictionary, route: Variant) -> Dictionary:
	if not route is Array or route.size() < 1 or route.size() > 8: return {}
	var state := Rules.initial(level)
	for id in route:
		if not id is String: return {}
		var result := Rules.step(level, state, id)
		if not result.ok: return {}
		state = result.state
	return state

static func validate(bundle: Variant) -> Dictionary:
	var no := {"ok": false, "message": "Invalid generated puzzle snapshot"}
	if not bundle is Dictionary or bundle.size() != 9: return no
	for key in ["version", "family", "seed", "options", "snapshot", "witness", "medal_witness", "bad_route", "fallback"]:
		if not bundle.has(key): return no
	if not whole(bundle.version, 1, 1) or not bundle.family is String or not bundle.family in FAMILIES or not whole(bundle.seed, 0, 2147483647) or not options_valid(bundle.options) or not bundle.fallback is bool: return no
	if not bundle.snapshot is Dictionary: return no
	var level: Dictionary = bundle.snapshot
	var fields := ["id", "name", "chapter", "power", "par", "lesson", "story", "rooms", "rules", "finale"]
	if level.size() != fields.size(): return no
	for field in fields:
		if not level.has(field): return no
	if level.id != identity(bundle.family, int(bundle.seed), bundle.options) or not printable(level.name, 48) or not printable(level.lesson, 240) or not printable(level.story, 240): return no
	if not whole(level.chapter, 0, 0) or not whole(level.power, 1, 100) or not whole(level.par, 1, 8) or not whole(level.rules, 2, 2) or not level.finale is bool or level.finale: return no
	if not level.rooms is Array or level.rooms.size() < 4 or level.rooms.size() > 8: return no
	var ids: Array = []
	var cells: Array = []
	var goal: Dictionary = {}
	var lenses := 0
	var treasures := 0
	for value in level.rooms:
		if not value is Dictionary: return no
		var required := ["id", "name", "column", "floor", "enemies", "requires", "key_cost", "keys", "shields", "trap", "multiplier", "collapse", "treasure", "rescue"]
		for key in required:
			if not value.has(key): return no
		for key in value:
			if not key in required and not key in ["keeper", "requires_any"]: return no
		if not value.id is String or not RegEx.create_from_string("^[a-z][a-z0-9_]{0,23}$").search(value.id) or value.id in ids or not printable(value.name, 32): return no
		ids.append(value.id)
		for key in ["column", "floor", "key_cost", "keys", "shields", "trap", "multiplier"]:
			var bounds: Array = {"column": [1, 2], "floor": [0, 3], "key_cost": [0, 3], "keys": [0, 3], "shields": [0, 2], "trap": [0, 500], "multiplier": [1, 2]}[key]
			if not whole(value[key], bounds[0], bounds[1]): return no
			value[key] = int(value[key])
		var cell := int(value.column) * 10 + int(value.floor)
		if cell in cells: return no
		cells.append(cell)
		if not value.enemies is Array or value.enemies.size() < 1 or value.enemies.size() > 2: return no
		for i in value.enemies.size():
			if not whole(value.enemies[i], 1, 1000): return no
			value.enemies[i] = int(value.enemies[i])
		if not value.treasure is bool or not value.rescue is bool or not value.get("keeper", false) is bool: return no
		if value.rescue:
			if not goal.is_empty() or value.treasure: return no
			goal = value
		treasures += 1 if value.treasure else 0
		lenses += 1 if value.multiplier == 2 else 0
	if goal.is_empty() or lenses > 2 or treasures != (1 if bundle.options.treasure else 0): return no
	for value in level.rooms:
		for key in ["requires", "collapse", "requires_any"]:
			var refs: Variant = value.get(key, [])
			if not refs is Array or refs.size() > 8: return no
			var seen: Array = []
			for id in refs:
				if not id is String or not id in ids or id == value.id or id in seen: return no
				seen.append(id)
		if value.get("keeper", false) and not value.id in goal.requires: return no
	for key in ["chapter", "power", "par", "rules"]: level[key] = int(level[key])
	bundle.version = int(bundle.version)
	bundle.seed = int(bundle.seed)
	bundle.options.weave = int(bundle.options.weave)
	for field in ["witness", "medal_witness", "bad_route"]:
		if not bundle[field] is Array or bundle[field].size() < 1 or bundle[field].size() > 8: return no
		for id in bundle[field]:
			if not id is String or not id in ids: return no
	var digest := JSON.stringify(bundle, "", true, true).sha256_text()
	if verified.has(digest): return {"ok": true, "key": digest, "cached": true}
	var win := route_state(level, bundle.witness)
	var medal := route_state(level, bundle.medal_witness)
	var loss := route_state(level, bundle.bad_route)
	if win.is_empty() or win.status != "won" or win.moves != level.par or medal.is_empty() or medal.status != "won" or (bundle.options.treasure and medal.treasure < 1) or loss.is_empty() or loss.status != "lost": return no
	var first := Rules.find_room(level, str(bundle.bad_route[0]))
	if first.is_empty() or first.trap != 0: return no
	var power: int = level.power
	for enemy in first.enemies:
		if power <= int(enemy): return no
		power += int(enemy)
	var committed := Rules.step(level, Rules.initial(level), first.id)
	var continuation := search(level, committed.state)
	var solved := search(level)
	if continuation.ok or continuation.exhausted or not solved.ok or solved.route.size() != level.par: return no
	if verified.size() >= 64: verified.clear()
	verified[digest] = true
	return {"ok": true, "key": digest, "cached": false}
