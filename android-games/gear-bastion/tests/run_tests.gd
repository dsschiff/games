extends SceneTree

const Gear = preload("res://scripts/gear_rules.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const Saves = preload("res://scripts/save_store.gd")
const Review = preload("res://tests/review_regressions.gd")
const Campaign = preload("res://tests/campaign_rules.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures.append(detail)
		push_error(detail)

func simulate(state: Dictionary, seconds: float) -> void:
	for i in ceili(seconds / Battle.STEP):
		Battle.tick(state, Battle.STEP)

func equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not equivalent(a[i], b[i]):
				return false
		return true
	return a == b

func run() -> void:
	var board := Gear.initial_board()
	check(Gear.powered(board).size() == 5, "Initial network connected")
	check(is_equal_approx(Gear.total_rate(board), 1.24), "Actual starting production")
	var boosted := Gear.move(board, 5, 1, 1)
	check(boosted.ok and Gear.rate(boosted.board, 2) > Gear.rate(board, 2), "Adjacent drive changes rate")
	var off := Gear.move(board, 2, 0, 0)
	check(off.ok and Gear.rate(off.board, 2) == 0, "Disconnected generator stops")
	var back := Gear.move(off.board, 2, 1, 2)
	check(back.ok and Gear.rate(back.board, 2) > 0, "Reconnection restarts")
	check(not Gear.move(board, 2, -1, 0).ok and Gear.move(board, 2, -1, 0).board == board, "Cancelled move retains board")
	check(not Gear.move(board, 2, 2, 2).ok, "Occupied core cannot be overwritten")
	check(not Gear.move(board, 1, 0, 0).ok, "Core anchored")
	var merge := Gear.move(board, 5, 2, 1)
	check(merge.ok and merge.board.size() == 4 and int(merge.board[3].level) == 2, "Equal drives merge directly")
	check(not Gear.move(merge.board, 4, 1, 2).ok, "Unequal types cannot merge")
	check(not Gear.buy(board, "ranger", 0, 0, 0, 6).ok, "Resource cost enforced")
	check(Gear.buy(board, "guard", 0, 0, 24, 6).gold == 12, "Purchase spends exactly cost")
	var cycle := [Gear.piece(1, "core", 0, 0), Gear.piece(2, "drive", 1, 0, 4), Gear.piece(3, "drive", 0, 1, 4), Gear.piece(4, "guard", 1, 1), Gear.piece(5, "drive", 2, 1, 4)]
	check(is_equal_approx(Gear.rate(cycle, 4), 0.72 * 3), "Cycles terminate and modifier caps at 3x")
	check(Gear.powered(cycle).size() == 5, "Flood fill visits cycle once")
	var duplicate := board.duplicate(true)
	duplicate[1].id = 1
	check(not Gear.valid_board(duplicate), "Duplicate IDs rejected")
	duplicate = board.duplicate(true)
	duplicate[1].x = 1.5
	check(not Gear.valid_board(duplicate), "Fractional socket rejected")
	var a := Battle.initial(717)
	var b := Battle.initial(717)
	Battle.start(a)
	Battle.start(b)
	simulate(a, 12)
	simulate(b, 12)
	check(a == b, "Seeded simulation deterministic")
	check(a.produced > 0 and not a.units.is_empty(), "Rates become actual troops")
	check(a.units[0].lane == 0, "Generator's selected gate used")
	var counter := Battle.initial()
	Battle.start(counter)
	var guard := Battle.make_unit(counter, "guard", 1, true)
	var shell := Battle.make_unit(counter, "shell", 1, false)
	guard.y = 300.0
	shell.y = 305.0
	guard.x = 300.0
	shell.x = 300.0
	guard.cooldown = 0.0
	counter.units = [guard]
	counter.enemies = [shell]
	Battle.tick(counter, Battle.STEP)
	check(is_equal_approx(float(shell.hp), 66.4), "Shell armor reduces guard damage by 60 percent")
	guard.kind = "ranger"
	guard.cooldown = 0.0
	shell.hp = 70.0
	Battle.tick(counter, Battle.STEP)
	check(is_equal_approx(float(shell.hp), 59.0), "Ranger damage pierces shell armor")
	print("BASELINE before final: ", a.wall, " produced ", a.produced)
	simulate(a, 180)
	print("BASELINE result: ", a.phase, " wall ", a.wall, " army ", a.units.size(), " kills ", a.kills)
	check(a.phase == "victory", "Starting balanced layout wins tutorial")
	var failed := Battle.initial()
	failed.board = Gear.move(failed.board, 2, 0, 0).board
	failed.board = Gear.move(failed.board, 3, 4, 0).board
	Battle.start(failed)
	simulate(failed, 160)
	print("DISCONNECTED result: ", failed.phase, " wall ", failed.wall)
	check(failed.phase == "defeat" and failed.produced == 0, "Disconnected strategy loses wall")
	var repaired := Battle.initial()
	repaired.board = Gear.move(repaired.board, 2, 0, 0).board
	repaired.board = Gear.move(repaired.board, 3, 4, 0).board
	Battle.start(repaired)
	simulate(repaired, 20)
	print("REPAIR at20: wall ", repaired.wall, " phase ", repaired.phase)
	check(float(repaired.wall) < 220 and repaired.phase == "battle", "Failed layout creates repairable damage")
	repaired.board = Gear.move(repaired.board, 2, 1, 2).board
	repaired.board = Gear.move(repaired.board, 3, 3, 2).board
	simulate(repaired, 180)
	print("REPAIR result: ", repaired.phase, " wall ", repaired.wall)
	check(repaired.phase == "victory", "Live rearrangement rescues failing strategy")
	var portable := Saves.encode(b, {"muted": true, "reduced_effects": true})
	var loaded := Saves.decode(portable)
	check(loaded.ok and loaded.settings.muted and is_equal_approx(float(loaded.state.time), float(b.time)), "Portable active battle and preferences restored")
	simulate(b, 8)
	simulate(loaded.state, 8)
	check(equivalent(b, loaded.state), "Resumed battle matches uninterrupted simulation within 0.000001 float tolerance")
	check(not Saves.decode("{broken").ok, "Corrupt JSON rejected")
	check(not Saves.decode('{"version":99,"state":{}}').ok, "Future version rejected")
	var corrupt := b.duplicate(true)
	corrupt.units[0].x = {"broken": 1}
	check(not Saves.decode(Saves.encode(corrupt, {})).ok, "Malformed unit numeric type rejected without replacing state")
	corrupt = b.duplicate(true)
	corrupt.production["2"] = 99
	check(not Saves.decode(Saves.encode(corrupt, {})).ok, "Unbounded saved production rejected")
	var legacy := JSON.stringify({"version": 1, "state": {"board": Gear.initial_board()}})
	check(Saves.decode(legacy).ok, "Prior version migrates without losing board")
	var path := "user://test-save.json"
	check(Saves.write(b, {}, path), "First atomic save")
	check(Saves.write(a, {}, path), "Replacement atomic save plus backup")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("interrupted garbage")
	file.close()
	var recovered := Saves.read(path)
	check(recovered.ok and recovered.recovered and recovered.state.phase == "battle", "Corrupt primary recovers previous valid save")
	var stress := Battle.initial()
	stress.board = [Gear.piece(1, "core", 2, 2)]
	var id := 2
	for y in 4:
		for x in 5:
			if x != 2 or y != 2:
				stress.board.append(Gear.piece(id, "guard" if id % 2 == 0 else "ranger", x, y))
				id += 1
	stress.next_id = id
	Battle.start(stress)
	stress.wave_time = -1000.0
	stress.spawned = 12
	var began := Time.get_ticks_usec()
	simulate(stress, 80)
	var elapsed := Time.get_ticks_usec() - began
	check(stress.units.size() == Battle.UNIT_CAP and stress.peak_units == Battle.UNIT_CAP, "Army cap holds under full board")
	check(stress.cap_time > 0, "Production stalls at cap instead of accumulating an unbounded queue")
	stress.board[1].lane = 2
	stress.units.pop_back()
	simulate(stress, 0.1)
	check(stress.units.size() == Battle.UNIT_CAP and int(stress.units.back().lane) == 2, "At-cap gate choice affects next reinforcement")
	print("STRESS 80s / 2400 steps: ", elapsed / 1000.0, " ms; peak ", stress.peak_units)
	for i in Battle.ENEMY_CAP:
		stress.enemies.append(Battle.make_unit(stress, "shell" if i % 3 == 0 else "beetle", i % 3, false))
	var worst_step := 0
	began = Time.get_ticks_usec()
	for i in 120:
		var tick_began := Time.get_ticks_usec()
		Battle.tick(stress, Battle.STEP)
		worst_step = maxi(worst_step, Time.get_ticks_usec() - tick_began)
	check(stress.units.size() <= Battle.UNIT_CAP and stress.enemies.size() <= Battle.ENEMY_CAP, "120-troop / 90-raider stress remains bounded")
	print("HEAVY 120 steps: ", (Time.get_ticks_usec() - began) / 1000.0, " ms; max step ", worst_step / 1000.0, " ms; desktop only")
	var review_outcomes: Variant = Review.run(check)
	check(review_outcomes is Dictionary and review_outcomes.size() == 5, "All review regression scenarios reached completion")
	var campaign_completed: Variant = Campaign.run(check)
	check(campaign_completed == true, "All campaign rule scenarios reached completion")
	print("RULE TESTS: ", checks, " checks, ", failures.size(), " failures")
	print("SUITE_COMPLETE: PASS" if failures.is_empty() else "SUITE_COMPLETE: FAIL")
	quit(0 if failures.is_empty() else 1)
