extends "res://tests/campaign_input.gd"
## Rendered graphics inspection frames at 720x1280 (plus inner/cover sizes).
## VISUAL HARNESS ONLY: later roads are opened by writing a labelled fixture
## clear list into an isolated profile, never earned progress. Steering uses
## the read-only policy through real touch-drag events; Start uses the real UI.
const SCENARIOS := {
	"early": [0, "rivet", [420, 900, 1500]],
	"dense": [10, "fan", [1500, 2210, 2600, 3500]],
	"cluster": [4, "fan", [1300, 1904, 2500]],
	"reservoir": [14, "rivet", [1700, 3300]],
	"matron": [5, "rivet", ["boss+120", "boss+600"]],
	"ram": [11, "rivet", ["boss+60", "boss+400"]],
	"bell": [17, "rivet", ["boss+90", "boss+500"]],
	"ferry": [23, "rivet", ["boss+60", "boss+700", "victory"]],
	# Horde rule3: surges flood every lane before the blockade or finale.
	"surge": [10, "fan", [4200, 4520]],
	"surge-lance": [12, "lance", [3700, 3980]],
	"mid": [8, "rivet", [2000, 2900]],
}
var scenario := "all"

func _initialize() -> void:
	super._initialize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")

func run() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	await dwell(6)
	for name in SCENARIOS:
		if scenario != "all" and name not in scenario.split(","): continue
		await play_scenario(name, SCENARIOS[name])
	if scenario == "all" or "sizes" in scenario.split(","):
		await sizes()
	print("GRAPHICS_FRAMES checks=", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func play_scenario(name: String, spec: Array) -> void:
	var index: int = spec[0]
	fixture_clears(index)
	scene.ctx.loadout = spec[1]
	scene.load_road(index)
	await dwell(4)
	await click("START RESCUE")
	check(scene.state.phase == "playing" and scene.state.definition.index == index, name + " fixture road started through actual Start button")
	var marks: Array = spec[2].duplicate()
	var born: int = scene.state.definition.boss.born
	prior_aim = 999
	for frame in 9000:
		if marks.is_empty(): break
		if scene.state.phase != "playing":
			if str(marks[0]) == "victory" and scene.state.phase == "victory":
				await dwell(240)
				await snap("%s-victory" % name)
			else:
				check(str(marks[0]) == "victory", name + " reached planned capture before terminal phase " + scene.state.phase + " at " + str(scene.state.tick) + " " + scene.state.notice)
			break
		if frame % 12 == 0:
			var target := Policy.aim(scene.state, "rescue")
			if absf(target - prior_aim) > 0.025:
				drive(target)
				prior_aim = target
		await physics_frame
		var mark: Variant = marks[0]
		var due: int = born + int(String(mark).trim_prefix("boss+")) if mark is String and String(mark).begins_with("boss+") else (int(mark) if mark is int else 1 << 30)
		if scene.state.tick >= due:
			await snap("%s-t%04d" % [name, scene.state.tick])
			marks.pop_front()
	await release()
	check(C.valid(scene.state), name + " state remains rule-valid under presentation")

## Labelled visual fixture: a structurally valid profile with prior roads
## marked cleared so later districts can be rendered. Not earned progress.
func fixture_clears(count: int) -> void:
	var p: Dictionary = scene.ctx.profile
	p.clears = Array(range(count))
	p.medals = {}
	for i in count: p.medals[str(i)] = {"rescues": false, "no_loss": false, "best_crew": 5}
	p.ending = count == 24

func sizes() -> void:
	fixture_clears(12)
	scene.ctx.loadout = "fan"
	scene.load_road(12)
	await click("START RESCUE")
	for i in 2200:
		if i % 12 == 0: drive(Policy.aim(scene.state, "rescue"))
		await physics_frame
	await release()
	await snap("size-native-720x1280")
	scene.settings.reduced_effects = true
	await dwell(30)
	await snap("size-reduced-effects")
	scene.settings.reduced_effects = false
	await click("II")
	root.size = Vector2i(1000, 1110)
	await dwell(8)
	await click("RESUME")
	await dwell(60)
	await snap("size-inner-1000x1110")
	root.size = Vector2i(720, 1680)
	await dwell(60)
	await snap("size-cover-720x1680")
	root.size = Vector2i(720, 1280)
	await dwell(10)
