extends RefCounted
## Deep value snapshots only; no node, dictionary or RNG can write into rules.
const C = preload("res://scripts/campaign_rules.gd")
const L = preload("res://scripts/rules.gd")
var previous := {}
var current := {}
var epoch := 0
var paused := false
var interval := 1.0 / 60
var elapsed := 1.0 / 60
var seen := {}
var order: Array[String] = []

func reset(state: Dictionary, held: bool) -> void:
	epoch += 1
	current = snapshot(state)
	previous = current.duplicate(true)
	paused = held
	elapsed = interval
	seen.clear()
	order.clear()

func ingest(state: Dictionary, held: bool, dt: float) -> bool:
	var next := snapshot(state)
	if current.is_empty() or next.time < current.time or paused != held or next.identity != current.identity:
		reset(state, held)
		return true
	if next.time > current.time:
		previous = current
		interval = maxf(dt, .001)
		elapsed = 0
	current = next
	return false

func advance(dt: float) -> float:
	if not paused:
		elapsed = minf(interval, elapsed + dt)
	return clampf(elapsed / interval, 0, 1)

func accept(event: Dictionary) -> bool:
	var key := "%d:%s:%s" % [epoch, str(current.time), JSON.stringify(event)]
	if seen.has(key):
		return false
	seen[key] = true
	order.append(key)
	if order.size() > 512:
		seen.erase(order.pop_front())
	return true

static func snapshot(state: Dictionary) -> Dictionary:
	var campaign: bool = state.schema == 2
	var actors := {"commander": {"role": "commander", "position": Vector3(state.x, 0, state.z), "hp": 1.0, "max_hp": 1.0}}
	for e in state.enemies:
		var spec: Dictionary = state.definition.roster[int(e.id)] if campaign else {}
		var p := C.point(state.definition, e) if campaign else Vector2(L.road_x(e.z), e.z)
		actors["enemy:" + str(int(e.id))] = {"role": str(spec.role) if campaign else ("raider" if e.id < 10 else "armor"), "position": Vector3(p.x, 0, p.y), "hp": float(e.hp), "max_hp": float(spec.hp) if campaign else float(L.enemy_hp(e.id)), "slow": float(e.get("slow", 0))}
	var towers: Array = []
	if campaign:
		towers = state.towers.duplicate(true)
	else:
		for i in 2:
			towers.append({"family": 0 if state.pads[i] == 1 else -1, "fork": 1 if i == 1 else 0, "jam": 0.0})
	return {"time": float(state.time), "phase": str(state.phase), "identity": JSON.stringify(state.definition) if campaign else "legacy", "actors": actors, "towers": towers, "coins": state.coins.duplicate(true), "integrity": int(state.integrity), "killed": state.killed.duplicate(), "leaked": state.leaked.duplicate()}
