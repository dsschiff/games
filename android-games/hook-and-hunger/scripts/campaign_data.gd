extends RefCounted
## Definition1 is immutable: active saves carry this complete combat snapshot.
const WEAPONS := [
	{"name": "RUST ANCHOR", "power": 100, "damage": 12.0, "reach": 2.5, "period": 0.8, "cleave": 0.1, "color": "f4b579"},
	{"name": "TIDECUTTER", "power": 200, "damage": 32.0, "reach": 3.6, "period": 0.67, "cleave": 1.1, "color": "7ef3cd"},
	{"name": "FURNACE FLAIL", "power": 300, "damage": 58.0, "reach": 3.35, "period": 0.88, "cleave": 1.85, "color": "ffb47a"},
	{"name": "STORM CHAIN", "power": 400, "damage": 78.0, "reach": 3.85, "period": 0.62, "cleave": 1.3, "color": "b4a4fa"}
]
const COSTS := [36, 120, 240]
const LAYOUTS := [
	[Vector3(-3.8, -1, 1.0), Vector3(3.8, -6, 1.0)],
	[Vector3(-2.7, -4, 1.0), Vector3(2.7, -4, 1.0)],
	[Vector3(0, -2.5, 1.2), Vector3(-4.2, -7, 0.85), Vector3(4.2, -7, 0.85)]
]
const ARENA_WEAPONS := [
	WEAPONS[0],
	{"name": "TIDECUTTER REFIT", "power": 400, "damage": 64.0, "reach": 4.6, "period": 0.67, "cleave": 0.4, "color": "7ef3cd"},
	{"name": "FURNACE REFIT", "power": 400, "damage": 115.0, "reach": 3.2, "period": 0.95, "cleave": 2.3, "color": "ffb47a"},
	{"name": "STORM CHAIN", "power": 400, "damage": 78.0, "reach": 3.85, "period": 0.62, "cleave": 1.3, "color": "b4a4fa"}
]
const TITLES := ["Buoy Channel", "Broken Causeway", "Saltglass Beacon", "Kiln Landing", "Crabworks", "Cinder Beacon", "Lantern Sound", "Split Hulls", "Wreck Beacon", "Crown Approach", "Crystal Choir", "Glasswater Crown"]
const ISLANDS := ["SALTGLASS", "CINDER REEF", "LANTERN WRECKS", "GLASSWATER"]
const LESSONS := [
	"Bait the lancer's line, then step sideways.", "A spitter aims where you stood. Let rock catch the shot.", "Warden rings: step IN. Solid circles: step OUT.",
	"Forge the Furnace Flail. More power and cleave; slower recovery.", "Shield faces block strikes. Bait a swing, then flank during recovery.", "The Kiln guards its front. Move behind its shell between attacks.",
	"Forge the Storm Chain. Reach and recovery both improve.", "Tenders mend nearby allies. Approach the violet tender first.", "The twin lanterns mix charges and shots. Separate their approaches.",
	"A charger commits to a line. Sidestep and attack its recovery.", "Choir tenders sustain shields. Break the support chain first.", "The Crown changes pattern: ring, line, then burst. Read the ground."
]
const STATS := {
	"skitter": {"hp": 3.0, "speed": 1.9, "range": 1.25, "damage": 13.0, "wind": 0.65, "recovery": 1.4},
	"lancer": {"hp": 4.0, "speed": 1.1, "range": 4.4, "damage": 22.0, "wind": 1.1, "recovery": 1.9},
	"spitter": {"hp": 3.0, "speed": 1.15, "range": 7.5, "damage": 18.0, "wind": 0.9, "recovery": 2.1},
	"shield": {"hp": 5.0, "speed": 1.0, "range": 3.2, "damage": 24.0, "wind": 1.05, "recovery": 2.8},
	"charger": {"hp": 4.0, "speed": 1.4, "range": 7.0, "damage": 27.0, "wind": 1.0, "recovery": 2.5},
	"tender": {"hp": 3.0, "speed": 0.7, "range": 6.0, "damage": 12.0, "wind": 1.15, "recovery": 2.2},
	"warden": {"hp": 32.0, "speed": 1.2, "range": 7.5, "damage": 32.0, "wind": 1.3, "recovery": 2.0},
	"kiln": {"hp": 35.0, "speed": 0.9, "range": 7.5, "damage": 36.0, "wind": 1.4, "recovery": 2.8},
	"twin_sun": {"hp": 21.0, "speed": 1.2, "range": 7.5, "damage": 28.0, "wind": 1.15, "recovery": 2.2},
	"twin_moon": {"hp": 21.0, "speed": 1.5, "range": 7.5, "damage": 28.0, "wind": 1.0, "recovery": 2.4},
	"crown": {"hp": 48.0, "speed": 1.25, "range": 8.5, "damage": 36.0, "wind": 1.25, "recovery": 1.8}
}

static func definition(stage: int, seed: int = 1701, arena: bool = false, loadout: int = 3) -> Dictionary:
	var island := mini(3, stage / 3)
	var tier := 1 if stage < 3 else (2 if stage < 6 else 3)
	if arena:
		tier = 3
	var d := {"version": 1, "stage": stage, "seed": seed, "arena": arena, "title": TITLES[stage], "island": ISLANDS[island], "lesson": LESSONS[stage], "weapons": WEAPONS.duplicate(true), "costs": COSTS.duplicate(), "required_tier": tier, "offer": tier if stage in [3, 6] and not arena else 0, "waves": 6, "roster": [], "obstacles": [], "color": ["7d9690", "a67b68", "758b9e", "738c9c"][island]}
	if stage == 0:
		d.waves = 4
	if arena:
		d.waves = 3
		d.required_tier = 1
		d.weapons = ARENA_WEAPONS.duplicate(true)
		d.title = "Seeded arena " + str(seed)
		d.lesson = "Same seed, different weapon: compare hits, time and recoveries."
	for b in LAYOUTS[(stage + seed) % 3]:
		d.obstacles.append({"x": b.x, "z": b.y, "radius": b.z})
	var unlocked: Array = ["skitter", "lancer"]
	if stage >= 1:
		unlocked.append("spitter")
	if stage >= 3:
		unlocked.append("shield")
	if stage >= 6:
		unlocked.append("tender")
	if stage >= 7:
		unlocked.append("charger")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + stage * 997
	for wave in int(d.waves):
		var count := 7 + (wave % 3) + (1 if stage > 5 else 0)
		if stage == 0:
			count = 6 + wave % 2
		for i in count:
			var role: String = str(unlocked[(i + wave + stage) % unlocked.size()])
			if stage in [4, 10] and i < 2:
				role = "shield"
			if stage in [7, 10] and i == count - 1:
				role = "tender"
			var angle := float(i) / count * TAU + rng.randf_range(-0.18, 0.18)
			var at := Vector2(cos(angle) * (4.5 if i % 2 == 0 else 3.0), -3.6 + sin(angle) * 5.4)
			_add(d, role, wave, at, tier, false)
		if wave == int(d.waves) - 1 and stage % 3 == 2:
			if island == 2:
				_add(d, "twin_sun", wave, Vector2(-2.5, -8.8), tier, true)
				_add(d, "twin_moon", wave, Vector2(2.5, -8.8), tier, true)
			else:
				_add(d, ["warden", "kiln", "twin_sun", "crown"][island], wave, Vector2(0, -9.2), tier, true)
	return d

static func _add(d: Dictionary, role: String, wave: int, at: Vector2, tier: int, boss: bool) -> void:
	var stats: Dictionary = STATS[role].duplicate(true)
	var damage: float = WEAPONS[tier].damage
	stats.hp *= damage
	stats.merge({"id": d.roster.size(), "role": role, "wave": wave, "x": at.x, "z": at.y, "reward": 20 if boss else (6 if role == "skitter" else 9), "boss": boss, "pen": 0})
	d.roster.append(stats)

static func valid(d: Variant) -> bool:
	if not d is Dictionary or d.get("version") != 1 or not d.get("stage") is float and not d.get("stage") is int:
		return false
	if not number(d.get("stage"), 0, 11, true) or not number(d.get("seed"), 1, 999999, true) or not d.get("arena") is bool or not d.get("title") is String or not d.get("island") in ISLANDS or not d.get("lesson") is String or not d.get("color") is String:
		return false
	if not number(d.get("required_tier"), 1, 3, true) or not number(d.get("offer"), 0, 3, true) or not number(d.get("waves"), 1, 8, true) or not d.get("roster") is Array or d.roster.size() > 100 or not d.get("obstacles") is Array or d.obstacles.size() > 8:
		return false
	var expected_tier := 1 if d.stage < 3 else (2 if d.stage < 6 else 3)
	if d.required_tier != (1 if d.arena else expected_tier) or d.offer != (expected_tier if int(d.stage) in [3, 6] and not d.arena else 0) or d.waves != (3 if d.arena else (4 if d.stage == 0 else 6)):
		return false
	if not d.get("weapons") is Array or d.weapons.size() != 4 or not d.get("costs") is Array or d.costs.size() != 3:
		return false
	var expected: Array = ARENA_WEAPONS if d.arena else WEAPONS
	for i in expected.size():
		if not d.weapons[i] is Dictionary or d.weapons[i].size() != expected[i].size():
			return false
		for key in expected[i]:
			if d.weapons[i].get(key) != expected[i][key]:
				return false
	for i in COSTS.size():
		if not number(d.costs[i], COSTS[i], COSTS[i], true):
			return false
	for b in d.obstacles:
		if not b is Dictionary or not number(b.get("x"), -4.5, 4.5) or not number(b.get("z"), -9, 1) or not number(b.get("radius"), 0.5, 1.3):
			return false
	var layout: Array = LAYOUTS[(int(d.stage) + int(d.seed)) % 3]
	if d.obstacles.size() != layout.size():
		return false
	for i in layout.size():
		if absf(float(d.obstacles[i].x) - layout[i].x) > 0.0001 or absf(float(d.obstacles[i].z) - layout[i].y) > 0.0001 or absf(float(d.obstacles[i].radius) - layout[i].z) > 0.0001:
			return false
	var wave_counts := {}
	for i in d.roster.size():
		var e: Variant = d.roster[i]
		if not e is Dictionary or not number(e.get("id"), i, i, true) or not e.get("role") in STATS or not e.get("boss") is bool or not number(e.get("wave"), 0, d.waves - 1, true) or not number(e.get("x"), -5.3, 5.3) or not number(e.get("z"), -11.5, 2.5):
			return false
		for field in ["hp", "speed", "range", "damage", "wind", "recovery", "reward"]:
			if not number(e.get(field), 0.1, 10000):
				return false
		var tier: int = 3 if d.arena else (1 if d.stage < 3 else (2 if d.stage < 6 else 3))
		for field in ["hp", "speed", "range", "damage", "wind", "recovery"]:
			var expected_value: float = float(STATS[e.role][field]) * (float(WEAPONS[tier].damage) if field == "hp" else 1.0)
			if float(e[field]) != expected_value:
				return false
		if e.reward != (20 if e.boss else (6 if e.role == "skitter" else 9)):
			return false
		wave_counts[int(e.wave)] = true
	return wave_counts.size() == int(d.waves)

static func number(v: Variant, lo: float, hi: float, whole: bool = false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v >= lo and v <= hi and (not whole or float(v) == int(v))
