extends Control

const Rules = preload("res://rules.gd")
const SAVE := "user://probe-save.json"
var state := Rules.initial_state()
var status_label: Label
var board: GridContainer
var pulse := 0.0
var paused := false
var save_error := ""

func _ready() -> void:
	_load_save()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 50)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 22)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "GEAR LAB"
	title.add_theme_font_size_override("font_size", 48)
	layout.add_child(title)
	var help := Label.new()
	help.text = "Android delivery probe • 2D\nTap a pad to build. Run eight waves.\nProgress restores after closing the app."
	help.add_theme_font_size_override("font_size", 24)
	layout.add_child(help)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 30)
	layout.add_child(status_label)
	board = GridContainer.new()
	board.columns = 3
	board.add_theme_constant_override("h_separation", 14)
	board.add_theme_constant_override("v_separation", 14)
	layout.add_child(board)
	for cell in range(Rules.CELLS):
		var button := Button.new()
		button.custom_minimum_size = Vector2(205, 130)
		button.add_theme_font_size_override("font_size", 27)
		button.pressed.connect(_place.bind(cell))
		board.add_child(button)
	_button(layout, "RUN WAVE", _run_wave)
	_button(layout, "PAUSE / RESUME", _toggle_pause)
	_button(layout, "RESTART", _restart)
	_refresh()

func _button(parent: Node, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 76
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(action)
	parent.add_child(button)

func _place(cell: int) -> void:
	if not paused and state["result"] == "building" and Rules.place(state, cell):
		_save()
	_refresh()

func _run_wave() -> void:
	if not paused:
		Rules.run_wave(state)
		_save()
	_refresh()

func _toggle_pause() -> void:
	paused = not paused
	_save()
	_refresh()

func _restart() -> void:
	state = Rules.initial_state()
	paused = false
	_save()
	_refresh()

func _refresh() -> void:
	status_label.text = "%s  •  Wave %d/8\n%d scrap  •  %d integrity" % ["PAUSED" if paused else str(state["result"]).to_upper(), state["wave"], state["coins"], state["health"]]
	if not save_error.is_empty():
		status_label.text += "\n" + save_error
	for cell in range(board.get_child_count()):
		var built: bool = state["pads"].has(cell)
		var button := board.get_child(cell) as Button
		button.text = "⚙\nONLINE" if built else "+\n20 SCRAP"
		button.modulate = Color(0.4, 1.0, 0.76) if built else Color(0.65, 0.76, 0.9)

func _save() -> bool:
	var file := FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if file == null:
		save_error = "SAVE FAILED: could not write progress"
		push_warning(save_error)
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		save_error = "SAVE FAILED: storage write error"
		push_warning(save_error)
		return false
	if DirAccess.rename_absolute(SAVE + ".tmp", SAVE) != OK:
		save_error = "SAVE PENDING: temporary copy preserved"
		push_warning(save_error)
		return false
	save_error = ""
	return true

func _load_save() -> void:
	# A valid leftover temporary file is the newer interrupted write.
	for path in [SAVE + ".tmp", SAVE]:
		if FileAccess.file_exists(path):
			var candidate: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if Rules.valid(candidate):
				state = Rules.restore(candidate)
				return

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()

