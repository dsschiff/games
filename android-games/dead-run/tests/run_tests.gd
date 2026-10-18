extends SceneTree
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const F = preload("res://tests/fault_files.gd")
const Exhaustion = preload("res://tests/exhaustion_fixture.gd")
var checks := 0
var failures := 0
var details: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(okay: bool, label: String) -> void:
	checks += 1
	details.append({"pass": okay, "label": label})
	if not okay:
		failures += 1
		print("FAIL ", label)

func equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not equal(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not equal(a[i], b[i]):
				return false
		return true
	if a is float and b is float:
		return absf(a - b) < 0.000000001
	return a == b

func run() -> void:
	for survives in [false, true]:
		var fixture := Exhaustion.make(survives)
		var config := {"sound": false, "reduced_effects": true}
		check(R.valid(fixture), "synthetic exhaustion fixture valid before step; survives=" + str(survives))
		check(S.decode(S.encode(fixture, config, 1)).ok, "synthetic exhaustion fixture importable before step; survives=" + str(survives))
		R.step(fixture)
		check(R.valid(fixture), "exhaustion boundary valid after ordinary step; survives=" + str(survives))
		check(S.decode(S.encode(fixture, config, 2)).ok, "exhaustion boundary remains save-decodable; survives=" + str(survives))
		check(fixture.leaks == 1 and fixture.contact == 1, "paired fixture actually applies same-tick contact")
		if survives:
			check(fixture.phase == "playing" and fixture.crew == 4 and fixture.joined == 9 and fixture.lost == 8, "living formation receives legitimate same-tick crane recruits")
			check(fixture.side_hp == 0 and fixture.side_claimed, "living queued projectile finishes crane and claims payout")
		else:
			check(fixture.phase == "defeat" and fixture.crew == 0 and fixture.joined == 4 and fixture.lost == 7, "exhaustion precedes queued impacts; no revival or recruit payout")
			check(fixture.side_hp == 1 and not fixture.side_claimed and fixture.bullets[0].z == 11.99, "fatal contact freezes queued projectile before crane impact")
			var terminal := fixture.duplicate(true)
			R.step(fixture)
			check(fixture == terminal, "fatal boundary is stable on subsequent step")
	var s := R.fresh()
	check(R.valid(s), "fresh pinned run validates")
	check(S.decode(S.encode(s, {"sound": true, "reduced_effects": false}, 0)).ok, "ready save survives JSON type normalization")
	check(s.seed == 61723 and s.enemies.size() == 24, "fixed seed and authored roster")
	for count in range(1, 13):
		for i in count:
			check(absf(R.offset(i, count).x) + 0.24 <= R.half_width(count) + 0.00001, "visible footprint bounds crew %d/%d" % [i, count])
	var g: Dictionary = s.gates[0]
	R.gate_hit(g)
	check(g.value == -5 and g.hits == 1, "one original bullet adds one signed gate point")
	for i in 30:
		R.gate_hit(g)
	check(g.value == 6, "gate cap prevents opaque explosive growth")
	R.cross(s, g)
	check(s.crew == 9 and g.applied == 6, "positive crossing adds six actual crew")
	R.cross(s, g)
	check(s.crew == 9, "same gate cannot grant twice")
	R.add_crew(s, 100)
	check(s.crew == 12, "formation cap")
	R.steer(s, 999)
	check(s.aim == 4.35 - R.half_width(12), "steering clamps whole formation")
	check(R.overlap(0, 12, 1.8, 0.9) and not R.overlap(0, 1, 1.8, 0.9), "wide formation has explicit wider collision")
	s = R.fresh()
	s.x = 2.65
	R.cross(s, s.gates[1])
	check(s.crew == 0 and s.gates[1].applied == -12, "untouched harmful gate removes crew deterministically")
	s = R.fresh()
	check(R.hit(s, {"x": 0.0, "z": 16.0}, 0.0) and s.gates[0].hits == 1, "swept projectile strikes gate")
	check(not R.hit(s, {"x": 4.0, "z": 30.0}, 0.0), "out of column shot misses")
	s = R.fresh()
	s.tick = 600
	s.enemies[0].z = 4.0
	check(R.hit(s, {"x": 0.0, "z": 20.0}, 0.0) and s.enemies[0].hp == 2 and s.gates[0].hits == 0, "nearest infected intercepts fire before farther gate")
	s = R.fresh()
	s.tick = 2160
	s.gates[0].crossed = true
	for e in s.enemies: e.resolved = true
	for i in 40: R.hit(s, {"x": 0.0, "z": 25.0}, 0.0)
	check(s.final_hp == 0 and s.final_hits == 40, "final blockade consumes exactly forty original projectile hits")
	s = R.fresh()
	for i in 119:
		R.hit(s, {"x": -2.65, "z": 13.0}, 0.0)
	check(s.side_hp == 1 and s.crew == 3, "side target requires sustained hits")
	R.hit(s, {"x": -2.65, "z": 13.0}, 0.0)
	check(s.side_hp == 0 and s.side_claimed and s.crew == 6, "last side hit grants three once")
	R.hit(s, {"x": -2.65, "z": 13.0}, 0.0)
	check(s.crew == 6, "destroyed side target cannot farm recruits")
	s = R.fresh()
	s.phase = "playing"
	var valid_all := true
	while s.phase == "playing":
		R.step(s)
		valid_all = valid_all and R.valid(s)
	check(valid_all, "every natural untouched tick structurally valid")
	check(s.phase == "defeat" and s.crew == 0 and s.leaks > 0, "untouched forward run naturally loses crew")
	var end := s.duplicate(true)
	R.step(s)
	check(s == end, "terminal simulation is stable")
	var settings := {"sound": false, "reduced_effects": true}
	var text := S.encode(s, settings, 7)
	check(S.decode(text).ok and equal(S.decode(text).state, s), "checked terminal round trip within 1e-9 for JSON float parsing")
	check(not S.decode(text.replace("payload", "payloadx")).ok, "checksum wrapper rejection")
	for key in ["seed", "crew", "tick", "side_hp", "final_hp", "gates", "enemies", "bullets"]:
		var bad := s.duplicate(true)
		bad[key] = null
		check(not R.valid(bad), "reject malformed " + key)
	var bad := s.duplicate(true)
	bad.gates[0].crossed = false
	check(not S.decode(S.encode(bad, settings, 8)).ok, "reject crossed gate reward replay")
	bad = s.duplicate(true)
	bad.enemies[3].born += 1
	check(not R.valid(bad), "reject changed pinned encounter")
	bad = R.fresh()
	bad.enemies[0].resolved = true
	bad.enemies[0].hp = 0
	check(not R.valid(bad), "unborn enemy cannot be pre-cleared by import")
	bad = R.fresh()
	bad.phase = "playing"
	bad.crew = 12
	check(not R.valid(bad), "crew cannot exceed earned recruitment ledger")
	check(not S.decode(S.encode(s, {"sound": 1, "reduced_effects": false}, 2)).ok, "settings must be booleans")
	var io := F.new()
	check(S.write(s, settings, "test", io), "first durable slot")
	check(S.write(s, settings, "test", io) and S.read("test", io).revision == 2, "alternating slots revision")
	var previous: Dictionary = S.read("test", io)
	io.fail_write = true
	check(not S.write(s, settings, "test", io) and S.read("test", io).revision == previous.revision, "partial write preserves previous")
	io.fail_write = false
	io.corrupt_readback = true
	check(not S.write(s, settings, "test", io), "corrupt readback rejected")
	io.corrupt_readback = false
	check(S.read("test", io).revision == 3, "valid interrupted ordinary save temp recovers")
	previous = S.read("test", io)
	io.fail_rename = true
	check(not S.write(s, settings, "test", io, true), "failed import promotion reports failure")
	check(S.read("test", io).revision == previous.revision, "unpromoted import temp never displaces current save")
	io.fail_rename = false
	check(S.write(s, settings, "test", io, true) and S.read("test", io).revision == 4, "promoted imported slot accepted")
	io.files["test" + str(S.read("test", io).slot)] = "torn"
	check(S.read("test", io).revision == 3, "corrupt newest recovers older valid slot")
	var retry := R.fresh()
	check(retry.tick == 0 and retry.crew == 3 and retry.side_hp == 120 and not retry.gates[0].crossed, "Retry restores pinned encounter without duplicate recruits")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details}, "  "))
	print("RULES: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
