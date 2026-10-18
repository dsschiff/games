extends RefCounted
## Observations only. No runtime hooks, simulation writes or RNG calls.
var actor_bindings := {}
var effect_seen := {}
var effect_previous := {}
var actor_rebindings: Array = []
var effect_reuses := 0
var frames: Array = []
var roles := {}
var regions := {}

func pool_sample(scene: Node) -> Dictionary:
	var view: Node = scene.presenter
	for key in view.units:
		var id: int = view.units[key].get_instance_id()
		if actor_bindings.has(id) and actor_bindings[id] != key:
			actor_rebindings.append({"instance": id, "from": actor_bindings[id], "to": key, "simulation": float(scene.state.time)})
		actor_bindings[id] = key
	var now := {}
	for effect in view.effects:
		var id: int = effect.node.get_instance_id()
		if effect_seen.has(id) and (not effect_previous.has(id) or effect.left > effect_previous[id] + .001):
			effect_reuses += 1
		effect_seen[id] = true
		now[id] = float(effect.left)
	effect_previous = now
	return {"actor_reserve": view.actor_pool.reserve_count, "effect_reserve": view.effect_pool.reserve_count,
		"actor_cross_id_reuses": actor_rebindings.size(), "effect_observed_reuses": effect_reuses}

func record_frame(scene: Node, frame: int) -> void:
	var view: Node = scene.presenter
	var camera: Camera3D = view.camera
	var viewport: Rect2 = scene.get_viewport().get_visible_rect()
	var actors: Dictionary = view.units.duplicate()
	for i in view.civilians.size():
		actors["citizen:" + str(i)] = view.civilians[i].actor
	for i in view.towers.size():
		if view.towers[i].operator != null:
			actors["tower:" + str(i)] = view.towers[i].operator
	for corpse in view.corpses:
		actors["retiring:" + str(corpse.node.get_instance_id())] = corpse.node
	var visible := {}
	for key in actors:
		var actor: Node3D = actors[key]
		if not actor.is_visible_in_tree() or camera.is_position_behind(actor.global_position):
			continue
		var bounds: AABB = actor.model.global_transform * (view.manifest["actor_" + actor.role] as AABB).grow(.15)
		var points: Array[Vector3] = []
		for corner in 8:
			points.append(bounds.get_endpoint(corner))
		var projected: Rect2 = view.projected_bounds(points)
		if not viewport.intersects(projected) or projected.size.x < 4 or projected.size.y < 8:
			continue
		if not visible.has(actor.role):
			visible[actor.role] = {"ids": [], "live_ids": [], "fully_inside": 0, "max_pixel_height": 0.0}
		visible[actor.role].ids.append(key)
		if not str(key).begins_with("retiring:"):
			visible[actor.role].live_ids.append(key)
		visible[actor.role].fully_inside += int(viewport.encloses(projected))
		visible[actor.role].max_pixel_height = maxf(visible[actor.role].max_pixel_height, projected.size.y)
	var region: int = scene.state.definition.region if scene.state.schema == 2 else -1
	regions[str(region)] = true
	for role in visible:
		if not roles.has(role):
			roles[role] = {"frames": 0, "active_frames": 0, "live_active_frames": 0, "fully_inside_frames": 0, "first_frame": frame, "last_frame": frame, "regions": {}}
		roles[role].frames += 1
		roles[role].active_frames += int(scene.state.phase == "playing" and not scene.paused)
		roles[role].live_active_frames += int(scene.state.phase == "playing" and not scene.paused and not visible[role].live_ids.is_empty())
		roles[role].fully_inside_frames += int(visible[role].fully_inside > 0)
		roles[role].last_frame = frame
		roles[role].regions[str(region)] = true
	frames.append({"frame": frame, "simulation": float(scene.state.time), "phase": str(scene.state.phase), "paused": scene.paused,
		"region": region, "models": visible, "attacks": view.attacks_emitted, "effects": view.effects.size(), "pools": pool_sample(scene)})

func report() -> Dictionary:
	return {"roles": roles, "regions": regions.keys(), "frames": frames, "actor_rebindings": actor_rebindings,
		"effect_observed_reuses": effect_reuses,
		"limits": "Projected rest-model bounds plus15cm margin identify possible onscreen models, not visible-pixel or motion acceptance. Corpus includes corpses/citizens/operators. Cross-ID actor reuse and observed effect lifetime transitions are lower bounds; shorter between-sample lifetimes can be missed. Independent actual playback must assess substantive exposure."}
