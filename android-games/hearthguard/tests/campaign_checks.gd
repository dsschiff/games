extends SceneTree
const C = preload("res://scripts/campaign_rules.gd")
const Cat = preload("res://scripts/campaign_catalog.gd")
const L = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const Policy = preload("res://tests/campaign_policy.gd")
const Faults = preload("res://tests/fault_files.gd")
var checks := 0
var failures := 0
var details: Array = []
var outcomes: Array = []
var folder := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)

func simulate(stage: int, variant: int = 0, seed: int = 1, budget: int = 0, mirror: bool = false, endless: int = -1) -> Dictionary:
	var s := C.fresh(Cat.definition(stage, seed, budget, mirror, endless))
	s.phase = "playing"
	for frame in 40000:
		if s.phase != "playing":
			break
		var plan := Policy.plan(s, variant)
		if plan.affordable and C.position(s).distance_to(plan.goal) < 1.4:
			C.action(s, plan.pad, plan.choice)
		C.tick(s, (plan.goal - C.position(s)).limit_length(), 1.0 / 60)
	return s

func run() -> void:
	var profile := C.profile()
	var legacy := L.profile()
	var settings := {"sound": false, "reduced_effects": true}
	var total := 0.0
	var final: Dictionary
	for stage in 10:
		var s := simulate(stage, 1 if stage == 8 else 0)
		C.finish(s, profile)
		check(s.phase == "victory", "rules route naturally clears map " + str(stage + 1))
		check(C.valid(s) and C.valid_profile(profile), "terminal and complete profile valid on map " + str(stage + 1))
		check(S.decode(S.encode(s, legacy, settings, 1, true, profile)).ok, "whole pinned terminal/profile round-trip map " + str(stage + 1))
		check(s.ledger.size() >= 6, "multiple useful investments map " + str(stage + 1))
		var finished := profile.duplicate(true)
		C.finish(s, profile)
		check(profile == finished, "terminal credit idempotent map " + str(stage + 1))
		total += s.time
		outcomes.append({"stage": stage, "phase": s.phase, "time": s.time, "leaks": s.leaked.size(), "actions": s.ledger, "shots": s.shots})
		final = s
	check(total >= 1800 and total <= 3600, "scripted rule simulation arc in 30–60 minutes; human timing unverified")
	check(profile.clears.size() == 10 and profile.ending, "ten unique clears unlock conclusive ending")
	for stage in [6, 7, 9]:
		var alternate := simulate(stage, 1)
		check(alternate.phase == "victory", "second funded family/layout route late map " + str(stage + 1))
		check(alternate.ledger != outcomes[stage].actions, "alternative is a different funded layout, map " + str(stage + 1))
	var replay := simulate(9, 0, 42, 1, true)
	check(replay.phase == "victory", "different seeded mirrored rich-budget final replay viable")
	check(not C.equivalent(replay.definition, final.definition), "seed/options change full pinned replay definition")
	var endless := simulate(9, 0, 7, 0, false, 0)
	C.finish(endless, profile)
	check(endless.phase == "victory" and profile.endless_best.get("7", 0) == 1, "seeded endless watch earns separate record")
	var missing_endless := profile.duplicate(true)
	missing_endless.endless_best.clear()
	check(not S.decode(S.encode(endless, legacy, settings, 1, true, missing_endless)).ok, "exhausted endless victory requires its earned survival credit")
	check(profile.clears.size() == 10, "endless does not invent extra campaign clears")
	var s := C.fresh(Cat.definition(0))
	check(not C.valid_definition(Cat.definition(0, 1, 0, false, 0)), "unsupported early-stage endless definition rejected")
	check(C.valid(s) and C.valid_definition(s.definition), "new ready snapshot validates")
	s.phase = "playing"
	for coin in s.coins.duplicate(true):
		s.x = coin.x
		s.z = coin.z
		C.tick(s, Vector2.ZERO, 0.016)
	check(s.wallet == 18 and s.collected.size() == 6, "finite bootstrap is all obtainable")
	var before := s.duplicate(true)
	check(not C.action(s, -1, 0) and not C.action(s, 100, 0) and not C.action(s, 0, 3), "invalid pad/choice rejected")
	check(s == before, "failed action leaves whole state unchanged")
	s.x = s.definition.pads[2].x
	s.z = s.definition.pads[2].z
	C.tick(s, Vector2.ZERO, 0.016)
	check(s.wallet == 18 and s.ledger.is_empty(), "crossing pad never spends")
	check(C.action(s, 2, 0) and s.wallet == 8, "exact funded Bolt purchase")
	check(not C.action(s, 2, 0), "occupied purchase becomes priced unaffordable fork")
	check(C.action(s, 2, 2) and s.wallet == 15 and s.refunded == 7, "sell returns exactly 70 percent")
	check(C.action(s, 2, 1) and s.wallet == 3, "refit builds different family with real cost")
	check(C.valid(s), "build/sell/refit ledger reconciles")
	# Synthetic UI-context fixtures; not additions to the earned input route.
	var control := Node3D.new()
	control.set_script(load("res://scripts/campaign_main.gd"))
	control.state = s.duplicate(true)
	control.state.wallet = 100
	control.arm_action(2)
	control.state.x = s.definition.pads[3].x
	control.state.z = s.definition.pads[3].z
	var held: Dictionary = control.state.duplicate(true)
	control.invest(2)
	check(control.state == held, "held contextual action cannot move to a different pad")
	control.state = s.duplicate(true)
	control.arm_action(2)
	control.state.towers[2].fork = 1
	held = control.state.duplicate(true)
	control.invest(2)
	check(control.state == held, "held contextual action cannot become a different fork/sale")
	control.free()
	var fraction := s.duplicate(true)
	while fraction.enemies.is_empty():
		C.tick(fraction, Vector2.ZERO, 1.0 / 60)
	var residue := 7.0
	for i in 20:
		residue -= 0.35
	fraction.enemies[0].hp = residue
	check(residue > 0 and residue < 0.000001, "fractional damage can leave a genuine positive health residue")
	check(C.valid(fraction) and S.decode(S.encode(fraction, legacy, settings, 1, true, C.profile())).ok, "positive sub-micro health remains saveable without retuning combat")
	fraction.enemies[0].hp = 0
	check(not C.valid(fraction), "zero-health living actor still rejected")
	for field in ["price", "upgrades", "stats"]:
		var malformed := s.duplicate(true)
		malformed.definition.families[0][field] = null
		check(not C.valid(malformed), "pinned tower snapshot rejects malformed " + field)
	for field in ["wallet", "spent", "refunded", "integrity", "spawned", "time"]:
		var bad := s.duplicate(true)
		bad[field] = -100
		check(not C.valid(bad), "bounds reject invalid " + field)
	for field in ["hp", "reward", "speed", "armor", "t", "lane", "id"]:
		var bad := s.duplicate(true)
		bad.definition.roster[0][field] += 0.01
		check(not C.valid(bad), "pinned definition rejects modified " + field)
	var bad := s.duplicate(true)
	bad.definition.roster[0].id += 0.00000000001
	check(not C.valid(bad), "integer definition IDs exact even under fractional noise")
	bad = s.duplicate(true)
	bad.collected.append(bad.collected[0])
	check(not C.valid(bad), "unique coin ownership enforced")
	bad = s.duplicate(true)
	bad.ledger[0].choice = 2
	check(not C.valid(bad), "occupied/refunded purchase ledger cannot change retroactively")
	bad = final.duplicate(true)
	bad.phase = "playing"
	bad.credited = false
	check(not C.valid(bad), "exhausted living battlefield must be terminal")
	check(C.valid(final), "legitimate exhausted victory remains importable")
	var lost := C.fresh(Cat.definition(0))
	lost.phase = "playing"
	for frame in 30000:
		if lost.phase != "playing":
			break
		C.tick(lost, Vector2.ZERO, 1.0 / 60)
	var lost_profile := C.profile()
	C.finish(lost, lost_profile)
	check(lost.phase == "defeat" and C.valid(lost), "legitimate leak-driven exhausted/partial loss validates")
	check(C.fresh(final.definition).definition == final.definition, "Retry pins exact complete definition/options")
	var boundary := C.fresh(Cat.definition(0))
	boundary.phase = "playing"
	for frame in 8000:
		var plan := Policy.plan(boundary)
		if plan.affordable and C.position(boundary).distance_to(plan.goal) < 1.4:
			C.action(boundary, plan.pad, plan.choice)
		C.tick(boundary, (plan.goal - C.position(boundary)).limit_length(), 1.0 / 60)
		if absf(boundary.time - 126.0) < 0.00000001:
			break
	check(boundary.spawned == 59 and C.valid(boundary) and S.decode(S.encode(boundary, legacy, settings, 1, true, C.profile())).ok, "legitimate pre-final-spawn floating boundary remains saveable")
	bad = boundary.duplicate(true)
	bad.time = 126.0001
	check(not C.valid(bad), "materially missing past spawn still rejected")
	C.tick(boundary, Vector2.ZERO, 1.0 / 60)
	var boundary_profile := C.profile()
	C.finish(boundary, boundary_profile)
	check(boundary.phase == "victory" and C.valid(boundary) and S.decode(S.encode(boundary, legacy, settings, 1, true, boundary_profile)).ok, "next-frame legitimate exhausted terminal remains saveable")
	var io := Faults.new()
	check(S.write(final, legacy, settings, "campaign", io, false, profile), "campaign durable baseline")
	var good := S.read("campaign", io)
	for fault in ["fail_write", "corrupt_readback", "fail_rename", "missing_destination", "corrupt_destination"]:
		io.set(fault, true)
		check(not S.write(lost, legacy, settings, "campaign", io, true, lost_profile), "failed import transaction: " + fault)
		var kept := S.read("campaign", io)
		check(kept.state == good.state and kept.campaign == good.campaign and kept.settings == good.settings and kept.profile == good.profile, "whole-state durable retention: " + fault)
		io.set(fault, false)
	var code := S.encode(final, legacy, settings, 1, true, profile)
	var packet: Dictionary = JSON.parse_string(JSON.parse_string(code).payload)
	packet.erase("campaign")
	var payload := JSON.stringify(packet)
	check(not S.decode(JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})).ok, "schema2 cannot silently invent missing campaign profile")
	check(not S.decode("x".repeat(S.LIMIT + 1)).ok, "import byte limit enforced")
	check_bosses()
	# Synthetic old-format wrapper, separate from root's real device migration.
	var old_state := L.fresh()
	var old_payload := JSON.stringify({"version": 1, "state": old_state, "profile": legacy, "settings": settings, "revision": 164, "committed": true})
	var decoded := S.decode(JSON.stringify({"payload": old_payload, "sha256": old_payload.sha256_text()}))
	check(decoded.ok and decoded.campaign.clears.is_empty() and not decoded.campaign.ending, "old prototype profile invents no campaign clears")
	check(decoded.state == JSON.parse_string(JSON.stringify(old_state)) and decoded.profile == JSON.parse_string(JSON.stringify(legacy)), "old state/profile meaning retained without rule migration")
	var old_win := L.fresh()
	old_win.phase = "playing"
	for frame in 8000:
		if old_win.phase != "playing":
			break
		var goal := L.position(old_win)
		if not old_win.coins.is_empty():
			goal = Vector2(old_win.coins[0].x, old_win.coins[0].z)
		for pad in 2:
			if old_win.pads[pad] == 0 and old_win.wallet >= L.COSTS[pad]:
				goal = L.PADS[pad]
				if L.position(old_win).distance_to(goal) <= L.BUILD_DISTANCE:
					L.buy(old_win, pad)
				break
		L.tick(old_win, (goal - L.position(old_win)).limit_length(), 1.0 / 60)
	var old_winner := L.profile()
	L.finish(old_win, old_winner)
	var legacy_park := C.profile()
	legacy_park.legacy_snapshot = old_win
	check(old_win.phase == "victory" and not S.decode(S.encode(C.fresh(Cat.definition(0)), legacy, settings, 1, true, legacy_park)).ok, "inconsistent parked legacy terminal/profile rejected before import")
	check(S.decode(S.encode(C.fresh(Cat.definition(0)), old_winner, settings, 1, true, legacy_park)).ok, "matching parked legacy terminal/profile remains available")
	var old_expedition := C.profile()
	old_expedition.legacy_snapshot = decoded.state.duplicate(true)
	var parked := C.fresh(Cat.definition(0))
	old_expedition.parked = parked
	check(S.decode(S.encode(decoded.state, decoded.profile, decoded.settings, 165, true, old_expedition)).ok, "parked campaign and legacy mode coexist without losing old meaning")
	print("CAMPAIGN_RULES: ", checks, " checks, failures=", failures, " scripted_arc_seconds=", total)
	if not folder.is_empty():
		var f := FileAccess.open(folder.path_join("campaign-rules.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "outcomes": outcomes, "scripted_rule_seconds": total, "scope": "Synthetic rules/config/fault fixtures. Not input-earned or human duration, and not root's actual native upgrade."}, "  "))
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func boss_fixture(stage: int) -> Dictionary:
	var s := C.fresh(Cat.definition(stage))
	s.phase = "playing"
	s.spawned = s.definition.roster.size()
	for spec in s.definition.roster:
		if spec.role in ["ram", "matriarch", "regent"]:
			s.enemies = [{"id": spec.id, "z": 0.0, "hp": float(spec.hp), "lane": spec.lane, "slow": 0.0, "factor": 1.0, "heal": 0.0}]
			s.time = spec.t + 0.5
			break
	return s

func check_bosses() -> void:
	# These intentionally manufactured combat fixtures do not claim earned saves.
	var shielded := boss_fixture(2)
	shielded.towers[2] = {"family": 0, "fork": 1, "invested": 40, "cooldown": 0.0, "priority": 0, "jam": 0.0}
	var unshielded := shielded.duplicate(true)
	unshielded.time += 4
	var hp: float = shielded.enemies[0].hp
	C.tick(shielded, Vector2.ZERO, 0.016)
	C.tick(unshielded, Vector2.ZERO, 0.016)
	check(hp - shielded.enemies[0].hp < hp - unshielded.enemies[0].hp, "Ram shield phase materially reduces even piercing shot damage")
	var brood := boss_fixture(5)
	var ally := {"id": 0, "z": 0.1, "hp": 1.0, "lane": 0, "slow": 0.0, "factor": 1.0, "heal": 0.0}
	brood.enemies.append(ally)
	C.tick(brood, Vector2.ZERO, 0.016)
	check(ally.hp > 1.0, "Matriarch actively heals its wounded nearby column")
	var regent := boss_fixture(9)
	var birth: float = regent.definition.roster[int(regent.enemies[0].id)].t
	regent.towers[7] = {"family": 0, "fork": 1, "invested": 40, "cooldown": 0.0, "priority": 0, "jam": 0.0}
	regent.time = birth + 9.2
	C.tick(regent, Vector2.ZERO, 0.016)
	check(regent.towers[7].jam > 0 and regent.shots[0] == 0, "Regent silence actually prevents a charged nearby tower firing")
	regent.time = birth + 11.1
	C.tick(regent, Vector2.ZERO, 0.016)
	check(regent.enemies[0].lane == 1, "Regent switches the threatened road")
