extends SceneTree
## Headless presentation checks: the renderer never changes rule state, effects
## start once per observed change, pools stay bounded, rebuild/hydrate clears
## transients, pause freezes effects, reduced effects keeps telegraphs.
const C = preload("res://scripts/campaign_rules.gd")
const Policy = preload("res://tests/campaign_policy.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(okay: bool, label: String) -> void:
	checks += 1
	if not okay:
		failures += 1
		print("FAIL ", label)

func steer_policy(s: Dictionary) -> void:
	if s.tick % 12 == 0: C.steer(s, Policy.aim(s, "rescue"))

func run() -> void:
	var scene: Node = load("res://campaign.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	for road in [0, 11, 17, 23]:
		# Control: identical rule stepping with no scene at all.
		var control := C.fresh(road, "fan")
		control.phase = "playing"
		scene.state = C.fresh(road, "fan")
		scene.state.phase = "playing"
		scene.ctx.campaign = scene.state
		scene.paused = false
		scene.journey_visible = false
		scene.build_world()
		scene.refresh()
		var p: RefCounted = scene.presentation
		var peak_pool := 0
		var peak_particles := 0
		for t in 6600:
			if control.phase != "playing": break
			steer_policy(control)
			steer_policy(scene.state)
			C.step(control)
			C.step(scene.state)
			scene.refresh()
			p.frame(1.0 / 60.0, false)
			for key in p.pool: peak_pool = maxi(peak_pool, p.pool[key].size())
			peak_particles = maxi(peak_particles, p.fx.parts.size())
		check(JSON.stringify(control) == JSON.stringify(scene.state), "road %d: presented state equals control after %d ticks" % [road, control.tick])
		check(C.valid(scene.state), "road %d: presented state valid" % road)
		check(peak_pool <= p.RESERVE and peak_particles <= 320, "road %d: pools bounded (%d reserve, %d particles)" % [road, peak_pool, peak_particles])
		var live := 0
		for i in scene.state.enemies.size():
			if scene.state.tick >= scene.state.definition.enemies[i].born and not scene.state.enemies[i].resolved: live += 1
		check(p.visuals.size() + p.far.size() == live, "road %d: one skinned visual or far crowd instance per live infected (%d)" % [road, live])
	# Pause freezes transient effects.
	var p2: RefCounted = scene.presentation
	p2.fx.burst(Vector3.ZERO, Color.WHITE, 10)
	var before: int = p2.fx.parts.size()
	var first: Vector3 = p2.fx.parts[0].p
	for i in 30: p2.frame(1.0 / 60.0, true)
	check(p2.fx.parts.size() == before and p2.fx.parts[0].p == first, "paused frames freeze particles")
	# Hydrating a mid-road state starts no effects and no deaths.
	var mid := C.fresh(10, "rivet")
	mid.phase = "playing"
	for t in 2500:
		steer_policy(mid)
		C.step(mid)
	scene.state = mid
	scene.ctx.campaign = mid
	scene.build_world()
	scene.refresh()
	var p3: RefCounted = scene.presentation
	check(p3.fx.parts.is_empty() and p3.dying.is_empty() and p3.fx.splat_list.is_empty(), "rebuild/hydrate starts with no transient effects")
	scene.refresh()
	scene.refresh()
	check(p3.fx.parts.is_empty(), "repeated refresh of one tick replays no effect")
	# Reduced effects: no particles, telegraph decals still drawn.
	scene.settings.reduced_effects = true
	var hz := C.fresh(17, "rivet")
	hz.phase = "playing"
	scene.state = hz
	scene.ctx.campaign = hz
	scene.build_world()
	scene.refresh()
	var p4: RefCounted = scene.presentation
	var saw_telegraph := false
	for t in 5200:
		steer_policy(hz)
		C.step(hz)
		scene.refresh()
		p4.frame(1.0 / 60.0, false)
		for node in p4.hazards: saw_telegraph = saw_telegraph or node.visible
		if hz.phase != "playing": break
	check(p4.fx.parts.is_empty() and p4.fx.splat_list.is_empty(), "reduced effects spawns no particles or splats")
	check(saw_telegraph, "reduced effects still draws essential telegraphs")
	check(scene.camera.h_offset == 0 and scene.camera.v_offset == 0, "reduced effects never shakes the camera")
	scene.settings.reduced_effects = false
	print("PRESENTATION ", checks, " failures=", failures)
	print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
