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
	var replay_run := run_state.duplicate(true)
	replay_run.config.challenge = true
	Profile.award(profile, replay_run)
	replay_run.wall = 100.0
	replay_run.time = 500.0
	Profile.award(profile, replay_run)
	check.call(profile.challenge_clears["camp_01:1701"] == 3 and profile.cleared.size() == 1, "A worse replay preserves the best earned challenge medals without campaign advancement")
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
	pinned.config.deployment_seconds = 0.0
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
	var reserves := Battle.initial(1701, "camp_07")
	var old_reserves := reserves.duplicate(true)
	old_reserves.config.erase("reserve_by_exit")
	for run in [reserves, old_reserves]:
		Battle.start(run)
		run.serial = 12
		var defender := Battle.make_unit(run, "guard", 0, true)
		defender.x = 116.0
		defender.y = 300.0
		run.units = [defender]
		Battle.tick(run, Battle.STEP)
	check.call(float(reserves.units[0].x) < 116 and float(old_reserves.units[0].x) > 116, "Exit-specific reserves retain their flank while older snapshots retain global holding behavior")
	var restored_reserves := Saves.decode(Saves.encode(reserves, {}))
	check.call(restored_reserves.ok and restored_reserves.state.config.reserve_by_exit, "Exit-reserve behavior is pinned in the active encounter save")
	var salvage := Battle.initial(1701, "camp_08")
	Policy.apply(salvage, "B")
	Battle.start(salvage)
	salvage.wave = 2
	salvage.gold += 6
	salvage.claimed_grants = 6
	Policy.adapt(salvage, "B")
	check.call(salvage.spent == 72 and salvage.gold == 4 and salvage.board[Gear.at(salvage.board, 1, 2)].kind == "ranger" and salvage.board[Gear.at(salvage.board, 3, 2)].kind == "ranger" and Saves.decode(Saves.encode(salvage, {})).ok, "Salvage refits use their actual price and preserve the saved budget")
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
	var deployment := Battle.initial(1701, "camp_01")
	Policy.apply(deployment, "A")
	Battle.start(deployment)
	for i in 36:
		Battle.tick(deployment, Battle.STEP)
	var staged: Array = deployment.units.filter(func(u): return float(u.get("deploy_left", 0)) > 0)
	check.call(not staged.is_empty() and deployment.produced == deployment.units.size(), "Production creates real capped staging actors rather than decorative duplicates")
	var staged_packet := Saves.decode(Saves.encode(deployment, {}))
	check.call(staged_packet.ok, "Generator-to-gate path persists through a normal save")
	var original_run := deployment.duplicate(true)
	var continued: Dictionary = staged_packet.state
	for i in 120:
		Battle.tick(original_run, Battle.STEP)
		Battle.tick(continued, Battle.STEP)
	var same: bool = original_run.units.size() == continued.units.size() and original_run.enemies.size() == continued.enemies.size() and original_run.produced == continued.produced and original_run.kills == continued.kills and is_equal_approx(float(original_run.wall), float(continued.wall))
	for index in mini(original_run.units.size(), continued.units.size()):
		for key in ["id", "x", "y", "hp", "deploy_left"]:
			same = same and is_equal_approx(float(original_run.units[index].get(key, 0)), float(continued.units[index].get(key, 0)))
	check.call(same, "Saved staging path resumes deterministically through gate deployment and combat")
	var staged_bad := deployment.duplicate(true)
	staged_bad.units[0].deploy_total = 0.0
	check.call(not Saves.decode(Saves.encode(staged_bad, {})).ok, "Zero-duration staging path is rejected before rendering")
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
