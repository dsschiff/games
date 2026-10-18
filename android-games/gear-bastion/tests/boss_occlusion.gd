extends SceneTree
## CPU projection/material/reset checks using genuine retained dense boss starts.
const Foundry = preload("res://scripts/presentation/foundry.gd")
const Layout = preload("res://scripts/window_layout.gd")
const Saves = preload("res://scripts/save_store.gd")
var checks := 0
var failures: Array[String] = []
var result_path := ""
var sources: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="): result_path=arg.trim_prefix("--run-dir=")+"/occlusion-data.json"
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail);push_error(detail)

func run() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var world := Foundry.new();viewport.add_child(world)
	var layout := Layout.new();layout.arrange(Vector2(600,1400));world.build(layout,Vector2(600,1400))
	for entry in [["captain","motion-prepare-captain-20261018T162415737581Z"],["siege","motion-prepare-siege-20261018T162713093079Z"]]:
		var path: String="res://.artifacts/graphics-production/"+str(entry[1])+"/slots/bastion-save.json"
		var decoded := Saves.decode(FileAccess.get_file_as_string(path))
		check(decoded.ok,"Genuine dense starting save decodes")
		if not decoded.ok: continue
		sources.append({"path":path,"sha256":FileAccess.get_sha256(path)})
		for dimensions in [Vector2(600,1400),Vector2(984,1092),Vector2(1092,984),Vector2(600,1066)]:
			layout.arrange(dimensions);viewport.size=Vector2i(dimensions);world.fit(layout,dimensions)
			var state: Dictionary=decoded.state.duplicate(true)
			var before:=state.duplicate(true)
			world.hydrate(state,true)
			var boss: Node3D
			var faded := 0
			var solid := 0
			for actor in world.actors.values():
				if actor.role==entry[0]: boss=actor
				if actor.friendly:
					if actor.boss_occluded: faded+=1
					else: solid+=1
			check(boss!=null and faded>0 and solid>0,"Dense actual boss overlap fades only a local subset of friendlies")
			if boss==null: continue
			var box: Rect2=world.projected_bounds(boss.model)
			check(not box.intersects(layout.summary) and not box.intersects(layout.boss_status()),"Actual boss mesh clears HUD at unchanged scale")
			for scenic in world.scenic_nodes:
				check(not box.intersects(world.projected_bounds(scenic)),"Actual boss mesh clears scenic silhouettes")
			check(boss.scale==Vector3.ONE and boss.model.transform==Transform3D.IDENTITY,"Boss root and authored model scale/grounding remain unchanged")
			var data: Dictionary=world.adapter.current["enemy:"+str(int(state.enemies.filter(func(unit): return unit.kind==entry[0])[0].id))]
			check(boss.position.distance_to(world.point_for(data))<.00001,"Boss retains exact projected logical foot position")
			var health: Dictionary={}
			for key in world.actors:
				health[key]=world.actors[key].health.visible
			world.update_boss_occlusion()
			for key in health:
				var actor: Node3D=world.actors[key]
				check(actor.health.visible==health[key] and actor.health.visible==(actor.health_requested_visible and not actor.health_occluded and actor.death_time<0),"Only health bars crossing boss equipment are suppressed; others keep current health")
			boss.fire(boss.position+Vector3(3,0,2))
			var expected: Vector3=boss.rig.global_transform*boss.rig.get_bone_global_pose(boss.bones.Weapon)*boss.muzzle.position
			check(expected.distance_to(boss.muzzle.global_position)<.00001,"Same-call weapon contact remains exact")
			check(state==before,"Occlusion does not mutate saved state or RNG")
			state.enemies=[];world.sync(state,[])
			check(world.corpses.size()>0,"Boss defeat retains ordinary corpse lifetime")
			world.step(1,false,false)
			var restored := true
			for actor in world.actors.values():
				if actor.friendly: restored=restored and not actor.boss_occluded and not actor.health_occluded
			check(restored,"After boss removal all remaining friendlies return to normal materials")
	var file:=FileAccess.open(result_path,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"scope":"CPU genuine-state projection, localized material treatment, grounding, same-call contact and restoration; no visible-readability claim"},"\t"));file.close()
	viewport.free();print("BOSS_OCCLUSION: %d checks, %d failures" % [checks,failures.size()]);print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL");quit(0 if failures.is_empty() else 1)
