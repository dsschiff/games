extends RefCounted
const VERSION := 2
const IDS := ["ash_gate", "switchyard", "signal_ridge", "iron_drill", "broken_bridge", "glass_quarry", "night_relays", "brood_carrier", "red_causeway", "mortar_gardens", "last_supply", "foundry_liberation"]
const TITLES := ["Ash Gate", "Switchyard", "Signal Ridge", "The Iron Drill", "Broken Bridge", "Glass Quarry", "Night Relays", "The Brood Carrier", "Red Causeway", "Mortar Gardens", "Last Supply", "Foundry Liberation"]
const ROLES := ["rifle", "breaker", "ranger", "rover"]
const PADS := [Vector2(-3.2, 2.5), Vector2(-1.4, 4.7), Vector2(1.4, 4.7), Vector2(3.2, 2.5), Vector2(0, 2.8)]
const FORMATION := [Vector2(-3, -1.2), Vector2(-1, -1.8), Vector2(1, -1.8), Vector2(3, -1.2), Vector2(-2, -2.3), Vector2(2, -2.3)]
const UNIT := {
	"rifle": {"cost": 7, "hp": 60, "damage": 10, "interval": 0.52, "range": 4.6, "speed": 2.6, "armor": 0.32},
	"breaker": {"cost": 10, "hp": 76, "damage": 28, "interval": 0.95, "range": 4.9, "speed": 2.3, "armor": 1.0},
	"ranger": {"cost": 10, "hp": 44, "damage": 25, "interval": 1.0, "range": 7.4, "speed": 2.7, "armor": 0.40},
	"rover": {"cost": 18, "hp": 170, "damage": 25, "interval": 1.1, "range": 5.5, "speed": 1.9, "armor": 0.8}}
const ENEMY := {
	"drone": {"hp": 64, "speed": 0.52, "damage": 7, "range": 2.6, "interval": 1.0, "reward": 5, "leak": 26, "armor": false},
	"runner": {"hp": 50, "speed": 1.1, "damage": 5, "range": 1.1, "interval": 0.7, "reward": 4, "leak": 24, "armor": false},
	"bulwark": {"hp": 145, "speed": 0.36, "damage": 12, "range": 2.7, "interval": 1.35, "reward": 8, "leak": 38, "armor": true},
	"mortar": {"hp": 82, "speed": 0.32, "damage": 14, "range": 8.8, "interval": 3.8, "reward": 7, "leak": 30, "armor": false},
	"sapper": {"hp": 60, "speed": 0.82, "damage": 30, "range": 1.0, "interval": 1.0, "reward": 5, "leak": 42, "armor": false},
	"jammer": {"hp": 96, "speed": 0.40, "damage": 6, "range": 3.1, "interval": 1.3, "reward": 6, "leak": 28, "armor": false},
	"drill": {"hp": 620, "speed": 0.26, "damage": 25, "range": 2.5, "interval": 2.8, "reward": 24, "leak": 95, "armor": true},
	"carrier": {"hp": 680, "speed": 0.23, "damage": 16, "range": 3.1, "interval": 2.0, "reward": 26, "leak": 95, "armor": true},
	"storm": {"hp": 820, "speed": 0.21, "damage": 26, "range": 9.0, "interval": 2.5, "reward": 32, "leak": 110, "armor": true}}
const SUPPORT := {"ward": "WARD: 35% less incoming damage", "relay": "RELAY: longer fire range, faster captures", "recovery": "RECOVERY: 200 finite repair points; living allies only"}
const OBJECTIVES := ["hold", "salvage", "relay", "boss", "relay", "silence", "relay", "boss", "hold", "silence", "salvage", "liberate"]
const FORECASTS := [
	"Rifles stop drones. Rovers sweep the runners. Collect scrap before the next arrival.",
	"Recover three exposed supply caches. Breakers pierce the late bulwarks.",
	"Capture both field relays. Rangers outrange mortar crews; Relay helps your own rifle.",
	"The Drill winds up, then charges. Breakers pierce it; keep away from its charge lane.",
	"Two side relays draw you away from base. Runners bypass your infantry.",
	"Kill every mortar crew. Rangers reach them; Jammers silence nearby recruits.",
	"Capture both relays under crossfire. Ward protects exposed infantry; Recovery repairs survivors.",
	"The Carrier repairs living escorts with a finite repair tank. Pick off its escorts or burst it down.",
	"Stop 90% of the rush. Rovers sweep clusters; Ward absorbs sapper impacts.",
	"Silence long-range mortar crews. Flank with your commander while Rangers cover the other side.",
	"Three caches fund the final battle. Specialist order and exposed collection routes matter.",
	"Capture both relays, destroy the Storm Engine and liberate the foundry. Move out of red strike circles."]

static func same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

static func signature(d: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d))).sha256_text()

static func mission(index: int) -> Dictionary:
	index = clampi(index, 0, 11)
	var objective: String = OBJECTIVES[index]
	var waves := 5 if index < 2 else 6
	var gap: float = [25, 28, 31, 32, 33, 33, 34, 35, 34, 35, 36, 37][index]
	var roles: Array = ["drone", "runner"]
	if index >= 1:
		roles.append("bulwark")
	if index >= 2:
		roles.append("mortar")
	if index >= 4:
		roles.append("sapper")
	if index >= 5:
		roles.append("jammer")
	var schedule: Array = []
	for wave in waves:
		var amount := 3 if index < 2 else (4 if index < 6 else 5)
		for j in amount:
			var role: String = roles[(wave * 2 + j + index) % roles.size()]
			if (objective == "silence" or index >= 5) and j == 0:
				role = "mortar"
			if wave == waves - 1 and j == 0 and index in [3, 7, 11]:
				role = {3: "drill", 7: "carrier", 11: "storm"}[index]
			var x: float = [-3.5, 0.0, 3.5][(wave + j + index) % 3]
			var offsets: Array = [0.0, 0.33, 0.66] if amount == 3 else ([0.0, 0.22, 0.5, 0.73] if amount == 4 else [0.0, 0.18, 0.37, 0.64, 0.68])
			schedule.append({"id": schedule.size(), "at": 2.0 + wave * gap + gap * offsets[j], "role": role, "x": x, "z": -6.4 - (j % 2) * 0.35})
	var available := ["rifle", "rover"] if index == 0 else (["rifle", "breaker", "rover"] if index == 1 else ROLES.duplicate())
	var definition := {"version": VERSION, "mode": "campaign", "id": IDS[index], "index": index, "seed": 900 + index, "style": "authored", "title": TITLES[index], "objective": objective, "forecast": FORECASTS[index], "schedule": schedule, "available": available, "unit": UNIT.duplicate(true), "enemy": ENEMY.duplicate(true), "pool": [3, 3, 3, 3], "cap": 6 if index < 2 else 4, "funds": 22 if index < 2 else 34, "commander_hp": 120, "hq": 280 if index == 11 else 210, "minimum": int(ceil(schedule.size() * (0.9 if index == 8 else 0.72))), "support_cost": 14, "relays": [[-3.6, -2.2], [3.6, -2.2]] if objective in ["relay", "liberate"] else [], "caches": [[-3.6, -3.4, 10], [0.0, -4.6, 10], [3.6, -3.4, 10]] if objective == "salvage" else [[0.0, 0.5, 8]], "capture_seconds": 3.0, "command_damage": 17, "command_range": 3.7, "command_interval": 0.46, "command_speed": 3.8}

	definition["layout"] = {"pads": PADS.map(func(p): return [p.x, p.y]), "formation": FORMATION.map(func(p): return [p.x, p.y]), "gate": [[0, 1], [0, -0.9]]}
	definition["support_effects"] = {"ward_factor": 0.65, "relay_unit_range": 1.1, "relay_command_range": 1.8, "relay_damage_factor": 1.25, "relay_capture_factor": 2.0, "repair_budget": 200.0, "repair_commander_rate": 2.2, "repair_unit_rate": 1.6}
	definition["arm_seconds"] = 0.6
	definition["pickup_radius"] = 1.25
	definition["sentry"] = {"damage": 3.0, "interval": 0.9, "range": 4.6}
	return definition

static func pad(d: Dictionary, index: int) -> Vector2:
	return Vector2(d.layout.pads[index][0], d.layout.pads[index][1])

static func formation(d: Dictionary, index: int) -> Vector2:
	return Vector2(d.layout.formation[index][0], d.layout.formation[index][1])

static func skirmish(seed: int, style: String) -> Dictionary:
	seed = clampi(seed, 0, 999999)
	if style not in ["mixed", "flank", "siege"]:
		style = "mixed"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var d := mission(6 + seed % 6)
	d.mode = "skirmish"
	d.id = "skirmish"
	d.seed = seed
	d.style = style
	d.title = "Skirmish %06d / %s" % [seed, style.capitalize()]
	d.objective = "relay" if style == "flank" else ("silence" if style == "siege" else "hold")
	d.relays = [[-3.6, -2.2], [3.6, -2.2]] if style == "flank" else []
	d.caches = [[0.0, 0.5, 8]]
	d.forecast = "Seeded " + style + ": same seed and style reproduce the complete pinned encounter."
	for e in d.schedule:
		e.role = ("runner" if rng.randi_range(0, 1) == 0 else "sapper") if style == "flank" else (("mortar" if rng.randi_range(0, 1) == 0 else "bulwark") if style == "siege" else ["drone", "runner", "bulwark", "mortar", "sapper", "jammer"][rng.randi_range(0, 5)])
		e.x = [-3.5, 0.0, 3.5][rng.randi_range(0, 2)]
	return d

static func valid(d: Variant) -> bool:
	if not d is Dictionary or not finite_tree(d) or d.get("version") != VERSION or d.get("mode") not in ["campaign", "skirmish"]:
		return false
	if d.mode == "campaign":
		if not d.get("index") is float and not d.get("index") is int:
			return false
		if not is_finite(float(d.index)) or d.index != floor(d.index) or d.index < 0 or d.index > 11:
			return false
		return same(d, mission(int(d.index)))
	if not (d.get("seed") is float or d.get("seed") is int) or not is_finite(float(d.seed)) or d.seed != floor(d.seed) or d.seed < 0 or d.seed > 999999 or d.get("style") not in ["mixed", "flank", "siege"]:
		return false
	return same(d, skirmish(int(d.seed), d.style))

static func finite_tree(value: Variant, depth: int = 0) -> bool:
	if depth > 8:
		return false
	if value is float or value is int:
		return is_finite(float(value))
	if value is Array:
		if value.size() > 40:
			return false
		for child in value:
			if not finite_tree(child, depth + 1):
				return false
	if value is Dictionary:
		if value.size() > 80:
			return false
		for key in value:
			if not key is String or not finite_tree(value[key], depth + 1):
				return false
	return value is Dictionary or value is Array or value is String or value is bool
