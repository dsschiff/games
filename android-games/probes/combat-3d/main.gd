extends Node3D

const Rules = preload("res://rules.gd")
const SAVE := "user://combat-probe.json"
var state := Rules.initial_state()
var player: Node3D
var swarm: Node3D
var meshes := {}
var status: Label
var hint: Label
var dragging := false
var drag_start := Vector2.ZERO
var movement := Vector2.ZERO
var paused := false
var save_clock := 0.0

func _ready() -> void:
	_load_save()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25.0
	camera.position = Vector3(0, 22, 19)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.2
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101c29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c9dbea")
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	for x in range(-3, 4):
		for z in range(-5, 6):
			var floor_tile := _box(Vector3(1.94, 0.16, 1.94), Color("283f4d") if (x + z) % 2 == 0 else Color("243744"))
			floor_tile.position = Vector3(x * 2.0, -0.2, z * 2.0)
			add_child(floor_tile)
	player = _actor(Color("43d9ee"), true)
	add_child(player)
	swarm = Node3D.new()
	add_child(swarm)
	_ui()
	_sync_visuals()

func _box(dimensions: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	instance.material_override = material
	return instance

func _actor(color: Color, armed: bool) -> Node3D:
	var actor := Node3D.new()
	var body := _box(Vector3(0.62, 0.8, 0.42), color)
	body.position.y = 0.9
	actor.add_child(body)
	var head := _box(Vector3(0.48, 0.44, 0.45), color.lightened(0.18))
	head.position.y = 1.5
	actor.add_child(head)
	var visor := _box(Vector3(0.38, 0.16, 0.04), Color("14202c"))
	visor.position = Vector3(0, 1.54, 0.25)
	actor.add_child(visor)
	for side in [-1.0, 1.0]:
		var leg := _box(Vector3(0.22, 0.5, 0.26), color.darkened(0.25))
		leg.position = Vector3(side * 0.2, 0.3, 0)
		actor.add_child(leg)
	if armed:
		var gun := _box(Vector3(0.2, 0.22, 0.7), Color("ffce69"))
		gun.position = Vector3(0.42, 0.95, 0.4)
		actor.add_child(gun)
	return actor

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_bottom", 35)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 32)
	layout.add_child(status)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	hint = Label.new()
	hint.text = "Drag anywhere to move\nAuto-fire • survive 30 encounters\n3D Android delivery probe"
	hint.add_theme_font_size_override("font_size", 25)
	layout.add_child(hint)
	var row := HBoxContainer.new()
	layout.add_child(row)
	for label in ["PAUSE", "RESTART"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(300, 85)
		button.add_theme_font_size_override("font_size", 28)
		button.pressed.connect(_pause if label == "PAUSE" else _restart)
		row.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		dragging = event.pressed
		drag_start = event.position
		movement = Vector2.ZERO
	elif event is InputEventScreenDrag and dragging:
		movement = (event.position - drag_start) / 100.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		drag_start = event.position
		movement = Vector2.ZERO
	elif event is InputEventMouseMotion and dragging:
		movement = (event.position - drag_start) / 100.0

func _physics_process(delta: float) -> void:
	if not paused:
		var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		Rules.step(state, movement if dragging else keyboard, delta)
		save_clock += delta
		if save_clock > 1.0:
			save_clock = 0.0
			_save()
	_sync_visuals()

func _sync_visuals() -> void:
	player.position = Vector3(state["x"], 0, state["z"])
	if movement.length() > 0.05:
		player.rotation.y = atan2(movement.x, movement.y)
	var alive := {}
	for enemy in state["enemies"]:
		var id: int = int(enemy["id"])
		alive[id] = true
		if not meshes.has(id):
			meshes[id] = _actor(Color("bd6e65"), false)
			swarm.add_child(meshes[id])
		var node := meshes[id] as Node3D
		node.position = Vector3(enemy["x"], 0, enemy["z"])
		node.rotation.y = atan2(state["x"] - enemy["x"], state["z"] - enemy["z"])
	for id in meshes.keys():
		if not alive.has(id):
			meshes[id].queue_free()
			meshes.erase(id)
	status.text = "FIELD TEST 3D  •  %s\nIntegrity %d   •   Cleared %d/30" % ["PAUSED" if paused else str(state["result"]).to_upper(), int(state["health"]), state["kills"]]

func _pause() -> void:
	paused = not paused
	dragging = false
	movement = Vector2.ZERO
	_save()

func _restart() -> void:
	state = Rules.initial_state()
	paused = false
	_save()

func _save() -> void:
	var file := FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if file == null:
		push_error("Cannot open probe save")
		return
	file.store_string(JSON.stringify(state))
	file.flush()
	file.close()
	DirAccess.rename_absolute(SAVE + ".tmp", SAVE)

func _load_save() -> void:
	for path in [SAVE, SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			var candidate: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if Rules.valid(candidate):
				state = Rules.restore(candidate)
				return

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		paused = true
		dragging = false
		movement = Vector2.ZERO
		_save()

