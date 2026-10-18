extends RefCounted

const VERSION := 1
const TITLES := ["Copper Pass", "Reed Narrows", "The Ram at Cinder Gate", "Twinwater Crossing", "Lantern Fen", "The Brood March", "Glasswind Ridge", "The Broken Switchback", "Last Watch", "The Ash Regent"]
const DURATIONS := [140, 155, 170, 185, 195, 205, 215, 225, 235, 250]
const COUNTS := [60, 68, 76, 84, 92, 100, 108, 116, 124, 140]
const REGIONS := ["COPPER MARCH", "LANTERN FENS", "GLASSWIND"]
const FAMILIES := ["BOLT", "MORTAR", "BEACON"]
const PRICES := [10, 12, 9]
const FORKS := [["PIERCE", "VOLLEY"], ["SIEGE", "SCATTER"], ["PRISM", "WINTER"]]
const UPGRADES := [[30, 32], [36, 34], [30, 28]]
const ROLES := ["raider", "runner", "armor", "swarm", "mender", "shade", "ram", "matriarch", "regent"]
const STATS := {
	"raider": [6, 0.95, 0, 3, 2], "runner": [4, 1.65, 0, 2, 2],
	"armor": [18, 0.72, 2, 4, 3], "swarm": [3, 1.15, 0, 1, 1],
	"mender": [11, 0.85, 0, 4, 2], "shade": [10, 1.12, 0, 4, 2],
	"ram": [330, 0.34, 3, 30, 12], "matriarch": [380, 0.38, 1, 30, 12],
	"regent": [600, 0.38, 2, 40, 16]}

static func region(stage: int) -> int:
	return 0 if stage < 3 else (1 if stage < 6 else 2)

static func definition(stage: int, seed: int = 1, budget: int = 0, mirrored: bool = false, endless: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + stage * 7919 + (endless + 1) * 104729
	var d := {"catalog": VERSION, "rules": 2, "generator": 1, "id": "pass%02d" % (stage + 1), "stage": stage, "title": TITLES[stage], "region": region(stage), "seed": seed, "budget": budget, "mirror": mirrored, "endless": endless, "lanes": 1 if stage < 3 else 2, "curve": [0.0, 0.8, -0.4, 0.5, 1.2, -0.8, 0.1, 1.5, -1.0, 0.8][stage], "duration": DURATIONS[stage], "integrity": 16, "supply": 18 + budget * 3, "pads": [], "roster": []}
	d["families"] = []
	for family in 3:
		d.families.append({"name": FAMILIES[family], "price": PRICES[family], "upgrades": UPGRADES[family].duplicate(), "fork_names": FORKS[family].duplicate(), "stats": [stats(family, 0).duplicate(), stats(family, 1).duplicate(), stats(family, 2).duplicate()]})
	if endless >= 0:
		d.id = "endless"
		d.title = "Endless watch %d" % (endless + 1)
		d.lanes = 2
		d.duration = 160 + mini(endless, 8) * 8
		d.curve = rng.randf_range(-1.5, 1.5)
	for z in [-5.0, -0.3, 4.3]:
		for x in [-3.7, 3.7]:
			d.pads.append({"x": x, "z": z})
	if stage >= 4 or endless >= 0:
		d.pads.append({"x": 0.0, "z": -2.8})
		d.pads.append({"x": 0.0, "z": 2.5})
	var count: int = COUNTS[stage] if endless < 0 else 100 + mini(endless, 12) * 6
	var pool := ["raider", "runner"]
	if stage >= 1:
		pool.append("swarm")
	if stage >= 2:
		pool.append("armor")
	if stage >= 3:
		pool.append("mender")
	if stage >= 4:
		pool.append("shade")
	var clock := 7.0
	for id in count:
		var role: String = pool[(id * 7 + int(rng.randi() % 7)) % pool.size()]
		if id < 12:
			role = "raider" if id % 4 != 3 else "runner"
		var pulse := id % 16
		# Pulses mix dense packs with short recovery gaps; no resource timer.
		var stride: float = (float(d.duration) - 30) / count
		clock += stride * (0.48 if pulse < 6 else (1.7 if pulse > 12 else 1.0))
		var lane := 0 if d.lanes == 1 else ((id / 12 + int(rng.randi() % 3)) % 2)
		if id < 12:
			lane = 0
		if stage == 7:
			lane = 0 if id < count / 2 else 1
		if stage == 8 and id >= 12 and id % 20 < 7:
			role = "runner"
		var scale := 1.0 + stage * 0.075 + maxf(0, endless) * 0.06
		d.roster.append(enemy(id, clock, role, lane, scale))
	var final_time: float = d.duration - 14.0
	var time_scale: float = (final_time - 7) / (clock - 7)
	for e in d.roster:
		e.t = 7 + (e.t - 7) * time_scale
	clock = final_time
	var boss := "ram" if stage == 2 else ("matriarch" if stage == 5 else ("regent" if stage == 9 else ""))
	if endless >= 0:
		boss = ["ram", "matriarch", "regent"][endless % 3]
	if not boss.is_empty():
		var e := enemy(count, maxf(20, clock - 28), boss, 0, 1.0 + maxf(0, endless) * 0.08)
		d.roster.append(e)
	d.roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	for id in d.roster.size():
		d.roster[id].id = id
	return d

static func enemy(id: int, time: float, role: String, lane: int, scale: float) -> Dictionary:
	var stats: Array = STATS[role]
	return {"id": id, "t": time, "role": role, "lane": lane, "hp": ceili(stats[0] * scale), "speed": stats[1], "armor": stats[2], "reward": stats[3], "leak": stats[4]}

static func road_x(d: Dictionary, lane: int, z: float) -> float:
	var offset := 0.0 if d.lanes == 1 else (-1.45 if lane == 0 else 1.45)
	return (offset + sin(z * 0.42 + d.curve) * 0.55) * (-1 if d.mirror else 1)

static func stats(family: int, fork: int) -> Dictionary:
	var rows := [
		[{"damage": 2.5, "period": 0.55, "range": 5.0, "area": 0.0, "chain": 1, "pierce": false, "slow": 1.0}, {"damage": 7.0, "period": 0.65, "range": 5.5, "area": 0.0, "chain": 1, "pierce": true, "slow": 1.0}, {"damage": 3.5, "period": 0.42, "range": 5.0, "area": 0.0, "chain": 2, "pierce": false, "slow": 1.0}],
		[{"damage": 7.0, "period": 1.7, "range": 5.2, "area": 1.6, "chain": 1, "pierce": false, "slow": 1.0}, {"damage": 22.0, "period": 1.8, "range": 5.6, "area": 1.2, "chain": 1, "pierce": true, "slow": 1.0}, {"damage": 11.0, "period": 1.4, "range": 5.2, "area": 2.5, "chain": 1, "pierce": false, "slow": 1.0}],
		[{"damage": 1.5, "period": 0.6, "range": 4.7, "area": 0.0, "chain": 1, "pierce": true, "slow": 0.5}, {"damage": 6.0, "period": 0.7, "range": 5.0, "area": 0.0, "chain": 3, "pierce": true, "slow": 0.65}, {"damage": 2.5, "period": 0.8, "range": 5.0, "area": 2.1, "chain": 1, "pierce": true, "slow": 0.28}]]
	return rows[family][fork]
