extends SceneTree
## CPU fixtures verify actual object identity, reset geometry and routing.
const Foundry = preload("res://scripts/presentation/foundry.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
const Layout = preload("res://scripts/window_layout.gd")
const Battle = preload("res://scripts/battle_rules.gd")
const Policy = preload("res://tests/campaign_policies.gd")
var checks := 0
var failures: Array[String] = []
var result_path := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="): result_path=arg.trim_prefix("--run-dir=")+"/pool-data.json"
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error(detail)

func contact(actor: Node3D) -> void:
	var expected: Vector3=actor.rig.global_transform*actor.rig.get_bone_global_pose(actor.bones.Weapon)*actor.muzzle.position
	check(expected.distance_to(actor.muzzle.global_position)<.00001,"Reused actual contact socket matches the current weapon bone immediately")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(600,1400)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var world := Foundry.new()
	viewport.add_child(world)
	var layout := Layout.new()
	layout.arrange(Vector2(600,1400))
	world.build(layout,Vector2(600,1400))
	await process_frame
	var roles := ["guard","ranger","mortar","beetle","shell","skitter","spitter","swarm","carapace","captain","siege","matriarch"]
	for role in roles:
		var friendly: bool=role in ["guard","ranger","mortar"]
		var actor: Node3D=world.acquire_actor(role,friendly,.37)
		var identity := actor.get_instance_id()
		var rig_identity: int=actor.rig.get_instance_id()
		var model_identity: int=actor.model.get_instance_id()
		actor.fire(Vector3(8,0,-4));actor.hit();actor.death_time=.4
		actor.pose(.2,Vector3(1,0,0),true)
		actor.position=Vector3(11,3,-7);actor.scale=Vector3.ONE*2
		actor.model.hide();actor.rig.hide();actor.muzzle.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*3),Vector3(9,9,9))
		actor.health.position=Vector3(10,10,10);actor.health_fill.scale=Vector3(.1,2,3);actor.health.show()
		world.retire_actor(actor)
		check(not actor.visible and actor.process_mode==Node.PROCESS_MODE_DISABLED,"Retired "+role+" is inactive and hidden")
		actor=world.acquire_actor(role,friendly,.81)
		check(actor.get_instance_id()==identity and actor.rig.get_instance_id()==rig_identity and actor.model.get_instance_id()==model_identity,"Actual "+role+" actor, rig and model instances are reused")
		var fresh := Actor.new()
		world.add_child(fresh);fresh.configure(role,friendly,.81)
		check(actor.transform.is_equal_approx(fresh.transform) and actor.aim==fresh.aim and actor.gait==fresh.gait and actor.travel==0 and actor.fire_left==0 and actor.hit_left==0 and actor.death_time<0 and actor.torso_yaw==0,"Reused "+role+" resets world transform/facing/gait/contact/death/hit state")
		for i in actor.rest_nodes.size():
			var reused_node: Node3D=actor.rest_nodes[i].node
			var fresh_node: Node3D=fresh.rest_nodes[i].node
			check(reused_node.transform.is_equal_approx(fresh_node.transform) and reused_node.visible==fresh_node.visible,"Reused "+role+" resets authored child transform/visibility: "+str(reused_node.name))
		for i in actor.rig.get_bone_count():
			check(actor.rig.get_bone_pose(i).is_equal_approx(fresh.rig.get_bone_pose(i)),"Reused "+role+" resets actual joint pose")
		actor.set_health(100,100)
		check(not actor.health.visible and actor.health_fill.scale==Vector3.ONE,"Reused "+role+" does not retain old health-bar scale/visibility")
		actor.set_health(50,100)
		check(actor.health.visible and actor.health_fill.scale==Vector3(.5,1,1),"Reused "+role+" accepts current health")
		actor.fire(Vector3(-4,0,7));fresh.fire(Vector3(-4,0,7))
		contact(actor)
		check(actor.muzzle.global_position.distance_to(fresh.muzzle.global_position)<.00001,"Reused "+role+" fires from the same current contact as a fresh instance")
		fresh.free();world.retire_actor(actor)
	var ally: Node3D=world.acquire_actor("guard",true,0)
	var enemy: Node3D=world.acquire_actor("guard",false,0)
	check(ally.get_instance_id()!=enemy.get_instance_id() and ally.friendly and not enemy.friendly,"Role/side keys never mix opposing actor instances")
	world.retire_actor(ally);world.retire_actor(enemy)
	var burst: Array[Node3D]=[]
	for role in roles:
		for i in 16: burst.append(world.acquire_actor(role,role in ["guard","ranger","mortar"],0))
	for actor in burst: world.retire_actor(actor)
	check(world.inactive_count(world.actor_pool)==world.MAX_INACTIVE_ACTORS,"Inactive actor reserve saturates at the explicit global cap")
	for key in world.actor_pool:
		check(world.actor_pool[key].size()<=world.MAX_INACTIVE_PER_ROLE_SIDE,"Per-role/side inactive cap holds")
	world.pulse(Vector3(1,2,3),"f5d58c")
	var impact: MeshInstance3D=world.effects[0].node
	var impact_id := impact.get_instance_id()
	var mesh_id := impact.mesh.get_instance_id()
	impact.rotation=Vector3(1,2,3);impact.scale=Vector3(7,8,9)
	world.step(.2,false,false)
	check(not impact.visible and impact.transform==Transform3D.IDENTITY and impact.material_override==null,"Retired impact clears transform/material/visibility")
	world.pulse(Vector3(-1,4,8),"df906a")
	check(world.effects[0].node.get_instance_id()==impact_id and impact.mesh.get_instance_id()==mesh_id,"Impact node and compatible mesh resource actually reuse")
	check(impact.position==Vector3(-1,4,8) and impact.scale.is_equal_approx(Vector3.ONE*.1) and impact.rotation.is_zero_approx() and impact.visible and impact.material_override==world.mat("df906a"),"Reused impact uses only new point/color/scale/visibility")
	world.tracer(Vector3.ZERO,Vector3(0,0,-4),"ffe3a0")
	var tracer: MeshInstance3D=world.effects[-1].node
	var tracer_id := tracer.get_instance_id()
	check(tracer_id!=impact_id,"Tracer reserve is distinct from active impact")
	world.step(.2,false,false)
	world.tracer(Vector3(3,2,1),Vector3(3,2,9),"c5b56c")
	check(world.effects[-1].node.get_instance_id()==tracer_id and tracer.mesh.get_instance_id()==mesh_id,"Tracer instance and unit geometry actually reuse")
	check(tracer.position==Vector3(3,2,5) and tracer.scale.is_equal_approx(Vector3(.025,.025,8)) and (-tracer.basis.z.normalized()).dot(Vector3.BACK)>.9999,"Reused tracer resets origin, orientation and exact endpoint length")
	world.step(.2,false,false)
	for i in 70: world.pulse(Vector3(i,0,0),"f5d58c")
	check(world.effects.size()==world.MAX_EFFECTS,"Active effects preserve original48-node cap")
	world.step(.2,false,false)
	check(world.effects.is_empty() and world.inactive_count(world.effect_pool)==world.MAX_INACTIVE_EFFECTS,"Expired effects saturate bounded inactive reserve")
	var state := Battle.initial(1701,"camp_05")
	Policy.apply(state,"A");Battle.start(state)
	state.units.append(Battle.make_unit(state,"guard",1,true))
	state.enemies.append(Battle.make_unit(state,"beetle",1,false))
	world.hydrate(state,true)
	var old_key := "ally:"+str(int(state.units[0].id))
	var enemy_key := "enemy:"+str(int(state.enemies[0].id))
	var old_actor: Node3D=world.actors[old_key]
	var old_id := old_actor.get_instance_id()
	var epoch: int=world.adapter.epoch
	var event := {"kind":"hit","attack":"pool-integration","actor":old_key,"target":enemy_key,"role":"guard","from":[300,300],"to":[300,320]}
	var saved := state.duplicate(true)
	world.sync(state,[event,event]);world.sync(state,[event])
	check(world.attacks_emitted==1 and world.impacts_emitted==1,"Duplicate event batches still emit once with pooled instances")
	check(state==saved,"Pooling and presentation events do not mutate rules/seed/saved state")
	state.units.clear();world.sync(state,[])
	check(world.actor_for(old_key)==old_actor and world.corpses.has("%d:%s" % [epoch,old_key]),"Exact ID/epoch owns corpse until its ordinary expiry")
	world.step(1,false,false)
	check(world.actor_for(old_key)==null and not old_actor.visible,"Expired ID has no actor while its instance is reserved")
	state.units.append(Battle.make_unit(state,"guard",1,true));world.sync(state,[])
	var new_key := "ally:"+str(int(state.units[0].id))
	check(new_key!=old_key and world.actors[new_key].get_instance_id()==old_id and world.actor_for(old_key)==null,"A new exact ID borrows the retired instance without inheriting old identity")
	check(world.actors[new_key].fire_left==0 and world.actors[new_key].hit_left==0 and world.actors[new_key].death_time<0,"Natural corpse-to-live reuse carries no ghost hit/shot/death")
	var repeated := event.duplicate(true);repeated.actor=new_key
	world.sync(state,[repeated])
	check(world.attacks_emitted==1,"Object reuse does not clear attempt dedupe")
	world.hydrate(state,true)
	check(world.adapter.epoch>epoch and world.effects.is_empty() and world.corpses.is_empty() and world.actors[new_key].get_instance_id()==old_id,"Attempt reset reuses nodes while clearing old transient namespace")
	world.sync(state,[repeated])
	check(world.attacks_emitted==2,"New epoch accepts a repeated attack token exactly once")
	contact(world.actors[new_key])
	world.fit(layout,Vector2(600,1400))
	check(world.effects.is_empty() and world.inactive_count(world.effect_pool)<=world.MAX_INACTIVE_EFFECTS,"Resize returns active effects to bounded reserve")
	var report := {"checks":checks,"failures":failures,"pool":world.pool_snapshot(),"scope":"CPU fixtures; actual node/model/rig/mesh identities, complete reset/contact, caps and typed-ID/epoch/dedupe invariants; no GPU quality/performance claim"}
	var file := FileAccess.open(result_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	viewport.free()
	print("POOLING: %d checks, %d failures" % [checks,failures.size()])
	print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
