extends "res://tests/input_base.gd"
const Content = preload("res://scripts/content.gd")
var samples: Array = []

func _initialize() -> void:
    root.size = Vector2i(600, 1066)
    test_path = "user://tower-feedback-test.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="): folder = arg.trim_prefix("--capture-dir=")
    call_deferred("run")

func painted() -> Array:
    if game.view.has_method("popup_layout"):
        var result: Array = game.view.popup_layout()
        # Independently derive the paint bounds from the exact baseline and size
        # consumed by draw_string; a false placement rectangle cannot pass.
        for item in result:
            var font: Font = game.view.font
            var outline: int = item.outline
            item.bounds = Rect2(item.where - Vector2(outline, font.get_ascent(item.size) + outline), Vector2(font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, item.size).x + outline * 2, font.get_height(item.size) + outline * 2))
        return result
    var result: Array = []
    for pop in game.view.pops:
        var k: float = pop.t / pop.life
        var size := int(pop.size * (1.0 + (.5 * (1.0 - smoothstep(0.0, .18, k)) if pop.big else 0.0)))
        var rise := (60.0 if pop.big else 46.0) * (1.0 - pow(1.0 - minf(1.0, k * 1.6), 2.0))
        var width: float = game.view.font.get_string_size(pop.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
        var where: Vector2 = pop.at + Vector2(-width * .5, -rise)
        where.x = clampf(where.x, 8.0, 592.0 - width)
        var outline := maxi(6, size / 5)
        result.append({"text": pop.text, "bounds": Rect2(where - Vector2(outline, game.view.font.get_ascent(size) + outline), Vector2(width + outline * 2, game.view.font.get_height(size) + outline * 2))})
    return result

func observe_move(id: String, label: String, duration: int = 150, minimum: int = 2) -> void:
    var expected: Dictionary = Rules.step(game.level, game.state, id).state
    await choose(id)
    await action("enter")
    var overlaps := 0
    var clipped := 0
    var peak := 0
    var texts: Array = []
    for frame_index in duration:
        await process_frame
        var items := painted()
        peak = maxi(peak, items.size())
        for i in items.size():
            if not texts.has(items[i].text): texts.append(items[i].text)
            if not Rect2(0, 224, 600, 520).encloses(items[i].bounds): clipped += 1
            for j in range(i):
                if items[i].bounds.intersects(items[j].bounds): overlaps += 1
    samples.append({"label": label, "overlap_frames": overlaps, "clipped_frames": clipped, "peak": peak, "texts": texts})
    check(peak >= minimum, label + ": naturally concurrent feedback was exercised")
    check(overlaps == 0, label + ": painted text including outline never overlaps (%d intersections)" % overlaps)
    check(clipped == 0, label + ": feedback stays inside board feedback area")
    check(game.state == expected and game.pending.is_empty(), label + ": natural resolution equals authoritative rules")

func run() -> void:
    DirAccess.make_dir_recursive_absolute(folder)
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: DirAccess.remove_absolute(test_path + suffix)
    await create_game()
    for id in ["bell", "rope", "clock", "light"]: await enter(id)
    check(game.state.status == "won" and game.data.profile.has("watch_01"), "First tower earned by touch and natural engine updates")
    await wait_frames(120)
    await action("next")
    check(game.level.id == "watch_02", "Earned progression reaches ordered chimes")
    await observe_move("pair", "earned-twin-chimes")
    check(samples[-1].texts.has("+3") and samples[-1].texts.has("+7") and samples[-1].texts.has("+10"), "Both spirit values and room total remain visible")
    await action("retry")
    await observe_move("reverse", "natural-order-defeat")
    check(game.state.status == "lost", "Wrong ordered room naturally defeats courier")
    await action("undo")
    check(game.state == Rules.initial(game.level), "Undo preserves original complete initial state")
    # Earn every later authored tower. The solver is test input selection only;
    # it supplies no new guidance in the product. Enter again as soon as the
    # rule beat completes, retaining overlapping lifetimes across rooms.
    for index in range(1, Content.levels().size()):
        check(game.level.id == Content.levels()[index].id, "Earned tower " + game.level.id)
        for id in Rules.solve(game.level, game.state).route:
            await observe_move(id, game.level.id + "/" + id, 65)
        check(game.state.status == "won", "Natural route completes " + game.level.id)
        if index < Content.levels().size() - 1: await action("next")
    check(samples.any(func(s): return s.texts.has("SHIELD")), "Authored shield feedback exercised")
    check(samples.any(func(s): return s.texts.has("KEEPER RESCUED")), "Natural terminal celebration exercised")
    check(samples.any(func(s): return s.texts.has("+1000")), "Late large arithmetic exercised")
    await action("retry")
    game.data.settings.reduced_effects = true
    game.sync_view()
    for id in Rules.solve(game.level, game.state).route:
        await observe_move(id, "reduced/" + id, 65, 1)
    check(game.state.status == "won", "Reduced effects retain complete route arithmetic")
    var before: Dictionary = game.state.duplicate(true)
    var data_before: Dictionary = game.data.duplicate(true)
    for size in [Vector2i(1080, 2520), Vector2i(1968, 2184), Vector2i(1600, 900), Vector2i(600, 1066)]:
        root.size = size
        await wait_frames(1)
        var layout: Array = painted()
        for item in layout:
            var physical := Rect2(game.view.fx.to_global(item.bounds.position), item.bounds.size * game.view.fx.scale)
            check(Rect2(Vector2.ZERO, Vector2(size)).encloses(physical), "Feedback fits uniformly scaled viewport " + str(size))
    check(game.state == before and game.data == data_before, "Layout queries and resize never mutate rules or saves")
    var file := FileAccess.open(folder + "/feedback-result.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks": checks, "failures": failures, "touch_taps": taps, "samples": samples, "scope": "Headless engine input and actual font/outline geometry; no rendered or device claim"}, "\t"))
    file.close()
    print("TOWER FEEDBACK: %d checks; %d failures; %d taps" % [checks, failures.size(), taps])
    game.queue_free()
    await wait_frames(4)
    if failures.is_empty(): print("SUITE_COMPLETE: PASS")
    quit(0 if failures.is_empty() else 1)
