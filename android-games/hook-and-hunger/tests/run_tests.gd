extends SceneTree
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const Fault = preload("res://tests/fault_files.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var s := R.fresh()
	check(R.valid(s), "fresh state valid")
	for i in 1000:
		R.step(s, Vector2(1, -1), 0.05)
	check(s.x <= 5.6 and s.z >= -6.0, "closed gate and world bounds")
	check(R.position(s).distance_to(Vector2(3.8, -2)) >= 1.35, "rock collision")
	check(not R.line_clear(Vector2(2, -2), Vector2(5, -2)), "rock blocks chained strikes")
	s = R.fresh()
	s.x = 0.0
	s.z = 0.0
	check(R.target(s) == -1, "out of reach cannot select")
	s.x = -2.8
	s.z = 4.0
	check(R.target(s) == 0, "nearest in reach target selected")
	R.step(s, Vector2.ZERO, 0.05)
	check(s.strike > 0 and s.enemies[0].hp == 24, "launch precedes damage")
	for i in 4:
		R.step(s, Vector2.ZERO, 0.05)
	check(s.enemies[0].hp == 12, "single contact damage applied")
	for i in 3:
		R.step(s, Vector2.ZERO, 0.05)
	check(s.enemies[0].hp == 12, "contact cannot repeat within swing")
	s = R.fresh()
	s.x = -2.8
	s.z = 4.0
	R.step(s, Vector2.ZERO, 0.05)
	s.x = 4.9
	for i in 5:
		R.step(s, Vector2.ZERO, 0.05)
	check(s.enemies[0].hp == 24, "moving out of reach before contact misses")
	var duel := R.fresh()
	duel.x = -2.8
	duel.z = 2.0
	duel.enemies = [duel.enemies[0]]
	duel.cooldown = 100.0
	R.step(duel, Vector2.ZERO, 0.05)
	check(duel.enemies[0].mode == "wind" and duel.hp == 100, "enemy exposes windup before damaging")
	for i in 12:
		R.step(duel, Vector2.ZERO, 0.05)
	check(duel.hp == 100, "windup grants escape interval")
	for i in 2:
		R.step(duel, Vector2.ZERO, 0.05)
	check(duel.hp == 88 and duel.enemies[0].mode == "recover", "one declared hit enters recovery")
	for i in 10:
		R.step(duel, Vector2.ZERO, 0.05)
	check(duel.hp == 88, "enemy recovery prevents continuous contact damage")
	duel = R.fresh()
	duel.x = -2.8
	duel.z = 2.0
	duel.enemies = [duel.enemies[0]]
	duel.cooldown = 100.0
	R.step(duel, Vector2.ZERO, 0.05)
	for i in 15:
		R.step(duel, Vector2(0, 1), 0.05)
	check(duel.hp == 100, "leaving locked windup disk avoids damage")
	duel = R.fresh()
	var before_z: float = duel.z
	R.step(duel, Vector2(0, -1), 5.0)
	check(before_z - float(duel.z) < 0.201, "large frame delta cannot teleport through world")
	var frozen := R.fresh()
	frozen.phase = "defeat"
	frozen.hp = 0.0
	var frozen_bytes := JSON.stringify(frozen)
	R.step(frozen, Vector2.ONE, 0.05)
	check(JSON.stringify(frozen) == frozen_bytes, "terminal phase freezes all combat and movement")
	s = R.fresh()
	check(not R.purchase(s), "insufficient salvage rejected")
	for id in 5:
		R._kill(s, s.enemies[id])
	s.enemies = s.enemies.filter(func(e: Dictionary) -> bool: return not int(e.id) in s.dead)
	for d in s.drops:
		s.wallet += int(R.ROSTER[int(d.id)].reward)
		s.collected.append(int(d.id))
	s.drops.clear()
	check(s.wallet == 42 and R.valid(s), "first pen contains enough finite salvage")
	var far := s.duplicate(true)
	far.z = 3.0
	check(not R.purchase(far) and far.wallet == 42, "purchase requires actual pad proximity")
	s.hp = 12.0
	check(R.purchase(s), "pad purchase works with earned salvage")
	check(s.wallet == 6 and s.hp == 100 and s.tier == 1, "purchase debits once and fully heals")
	check(R.weapon(s).damage > R.WEAPONS[0].damage * 2 and R.weapon(s).reach > R.WEAPONS[0].reach, "tangible damage and reach upgrade")
	check(not R.purchase(s) and s.wallet == 6, "owned purchase cannot duplicate")
	s.hp = 0.0
	s.phase = "defeat"
	var balance: int = s.wallet
	var dead: Array = s.dead.duplicate()
	check(R.retry(s), "retry available after natural phase")
	check(s.wallet == balance and s.dead == dead and s.tier == 1 and s.hp == 100, "retry preserves earned economy and heals")
	check(s.enemies.size() == 3 and R.valid(s), "dead enemies cannot respawn for farming")
	var counts: int = s.drops.size()
	R._kill(s, {"id": 0, "x": 0.0, "z": 0.0})
	check(s.drops.size() == counts and s.wallet == balance, "repeated death event cannot mint salvage")
	for i in 200:
		R.step(s, Vector2(0, -1), 0.05)
	check(s.z < -6.5, "power opens central gate")
	var roundtrip := R.restore(JSON.parse_string(JSON.stringify(s)))
	check(not roundtrip.is_empty() and R.valid(roundtrip), "JSON state round trip")
	var settings := {"sound": true, "reduced_effects": false}
	var text := S.encode(s, settings, 12)
	check(S.decode(text).ok, "checked export decode")
	check(not S.decode(text.replace("sha256", "broken")).ok, "corrupt envelope rejected")
	for mutation in ["wallet", "tier", "dead", "collected", "enemies", "hp", "phase", "schema", "cooldown", "strike", "infinite", "missing"]:
		var bad := s.duplicate(true)
		match mutation:
			"wallet": bad.wallet += 1
			"tier": bad.tier = 0.5
			"dead": bad.dead.append(0)
			"collected": bad.collected.append(7)
			"enemies": bad.enemies.append(bad.enemies[0].duplicate())
			"hp": bad.hp = -1
			"phase": bad.phase = "victory"
			"schema": bad.schema = 2
			"cooldown": bad.cooldown = 5.0
			"strike": bad.strike = 0.6
			"infinite": bad.time = INF
			"missing": bad.erase("x")
		check(not R.valid(bad), "reject invalid " + mutation)
	var io := Fault.new()
	check(S.write(s, settings, "save", io), "first slot write")
	check(S.read("save", io).state.wallet == balance, "read first slot")
	io.fail_write = true
	check(not S.write(s, settings, "save", io), "partial write surfaced")
	check(S.read("save", io).ok, "partial write retains newest slot")
	io.fail_write = false
	io.fail_rename = true
	check(not S.write(s, settings, "save", io), "rename failure surfaced")
	var recovered := S.read("save", io)
	check(recovered.ok and recovered.recovered, "complete interrupted save recovers")
	io.fail_write = true
	check(not S.write(s, settings, "save", io), "next partial write fails")
	check(S.read("save", io).source == recovered.source, "sole staged newest save never truncated")
	io.fail_write = false
	io.fail_rename = false
	check(S.write(s, settings, "save", io), "later write recovers normally")
	var before := S.read("save", io)
	io.fail_rename = true
	check(not S.write(R.fresh(), settings, "save", io, true), "failed import refused")
	check(S.read("save", io).source == before.source, "failed import cannot activate on next launch")
	io.fail_rename = false
	check(S.write(R.fresh(), settings, "save", io, true), "committed import works")
	check(S.read("save", io).state.dead.is_empty(), "committed import becomes active")
	print("HOOK_RULES: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func check(okay: bool, message: String) -> void:
	checks += 1
	if not okay:
		failures += 1
		push_error(message)

