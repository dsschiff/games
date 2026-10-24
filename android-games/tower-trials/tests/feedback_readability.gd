extends "res://tests/input_base.gd"
const Content = preload("res://scripts/content.gd")
var samples: Array = []
var measuring: Dictionary = {}
var measured_frames := 0
var max_stack_height := 0.0
var max_pop_count := 0
var all_clipped := 0
var all_overlaps := 0

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

# Measure every engine frame, including room selection/entry input frames.
func measure_frame() -> void:
    if not is_instance_valid(game): return
    measured_frames += 1
    var items := painted()
    var height := maxf(0.0, (items.size() - 1) * 8.0)
    for item in items: height += item.bounds.size.y
    max_stack_height = maxf(max_stack_height, height)
    max_pop_count = maxi(max_pop_count, items.size())
    for i in items.size():
        if not Rect2(0, 224, 600, 520).encloses(items[i].bounds): all_clipped += 1
        for j in range(i):
            if items[i].bounds.intersects(items[j].bounds): all_overlaps += 1
    if measuring.is_empty(): return
    measuring.frames += 1
    measuring.peak = maxi(measuring.peak, items.size())
    measuring.stack_height = maxf(measuring.stack_height, height)
    for i in items.size():
        if not measuring.texts.has(items[i].text): measuring.texts.append(items[i].text)
        if not Rect2(0, 224, 600, 520).encloses(items[i].bounds):
            measuring.clipped_frames += 1
            if measuring.first_clipped.is_empty():
                measuring.first_clipped = {"text": items[i].text, "bounds": str(items[i].bounds), "pop_count": items.size(), "stack_height": height}
        for j in range(i):
            if items[i].bounds.intersects(items[j].bounds): measuring.overlap_frames += 1

# A press/release is dispatched through the engine's real input path. Sending
# selection and Enter in one frame avoids the helper's extra wait frames.
func tap_now(point: Vector2) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = root.get_final_transform() * game.to_global(point)
    event.pressed = true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    event = event.duplicate()
    event.pressed = false
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    taps += 1

func observe_move(id: String, label: String, drain: bool = true, minimum: int = 2) -> void:
    var expected: Dictionary = Rules.step(game.level, game.state, id).state
    measuring = {"label": label, "overlap_frames": 0, "clipped_frames": 0, "peak": 0, "texts": [], "frames": 0, "stack_height": 0.0, "first_clipped": {}}
    check(game.pending.is_empty(), label + ": dispatch begins at legal unlocked state")
    tap_now(game.room_rect(Rules.find_room(game.level, id)).get_center())
    check(game.selected == id and game.buttons().has("enter"), label + ": earliest selection exposes Enter")
    tap_now(game.buttons()["enter"].get_center())
    check(not game.pending.is_empty(), label + ": same-frame actual input starts encounter")
    var frames := 0
    while not game.pending.is_empty() and frames < 70:
        await process_frame
        frames += 1
    # Normal route chaining returns at the very first pending-empty frame.
    # The two introductory captures also drain all effects for full lifetimes.
    if drain:
        await wait_frames(150 - frames)
    samples.append(measuring.duplicate(true))
    check(measuring.peak >= minimum, label + ": naturally concurrent feedback was exercised")
    check(measuring.overlap_frames == 0, label + ": painted text including outline never overlaps (%d intersections)" % measuring.overlap_frames)
    check(measuring.clipped_frames == 0, label + ": feedback stays inside board feedback area")
    check(game.state == expected and game.pending.is_empty(), label + ": natural resolution equals authoritative rules")
    if not drain:
        check(frames <= 56, label + ": input does not wait for visual effects after 0.9 second rule unlock (%d frames)" % frames)
    measuring = {}

func run() -> void:
    DirAccess.make_dir_recursive_absolute(folder)
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: DirAccess.remove_absolute(test_path + suffix)
    await create_game()
    process_frame.connect(measure_frame)
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
            await observe_move(id, game.level.id + "/" + id, false)
        check(game.state.status == "won", "Natural route completes " + game.level.id)
        if index < Content.levels().size() - 1: await action("next")
    check(samples.any(func(s): return s.texts.has("SHIELD")), "Authored shield feedback exercised")
    check(samples.any(func(s): return s.texts.has("KEEPER RESCUED")), "Natural terminal celebration exercised")
    check(samples.any(func(s): return s.texts.has("+1000")), "Late large arithmetic exercised")
    await action("retry")
    game.data.settings.reduced_effects = true
    game.sync_view()
    for id in Rules.solve(game.level, game.state).route:
        await observe_move(id, "reduced/" + id, false, 1)
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
    check(all_overlaps == 0, "Every sampled frame, including input and transition frames, remains separated")
    check(all_clipped == 0, "Every sampled frame, including input and transition frames, stays in bounds")
    check(max_stack_height <= 520.0, "Authored earliest-input peak stack fits fallback area (%0.1f/520 px)" % max_stack_height)
    var file := FileAccess.open(folder + "/feedback-result.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks": checks, "failures": failures, "touch_taps": taps, "samples": samples, "measured_frames": measured_frames, "max_pop_count": max_pop_count, "max_stack_height": max_stack_height, "all_clipped": all_clipped, "all_overlaps": all_overlaps, "timing": "Actual selection and Enter press/releases in the first pending-empty frame; next input waits for no presentation settle delay", "scope": "Headless engine input and actual font/outline geometry; no rendered or device claim"}, "\t"))
    file.close()
    print("TOWER FEEDBACK: %d checks; %d failures; %d taps" % [checks, failures.size(), taps])
    process_frame.disconnect(measure_frame)
    game.queue_free()
    await wait_frames(4)
    if failures.is_empty(): print("SUITE_COMPLETE: PASS")
    quit(0 if failures.is_empty() else 1)
