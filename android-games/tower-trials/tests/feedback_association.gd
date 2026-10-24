extends "res://tests/feedback_readability.gd"
var observed: Array = []
var associations: Array = []
var ambiguous_frames := 0
var unlinked_frames := 0
var bad_origins := 0
var link_text_intersections := 0
var link_clipped := 0
var first_ambiguities: Array = []
var last_level := ""
var exhaustive := false
var missing_leaders := 0
var hidden_markers := 0
var max_links := 0
var repeated_origin_seen := false
var above_origin_seen := false
var below_origin_seen := false
var first_missing: Dictionary = {}
var first_clip: Dictionary = {}

func _initialize() -> void:
    root.size = Vector2i(600, 1066)
    test_path = "user://tower-association-input.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="): folder = arg.trim_prefix("--capture-dir=")
        if arg.begins_with("--viewport="):
            var dimensions := arg.trim_prefix("--viewport=").split("x")
            root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
    call_deferred("run")

func measure_frame() -> void:
    super.measure_frame()
    if not is_instance_valid(game): return
    if game.level.id != last_level:
        last_level = game.level.id
        observed.clear()
    var items := painted()
    var links: Array = game.view.popup_links() if game.view.has_method("popup_links") else []
    max_links = maxi(max_links, links.size())
    for i in game.view.pops.size():
        var pop: Dictionary = game.view.pops[i]
        if pop.text == "KEEPER RESCUED": continue
        var found := -1
        for j in observed.size():
            if observed[j].pop == pop: found = j
        if found < 0:
            # Independent event-time room read, not inferred from paint placement.
            var id: String = game.view.encounter.get("room", game.pending_room)
            observed.append({"pop": pop, "room": id, "rect": game.room_rect(Rules.find_room(game.level, id))})
            found = observed.size() - 1
        var birth: Dictionary = observed[found]
        if pop.get("origin_room", "") != birth.room or pop.get("origin_rect", Rect2()) != birth.rect:
            bad_origins += 1
        for room in game.level.rooms:
            if room.id == birth.room or room.id in game.state.claimed: continue
            var rect: Rect2 = game.room_rect(room)
            if not rect.has_point(items[i].bounds.get_center()): continue
            ambiguous_frames += 1
            var linked: bool = pop.get("origin_room", "") == birth.room and links.any(func(link): return link.room == birth.room and link.origin_rect == birth.rect and not link.segments.is_empty())
            if not linked:
                missing_leaders += 1
                if first_missing.is_empty(): first_missing = {"text": pop.text, "source": birth.room, "source_rect": str(birth.rect), "links": str(links), "layout": str(items)}
            if not linked: unlinked_frames += 1
            if first_ambiguities.size() < 24 and not first_ambiguities.any(func(row): return row.text == pop.text and row.source_room == birth.room and row.painted_over_unclaimed == room.id and row.get("move", "") == measuring.get("label", "")):
                first_ambiguities.append({"frame": measured_frames, "move": measuring.get("label", ""), "text": pop.text, "source_room": birth.room, "painted_over_unclaimed": room.id, "bounds": str(items[i].bounds), "source_rect": str(birth.rect), "linked": linked})
    for link in links:
            repeated_origin_seen = repeated_origin_seen or links.filter(func(other): return other.room == link.room).size() > 1
            hidden_markers += int(not link.marker_visible)
            var on_edge: bool = is_equal_approx(link.origin.x, link.origin_rect.position.x) or is_equal_approx(link.origin.x, link.origin_rect.end.x)
            if not on_edge or link.origin.y < link.origin_rect.position.y or link.origin.y > link.origin_rect.end.y: bad_origins += 1
            var source_room: Dictionary = Rules.find_room(game.level, link.room)
            if source_room.is_empty() or game.room_rect(source_room) != link.origin_rect: bad_origins += 1
            if link.marker_visible:
                for item in items:
                    if item.bounds.grow(5).has_point(link.origin): link_text_intersections += 1
            var before_query: Dictionary = game.state.duplicate(true)
            var data_before: Dictionary = game.data.duplicate(true)
            var again: Array = game.view.popup_links()
            if game.state != before_query or game.data != data_before or again != links: bad_origins += 1
            for segment in link.segments:
                for point in segment:
                    above_origin_seen = above_origin_seen or point.y < link.origin.y - 20
                    below_origin_seen = below_origin_seen or point.y > link.origin.y + 20
                    var physical: Vector2 = game.view.fx.to_global(point)
                    if not root.get_visible_rect().has_point(physical):
                        link_clipped += 1
                        if first_clip.is_empty(): first_clip = {"physical": str(physical), "root_size": str(root.size), "visible_rect": str(root.get_visible_rect()), "logical": str(point), "fx_scale": str(game.view.fx.scale)}
                for item in items:
                    if segment_hits_rect(segment[0], segment[1], item.bounds.grow(2.0)):
                        link_text_intersections += 1
                var stroke := Rect2(segment[0], Vector2.ZERO).expand(segment[1]).grow(2.75)
                if not Rect2(0, 224, 600, 520).encloses(stroke): link_clipped += 1

func segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
    if rect.has_point(a) or rect.has_point(b): return true
    var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
    for i in 4:
        if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null: return true
    return false

func run() -> void:
    DirAccess.make_dir_recursive_absolute(folder)
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: DirAccess.remove_absolute(test_path + suffix)
    await create_game()
    process_frame.connect(measure_frame)
    for id in ["bell", "rope", "clock", "light"]: await enter(id)
    check(game.state.status == "won" and game.data.profile.has("watch_01"), "Actual input earns first tower")
    await wait_frames(30)
    await action("next")
    await observe_move("pair", "earned-twin-chimes")
    check(samples[-1].texts.has("+3") and samples[-1].texts.has("+7") and samples[-1].texts.has("+10"), "Both spirit and total arithmetic remain visible")
    await action("retry")
    await observe_move("reverse", "natural-order-defeat")
    check(game.state.status == "lost", "Wrong ordering naturally loses")
    await action("undo")
    check(game.state == Rules.initial(game.level), "Undo restores complete original state")
    for id in Rules.solve(game.level, game.state).route:
        await observe_move(id, "earliest-" + id, false)
    check(game.state.status == "won", "Earliest legal inputs naturally complete second tower")
    if exhaustive:
        for index in range(2, Content.levels().size()):
            await action("next")
            for id in Rules.solve(game.level, game.state).route:
                await observe_move(id, game.level.id + "/" + id, false)
            check(game.state.status == "won", "Natural association route earns " + game.level.id)
        await action("retry")
        game.data.settings.reduced_effects = true
        game.sync_view()
        for id in Rules.solve(game.level, game.state).route:
            await observe_move(id, "reduced/" + id, false, 1)
        check(game.state.status == "won", "Reduced effects preserve route and source association")
    check(repeated_origin_seen, "Ordered components and total retain a shared event source")
    check(above_origin_seen and below_origin_seen, "Leaders exercise both upward and downward displacement")
    check(missing_leaders == 0, "Ambiguous numbers have actual nonempty leader paint, not only metadata")
    check(ambiguous_frames > 0, "Reproduction exercises feedback over another untouched room")
    check(unlinked_frames == 0, "Displaced feedback retains visible association with its actual source floor")
    check(bad_origins == 0, "Every room feedback event retains exact room identity and bounds at birth")
    check(link_text_intersections == 0 and link_clipped == 0, "Connector paint avoids popup text and stays inside board")
    check(all_overlaps == 0 and all_clipped == 0, "All popup paint remains separate and in bounds")
    process_frame.disconnect(measure_frame)
    write_result()
    game.queue_free()
    game = null
    await wait_frames(4)
    print("TOWER ASSOCIATION ", checks, " failures=", failures.size())
    print("SUITE_COMPLETE: ", "PASS" if failures.is_empty() else "FAIL")
    quit(0 if failures.is_empty() else 1)

func write_result() -> void:
    FileAccess.open(folder.path_join("association-full-result.json" if exhaustive else "association-result.json"), FileAccess.WRITE).store_string(JSON.stringify({"viewport": str(root.size), "visible_rect": str(root.get_visible_rect()), "checks": checks, "failures": failures, "taps": taps, "frames": measured_frames, "ambiguous_frames": ambiguous_frames, "unlinked_frames": unlinked_frames, "bad_origins": bad_origins, "link_text_intersections": link_text_intersections, "link_clipped": link_clipped, "missing_leaders": missing_leaders, "hidden_markers": hidden_markers, "max_links": max_links, "first_missing": first_missing, "first_clip": first_clip, "repeated_origin_seen": repeated_origin_seen, "above_origin_seen": above_origin_seen, "below_origin_seen": below_origin_seen, "first_ambiguities": first_ambiguities, "samples": samples, "scope": "Fresh actual input earns first tower, ordered components/total, natural defeat, Undo, earliest legal chaining. CPU font/outline association geometry; no rendered/native claim."}, "  "))
