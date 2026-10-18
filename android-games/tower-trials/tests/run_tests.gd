extends SceneTree

const Content = preload("res://scripts/content.gd")
const Rules = preload("res://scripts/rules.gd")
const Saves = preload("res://scripts/save_store.gd")
const Fault = preload("res://tests/fault_files.gd")
var checks := 0
var failures: Array = []
var solutions: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize() -> void:
	var levels := Content.levels()
	for level in levels:
		var solved := Rules.solve(level)
		check(solved.ok, "Solver completes " + level.id)
		var state := Rules.initial(level)
		var route_states: Array = [state.duplicate(true)]
		for id in solved.route:
			state = Rules.step(level, state, id).state
			route_states.append(state.duplicate(true))
		check(state.status == "won", "Solver witness replays " + level.id)
		check(int(state.moves) <= int(level.par), "Par is achievable " + level.id)
		if level.rooms.any(func(room): return room.treasure):
			check(Rules.solve(level, {}, true).ok, "Treasure medal is reachable " + level.id)
		solutions.append({"id": level.id, "route": solved.route, "visited": solved.visited, "shortest": solved.shortest, "greedy": Rules.greedy(level), "topology": topology(level), "room_count": level.rooms.size(), "treasure_offered": level.rooms.any(func(room): return room.treasure)})
		for i in route_states.size():
			var replay := Rules.initial(level)
			for j in i:
				replay = Rules.step(level, replay, solved.route[j]).state
			check(replay == route_states[i], "Undo replay restores complete state " + level.id + ":" + str(i))
	var first: Dictionary = levels[0]
	var initial := Rules.initial(first)
	var equal := Rules.step(first, initial, "rope")
	check(equal.ok and equal.state.status == "lost" and equal.state.power == 3, "Equality loses without adding power")
	check(initial == Rules.initial(first), "Preview cannot mutate original state")
	check(Rules.step(first, initial, "light").ok == false, "Locked prerequisite blocks entry")
	check(Rules.step(first, Rules.step(first, initial, "bell").state, "bell").ok == false, "Claimed room cannot pay twice")
	check(Rules.step(first, initial, "missing").ok == false, "Unknown room blocked")
	var pair: Dictionary = levels[1]
	var forward := Rules.step(pair, Rules.initial(pair), "pair")
	check(forward.state.power == 15 and forward.state.claimed == ["pair"], "Multi-enemy order adds before second fight")
	var reverse := Rules.step(pair, Rules.initial(pair), "reverse")
	check(reverse.state.status == "lost" and reverse.state.power == 5, "Reverse order loses")
	var ferry: Dictionary = Content.by_id("watch_03")
	var keyed: Dictionary = Rules.step(ferry, Rules.initial(ferry), "key").state
	check(keyed.keys == 1 and keyed.collapsed == ["easy"] and keyed.power == 14, "Key ferry claims resources and collapses alternative")
	check(not Rules.step(ferry, keyed, "easy").ok, "Collapsed route unavailable")
	check(Rules.step(ferry, keyed, "door").state.keys == 0, "Door consumes key exactly once")
	check(not Rules.greedy(ferry).won and Rules.greedy(ferry).state.status == "lost", "Greedy smallest-first is stranded and reaches visible loss")
	var glass: Dictionary = Content.by_id("watch_04")
	var shield: Dictionary = Rules.step(glass, Rules.initial(glass), "shield").state
	var trap: Dictionary = Rules.step(glass, shield, "trap").state
	check(trap.shields == 0 and trap.power == 17, "Shield blocks trap before fighting and is consumed")
	check(Rules.step(glass, Rules.initial(glass), "trap").state.status == "lost", "Unshielded lethal trap loses")
	check(Rules.step(glass, Rules.initial(glass), "sun").state.power == 18, "Multiplier applies after enemies")
	var sun: Dictionary = Rules.find_room(glass, "sun").duplicate(true)
	sun.collapse = []
	var held := Rules.initial(glass)
	held.shields = 1
	check(Rules.blocked(held, sun) == "Sun lens refuses a carried shield", "Carried shield prevents multiplier independently of collapse")
	var wrong := Rules.initial(ferry)
	wrong.keys = 0
	wrong.claimed = ["key"]
	check(not Rules.step(ferry, wrong, "door").ok, "Door checks actual key not only prerequisite")
	save_checks()
	var extra := preload("res://tests/challenge_cases.gd").new().run_suite()
	checks += extra.checks
	failures.append_array(extra.failures)
	DirAccess.make_dir_recursive_absolute("res://.artifacts/challenge-v1/authored-rules")
	var file := FileAccess.open("res://.artifacts/challenge-v1/authored-rules/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "solutions": solutions, "claim": "BFS gives shortest successful routes; no uniqueness claim"}, "\t"))
	file.close()
	print("TOWER RULES: %d checks; %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("SUITE_COMPLETE: PASS")
	quit(0 if failures.is_empty() else 1)

func topology(level: Dictionary) -> String:
	var ids: Array = level.rooms.map(func(room): return room.id)
	var graph: Array = []
	for room in level.rooms:
		graph.append([room.enemies.size(), room.requires.map(func(id): return ids.find(id)), room.get("requires_any", []).map(func(id): return ids.find(id)), room.collapse.map(func(id): return ids.find(id)), room.key_cost, room.keys, room.shields, int(room.trap) > 0, room.multiplier, room.treasure, room.get("keeper", false), room.rescue])
	return JSON.stringify(graph).sha256_text()

func save_checks() -> void:
	var data := Saves.fresh()
	data.actions = ["bell"]
	var restored := Saves.decode(Saves.encode(data))
	check(restored.ok and restored.state.power == 5, "Versioned save replays actions with normalized integers")
	var invalid := data.duplicate(true)
	invalid.actions = ["light"]
	check(not Saves.decode(Saves.encode(invalid)).ok, "Import rejects impossible route")
	invalid = data.duplicate(true)
	invalid.level = 3
	check(not Saves.decode(Saves.encode(invalid)).ok, "Import rejects locked progression")
	invalid = data.duplicate(true)
	invalid.settings.sound = 1
	check(not Saves.decode(Saves.encode(invalid)).ok, "Import rejects coercion of setting")
	invalid = data.duplicate(true)
	invalid.actions = ["rope", "bell"]
	check(not Saves.decode(Saves.encode(invalid)).ok, "Import rejects action after terminal defeat")
	invalid = data.duplicate(true)
	invalid.actions = ["bell", "rope", "clock", "light"]
	check(not Saves.decode(Saves.encode(invalid)).ok, "Import rejects terminal clear without profile used by victory view")
	invalid = data.duplicate(true)
	invalid.level_id = "unknown"
	check(not Saves.decode(Saves.encode(invalid)).ok, "Import rejects unknown stable puzzle ID")
	invalid = data.duplicate(true)
	invalid.catalog = 99
	check(not Saves.decode(Saves.encode(invalid)).ok, "Import rejects missing immutable catalog")
	invalid = data.duplicate(true)
	invalid.profile.watch_01 = {"best": 4, "medals": 5}
	check(not Saves.decode(Saves.encode(invalid)).ok, "Import rejects treasure medal in watch without treasure")
	check(not Saves.decode("{").ok and not Saves.decode("x".repeat(Saves.LIMIT + 1)).ok, "Corrupt and oversized saves rejected")
	for suffix in [".tmp", ".bak.tmp"]:
		for mode in ["write", "flush", "readback", "rename"]:
			var io := Fault.new()
			check(Saves.write(data, "save", io), "Baseline filesystem write")
			io.fail_suffix = suffix
			io.fail_mode = mode
			var newer := data.duplicate(true)
			newer.actions.append("rope")
			check(not Saves.write(newer, "save", io), "Fault is surfaced " + suffix + mode)
			check(Saves.read("save", io).ok, "Fault keeps recoverable valid save " + suffix + mode)
	var io := Fault.new()
	var staged := data.duplicate(true)
	staged.revision = 7
	io.files["save.bak.tmp"] = Saves.encode(staged)
	io.fail_suffix = ".bak.tmp"
	io.fail_mode = "write"
	check(Saves.write(data, "save", io), "Sole valid staged backup reused without truncation")
	check(Saves.read("save", io).ok and Saves.read("save", io).data.revision == 8, "Staged backup survives next revision")
	io = Fault.new()
	check(Saves.write(data, "save", io), "Import baseline")
	io.fail_mode = "rename"
	io.fail_suffix = ".tmp"
	var imported := data.duplicate(true)
	imported.actions.append("rope")
	check(not Saves.write(imported, "save", io, false), "Failed import surfaces commit failure")
	check(Saves.read("save", io).data.actions == ["bell"], "Failed import cannot silently replace current run on restart")
	io = Fault.new()
	check(Saves.write(data, "save", io) and Saves.write(imported, "save", io, false) and Saves.write(imported, "save", io), "Committed import can become the next backup")
	io.files["save"] = "{"
	check(Saves.read("save", io).ok and Saves.read("save", io).data.actions == imported.actions, "Committed import backup remains recoverable after primary corruption")
	var old_source := FileAccess.get_file_as_string("res://tests/fixtures/code1-active-route.json")
	var old_expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/code1-active-route.json.expected.json"))
	for key in ["power", "keys", "shields", "moves", "treasure"]:
		old_expected.state[key] = int(old_expected.state[key])
	var old := Saves.decode(old_source)
	check(old.ok and old.state == old_expected.state and old.data.catalog == 1 and old.data.schema == Saves.VERSION, "Genuine touch-created code1 route keeps exact state while schema migrates")
	if old.ok:
		var legacy_level := Content.by_id(old.data.level_id, 1)
		check(Rules.step(legacy_level, old.state, "rope").state.power == 8, "Updated runtime can naturally continue immutable catalog1 arithmetic")
		var old_mutation: Dictionary = JSON.parse_string(old_source)
		old_mutation.level = 4
		check(not Saves.decode(Saves.encode(old_mutation)).ok, "Malformed catalog1/level4 is rejected before array indexing")
		old_mutation = JSON.parse_string(old_source)
		old_mutation.level = 35
		check(not Saves.decode(Saves.encode(old_mutation)).ok, "Latest-catalog upper bound cannot admit invalid legacy index")
		old_mutation = JSON.parse_string(old_source)
		old_mutation.level = 3
		old_mutation.level_id = "watch_04"
		old_mutation.actions = []
		old_mutation.profile = {"watch_01": {"best": 4, "medals": 3}, "watch_02": {"best": 3, "medals": 3}, "watch_03": {"best": 3, "medals": 3}}
		check(Saves.decode(Saves.encode(old_mutation)).ok and Content.index_of("watch_04") == 8, "Historic active puzzle remains valid when new tutorials precede its current display index")
		old_mutation.level = 2
		old_mutation.level_id = "watch_03"
		old_mutation.actions = ["key"]
		old_mutation.profile.erase("watch_03")
		old_mutation.settings = {"sound": false, "reduced_effects": true}
		old_mutation.used_undo = true
		var ferry_upgrade := Saves.decode(Saves.encode(old_mutation))
		check(ferry_upgrade.ok and ferry_upgrade.state.power == 14 and ferry_upgrade.state.keys == 1 and ferry_upgrade.state.collapsed == ["easy"] and ferry_upgrade.data.level == 2 and ferry_upgrade.data.catalog == 1 and ferry_upgrade.data.used_undo and not ferry_upgrade.data.settings.sound, "Coordinator-described code1 key-ferry route/settings survive its shifted current display index")
