extends RefCounted
## Catalog2 / rule3 / generator2: the dense-horde campaign (0.4.0/code5).
## catalog1_data.gd keeps catalog1/rule2/generator1 byte-for-byte, so a road
## started before code5 keeps replaying under its original definition.
const Catalog1 = preload("res://scripts/catalog1_data.gd")
const CATALOG := 2
const VERSION := 3
const GENERATOR := 2
const CAP := 49
const LANES := [-2.65, 0.0, 2.65]
const WEAPONS := {
	"rivet": {"title": "RIVET", "period": 20, "damage": 1, "pierce": 1, "pellets": 1, "spread": 0.0, "range": 19.0, "hint": "Focused stream. Fastest gate conversion and boss damage; chase split packs."},
	"lance": {"title": "LANCE", "period": 40, "damage": 2, "pierce": 4, "pellets": 1, "spread": 0.0, "range": 21.0, "hint": "Bolts pierce four infected and ignore armor. Mows whole columns; slower gate conversion."},
	"fan": {"title": "FAN", "period": 34, "damage": 1, "pierce": 2, "pellets": 2, "spread": 0.034, "range": 16.0, "hint": "Twin spreading pellets each pass through two infected. Sweeps the whole road at range."}}
# Range: rounds fade past it, so a horde visibly closes in before it falls.
# Fodder dies in one or two hits; the tough roles stay rarer and readable.
const ROLES := {
	"drifter": {"hp": 2, "armor": 0, "speed": 2.0, "loss": 1, "width": 0.40},
	"runner": {"hp": 1, "armor": 0, "speed": 3.4, "loss": 1, "width": 0.32},
	"plated": {"hp": 6, "armor": 3, "speed": 1.8, "loss": 2, "width": 0.50},
	"spitter": {"hp": 5, "armor": 0, "speed": 1.65, "loss": 1, "width": 0.45},
	"cluster": {"hp": 1, "armor": 0, "speed": 2.2, "loss": 1, "width": 0.30},
	"bulwark": {"hp": 16, "armor": 5, "speed": 1.45, "loss": 3, "width": 0.65}}
const FODDER := ["drifter", "runner", "cluster"]
# Lateral offsets of pack members around their lane centre, in spawn order.
const SPREAD := [0.0, -0.42, 0.42, -0.84, 0.84, -0.21, 0.21, -0.63, 0.63, -1.05, 1.05, 0.1]
const DISTRICTS := Catalog1.DISTRICTS
const ROWS := Catalog1.ROWS

static func enemy(out: Array, born: int, x: float, role: String) -> void:
	var r: Dictionary = ROLES[role]
	out.append({"id": out.size(), "born": born, "x": x, "z": 25.0, "role": role, "hp": r.hp, "armor": r.armor, "speed": r.speed, "loss": r.loss, "width": r.width})

static func pack(out: Array, born: int, centre: float, role: String, count: int) -> void:
	# Rows of three march in together; a pack fills most of its lane.
	for j in count:
		enemy(out, born + (j / 3) * 16 + (j % 3) * 3, clampf(centre + SPREAD[j % SPREAD.size()], -3.7, 3.7), role)

static func roll(seed: int, salt: int, count: int) -> int:
	return Catalog1.roll(seed, salt, count)

static func stage(index: int, seed: int = 0) -> Dictionary:
	var row: Array = ROWS[index]
	var district := index / 6
	var pattern: int = row[2]
	var duration: int = row[1] * 60
	var flip := -1.0 if seed > 0 and seed % 2 == 1 else 1.0
	var boss := index % 6 == 5
	var boss_born := duration - (1800 if boss else 1020)
	var enemies: Array = []
	var tick := 240
	var wave := 0
	while tick < duration - 240:
		var lane := roll(seed, wave + 1, 3) if seed > 0 else (wave + pattern) % 3
		var x: float = LANES[lane] * flip
		var progress := float(tick) / duration
		# Ordinary packs grow through the road. A surge floods every lane in
		# the 14 seconds before the finale or blockade appears.
		var surge := tick >= boss_born - 840 and tick < boss_born
		var count := 3 + district + int(progress * 5.0) + (1 if wave % 2 == 0 else 0)
		if index == 0: count = mini(count, 2 + int(progress * 4.0))
		if surge: count += 4 + district * 2 + (3 if boss else 0)
		if boss and tick >= boss_born: count = maxi(2, count - 2)
		var role := "drifter"
		if pattern >= 3 and wave % 5 == 2: role = "runner"
		if district >= 1 and wave % 5 == 0: role = "plated"
		if district >= 1 and pattern % 3 == 2 and wave % 7 == 3: role = "spitter"
		if district >= 2 and wave % 8 == 5: role = "bulwark"
		if seed > 0: role = ["drifter", "runner", "plated", "spitter", "cluster", "bulwark"][roll(seed, wave + 200, 6)]
		var fodder: String = role if role in FODDER else ("runner" if pattern >= 3 and wave % 3 == 2 else "drifter")
		if (seed > 0 and roll(seed, wave + 400, 5) == 0) or (seed == 0 and (pattern % 6 == 4 or (district >= 2 and wave % 4 == 1))):
			fodder = "cluster"
			count += 2
		if role not in FODDER:
			# The tough role leads; its fodder escort fans out behind it.
			enemy(enemies, tick, x, role)
			pack(enemies, tick + 20, x, fodder, count - 1)
		else:
			pack(enemies, tick, x, fodder, count)
		if index >= 2 and wave % 2 == 1:
			var other: float = -x if absf(x) > 1 else LANES[(lane + 1) % 3] * flip
			pack(enemies, tick + 24, other, "runner" if pattern % 2 else "drifter", 2 + count / 2)
		if surge:
			pack(enemies, tick + 40, LANES[(lane + 2) % 3] * flip, "drifter" if wave % 2 else "cluster", 3 + count / 2)
		wave += 1
		tick += [110, 105, 100, 92][district] + ((wave + pattern) % 3) * 15 + (roll(seed, wave + 600, 25) - 12 if seed > 0 else 0)
	var gates: Array = []
	for i in range(5 if index > 0 else 4):
		var born := 1 if i == 0 else 60 + i * (duration - 1200) / 5
		var lane := 1 if i == 0 else (roll(seed, i + 800, 3) if seed > 0 else (i + pattern) % 3)
		# Gate 0 teaches; odd gates add crew; later even gates multiply it.
		# The opening road keeps a harmful third gate and multiplies at its fourth.
		var multiply := (i % 2 == 0 and i > 0) if index > 0 else i == 3
		if multiply:
			gates.append({"id": i, "born": born, "x": LANES[lane] * flip, "z": 22.0, "kind": "mul", "initial": 1, "cap": 2 if district < 2 else 3, "step": 40 + district * 15, "width": 0.85})
		else:
			var initial := -3 if i == 0 else -(8 + district * 3) - (4 if index == 0 and i == 2 else 0)
			gates.append({"id": i, "born": born, "x": LANES[lane] * flip, "z": 14.0 if i == 0 else 22.0, "kind": "add", "initial": initial, "cap": 8 if i == 0 else 10 + district * 2, "step": 1, "width": 0.85})
		if pattern % 6 == 1 and i in [1, 3]:
			gates.append({"id": gates.size(), "born": born, "x": -LANES[lane] * flip if lane != 1 else -2.65 * flip, "z": 22.0, "kind": "mul", "initial": 1, "cap": 2, "step": 50 + district * 15, "width": 0.85})
	# IDs are independent of optional paired-gate count.
	for i in gates.size(): gates[i].id = i
	var sides: Array = [{"id": 0, "born": 300, "until": duration - 540, "x": -2.65 * flip, "z": 13.5, "hp": 160 + district * 40, "reward": 6 + district, "kind": "pump" if district == 2 else "rig", "disables": 0 if district == 2 else -1}]
	if district >= 2 or pattern % 6 == 4:
		sides.append({"id": 1, "born": 1500, "until": duration - 360, "x": 2.65 * flip, "z": 12.0, "hp": 150 + district * 35, "reward": 6 + district, "kind": "pump" if pattern in [15, 21] else "rig", "disables": 1 if pattern in [15, 21] else -1})
	var obstacles: Array = []
	if pattern % 6 in [2, 5] or pattern in [7, 13, 19, 22]:
		for i in 4:
			obstacles.append({"id": i, "born": 1140 + i * (duration - 2100) / 4, "x": LANES[roll(seed, i + 900, 3) if seed > 0 else (i + pattern) % 3] * flip, "z": 25.0, "width": 0.8 if pattern % 6 == 2 else 1.1, "loss": 4 + district, "kind": "cart"})
	var floods: Array = []
	if district >= 2:
		for i in range(6 if district == 2 else 4):
			floods.append({"id": i, "mark": 1500 + i * (duration - 2040) / 6, "x": LANES[roll(seed, i + 1000, 3) if seed > 0 else (i + pattern) % 3] * flip, "width": 0.7, "loss": 3 + district, "pump": i % 2})
	return {"catalog": CATALOG, "rule_version": VERSION, "generator": GENERATOR, "index": index, "seed": seed, "replay": seed > 0, "title": row[0], "district": district,
		"hint": row[3], "duration": duration, "speed": 1.9, "initial_crew": 5, "cap": CAP, "spit_loss": 3, "boss_loss": 4 + district,
		"weapons": WEAPONS.duplicate(true), "roles": ROLES.duplicate(true),
		"enemies": enemies, "gates": gates, "sides": sides, "obstacles": obstacles, "floods": floods,
		"boss": {"kind": district + 1 if boss else 0, "title": row[0] if boss else "EVAC BLOCKADE", "born": boss_born, "hp": [520, 640, 720, 760][district] if boss else 300,
			"arms": 180 if index == 23 else 0, "x": 0.0, "z": 23.0}}

static func same(a: Variant, b: Variant) -> bool:
	return Catalog1.same(a, b)
