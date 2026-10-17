class_name BattleRules
extends RefCounted

const Gear = preload("res://scripts/gear_rules.gd")
const UNIT_CAP := 120
const ENEMY_CAP := 90
const STEP := 1.0 / 30.0
const STATS := {
	"guard": {"hp": 36.0, "damage": 9.0, "reach": 20.0, "speed": 29.0, "period": 0.72},
	"ranger": {"hp": 14.0, "damage": 11.0, "reach": 103.0, "speed": 25.0, "period": 1.05},
	"beetle": {"hp": 30.0, "damage": 7.0, "reach": 21.0, "speed": 22.0, "period": 0.9},
	"shell": {"hp": 70.0, "damage": 10.0, "reach": 23.0, "speed": 17.0, "period": 1.15},
	"skitter": {"hp": 18.0, "damage": 5.0, "reach": 18.0, "speed": 39.0, "period": 0.65}}

static func initial(seed_value: int = 1701) -> Dictionary:
	return {"board": Gear.initial_board(), "gold": 24, "next_id": 6, "wall": 220.0,
		"units": [], "enemies": [], "projectiles": [], "production": {}, "phase": "ready",
		"time": 0.0, "wave": 0, "wave_time": 0.0, "spawn_clock": 0.0, "spawned": 0,
		"serial": 1, "seed": seed_value, "kills": 0, "produced": 0, "peak_units": 0,
		"wall_hits": 0, "cap_time": 0.0}

static func waves() -> Array:
	return [
		{"name": "Scouts", "count": 12, "interval": 1.6, "kind": "beetle", "duration": 24.0},
		{"name": "Fast flanks", "count": 20, "interval": 1.1, "kind": "skitter", "duration": 27.0},
		{"name": "Iron shells", "count": 20, "interval": 1.2, "kind": "shell", "duration": 29.0}]

static func start(state: Dictionary) -> void:
	if state.phase == "ready":
		state.phase = "battle"
		state.wave = 1

static func make_unit(state: Dictionary, kind: String, lane: int, friendly: bool) -> Dictionary:
	var stats: Dictionary = STATS[kind]
	var serial := int(state.serial)
	state.serial = serial + 1
	# Integer hash gives repeatable visible spacing, without depending on global RNG.
	var offset := float((serial * 37 + int(state.seed)) % 41 - 20)
	return {"id": serial, "kind": kind, "lane": lane, "x": 116.0 + 184.0 * lane + offset,
		"y": 537.0 if friendly else 205.0, "hp": stats.hp, "max_hp": stats.hp,
		"cooldown": 0.1, "flash": 0.0}

static func tick(state: Dictionary, dt: float) -> void:
	if state.phase != "battle":
		return
	state.time = float(state.time) + dt
	state.wave_time = float(state.wave_time) + dt
	state.spawn_clock = float(state.spawn_clock) + dt
	state.projectiles.clear()
	var rates := Gear.rates(state.board)
	var production: Dictionary = {}
	for p in state.board:
		if not Gear.BASE_RATES.has(p.kind):
			continue
		var key := str(int(p.id))
		var stored := float(state.production.get(key, 0.0))
		stored = minf(1.0, stored + float(rates.get(int(p.id), 0.0)) * dt)
		if stored >= 1.0 and state.units.size() < UNIT_CAP:
			state.units.append(make_unit(state, str(p.kind), int(p.lane), true))
			state.produced = int(state.produced) + 1
			stored -= 1.0
		production[key] = stored
	state.production = production
	state.peak_units = maxi(int(state.peak_units), state.units.size())
	if state.units.size() >= UNIT_CAP:
		state.cap_time = float(state.cap_time) + dt
	var wave: Dictionary = waves()[int(state.wave) - 1]
	if int(state.spawned) < int(wave.count) and float(state.spawn_clock) >= float(wave.interval) and state.enemies.size() < ENEMY_CAP:
		state.spawn_clock = float(state.spawn_clock) - float(wave.interval)
		var lane := (int(state.spawned) + int(state.wave)) % 3
		var kind: String = wave.kind
		if int(state.wave) == 3 and int(state.spawned) % 3 == 0:
			kind = "skitter"
		state.enemies.append(make_unit(state, kind, lane, false))
		state.spawned = int(state.spawned) + 1
	for friendly in [true, false]:
		var attackers: Array = state.units if friendly else state.enemies
		var targets: Array = state.enemies if friendly else state.units
		for unit in attackers:
			if float(unit.hp) <= 0:
				continue
			unit.flash = maxf(0.0, float(unit.flash) - dt)
			unit.cooldown = maxf(0.0, float(unit.cooldown) - dt)
			var stats: Dictionary = STATS[unit.kind]
			var target: Dictionary = {}
			var distance := INF
			for candidate in targets:
				if float(candidate.hp) <= 0:
					continue
				var dx := float(candidate.x) - float(unit.x)
				var dy := float(candidate.y) - float(unit.y)
				var value := Vector2(dx, dy).length()
				if value < distance:
					distance = value
					target = candidate
			if not target.is_empty() and distance <= float(stats.reach):
				if float(unit.cooldown) <= 0:
					var damage := float(stats.damage)
					if str(target.kind) == "shell" and str(unit.kind) == "guard":
						damage *= 0.4
					target.hp = float(target.hp) - damage
					target.flash = 0.16
					unit.cooldown = stats.period
					if unit.kind == "ranger":
						state.projectiles.append([float(unit.x), float(unit.y), float(target.x), float(target.y)])
			else:
				var direction := Vector2(0, -1 if friendly else 1)
				if not target.is_empty():
					direction = Vector2(float(target.x) - float(unit.x), float(target.y) - float(unit.y)).normalized()
				elif friendly:
					# A dispersed holding formation keeps a large army readable at the field edge.
					var slot := int(unit.id) % UNIT_CAP
					var holding := Vector2(62 + (slot % 20) * 25, 219 + (slot / 20) * 18)
					direction = (holding - Vector2(float(unit.x), float(unit.y))).limit_length(1.0)
				unit.x = clampf(float(unit.x) + direction.x * float(stats.speed) * dt, 48, 552)
				unit.y = clampf(float(unit.y) + direction.y * float(stats.speed) * dt, 204, 542)
			if not friendly and float(unit.y) >= 539.0 and float(unit.cooldown) <= 0:
				state.wall = maxf(0.0, float(state.wall) - float(stats.damage))
				state.wall_hits = int(state.wall_hits) + 1
				unit.cooldown = stats.period
	var dead := 0
	for enemy in state.enemies:
		if float(enemy.hp) <= 0:
			dead += 1
	state.kills = int(state.kills) + dead
	state.gold = int(state.gold) + dead
	state.units = state.units.filter(func(u): return float(u.hp) > 0)
	state.enemies = state.enemies.filter(func(u): return float(u.hp) > 0)
	if float(state.wall) <= 0:
		state.phase = "defeat"
	elif int(state.spawned) >= int(wave.count) and float(state.wave_time) >= float(wave.duration) and state.enemies.is_empty():
		if int(state.wave) == waves().size():
			state.phase = "victory"
		else:
			state.wave = int(state.wave) + 1
			state.wave_time = 0.0
			state.spawn_clock = 0.0
			state.spawned = 0
