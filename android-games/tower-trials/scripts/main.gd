extends Node2D

const Content = preload("res://scripts/content.gd")
const Rules = preload("res://scripts/rules.gd")
const Saves = preload("res://scripts/save_store.gd")
const Challenge = preload("res://scripts/challenge_v1.gd")
const CopyConfirm = preload("res://scripts/copy_confirm.gd")
const ClipboardBackend = preload("res://scripts/clipboard_backend.gd")
const Audio = preload("res://scripts/local_audio.gd")
const Recovery = preload("res://scripts/import_recovery.gd")
const TowerView = preload("res://scripts/presentation/tower_view.gd")
const INK := Color("102c42")
const SAND := Color("edddbc")
const TEAL := Color("63e0bf")
const GOLD := Color("ffd17d")
const RED := Color("fa8b7c")
const WHITE := Color("f4eee3")
const MUTED := Color("a5bcc9")
## Chapter names as shown on the Journey tabs; challenge families as on the select screen.
const CHAPTER_NAMES := ["Lantern Coast", "Salt Archives", "Glass March", "Last Meridian"]
const FAMILY_NAMES := {"key": "Keys", "shell": "Shell / sun", "rescue": "Rescue fork", "finale": "Woven finale"}

var save_path := Saves.PATH
var save_io: Variant = null
var import_pending := false
var import_recovery: Recovery
var recovery_status := {}
var recovery_root: Control
var recovery_panel: PanelContainer
var recovery_summary: Label
var recovery_message: Label
var recovery_copy_feedback: Label
var recovery_code: TextEdit
var recovery_scroll: ScrollContainer
var recovery_buttons := {}
var recovery_copy_backend: Variant = null
var clipboard_backend: RefCounted = ClipboardBackend.new()
var normal_copy := CopyConfirm.new(clipboard_backend)
var normal_copy_ticket := -1
var data := Saves.fresh()
var level: Dictionary
var state: Dictionary
var selected := ""
var screen := "game"
var menu := false
var transfer := false
var guide := false
var details := false
var chapter := 0
var map_scroll := 0.0
var map_press := Vector2.ZERO
var map_touch_pending := false
var map_dragged := false
var save_error := ""
var note := ""
var pending: Dictionary = {}
var pending_room := ""
var beat := 0.0
var phase := 0.0
var paused := false
var font: Font = ThemeDB.fallback_font
var sound := Audio.new()
var player := AudioStreamPlayer.new()
var editor := TextEdit.new()
var input_count := 0
var seed_edit := LineEdit.new()
var challenge_family := "key"
var challenge_weave := 0
var challenge_treasure := true
var show_hint := false
var record_page := 0
var claimed_gain := -1
var view: Node3D = TowerView.new()

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	import_recovery=Recovery.new(save_io,Recovery.path_for(save_path),save_path)
	recovery_status=import_recovery.read(); import_pending=recovery_status.pending
	var restored: Dictionary=recovery_status.original if recovery_status.ok else ({"ok":false} if import_pending else Saves.read(save_path,save_io))
	if restored.ok: data=restored.data
	elif not import_pending and (FileAccess.file_exists(save_path) if save_io==null else save_io.exists(save_path)):
		save_error="Save damaged; no valid recovery. Import a saved route."
	if not import_pending or recovery_status.ok: load_run()
	if import_pending: paused=true
	add_child(view)
	add_child(player)
	add_child(editor)
	add_child(seed_edit)
	seed_edit.position = Vector2(42, 434)
	seed_edit.size = Vector2(358, 80)
	seed_edit.max_length = 10
	seed_edit.add_theme_font_size_override("font_size", 28)
	hide_seed()
	editor.position = Vector2(42, 310)
	editor.size = Vector2(516, 380)
	editor.add_theme_font_size_override("font_size", 20)
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.visible = false
	editor.text_changed.connect(cancel_normal_copy)
	build_recovery_ui()
	get_viewport().size_changed.connect(layout)
	layout()
	if import_pending: show_recovery()
	queue_redraw()

func _exit_tree() -> void:
	cancel_normal_copy()
	player.stop()
	player.stream = null
	sound.cache.clear()

func load_run() -> void:
	level = data.challenge_run.bundle.snapshot if data.kind == "challenge" else Content.by_id(data.level_id, int(data.catalog))
	state = Saves.replay(data)
	note = ""
	show_hint = false
	if state.status == "lost" and not current_run().actions.is_empty():
		var prefix: Array = current_run().actions.duplicate()
		var last: String = prefix.pop_back()
		var reason := Rules.step(level, Saves.replay_route(level, prefix), last)
		note = " / ".join(reason.events) + " " + reason.message
	selected = ""
	claimed_gain = -1
	pending = {}
	beat = 0
	chapter = maxi(0, Content.index_of(data.level_id)) / 9

func layout() -> void:
	var area := get_viewport_rect().size
	var factor := minf(area.x / 600.0, area.y / 1066.0)
	scale = Vector2.ONE * factor
	position = (area - Vector2(600, 1066) * factor) * 0.5
	view.frame(area)
	if is_instance_valid(recovery_root):
		recovery_root.size=area
		var width:=minf(640,area.x-24)
		recovery_panel.position=Vector2((area.x-width)*.5,12)
		recovery_panel.size=Vector2(width,area.y-24)
	queue_redraw()

## Read-only snapshot for the 3D presentation; rules and saves are untouched.
func sync_view() -> void:
	if import_pending: return
	var rects := {}
	var blocked := {}
	for room in level.rooms:
		rects[room.id] = room_rect(room)
		blocked[room.id] = Rules.blocked(state, room)
	view.sync({"screen": screen, "level": level, "state": state, "selected": selected, "rects": rects, "blocked": blocked, "home_stride": home_stride(), "courier": courier_point(), "flight": clampf(beat / 0.9, 0, 1) if not pending.is_empty() else 0.0, "pending_room": pending_room if not pending.is_empty() else "", "pending_win": bool(pending.get("win", false)), "chapter": Challenge.FAMILIES.find(data.challenge_run.bundle.family) if data.kind == "challenge" else int(level.get("chapter", 0)), "reduced": bool(data.settings.reduced_effects), "frozen": paused or menu or transfer or guide or details})

## The courier's resting anchor on the watch roof. The 3D view animates the
## encounter itself from main's rule-timed beat (see tower_view.gd).
func courier_point() -> Vector2:
	return home_point()

## Draws a connector between two room centres only outside both room fronts,
## so it never paints over the 3D blocks.
func connector(a: Rect2, b: Rect2, color: Color, dashed: bool) -> void:
	var from := a.get_center()
	var to := b.get_center()
	var span := to - from
	if span.length() < 1.0:
		return
	var exit_a := _exit(a, span)
	var exit_b := 1.0 - _exit(b, -span)
	if exit_b <= exit_a:
		return
	if dashed:
		draw_dashed_line(from + span * exit_a, from + span * exit_b, color, 2, 8)
	else:
		draw_line(from + span * exit_a, from + span * exit_b, color, 3)

func _exit(rect: Rect2, span: Vector2) -> float:
	var half := rect.size * 0.5
	var tx := INF if is_zero_approx(span.x) else half.x / absf(span.x)
	var ty := INF if is_zero_approx(span.y) else half.y / absf(span.y)
	return minf(tx, ty)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_WM_CLOSE_REQUEST]: cancel_normal_copy()
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		paused = true
		if is_node_ready():
			persist()
			queue_redraw()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		back()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		persist()
		get_tree().quit()

func persist(recoverable: bool = true) -> bool:
	if import_pending: return false
	var ok := Saves.write(data, save_path, save_io, recoverable)
	save_error = "" if ok else "SAVE FAILED — keep this app open; export your route."
	queue_redraw()
	return ok

func tone(hz: float) -> void:
	if data.settings.sound and DisplayServer.get_name() != "headless":
		player.stream = sound.tone(hz)
		player.play()

func _process(delta: float) -> void:
	poll_normal_copy(delta)
	if import_pending: return
	if paused or menu or transfer or guide or details or screen != "game":
		return
	if not pending.is_empty():
		beat += delta
		if beat >= 0.9:
			claimed_gain = int(pending.state.power) - int(state.power) if pending_room in pending.state.claimed else -1
			state = pending.state
			# The claimed room cannot be entered again; return to a neutral read.
			if pending_room in state.claimed:
				selected = ""
			current_run().actions.append(pending_room)
			note = "  /  ".join(pending.events)
			pending = {}
			if state.status == "won":
				award()
			tone(740 if state.status != "lost" else 160)
			persist()
		queue_redraw()
	phase += delta

func award() -> void:
	if import_pending: return
	var medals := 1
	if int(state.moves) <= int(level.par):
		medals |= 2
	if state.treasure > 0:
		medals |= 4
	if not current_run().used_undo:
		medals |= 8
	if data.kind == "challenge":
		var bundle: Dictionary = data.challenge_run.bundle
		var key: String = Challenge.validate(bundle).key
		for record in data.challenge_records:
			if record.key == key:
				record.best = mini(int(record.best), int(state.moves))
				record.medals = int(record.medals) | medals
				data.challenge_records.erase(record)
				data.challenge_records.append(record)
				return
		data.challenge_records.append({"key": key, "version": bundle.version, "family": bundle.family, "seed": bundle.seed, "options": bundle.options.duplicate(true), "best": int(state.moves), "medals": medals, "fallback": bundle.fallback})
		if data.challenge_records.size() > Challenge.MAX_RECORDS: data.challenge_records.pop_front()
		return
	var prior: Dictionary = data.profile.get(level.id, {"best": 99, "medals": 0})
	data.profile[level.id] = {"best": mini(int(prior.best), int(state.moves)), "medals": int(prior.medals) | medals}

func buttons() -> Dictionary:
	if import_pending: return {}
	if details:
		return {"close_details": Rect2(42, 910, 516, 80)}
	if guide:
		return {"close_guide": Rect2(42, 876, 516, 80)}
	if transfer:
		return {"copy": Rect2(42, 710, 160, 80), "paste": Rect2(220, 710, 160, 80), "import": Rect2(398, 710, 160, 80), "close_transfer": Rect2(42, 804, 516, 80)}
	if menu:
		return {"sound": Rect2(58, 282, 484, 80), "effects": Rect2(58, 370, 484, 80), "transfer": Rect2(58, 458, 484, 80), "guide": Rect2(58, 546, 484, 80), "challenge_select": Rect2(58, 634, 484, 80), "close_menu": Rect2(58, 738, 484, 80)}
	if screen == "challenge_records":
		var records := {"record_prev": Rect2(42, 830, 248, 80), "record_next": Rect2(310, 830, 248, 80), "records_back": Rect2(42, 936, 516, 80)}
		for slot in 5:
			var index: int = data.challenge_records.size() - 1 - record_page * 5 - slot
			if index >= 0: records["record_%d" % index] = Rect2(42, 240 + slot * 112, 516, 100)
		return records
	if screen == "challenge_select":
		var choices := {"seed_next": Rect2(414, 434, 144, 80), "weave": Rect2(42, 548, 248, 80), "treasure_option": Rect2(310, 548, 248, 80), "generate": Rect2(42, 654, 516, 80), "back_challenge": Rect2(42, 850, 516, 80)}
		for i in 4: choices["family_" + Challenge.FAMILIES[i]] = Rect2(42 + (i % 2) * 268, 222 + (i / 2) * 100, 248, 80)
		if not data.challenge_run.is_empty(): choices["resume_challenge"] = Rect2(42, 752, 248, 80)
		if not data.challenge_records.is_empty(): choices["records"] = Rect2(310, 752, 248, 80)
		return choices
	if screen == "ending":
		return {"map": Rect2(26, 930, 548, 80), "settings": Rect2(496, 18, 80, 80)}
	if screen == "map":
		var result := {"settings": Rect2(496, 18, 80, 80), "resume": Rect2(26, 966, 548, 80)}
		for i in 4:
			result["chapter%d" % i] = Rect2(26 + i * 140, 154, 128, 80)
		for i in 9:
			var rect := Rect2(26, 240 + i * 84 - map_scroll, 548, 80)
			if rect.position.y >= 240 and rect.end.y <= 922:
				result["level%d" % (chapter * 9 + i)] = rect
		return result
	var result := {"settings": Rect2(496, 18, 80, 80), "undo": Rect2(24, 966, 174, 80), "retry": Rect2(213, 966, 174, 80), "map": Rect2(402, 966, 174, 80)}
	if data.kind == "challenge":
		result = {"settings": Rect2(496, 18, 80, 80), "undo": Rect2(24, 966, 126, 80), "retry": Rect2(162, 966, 126, 80), "challenge_new": Rect2(300, 966, 126, 80), "map": Rect2(438, 966, 138, 80)}
	if state.status == "won":
		result["next"] = Rect2(38, 862, 524, 80)
	elif paused:
		result["resume"] = Rect2(38, 862, 524, 80)
	elif selected != "" and pending.is_empty() and Rules.blocked(state, Rules.find_room(level, selected)) == "":
		result["enter"] = Rect2(38, 866, 524, 80)
		result["details"] = Rect2(38, 786, 524, 80)
	if data.kind == "campaign" and state.status == "active" and not paused and selected == "" and pending.is_empty() and Content.index_of(data.level_id) >= 6:
		result["hint"] = Rect2(38, 794, 524, 140)
	return result

func room_rect(room: Dictionary) -> Rect2:
	var rows := 1
	for item in level.rooms:
		rows = maxi(rows, int(item.floor) + 1)
	var stride := 115 if rows >= 4 else 140
	return Rect2(182 + (int(room.column) - 1) * 200, 620 - int(room.floor) * stride, 180, 104 if rows >= 4 else 122)

func home_stride() -> float:
	return minf(64, 384.0 / maxi(1, state.claimed.size()))

func home_point() -> Vector2:
	return Vector2(89, 637 - state.claimed.size() * home_stride())

func _unhandled_input(event: InputEvent) -> void:
	if import_pending: return
	# Native text editing needs touch-to-mouse emulation; avoid handling it twice.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if screen == "map" and not menu and not transfer and not guide:
		if event is InputEventScreenDrag and map_touch_pending:
			map_dragged = true
			map_scroll = clampf(map_scroll - event.relative.y / scale.y, 0, 76)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch:
			var local := to_local(event.position)
			if event.pressed and Rect2(26, 240, 548, 682).has_point(local):
				map_touch_pending = true
				map_press = local
				map_dragged = false
				get_viewport().set_input_as_handled()
				return
			if not event.pressed and map_touch_pending:
				map_touch_pending = false
				if not map_dragged and local.distance_to(map_press) < 20:
					var visible_buttons := buttons()
					for key in visible_buttons:
						if key.begins_with("level") and visible_buttons[key].has_point(local):
							action(key)
							break
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			map_scroll = clampf(map_scroll + (84 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -84), 0, 76)
			queue_redraw()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		point = to_local(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = to_local(event.position)
	else:
		return
	input_count += 1
	for key in buttons():
		if buttons()[key].has_point(point):
			action(key)
			get_viewport().set_input_as_handled()
			return
	if screen == "game" and not menu and not transfer and not guide and not details and pending.is_empty() and not paused:
		for room in level.rooms:
			if room_rect(room).has_point(point):
				selected = room.id
				claimed_gain = -1
				tone(420)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return

func back() -> void:
	if import_pending: return
	cancel_normal_copy()
	if details:
		details = false
	elif guide:
		guide = false
		menu = true
	elif transfer:
		transfer = false
		editor.visible = false
	elif menu:
		menu = false
	elif screen == "challenge_records":
		screen = "challenge_select"
	elif screen == "challenge_select":
		screen = "game"
		hide_seed()
	elif screen == "map":
		screen = "game"
	elif not paused:
		paused = true
	else:
		data.kind = "campaign"
		load_run()
		screen = "map"
	seed_edit.visible = screen == "challenge_select" and not menu and not guide and not transfer
	persist()
	queue_redraw()

func action(key: String) -> void:
	if import_pending: return
	cancel_normal_copy()
	if key == "settings":
		menu = true
		hide_seed()
	elif key == "close_menu":
		menu = false
		seed_edit.visible = screen == "challenge_select"
	elif key == "guide":
		guide = true
		menu = false
	elif key == "close_guide":
		guide = false
		menu = true
	elif key == "details":
		details = true
	elif key == "close_details":
		details = false
	elif key == "sound":
		data.settings.sound = not data.settings.sound
		persist()
	elif key == "effects":
		data.settings.reduced_effects = not data.settings.reduced_effects
		persist()
	elif key == "transfer":
		transfer = true
		editor.text = Saves.encode(data)
		editor.visible = true
	elif key == "close_transfer":
		transfer = false
		editor.visible = false
	elif key == "copy":
		start_normal_copy()
	elif key == "paste":
		paste_normal_code()
	elif key == "import":
		begin_import(editor.text)
	elif key == "resume":
		screen = "game"
		paused = false
	elif key == "map":
		if data.kind == "challenge":
			data.kind = "campaign"
			load_run()
		screen = "map"
		persist()
	elif key.begins_with("chapter"):
		chapter = int(key.trim_prefix("chapter"))
		map_scroll = 0
	elif key.begins_with("level"):
		var index := int(key.trim_prefix("level"))
		var levels := Content.levels()
		if Content.unlocked(index, data.profile) or levels[index].id == data.level_id or data.profile.has(levels[index].id):
			if levels[index].id != data.level_id:
				data.level = index
				data.level_id = levels[index].id
				data.catalog = Content.VERSION
				data.actions = []
				data.used_undo = false
				load_run()
				note = ""
			persist()
			screen = "game"
			paused = false
	elif key == "retry":
		current_run().actions = []
		current_run().used_undo = false
		load_run()
		note = "A fresh route. Earned medals stay."
		paused = false
		persist()
	elif key == "undo" and pending.is_empty():
		if not current_run().actions.is_empty():
			current_run().actions.pop_back()
			current_run().used_undo = true
			load_run()
			note = "Undone: power, key, shield and bridges restored."
			persist()
	elif key == "next" and state.status == "won" and data.kind == "challenge":
		current_run().actions = []
		current_run().used_undo = false
		load_run()
		persist()
	elif key == "records":
		screen = "challenge_records"
		hide_seed()
		record_page = 0
	elif key == "record_prev":
		record_page = maxi(0, record_page - 1)
	elif key == "record_next":
		record_page = mini(maxi(0, (data.challenge_records.size() - 1) / 5), record_page + 1)
	elif key == "records_back":
		screen = "challenge_select"
		seed_edit.visible = true
	elif key.begins_with("record_"):
		var record: Dictionary = data.challenge_records[int(key.trim_prefix("record_"))]
		var replay := Challenge.generate(record.family, int(record.seed), record.options, 0 if record.fallback else Challenge.MAX_ATTEMPTS)
		if replay.ok and Challenge.validate(replay.bundle).key == record.key:
			data.kind = "challenge"
			data.challenge_run = {"bundle": replay.bundle, "actions": [], "used_undo": false}
			load_run()
			screen = "game"
			paused = false
			persist()
		else: note = "Cannot reproduce record; resume the saved watch."
	elif key == "challenge_select":
		note = ""
		menu = false
		screen = "challenge_select"
		if not data.challenge_run.is_empty():
			var bundle: Dictionary = data.challenge_run.bundle
			challenge_family = bundle.family
			challenge_weave = int(bundle.options.weave)
			challenge_treasure = bundle.options.treasure
			seed_edit.text = str(bundle.seed)
		else: seed_edit.text = "137"
		seed_edit.visible = true
	elif key.begins_with("family_"):
		challenge_family = key.trim_prefix("family_")
	elif key == "weave":
		challenge_weave = (challenge_weave + 1) % 4
	elif key == "treasure_option":
		challenge_treasure = not challenge_treasure
	elif key == "seed_next":
		seed_edit.text = str((int(seed_edit.text) + 1) % 2147483648)
	elif key == "generate":
		if RegEx.create_from_string("^[0-9]{1,10}$").search(seed_edit.text) and int(seed_edit.text) <= 2147483647:
			start_challenge(challenge_family, int(seed_edit.text), {"weave": challenge_weave, "treasure": challenge_treasure})
		else: note = "Seed must be a whole number from 0 to 2147483647."
	elif key == "resume_challenge":
		data.kind = "challenge"
		load_run()
		screen = "game"
		paused = false
		hide_seed()
		persist()
	elif key == "back_challenge":
		back()
	elif key == "challenge_new":
		var bundle: Dictionary = data.challenge_run.bundle
		start_challenge(bundle.family, (int(bundle.seed) + 1) % 2147483648, bundle.options)
	elif key == "hint":
		show_hint = not show_hint
	elif key == "next" and state.status == "won":
		var next_index := Content.index_of(data.level_id) + 1
		# Inserted tutorials remain real requirements for historic profiles.
		for i in next_index:
			if not data.profile.has(Content.levels()[i].id):
				next_index = i
				break
		if next_index < Content.levels().size():
			data.level = next_index
			data.level_id = Content.levels()[int(data.level)].id
			data.catalog = Content.VERSION
			data.actions = []
			data.used_undo = false
			load_run()
			note = ""
			persist()
		else:
			screen = "ending"
	elif key == "enter" and pending.is_empty() and not paused:
		var result := Rules.step(level, state, selected)
		if result.ok:
			pending = result
			pending_room = selected
			beat = 0
			tone(260)
		else:
			note = result.message
	queue_redraw()

func box(rect: Rect2, color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(2)
	draw_style_box(style, rect)

func text_at(value: String, at: Vector2, size: int, color: Color = WHITE) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, rect: Rect2, size: int, color: Color = WHITE) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_at(value, Vector2(rect.get_center().x - width * 0.5, rect.position.y + rect.size.y * 0.5 + size * 0.34), size, color)

func lines(value: String, at: Vector2, width: float, size: int, color: Color = WHITE, max_lines: int = 3, line_height: float = 0.0) -> void:
	var line := ""
	var row := 0
	var step := line_height if line_height > 0 else size + 5.0
	for word in value.split(" "):
		if font.get_string_size(line + " " + word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			text_at(line, at + Vector2(0, row * step), size, color)
			row += 1
			line = word
			if row >= max_lines:
				return
		else:
			line = word if line == "" else line + " " + word
	text_at(line, at + Vector2(0, row * step), size, color)

func button(key: String, label: String, color: Color = Color("24485e")) -> void:
	if buttons().has(key):
		box(buttons()[key], color, 12)
		centered(label, buttons()[key], 23, INK if color == TEAL or color == GOLD else WHITE)

## Enemy strength badge: dark plate, gold rim, outlined white numeral.
func badge(value: String, center: Vector2, size: int, active: bool) -> void:
	var width := maxf(40.0, font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 18)
	var rect := Rect2(center - Vector2(width * 0.5, size * 0.6), Vector2(width, size * 1.2))
	box(rect, Color("5e1f33", .94) if active else Color("2a3a4a", .9), 9, GOLD if active else Color("6e8494"))
	var text_pos := Vector2(center.x - (width - 18) * 0.5, center.y + size * 0.36)
	draw_string_outline(font, text_pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color("1a0710"))
	draw_string(font, text_pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, WHITE if active else MUTED)

func pill(value: String, center: Vector2, size: int, fill: Color, ink: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 16
	box(Rect2(center - Vector2(width * 0.5, size * 0.7), Vector2(width, size * 1.4)), fill, 8)
	text_at(value, Vector2(center.x - width * 0.5 + 8, center.y + size * 0.36), size, ink)

func courier(at: Vector2, factor: float = 1.0) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-14, -2) * factor, at + Vector2(-23, 29) * factor, at + Vector2(15, 22) * factor, at + Vector2(11, -7) * factor]), Color("32baa2"))
	draw_line(at + Vector2(-6, 18) * factor, at + Vector2(-7, 32) * factor, SAND, 6 * factor)
	draw_line(at + Vector2(7, 18) * factor, at + Vector2(11, 32) * factor, SAND, 6 * factor)
	draw_circle(at + Vector2(0, -12) * factor, 15 * factor, GOLD)
	draw_line(at + Vector2(-13, -12) * factor, at + Vector2(14, -12) * factor, INK, 9 * factor)
	draw_circle(at + Vector2(7, -13) * factor, 2 * factor, WHITE)
	draw_line(at + Vector2(11, 4) * factor, at + Vector2(25, 9) * factor, GOLD, 4 * factor)
	draw_circle(at + Vector2(27, 10) * factor, 6 * factor, GOLD)

func spirit(at: Vector2, active: bool = true, compact: bool = false) -> void:
	var tint := RED if active else Color("4b7c83")
	draw_set_transform(at, 0, Vector2.ONE * (0.7 if compact else 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 15), Vector2(-13, -8), Vector2(13, -8), Vector2(17, 15), Vector2(5, 10), Vector2(-6, 15)]), tint)
	draw_circle(Vector2(0, -8), 16, tint)
	draw_circle(Vector2(0, -8), 11, INK)
	draw_line(Vector2(0, -8), Vector2(0, -15), SAND, 2)
	draw_line(Vector2(0, -8), Vector2(6, -5), SAND, 2)
	draw_set_transform(Vector2.ZERO)

func background() -> void:
	if view != null:
		return
	for y in 54:
		draw_rect(Rect2(0, y * 20, 600, 20), Color("0a182e").lerp(Color("285264"), float(y) / 54.0))
	for i in 18:
		draw_circle(Vector2(fmod(i * 127 + 41, 590), fmod(i * 73, 290) + 94), 1.3, Color("829ead"))
	draw_circle(Vector2(521, 262), 35, Color("d2c8ae"))
	draw_circle(Vector2(505, 253), 31, Color("193a51"))
	for i in 8:
		var x := float(i * 92 - 30)
		draw_rect(Rect2(x, 605 + (i % 3) * 19, 65, 148), Color("234456"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, 608 + (i % 3) * 19), Vector2(x + 32, 574 + (i % 3) * 19), Vector2(x + 72, 608 + (i % 3) * 19)]), Color("2d5360"))
	draw_rect(Rect2(0, 746, 600, 320), Color("102d42"))
	for i in 7:
		draw_line(Vector2(i * 96, 759 + (i % 2) * 10), Vector2(i * 96 + 58, 759 + (i % 2) * 10), Color("417789"), 2)

func draw_header() -> void:
	text_at("TOWER TRIALS", Vector2(26, 58), 29, GOLD)
	button("settings", "•••")
	text_at(FAMILY_NAMES.get(data.challenge_run.bundle.family, "Challenge").to_upper() + " · v1 · seed %d · weave %d · treasure %s%s" % [data.challenge_run.bundle.seed, data.challenge_run.bundle.options.weave, "on" if data.challenge_run.bundle.options.treasure else "off", " · backup" if data.challenge_run.bundle.fallback else ""] if data.kind == "challenge" else (CHAPTER_NAMES[clampi(int(level.get("chapter", 0)), 0, 3)].to_upper() if screen == "game" else "COAST OF THE LOST CHIMES"), Vector2(26, 84), 15, MUTED)
	if screen == "game":
		text_at("Challenge · " + level.name if data.kind == "challenge" else "%02d / %02d  ·  %s" % [Content.index_of(data.level_id) + 1, Content.levels().size(), level.name], Vector2(26, 126), 23)
		box(Rect2(24, 146, 260, 72), Color("173e53"), 12, Color("347b7d"))
		text_at("COURIER POWER", Vector2(40, 170), 15, TEAL)
		text_at(str(state.power), Vector2(40, 205), 34, GOLD)
		text_at("Keys  %d    Shields  %d" % [state.keys, state.shields], Vector2(310, 172), 20)
		text_at("Moves %d    Treasure %d" % [state.moves, state.treasure], Vector2(310, 204), 19, MUTED)
		if not state.get("rescued", []).is_empty():
			text_at("Keepers rescued: %d" % state.rescued.size(), Vector2(310, 232), 17, TEAL)

func draw_board() -> void:
	for column in [1, 2]:
		var highest := -1
		for room in level.rooms:
			if int(room.column) == column:
				highest = maxi(highest, int(room.floor))
		if highest >= 0:
			var x: int = 182 + (column - 1) * 200
			var highest_room: Dictionary = level.rooms.filter(func(item): return int(item.column) == column and int(item.floor) == highest)[0]
			var y: int = int(room_rect(highest_room).position.y)
			if view == null:
				draw_rect(Rect2(x + 6, y + 5, 168, 742 - y), Color("345566"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 7, y), Vector2(x + 90, y - 50), Vector2(x + 187, y)]), Color("5f7e89"))
	for room in level.rooms:
		for prerequisite in room.requires:
			var other := Rules.find_room(level, prerequisite)
			if not other.is_empty():
				connector(room_rect(other), room_rect(room), Color("74b9ab"), false)
		if not room.collapse.is_empty():
			var other := Rules.find_room(level, room.collapse[0])
			if not other.is_empty():
				connector(room_rect(room), room_rect(other), GOLD, true)
	var floors: int = state.claimed.size() + 1
	if view == null:
		for i in floors:
			var rect := Rect2(31, 692 - i * home_stride(), 116, home_stride() - 2)
			box(rect, Color("397781") if i > 0 else Color("345566"), 4, Color("64bea9"))
			draw_rect(Rect2(72, rect.position.y + 19, 29, minf(32, home_stride() - 22)), INK)
			if i > 0:
				draw_circle(rect.position + Vector2(100, 12), 4, GOLD)
		var top: float = 692 - (floors - 1) * home_stride()
		draw_colored_polygon(PackedVector2Array([Vector2(23, top), Vector2(89, top - 42), Vector2(156, top)]), TEAL)
		draw_line(Vector2(89, top - 42), Vector2(89, top - 69), GOLD, 3)
		draw_colored_polygon(PackedVector2Array([Vector2(90, top - 69), Vector2(116, top - 61), Vector2(90, top - 52)]), GOLD)
	text_at("YOUR WATCH", Vector2(25, 778), 16, TEAL)
	for room in level.rooms:
		var rect := room_rect(room)
		var claimed: bool = room.id in state.claimed
		var collapsed: bool = room.id in state.collapsed and not claimed
		var blocked := Rules.blocked(state, room)
		var fill := Color("405a66") if blocked != "" else Color("e0cba5")
		if claimed:
			fill = Color("397781")
		if collapsed:
			fill = Color("263c50")
		box(rect, fill if view == null else Color.TRANSPARENT, 5, GOLD if selected == room.id else Color("75949a"))
		if selected == room.id and view != null:
			box(rect.grow(3), Color.TRANSPARENT, 7, GOLD)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 24), Vector2(180, 24)), Color("1d3a4c"))
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 24), Vector2(180, 2)), Color("c9a24e"))
		centered(room.name, Rect2(rect.position + Vector2(0, rect.size.y - 24), Vector2(180, 24)), 16, WHITE)
		if collapsed:
			centered("COLLAPSED", Rect2(rect.position, Vector2(180, 90)), 18, MUTED)
		elif claimed:
			pill("CLAIMED", Vector2(rect.get_center().x, rect.position.y + 20), 15, Color("15584f"), TEAL)
		else:
			for i in room.enemies.size():
				var enemy_x: float = (i + 1) * 180.0 / (room.enemies.size() + 1)
				var compact: bool = rect.size.y < 120
				if view == null:
					spirit(rect.position + Vector2(enemy_x, 67 if compact else 77), blocked == "", compact)
				badge(str(room.enemies[i]), rect.position + Vector2(enemy_x, 26 if compact else 28), 24 if compact or room.enemies.size() > 2 else 27, blocked == "")
			var tags: Array = []
			if room.key_cost > 0: tags.append("LOCK %d" % room.key_cost)
			if room.keys > 0: tags.append("+%d KEY" % int(room.keys))
			if room.shields > 0: tags.append("+%d SHIELD" % int(room.shields))
			if room.trap > 0: tags.append("TRAP %d" % room.trap)
			if room.multiplier > 1: tags.append("SUN x%d" % room.multiplier)
			if room.treasure: tags.append("CHEST")
			if room.rescue: tags.append("RESCUE")
			if room.get("keeper", false): tags.append("KEEPER")
			if not tags.is_empty():
				pill("  ".join(tags), Vector2(rect.get_center().x, rect.position.y + 4), 12, Color("102c42", .94), GOLD)
	if view == null:
		courier(courier_point())

func draw_game() -> void:
	draw_board()
	box(Rect2(24, 792, 552, 158), Color("091d32"), 16)
	if state.status == "won":
		var feedback:=clear_feedback()
		text_at(feedback[0],Vector2(40,820),19,TEAL)
		text_at(feedback[1],Vector2(40,850),17,SAND)
		text_at(feedback[2],Vector2(560-font.get_string_size(feedback[2],HORIZONTAL_ALIGNMENT_LEFT,-1,17).x,850),17,MUTED)
		button("next", "Replay this exact watch" if data.kind == "challenge" else ("Next watch" if Content.index_of(data.level_id) + 1 < Content.levels().size() else "The ending · all lanterns rise"), TEAL)
	elif paused:
		text_at("ROUTE PAUSED", Vector2(40, 829), 27, GOLD)
		button("resume", "Resume route", TEAL)
	elif state.status == "lost":
		text_at("LANTERN EXTINGUISHED", Vector2(40, 827), 25, RED)
		lines(note, Vector2(40, 859), 500, 18, SAND, 2)
		text_at("Undo the last room or Retry below.", Vector2(40, 927), 20, WHITE)
	elif not pending.is_empty():
		text_at("COURIER IN FLIGHT", Vector2(40, 829), 24, GOLD)
		lines("  /  ".join(pending.events), Vector2(40, 861), 510, 19, SAND, 3)
	elif selected != "":
		var preview := Rules.step(level, state, selected)
		if not preview.ok:
			text_at("ROUTE CLOSED", Vector2(40, 824), 22, MUTED)
			lines(preview.message, Vector2(40, 854), 500, 18, WHITE, 1)
		else:
			text_at("FORECAST: %s · %d to %d" % ["CLAIM" if preview.win else "DEFEAT", int(state.power), int(preview.state.power)], Vector2(40, 820), 21, TEAL if preview.win else RED)
			text_at("Tap forecast for all steps and resources", Vector2(40, 851), 17, SAND)
		button("enter", "Enter room" if preview.get("win", false) else "Enter anyway · danger", TEAL if preview.get("win", false) else Color("633f4b"))
	else:
		var later: bool = data.kind == "campaign" and Content.index_of(data.level_id) >= 6
		if claimed_gain >= 0 and not show_hint:
			text_at("+%d CLAIMED · PICK THE NEXT ROOM" % claimed_gain, Vector2(40, 825), 21, TEAL)
		else:
			text_at("OPTIONAL HINT · tap to hide" if show_hint else ("RULES · tap for optional hint" if later else "READ THE TOWER"), Vector2(40, 825), 21, GOLD)
		lines(level.lesson if not later or show_hint else "Greater power wins. Locks spend keys; shields block traps. Read gifts, sealed routes and ordered enemies.", Vector2(40, 858), 510, 21, WHITE, 3)
	button("undo", "Undo")
	button("retry", "Retry")
	button("map", "Campaign" if data.kind == "challenge" else "Journey")
	button("challenge_new", "New")

func draw_map() -> void:
	text_at(CHAPTER_NAMES[chapter], Vector2(26, 130), 32)
	for i in 4:
		button("chapter%d" % i, ["Coast", "Archive", "Glass", "Meridian"][i], TEAL if chapter == i else Color("24485e"))
	var all := Content.levels()
	for slot in 9:
		var i := chapter * 9 + slot
		var current: bool = all[i].id == data.level_id
		var earned: bool = data.profile.has(all[i].id)
		var available: bool = Content.unlocked(i, data.profile) or current or earned
		if not buttons().has("level%d" % i): continue
		var rect: Rect2 = buttons()["level%d" % i]
		box(rect, Color("254c5e") if available else Color("182f43"), 10, TEAL if current else Color.TRANSPARENT)
		text_at("%02d" % (i + 1), rect.position + Vector2(16, 32), 24, GOLD if available else MUTED)
		text_at(all[i].name, rect.position + Vector2(70, 29), 23, WHITE if available else MUTED)
		var medals: Dictionary = data.profile.get(all[i].id, {})
		text_at(journey_medals(all[i],medals) if earned else ("Par %d%s" % [int(all[i].par), " · chapter finale" if bool(all[i].get("finale", false)) else ""] if available else "Rescue the previous keepers"), rect.position + Vector2(70, 55), 17, TEAL if available else MUTED)
	text_at("Drag the list to see all nine watches", Vector2(26, 945), 18, SAND)
	button("resume", "Return to current route", TEAL)
	text_at("%d / 36 rescued · rules and medal guide in •••" % data.profile.size(), Vector2(26, 962), 15, MUTED)

func draw_ending() -> void:
	text_at("ALL LANTERNS RISE", Vector2(26, 180), 36, GOLD)
	lines("The last chime crosses the sea. Every watch answers. You brought the lost keepers home.", Vector2(28, 234), 530, 27, WHITE, 4)
	if view == null:
		for i in 12:
			var x := 34 + (i % 6) * 93
			var y := 488 + (i / 6) * 168
			box(Rect2(x, y, 68, 104), Color("397781"), 5, TEAL)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y), Vector2(x + 34, y - 36), Vector2(x + 73, y)]), TEAL)
			draw_circle(Vector2(x + 34, y + 44), 10, GOLD)
		courier(Vector2(300, 750), 1.6)
	lines("36 authored watches. Return for unclaimed treasure, par routes, clean runs and alternate branches.", Vector2(28, 836), 530, 22, SAND, 3)
	button("map", "Explore your journey", TEAL)

func _draw() -> void:
	if import_pending: return
	if state == null:
		return
	if view != null and view.is_inside_tree():
		sync_view()
	background()
	draw_header()
	if screen == "game": draw_game()
	elif screen == "ending": draw_ending()
	elif screen == "challenge_select": draw_challenge_select()
	elif screen == "challenge_records": draw_challenge_records()
	else: draw_map()
	if save_error != "":
		box(Rect2(12, 226, 576, 65), Color("6a2838"), 8)
		lines(save_error, Vector2(24, 250), 550, 19, WHITE, 2)
	if menu:
		draw_rect(Rect2(0, 0, 600, 1066), Color(0.01, 0.03, 0.08, 0.85))
		box(Rect2(30, 180, 540, 680), INK, 20, Color("467a87"))
		text_at("Your lantern", Vector2(58, 242), 32, GOLD)
		button("sound", "Sound: " + ("on" if data.settings.sound else "off"))
		button("effects", "Reduced effects: " + ("on" if data.settings.reduced_effects else "off"))
		button("transfer", "Export / import save")
		button("guide", "Rules and medals")
		button("challenge_select", "Seeded Challenges")
		button("close_menu", "Return", TEAL)
	if transfer:
		draw_rect(Rect2(0, 0, 600, 1066), Color(0.01, 0.03, 0.08, 0.95))
		text_at("A route in your pocket", Vector2(42, 244), 29, GOLD)
		lines("Copy this text to keep a backup. Paste a saved route and Import to restore.", Vector2(42, 277), 516, 18, SAND, 2)
		button("copy", "Copy")
		button("paste", "Paste")
		button("import", "Import", TEAL)
		button("close_transfer", "Return")
		lines(note, Vector2(42, buttons().close_transfer.end.y + font.get_ascent(19) + 8), 516, 19, WHITE, 3, font.get_height(19))

	if guide:
		draw_rect(Rect2(0, 0, 600, 1066), Color("0b2037"))
		text_at("Carry the light", Vector2(42, 107), 34, GOLD)
		var help := ["Power must be GREATER than each enemy. Equality loses. Add each defeated strength before the next voice.", "A key opens one lock, then is gone. Read the lock cost and the keys a room gives.", "A dashed bridge seals the named alternative rooms. Rescue KEEPER rooms before their bridge closes.", "A shield blocks one trap before combat. Otherwise subtract the trap from power first.", "A sun lens multiplies after enemies. It refuses a carried shield: spend protection before entering.", "Medals reward rescue, a route at par, no Undo and treasure where offered. Earn them on separate replays. Retry starts a clean attempt; earned medals stay."]
		for i in help.size():
			text_at(str(i + 1), Vector2(42, 174 + i * 111), 26, TEAL)
			lines(help[i], Vector2(80, 168 + i * 111), 470, 21, WHITE, 4)
		button("close_guide", "Return", TEAL)
	if details:
		draw_rect(Rect2(0, 0, 600, 1066), Color("0b2037"))
		var preview := Rules.step(level, state, selected)
		text_at("Every step is visible", Vector2(42, 104), 32, GOLD)
		text_at(Rules.find_room(level, selected).name, Vector2(42, 148), 26, WHITE)
		text_at("Power %d to %d" % [state.power, preview.state.power], Vector2(42, 196), 26, TEAL if preview.get("win", false) else RED)
		text_at("Keys %d to %d · Shields %d to %d" % [state.keys, preview.state.keys, state.shields, preview.state.shields], Vector2(42, 231), 22, SAND)
		var y := 290
		for event in preview.events:
			lines(str(event), Vector2(42, y), 516, 23, WHITE, 2)
			y += 78
		button("close_details", "Return to room choice", TEAL)

func current_run() -> Dictionary:
	return data.challenge_run if data.kind == "challenge" else data

func start_challenge(family: String, seed_value: int, options: Dictionary) -> void:
	if import_pending: return
	var result := Challenge.generate(family, seed_value, options)
	if not result.ok:
		note = result.message
		return
	data.challenge_run = {"bundle": result.bundle, "actions": [], "used_undo": false}
	data.kind = "challenge"
	load_run()
	screen = "game"
	paused = false
	hide_seed()
	persist()

func draw_challenge_select() -> void:
	text_at("Seeded Challenges · v1", Vector2(26, 130), 30, GOLD)
	text_at("Family, seed and options define a repeatable watch.", Vector2(42, 184), 18, SAND)
	for family in Challenge.FAMILIES:
		button("family_" + family, FAMILY_NAMES[family], TEAL if family == challenge_family else Color("24485e"))
	text_at("Seed · 0 to 2147483647", Vector2(42, 420), 21, WHITE)
	button("seed_next", "+1 seed")
	button("weave", "Weave %d" % challenge_weave)
	button("treasure_option", "Treasure " + ("on" if challenge_treasure else "off"))
	button("generate", "New challenge", TEAL)
	button("resume_challenge", "Resume saved")
	button("records", "Records")
	button("back_challenge", "Return")
	lines(note if note != "" else "Plan before crossing: a choice can seal your only route. Retry and Resume keep the same watch. Your 256 most recent challenge records stay separate from campaign medals.", Vector2(42, 970), 516, 18, SAND, 4)

func current_challenge_record() -> Dictionary:
	if data.kind != "challenge": return {}
	var key: String = Challenge.validate(data.challenge_run.bundle).key
	for record in data.challenge_records:
		if record.key == key: return record
	return {}

func draw_challenge_records() -> void:
	text_at("Challenge records · v1", Vector2(42, 130), 30, GOLD)
	text_at("Tap to replay the same version, seed and options.", Vector2(42, 187), 20, SAND)
	if note != "": lines(note, Vector2(42, 214), 516, 17, RED, 1)
	var visible_buttons := buttons()
	for slot in 5:
		var index: int = data.challenge_records.size() - 1 - record_page * 5 - slot
		if index < 0: continue
		var record: Dictionary = data.challenge_records[index]
		var rect: Rect2 = visible_buttons["record_%d" % index]
		box(rect, Color("24485e"), 12)
		text_at("%s · seed %d" % [str(record.family).capitalize(), record.seed], rect.position + Vector2(16, 31), 24, WHITE)
		text_at("Weave %d · treasure %s · best %d" % [record.options.weave, "on" if record.options.treasure else "off", record.best], rect.position + Vector2(16, 62), 20, SAND)
		text_at(medal_labels(int(record.medals)) + (" · fallback" if record.fallback else ""), rect.position + Vector2(16, 87), 18, TEAL)
	button("record_prev", "Newer")
	button("record_next", "Older")
	button("records_back", "Return", TEAL)

func hide_seed() -> void:
	seed_edit.release_focus()
	seed_edit.visible = false
	if OS.get_name() == "Android": DisplayServer.virtual_keyboard_hide()

func medal_labels(bits: int) -> String:
	var names: Array = []
	for pair in [[1, "Rescue"], [2, "Par"], [4, "Treasure"], [8, "No Undo"]]:
		if bits & int(pair[0]): names.append(pair[1])
	return " · ".join(names)

# Presentation reads the current clear separately from accumulated replay records.
func clear_feedback() -> Array[String]:
	if state.status!="won": return []
	var bits:=1
	if int(state.moves)<=int(level.par): bits|=2
	if int(state.treasure)>0: bits|=4
	if not current_run().used_undo: bits|=8
	var record: Dictionary=current_challenge_record() if data.kind=="challenge" else data.profile.get(level.id,{})
	return ["This clear · "+medal_labels(bits),"Collected · "+medal_labels(int(record.get("medals",0)) & eligible_medals(level)),"Best %d · Par %d" % [int(record.get("best",0)),level.par]]
func eligible_medals(definition: Dictionary) -> int:
	return 15 if definition.rooms.any(func(room): return room.treasure) else 11
func journey_medals(definition: Dictionary,record: Dictionary) -> String:
	var missing:=eligible_medals(definition) & ~int(record.get("medals",0))
	return "Best %d · " % int(record.get("best",0))+("All medals earned" if missing==0 else "To earn: "+medal_labels(missing))

func build_recovery_ui() -> void:
	var layer:=CanvasLayer.new(); layer.layer=20; add_child(layer)
	recovery_root=Control.new(); recovery_root.mouse_filter=Control.MOUSE_FILTER_STOP; layer.add_child(recovery_root); recovery_root.hide()
	var backplate:=ColorRect.new(); backplate.color=Color("102c42"); backplate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); recovery_root.add_child(backplate)
	recovery_panel=PanelContainer.new(); recovery_root.add_child(recovery_panel)
	var surface:=StyleBoxFlat.new(); surface.bg_color=Color("102c42"); surface.content_margin_left=16; surface.content_margin_right=16; surface.content_margin_top=16; surface.content_margin_bottom=16
	recovery_panel.add_theme_stylebox_override("panel",surface)
	recovery_scroll=ScrollContainer.new(); recovery_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; recovery_panel.add_child(recovery_scroll)
	var col:=VBoxContainer.new(); col.size_flags_horizontal=Control.SIZE_EXPAND_FILL; col.add_theme_constant_override("separation",14); recovery_scroll.add_child(col)
	var title:=recovery_label(col,"Choose your complete save",28); title.add_theme_color_override("font_color",GOLD)
	recovery_message=recovery_label(col,"",23); recovery_summary=recovery_label(col,"",23)
	for item in [["retry","Retry Import",finish_import.bind(true)],["previous","Keep Previous",finish_import.bind(false)],["read","Retry Recovery Read",retry_recovery_read],["copy_previous","Copy Previous",copy_recovery_code.bind(false)],["copy_incoming","Copy Imported",copy_recovery_code.bind(true)],["view_previous","View Previous Code",show_recovery_code.bind(false)],["view_incoming","View Imported Code",show_recovery_code.bind(true)]]:
		var control:=Button.new(); control.text=item[1]; control.custom_minimum_size=Vector2(0,90); control.add_theme_font_size_override("font_size",24); control.pressed.connect(item[2]); col.add_child(control); recovery_buttons[item[0]]=control
		if item[0]=="read":
			recovery_copy_feedback=recovery_label(col,"",22); recovery_copy_feedback.custom_minimum_size.y=112
	recovery_label(col,"Copying or viewing a code keeps recovery paused. An unfinished room step has not been counted; either choice restarts from its saved route.",21)
	recovery_code=TextEdit.new(); recovery_code.editable=false; recovery_code.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY; recovery_code.custom_minimum_size=Vector2(0,230); recovery_code.add_theme_font_size_override("font_size",18); col.add_child(recovery_code); recovery_code.hide()
func recovery_label(parent: Node,text: String,size: int) -> Label:
	var result:=Label.new(); result.text=text; result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; result.add_theme_font_size_override("font_size",size); result.add_theme_color_override("font_color",WHITE); parent.add_child(result); return result
func show_recovery() -> void:
	if not import_pending or not is_instance_valid(recovery_root): return
	paused=true; map_touch_pending=false; map_dragged=false; editor.hide(); hide_seed(); view.visible=false
	recovery_root.show(); recovery_message.text=import_recovery.message
	var known:=not import_recovery.record.is_empty()
	for id in recovery_buttons: recovery_buttons[id].visible=(id=="read") if not known else id!="read"
	recovery_summary.text="PREVIOUS COMPLETE SAVE\n"+Recovery.describe(import_recovery.original)+"\n\nIMPORTED COMPLETE SAVE\n"+Recovery.describe(import_recovery.incoming) if known else "Play and local saving are paused. No default route will be saved."
func cancel_normal_copy() -> void:
	if normal_copy.pending: note="Copy not confirmed. Select the save text to copy manually."
	normal_copy.cancel(); normal_copy_ticket=-1
	if is_inside_tree(): queue_redraw()
func normal_transfer_valid(editor_id: int,generation: int) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and not import_pending and transfer and is_instance_valid(editor) and editor.visible and editor.get_instance_id()==editor_id and normal_copy.generation==generation
func normal_copy_valid() -> bool:
	if not is_instance_valid(editor): return false
	return normal_transfer_valid(editor.get_instance_id(),normal_copy_ticket) and normal_copy.target=="normal:"+str(editor.get_instance_id()) and editor.text==normal_copy.expected
func start_normal_copy() -> void:
	if import_pending or not transfer or not is_instance_valid(editor) or not editor.visible: return
	editor.select_all(); normal_copy.backend=clipboard_backend
	var ticket:=normal_copy.begin(editor.text,"normal:"+str(editor.get_instance_id()),"Select the save text to copy manually.")
	if not is_instance_valid(self) or ticket!=normal_copy.generation: return
	normal_copy_ticket=ticket
	if normal_copy_valid(): note=normal_copy.feedback; queue_redraw()
func poll_normal_copy(delta: float) -> void:
	if not normal_copy.pending: return
	if not normal_copy_valid(): cancel_normal_copy(); return
	var ticket:=normal_copy.generation
	var changed:=normal_copy.poll(delta)
	if ticket!=normal_copy.generation: return
	if not normal_copy_valid():
		note="Copy not confirmed. Select the save text to copy manually."
		cancel_normal_copy(); return
	if changed: note=normal_copy.feedback; queue_redraw()
func paste_normal_code() -> void:
	cancel_normal_copy()
	if not is_instance_valid(editor): return
	var generation:=normal_copy.generation; var editor_id:=editor.get_instance_id(); var backend:=clipboard_backend; var previous_text:=editor.text
	var supported: bool=backend.available()
	if not normal_transfer_valid(editor_id,generation) or editor.text!=previous_text: return
	if not supported: note="Clipboard unavailable. Enter a save code in the text field."; queue_redraw(); return
	var text: String=backend.get_text()
	if normal_transfer_valid(editor_id,generation) and editor.text==previous_text: editor.text=text

func begin_import(text: String) -> void:
	cancel_normal_copy()
	if import_pending: return
	var decoded:=Saves.decode(text)
	if not decoded.ok: note=decoded.get("message","Invalid save"); return
	# No await: the admitted room animation cannot advance across this boundary.
	import_pending=true; paused=true; map_touch_pending=false
	import_recovery=Recovery.new(save_io,Recovery.path_for(save_path),save_path)
	recovery_status=import_recovery.begin(Saves.encode(data),text); import_pending=recovery_status.pending
	if not import_pending: note=import_recovery.message; return
	recovery_code.hide(); recovery_copy_feedback.text=""; show_recovery()
	if recovery_status.ok: finish_import(true)
func finish_import(use_import: bool) -> void:
	if not import_pending: return
	var result:=import_recovery.resolve(use_import)
	if not result.ok: show_recovery(); return
	# Complete saved history is authority; an uncommitted animation never appends later.
	var had_step:=not pending.is_empty()
	data=result.decoded.data.duplicate(true); load_run(); paused=true
	transfer=false; menu=false; guide=false; details=false; screen="game"; editor.hide(); hide_seed()
	map_touch_pending=false; map_dragged=false; pending_room=""; save_error=""
	import_pending=false; recovery_root.hide(); view.visible=true
	note=("Imported" if use_import else "Previous")+" complete save checked. Play is paused."+(" The unfinished step was not counted." if had_step else "")
	queue_redraw()
func retry_recovery_read() -> void:
	if not import_pending or not import_recovery.record.is_empty(): return
	recovery_status=import_recovery.read()
	if recovery_status.ok: data=recovery_status.original.data.duplicate(true); load_run(); paused=true
	elif not recovery_status.pending: import_recovery.message="The saved choices are unavailable. Local copies remain; play and saving stay paused. Keep this app installed for recovery."
	show_recovery()
func show_recovery_code(use_import: bool) -> void:
	if not import_pending or import_recovery.record.is_empty(): return
	recovery_code.text=import_recovery.incoming_code if use_import else import_recovery.original_code
	recovery_code.show(); call_deferred("scroll_recovery_code")
func scroll_recovery_code() -> void:
	await get_tree().process_frame
	if import_pending and recovery_code.is_visible_in_tree(): recovery_scroll.ensure_control_visible(recovery_code)
func copy_recovery_code(use_import: bool) -> void:
	if not import_pending or import_recovery.record.is_empty(): return
	var transaction:=import_recovery
	var text: String=transaction.incoming_code if use_import else transaction.original_code
	var id: String=transaction.record.incoming if use_import else transaction.record.original
	var name: String="Imported" if use_import else "Previous"
	if text.sha256_text()!=id or not Saves.decode(text).ok:
		recovery_copy_notice(name+" code is unavailable. Recovery stays paused."); return
	var available: bool=recovery_copy_backend.available() if recovery_copy_backend!=null else DisplayServer.get_name()!="headless" and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	if not available:
		recovery_copy_notice("Clipboard unavailable. Use View "+name+" Code to export manually. Recovery stays paused."); return
	var accepted:=true
	if recovery_copy_backend!=null: accepted=recovery_copy_backend.put(text)
	else: DisplayServer.clipboard_set(text)
	var observed: String=recovery_copy_backend.get_text() if recovery_copy_backend!=null else DisplayServer.clipboard_get()
	if not import_pending or import_recovery!=transaction: return
	recovery_copy_notice(name+" code copied and checked. Recovery stays paused." if accepted and observed==text else "Copy not confirmed. Use View "+name+" Code or try again. Recovery stays paused.")

func recovery_copy_notice(text: String) -> void:
	if not import_pending: return
	recovery_copy_feedback.text=text
	# A permanently allocated row makes the synchronous acknowledgment reachable.
	recovery_scroll.ensure_control_visible(recovery_copy_feedback)
