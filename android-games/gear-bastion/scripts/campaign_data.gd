class_name CampaignData
extends RefCounted
## Authoritative content is copied into each active run, never read mid-battle.
const CONTENT_VERSION := 1
const IDS := ["camp_01", "camp_02", "camp_03", "camp_04", "camp_05", "camp_06", "camp_07", "camp_08", "camp_09"]
const NAMES := ["First Spark", "Glass Arrows", "The Forked Wall", "Hammer Chorus", "Broken Lattice", "The Cinder Engine", "Three Fronts", "Furnace Tide", "Heart of the Foundry"]
const DECISIONS := [
	"Connect a working foundry; place adjacent drives without breaking the path.",
	"Guards screen the spitter fire; rangers cut through shells.",
	"Cover both exits before the shell captain arrives with escorts.",
	"Mortars clear dense packs, but need guards against the ranged screen.",
	"Bridge the broken board; choose concentrated splash or dispersed arrows.",
	"Sustain the front to interrupt siege volleys while escorts press the flanks.",
	"Enemy pressure changes exits. Reallocate future troops before each shift.",
	"Spend wave salvage on the weakness your last wave exposed.",
	"Keep a mixed army through the matriarch's escorts, siege and final charge."]

static func wave(name: String, count: int, interval: float, pattern: Array, lanes: Array = [0, 1, 2], pack: int = 2, grant: int = 0) -> Dictionary:
	return {"name": name, "count": count, "interval": interval, "pattern": pattern, "lanes": lanes, "pack": pack, "grant": grant}

static func sockets(shape: String) -> Array:
	var result: Array = []
	for y in 4:
		for x in 5:
			if shape == "cross" and not (y == 2 or x == 2 or (y in [1, 3] and x in [1, 3])):
				continue
			if shape == "broken" and Vector2i(x, y) in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(2, 1), Vector2i(0, 3), Vector2i(4, 3)]:
				continue
			if shape == "ring" and Vector2i(x, y) in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0), Vector2i(0, 3), Vector2i(4, 3)]:
				continue
			result.append([x, y])
	return result

static func definition(id: String) -> Dictionary:
	var index := IDS.find(id)
	if index < 0:
		return {}
	var config := {"id": id, "definition_version": CONTENT_VERSION, "rules_version": 1,
		"index": index, "act": index / 3 + 1, "name": NAMES[index], "decision": DECISIONS[index],
		"sockets": sockets("full"), "core": [2, 2], "starter": [["drive", 2, 1, 1, 1]],
		"budget": 60, "allowed": ["guard", "ranger"], "wall": 220.0,
		"hp_scale": 1.0, "damage_scale": 1.0, "speed_scale": 1.0,
		"boss": "", "boss_hp": 0.0, "waves": [], "challenge": false, "seed_offset": 0}
	match index:
		0:
			config.allowed = ["guard"]
			config.budget = 30
			config.starter.append(["guard", 0, 2, 1, 0])
			config.waves = [wave("Quay scouts", 40, 1.8, ["beetle"], [0, 1, 2], 2), wave("Fast flanks", 48, 1.7, ["beetle", "skitter"], [0, 2], 2), wave("Shell vanguard", 42, 1.8, ["beetle", "shell", "skitter"], [0, 1, 2], 2)]
		1:
			config.budget = 58
			config.sockets = sockets("cross")
			config.waves = [wave("Screen the spitters", 48, 1.3, ["spitter", "beetle"], [0, 2], 2), wave("Iron approach", 72, 1.5, ["shell", "beetle"], [0, 1, 2], 2), wave("Crossfire", 68, 1.5, ["spitter", "skitter", "beetle"], [0, 2], 2), wave("Mixed column", 72, 1.5, ["shell", "beetle", "spitter"], [0, 1, 2], 2)]
		2:
			config.budget = 66
			config.sockets = sockets("ring")
			config.waves = [wave("Left embankment", 80, 1.4, ["beetle", "shell"], [0, 0, 1], 2), wave("Right crossfire", 80, 1.4, ["spitter", "beetle", "skitter"], [2, 2, 1], 2), wave("Captain's escort", 80, 1.4, ["shell", "spitter", "beetle"], [0, 1, 2], 2)]
			config.boss = "captain"
			config.boss_hp = 4200.0
		3:
			config.budget = 76
			config.allowed.append("mortar")
			config.waves = [wave("Packed raiders", 200, 1.2, ["swarm", "swarm", "beetle"], [1], 8), wave("Protect the guns", 76, 1.5, ["spitter", "beetle"], [0, 2], 2), wave("Hammer chorus", 160, 1.5, ["swarm", "beetle", "shell"], [0, 1, 2], 4), wave("Loose formation", 64, 1.5, ["spitter", "shell", "skitter"], [0, 2], 2)]
		4:
			config.allowed.append("mortar")
			config.budget = 82
			config.sockets = sockets("broken")
			config.starter = [["drive", 1, 2, 1, 0], ["drive", 3, 2, 1, 2]]
			config.waves = [wave("Broken crossing", 84, 1.4, ["spitter", "beetle"], [0, 2], 2), wave("Central crush", 120, 1.4, ["swarm", "shell"], [1], 3), wave("Open flanks", 84, 1.4, ["spitter", "skitter"], [0, 2], 2), wave("Rejoin the line", 100, 1.4, ["shell", "beetle", "spitter"], [0, 1, 2], 3)]
		5:
			config.allowed.append("mortar")
			config.budget = 86
			config.waves = [wave("Ash escort", 120, 1.4, ["swarm", "beetle", "shell"], [0, 1, 2], 3), wave("Hot crossfire", 84, 1.4, ["spitter", "shell"], [0, 2], 2), wave("Engine crew", 120, 1.4, ["beetle", "swarm", "spitter"], [0, 1, 2], 3)]
			config.boss = "siege"
			config.boss_hp = 6500.0
		6:
			config.allowed.append("mortar")
			config.budget = 84
			config.sockets = sockets("cross")
			config.waves = [wave("West alarm", 100, 1.5, ["beetle", "spitter", "shell"], [0], 3), wave("East alarm", 100, 1.5, ["spitter", "skitter", "beetle"], [2], 3), wave("Center swarm", 144, 1.5, ["swarm", "shell"], [1], 4), wave("Three fronts", 108, 1.5, ["shell", "spitter", "beetle"], [0, 1, 2], 3)]
		7:
			config.allowed.append("mortar")
			config.budget = 70
			config.sockets = sockets("ring")
			config.waves = [wave("Furnace mouth", 80, 1.2, ["beetle", "spitter"], [0, 2], 2, 6), wave("Spend the salvage", 120, 1.3, ["swarm", "shell"], [1], 3, 6), wave("Thin the screen", 80, 1.2, ["spitter", "shell"], [0, 2], 2, 6), wave("Hot tide", 144, 1.3, ["swarm", "beetle"], [0, 1, 2], 4, 6), wave("Last embers", 96, 1.2, ["shell", "spitter", "skitter"], [0, 1, 2], 3)]
		8:
			config.allowed.append("mortar")
			config.budget = 94
			config.waves = [wave("Citadel approach", 120, 1.4, ["beetle", "shell", "spitter"], [0, 1, 2], 3), wave("Gathering brood", 160, 1.5, ["swarm", "swarm", "shell"], [1], 4), wave("Split the guard", 108, 1.4, ["spitter", "skitter", "shell"], [0, 2], 3), wave("Hold the heart", 120, 1.4, ["shell", "spitter", "beetle"], [0, 1, 2], 3)]
			config.boss = "matriarch"
			config.boss_hp = 10000.0
	# Pressure rises through health and damage, not longer solved waits. These
	# values are provisional until exact-step policy/variant sweeps accept them.
	config.hp_scale = [1.0, 1.5, 1.65, 1.9, 2.0, 2.1, 2.2, 2.35, 2.5][index]
	config.damage_scale = [1.0, 1.2, 1.3, 1.35, 1.4, 1.5, 1.5, 1.6, 1.6][index]
	config["par_seconds"] = [135, 220, 205, 220, 245, 220, 240, 265, 300][index]
	if index > 0:
		config.waves[0]["hp_scale"] = minf(1.0, 1.5 / float(config.hp_scale))
		config.waves[0]["damage_scale"] = minf(1.0, 1.2 / float(config.damage_scale))
	return config

static func numeric(value: Variant, low: float, high: float, integer: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and (not integer or float(value) == int(value))

static func pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and numeric(value[0], 0, 4, true) and numeric(value[1], 0, 3, true)

static func valid_snapshot(config: Dictionary) -> bool:
	for key in ["id", "index", "definition_version", "rules_version", "name", "decision", "act", "budget", "allowed", "wall", "sockets", "core", "starter", "hp_scale", "damage_scale", "speed_scale", "boss", "boss_hp", "waves", "actor_stats", "generator_rates", "costs"]:
		if not config.has(key):
			return false
	if not config.id in IDS or not numeric(config.index, 0, 8, true) or int(config.index) != IDS.find(config.id) or not numeric(config.definition_version, 1, 1000, true) or not numeric(config.rules_version, 1, 1, true) or not config.waves is Array or config.waves.is_empty() or config.waves.size() > 8:
		return false
	if not config.name is String or config.name.length() > 80 or not config.decision is String or config.decision.length() > 200:
		return false
	if config.has("par_seconds") and not numeric(config.par_seconds, 1, 2000):
		return false
	if not numeric(config.act, 1, 3, true) or not numeric(config.budget, 0, 200, true) or not numeric(config.wall, 100, 500) or not numeric(config.hp_scale, 0.5, 5) or not numeric(config.damage_scale, 0.5, 3) or not numeric(config.speed_scale, 0.5, 2) or not numeric(config.boss_hp, 0, 30000):
		return false
	if not config.sockets is Array or config.sockets.is_empty() or config.sockets.size() > 20 or not config.allowed is Array or config.allowed.is_empty() or config.allowed.size() > 3 or not pair(config.core) or not config.starter is Array or config.starter.size() > 10:
		return false
	for role in config.allowed:
		if not role in ["guard", "ranger", "mortar"]:
			return false
	for cell in config.sockets:
		if not pair(cell):
			return false
	# Retry constructs this kit afresh, so its occupied cells must be valid too.
	var socket_keys: Dictionary = {}
	for cell in config.sockets:
		var key := "%d:%d" % [int(cell[0]), int(cell[1])]
		if socket_keys.has(key):
			return false
		socket_keys[key] = true
	var core_key := "%d:%d" % [int(config.core[0]), int(config.core[1])]
	if not socket_keys.has(core_key):
		return false
	var occupied := {core_key: true}
	for p in config.starter:
		if not p is Array or p.size() != 5 or not p[0] in ["drive", "guard", "ranger", "mortar"] or not numeric(p[1], 0, 4, true) or not numeric(p[2], 0, 3, true) or not numeric(p[3], 1, 4, true) or not numeric(p[4], 0, 2, true):
			return false
		var key := "%d:%d" % [int(p[1]), int(p[2])]
		if occupied.has(key) or not socket_keys.has(key) or (p[0] != "drive" and not p[0] in config.allowed):
			return false
		occupied[key] = true
	if not config.actor_stats is Dictionary or not config.generator_rates is Dictionary or not config.costs is Dictionary:
		return false
	for kind in ["guard", "ranger", "mortar", "beetle", "shell", "skitter", "spitter", "swarm", "carapace", "captain", "siege", "matriarch"]:
		if not config.actor_stats.has(kind) or not config.actor_stats[kind] is Dictionary:
			return false
		var actor: Dictionary = config.actor_stats[kind]
		for stat in ["hp", "damage", "reach", "speed", "period"]:
			if not actor.has(stat) or not numeric(actor[stat], 0.01, 30000 if stat == "hp" else 300):
				return false
	for role in ["guard", "ranger", "mortar"]:
		if not config.generator_rates.has(role) or not numeric(config.generator_rates[role], 0.1, 3):
			return false
	for role in ["drive", "guard", "ranger", "mortar"]:
		if not config.costs.has(role) or not numeric(config.costs[role], 1, 100, true):
			return false
	for item in config.waves:
		if not item is Dictionary:
			return false
		for key in ["name", "count", "interval", "pattern", "lanes", "pack", "grant"]:
			if not item.has(key):
				return false
		if not numeric(item.count, 1, 500, true) or not numeric(item.interval, 0.2, 5) or not numeric(item.pack, 1, 8, true) or not numeric(item.grant, 0, 24, true) or not item.name is String or not item.pattern is Array or item.pattern.is_empty() or item.pattern.size() > 12 or not item.lanes is Array or item.lanes.is_empty() or item.lanes.size() > 6:
			return false
		for scalar in ["hp_scale", "damage_scale"]:
			if item.has(scalar) and not numeric(item[scalar], 0.1, 3):
				return false
		for kind in item.pattern:
			if not kind in ["beetle", "shell", "skitter", "swarm", "spitter", "carapace"]:
				return false
			if float(config.actor_stats[kind].hp) * float(config.hp_scale) * float(item.get("hp_scale", 1.0)) > 30000:
				return false
		for lane in item.lanes:
			if not numeric(lane, 0, 2, true):
				return false
	# Boss escorts use the encounter multiplier without a wave modifier.
	for kind in ["beetle", "swarm", "skitter", "spitter"]:
		if float(config.actor_stats[kind].hp) * float(config.hp_scale) > 30000:
			return false
	return str(config.boss) in ["", "captain", "siege", "matriarch"] and (config.boss == "" or float(config.boss_hp) > 0)
