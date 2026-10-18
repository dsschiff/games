extends SceneTree
## Actual owner/viewport destruction; weak references detect retained resources.
const Foundry = preload("res://scripts/presentation/foundry.gd")
const Actor = preload("res://scripts/presentation/actor.gd")
var checks := 0
var failures: Array[String] = []
var result_path := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir=" ):
			result_path=arg.trim_prefix("--run-dir=")+"/cache-data.json"
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error(detail)

func owner(viewport: SubViewport, region: Rect2) -> Node3D:
	var world := Foundry.new()
	viewport.add_child(world)
	Actor.set_occlusion_region(viewport.get_instance_id(),region)
	var actor: Node3D=world.acquire_actor("guard",true,0)
	actor.set_boss_occluded(true)
	return world

func snapshot(viewport_id: int) -> Dictionary:
	var result: Dictionary={}
	for key in Actor.occlusion_materials:
		var entry: Dictionary=Actor.occlusion_materials[key]
		if entry.viewport==viewport_id:
			result[key]={"material_id":entry.material.get_instance_id(),"center":entry.material.get_shader_parameter("boss_center"),"radius":entry.material.get_shader_parameter("boss_radius")}
	return result

func material_refs(viewport_id: int) -> Array[WeakRef]:
	var result: Array[WeakRef]=[]
	for entry in Actor.occlusion_materials.values():
		if entry.viewport==viewport_id: result.append(weakref(entry.material))
	return result

func all_released(refs: Array[WeakRef]) -> bool:
	for reference in refs:
		if reference.get_ref()!=null: return false
	return true

func run() -> void:
	var first := SubViewport.new()
	var second := SubViewport.new()
	first.own_world_3d=true;second.own_world_3d=true
	first.render_target_update_mode=SubViewport.UPDATE_DISABLED
	second.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(first);root.add_child(second)
	var first_id := first.get_instance_id()
	var second_id := second.get_instance_id()
	var first_world := owner(first,Rect2(.2,.1,.1,.15))
	var second_region := Rect2(.6,.4,.2,.1)
	var second_world := owner(second,second_region)
	var first_refs := material_refs(first_id)
	var second_refs := material_refs(second_id)
	var second_snapshot := snapshot(second_id)
	check(first_world.occlusion_viewport_id==first_id and second_world.occlusion_viewport_id==second_id,"Owning Foundries retain their actual viewport identities")
	check(not first_refs.is_empty() and not second_refs.is_empty() and Actor.occlusion_regions.has(first_id) and Actor.occlusion_regions.has(second_id),"Both actual viewports populate distinct material/region caches")
	first.free()
	check(snapshot(first_id).is_empty() and not Actor.occlusion_regions.has(first_id),"Actual viewport destruction releases only its cache entries")
	check(all_released(first_refs),"Destroyed viewport's ShaderMaterial resources lose all strong owners")
	check(second.is_inside_tree() and snapshot(second_id)==second_snapshot and Actor.occlusion_regions[second_id]==second_region,"Other live viewport retains exact material instances, uniforms and region")
	check(not all_released(second_refs),"Other live viewport's ShaderMaterials remain alive")
	Actor.release_occlusion_viewport(first_id)
	check(snapshot(second_id)==second_snapshot,"Repeated release is harmless to other live viewport")
	second_world.free()
	check(second.is_inside_tree() and snapshot(second_id).is_empty() and not Actor.occlusion_regions.has(second_id),"Actual Foundry teardown releases cache while its viewport survives")
	check(all_released(second_refs),"Owner teardown releases its actual ShaderMaterials")
	var replacement_region := Rect2(.1,.7,.15,.2)
	var replacement := owner(second,replacement_region)
	var replacement_refs := material_refs(second_id)
	check(replacement.occlusion_viewport_id==second_id and not replacement_refs.is_empty() and Actor.occlusion_regions[second_id]==replacement_region,"Replacement owner initializes fresh cache without stale region")
	check(snapshot(second_id)!=second_snapshot,"Replacement creates fresh ShaderMaterial instances")
	second.free()
	check(snapshot(second_id).is_empty() and not Actor.occlusion_regions.has(second_id) and all_released(replacement_refs),"Replacement viewport destruction releases its resources too")
	var file := FileAccess.open(result_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"CPU actual viewport/Foundry create/free, weak-resource release, other-live-viewport identity/uniform preservation and replacement; no rendering"},"\t"));file.close()
	print("CACHE_LIFECYCLE: %d checks, %d failures" % [checks,failures.size()])
	print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
