extends SceneTree
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const Faults = preload("res://tests/fault_files.gd")
var checks := 0
var failures := 0
var details: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)

func route(s: Dictionary, purchase: bool = true, rover: bool = true) -> Dictionary:
	var valid_ticks := true
	var evidence := {"equipped": false, "departed": false, "rifle_damage": 0.0, "vehicle_damage": 0.0, "valid_ticks": true}
	for frame in 10000:
		if s.phase != "playing":
			break
		var goal := Vector2(0, 1.4) if purchase else Vector2(4.3, 5.5)
		if purchase and not s.pads[0]:
			goal = R.PADS[0]
			if R.nearby_pad(s) == 0:
				R.buy(s, 0)
		elif purchase and rover and not s.pads[1] and s.wallet >= 14:
			goal = R.PADS[1]
			if R.nearby_pad(s) == 1:
				R.buy(s, 1)
		elif purchase and (s.wallet < 14 or not s.pads[1]) and not s.coins.is_empty():
			goal = Vector2(s.coins[0].x, s.coins[0].z)
		R.tick(s, (goal - R.position(s)).limit_length(), 1.0 / 60)
		if not R.valid(s) and valid_ticks:
			print("INVALID FIRST ", JSON.stringify(s))
		valid_ticks = valid_ticks and R.valid(s)
		for r in s.recruits:
			evidence.equipped = evidence.equipped or r.phase == "equipping"
			evidence.departed = evidence.departed or r.phase == "deploying"
	evidence.rifle_damage = s.recruits[0].damage + s.recruits[1].damage + s.recruits[2].damage
	evidence.vehicle_damage = s.recruits[3].damage
	evidence.valid_ticks = valid_ticks
	return evidence

func wrap_packet(packet: Dictionary) -> String:
	var payload := JSON.stringify(packet)
	return JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})

func run() -> void:
	var s := R.fresh()
	check(R.valid(s), "fresh pinned catalog1 state is valid")
	check(s.wallet == 8 and s.coins[0].value == 6, "bootstrap can buy rifles without fighting or waiting")
	check(not R.buy(s, 0), "no purchase in ready state")
	s.phase = "playing"
	check(not R.buy(s, -1) and not R.buy(s, 2) and not R.buy(s, 0), "invalid or remote station refused")
	s.x = R.PADS[0].x
	s.z = R.PADS[0].y
	R.tick(s, Vector2.ZERO, 0.01)
	check(s.spent == 0 and s.wallet == 8, "standing on pad never spends automatically")
	check(R.buy(s, 0) and s.wallet == 0 and s.stock == [3, 0], "exact8 purchase creates three rifle tokens")
	var old := s.duplicate(true)
	check(not R.buy(s, 0) and s == old, "occupied station cannot charge twice")
	R.tick(s, Vector2.ZERO, 0.01)
	check(s.recruits[0].phase == "equipping" and s.recruits[1].phase == "waiting" and s.stock == [2, 0] and s.consumed == [1, 0], "station arms exactly its queue head and consumes one token")
	check(s.recruits[3].phase == "waiting", "rifle investment cannot equip vehicle queue")
	for frame in 250:
		R.tick(s, Vector2.ZERO, 1.0 / 60)
	check(s.consumed == [3, 0] and s.stock == [0, 0], "all three rifle tokens consumed exactly once")
	check(s.recruits[0].phase == "fighting" and s.recruits[0].z < 0, "first recruit crosses unobstructed gate and reaches front")
	check(s.recruits[3].shots == 0 and s.recruits[3].phase == "waiting", "unpaid vehicle has no combat effect")
	s.x = R.PADS[1].x
	s.z = R.PADS[1].y
	check(not R.buy(s, 1), "insufficient rover funds refused")
	var enemies := [{"id": 0, "x": 0.0, "z": -2.0, "hp": 1.0}, {"id": 1, "x": 0.0, "z": -1.0, "hp": 1.0}, {"id": 2, "x": 0.0, "z": -0.2, "hp": 0.0}]
	check(R.target(enemies, Vector2.ZERO, 3) == 1 and R.target(enemies, Vector2.ZERO, 0.5) == -1, "nearest living target in range; no dead/out-of-range shot")
	var best := R.fresh()
	best.phase = "playing"
	var chain := route(best)
	print("SYNTHETIC_ROUTE ", JSON.stringify({"state": best, "chain": chain}))
	check(chain.valid_ticks, "all synthetic route states pass structural/economy checks")
	check(best.phase == "victory" and best.pads == [true, true], "complete causal route naturally breaks finite siege")
	check(chain.equipped and chain.departed and chain.rifle_damage > 100 and chain.vehicle_damage > 100, "equipping, departure and both independent reinforcement attacks consequential")
	check(best.consumed == [3, 1] and best.stock == [0, 0], "four-unit cap and both equipment ledgers conserved")
	check(best.recruits.all(func(r): return r.phase not in ["equipping", "deploying"]), "no armed recruit stranded permanently at gate")
	var first_only := R.fresh()
	first_only.phase = "playing"
	route(first_only, true, false)
	check(first_only.phase == "defeat" and first_only.killed.size() < best.killed.size(), "counterfactual rifle-only route loses: vehicle changes outcome")
	var none := R.fresh()
	none.phase = "playing"
	route(none, false)
	print("COUNTERFACTUALS ", JSON.stringify({"rifle_only": first_only, "no_supply": none}))
	check(none.phase == "defeat" and none.hq == 0 and none.killed.size() < best.killed.size(), "starter defense alone loses: supplied force changes fight")
	# Paired synthetic control: same safe commander, only rifle investment differs.
	var supplied := R.fresh()
	supplied.phase = "playing"
	supplied.x = R.PADS[0].x
	supplied.z = R.PADS[0].y
	R.buy(supplied, 0)
	supplied.x = 4.3
	supplied.z = 5.5
	for frame in 10000:
		if supplied.phase != "playing":
			break
		R.tick(supplied, Vector2.ZERO, 1.0 / 60)
	check(supplied.commander_shots == 0 and supplied.killed.size() > none.killed.size() and supplied.time > none.time, "rifle-only causal control: safe inactive commander, recruits earn additional kills and extend defense")
	check(supplied.recruits[0].shots > 0 and supplied.recruits[0].damage > 0, "causal control attributed to individually armed recruit attacks")
	var death := R.fresh()
	death.phase = "playing"
	death.x = -1.7
	death.z = -5.7
	for frame in 5000:
		R.tick(death, Vector2.ZERO, 1.0 / 60)
		if death.phase != "playing":
			break
	check(death.phase == "defeat" and death.hp == 0 and death.hq > 0, "commander death is independent terminal condition")
	var p := R.profile()
	R.finish(best, p)
	var earned := p.duplicate(true)
	R.finish(best, p)
	check(p == earned and p.wins == 1 and p.attempts == 1, "terminal reward idempotent; one attempt and win")
	var settings := {"sound": false, "reduced_effects": true}
	var code := S.encode(best, p, settings, 8)
	check(S.decode(code).ok, "whole checked state/settings/profile round trip")
	check(not S.decode(code + "x").ok and not S.decode("x".repeat(S.LIMIT + 1)).ok, "corrupt and oversized import rejected")
	var unrecorded := best.duplicate(true)
	unrecorded.recorded = false
	check(not S.decode(S.encode(unrecorded, p, settings, 9)).ok, "terminal save must include committed attempt accounting")
	var envelope: Dictionary = JSON.parse_string(code)
	envelope.sha256 = "bad"
	check(not S.decode(JSON.stringify(envelope)).ok, "checksum tamper rejected")
	for field in ["wallet", "spent", "hq", "hp", "spawned", "catalog", "seed", "phase", "recruits", "coins", "killed", "consumed", "stock", "pads"]:
		var packet: Dictionary = JSON.parse_string(JSON.parse_string(code).payload)
		packet.state[field] = null
		check(not S.decode(wrap_packet(packet)).ok, "malformed state " + field + " rejected")
	for field in ["version", "revision", "settings", "profile", "state"]:
		var packet: Dictionary = JSON.parse_string(JSON.parse_string(code).payload)
		packet[field] = null
		check(not S.decode(wrap_packet(packet)).ok, "malformed envelope " + field + " rejected")
	for mutation in ["duplicate_reward", "unearned_coin", "inflated_wallet", "duplicate_enemy", "equipment", "wrong_role", "extra_recruit", "faked_victory"]:
		var bad := best.duplicate(true)
		match mutation:
			"duplicate_reward": bad.collected.append(bad.collected[0])
			"unearned_coin": bad.coins.append({"id": 98, "value": 8, "x": 0, "z": 0})
			"inflated_wallet": bad.wallet += 1
			"duplicate_enemy": bad.killed.append(bad.killed[0])
			"equipment": bad.consumed[0] = 0
			"wrong_role": bad.recruits[0].role = "vehicle"
			"extra_recruit": bad.recruits.append(bad.recruits[0])
			"faked_victory": bad.hq = 0
		check(not R.valid(bad), "semantic save tamper " + mutation + " rejected")
	var io := Faults.new()
	check(S.write(best, p, settings, "test-", io), "first atomic slot write")
	var baseline := S.read("test-", io)
	check(baseline.ok and same(baseline.state, best) and baseline.revision == 1, "one stable slot restores whole state")
	for fault in ["fail_write", "corrupt_readback", "fail_rename"]:
		io.set(fault, true)
		check(not S.write(R.fresh(), p, settings, "test-", io, true), "import fails safely on " + fault)
		check(same(S.read("test-", io).state, best), "failed import retains stable prior on " + fault)
		io.set(fault, false)
	check(S.write(R.fresh(), p, settings, "test-", io), "ordinary checkpoint writes after fault")
	check(S.read("test-", io).state.phase == "ready", "highest valid revision restored")
	io.files["test-0"] = "torn"
	check(S.read("test-", io).ok, "torn older slot leaves newest valid state")
	var tmp := Faults.new()
	tmp.files["test-0.tmp"] = S.encode(best, p, settings, 2, true)
	check(S.read("test-", tmp).ok, "committed autosave temporary recovers after interrupted rename")
	tmp.files["test-0.tmp"] = S.encode(best, p, settings, 3, false)
	check(not S.read("test-", tmp).ok, "uncommitted imported temporary never replaces progress")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "scope": "Synthetic rule/save fixtures, not playthrough evidence", "complete": best, "rifle_only": first_only, "no_stations": none, "commander_loss": death}, "  "))
	print("FRONTLINE_RULES ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
