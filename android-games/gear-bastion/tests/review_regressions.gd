extends RefCounted
const Gear = preload("res://scripts/gear_rules.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const Saves = preload("res://scripts/save_store.gd")
const FaultFiles = preload("res://tests/fault_files.gd")
const Trial = preload("res://tests/trial_cases.gd")

static func simulate(state: Dictionary, seconds: float) -> void:
	for i in ceili(seconds / Battle.STEP):
		Battle.tick(state, Battle.STEP)

static func run(check: Callable) -> Dictionary:
	var old := Battle.initial()
	var newer := Battle.initial()
	Battle.start(newer)
	simulate(newer, 8)
	var path := "user://fault-slot.json"
	var staged_source := Saves.encode(old, {}, 8)
	var staged := FaultFiles.new()
	staged.files[path + ".bak.tmp"] = staged_source
	var staged_load := Saves.read(path, staged)
	check.call(staged_load.ok and staged_load.revision == 8 and staged_load.path == path + ".bak.tmp", "Sole valid staged backup loads normally")
	staged.fail_suffix = ".bak.tmp"
	staged.fail_mode = "write"
	check.call(Saves.write(newer, {}, path, staged), "Matching sole staged backup is reused despite injected truncating write failure")
	check.call(staged.files[path + ".bak"] == staged_source and staged.write_count == 1, "Validated staged bytes reach backup without being rewritten")
	check.call(Saves.read(path, staged).revision == 9, "New primary loads normally after sole staged backup reuse")
	var staged_rename := FaultFiles.new()
	staged_rename.files[path + ".bak.tmp"] = staged_source
	staged_rename.fail_suffix = ".bak.tmp"
	staged_rename.fail_mode = "rename"
	check.call(not Saves.write(newer, {}, path, staged_rename), "Sole staged-backup rename failure returns false")
	check.call(staged_rename.write_count == 0 and staged_rename.files[path + ".bak.tmp"] == staged_source and Saves.read(path, staged_rename).revision == 8, "Rename failure keeps sole staged candidate byte-for-byte readable")
	var staged_new_write := FaultFiles.new()
	staged_new_write.files[path + ".bak.tmp"] = staged_source
	staged_new_write.fail_suffix = "fault-slot.json.tmp"
	staged_new_write.fail_mode = "write"
	check.call(not Saves.write(newer, {}, path, staged_new_write), "New temporary write failure after sole staged-backup recovery returns false")
	check.call(staged_new_write.files[path + ".bak"] == staged_source and Saves.read(path, staged_new_write).revision == 8, "Failed replacement preserves recovered sole candidate in final backup")
	var staged_new_rename := FaultFiles.new()
	staged_new_rename.files[path + ".bak.tmp"] = staged_source
	staged_new_rename.fail_suffix = "fault-slot.json.tmp"
	staged_new_rename.fail_mode = "rename"
	check.call(not Saves.write(newer, {}, path, staged_new_rename), "New primary rename failure after staged recovery returns false")
	check.call(staged_new_rename.files[path + ".bak"] == staged_source and Saves.read(path, staged_new_rename).ok, "Primary rename failure leaves prior staged data protected and loadable")
	for mode in ["write", "flush", "readback", "rename"]:
		var io := FaultFiles.new()
		var original := Saves.encode(old, {}, 7)
		io.files[path] = original
		io.files[path + ".bak"] = original
		io.fail_suffix = "fault-slot.json.tmp"
		io.fail_mode = mode
		check.call(not Saves.write(newer, {}, path, io), "Injected " + mode + " failure returns false")
		check.call(io.files[path] == original, "Injected " + mode + " failure preserves primary bytes")
		if mode != "rename":
			check.call(io.rename_count == 0, "Unconfirmed " + mode + " output is never renamed")
	var recovered_io := FaultFiles.new()
	var import_io := FaultFiles.new()
	import_io.files[path] = Saves.encode(old, {}, 7)
	import_io.files[path + ".bak"] = import_io.files[path]
	import_io.fail_mode = "rename"
	import_io.fail_suffix = "fault-slot.json.tmp"
	check.call(not Saves.write(newer, {}, path, import_io, false), "Failed import replacement is reported")
	check.call(Saves.read(path, import_io).state.phase == "ready", "Failed import temp is not accepted on next load")
	recovered_io.files[path] = Saves.encode(old, {}, 2)
	recovered_io.files[path + ".bak"] = Saves.encode(old, {}, 1)
	recovered_io.files[path + ".tmp"] = Saves.encode(newer, {}, 3)
	check.call(Saves.read(path, recovered_io).state.phase == "battle", "Valid newer interrupted tmp beats valid older primary and backup")
	var stale := FaultFiles.new()
	stale.files[path] = Saves.encode(newer, {}, 8)
	stale.files[path + ".tmp"] = Saves.encode(old, {}, 7)
	stale.times[path + ".tmp"] = 1000
	check.call(Saves.read(path, stale).revision == 8, "Older valid tmp cannot override newer primary even with newer filesystem timestamp")
	stale.files[path + ".tmp"] = "{interrupted"
	check.call(Saves.read(path, stale).revision == 8, "Invalid interrupted tmp cannot override valid primary")
	recovered_io.fail_suffix = "fault-slot.json.tmp"
	recovered_io.fail_mode = "write"
	check.call(not Saves.write(old, {}, path, recovered_io), "Failure while replacing recovered progress is reported")
	check.call(Saves.read(path, recovered_io).revision == 3, "Recovered newest state backed up before partial tmp overwrite")
	var backup_io := FaultFiles.new()
	backup_io.files[path] = Saves.encode(newer, {}, 9)
	backup_io.fail_suffix = ".bak.tmp"
	backup_io.fail_mode = "flush"
	check.call(not Saves.write(old, {}, path, backup_io) and backup_io.files[path] == Saves.encode(newer, {}, 9), "Backup flush failure aborts before primary replacement")
	var legacy := old.duplicate(true)
	for key in ["encounter", "spent", "losses", "production_last_id"]:
		legacy.erase(key)
	check.call(Saves.decode(JSON.stringify({"version": 2, "state": legacy})).ok, "Version-2 prototype migrates to current fields")
	var actors := Battle.initial()
	Battle.start(actors)
	actors.units = [Battle.make_unit(actors, "guard", 0, true), Battle.make_unit(actors, "ranger", 1, true)]
	actors.enemies = [Battle.make_unit(actors, "carapace", 1, false)]
	for invalid in ["duplicate_friend", "duplicate_across_factions", "wrong_friend_kind", "wrong_enemy_kind", "zero_max_hp", "negative_max_hp", "hp_over_max"]:
		var source := actors.duplicate(true)
		match invalid:
			"duplicate_friend": source.units[1].id = source.units[0].id
			"duplicate_across_factions": source.enemies[0].id = source.units[0].id
			"wrong_friend_kind": source.units[0].kind = "carapace"
			"wrong_enemy_kind": source.enemies[0].kind = "ranger"
			"zero_max_hp": source.units[0].max_hp = 0
			"negative_max_hp": source.units[0].max_hp = -1
			"hp_over_max": source.units[0].max_hp = source.units[0].hp - 1
		check.call(not Saves.decode(Saves.encode(source, {})).ok, "Import rejects " + invalid)
	check.call(Saves.decode(Saves.encode(actors, {})).ok, "Valid mixed-faction actors import")
	var capped := Battle.initial()
	Battle.start(capped)
	capped.spawned = 12
	capped.wave_time = -1000.0
	for i in Battle.UNIT_CAP:
		capped.units.append(Battle.make_unit(capped, "guard", 1, true))
	capped.production = {"2": 1.0, "3": 1.0}
	capped.board.reverse()
	var sequence: Array = []
	for i in 12:
		simulate(capped, 2)
		capped.units.pop_front()
		Battle.tick(capped, Battle.STEP)
		sequence.append(capped.units.back().kind)
	check.call(sequence == ["guard", "ranger", "guard", "ranger", "guard", "ranger", "guard", "ranger", "guard", "ranger", "guard", "ranger"], "Repeated single vacancies fairly alternate roles despite reversed board order")
	simulate(capped, 2)
	capped.board = Gear.move(capped.board, 2, 0, 0).board
	for i in 4:
		simulate(capped, 2)
		capped.units.pop_front()
		Battle.tick(capped, Battle.STEP)
		check.call(capped.units.back().kind == "ranger" and capped.production["2"] == 1.0, "Disconnected full guard buffer holds without dispatch at cap vacancy")
	capped.board = Gear.move(capped.board, 2, 1, 2).board
	capped.units.pop_front()
	Battle.tick(capped, Battle.STEP)
	check.call(capped.units.back().kind == "guard", "Reconnected buffered guard receives its next fair turn")
	capped.board = Gear.move(capped.board, 2, 0, 0).board
	capped.board = Gear.move(capped.board, 3, 4, 0).board
	capped.production = {"2": 1.0, "3": 1.0}
	capped.units.pop_front()
	var before: int = capped.produced
	simulate(capped, 2)
	check.call(capped.produced == before and capped.units.size() == 119, "No unpowered dispatch even when all buffers full and vacancy remains")
	var outcomes: Dictionary = {}
	for strategy in ["A", "B", "C", "R", "repair"]:
		var state := Trial.build("C" if strategy == "repair" else strategy)
		check.call(Gear.powered(state.board).size() == state.board.size(), "Trial " + strategy + " starts fully connected")
		var initial_spent: int = state.spent
		Battle.start(state)
		if strategy == "repair":
			simulate(state, 36)
			check.call(state.phase == "battle" and state.losses >= 40 and state.wave == 2 and state.enemies.any(func(e): return e.kind == "carapace"), "Connected all-guard trial has casualties and visible armor pressure before repair")
			Trial.repair(state)
		simulate(state, 180)
		check.call(state.phase == ("defeat" if strategy in ["C", "R"] else "victory"), "Constrained trial expected outcome for " + strategy)
		check.call(int(state.spent) + int(state.gold) == 54, "Trial " + strategy + " has fixed 54-brass economy without kill income")
		check.call(Saves.decode(Saves.encode(state, {})).ok, "Trial " + strategy + " saves valid current state")
		outcomes[strategy] = {"phase": state.phase, "wall": state.wall, "time": state.time, "initial_spent": initial_spent, "final_spent": state.spent, "losses": state.losses, "kills": state.kills}
		print("TRIAL ", strategy, ": ", outcomes[strategy])
	check.call(outcomes.A.initial_spent == 52 and outcomes.B.initial_spent == 50 and outcomes.repair.final_spent == 52, "Winning plans cost comparable 50/52 brass; repaired plan costs 52")
	check.call(not Gear.buy(Battle.initial(1701, "iron_trial").board, "guard", 0, 0, 54, 3, "iron_trial").ok, "Constrained trial rejects blocked sockets")
	return outcomes
