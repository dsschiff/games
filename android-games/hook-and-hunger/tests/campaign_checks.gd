extends SceneTree
const C = preload("res://scripts/campaign_rules.gd")
const D = preload("res://scripts/campaign_data.gd")
const E = preload("res://scripts/engine.gd")
const L = preload("res://scripts/rules.gd")
const S = preload("res://scripts/save_store.gd")
const P = preload("res://tests/campaign_policy.gd")
const Fault = preload("res://tests/fault_files.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var settings := {"sound": true, "reduced_effects": true}
	for stage in 12:
		var tier := 1 if stage <= 3 else (2 if stage <= 6 else 3)
		var s := C.fresh(stage, tier, 1200)
		check(D.valid(s.definition) and C.valid(s), "valid new campaign definition " + str(stage))
		check(C.valid(JSON.parse_string(JSON.stringify(s))), "JSON campaign state roundtrip " + str(stage))
		var profile := C.profile()
		profile.stage = stage
		for cleared in range(-1, stage):
			profile.clears.append(cleared)
		check(C.valid_profile(profile) and S.decode(S.encode(s, settings, 1, true, profile)).ok, "complete campaign packet roundtrip " + str(stage))
		if C.cost(s) > 0:
			var cost := C.cost(s)
			check(C.purchase(s) and s.wallet == 1200 - cost and s.hp == 100, "earned dock upgrade accounting " + str(stage))
			check(C.valid(s) and C.cost(s) == 0, "one-time upgrade coherence " + str(stage))
			var bought := s.duplicate(true)
			bought.spent = 0
			bought.wallet = 1200
			check(not C.valid(bought), "reject uncharged power increase " + str(stage))
	var s := C.fresh(4, 2, 1500)
	check(C.target(s) == -1, "safe dock cannot fire into arena")
	var gated := C.fresh(3, 1, 1200)
	check(C.target(gated) == -1, "unbought power gate blocks combat as well as movement")
	var rock: Dictionary = s.definition.obstacles[0]
	var center := Vector2(rock.x, rock.z)
	check(C.constrain(s, center, 0.4).distance_to(center) >= float(rock.radius) + 0.399, "new arena collision resolves rock center")
	check(not C.clear_line(s, center - Vector2(2, 0), center + Vector2(2, 0)), "rock blocks chain and enemy attack sightline")
	var shield: Dictionary = {}
	for e in s.enemies:
		if s.definition.roster[int(e.id)].role == "shield":
			shield = e
			break
	shield.facing = 0.0
	s.x = shield.x
	s.z = shield.z + 1.5
	check(C.shielded(s, shield), "frontal armor blocks damage")
	shield.mode = "recover"
	check(C.shielded(s, shield), "recovery alone cannot replace flanking")
	s.z = shield.z - 1.5
	check(not C.shielded(s, shield), "back approach defeats armor")
	s = C.fresh(2, 1, 800)
	s.definition.obstacles = []
	var spec: Dictionary = s.definition.roster[-1]
	var boss := C.actor(spec)
	boss.ax = 0.0
	boss.az = -6.0
	boss.tx = 0.0
	boss.tz = 1.0
	s.x = 0.0
	s.z = -3.0
	boss.attack = "ring"
	C._resolve(s, boss, spec)
	check(s.hp == 68, "hollow boss ring punishes outer-reach holding")
	s.hp = 100.0
	s.z = -5.0
	C._resolve(s, boss, spec)
	check(s.hp == 100, "stepping inside hollow ring is safe")
	boss.attack = "slam"
	C._resolve(s, boss, spec)
	check(s.hp == 68, "solid slam punishes close holding")
	s.hp = 100.0
	s.z = -1.0
	C._resolve(s, boss, spec)
	check(s.hp == 100, "leaving solid slam is safe")
	boss.attack = "line"
	C._resolve(s, boss, spec)
	check(s.hp == 68, "locked line reaches outside weapon range")
	s.hp = 100.0
	s.x = 2.0
	C._resolve(s, boss, spec)
	check(s.hp == 100, "sidestep avoids line")
	check(C._attack_kind(spec, {"cycles": 0}) == "ring" and C._attack_kind(spec, {"cycles": 1}) == "slam" and C._attack_kind(spec, {"cycles": 2}) == "line", "boss alternates incompatible safe positions")
	s = C.fresh(1, 1, 1000)
	s.definition.obstacles = []
	s.enemies = []
	s.x = 0.0
	s.z = -2.0
	var shooter := {"x": 0.0, "z": -5.0, "tx": 0.0, "tz": 1.0}
	C._projectile(s, shooter, {"damage": 18.0}, 0.0)
	for frame in 30:
		C.step(s, Vector2.ZERO, 1.0 / 60)
	check(s.hp == 82 and s.projectiles.is_empty(), "travelling projectile hits exactly once")
	s.hp = 100.0
	s.definition.obstacles = [{"x": 0.0, "z": -3.5, "radius": 0.8}]
	C._projectile(s, shooter, {"damage": 18.0}, 0.0)
	for frame in 30:
		C.step(s, Vector2.ZERO, 1.0 / 60)
	check(s.hp == 100 and s.projectiles.is_empty(), "cover intercepts projectile before contact")
	s = C.fresh(7, 3, 2000)
	var tender: Dictionary = {}
	var ally: Dictionary = {}
	for e in C.active(s):
		if s.definition.roster[int(e.id)].role == "tender":
			tender = e
		else:
			ally = e
	tender.x = 0.0
	tender.z = -6.0
	tender.heal_clock = 0.0
	ally.x = 0.0
	ally.z = -4.0
	ally.hp -= 100
	var hp_before: float = ally.hp
	s.x = 0.0
	s.z = 0.0
	C.step(s, Vector2.ZERO, 1.0 / 60)
	check(ally.hp > hp_before and s.heals == 1, "living tender visibly sustains another creature")
	var enemy_count: int = s.enemies.size()
	check(s.enemies.size() == enemy_count and s.dead.is_empty(), "healing never creates or resurrects an enemy ID")
	var arena1 := C.fresh(11, 1, 0, 1701, true)
	var arena3 := C.fresh(11, 3, 0, 1701, true)
	var arena_next := C.fresh(11, 3, 0, 1702, true)
	check(arena1.definition.roster == arena3.definition.roster, "same-seed replay loadouts face identical enemies")
	check(arena3.definition.roster != arena_next.definition.roster, "new seed changes actual formation")
	check(C.weapon(arena1).reach > C.weapon(arena3).reach and C.weapon(arena1).damage < C.weapon(arena3).damage, "replay refit trades longer reach for damage")
	check(D.ARENA_WEAPONS[2].cleave > C.weapon(arena3).cleave and D.ARENA_WEAPONS[2].period > C.weapon(arena3).period, "heavy refit trades recovery for cleave")
	check(C.valid(arena1) and C.valid(arena3) and C.valid(arena_next), "all seeded arena states validate")
	var reach_trial := arena1.duplicate(true)
	reach_trial.definition.obstacles = []
	reach_trial.enemies = [reach_trial.enemies[1]]
	reach_trial.x = 0.0
	reach_trial.z = 0.0
	reach_trial.enemies[0].x = 0.0
	reach_trial.enemies[0].z = -4.4
	check(C.target(reach_trial) >= 0, "long refit contacts target before a short weapon can reach")
	reach_trial.tier = 3
	check(C.target(reach_trial) == -1, "storm recovery advantage costs the long refit's extra reach")
	var cleave_totals := []
	for loadout in [2, 3]:
		var trial := C.fresh(11, loadout, 0, 1701, true)
		trial.definition.obstacles = []
		trial.enemies = [trial.enemies[1], trial.enemies[2], trial.enemies[3]]
		trial.x = 0.0
		trial.z = 0.0
		trial.strike_id = 1
		trial.strike_x = 0.0
		trial.strike_z = -2.0
		var before_total := 0.0
		for i in 3:
			trial.enemies[i].x = 0.0 if i == 0 else (1.7 if i == 1 else -1.7)
			trial.enemies[i].z = -2.0
			before_total += trial.enemies[i].hp
		C._strike(trial)
		var after_total := 0.0
		for enemy in trial.enemies:
			after_total += enemy.hp
		cleave_totals.append(before_total - after_total)
	check(cleave_totals[0] == 345 and cleave_totals[1] == 78, "heavy cleave damages three separated targets while faster Storm contacts one")
	# Exact old active state and its displayed combat meaning remain immutable.
	var old := L.fresh()
	for frame in 90:
		L.step(old, Vector2(0, -1), 1.0 / 60)
	var old_payload := JSON.stringify({"version": 1, "revision": 33, "committed": true, "state": old, "settings": settings})
	var old_source := JSON.stringify({"payload": old_payload, "sha256": old_payload.sha256_text()})
	var migrated := S.decode(old_source)
	var expected := L.restore(JSON.parse_string(JSON.stringify(old)))
	check(migrated.ok and migrated.state == expected and migrated.state.size() == expected.size(), "whole old version1 active state preserved without added or lost fields")
	check(migrated.settings == settings and migrated.revision == 33, "old settings/revision retained")
	check(E.weapon(migrated.state) == L.weapon(expected) and E.roster(migrated.state) == L.ROSTER, "old displayed weapon and roster retain shipped meaning")
	for frame in 180:
		L.step(expected, Vector2(0.5, -0.2), 1.0 / 60)
		E.step(migrated.state, Vector2(0.5, -0.2), 1.0 / 60)
	check(migrated.state == expected, "resumed old state executes identical combat trajectory")
	var io := Fault.new()
	check(S.write(migrated.state, settings, "migration", io, false, migrated.profile), "migrated state writes version2 envelope")
	check(S.read("migration", io).state == L.restore(JSON.parse_string(JSON.stringify(expected))), "migrated state survives new-format durable reload")
	var malformed := C.fresh(3, 1, 0)
	check(not C.valid(malformed), "reject new encounter with unaffordable power gate checkpoint")
	malformed = arena3.duplicate(true)
	malformed.wallet += 1
	check(not C.valid(malformed), "reject duplicated new-campaign currency")
	malformed = arena3.duplicate(true)
	malformed.wave = 1
	check(not C.valid(malformed), "reject skipped uncleared wave")
	malformed = C.fresh(3, 1, 1200)
	malformed.definition.offer = 0
	check(not C.valid(malformed), "reject edited gate with no available required purchase")
	malformed = C.fresh(4, 2, 1200)
	malformed.definition.obstacles.append({"x": 0.0, "z": 1.0, "radius": 1.3})
	check(not C.valid(malformed), "reject edited collision layout that could seal an active route")
	var impossible := L.fresh()
	impossible.dead = [0,1,2,3,4,5,6,7]
	impossible.collected = impossible.dead.duplicate()
	impossible.enemies = []
	impossible.wallet = 99
	impossible.phase = "victory"
	check(not S.decode(S.encode(impossible, settings, 0)).ok, "reject legacy victory without its mandatory paid weapon before campaign transition")
	impossible = L.fresh()
	impossible.dead = [0]
	impossible.enemies.remove_at(0)
	impossible.drops = [{"id": 0, "x": -3.8, "z": 0.0}]
	check(not S.decode(S.encode(impossible, settings, 0)).ok, "reject legacy required reward trapped inside solid rock")
	print("CAMPAIGN_CHECKS: ", checks, " checks; failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func check(okay: bool, text: String) -> void:
	checks += 1
	if not okay:
		failures += 1
		push_error(text)
