extends Node3D
const Adapter = preload("res://scripts/presentation/adapter.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const Gear = preload("res://scripts/gear_rules.gd")
var adapter := Adapter.new()
var camera: Camera3D
var layout: RefCounted
var canvas_size := Vector2(600, 1066)
var pixel_size := Vector2(600, 1066)
var actors: Dictionary = {}
var corpses: Dictionary = {}
var gears: Dictionary = {}
var scenery: Node3D
var connections: Node3D
var ground: MeshInstance3D
var effects: Array = []
var materials: Dictionary = {}
var board_key := ""
var region := 0
var presentation_time := 0.0
var reduced := false
var attacks_seen: Dictionary = {}
var attack_order: Array[String] = []
var attacks_emitted := 0
var impacts_emitted := 0
var wall_hit_left := 0.0
var arches: Array[Node3D] = []
var scenic_nodes: Array[Node3D] = []
var ghost: Node3D
var ghost_kind := ""

func build(game_layout: RefCounted, pixels: Vector2) -> void:
	layout = game_layout
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9ba993")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e1e7e0")
	env.ambient_light_energy = .38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = .86
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_color = Color("fff7e8")
	sun.light_energy = .62
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	sun.shadow_bias = .20
	sun.shadow_normal_bias = 2
	sun.shadow_opacity = .45
	sun.shadow_blur = 2
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 145, 0)
	fill.light_color = Color("d5e0df")
	fill.light_energy = .20
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = .1
	camera.far = 180
	camera.position = Vector3(0, 42, 42)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	scenery = Node3D.new()
	add_child(scenery)
	connections = Node3D.new()
	add_child(connections)
	ground = box(self, Vector3(0, -.25, 0), Vector3(160, .45, 180), "a4ac83")
	fit(game_layout, pixels)

func mat(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		materials[color] = Actor.material(Color(color))
	return materials[color]

func box(parent: Node3D, point: Vector3, dimensions: Vector3, color: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	node.position = point
	parent.add_child(node)
	return node

func asset(id: String, parent: Node3D, point: Vector3) -> Node3D:
	var node := (load("res://art/models/" + id + ".glb") as PackedScene).instantiate() as Node3D
	Actor.finish_materials(node)
	parent.add_child(node)
	node.position = point
	return node

func canvas_to_world(point: Vector2, height: float = 0) -> Vector3:
	var pixel := point * pixel_size / canvas_size
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	return origin + direction * ((height - origin.y) / direction.y)

func world_to_canvas(point: Vector3) -> Vector2:
	return camera.unproject_position(point) * canvas_size / pixel_size

func fit(game_layout: RefCounted, pixels: Vector2) -> void:
	layout = game_layout
	canvas_size = layout.size
	pixel_size = pixels
	camera.size = canvas_size.y / 40.0
	if region > 0:
		rebuild_scenery(region)
		board_key = ""
	for key in actors:
		if adapter.current.has(key):
			actors[key].position = point_for(adapter.current[key])
	# Existing corpses/effects remain at their projected positions on a resize.
	for key in corpses:
		corpses[key].node.position = canvas_to_world(corpses[key].canvas)
	for effect in effects:
		effect.node.queue_free()
	effects.clear()

func rebuild_scenery(act: int) -> void:
	for child in scenery.get_children():
		child.free()
	arches.clear()
	scenic_nodes.clear()
	region = act
	ground.material_override = mat(["a4a18a", "a38e7d", "9da5a3"][act-1])
	var field: Rect2 = layout.field
	for side in [-1, 1]:
		for i in 2:
			var y := field.position.y + field.size.y * (.28 if i == 0 else .72)
			place_scenic("workshop",side,y,1.05,-side*.18)
			place_scenic("region_"+str(act),side,y+65,.65,side*.35+i*.8)
	# A connected brass deck beneath the power board, with depth and an open route
	# through all three arches; it is part of the same ground/camera composition.
	var board: Rect2 = layout.board
	asset("foundry_deck",scenery,canvas_to_world(board.get_center(),.24))
	for lane in 3:
		var gate_point := Vector2(layout.gate_x(lane), layout.wall.end.y)
		var arch := asset("arch", scenery, canvas_to_world(gate_point))
		arches.append(arch)
		var gate_start: float = layout.gate_x(lane)-48
		var gate_end: float = layout.gate_x(lane)+48
		var left: float = 0.0 if lane == 0 else layout.gate_x(lane-1)+48
		var right: float = canvas_size.x if lane == 2 else gate_end
		for x in range(int(left), int(gate_start), 38):
			var wall := asset("wall", scenery, canvas_to_world(Vector2(x+18, layout.wall.end.y)))
			wall.scale.x = .95
		if lane == 2:
			for x in range(int(gate_end), int(right), 38):
				asset("wall", scenery, canvas_to_world(Vector2(x+18, layout.wall.end.y)))
	var groups: Array = [[],[],[]]
	var clusters: Array[Vector2] = [Vector2(layout.field_x(145),field.position.y+field.size.y*.30),Vector2(layout.field_x(440),field.position.y+field.size.y*.45),Vector2(layout.field_x(275),field.position.y+field.size.y*.72)]
	var patches: Array[Transform3D] = []
	for i in clusters.size():
		patches.append(Transform3D(Basis(Vector3.UP,i*.7),canvas_to_world(clusters[i])))
	batch_asset("courtyard_patch",patches)
	for row in maxi(3,int(field.size.y/44)):
		for column in maxi(2,int((canvas_size.x-160)/54)):
			var ordinal: int = row*37+column*17
			var point := Vector2(90+column*54+(12 if row%2==0 else 0)+sin(ordinal)*2,field.position.y+65+row*44+cos(ordinal)*2)
			if point.y > layout.wall.position.y-8 or point.x > canvas_size.x-80:
				continue
			var near: bool = point.y > layout.wall.position.y-95
			for center in clusters:
				near = near or Vector2((point.x-center.x)/95,(point.y-center.y)/85).length_squared() < 1
			if not near or ordinal%5==0:
				continue
			groups[ordinal%3].append(Transform3D(Basis(Vector3.UP,sin(ordinal*1.17)*.20),canvas_to_world(point)))
	for i in 3:
		var paving: Array[Transform3D] = []
		paving.assign(groups[i])
		batch_asset(["paver","paver_broken","paver_long"][i],paving)

func projected_bounds(node: Node3D) -> Rect2:
	var points: Array[Vector2] = []
	collect_projected(node,points)
	if points.is_empty():
		return Rect2(world_to_canvas(node.global_position),Vector2.ZERO)
	var rect := Rect2(points[0],Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect

func collect_projected(node: Node3D, points: Array[Vector2]) -> void:
	if node is MeshInstance3D:
		var bounds: AABB = node.mesh.get_aabb()
		for corner in 8:
			points.append(world_to_canvas(node.global_transform*bounds.get_endpoint(corner)))
	for child in node.get_children():
		if child is Node3D:
			collect_projected(child,points)

func place_scenic(id: String, side: int, y: float, model_scale: float, angle: float) -> void:
	# 70 logical pixels conservatively encloses the largest rotating boss kit;
	# retain a further five-pixel gap beyond that body corridor.
	var limit: float = layout.field_x(44)-75
	var frame := Rect2(6 if side < 0 else canvas_size.x-limit,layout.field.position.y+60,limit-6,layout.field.size.y-80)
	var node := asset(id,scenery,canvas_to_world(Vector2(frame.get_center().x,y)))
	node.rotation.y = angle
	node.scale = Vector3.ONE * model_scale
	var bounds := projected_bounds(node)
	node.scale *= minf(1,minf(frame.size.x/maxf(1,bounds.size.x),frame.size.y/maxf(1,bounds.size.y)))
	bounds = projected_bounds(node)
	var center := Vector2(frame.get_center().x,clampf(y,frame.position.y+bounds.size.y/2,frame.end.y-bounds.size.y/2))
	node.position = canvas_to_world(world_to_canvas(node.position)+center-bounds.get_center())
	scenic_nodes.append(node)

func batch_asset(id: String, transforms: Array[Transform3D]) -> void:
	# Repeated ground sculpture uses one MultiMesh per authored material group.
	# It is walkable flush paving, with no runtime collision or rule geometry.
	var source := (load("res://art/models/"+id+".glb") as PackedScene).instantiate() as Node3D
	Actor.finish_materials(source)
	batch_meshes(source,Transform3D.IDENTITY,transforms)
	source.free()

func batch_meshes(source: Node3D, inherited: Transform3D, transforms: Array[Transform3D]) -> void:
	var local := inherited * source.transform
	if source is MeshInstance3D:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var mesh := source.mesh.duplicate() as ArrayMesh
		for surface in mesh.get_surface_count():
			mesh.surface_set_material(surface,source.get_surface_override_material(surface))
		multi.mesh = mesh
		multi.instance_count = transforms.size()
		for i in transforms.size():
			multi.set_instance_transform(i,transforms[i]*local)
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scenery.add_child(node)
	for child in source.get_children():
		if child is Node3D:
			batch_meshes(child,local,transforms)

func point_for(data: Dictionary) -> Vector3:
	var canvas: Vector2 = layout.field_point(data.point)
	var height := 0.0
	if float(data.deploy_left) > 0:
		var start: Vector2 = layout.board.position + Vector2(data.deploy_x+.5, data.deploy_y+.5) * 80
		# Travel up the board's clear central footprint, then branch in the corridor
		# above the side controls. Troops never disappear beneath an opaque HUD row.
		var bend := Vector2(start.x, layout.wall.end.y + 28)
		var gate := Vector2(layout.gate_x(int(data.lane)), bend.y)
		var progress := clampf(1.0 - data.deploy_left / data.deploy_total, 0, 1)
		if progress < .5:
			canvas = start.lerp(bend, progress/.5)
		elif progress < .75:
			canvas = bend.lerp(gate, (progress-.5)/.25)
		else:
			canvas = gate.lerp(canvas, (progress-.75)/.25)
		height = .24 * clampf((canvas.y-(layout.board.position.y-16))/32,0,1)
	return canvas_to_world(canvas,height)

func hydrate(state: Dictionary, held: bool) -> void:
	adapter.reset(state, held)
	presentation_time = 0
	for key in actors:
		actors[key].free()
	actors.clear()
	for key in corpses:
		corpses[key].node.free()
	corpses.clear()
	for effect in effects:
		effect.node.free()
	effects.clear()
	attacks_seen.clear()
	attack_order.clear()
	wall_hit_left = 0
	board_key = ""
	if is_instance_valid(ghost):
		ghost.hide()
	sync(state, [])

func sync(state: Dictionary, events: Array, interval: float = 1.0/30.0) -> void:
	if float(state.time) < adapter.last_time:
		hydrate(state, adapter.paused)
		return
	adapter.ingest(state, interval)
	var act: int = state.config.get("act", 1)
	if act != region:
		rebuild_scenery(act)
		sync_board(state, true)
	else:
		sync_board(state)
	for key in adapter.current:
		var data: Dictionary = adapter.current[key]
		if not actors.has(key):
			var actor := Actor.new()
			add_child(actor)
			actor.configure(data.role, data.friendly, float(absi(key.hash()) % 100) * .11)
			actor.position = point_for(data)
			actors[key] = actor
		actors[key].set_health(data.hp, data.max_hp)
	for key in actors.keys():
		if not adapter.current.has(key):
			var actor: Node3D = actors[key]
			actor.death_time = 0
			corpses["%d:%s" % [adapter.epoch,key]] = {"node":actor,"left":.9,"canvas":world_to_canvas(actor.position)}
			actors.erase(key)
	for event in events:
		if adapter.accept(event):
			present_event(event)

func sync_board(state: Dictionary, force: bool = false) -> void:
	var signature := JSON.stringify(state.board)
	if not force and signature == board_key:
		return
	board_key = signature
	for key in gears:
		gears[key].root.free()
	gears.clear()
	for child in connections.get_children():
		child.free()
	var powered := Gear.powered(state.board)
	for y in 4:
		for x in 5:
			if Gear.cell_allowed(x,y,str(state.encounter),state.config):
				continue
			var point := canvas_to_world(layout.board.position + Vector2(x+.5,y+.5)*80,.24)+Vector3(0,.025,0)
			for angle in [-.7,.7]:
				var bar := box(connections,point,Vector3(.12,.05,.62),"78685c")
				bar.rotation.y = angle
	for piece in state.board:
		var center: Vector2 = layout.board.position + Vector2(piece.x+.5,piece.y+.5)*80
		var root := Node3D.new()
		add_child(root)
		root.position = canvas_to_world(center,.24)
		var rotor := asset("core" if piece.kind == "core" else "drive",root,Vector3.ZERO)
		var generator_rig: Skeleton3D
		if piece.kind in Gear.BASE_RATES:
			generator_rig = Actor.find_skeleton(asset("generator_"+str(piece.kind),root,Vector3(0,.26,0)))
		gears[int(piece.id)] = {"root":root,"rotor":rotor,"generator_rig":generator_rig,"powered":powered.has(int(piece.id)),"direction":1 if (int(piece.x)+int(piece.y))%2 == 0 else -1,"point":center,"kind":str(piece.kind)}
	for piece in state.board:
		for other in state.board:
			if int(other.id) <= int(piece.id) or not powered.has(int(piece.id)) or not powered.has(int(other.id)) or absi(int(piece.x)-int(other.x))+absi(int(piece.y)-int(other.y)) != 1:
				continue
			var a: Vector3 = gears[int(piece.id)].root.position + Vector3(0,.06,0)
			var b: Vector3 = gears[int(other.id)].root.position + Vector3(0,.06,0)
			var link := box(connections,(a+b)/2,Vector3(.10,.10,a.distance_to(b)),"76c6a2")
			link.look_at(b)

func drag_preview(point: Vector2, piece: Dictionary, showing: bool) -> void:
	if not showing or piece.is_empty():
		if is_instance_valid(ghost):
			ghost.hide()
		return
	var kind: String = piece.kind
	if not is_instance_valid(ghost) or ghost_kind != kind:
		if is_instance_valid(ghost):
			ghost.free()
		ghost = Node3D.new()
		add_child(ghost)
		ghost_kind = kind
		asset("core" if kind == "core" else "drive",ghost,Vector3.ZERO)
		if kind in Gear.BASE_RATES:
			asset("generator_"+kind,ghost,Vector3(0,.26,0))
	ghost.show()
	ghost.position = canvas_to_world(point,.30)

func actor_for(key: String) -> Node3D:
	if actors.has(key):
		return actors[key]
	var dead_key := "%d:%s" % [adapter.epoch,key]
	return corpses[dead_key].node if corpses.has(dead_key) else null

func present_event(event: Dictionary) -> void:
	var attack := "%d:%s" % [adapter.epoch,event.attack]
	var destination := canvas_to_world(layout.field_point(Vector2(event.to[0],event.to[1]))) + Vector3(0,.45,0)
	var shooter := actor_for(event.actor)
	if not attacks_seen.has(attack):
		attacks_seen[attack] = true
		attack_order.append(attack)
		if attack_order.size() > 512:
			attacks_seen.erase(attack_order.pop_front())
		attacks_emitted += 1
		if shooter != null:
			shooter.fire(destination)
			if event.role in ["ranger","mortar","spitter","siege"]:
				tracer(shooter.muzzle.global_position,destination,"ffe3a0" if event.actor.begins_with("ally:") else "c5b56c")
	var victim := actor_for(event.target)
	if victim != null:
		victim.hit()
	if event.target == "wall":
		wall_hit_left = .25
	impacts_emitted += 1
	if not reduced:
		pulse(destination,"f5d58c" if event.actor.begins_with("ally:") else "df906a")

func tracer(from: Vector3, to: Vector3, color: String) -> void:
	if effects.size() >= 48 or from.distance_squared_to(to) < .001:
		return
	var node := box(self,(from+to)/2,Vector3(.025,.025,from.distance_to(to)),color)
	node.look_at(to)
	effects.append({"node":node,"left":.055})

func pulse(point: Vector3, color: String) -> void:
	if effects.size() >= 48:
		return
	var node := box(self,point,Vector3(.10,.10,.10),color)
	effects.append({"node":node,"left":.12})

func step(dt: float, held: bool, calm: bool) -> void:
	adapter.paused = held
	reduced = calm
	if held:
		return
	presentation_time += dt
	var alpha := adapter.advance(dt)
	for key in actors:
		var current: Dictionary = adapter.current[key]
		var previous: Dictionary = adapter.previous.get(key,current)
		var from := point_for(previous)
		var to := point_for(current)
		var velocity := (to-from)/adapter.interval if adapter.phase == "battle" else Vector3.ZERO
		actors[key].position = from.lerp(to,alpha)
		actors[key].pose(dt,velocity,adapter.phase == "victory" and current.friendly)
	for key in corpses.keys():
		corpses[key].node.pose(dt,Vector3.ZERO,false)
		corpses[key].left -= dt
		if corpses[key].left <= 0:
			corpses[key].node.queue_free()
			corpses.erase(key)
	for key in gears:
		if gears[key].powered:
			gears[key].rotor.rotation.y = presentation_time * .55 * int(gears[key].direction)
			var rig: Skeleton3D = gears[key].generator_rig
			if rig != null:
				for side in ["L","R"]:
					var piston := rig.find_bone("Piston"+side)
					rig.set_bone_pose_position(piston,Vector3(0,sin(presentation_time*5+key*.6+(0 if side=="L" else PI))*.07,0))
	for i in range(effects.size()-1,-1,-1):
		effects[i].left -= dt
		if effects[i].left <= 0:
			effects[i].node.queue_free()
			effects.remove_at(i)
	wall_hit_left = maxf(0,wall_hit_left-dt)
	for arch in arches:
		arch.rotation.z = sin(PI*wall_hit_left/.25)*.015 if not calm else 0.0
