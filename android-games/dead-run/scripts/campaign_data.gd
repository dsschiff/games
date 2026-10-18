extends RefCounted
const CATALOG := 1
const VERSION := 2
const LANES := [-2.65, 0.0, 2.65]
const WEAPONS := {
	"rivet": {"title": "RIVET", "period": 24, "damage": 1, "pierce": 1, "pellets": 1, "spread": 0.0, "hint": "Focused stream. Fast gate conversion; chase split groups."},
	"lance": {"title": "LANCE", "period": 42, "damage": 2, "pierce": 3, "pellets": 1, "spread": 0.0, "hint": "Pierces three infected and armor. Slower gate conversion."},
	"fan": {"title": "FAN", "period": 36, "damage": 1, "pierce": 1, "pellets": 2, "spread": 0.028, "hint": "Wide twin pellets. Sweeps crowds; less concentrated at range."}}
const ROLES := {
	"drifter": {"hp": 3, "armor": 0, "speed": 2.0, "loss": 1, "width": 0.44},
	"runner": {"hp": 2, "armor": 0, "speed": 3.4, "loss": 2, "width": 0.32},
	"plated": {"hp": 5, "armor": 2, "speed": 1.8, "loss": 2, "width": 0.50},
	"spitter": {"hp": 4, "armor": 0, "speed": 1.65, "loss": 1, "width": 0.45},
	"cluster": {"hp": 1, "armor": 0, "speed": 2.2, "loss": 1, "width": 0.30},
	"bulwark": {"hp": 9, "armor": 3, "speed": 1.45, "loss": 3, "width": 0.65}}
const DISTRICTS := ["CANAL WORKS", "MARKET VIADUCT", "RESERVOIR RING", "FERRY APPROACH"]
# Each row pins a different combination of lanes, wave grammar, width/target decisions.
# Rows are catalog1; future catalogs must retain these definitions for old saves.
const ROWS := [
	["First Riggers", 75, 0, "First convert a gate; sweep the loose drifters before working the crane."],
	["Split Signal", 80, 1, "Two recruit gates compete for fire. Choose a side, then cover the opposite line."],
	["Service Gap", 85, 2, "Carts narrow the crossing. A broad crew needs earlier steering."],
	["Running Lights", 85, 3, "Runners arrive quickly. Crane windows follow each sprint."],
	["Work Crew", 90, 4, "Cluster groups split across lanes. Fan covers crowds; Rivet converts gates faster."],
	["Cable Matron", 100, 5, "Follow the cable head between sweeps. Amber lane marks become damaging red zones."],
	["Market Divide", 80, 6, "Plated escorts soak focused fire. Lance passes through their line."],
	["Loading Bay", 85, 7, "A central cart rewards staying lean; recruit on a later gate instead."],
	["Glass Arcade", 90, 8, "Spitters mark your lane. Move after the mark, then return to unfinished targets."],
	["Crosswalk", 90, 9, "Alternating runner pairs make opposite-lane suppression valuable."],
	["Crowd Control", 95, 10, "Crowd lanes flank an armored column. Pick coverage or piercing."],
	["Toll Ram", 110, 11, "Its shield absorbs centre shots. Fire into its flanks or use Lance; dodge marked charges."],
	["Pump House", 85, 12, "Clearing the pump cancels later flood pulses. Suppress the road while it is unfinished."],
	["Wet Channel", 90, 13, "Flood marks alternate. The gold footprint, not just the lead rigger, must fit."],
	["Spillway", 95, 14, "Bulwarks guard the inner channel. Pierce them or recruit around the outer flow."],
	["Three Valves", 95, 15, "Two pumps offer different safe lanes. Either priority can keep the crew alive."],
	["Breakwater", 100, 16, "Dense clusters cross slow armor. Fan sweeps outside; Lance holds the armoured centre."],
	["Spore Bell", 115, 17, "The bell shifts side after half its shell falls. Its three-lane volley always leaves a gap."],
	["Ferry Queue", 90, 18, "Two roadside crews compete with plated escorts. Choose which crew to rescue first."],
	["Last Tram", 95, 19, "Wide wrecks demand early bends. Delay recruitment until you clear the tram."],
	["Platform Nine", 100, 20, "Runner pressure and spit marks overlap. Clear a lane, dodge, then resume side work."],
	["Twin Piers", 100, 21, "Both roadside priorities work: grow through the left rig or disable the right flood pump."],
	["Convoy Column", 105, 22, "Protect a narrow convoy through armor and crowds. Coverage and piercing win differently."],
	["The Last Ferry", 125, 23, "Break both outer arms to expose the core. Read the sweep, protect the line, evacuate everyone."]]

static func enemy(out: Array, born: int, x: float, role: String) -> void:
	var r: Dictionary = ROLES[role]
	out.append({"id": out.size(), "born": born, "x": x, "z": 25.0, "role": role, "hp": r.hp, "armor": r.armor, "speed": r.speed, "loss": r.loss, "width": r.width})

static func roll(seed: int, salt: int, count: int) -> int:
	var value: int = (seed * 1664525 + salt * 1013904223) & 0x7fffffff
	value = value ^ (value >> 13)
	value = (value * 48271) & 0x7fffffff
	return value % count

static func stage(index: int, seed: int = 0) -> Dictionary:
	var row: Array = ROWS[index]
	var district := index / 6
	var pattern: int = row[2]
	var duration: int = row[1] * 60
	var flip := -1.0 if seed > 0 and seed % 2 == 1 else 1.0
	var enemies: Array = []
	var tick := 240
	var wave := 0
	while tick < duration - 240:
		var lane := roll(seed, wave + 1, 3) if seed > 0 else (wave + pattern) % 3
		var x: float = LANES[lane] * flip
		var role := "drifter"
		if pattern >= 3 and wave % 5 == 2: role = "runner"
		if district >= 1 and wave % 5 == 0: role = "plated"
		if district >= 1 and pattern % 3 == 2 and wave % 7 == 3: role = "spitter"
		if district >= 2 and wave % 8 == 5: role = "bulwark"
		if seed > 0: role = ["drifter", "runner", "plated", "spitter", "cluster", "bulwark"][roll(seed, wave + 200, 6)]
		if (seed > 0 and roll(seed, wave + 400, 5) == 0) or (seed == 0 and (pattern % 6 == 4 or (district >= 2 and wave % 4 == 1))):
			for j in 3:
				enemy(enemies, tick + j * 14, clampf(x + (j - 1) * 0.65, -3.5, 3.5), "cluster")
		else:
			enemy(enemies, tick, x, role)
			if district >= 1 and wave % 3 == 1:
				enemy(enemies, tick + 24, -x if absf(x) > 1 else LANES[(lane + 1) % 3] * flip, "runner" if pattern % 2 else "drifter")
		wave += 1
		tick += [110, 105, 100, 92][district] + ((wave + pattern) % 3) * 15 + (roll(seed, wave + 600, 25) - 12 if seed > 0 else 0)
	var gates: Array = []
	for i in range(5 if index > 0 else 4):
		var born := 1 if i == 0 else 60 + i * (duration - 1200) / 5
		var lane := 1 if i == 0 else (roll(seed, i + 800, 3) if seed > 0 else (i + pattern) % 3)
		var initial := -5 if i == 0 else (-9 if i % 2 else -14)
		gates.append({"id": i, "born": born, "x": LANES[lane] * flip, "z": 14.0 if i == 0 else 22.0, "initial": initial, "cap": 5 if i == 0 else 6, "width": 0.85})
		if pattern % 6 == 1 and i in [1, 3]:
			gates.append({"id": gates.size(), "born": born, "x": -LANES[lane] * flip if lane != 1 else -2.65 * flip, "z": 22.0, "initial": -8, "cap": 4, "width": 0.85})
	# IDs are independent of optional paired-gate count.
	for i in gates.size(): gates[i].id = i
	var sides: Array = [{"id": 0, "born": 300, "until": duration - 540, "x": -2.65 * flip, "z": 13.5, "hp": 100 + district * 18, "reward": 3, "kind": "pump" if district == 2 else "rig", "disables": 0 if district == 2 else -1}]
	if district >= 2 or pattern % 6 == 4:
		sides.append({"id": 1, "born": 1500, "until": duration - 360, "x": 2.65 * flip, "z": 12.0, "hp": 95 + district * 15, "reward": 3, "kind": "pump" if pattern in [15, 21] else "rig", "disables": 1 if pattern in [15, 21] else -1})
	var obstacles: Array = []
	if pattern % 6 in [2, 5] or pattern in [7, 13, 19, 22]:
		for i in 4:
			obstacles.append({"id": i, "born": 1140 + i * (duration - 2100) / 4, "x": LANES[roll(seed, i + 900, 3) if seed > 0 else (i + pattern) % 3] * flip, "z": 25.0, "width": 0.8 if pattern % 6 == 2 else 1.1, "loss": 3, "kind": "cart"})
	var floods: Array = []
	if district >= 2:
		for i in range(6 if district == 2 else 4):
			floods.append({"id": i, "mark": 1500 + i * (duration - 2040) / 6, "x": LANES[roll(seed, i + 1000, 3) if seed > 0 else (i + pattern) % 3] * flip, "width": 0.7, "loss": 2, "pump": i % 2})
	var boss := index % 6 == 5
	return {"catalog": CATALOG, "rule_version": VERSION, "generator": 1, "index": index, "seed": seed, "replay": seed > 0, "title": row[0], "district": district,
		"hint": row[3], "duration": duration, "speed": 1.9, "initial_crew": 5, "cap": 20, "weapons": WEAPONS.duplicate(true), "roles": ROLES.duplicate(true),
		"enemies": enemies, "gates": gates, "sides": sides, "obstacles": obstacles, "floods": floods,
		"boss": {"kind": district + 1 if boss else 0, "title": row[0] if boss else "EVAC BLOCKADE", "born": duration - (1800 if boss else 1020), "hp": [140, 170, 190, 220][district] if boss else 36,
			"arms": 45 if index == 23 else 0, "x": 0.0, "z": 23.0}}

static func same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) < 0.000000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for k in a:
			if not b.has(k) or not same(a[k], b[k]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same(a[i], b[i]): return false
		return true
	return a == b
