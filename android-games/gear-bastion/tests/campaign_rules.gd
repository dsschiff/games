extends RefCounted
const Battle = preload("res://scripts/battle_rules.gd")
const Gear = preload("res://scripts/gear_rules.gd")
const Content = preload("res://scripts/campaign_data.gd")
const Profile = preload("res://scripts/campaign_profile.gd")
const Saves = preload("res://scripts/save_store.gd")
const Frames = preload("res://scripts/frame_capture.gd")
const Policy = preload("res://tests/campaign_policies.gd")
const FaultFiles = preload("res://tests/fault_files.gd")

static func run(check: Callable) -> bool:
	for id in Content.IDS:
		var state := Battle.initial(1701, id)
		check.call(Content.valid_snapshot(state.config), "Valid immutable content snapshot for " + id)
		check.call(Saves.decode(Saves.encode(state, {}, 0, true, Profile.fresh())).ok, "Campaign snapshot survives JSON numeric roundtrip for " + id)
	var profile := Profile.fresh()
	check.call(Profile.accessible(profile, "camp_01") and not Profile.accessible(profile, "camp_09"), "Progression begins with only first foundry accessible")
	var run_state := Battle.initial(1701, "camp_01")
	check.call(not Profile.award(profile, run_state) and profile.cleared.is_empty(), "Unfinished battle cannot award progression")
	run_state.phase = "victory"
	run_state.wave = 3
	run_state.time = 120.0
	run_state.gold = 6
	run_state.spent = 24
	check.call(Profile.award(profile, run_state) and Profile.accessible(profile, "camp_02") and profile.medals.camp_01 == 3, "Clear, intact-wall and efficient medals unlock next foundry")
	Profile.award(profile, run_state)
	check.call(profile.cleared.size() == 1, "Repeated awards cannot duplicate clear entries")
	var serialized := Saves.encode(run_state, {}, 0, true, profile)
	var profile_packet := Saves.decode(serialized)
	check.call(profile_packet.ok, "Completed-run profile fixture validates: " + str(profile_packet.get("message", "valid")))
	if not profile_packet.ok:
		return false
	check.call(profile_packet.profile.cleared == profile.cleared, "Profile and active run both restore from schema 4")
	var code := Saves.portable(run_state, {"muted": true}, profile)
	var portable := Saves.decode(code)
	check.call(code.begins_with("GB4:") and portable.ok and portable.profile.cleared == profile.cleared and portable.settings.muted, "Compressed portable save restores run, profile and settings")
	check.call(not Saves.decode("GB4:broken").ok, "Malformed compressed save code is rejected")
	var missing_profile: Dictionary = JSON.parse_string(serialized)
	missing_profile.erase("profile")
	missing_profile.revision = 99
	var io := FaultFiles.new()
	io.files["profile.json"] = JSON.stringify(missing_profile)
	io.files["profile.json.bak"] = serialized
	var recovered := Saves.read("profile.json", io)
	check.call(not Saves.decode(JSON.stringify(missing_profile)).ok and recovered.ok and recovered.recovered and recovered.profile.cleared == profile.cleared, "Higher-revision schema-4 primary missing profile recovers intact progress backup")
	var legacy := Battle.initial(1701)
	for key in ["config", "boss_spawned", "produced_by_role", "lost_by_role", "wave_times", "claimed_grants", "boss_phase", "boss_clock", "boss_total", "boss_volley", "rally"]:
		legacy.erase(key)
	var migrated := Saves.decode(JSON.stringify({"version": 3, "state": legacy, "settings": {"muted": true}}))
	check.call(migrated.ok and migrated.state.encounter == "tutorial" and migrated.state.board == legacy.board and migrated.profile.cleared.is_empty(), "Real schema-3 field contract migrates without inventing campaign clears")
	var pinned := Battle.initial(1701, "camp_01")
	pinned.config.name = "Pinned old foundry"
	pinned.config.budget = 41
	pinned.gold = 41
	pinned.config.starter = [["guard", 1, 2, 1, 0]]
	pinned.config.actor_stats.beetle.hp = 7.0
	pinned.config.waves[0].count = 2
	pinned.config.waves[0].interval = 0.2
	pinned.config.waves[0].pack = 2
	var restored := Saves.decode(Saves.encode(pinned, {}))
	check.call(restored.ok and restored.state.config.name == "Pinned old foundry" and restored.state.config.budget == 41, "Active configuration is restored rather than replaced by latest catalog")
	var retry := Battle.from_snapshot(restored.state.config, 1701)
	check.call(retry.gold == 41 and Gear.at(retry.board, 1, 2) >= 0 and Gear.at(retry.board, 0, 2) < 0, "Retry uses saved starting kit and budget")
	Battle.start(restored.state)
	Battle.tick(restored.state, 0.2)
	check.call(restored.state.enemies.size() == 2 and restored.state.enemies[0].max_hp == 7, "Simulation consumes pinned wave and actor-stat snapshots")
	for invalid in ["bad_lane", "bad_actor", "bad_core", "missing_index", "bad_cost", "bad_par", "overlap_core", "overlap_starters", "off_socket", "zero_boss", "scaled_hp"]:
		var bad := pinned.duplicate(true)
		match invalid:
			"bad_lane": bad.config.waves[0].lanes = [4]
			"bad_actor": bad.config.actor_stats.guard.damage = {}
			"bad_core": bad.config.core = ["x", 2]
			"missing_index": bad.config.erase("index")
			"bad_cost": bad.config.costs.guard = 0
			"bad_par": bad.config.par_seconds = {}
			"overlap_core": bad.config.starter = [["guard", 2, 2, 1, 0]]
			"overlap_starters": bad.config.starter.append(bad.config.starter[0].duplicate())
			"off_socket": bad.config.sockets.erase([1, 2])
			"zero_boss":
				bad.config.boss = "captain"
				bad.config.boss_hp = 0.0
			"scaled_hp":
				bad.config.actor_stats.beetle.hp = 20000.0
				bad.config.hp_scale = 5.0
		check.call(not Saves.decode(Saves.encode(bad, {})).ok, "Invalid configuration import rejected: " + invalid)
	check.call(Saves.decode(Saves.encode(retry, {})).ok, "Accepted altered starting kit remains valid after retry")
	var mortar_test := Battle.initial(1701, "camp_04")
	mortar_test.config.actor_stats.mortar.period = 6.0
	Battle.start(mortar_test)
	var gun := Battle.make_unit(mortar_test, "mortar", 1, true)
	gun.x = 300.0
	gun.y = 360.0
	gun.cooldown = 0.0
	mortar_test.units = [gun]
	for i in 12:
		var enemy := Battle.make_unit(mortar_test, "beetle", 1, false)
		enemy.x = 300.0 + i
		enemy.y = 300.0
		mortar_test.enemies.append(enemy)
	var initial_hp: float = mortar_test.enemies[0].hp
	Battle.tick(mortar_test, Battle.STEP)
	var hit := 0
	for enemy in mortar_test.enemies:
		if float(enemy.hp) < initial_hp:
			hit += 1
	check.call(hit == 8, "Mortar splash is consequential and bounded to primary plus seven nearby targets")
	var cooled := Saves.decode(Saves.encode(mortar_test, {}))
	check.call(gun.cooldown == 6.0 and cooled.ok and cooled.state.units[0].cooldown == 6.0, "Accepted six-second attack period remains saveable after attack and restore")
	check.call(19.0 / 2.6 < 11.0 / 1.05, "Mortar gives up single-target damage efficiency compared with ranger")
	var captured := Frames.new()
	captured.warmup = 0.0
	captured.start({"fixture": true})
	var tag := {"friendly": 120, "enemies": 5, "encounter": "fixture", "reduced_effects": false}
	captured.sample(1000, true, tag)
	captured.sample(17000, true, tag)
	captured.sample(51000, true, tag)
	captured.sample(52000, false, tag)
	captured.sample(9000000, true, tag)
	captured.sample(9016000, true, tag)
	var report := captured.stop()
	check.call(report.all_frames.frames == 3 and report.heavy_frames.frames == 3 and report.all_frames.over_33_333_ms == 1, "Local timing fixture excludes pause gap and records heavy-frame tail")
	return true
