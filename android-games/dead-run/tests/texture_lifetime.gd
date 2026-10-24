extends "res://tests/terminal_design.gd"
## Discriminating runtime prefixes. No resource purge or expected-error filter.
## Rendering must be explicitly scheduled by the coordinator; CPU checks only
## prove inputs/teardown execute, never the absence of a GL shutdown leak.
var scenario := "campaign-start20"
var checkpoints: Array = []
var weak_fonts: Dictionary = {}
var root_host: Node

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
    check(scenario in ["campaign-start20", "campaign-start60", "campaign-defeat", "campaign-terminal", "campaign-retry20", "campaign-win", "campaign-win-reload", "campaign-reload20", "campaign-defeat-reload", "legacy-start20", "legacy-defeat", "legacy-retry-leave", "full-runtime-prefix", "geometry-before-warning", "geometry-only", "single49-before-warning", "single49-only", "geometry-no-pixel-before-warning"], "Known discriminating prefix")
    root.size = Vector2i(720, 1280)
    scene = load("res://campaign.tscn").instantiate()
    root.add_child(scene)
    root_host = scene
    await dwell(5)
    observe("ready")
    if scenario in ["geometry-before-warning", "geometry-only", "single49-before-warning", "single49-only", "geometry-no-pixel-before-warning"]:
        # Explicit synthetic fixture tail only: no claimed progress or save.
        # Keep the same local adapter lifetime as the full harness; p=null
        # has already failed its matched intervention and is not a fix.
        scene.set_physics_process(false)
        warning_checks()
        for count in ([49] if scenario.begins_with("single49") else [5, 25, 49]):
            scene.state = C.fresh(0, "rivet")
            scene.state.crew = count
            scene.state.phase = "defeat"
            scene.state.tick = scene.state.definition.boss.born
            scene.state.boss.z = 0.0
            scene.journey_visible = false
            scene.build_world()
            scene.refresh()
            var adapter: RefCounted = scene.presentation
            var barrier := Kit.bounds(adapter.boss_visual, scene.world)
            var front := INF
            for i in count:
                front = minf(front, Kit.bounds(adapter.crew[i].model, scene.world).position.z)
            check(barrier.end.z + .2 <= front, "Synthetic geometry clearance " + str(count))
            if count == 49 and scenario != "geometry-no-pixel-before-warning":
                scene.overlay.hide()
                scene.notice.text = "GEOMETRY FIXTURE - 49 crew / frozen blockade. Not earned progress."
                await pixel("fixture-prefix-49-crew")
                scene.refresh()
            scene.state.phase = "playing"
            scene.state.boss.z = 2.0
            scene.refresh()
            check(adapter.boss.position == Vector3(scene.state.boss.x, 0, -scene.state.boss.z), "Synthetic active target relation " + str(count))
            observe("synthetic-geometry-" + str(count))
        if not scenario.ends_with("-only"): await warning_pixels()
        observe("synthetic-tail-complete")
        call_deferred("complete_probe")
        return
    if scenario.begins_with("legacy-"):
        await click("LEGACY CANAL BRIDGE")
        scene = root_host.legacy_view
        await dwell(4)
        check(scene.state.phase == "ready", "Legacy prefix begins at real ready bridge")
    else:
        await click(scene.stage_buttons[0].text)
    await click("START RESCUE")
    var frames := 60 if scenario == "campaign-start60" else 20
    await dwell(frames)
    check(scene.state.phase == "playing" and scene.state.tick >= frames, "Actual Start naturally advances prefix")
    observe("started")
    if scenario in ["campaign-defeat", "campaign-terminal", "campaign-retry20", "campaign-win", "campaign-win-reload", "campaign-defeat-reload", "legacy-defeat", "legacy-retry-leave", "full-runtime-prefix"]:
        var limit := 0
        while scene.state.phase == "playing" and limit < 9000:
            await physics_frame
            limit += 1
        check(scene.state.phase == "defeat", "Unattended input prefix naturally reaches defeat")
        await dwell(3)
        observe("defeat")
    if scenario == "full-runtime-prefix": await terminal_checks("prefix natural defeat")
    if scenario == "campaign-terminal":
        scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
        await click("SAVE / TRANSFER")
        await click("CLOSE TRANSFER")
        await key(KEY_ESCAPE)
        observe("terminal-transfer-back")
    if scenario in ["campaign-retry20", "campaign-win", "campaign-win-reload", "legacy-retry-leave", "full-runtime-prefix"]:
        await click("RETRY BRIDGE" if scenario.begins_with("legacy-") else "RETRY ROAD")
        await dwell(20)
        check(scene.state.phase == "playing", "Actual Retry naturally restarts prefix")
        observe("retry")
    if scenario in ["campaign-win", "campaign-win-reload", "full-runtime-prefix"]:
        check(await play_road(), "Actual drag policy earns natural victory")
        await dwell(3)
        observe("victory")
    if scenario == "full-runtime-prefix": await terminal_checks("prefix natural victory")
    if scenario == "legacy-retry-leave":
        await click("II")
        await click("EVACUATION MAP")
        scene = root_host
        await dwell(4)
        check(scene.ctx.mode == "campaign", "Legacy returns through actual map input")
        observe("legacy-left")
    if scenario in ["campaign-reload20", "campaign-defeat-reload", "campaign-win-reload", "full-runtime-prefix"]:
        var before: Dictionary = scene.state.duplicate(true)
        scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
        scene.queue_free()
        scene = null
        root_host = null
        await dwell(4)
        observe("before-reload")
        scene = load("res://campaign.tscn").instantiate()
        root.add_child(scene)
        root_host = scene
        await dwell(5)
        check(Data.same(scene.state, before), "Real cold reload retains complete prefix state")
        observe("reloaded")
    if scenario == "full-runtime-prefix":
        await click("NEXT ROAD")
        await legacy_terminal_checks()
        observe("post-legacy-runtime-prefix")
    # Leave the scenario coroutine so all locals are released before teardown,
    # matching terminal_design's strict closure instead of changing ownership.
    call_deferred("complete_probe")

func observe(label: String) -> void:
    var labels: Array = []
    if is_instance_valid(root_host):
        for node in root_host.find_children("*", "Label3D", true, false):
            var font: Font = node.font
            var font_id := font.get_instance_id() if font != null else 0
            if font != null: weak_fonts[str(font_id)] = weakref(font)
            labels.append({"text": node.text, "font_id": font_id, "font_size": node.font_size, "visible": node.is_visible_in_tree()})
    var row := {"label": label, "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "labels3d": labels, "live_explicit_fonts": weak_fonts.keys().filter(func(id): return weak_fonts[id].get_ref() != null)}
    if is_instance_valid(scene): row["tick"] = scene.state.tick
    checkpoints.append(row)
    print("TEXTURE_PREFIX ", scenario, " ", label, " nodes=", row.nodes, " resources=", row.resources, " explicit_fonts=", row.live_explicit_fonts)

func complete_probe() -> void:
    if is_instance_valid(root_host): root_host.queue_free()
    scene = null
    root_host = null
    await process_frame
    if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
    await process_frame
    observe("freed-drained")
    var file := FileAccess.open(folder + "/texture-lifetime.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"scenario": scenario, "headless": DisplayServer.get_name() == "headless", "checks": checks, "failures": failures, "events": events, "checkpoints": checkpoints, "limits": "Weak explicit-font observations are ownership diagnostics, not proof about default font caches. Headless cannot reproduce GL texture lifetime; strict shutdown errors stay in raw log."}, "\t"))
    file.close()
    print("TEXTURE_LIFETIME ", scenario, " checks=", checks, " failures=", failures)
    print("SUITE_COMPLETE: ", "PASS" if failures == 0 else "FAIL")
    quit(0 if failures == 0 else 1)
