extends RefCounted
## Immutable, bounded render snapshots. No game dictionary references survive.
var epoch := 0
var previous := {}
var current := {}
var seen := {}
var seen_order: Array[String] = []
var paused := false
var last_time := -1.0
var elapsed := 0.0
var interval := 1.0 / 60.0
var phase := "ready"

func reset(state: Dictionary, is_paused: bool) -> void:
	epoch += 1
	current = snapshot(state)
	previous = current.duplicate(true)
	seen.clear()
	seen_order.clear()
	paused = is_paused
	last_time = state.time
	elapsed = interval
	phase = state.phase

func ingest(state: Dictionary, is_paused: bool, dt: float) -> bool:
	if current.is_empty() or state.time < last_time or paused != is_paused:
		reset(state, is_paused)
		return true
	if state.time > last_time:
		previous = current
		current = snapshot(state)
		interval = maxf(0.001, dt)
		elapsed = 0
		last_time = state.time
	else:
		# Purchases and ready-state kit changes do not advance simulation time.
		current = snapshot(state)
	phase = state.phase
	return false

func advance(dt: float) -> float:
	if not paused:
		elapsed = minf(interval, elapsed + dt)
	return clampf(elapsed / interval, 0, 1)

func accept(event: Dictionary) -> bool:
	var key: String = str(epoch) + ":" + str(event.get("attack", "")) + ":" + str(event.kind) + ":" + str(event.get("enemy", event.get("recipient", event.get("id", -9))))
	if seen.has(key):
		return false
	seen[key] = true
	seen_order.append(key)
	if seen_order.size() > 512:
		seen.erase(seen_order.pop_front())
	return true

static func snapshot(state: Dictionary) -> Dictionary:
	var campaign: bool = int(state.catalog) == 2
	var result := {}
	var waiting_heads := {}
	for recruit in state.recruits:
		if recruit.phase == "waiting" and not waiting_heads.has(recruit.role):
			waiting_heads[recruit.role] = int(recruit.id)
	result["commander"] = {"key": "commander", "role": "commander", "team": "commander", "position": Vector3(state.x, 0, state.z), "hp": float(state.hp), "max_hp": float(state.definition.commander_hp) if campaign else 100.0, "phase": "fallen" if state.hp <= 0 else "fighting", "equip": 1.0}
	for r in state.recruits:
		var key := "recruit:" + str(int(r.id))
		var max_hp: float = state.definition.unit[r.role].hp if campaign else (140.0 if r.role == "vehicle" else 42.0)
		var arm_seconds: float = state.definition.arm_seconds if campaign else 0.8
		result[key] = {"key": key, "role": r.role, "team": "ally", "position": Vector3(r.x, 0, r.z), "hp": float(r.hp), "max_hp": max_hp, "phase": r.phase, "equip": 1.0 - float(r.clock) / arm_seconds if r.phase == "equipping" else 1.0}
		result[key]["request"] = waiting_heads.get(r.role, -1) == int(r.id) and Vector2(state.x, state.z).distance_to(Vector2(r.x, r.z)) < 1.8
		result[key]["jammed"] = false
		if campaign and r.phase == "fighting":
			for enemy in state.enemies:
				if enemy.role == "jammer" and enemy.hp > 0 and Vector2(enemy.x, enemy.z).distance_to(Vector2(r.x, r.z)) < 4.7:
					result[key].jammed = true
	for e in state.enemies:
		var key := "enemy:" + str(int(e.id))
		var role: String = e.role if campaign else ("bulwark" if e.armored else "drone")
		result[key] = {"key": key, "role": role, "team": "enemy", "position": Vector3(e.x, 0, e.z), "hp": float(e.hp), "max_hp": float(state.definition.enemy[role].hp) if campaign else (150.0 if e.armored else 48.0), "phase": "fighting", "equip": 1.0}
		result[key]["warning"] = float(e.get("telegraph", 0.0))
		for mark in state.get("marks", []):
			if int(mark.source) == int(e.id):
				result[key].warning = maxf(result[key].warning, float(mark.remaining))
	return result
