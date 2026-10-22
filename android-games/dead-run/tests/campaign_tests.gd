extends SceneTree
const D = preload("res://scripts/campaign_data.gd")
const R = preload("res://scripts/campaign_rules.gd")
const S = preload("res://scripts/campaign_store.gd")
const Old = preload("res://scripts/save_store.gd")
const Legacy = preload("res://scripts/rules.gd")
const P = preload("res://tests/campaign_policy.gd")
const Fault = preload("res://tests/fault_files.gd")
const Boundary = preload("res://tests/campaign_boundary.gd")
const Catalog1 = preload("res://scripts/catalog1_rules.gd")
const Catalog1Data = preload("res://scripts/catalog1_data.gd")
var checks := 0
var failures := 0
var details: Array = []
var legacy_file := ""
var outcomes: Array = []

func check(okay: bool, label: String) -> void:
	checks += 1
	details.append({"pass": okay, "label": label})
	if not okay:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-fixture="): legacy_file = arg.trim_prefix("--legacy-fixture=")
	call_deferred("run")

## Genuine code4 (0.3.0) app-written save with road 7 in progress, produced by
## the unmodified code4 project (tests/fixtures/code4-midroad). Profile clears
## in it are a labelled fixture; the road itself was simulated by code4.
func code4_midroad() -> void:
	var dir := "res://tests/fixtures/code4-midroad/"
	var best := {"ok": false}
	for slot in 2:
		var d := S.decode(FileAccess.get_file_as_string(dir + "dead-run-save-" + str(slot)))
		if d.ok and (not best.ok or d.revision > best.revision): best = d
	check(best.ok and not best.migrated, "code4 mid-road save decodes under code5")
	if not best.ok: return
	var ctx: Dictionary = best.context
	var road: Dictionary = ctx.campaign
	check(R.catalog1(road) and road.definition.rule_version == 2 and road.phase == "playing" and road.tick == 1500 and road.weapon == "lance", "code4 road keeps its pinned catalog1/rule2 definition, phase, tick and weapon")
	check(D.same(road.definition, Catalog1Data.stage(6)) and not D.same(road.definition, D.stage(6)), "pinned code4 definition is the catalog1 road, not the horde road")
	check(R.valid(road) and S.valid(ctx), "code4 road and whole context validate through the catalog1 rules")
	check(ctx.profile.clears == [0, 1, 2, 3, 4, 5] and ctx.profile.medals["1"] == {"rescues": false, "no_loss": true, "best_crew": 9} and ctx.profile.medals["4"].best_crew == 12 and not ctx.profile.ending, "code4 clears, medals and best crew survive exactly")
	check(ctx.settings == {"sound": false, "reduced_effects": true} and ctx.loadout == "lance" and ctx.mode == "campaign" and Legacy.valid(ctx.legacy), "code4 settings, loadout and parked legacy body survive")
	var untouched: Dictionary = ctx.duplicate(true)
	check(not S.upgrade(ctx) and D.same(ctx, untouched), "a code4 road in progress is never silently re-simulated or upgraded")
	var cont: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "continuation.json"))
	var steers := {}
	for pair in cont.steers: steers[int(pair[0])] = float(pair[1])
	var live: Dictionary = S.integers(road.duplicate(true))
	var every := true
	while live.phase == "playing":
		if steers.has(live.tick): R.steer(live, steers[live.tick])
		R.step(live)
		if live.tick % 300 == 0: every = every and R.valid(live)
	var final: Dictionary = S.integers(cont.final)
	check(every and D.same(live, final) and D.same(final, live), "code5 continues the code4 road tick-for-tick to the exact code4 result (%s, crew %d)" % [live.phase, live.crew])
	ctx.campaign = live
	S.award(ctx)
	check(ctx.profile.clears.size() == 7 and S.valid(ctx) and S.decode(S.encode(ctx, 9)).ok, "finishing the code4 road earns its clear and still saves")
	check(not S.upgrade(ctx) and R.catalog1(ctx.campaign), "a finished code4 road keeps showing its own result")
	var ready: Dictionary = ctx.duplicate(true)
	ready.campaign = Catalog1.fresh(7, "fan")
	var profile_before: Dictionary = ready.profile.duplicate(true)
	check(S.upgrade(ready) and not R.catalog1(ready.campaign) and D.same(ready.campaign.definition, D.stage(7)) and ready.campaign.weapon == "fan" and ready.campaign.phase == "ready", "an unstarted code4 road opens as the same road and weapon under the horde rules")
	check(D.same(ready.profile, profile_before) and S.valid(ready), "upgrading an unstarted road leaves progress untouched")

func run() -> void:
	var ctx := S.fresh()
	check(S.valid(ctx) and S.decode(S.encode(ctx, 1)).ok, "fresh schema2 context round trip")
	var old := Legacy.fresh()
	old.phase = "playing"
	for i in 103: Legacy.step(old)
	var migrated := S.decode(Old.encode(old, {"sound": false, "reduced_effects": true}, 384))
	check(migrated.ok and migrated.migrated and migrated.context.mode == "legacy" and D.same(migrated.context.legacy, old), "schema1 active run migrates whole legacy meaning")
	check(migrated.context.profile == S.profile() and migrated.context.campaign.phase == "ready", "old run fabricates no campaign clears/rewards")
	for survives in [false, true]:
		var boundary := Boundary.make(survives)
		check(R.valid(boundary), "campaign exhaustion fixture valid before ordinary step " + str(survives))
		R.step(boundary)
		check(R.valid(boundary), "campaign exhaustion fixture valid after ordinary step " + str(survives))
		var boundary_ctx := S.fresh()
		boundary_ctx.campaign = boundary
		check(S.decode(S.encode(boundary_ctx, 2)).ok, "campaign exhaustion boundary remains saveable " + str(survives))
		if survives:
			check(boundary.phase == "playing" and boundary.crew == 7 and boundary.joined == 6 and boundary.lost == 4 and boundary.sides[0].claimed, "living campaign contact still grants exact crane payout")
		else:
			check(boundary.phase == "defeat" and boundary.crew == 0 and boundary.joined == 0 and boundary.lost == 5 and not boundary.sides[0].claimed, "campaign depletion cannot revive through queued crane hit")
			var dead := boundary.duplicate(true)
			R.step(boundary)
			check(dead == boundary, "campaign depletion remains terminal")
			check(R.adjust(boundary, 3, "later paired-gate reward") == 0 and boundary.crew == 0 and R.valid(boundary), "depleted formation cannot revive through any later gate/target reward")
			var revived := boundary.duplicate(true)
			revived.phase = "playing"
			revived.crew = 3
			revived.members = [5, 6, 7]
			revived.next_member = 8
			revived.joined = 3
			revived.sides[0] = {"id": 0, "hp": 0, "claimed": true, "claimed_at": revived.tick, "delta": 3}
			revived.events.append({"tick": revived.tick, "cause": "invalid reward after depletion", "delta": 3})
			check(not R.valid(revived), "conserved final totals cannot hide resurrection in event history")
	if not legacy_file.is_empty():
		var code := FileAccess.get_file_as_string(legacy_file)
		var original := Old.decode(code)
		var real := S.decode(code)
		check(original.ok and original.state.tick == 103 and original.revision == 384, "read supplied genuinely earned native code1 fixture")
		check(real.ok and D.same(original.state, real.context.legacy) and original.settings == real.context.settings, "whole actual native legacy state/settings preserved by schema2 migration")
		check(real.context.profile == S.profile(), "actual old native active run creates empty campaign profile")
		check(D.same(S.decode(S.encode(real.context, 385)).context.legacy, original.state), "native legacy whole body survives new schema checked round trip")
	code4_midroad()
	var total := 0
	var first_terminal := {}
	var signatures := {}
	for index in 24:
		var def := D.stage(index)
		total += def.duration
		signatures[JSON.stringify([def.enemies, def.gates, def.obstacles, def.floods, def.boss])] = true
		check(R.valid(R.fresh(index)), "pinned authored definition %02d validates" % (index + 1))
		check(def.enemies[-1].born > def.duration - 420, "late visible pressure persists near evacuation %02d" % (index + 1))
	check(total == 135600 and total / 60.0 / 60.0 >= 30 and total / 60.0 / 60.0 <= 60, "24 roads contain 2260 seconds / 37.67 minutes active simulation")
	check(signatures.size() == 24, "24 serialized encounter structures differ; not a duration/fun proof")
	for count in range(1, D.CAP + 1):
		var bounded := true
		for i in count:
			bounded = bounded and absf(R.offset(i, count).x) + 0.24 <= R.half_width(count) + 0.00001
		check(bounded, "render/contact footprint agrees for all members at count " + str(count))
	check(R.half_width(5) < R.half_width(10) and R.half_width(10) < R.half_width(20) and R.half_width(20) < R.half_width(49), "recruit growth meaningfully widens formation")
	for count in range(1, 26):
		var same_layout := true
		for i in count: same_layout = same_layout and R.offset(i, count) == Catalog1.offset(i, count)
		check(same_layout and R.half_width(count) == Catalog1.half_width(count), "rule3 formation equals catalog1 formation at count " + str(count))
	check(4.35 - R.half_width(D.CAP) > R.half_width(D.CAP) + 1.1, "a full 49-crew blob can still clear a centre-lane wide cart")
	var s := R.fresh(6, "rivet")
	var e: Dictionary = s.enemies[0]
	var bullet := {"x": 0.0, "hit_ids": [], "remaining": 1}
	R.strike(s, bullet, {"kind": "enemy", "id": 0})
	check(e.armor == 2 and e.hp == 6, "Rivet hits consume plated armor before health")
	s = R.fresh(6, "lance")
	bullet = {"x": 0.0, "hit_ids": [], "remaining": 4}
	check(not R.strike(s, bullet, {"kind": "enemy", "id": 0}) and s.enemies[0].hp == 4 and s.enemies[0].armor == 3 and bullet.remaining == 3 and bullet.hit_ids == [0], "Lance bypasses armor and retains owned piercing capacity")
	check(not R.strike(s, bullet, {"kind": "enemy", "id": 0}) and s.enemies[0].hp == 4, "same piercing projectile cannot hit one enemy twice")
	s = R.fresh(11)
	var hp: int = s.boss.hp
	R.strike(s, {"x": 0.0}, {"kind": "boss"})
	check(s.boss.hp == hp, "Toll Ram centre shield blocks Rivet")
	R.strike(s, {"x": 0.9}, {"kind": "boss"})
	check(s.boss.hp == hp - 1, "Toll Ram flank fire damages shielded boss")
	s = R.fresh(11, "lance")
	R.strike(s, {"x": 0.0}, {"kind": "boss"})
	check(s.boss.hp == hp - 2, "Lance centre hit bypasses Toll shield")
	s = R.fresh(23)
	s.tick = s.definition.boss.born
	check(R.targets(s).filter(func(t):return t.kind == "boss").is_empty() and R.targets(s).filter(func(t):return t.kind == "arm").size() == 2, "Ferry Eater core cannot be targeted before both arms")
	for i in s.definition.boss.arms:
		R.strike(s, {}, {"kind": "arm", "id": 0})
		R.strike(s, {}, {"kind": "arm", "id": 1})
	check(R.targets(s).filter(func(t):return t.kind == "boss").size() == 1, "breaking both arms exposes final core")
	# Whole catalog rule-policy fixtures supplement, not replace, actual engine input.
	ctx = S.fresh()
	for index in 24:
		var weapon: String = ["rivet", "lance", "fan"][index % 3]
		s = R.fresh(index, weapon)
		ctx.campaign = s
		s.phase = "playing"
		var every := true
		while s.phase == "playing":
			if s.tick % 15 == 0: R.steer(s, P.aim(s))
			R.step(s)
			if s.tick % 60 == 0: every = every and R.valid(s)
		check(every and R.valid(s), "rule-policy state/ownership/ledgers valid across stage " + str(index + 1))
		check(s.phase == "victory", "rule-policy can clear authored stage " + str(index + 1))
		S.award(ctx)
		check(S.valid(ctx) and S.decode(S.encode(ctx, index + 1)).ok, "earned ledger/profile/checkpoint save coherent stage " + str(index + 1))
		var before: Dictionary = ctx.profile.duplicate(true)
		S.award(ctx)
		check(before == ctx.profile, "same terminal cannot duplicate clear/reward stage " + str(index + 1))
		outcomes.append({"index": index, "weapon": weapon, "crew": s.crew, "lost": s.lost, "kills": s.kills, "leaks": s.leaks})
		if index == 0: first_terminal = s.duplicate(true)
		if index in [0, 11, 23]:
			var bad := s.duplicate(true)
			bad.members.append(999999)
			check(not R.valid(bad), "member/formation ledger rejects malformed ownership")
			bad = s.duplicate(true)
			bad.definition.enemies[0].hp += 1
			check(not R.valid(bad), "full pinned definition rejects modified enemy values")
			bad = s.duplicate(true)
			bad.gates[0].crossed = false
			check(not R.valid(bad), "gate cannot be replayed by import")
	check(ctx.profile.ending and ctx.profile.clears.size() == 24, "complete profile earns conclusive ending once")
	for last_tick in [4498, 4499]:
		var boundary := first_terminal.duplicate(true)
		boundary.tick = last_tick
		boundary.phase = "playing"
		boundary.rewarded = false
		boundary.boss.dead = false
		boundary.boss.hp = 1
		boundary.boss.z = maxf(0, 23.0 - float(last_tick - boundary.definition.boss.born + 1) / 60.0 * 1.35)
		# Rewinding a full-cap crew two ticks must also rewind its shot count and
		# the infected still walking when the evacuation finished.
		for i in boundary.enemies.size():
			var ed: Dictionary = boundary.definition.enemies[i]
			if not boundary.enemies[i].resolved: boundary.enemies[i].z = maxf(0, ed.z - maxi(0, last_tick - ed.born + 1) / 60.0 * ed.speed)
		boundary.shots = mini(boundary.shots, floori(float(last_tick) / boundary.definition.weapons[boundary.weapon].period) * boundary.definition.cap)
		boundary.bullets = [{"id": boundary.shots - 1, "owner": 0, "x": 0.0, "z": 0.01, "dx": 0.0, "remaining": 1, "hit_ids": []}]
		check(R.valid(boundary), "synthetic final-hit/deadline boundary validates before step " + str(last_tick))
		R.step(boundary)
		check(R.valid(boundary), "final-hit/deadline ordering stays valid " + str(last_tick))
		if last_tick == 4498:
			check(boundary.boss.dead and boundary.phase == "playing", "queued hit one tick before deadline legitimately clears blockade")
			R.step(boundary)
			check(boundary.phase == "victory", "cleared objective then wins at evacuation deadline")
		else: check(boundary.phase == "defeat" and boundary.boss.hp == 1, "deadline precedes a too-late queued projectile")
	var seed_structures := {}
	for seed in range(1, 33):
		var seeded := D.stage(23, seed)
		seed_structures[JSON.stringify([seeded.enemies, seeded.gates, seeded.obstacles, seeded.floods])] = true
	check(seed_structures.size() == 32, "32 sampled seeds yield32 structural encounter variants, excluding seed labels")
	for seed in [61723, 42, 991]:
		check(D.same(D.stage(23, seed), D.stage(23, seed)), "seeded definition deterministic " + str(seed))
		check(not D.same(D.stage(23, seed), D.stage(23)), "seeded replay differs from authored finale " + str(seed))
		var replay := R.fresh(23, "fan", seed)
		replay.phase = "playing"
		while replay.phase == "playing":
			if replay.tick % 15 == 0: R.steer(replay, P.aim(replay, "line"))
			R.step(replay)
		check(replay.phase == "victory" and R.valid(replay), "bounded rule-policy seeded replay can finish " + str(seed))
	var io := Fault.new()
	check(S.write(ctx, "campaign-test", io), "checked campaign durable save")
	var before := S.read("campaign-test", io)
	io.fail_write = true
	check(not S.write(ctx, "campaign-test", io) and S.read("campaign-test", io).revision == before.revision, "partial campaign write preserves prior slot")
	io.fail_write = false
	io.fail_rename = true
	check(not S.write(ctx, "campaign-test", io, true) and S.read("campaign-test", io).revision == before.revision, "failed import promotion cannot displace checked campaign")
	io.fail_rename = false
	check(S.write(ctx, "campaign-test", io, true) and S.read("campaign-test", io).context.profile.ending, "successful imported promotion retains earned ending")
	var bad_ctx := ctx.duplicate(true)
	bad_ctx.profile.clears = [0, 2]
	check(not S.valid(bad_ctx), "campaign progression rejects missing/skip clear sequence")
	bad_ctx = ctx.duplicate(true)
	bad_ctx.campaign.bullets = [{"id": 0, "owner": 99999, "x": 0.0, "z": 1.0, "dx": 0.0, "remaining": 1, "hit_ids": []}]
	check(not S.valid(bad_ctx), "projectile owner must belong to a real recruited member ID")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"checks": checks, "failures": failures, "details": details, "outcomes": outcomes, "scope": "Rules/storage and explicit rule-policy fixtures. Actual GUI campaign evidence is separate. Native source fixture is migration-only."}, "  "))
	print("CAMPAIGN_RULES ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
