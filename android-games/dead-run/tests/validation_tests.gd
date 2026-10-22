extends SceneTree
const R = preload("res://scripts/campaign_rules.gd")
const S = preload("res://scripts/campaign_store.gd")
const D = preload("res://scripts/campaign_data.gd")
var checks := 0
var failures := 0
var details: Array = []
var folder := ""
var variant := "all"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--case="): variant = arg.trim_prefix("--case=")
	call_deferred("run")

func check(okay: bool, label: String) -> void:
	checks += 1
	details.append({"pass": okay, "label": label})
	if not okay:
		failures += 1
		print("FAIL ", label)

func write(name: String, data: String) -> void:
	var f := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
	f.store_string(data)
	f.close()

func bad(ctx: Dictionary, label: String, retain: bool = true, step_if_accepted: bool = false) -> void:
	var direct: Variant = R.valid(ctx.campaign)
	check(direct is bool and not direct, "direct validator rejects " + label)
	var code := S.encode(ctx, 500)
	var env: Dictionary = JSON.parse_string(code)
	check(env.payload.sha256_text() == env.sha256, "import checksum correct " + label)
	if retain: write(label + "-checked-save.json", code)
	var decoded := S.decode(code)
	check(not decoded.ok, "checked import rejects " + label)
	if step_if_accepted and decoded.ok:
		# Old-source sensitivity: ordinary stepping must never receive this period.
		R.step(decoded.context.campaign)

func late_context() -> Dictionary:
	var ctx := S.fresh()
	ctx.campaign = R.fresh(23)
	for i in 23:
		ctx.profile.clears.append(i)
		ctx.profile.medals[str(i)] = {"rescues": false, "no_loss": false, "best_crew": 5}
	return ctx

func boss_fixture() -> Dictionary:
	# Root's synthetic cancelled source=-1 fixture. Prior kills/clears are fabricated
	# only to isolate validation order; they are not earned gameplay evidence.
	var ctx := S.fresh()
	ctx.campaign = R.fresh(5)
	for i in 5:
		ctx.profile.clears.append(i)
		ctx.profile.medals[str(i)] = {"rescues": false, "no_loss": false, "best_crew": 5}
	var s: Dictionary = ctx.campaign
	s.phase = "playing"
	s.tick = s.definition.boss.born + 210
	for i in s.gates.size():
		var gd: Dictionary = s.definition.gates[i]
		s.gates[i].z = maxf(0, gd.z - maxi(0, s.tick - gd.born + 1) / 60.0 * s.definition.speed)
		s.gates[i].crossed = s.gates[i].z < 0.0001
	for i in s.enemies.size():
		if s.tick >= s.definition.enemies[i].born:
			s.enemies[i].hp = 0
			s.enemies[i].resolved = true
			s.enemies[i].dead = true
			s.enemies[i].z = 0.0
			s.kills += 1
	for i in s.obstacles.size():
		var od: Dictionary = s.definition.obstacles[i]
		s.obstacles[i].z = maxf(0, od.z - maxi(0, s.tick - od.born + 1) / 60.0 * s.definition.speed)
		s.obstacles[i].crossed = s.obstacles[i].z < 0.0001
	s.boss.hp = 0
	s.boss.dead = true
	s.boss.z = 14.0
	s.boss.next_attack = s.definition.boss.born + 570
	R.hazard(s, -1, 0.0, 0.85, s.definition.boss_loss, 180, "Cable sweep")
	s.hazards[0].resolved = true
	s.hazards[0].cancelled = true
	return ctx

func integral_paths(value: Variant, path: Array = []) -> Array:
	var paths: Array = []
	if value is Dictionary or value is Array:
		for key in value.keys() if value is Dictionary else range(value.size()):
			paths.append_array(integral_paths(value[key], path + [key]))
	elif (value is int or value is float) and float(value) == floor(float(value)):
		paths.append(path)
	return paths

func mutate(definition: Dictionary, path: Array) -> void:
	var parent: Variant = definition
	for key in path.slice(0, path.size() - 1): parent = parent[key]
	parent[path[-1]] = float(parent[path[-1]]) + 0.0000000001

func float_numbers(value: Variant) -> Variant:
	if value is int: return float(value)
	if value is Dictionary or value is Array:
		for key in value.keys() if value is Dictionary else range(value.size()): value[key] = float_numbers(value[key])
	return value

func run() -> void:
	if variant in ["all", "period-near"]:
		var ctx := S.fresh()
		ctx.campaign.phase = "playing"
		ctx.campaign.definition.weapons.rivet.period = 24.0000000001
		check(not D.same(ctx.campaign.definition, D.stage(0)), "pinned period near-integer is unequal")
		bad(ctx, "period-near", true, true)
	if variant == "all":
		for entry in [["below", 23.9999999999], ["outside", 24.00000001]]:
			var ctx := S.fresh()
			ctx.campaign.phase = "playing"
			ctx.campaign.definition.weapons.rivet.period = entry[1]
			bad(ctx, "period-" + entry[0])
	if variant in ["all", "period-whole"]:
		var ctx := S.fresh()
		ctx.campaign.phase = "playing"
		ctx.campaign.definition = float_numbers(ctx.campaign.definition)
		check(D.same(ctx.campaign.definition, D.stage(0)) and D.same(D.stage(0), ctx.campaign.definition), "equal whole-number floats match pins in both directions")
		check(R.valid(ctx.campaign), "direct validator accepts whole-number JSON representation")
		var decoded := S.decode(S.encode(ctx, 500))
		check(decoded.ok and decoded.context.campaign.definition.weapons.rivet.period is int, "checked JSON import normalizes valid whole-number period before arithmetic")
		if decoded.ok:
			for i in 24: R.step(decoded.context.campaign)
			check(decoded.context.campaign.tick == 24 and decoded.context.campaign.shots > 0 and R.valid(decoded.context.campaign), "imported whole-number representation steps cleanly through modulo firing")
	if variant == "all":
		check(not D.same(INF, INF) and not D.same(NAN, NAN), "nonfinite numeric equality rejected")
		check(not D.same(9007199254740992, 9007199254740993), "integer comparison retains precision beyond double mantissa")
		var ctx := late_context()
		check(S.valid(ctx), "synthetic final-road definition baseline valid")
		var paths := integral_paths(ctx.campaign.definition)
		for path in paths:
			var changed := ctx.duplicate(true)
			mutate(changed.campaign.definition, path)
			check(not D.same(changed.campaign.definition, ctx.campaign.definition), "exact integral pin " + str(path))
			bad(changed, "integral-pin-" + str(path), false)
		write("integral-pin-paths.json", JSON.stringify(paths, "  ", true, true))
	if variant == "all" or variant.begins_with("boss-"):
		var baseline := boss_fixture()
		check(R.valid(baseline.campaign) and S.decode(S.encode(baseline, 500)).ok, "synthetic cancelled boss hazard baseline validates directly and as checked import")
		for name in ["null", "array", "missing", "number", "string", "boolean", "empty-dictionary", "missing-dead", "wrong-dead", "wrong-arms"]:
			if variant != "all" and variant != "boss-" + name: continue
			var changed := baseline.duplicate(true)
			match name:
				"null": changed.campaign.boss = null
				"array": changed.campaign.boss = []
				"missing": changed.campaign.erase("boss")
				"number": changed.campaign.boss = 0
				"string": changed.campaign.boss = "boss"
				"boolean": changed.campaign.boss = false
				"empty-dictionary": changed.campaign.boss = {}
				"missing-dead": changed.campaign.boss.erase("dead")
				"wrong-dead": changed.campaign.boss.dead = []
				"wrong-arms": changed.campaign.boss.arms = null
			bad(changed, "boss-" + name)
	write("rules-report.json", JSON.stringify({"checks": checks, "failures": failures, "details": details, "case": variant, "scope": "Headless structural validation/import regression. Late/profile/boss fixtures are synthetic, not earned gameplay or native evidence."}, "  ", true, true))
	print("VALIDATION ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
