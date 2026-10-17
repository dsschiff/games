extends RefCounted
## Original SVG silhouettes share one texture; motion and health stay live.
const KINDS := ["guard", "ranger", "mortar", "beetle", "shell", "skitter", "spitter", "swarm", "carapace", "captain", "siege", "matriarch"]
const TILE := 64
var atlas: Texture2D
var textures: Dictionary = {}

func _init() -> void:
	for kind in KINDS:
		textures[kind] = load("res://art/%s.svg" % kind)

func body_size(kind: String) -> Vector2:
	return Vector2(48, 50) if kind in ["captain", "siege", "matriarch"] else Vector2(24, 30) if kind in ["guard", "ranger", "mortar"] else Vector2(27, 34)

func body_rect(point: Vector2, kind: String) -> Rect2:
	var size := body_size(kind)
	return Rect2(point - size * Vector2(0.5, 0.65), size)

func paint(canvas: CanvasItem) -> void:
	for index in KINDS.size():
		var kind: String = KINDS[index]
		var center := Vector2(index * TILE + TILE / 2, TILE / 2)
		canvas.draw_texture_rect(textures[kind], body_rect(center, kind), false)
	canvas.draw_circle(Vector2(KINDS.size() * TILE + TILE / 2, TILE / 2 + 6), 10, Color(0.05, 0.09, 0.08, 0.25))

func bake(game: Node2D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i((KINDS.size() + 1) * TILE * 2, TILE * 2)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Node2D.new()
	canvas.scale = Vector2.ONE * 2
	canvas.draw.connect(paint.bind(canvas))
	viewport.add_child(canvas)
	game.add_child(viewport)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(game) or not game.is_inside_tree():
		return
	var original := viewport.get_texture().get_image()
	original.convert(Image.FORMAT_RGBA8)
	var combined := Image.create(original.get_width(), original.get_height() * 2, false, Image.FORMAT_RGBA8)
	combined.blit_rect(original, Rect2i(Vector2i.ZERO, original.get_size()), Vector2i.ZERO)
	# A second row supplies a white hit silhouette without per-actor materials.
	for y in original.get_height():
		for x in original.get_width():
			var pixel := original.get_pixel(x, y)
			combined.set_pixel(x, y + original.get_height(), Color(1, 1, 1, pixel.a))
	atlas = ImageTexture.create_from_image(combined)
	viewport.queue_free()
	game.queue_redraw()
	print("ACTOR_ATLAS_READY: ", atlas.get_size(), " kinds=", KINDS.size())

func tile(game: CanvasItem, point: Vector2, column: int, row: int = 0) -> void:
	game.draw_texture_rect_region(atlas, Rect2(point - Vector2.ONE * TILE / 2, Vector2.ONE * TILE), Rect2(Vector2(column, row) * TILE * 2, Vector2.ONE * TILE * 2))

func draw_unit(game: Variant, unit: Dictionary, friendly: bool, point: Vector2) -> void:
	var kind: String = unit.kind
	var body_point := point
	if not game.paused and not game.settings.reduced_effects:
		body_point.y += sin(game.clock * (8.0 if friendly else 10.0) + int(unit.id) * 1.7) * (1.2 if friendly else 0.6)
	if atlas != null:
		tile(game, point, KINDS.size())
		tile(game, body_point, KINDS.find(kind), 1 if float(unit.flash) > 0 and not game.settings.reduced_effects else 0)
	else:
		game.draw_circle(point + Vector2(0, 6), 10, Color(0.05, 0.09, 0.08, 0.25))
		game.draw_texture_rect(textures[kind], body_rect(body_point, kind), false)
	if float(unit.hp) < float(unit.max_hp):
		var width := 36.0 if kind in ["captain", "siege", "matriarch"] else 18.0
		var top := body_point + Vector2(-width / 2, -36 if width == 36 else -25)
		game.draw_rect(Rect2(top, Vector2(width, 3)), game.INK)
		game.draw_rect(Rect2(top, Vector2(width * float(unit.hp) / float(unit.max_hp), 3)), game.MINT if friendly else game.RED)
