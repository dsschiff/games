extends RefCounted
const Challenge = preload("res://scripts/challenge_v1.gd")
const Rules = preload("res://scripts/rules.gd")
const Saves = preload("res://scripts/save_store.gd")
var checks := 0
var failures: Array = []
var rows: Array = []
var shapes: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func shape(level: Dictionary) -> String:
	var value: Array = []
	for room in level.rooms:
		value.append([room.id, room.requires, room.collapse, room.key_cost, room.keys, room.shields, room.trap > 0, room.multiplier, room.get("keeper", false), room.treasure, room.rescue, room.enemies.size(), room.enemies.size() == 2 and room.enemies[0] > room.enemies[1]])
	return JSON.stringify(value).sha256_text()

func run_suite() -> Dictionary:
	for family in Challenge.FAMILIES:
		for seed_value in 16:
			for weave in 4:
				for treasure in [false, true]:
					var options := {"weave": weave, "treasure": treasure}
					var result := Challenge.generate(family, seed_value, options)
					check(result.ok, "Generated " + family + str(seed_value) + str(options))
					if not result.ok: continue
					var bundle: Dictionary = result.bundle
					check(Challenge.validate(bundle).ok and not bundle.fallback, "Within-budget verified candidate")
					check(Challenge.generate(family, seed_value, options).bundle == bundle, "Seed/options determinism")
					var level: Dictionary = bundle.snapshot
					check(Challenge.route_state(level, bundle.witness).status == "won", "Win witness")
					check(not treasure or Challenge.route_state(level, bundle.medal_witness).treasure > 0, "Medal witness")
					check(Challenge.route_state(level, bundle.bad_route).status == "lost", "Consequential losing commitment")
					shapes[shape(level)] = true
					if seed_value == 0 and weave == 0 and treasure:
						rows.append({"family": family, "seed": seed_value, "options": options, "rooms": level.rooms.size(), "win": bundle.witness, "medal": bundle.medal_witness, "loss": bundle.bad_route})
	check(shapes.size() >= 24, "Structural diversity excluding enemy strengths and layout")
	for family in Challenge.FAMILIES:
		var result := Challenge.generate(family, 2147483647, {"weave": 3, "treasure": true}, 0)
		check(result.ok and result.bundle.fallback and Challenge.validate(result.bundle).ok, "Explicit bounded preverified fallback " + family)
	var baseline: Dictionary = Challenge.generate("key", 137, {"weave": 0, "treasure": true}).bundle
	for mutation in ["large_rooms", "bad_cell", "duplicate_id", "unknown_ref", "huge_enemy", "nan_power", "wrong_witness", "no_loss", "bad_seed", "rules", "extra", "bad_ordinal"]:
		var changed := baseline.duplicate(true)
		match mutation:
			"large_rooms": changed.snapshot.rooms.append_array(changed.snapshot.rooms.duplicate(true))
			"bad_cell": changed.snapshot.rooms[0].floor = 4
			"duplicate_id": changed.snapshot.rooms[1].id = changed.snapshot.rooms[0].id
			"unknown_ref": changed.snapshot.rooms[0].requires = ["missing"]
			"huge_enemy": changed.snapshot.rooms[0].enemies = [1000000000]
			"nan_power": changed.snapshot.power = NAN
			"wrong_witness": changed.witness = ["missing"]
			"no_loss": changed.bad_route = changed.witness.duplicate()
			"bad_seed": changed.seed = -1
			"rules": changed.snapshot.rules = 99
			"extra": changed.snapshot["arbitrary"] = "x"
			"bad_ordinal": changed.snapshot.rooms[0].enemies = [1.5]
		check(not Challenge.validate(changed).ok, "Malformed snapshot rejected: " + mutation)
	check(Challenge.search(baseline.snapshot, {}, false, 0).exhausted, "Zero budget returns exhausted without unbounded search")
	check(not Challenge.generate("invalid", 1, {"weave": 0, "treasure": true}).ok, "Unknown family rejected")
	save_checks(baseline)
	DirAccess.make_dir_recursive_absolute("res://.artifacts/challenge-v1/rules")
	var file := FileAccess.open("res://.artifacts/challenge-v1/rules/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "generated_cases": 512, "structural_signatures": shapes.size(), "witness_examples": rows, "scope": "Seed0..15 x4families x4weaves x2treasure; strengths/layout omitted from structure comparison; no uniqueness claim"}, "\t"))
	file.close()
	print("CHALLENGE RULES: %d checks; %d failures; %d structures" % [checks, failures.size(), shapes.size()])
	return {"checks": checks, "failures": failures, "structures": shapes.size()}

func save_checks(bundle: Dictionary) -> void:
	var data := Saves.fresh()
	data.actions = ["bell"]
	data.kind = "challenge"
	data.challenge_run = {"bundle": bundle, "actions": [], "used_undo": false}
	var loaded := Saves.decode(Saves.encode(data))
	check(loaded.ok and loaded.data.actions == ["bell"] and loaded.data.challenge_run.bundle == bundle, "Saved snapshot roundtrip preserves campaign and challenge")
	var changed := data.duplicate(true)
	changed.challenge_run.bundle.snapshot.rooms[0].column = 30
	check(not Saves.decode(Saves.encode(changed)).ok, "Imported snapshot dimensions rejected")
	changed = data.duplicate(true)
	changed.challenge_run.actions = ["missing"]
	check(not Saves.decode(Saves.encode(changed)).ok, "Impossible generated action rejected")
	changed = data.duplicate(true)
	changed.challenge_run.actions = bundle.witness.duplicate()
	check(not Saves.decode(Saves.encode(changed)).ok, "Generated terminal route needs separate earned record")
	var old := FileAccess.get_file_as_string("res://tests/fixtures/code1-active-route.json")
	var legacy := Saves.decode(old)
	check(legacy.ok and legacy.data.kind == "campaign" and legacy.data.catalog == 1 and legacy.state.power == 5, "Schema1 active route migrates without losing original rules")
	var code2 := FileAccess.get_file_as_string("res://tests/fixtures/code2-active-route.json")
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/code2-active-route.json.expected.json"))
	for key in ["power", "keys", "shields", "moves", "treasure"]: expected.state[key] = int(expected.state[key])
	var migrated := Saves.decode(code2)
	check(migrated.ok and migrated.state == expected.state and migrated.data.catalog == 2 and migrated.data.profile.size() == 18 and migrated.data.schema == 3 and migrated.data.kind == "campaign", "Touch-created code2 active route/profile migrate unchanged")
	for filename in ["challenge-v1-active.json", "challenge-v1-fallback.json"]:
		var source := FileAccess.get_file_as_string("res://tests/fixtures/" + filename)
		var parsed: Dictionary = JSON.parse_string(source)
		Challenge.validate(parsed.challenge_run.bundle)
		var calls: int = Challenge.generation_calls
		var restored := Saves.decode(source)
		check(restored.ok and Challenge.generation_calls == calls and restored.data.challenge_run.bundle == parsed.challenge_run.bundle, "Pinned fixture restored without regeneration " + filename)
		check(restored.ok and restored.state == Saves.replay_route(parsed.challenge_run.bundle.snapshot, parsed.challenge_run.actions), "Pinned fixture uses full saved snapshot state " + filename)
		if filename.contains("fallback"):
			var fresh := Challenge.generate(parsed.challenge_run.bundle.family, int(parsed.challenge_run.bundle.seed), parsed.challenge_run.bundle.options)
			check(fresh.ok and fresh.bundle.snapshot != restored.data.challenge_run.bundle.snapshot, "Fallback fixture survives even though current normal generation differs")
	changed = data.duplicate(true)
	changed.challenge_run.bundle.options.treasure = false
	changed.challenge_run.bundle.snapshot.id = Challenge.identity(changed.challenge_run.bundle.family, int(changed.challenge_run.bundle.seed), changed.challenge_run.bundle.options)
	check(not Saves.decode(Saves.encode(changed)).ok, "Treasure flags cannot contradict snapshot options")
	changed = data.duplicate(true)
	changed.challenge_records = [{"key": "a".repeat(64), "version": 1, "family": "key", "seed": 1, "options": {"weave": 0, "treasure": true}, "best": 1, "medals": 1, "fallback": false}]
	changed.challenge_records.append_array(changed.challenge_records.duplicate(true))
	check(not Saves.decode(Saves.encode(changed)).ok, "Duplicate challenge record identities rejected")
	changed = data.duplicate(true)
	changed.challenge_run.bundle.bad_route = Array(range(10000))
	check(not Saves.decode(Saves.encode(changed)).ok, "Huge search-route import is rejected before search")
