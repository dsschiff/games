extends "res://tests/charge_play.gd"
## Authentic earned continuation and input policy are inherited unchanged.
var windows_style := {}
var style_frames := 0
var simultaneous_winds := 0
var maximum_charge_alpha := 0.0
var deadline_pairs: Array = []
var missing_boundaries := 0
var boundary_outside := 0
var warning_geometry: Array = []
var wide_boundaries := 0
var dim_early := 0
var fading_deadlines := 0

func run() -> void:
    var fresh := C.fresh(0, 0, 0)
    var initial_view := Adapter.new()
    root.add_child(initial_view)
    initial_view.build(fresh)
    check(initial_view.actors.values().all(func(actor): return not actor.warning.visible), "Unstarted attack state has no fabricated ground warning")
    initial_view.free()
    await process_frame
    await style_fixtures()
    physics_frame.connect(observe_style)
    await super.run()

func observe_style() -> void:
    if not is_instance_valid(scene) or scene.paused or scene.presentation.snapshot.is_empty(): return
    style_frames += 1
    var winds: Array = []
    var charges: Array = []
    for enemy in C.active(scene.state):
        if enemy.mode != "wind": continue
        winds.append(enemy)
        if enemy.attack == "charge": charges.append(enemy)
        if not scene.presentation.actors.has(int(enemy.id)): continue
        var actor: Node3D = scene.presentation.actors[int(enemy.id)]
        var node: MeshInstance3D = actor.warning.get_node("Outer" if enemy.attack == "ring" else "Line") if enemy.attack != "slam" else actor.warning.get_node("Solid").get_child(0)
        if not node.visible: continue
        var color: Color = node.material_override.albedo_color
        var key := "%d:%d" % [enemy.id, enemy.cycles]
        if not windows_style.has(key): windows_style[key] = {"id": enemy.id, "attack": enemy.attack, "samples": []}
        if not windows_style[key].samples.is_empty():
            var previous: Dictionary = windows_style[key].samples[-1]
            if enemy.clock < previous.clock and (color.v + .00001 < previous.value or color.a + .00001 < previous.alpha): fading_deadlines += 1
        if color.a < (.10 if enemy.attack not in ["ring", "slam"] else .70): dim_early += 1
        windows_style[key].samples.append({"clock": enemy.clock, "color": [color.r, color.g, color.b, color.a], "value": color.v, "alpha": color.a})
        if enemy.attack == "charge":
            if not node.has_node("Boundary"):
                missing_boundaries += 1
            else:
                var half: Vector3 = node.mesh.size / 2
                for edge in node.get_node("Boundary").get_children():
                    var size: Vector3 = edge.mesh.size * edge.scale
                    var world: Vector3 = size * node.scale.abs()
                    if minf(world.x, world.z) > .10: wide_boundaries += 1
                    if absf(edge.position.x) + size.x / 2 > half.x + .00001 or absf(edge.position.z) + size.z / 2 > half.z + .00001: boundary_outside += 1
    simultaneous_winds = maxi(simultaneous_winds, winds.size())
    if charges.size() >= 2:
        var min_x := -6.0
        for x in 25:
            for z in 33:
                var point := Vector2(min_x + x * .5, -12 + z * .5)
                var combined := 0.0
                var count := 0
                for enemy in charges:
                    if not scene.presentation.actors.has(int(enemy.id)): continue
                    var strip: MeshInstance3D = scene.presentation.actors[int(enemy.id)].warning.get_node("Line")
                    if inside(strip, point):
                        count += 1
                        combined = 1.0 - (1.0 - combined) * (1.0 - strip.material_override.albedo_color.a)
                if count >= 2: maximum_charge_alpha = maxf(maximum_charge_alpha, combined)
    if style_frames <= 60:
        warning_geometry.append({"frame": style_frames, "time": scene.state.time, "winds": winds.map(func(enemy): return {"id": enemy.id, "attack": enemy.attack, "clock": enemy.clock})})

func release() -> void:
    await super.release()
    physics_frame.disconnect(observe_style)
    for key in windows_style:
        var samples: Array = windows_style[key].samples
        var far: Dictionary = {}
        var near: Dictionary = {}
        for sample in samples:
            if sample.clock >= .6: far = sample
            if sample.clock <= .18 and near.is_empty(): near = sample
        if not far.is_empty() and not near.is_empty():
            deadline_pairs.append({"id": windows_style[key].id, "attack": windows_style[key].attack, "far": far, "near": near})
    check(simultaneous_winds >= 4, "Earned finale exercises concurrent radial, charge and other windups")
    check(maximum_charge_alpha > 0, "Actual finale exercises overlapping charge interiors")
    check(maximum_charge_alpha <= .45, "Overlapping fill leaves more floor visible than the original dense wash")
    check(deadline_pairs.size() >= 3, "Actual continuation exercises long-to-imminent deadlines")
    check(deadline_pairs.all(func(pair): return pair.near.value > pair.far.value + .03 and pair.near.alpha > pair.far.alpha + .02), "Same windup gains visible contrast as actual release approaches")
    check(dim_early == 0 and fading_deadlines == 0, "All early warnings stay nonzero and the same deadline never fades backward")
    check(wide_boundaries == 0, "Conservative broad charge boxes keep thin world-space edges")
    check(missing_boundaries == 0 and boundary_outside == 0, "Every charge retains continuous inset edges within exact existing footprint")
    FileAccess.open(capture_dir.path_join("finale-readability-report.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "details": report, "observed_frames": style_frames, "simultaneous_winds": simultaneous_winds, "maximum_overlapping_charge_fill_alpha": maximum_charge_alpha, "missing_boundary_observations": missing_boundaries, "boundary_outside": boundary_outside, "wide_boundary_observations": wide_boundaries, "dim_early": dim_early, "fading_deadlines": fading_deadlines, "deadline_pairs": deadline_pairs, "first_windups": warning_geometry, "synthetic_style_observations": observations, "scope": "Whole hash-authenticated earned checkpoint loaded normally and inherited actual touch continuation. CPU material/geometry hierarchy contract, not perceived visual clarity or phone/FPS/fun. Original attack/collision/charge rules remain authoritative."}, "  "))


func style_fixtures() -> void:
    # Explicit presentation fixtures only: never installed in the earned save.
    var fixture := C.fresh(9, 3, 0, 5)
    var view := Adapter.new()
    root.add_child(view)
    view.build(fixture)
    var enemy: Dictionary = C.active(fixture)[0]
    var definition: Dictionary = fixture.definition.roster[int(enemy.id)].duplicate(true)
    definition.boss = true
    var actor: Node3D = view.actors[int(enemy.id)]
    for reduced in [false, true]:
        view.reduced = reduced
        for attack in ["slam", "ring", "line", "charge", "shot", "burst"]:
            enemy.mode = "wind"
            enemy.attack = attack
            enemy.clock = 1.0
            var before := fixture.duplicate(true)
            view._telegraph(actor, enemy, definition, false)
            var node: MeshInstance3D = actor.warning.get_node("Outer" if attack == "ring" else "Line") if attack != "slam" else actor.warning.get_node("Solid").get_child(0)
            var early: Color = node.material_override.albedo_color
            enemy.clock = .01
            view._telegraph(actor, enemy, definition, false)
            var imminent: Color = node.material_override.albedo_color
            enemy.clock = 1.0
            view._telegraph(actor, enemy, definition, false)
            check(node.material_override.albedo_color == early and imminent.v > early.v, "Absolute material reset on next " + attack + " instance / reduced=" + str(reduced))
            check(fixture == before, "Warning styling never writes whole authoritative fixture / " + attack)
            if attack == "ring":
                var inner: float = actor.warning.get_node("Inner").mesh.inner_radius
                var outer: float = actor.warning.get_node("Outer").mesh.outer_radius
                observations.append({"case": "ring_radii", "inner_mesh": inner, "outer_mesh": outer, "source_radii": [2.0, 6.35], "rim_half_width": .045})
                check(absf(inner - 1.955) < .000001 and absf(outer - 6.395) < .000001, "Ring safe hole and outer damage boundary remain original within float mesh storage")
            for mode in ["idle", "recover", "charge"]:
                enemy.mode = mode
                view._telegraph(actor, enemy, definition, false)
                check(not actor.warning.visible, "No false windup in " + mode + " / " + attack)
            actor.reset_for_reuse()
            check(not actor.warning.visible, "Pooled actor has no stale warning before hydration")
    view.free()
    await process_frame
