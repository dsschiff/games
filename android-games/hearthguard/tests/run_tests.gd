extends SceneTree
const R = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const Faults = preload("res://tests/fault_files.gd")
var checks := 0
var failures := 0
var details: Array = []

func check(okay: bool, message: String) -> void:
	checks += 1
	details.append({"pass": okay, "message": message})
	if not okay:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s := R.fresh()
	var p := R.profile()
	var settings := {"sound": false, "reduced_effects": true}
	check(R.valid(s), "fresh finite bootstrap supply validates")
	check(s.wallet == 0 and s.coins.size() == 5, "five obtainable original coins avoid zero-fund lock")
	check(not R.buy(s, 0), "ready state cannot buy")
	s.phase = "playing"
	check(not R.buy(s, -1) and not R.buy(s, 2), "invalid pad identifiers rejected")
	s.x = 2.4
	s.z = 2.4
	R.tick(s, Vector2.ZERO, 0.016)
	check(s.wallet == 3 and s.collected.size() == 3, "nearby pickup uses radius and actual values")
	var wallet: int = s.wallet
	R.tick(s, Vector2.ZERO, 0.016)
	check(s.wallet == wallet, "same coin cannot pay twice")
	check(not R.buy(s, 0), "remote and insufficient purchase refused")
	for c in s.coins.duplicate(true):
		s.x = c.x
		s.z = c.z
		R.tick(s, Vector2.ZERO, 0.016)
	check(s.wallet == 5, "all finite startup coins obtainable")
	s.x = R.PADS[0].x
	s.z = R.PADS[0].y
	R.tick(s, Vector2.ZERO, 0.016)
	check(s.pads[0] == 0 and s.wallet == 5, "standing on pad never spends automatically")
	check(R.buy(s, 0) and s.wallet == 0 and s.spent == 5, "explicit purchase debits exact price and constructs")
	var before := s.duplicate(true)
	check(not R.buy(s, 0) and s == before, "occupied pad cannot double-spend")
	check(R.valid(s), "post-pickup and purchase economy validates")
	var targeting := R.fresh()
	targeting.enemies = [{"id": 0, "z": -4.0, "hp": 2}, {"id": 1, "z": -1.0, "hp": 2}, {"id": 2, "z": 7.0, "hp": 2}]
	check(R.target(targeting, 0) == 1, "target prioritizes closest to refuge inside coverage")
	targeting.enemies = [{"id": 0, "z": 8.0, "hp": 2}]
	check(R.target(targeting, 0) == -1, "no firing beyond tower coverage")
	# Synthetic rules route only: it is not the input-driven playthrough.
	var second := false
	var states_valid := true
	for frame in 10000:
		if s.phase != "playing":
			break
		var goal := R.position(s)
		if not s.coins.is_empty():
			goal = Vector2(s.coins[0].x, s.coins[0].z)
		if s.pads[1] == 0 and s.wallet >= 15:
			goal = R.PADS[1]
			if R.position(s).distance_to(goal) <= R.BUILD_DISTANCE:
				second = R.buy(s, 1)
		R.tick(s, (goal - R.position(s)).limit_length(), 1.0 / 60)
		states_valid = states_valid and R.valid(s)
	check(second, "battle rewards fund second heavy tower")
	check(s.phase == "victory", "two-tower route naturally wins under rule simulation")
	check(states_valid, "every generated tick remains save-valid")
	check(s.shots > 20 and s.killed.size() >= 16, "constructed towers materially kill advancing column")
	var solo := R.fresh()
	solo.phase = "playing"
	for c in solo.coins.duplicate(true):
		solo.x = c.x
		solo.z = c.z
		R.tick(solo, Vector2.ZERO, 0.016)
	solo.x = R.PADS[0].x
	solo.z = R.PADS[0].y
	R.buy(solo, 0)
	for frame in 10000:
		if solo.phase != "playing":
			break
		R.tick(solo, Vector2.ZERO, 1.0 / 60)
	check(solo.phase == "defeat" and solo.integrity == 0, "counterfactual first tower alone loses: second investment consequential")
	R.finish(s, p)
	check(p.attempts == 1 and p.wins == 1 and p.best_kills == s.killed.size(), "terminal result recorded once at caller transition")
	var text := S.encode(s, p, settings, 7)
	check(S.decode(text).ok, "earned-shaped victory round-trips checked envelope")
	check(not S.decode(text + "x").ok, "trailing corrupt code rejected")
	var envelope: Dictionary = JSON.parse_string(text)
	envelope.sha256 = "00"
	check(not S.decode(JSON.stringify(envelope)).ok, "checksum tamper rejected")
	for mutation in ["version", "revision", "settings", "profile", "state"]:
		var packet: Dictionary = JSON.parse_string(JSON.parse_string(text).payload)
		packet[mutation] = null
		check(not S.decode(wrap_packet(packet)).ok, "missing or invalid " + mutation + " rejected")
	for field in ["wallet", "spent", "integrity", "spawned", "shots", "x", "time"]:
		var bad := s.duplicate(true)
		bad[field] = -999
		check(not R.valid(bad), "invalid " + field + " rejected")
	var bad := s.duplicate(true)
	bad.wallet += 1
	check(not R.valid(bad), "unearned extra wallet rejected")
	bad = s.duplicate(true)
	bad.collected.append(bad.collected[0])
	check(not R.valid(bad), "duplicate collected ownership rejected")
	bad = s.duplicate(true)
	bad.killed.append(bad.killed[0])
	check(not R.valid(bad), "duplicate enemy rewards rejected")
	bad = s.duplicate(true)
	bad.leaked.append(bad.killed[0])
	check(not R.valid(bad), "killed enemy cannot also leak")
	bad = s.duplicate(true)
	bad.pads[1] = 0
	check(not R.valid(bad), "tower spending occupancy ledger bound")
	bad = s.duplicate(true)
	bad.coins.append({"id": 24, "x": 0, "z": 0, "value": 30})
	check(not R.valid(bad), "coin cannot duplicate or inflate reward")
	bad = R.fresh()
	bad.coins[0].z = -9
	check(not R.valid(bad), "stranded imported bootstrap supply rejected")
	var lost := R.fresh()
	lost.phase = "playing"
	for frame in 10000:
		if lost.phase != "playing":
			break
		R.tick(lost, Vector2.ZERO, 1.0 / 60)
	check(lost.phase == "defeat" and lost.leaked.size() == 4, "inaction naturally loses from four road leaks")
	check(R.valid(lost), "natural leak-driven defeat saves")
	var io := Faults.new()
	check(S.write(s, p, settings, "save", io), "first checked durable write")
	var good := S.read("save", io)
	for fault in ["fail_write", "fail_rename", "corrupt_readback"]:
		io.set(fault, true)
		check(not S.write(lost, {"attempts": 1, "wins": 0, "best_kills": 0, "no_leak": false}, settings, "save", io, true), "import rejects storage " + fault)
		var retained := S.read("save", io)
		check(retained.state == good.state and retained.profile == good.profile and retained.settings == good.settings, "failed import retains whole durable current " + fault)
		io.set(fault, false)
	check(S.write(s, p, settings, "save", io), "subsequent ordinary write recovers")
	var latest := S.read("save", io)
	io.files["save" + str(latest.slot)] = "interrupted"
	check(S.read("save", io).ok, "corrupt newest slot falls back to intact older")
	var recovery := Faults.new()
	recovery.files["save0.tmp"] = S.encode(s, p, settings, 9, true)
	recovery.fail_rename = true
	check(not S.write(s, p, settings, "save", recovery), "failed autosave promotion reports failure")
	var staged := S.read("save", recovery)
	recovery.fail_write = true
	check(not S.write(s, p, settings, "save", recovery), "later truncation failure reports failure")
	check(S.read("save", recovery).state == staged.state and S.read("save", recovery).revision == 10, "sole highest checked staged recovery survives later failures")
	print("HEARTH_RULES: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "scope": "Synthetic rule and storage fixtures only; no earned-playthrough claim."}, "  "))
	quit(0 if failures == 0 else 1)

func wrap_packet(packet: Dictionary) -> String:
	var payload := JSON.stringify(packet)
	return JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})

