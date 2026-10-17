class_name BattleRules
extends RefCounted

const Gear = preload("res://scripts/gear_rules.gd")
const Content = preload("res://scripts/campaign_data.gd")
const UNIT_CAP := 120
const ENEMY_CAP := 90
const STEP := 1.0 / 30.0
const STATS := {
	"guard": {"hp": 36.0, "damage": 9.0, "reach": 20.0, "speed": 29.0, "period": 0.72},
	"ranger": {"hp": 14.0, "damage": 11.0, "reach": 103.0, "speed": 25.0, "period": 1.05},
	"mortar": {"hp": 18.0, "damage": 19.0, "reach": 124.0, "speed": 20.0, "period": 2.6},
	"beetle": {"hp": 30.0, "damage": 7.0, "reach": 21.0, "speed": 22.0, "period": 0.9},
	"shell": {"hp": 70.0, "damage": 10.0, "reach": 23.0, "speed": 17.0, "period": 1.15},
	"skitter": {"hp": 18.0, "damage": 5.0, "reach": 18.0, "speed": 39.0, "period": 0.65},
	"carapace": {"hp": 110.0, "damage": 18.0, "reach": 26.0, "speed": 24.0, "period": 0.9},
	"spitter": {"hp": 42.0, "damage": 7.0, "reach": 145.0, "speed": 24.0, "period": 0.9},
	"swarm": {"hp": 14.0, "damage": 3.0, "reach": 18.0, "speed": 32.0, "period": 0.8},
	"captain": {"hp": 4200.0, "damage": 40.0, "reach": 35.0, "speed": 17.0, "period": 1.2},
	"siege": {"hp": 6500.0, "damage": 30.0, "reach": 125.0, "speed": 15.0, "period": 1.5},
	"matriarch": {"hp": 10000.0, "damage": 42.0, "reach": 38.0, "speed": 19.0, "period": 1.0}}

static func initial(seed_value: int = 1701, encounter: String = "tutorial") -> Dictionary:
	var trial := encounter == "iron_trial"
	var state := {"board": [Gear.piece(1, "core", 2, 2), Gear.piece(2, "drive", 2, 1)] if trial else Gear.initial_board(), "gold": 54 if trial else 24, "next_id": 3 if trial else 6, "wall": 160.0 if trial else 220.0,
		"encounter": encounter, "spent": 0, "production_last_id": 0,
		"units": [], "enemies": [], "projectiles": [], "production": {}, "phase": "ready",
		"time": 0.0, "wave": 0, "wave_time": 0.0, "spawn_clock": 0.0, "spawned": 0,
		"serial": 1, "seed": seed_value, "kills": 0, "produced": 0, "peak_units": 0,
		"wall_hits": 0, "cap_time": 0.0, "losses": 0, "config": {}, "boss_spawned": false,
		"produced_by_role": {}, "lost_by_role": {}, "wave_times": [], "claimed_grants": 0,
		"boss_phase": 0, "boss_clock": 0.0, "boss_total": 0.0, "boss_volley": 0.0, "rally": false}
	if encounter in Content.IDS:
		var config := Content.definition(encounter)
		config["actor_stats"] = STATS.duplicate(true)
		config["generator_rates"] = Gear.BASE_RATES.duplicate(true)
		config["costs"] = Gear.COSTS.duplicate(true)
		configure(state, config)
	return state

static func configure(state: Dictionary, config: Dictionary) -> void:
	state.config = config.duplicate(true)
	state.encounter = str(config.id)
	state.board = [Gear.piece(1, "core", int(config.core[0]), int(config.core[1]))]
	var id := 2
	for p in config.starter:
		state.board.append(Gear.piece(id, p[0], int(p[1]), int(p[2]), int(p[3]), int(p[4])))
		id += 1
	state.next_id = id
	state.gold = int(config.budget)
	state.wall = float(config.wall)

static func from_snapshot(config: Dictionary, seed_value: int) -> Dictionary:
	var state := initial(seed_value)
	configure(state, config)
	return state

static func wall_limit(state: Dictionary) -> float:
	if not state.get("config", {}).is_empty():
		return float(state.config.wall)
	return 160.0 if state.encounter == "iron_trial" else 220.0

static func run_waves(state: Dictionary) -> Array:
	return state.config.waves if not state.get("config", {}).is_empty() else waves(str(state.encounter))

static func waves(encounter: String = "tutorial") -> Array:
	if encounter == "iron_trial":
		return [
			{"name": "Spitter screen", "count": 18, "interval": 0.9, "kind": "spitter", "duration": 22.0},
			{"name": "Carapace column", "count": 18, "interval": 1.35, "kind": "carapace", "duration": 30.0},
			{"name": "Combined assault", "count": 30, "interval": 0.65, "kind": "carapace", "duration": 30.0}]
	return [
		{"name": "Scouts", "count": 12, "interval": 1.6, "kind": "beetle", "duration": 24.0},
		{"name": "Fast flanks", "count": 20, "interval": 1.1, "kind": "skitter", "duration": 27.0},
		{"name": "Iron shells", "count": 20, "interval": 1.2, "kind": "shell", "duration": 29.0}]

static func start(state: Dictionary) -> void:
	if state.phase == "ready":
		state.phase = "battle"
		state.wave = 1

static func make_unit(state: Dictionary, kind: String, lane: int, friendly: bool) -> Dictionary:
	var config: Dictionary = state.get("config", {})
	var stats: Dictionary = config.get("actor_stats", STATS)[kind]
	var serial := int(state.serial)
	state.serial = serial + 1
	# Integer hash gives repeatable visible spacing, without depending on global RNG.
	var offset := float((serial * 37 + int(state.seed)) % 41 - 20)
	var hp := float(stats.hp)
	if not friendly and not config.is_empty():
		hp *= float(config.hp_scale)
	return {"id": serial, "kind": kind, "lane": lane, "x": 116.0 + 184.0 * lane + offset,
		"y": 537.0 if friendly else 205.0, "hp": hp, "max_hp": hp,
		"cooldown": 0.1, "flash": 0.0}

static func next_producer(state: Dictionary, rates: Dictionary) -> Dictionary:
	var available: Array = []
	for p in state.board:
		if float(rates.get(int(p.id), 0.0)) > 0 and float(state.production.get(str(int(p.id)), 0.0)) >= 1:
			available.append(p)
	available.sort_custom(func(a, b): return int(a.id) < int(b.id))
	for p in available:
		if int(p.id) > int(state.production_last_id):
			return p
	return available[0] if not available.is_empty() else {}

static func tick(state: Dictionary, dt: float) -> void:
	if state.phase != "battle":
		return
	state.time = float(state.time) + dt
	state.wave_time = float(state.wave_time) + dt
	# The opening gives the first produced defenders the same travel allowance.
	if float(state.time) > float(state.config.get("deployment_seconds", 0.0)):
		state.spawn_clock = float(state.spawn_clock) + dt
	state.projectiles.clear()
	var rates := Gear.rates(state.board, state.config)
	var production: Dictionary = {}
	for p in state.board:
		if not Gear.BASE_RATES.has(p.kind):
			continue
		var key := str(int(p.id))
		var stored := float(state.production.get(key, 0.0))
		stored = minf(1.0, stored + float(rates.get(int(p.id), 0.0)) * dt)
		production[key] = stored
	state.production = production
	# Round-robin by stable piece ID, independent of board array order. Only
	# currently powered generators can dispatch even if they hold a full buffer.
	while state.units.size() < UNIT_CAP:
		var producer := next_producer(state, rates)
		if producer.is_empty():
			break
		var generated := make_unit(state, str(producer.kind), int(producer.lane), true)
		var deployment: float = state.config.get("deployment_seconds", 0.0)
		if deployment > 0:
			generated["deploy_left"] = deployment
			generated["deploy_total"] = deployment
			generated["deploy_x"] = int(producer.x)
			generated["deploy_y"] = int(producer.y)
		state.units.append(generated)
		state.produced = int(state.produced) + 1
		state.produced_by_role[producer.kind] = int(state.produced_by_role.get(producer.kind, 0)) + 1
		state.production[str(int(producer.id))] = 0.0
		state.production_last_id = int(producer.id)
	state.peak_units = maxi(int(state.peak_units), state.units.size())
	if state.units.size() >= UNIT_CAP:
		state.cap_time = float(state.cap_time) + dt
	var config: Dictionary = state.config
	var wave: Dictionary = run_waves(state)[int(state.wave) - 1]
	if not config.is_empty():
		campaign_spawn(state, wave)
	elif int(state.spawned) < int(wave.count) and float(state.spawn_clock) >= float(wave.interval) and state.enemies.size() < ENEMY_CAP:
		state.spawn_clock = float(state.spawn_clock) - float(wave.interval)
		var lane := (int(state.spawned) + int(state.wave)) % 3
		var kind: String = wave.kind
		if int(state.wave) == 3 and int(state.spawned) % 3 == 0:
			kind = "skitter"
		state.enemies.append(make_unit(state, kind, lane, false))
		state.spawned = int(state.spawned) + 1
	if not config.is_empty() and state.boss_spawned:
		boss_tick(state, dt)
	for friendly in [true, false]:
		var attackers: Array = state.units if friendly else state.enemies
		var targets: Array = state.enemies if friendly else state.units
		for unit in attackers:
			if float(unit.hp) <= 0:
				continue
			if float(unit.get("deploy_left", 0.0)) > 0:
				unit.deploy_left = maxf(0, float(unit.deploy_left) - dt)
				continue
			unit.flash = maxf(0.0, float(unit.flash) - dt)
			unit.cooldown = maxf(0.0, float(unit.cooldown) - dt)
			var stats: Dictionary = config.get("actor_stats", STATS)[unit.kind]
			var target: Dictionary = {}
			var distance := INF
			for candidate in targets:
				if float(candidate.hp) <= 0 or float(candidate.get("deploy_left", 0.0)) > 0:
					continue
				var dx := float(candidate.x) - float(unit.x)
				var dy := float(candidate.y) - float(unit.y)
				var value := Vector2(dx, dy).length()
				if value < distance:
					distance = value
					target = candidate
			if not friendly and not config.is_empty() and distance > maxf(140.0, float(stats.reach)):
				# Raiders keep marching toward their gate until a defender is near;
				# an army on the opposite flank cannot lure the whole front away.
				target = {}
			if not target.is_empty() and distance <= float(stats.reach):
				if float(unit.cooldown) <= 0:
					var damage := float(stats.damage)
					if not friendly and not config.is_empty():
						damage *= float(config.damage_scale) * float(unit.get("wave_damage", 1.0))
					if str(unit.kind) == "guard":
						if str(target.kind) == "shell":
							damage *= 0.18 if not config.is_empty() and state.encounter != "camp_01" else 0.4
						elif str(target.kind) == "carapace":
							damage *= 0.04
						elif str(target.kind) in ["captain", "siege", "matriarch"]:
							damage *= 0.18
					if unit.kind == "mortar" and target.kind in ["shell", "captain", "siege", "matriarch"]:
						damage *= 0.6
					target.hp = float(target.hp) - damage
					target.flash = 0.16
					unit.cooldown = stats.period
					if unit.kind == "carapace":
						var splashed := 0
						for nearby in targets:
							if int(nearby.id) == int(target.id) or float(nearby.hp) <= 0 or float(nearby.get("deploy_left", 0.0)) > 0:
								continue
							if Vector2(float(nearby.x) - float(target.x), float(nearby.y) - float(target.y)).length_squared() <= 36 * 36:
								nearby.hp = float(nearby.hp) - damage * 0.65
								nearby.flash = 0.16
								splashed += 1
								if splashed >= 4:
									break
					if unit.kind == "mortar" or unit.kind in ["captain", "matriarch"]:
						var splash_hits := 0
						var radius := 44.0 if unit.kind == "mortar" else 55.0
						for nearby in targets:
							if int(nearby.id) == int(target.id) or float(nearby.hp) <= 0 or float(nearby.get("deploy_left", 0.0)) > 0:
								continue
							if Vector2(float(nearby.x) - float(target.x), float(nearby.y) - float(target.y)).length_squared() <= radius * radius:
								nearby.hp = float(nearby.hp) - damage * 0.7
								nearby.flash = 0.16
								splash_hits += 1
								if splash_hits >= 7:
									break
					if unit.kind in ["ranger", "spitter", "mortar", "siege"]:
						state.projectiles.append([float(unit.x), float(unit.y), float(target.x), float(target.y), friendly])
			else:
				var direction := Vector2(0, -1 if friendly else 1)
				if not target.is_empty():
					direction = Vector2(float(target.x) - float(unit.x), float(target.y) - float(unit.y)).normalized()
				elif friendly:
					# A dispersed holding formation keeps a large army readable at the field edge.
					var slot := int(unit.id) % UNIT_CAP
					var holding := Vector2(62 + (slot % 20) * 25, 219 + (slot / 20) * 18)
					direction = (holding - Vector2(float(unit.x), float(unit.y))).limit_length(1.0)
				var movement_speed := float(stats.speed) * (1.0 if friendly or config.is_empty() else float(config.speed_scale))
				unit.x = clampf(float(unit.x) + direction.x * movement_speed * dt, 48, 552)
				unit.y = clampf(float(unit.y) + direction.y * movement_speed * dt, 204, 542)
			if not friendly and float(unit.y) >= 539.0 and float(unit.cooldown) <= 0:
				state.wall = maxf(0.0, float(state.wall) - float(stats.damage))
				state.wall_hits = int(state.wall_hits) + 1
				unit.cooldown = stats.period
	var dead := 0
	for enemy in state.enemies:
		if float(enemy.hp) <= 0:
			dead += 1
	state.kills = int(state.kills) + dead
	for unit in state.units:
		if float(unit.hp) <= 0:
			state.losses = int(state.losses) + 1
			state.lost_by_role[unit.kind] = int(state.lost_by_role.get(unit.kind, 0)) + 1
	if state.encounter != "iron_trial" and config.is_empty():
		state.gold = int(state.gold) + dead
	state.units = state.units.filter(func(u): return float(u.hp) > 0)
	state.enemies = state.enemies.filter(func(u): return float(u.hp) > 0)
	if float(state.wall) <= 0:
		state.phase = "defeat"
	elif int(state.spawned) >= int(wave.count) and (not config.is_empty() or float(state.wave_time) >= float(wave.duration)) and state.enemies.is_empty():
		if int(state.wave) == run_waves(state).size():
			if not config.is_empty() and config.boss != "" and not state.boss_spawned:
				var boss := make_unit(state, str(config.boss), 1, false)
				boss.hp = float(config.boss_hp)
				boss.max_hp = boss.hp
				state.enemies.append(boss)
				state.boss_spawned = true
				state.boss_phase = 1
				return
			state.phase = "victory"
		else:
			state.wave_times.append(float(state.time))
			if not config.is_empty():
				state.gold = int(state.gold) + int(wave.grant)
				state.claimed_grants = int(state.claimed_grants) + int(wave.grant)
			state.wave = int(state.wave) + 1
			state.wave_time = 0.0
			state.spawn_clock = 0.0
			state.spawned = 0
			state.rally = false

static func campaign_spawn(state: Dictionary, wave: Dictionary) -> void:
	var interval := float(wave.interval) * (0.45 if state.rally else 1.0)
	if state.spawn_clock < interval or state.spawned >= int(wave.count) or state.enemies.size() >= ENEMY_CAP:
		return
	state.spawn_clock -= interval
	for i in int(wave.pack):
		if int(state.spawned) >= int(wave.count) or state.enemies.size() >= ENEMY_CAP:
			break
		var ordinal := int(state.spawned)
		var kind: String = wave.pattern[ordinal % wave.pattern.size()]
		var lane: int = int(wave.lanes[(ordinal / int(wave.pack)) % wave.lanes.size()])
		var unit := make_unit(state, kind, lane, false)
		unit.hp = float(unit.hp) * float(wave.get("hp_scale", 1.0))
		unit.max_hp = unit.hp
		unit["wave_damage"] = float(wave.get("damage_scale", 1.0))
		unit.x = clampf(float(unit.x) + float(i - int(wave.pack) / 2) * 11.0, 44, 556)
		state.enemies.append(unit)
		state.spawned += 1

static func boss_tick(state: Dictionary, dt: float) -> void:
	var boss: Dictionary = {}
	for enemy in state.enemies:
		if enemy.kind in ["captain", "siege", "matriarch"]:
			boss = enemy
			break
	if boss.is_empty():
		return
	state.boss_total += dt
	var ratio := float(boss.hp) / float(boss.max_hp)
	var phase := 3 if ratio < 0.33 and boss.kind == "matriarch" else 2 if ratio < 0.66 else 1
	if phase > int(state.boss_phase):
		state.boss_phase = phase
		for i in 12:
			if state.enemies.size() >= ENEMY_CAP:
				break
			state.enemies.append(make_unit(state, "spitter" if i % 4 == 0 else "skitter", i % 3, false))
	state.boss_clock += dt
	if float(state.boss_clock) >= 9:
		state.boss_clock = 0.0
		for i in 6:
			if state.enemies.size() < ENEMY_CAP:
				state.enemies.append(make_unit(state, "beetle" if i % 2 == 0 else "swarm", (i + int(state.boss_phase)) % 3, false))
	if boss.kind in ["siege", "matriarch"] or float(state.boss_total) >= 60:
		state.boss_volley += dt
		if state.boss_volley >= 12:
			state.boss_volley = 0.0
			var screened: bool = state.units.any(func(u): return float(u.get("deploy_left", 0.0)) <= 0 and Vector2(float(u.x) - float(boss.x), float(u.y) - float(boss.y)).length_squared() < 85 * 85)
			if not screened or float(state.boss_total) >= 60:
				state.wall = maxf(0.0, float(state.wall) - (20.0 if float(state.boss_total) >= 60 else 14.0))
				state.wall_hits += 1
