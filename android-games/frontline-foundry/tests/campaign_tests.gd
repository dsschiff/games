extends SceneTree
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/definitions.gd")
const L = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const P = preload("res://tests/policy.gd")
const Faults = preload("res://tests/fault_files.gd")
var checks := 0
var failures := 0
var details: Array = []
var records: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(okay: bool, text: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": text})
	if not okay:
		failures += 1
		push_error(text)

func wrap_packet(packet: Dictionary) -> String:
	var payload := JSON.stringify(packet)
	return JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})

func synthetically_unlocked(index: int) -> Dictionary:
	var c := C.career()
	c.attempts = index
	c.victories = index
	for i in index:
		c.clears[D.IDS[i]] = 1
		c.records[D.IDS[i]] = {"medal": 1, "seconds": 190, "kills": D.mission(i).schedule.size(), "spent": 70, "seed": 900 + i, "style": "authored"}
	return c

func simulate(index: int, support: String = "relay", variant: String = "A") -> Dictionary:
	var s := C.fresh(D.mission(index))
	s.planned_support = support
	s.phase = "playing"
	var valid := true
	var gate_valid := true
	var max_active := 0
	for frame in 12000:
		if s.phase != "playing":
			break
		var choice := P.decide(s, variant)
		if choice.station >= 0 and C.nearby(s) == choice.station:
			C.buy(s, choice.station)
		C.tick(s, (choice.goal - C.position(s)).limit_length(), 0.05)
		if frame % 100 == 0:
			valid = valid and C.valid(s)
		for r in s.recruits:
			if r.phase == "deploying" and r.waypoint == 1:
				gate_valid = gate_valid and absf(r.x) < 0.02 and r.z >= -0.92 and r.z <= 1.02
		max_active = maxi(max_active, C.active_count(s))
	check(valid and C.valid(s), "normal synthetic route structural/equipment/reward validity " + str(index + 1) + "/" + variant)
	check(gate_valid and max_active <= s.definition.cap, "finite occupied slots and deployment respect visible central opening " + str(index + 1))
	return s

func run() -> void:
	var p := L.profile()
	var settings := {"sound": false, "reduced_effects": true}
	for i in 12:
		var d := D.mission(i)
		check(D.valid(d) and D.valid(JSON.parse_string(JSON.stringify(d))), "complete authored definition validates before/after JSON " + str(i + 1))
		check(C.valid(C.fresh(d)), "fresh authored finite economy/crew pool validates " + str(i + 1))
	var generated_signatures := {}
	for seed in [0, 7, 138, 999999]:
		for style in ["mixed", "flank", "siege"]:
			var d := D.skirmish(seed, style)
			check(D.valid(d) and D.same(d, D.skirmish(seed, style)), "bounded deterministic seeded full snapshot " + str(seed) + style)
			generated_signatures[D.signature(d)] = true
			var bad := d.duplicate(true)
			bad.unit.rifle.cost -= 1
			check(not D.valid(bad), "generated rule/catalog tamper rejected " + str(seed) + style)
	check(generated_signatures.size() == 12, "seed/style vary full encounter and objective rather than only a record label")
	for corruption in ["unknown_id", "cost", "pool", "enemy", "schedule", "seed", "objective", "future_version"]:
		var d := D.mission(11)
		match corruption:
			"unknown_id": d.id = "other"
			"cost": d.unit.ranger.cost = -1
			"pool": d.pool = [99999]
			"enemy": d.enemy.storm.hp = INF
			"schedule": d.schedule[0].id = 1
			"seed": d.seed = 0
			"objective": d.objective = "idle"
			"future_version": d.version = 999
		check(not D.valid(d), "adversarial complete definition rejected: " + corruption)
	var s := C.fresh(D.mission(0))
	check(not C.buy(s, 0), "ready state cannot spend")
	s.phase = "playing"
	check(not C.buy(s, -1) and not C.buy(s, 5) and not C.buy(s, 0), "invalid/remote station cannot spend")
	s.x = D.PADS[2].x
	s.z = D.PADS[2].y
	check(not C.buy(s, 2), "intro locked ranger role cannot spend")
	s.x = D.PADS[0].x
	s.z = D.PADS[0].y
	C.tick(s, Vector2.ZERO, 0.05)
	check(s.spent == 0 and s.wallet == 22, "crossing/standing never buys equipment")
	check(C.buy(s, 0) and s.wallet == 15 and s.spent == 7 and s.stock == [1, 0, 0, 0], "explicit exact-price purchase creates one finite rifle token")
	C.tick(s, Vector2.ZERO, 0.05)
	check(s.consumed == [1, 0, 0, 0] and s.stock == [0, 0, 0, 0] and s.recruits[0].phase == "equipping" and s.recruits[1].phase == "waiting" and s.recruits[9].phase == "waiting", "equipment consumed once by owned queue head; other roles remain unarmed")
	for frame in 240:
		C.tick(s, Vector2.ZERO, 0.05)
	check(s.recruits[0].phase == "fighting" and s.recruits[0].waypoint == 2 and s.recruits[0].shots > 0, "armed recruit actually traverses gate and independently attacks")
	check(s.recruits[9].shots == 0 and s.recruits[9].damage == 0, "unpaid chassis is not a decorative stat bonus")
	var capped := C.fresh(D.mission(11))
	capped.phase = "playing"
	capped.x = D.PADS[0].x
	capped.z = D.PADS[0].y
	for i in 3:
		C.buy(capped, 0)
		C.tick(capped, Vector2.ZERO, 0.25)
	check(not C.buy(capped, 0) and capped.bought[0] == 3, "finite per-role crew pool cannot mint a fourth rifle")
	capped.x = 0
	capped.z = 0.5
	C.tick(capped, Vector2.ZERO, 0.1)
	capped.x = D.PADS[1].x
	capped.z = D.PADS[1].y
	check(C.buy(capped, 1) and capped.wallet >= 10, "fourth paid slot fills with another role while funds remain")
	check(not C.buy(capped, 1) and C.valid(capped), "full cap includes outstanding physical stock, preventing a stranded fifth purchase")
	for frame in 200:
		C.tick(capped, Vector2.ZERO, 0.05)
	for r in capped.recruits:
		C.hurt(capped, r, 1000, Vector2.ZERO, "fixture", [])
	capped.x = D.PADS[0].x
	capped.z = D.PADS[0].y
	check(not C.buy(capped, 0) and capped.consumed[0] == 3 and C.valid(capped), "exhausted dead crews remain spent and valid; freed slots do not create recruits")
	C.hurt(s, s.recruits[0], 1000, Vector2.ZERO, "fixture", [])
	check(s.recruits[0].phase == "fallen" and s.recruits[0].slot == -1 and s.consumed[0] == 1 and s.stock[0] == 0, "death frees slot without refunding/duplicating consumed equipment")
	var target_fixture := C.fresh(D.mission(11))
	target_fixture.enemies = [{"id": 0, "role": "drone", "x": 0.0, "z": 1.0, "hp": 64.0}, {"id": 1, "role": "mortar", "x": 0.0, "z": 3.0, "hp": 82.0}, {"id": 2, "role": "bulwark", "x": 0.0, "z": 4.0, "hp": 145.0}]
	check(C.pick_target(target_fixture, Vector2.ZERO, 7.4, "ranger") == 1, "Ranger prioritizes distant mortar over nearby drone")
	check(C.pick_target(target_fixture, Vector2.ZERO, 5, "breaker") == 2, "Breaker prioritizes armored counter")
	check(C.pick_target(target_fixture, Vector2.ZERO, 0.5, "rover") == -1, "no target outside adopted range")
	var armor: Dictionary = target_fixture.enemies[2]
	var small := C.hit(target_fixture, armor, Vector2.ZERO, 10, "rifle", [])
	armor.hp = 145
	var piercing := C.hit(target_fixture, armor, Vector2.ZERO, 28, "breaker", [])
	check(is_equal_approx(small, 3.2) and piercing == 28, "specialist armor interaction changes real damage")
	var covered: Dictionary = target_fixture.enemies[1]
	covered.hp = 0.5
	var lethal_covered := C.hit(target_fixture, covered, Vector2.ZERO, 10, "rifle", [])
	check(covered.hp == 0 and lethal_covered == 0.5, "cover reduces damage before remaining-health clamp; a lethal hit cannot leave an immortal fractional remnant")
	var base := C.fresh(D.mission(11))
	base.phase = "playing"
	base.x = 0
	base.z = 2.8
	check(C.buy(base, 4) and base.wallet == 20 and base.support == "ward", "explicit support choice costs finite scrap")
	var before := base.duplicate(true)
	check(not C.buy(base, 4) and D.same(base, before), "occupied support cannot be purchased again")
	C.hurt(base, {}, 20, Vector2.ZERO, "fixture", [])
	check(is_equal_approx(base.hp, 107) and is_equal_approx(base.prevented, 7), "Ward causally prevents 35% incoming damage")
	var repair := C.fresh(D.mission(11))
	repair.phase = "playing"
	repair.planned_support = "recovery"
	repair.z = 2.8
	C.buy(repair, 4)
	C.hurt(repair, {}, 30, Vector2.ZERO, "fixture", [])
	C.tick(repair, Vector2.ZERO, 0.25)
	check(repair.hp > 90 and repair.support_used > 0 and C.valid(repair), "Recovery consumes finite repair budget on living commander")
	C.hurt(repair, {}, 1000, Vector2.ZERO, "fixture", [])
	var budget: float = repair.support_used
	C.tick(repair, Vector2.ZERO, 0.25)
	check(repair.phase == "defeat" and repair.hp == 0 and repair.support_used == budget and C.valid(repair), "fatal damage cannot be undone by same-tick repair")
	var edge := C.fresh(D.mission(0))
	edge.phase = "playing"
	edge.time = 1.999999999
	check(C.valid(edge) and S.decode(S.encode(edge, p, settings, 1, true, C.career())).ok, "sub-microsecond pre-arrival state survives decimal serialization")
	edge.time = 2.1
	check(not C.valid(edge), "missing arrival outside numeric tolerance rejected")
	var tiny := C.fresh(D.mission(0))
	tiny.phase = "playing"
	for i in 8:
		C.tick(tiny, Vector2.ZERO, 0.25)
	tiny.enemies[0].hp = 0.000000000001
	check(C.valid(tiny) and S.decode(S.encode(tiny, p, settings, 1, true, C.career())).ok, "strictly positive finite fractional enemy health is a valid active save")
	var carrier := C.fresh(D.mission(7))
	carrier.phase = "playing"
	carrier.time = 200
	carrier.spawned = carrier.definition.schedule.size()
	carrier.enemies = [{"id": 0, "role": "carrier", "x": 0.0, "z": -4.0, "hp": 680.0, "cooldown": 1.0, "telegraph": 0.0, "boss_clock": 0.0, "heal_left": 160.0}, {"id": 1, "role": "drone", "x": 0.5, "z": -4.0, "hp": 0.0, "cooldown": 1.0, "telegraph": 0.0, "boss_clock": 1.0, "heal_left": 0.0}, {"id": 2, "role": "drone", "x": -0.5, "z": -4.0, "hp": 10.0, "cooldown": 1.0, "telegraph": 0.0, "boss_clock": 1.0, "heal_left": 0.0}]
	var carrier_events := C.tick(carrier, Vector2.ZERO, 0.05)
	check(carrier.killed.has(1) and carrier.enemies[1].id == 2 and carrier.enemies[1].hp == 30, "Carrier's distinct finite pulse repairs living escorts without resurrecting killed drones")
	check(carrier.enemies[0].heal_left == 140 and carrier_events.any(func(e): return e.kind == "repair"), "Carrier repair consumes budget and emits causal visual event")
	var arc := C.career()
	var total := 0.0
	var last := {}
	for index in 12:
		var result := simulate(index, "ward" if index == 11 else "relay")
		check(result.phase == "victory", "substantive synthetic policy wins mission " + str(index + 1))
		check(result.commander_shots > 5 and result.commander_damage > 30, "commander field intervention useful mission " + str(index + 1))
		C.finish(result, arc)
		var frozen := arc.duplicate(true)
		C.finish(result, arc)
		check(D.same(frozen, arc) and arc.clears.size() == index + 1, "one-time victory and contiguous earned unlock " + str(index + 1))
		check(S.decode(S.encode(result, p, settings, index + 1, true, arc)).ok, "whole terminal run/definitions/career round trip " + str(index + 1))
		check(L.valid_profile(p) and p.attempts == 0 and p.wins == 0, "campaign wins never fabricate legacy prototype history")
		total += result.time
		records.append(result)
		last = result
	check(total >= 1800 and total <= 3600 and arc.ending and C.valid_career(arc), "twelve finite objectives yield complete 30–60-minute simulated arc and conclusive ending")
	var alternative := simulate(10, "ward", "B")
	check(alternative.phase == "victory" and alternative.purchases[0].station == 3 and records[10].purchases[0].station == 0, "two differently funded viable late investment orders")
	var mistaken := simulate(10, "ward", "mistake")
	check(mistaken.phase == "defeat" and mistaken.hq == 0 and alternative.killed.size() > mistaken.killed.size(), "rifle-only choice has diagnosable failure improved by specialist refit")
	var passive := simulate(5, "relay", "idle")
	check(passive.phase == "defeat" and passive.purchases.size() == 5 and records[5].phase == "victory", "optimal opening kit then passive safe camping loses: field intervention/replacement remains necessary")
	var recovered := simulate(7, "recovery")
	check(recovered.support_used > 0 and recovered.support_used <= 200.00001, "third support uses bounded healing in a real pressure encounter")
	var exhausted := last.duplicate(true)
	exhausted.phase = "playing"
	exhausted.recorded = false
	exhausted.cause = ""
	exhausted.support = "recovery"
	exhausted.planned_support = "recovery"
	for entry in exhausted.purchases:
		if entry.station == 4:
			entry.support = "recovery"
	C.hurt(exhausted, {}, 119, Vector2.ZERO, "fixture", [])
	exhausted.x = 0
	exhausted.z = -2
	# Synthetic simultaneous final-kill/ground-strike fixture, not an earned playthrough.
	var boss_id := 25
	exhausted.killed = exhausted.killed.filter(func(id): return int(id) != boss_id)
	for i in range(exhausted.coins.size() - 1, -1, -1):
		if exhausted.coins[i].id == boss_id:
			exhausted.coins.remove_at(i)
	if boss_id in exhausted.collected:
		exhausted.collected.erase(boss_id)
		exhausted.wallet -= 32
	exhausted.enemies = [{"id": boss_id, "role": "storm", "x": 0, "z": -2.5, "hp": 0.01, "cooldown": 2.0, "telegraph": 0.0, "boss_clock": 2.0, "heal_left": 0.0}]
	exhausted.marks = [{"x": 0, "z": -2, "remaining": 0.01, "source": boss_id}]
	exhausted.commander_cd = 0
	C.tick(exhausted, Vector2.ZERO, 0.05)
	C.finish(exhausted, arc)
	check(exhausted.phase == "defeat" and exhausted.hp == 0 and exhausted.killed.size() == exhausted.definition.schedule.size(), "simultaneous last kill/fatal blast resolves defeat before objective/repair")
	check(C.valid(exhausted) and S.decode(S.encode(exhausted, p, settings, 99, true, arc)).ok, "exhausted zero-health all-resolved terminal is a valid durable save")
	var code := S.encode(last, p, settings, 20, true, arc)
	for key in ["definition", "definition_hash", "wallet", "spent", "bought", "stock", "consumed", "recruits", "enemies", "captures", "support", "marks"]:
		var bad: Dictionary = JSON.parse_string(JSON.parse_string(code).payload)
		bad.state[key] = null
		check(not S.decode(wrap_packet(bad)).ok, "malformed whole campaign import rejected: " + key)
	for kind in ["money", "duplicate_reward", "duplicate_partition", "wrong_role", "duplicate_slot", "future_spawn", "profile_clear", "invalid_definition", "nan_position"]:
		var bad: Dictionary = JSON.parse_string(JSON.parse_string(code).payload)
		match kind:
			"money": bad.state.wallet += 1
			"duplicate_reward": bad.state.collected.append(bad.state.collected[0])
			"duplicate_partition": bad.state.escaped.append(bad.state.killed[0])
			"wrong_role": bad.state.recruits[0].role = "rover"
			"duplicate_slot": bad.state.recruits[9].slot = bad.state.recruits[7].slot
			"future_spawn": bad.state.time = 0
			"profile_clear": bad.career.clears.erase(D.IDS[0])
			"invalid_definition": bad.state.definition.enemy.mortar.damage = 0
			"nan_position": bad.state.x = "NaN"
		check(not S.decode(wrap_packet(bad)).ok, "conservation/definition/finite import guard: " + kind)
	var io := Faults.new()
	check(S.write(last, p, settings, "fault-", io, false, arc), "whole campaign atomic first write")
	var stable := S.read("fault-", io)
	for fault in ["fail_write", "fail_rename", "corrupt_readback"]:
		io.set(fault, true)
		check(not S.write(C.fresh(D.mission(0)), p, settings, "fault-", io, true, C.career()), "import reports storage failure " + fault)
		var held := S.read("fault-", io)
		check(D.same(held.state, stable.state) and D.same(held.career, stable.career) and D.same(held.settings, stable.settings), "failed import preserves whole prior run/career/settings " + fault)
		io.set(fault, false)
	check(S.write(last, p, settings, "fault-", io, false, arc), "subsequent ordinary save recovers")
	var latest := S.read("fault-", io)
	io.files["fault-" + str(latest.slot)] = "torn"
	check(S.read("fault-", io).ok, "torn newest stable falls back to intact older")
	var temp := Faults.new()
	temp.files["fault-0.tmp"] = S.encode(last, p, settings, 90, true, arc)
	check(S.read("fault-", temp).ok, "checked committed interrupted autosave temporary recovers")
	temp.files["fault-0.tmp"] = S.encode(last, p, settings, 91, false, arc)
	check(not S.read("fault-", temp).ok, "uncommitted imported temporary never becomes progress")
	var old := L.fresh()
	old.phase = "playing"
	for frame in 600:
		L.tick(old, Vector2.ZERO, 1.0 / 60)
	var legacy_payload := {"version": 1, "revision": 213, "committed": true, "state": old, "profile": {"attempts": 2, "wins": 1, "best_kills": 10}, "settings": settings}
	var legacy := S.decode(wrap_packet(legacy_payload))
	check(legacy.ok and D.same(legacy.state, old) and D.same(legacy.profile, legacy_payload.profile) and D.same(legacy.settings, settings), "schema1 whole legacy active state/profile/settings preserved; synthetic shape fixture only")
	check(legacy.career.clears.is_empty() and legacy.career.attempts == 0 and not legacy.career.ending, "prototype win never invents a campaign clear")
	var migrated := S.decode(S.encode(legacy.state, legacy.profile, legacy.settings, 214, true, legacy.career))
	check(migrated.ok and D.same(migrated.state, legacy.state) and D.same(migrated.profile, legacy.profile) and D.same(migrated.settings, legacy.settings), "schema2 legacy round trip preserves every prior field")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "simulated_arc_seconds": total, "outcomes": records, "late_alternative": alternative, "failed_choice": mistaken, "recovery_pressure": recovered, "simultaneous_terminal": exhausted, "scope": "Synthetic rules/save/fault/causal controls only. Distinct from actual engine-input routes and authentic native upgrade fixture."}, "  "))
	print("FRONTLINE_CAMPAIGN_RULES ", checks, " failures=", failures, " arc_seconds=", total)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
