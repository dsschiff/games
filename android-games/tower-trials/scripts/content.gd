extends RefCounted
## Version 1 is immutable: existing saves always replay the original definitions.
const VERSION := 2
const V1 = preload("res://scripts/catalog_v1.gd")
const V2 = preload("res://scripts/catalog_v2.gd")
static var catalog_cache: Dictionary = {}

static func levels(version: int = VERSION) -> Array:
	if not catalog_cache.has(version):
		catalog_cache[version] = V1.levels() if version == 1 else (V2.levels() if version == 2 else [])
	# Definitions are immutable. Rules only duplicate the small mutable run state.
	return catalog_cache[version]

static func by_id(id: String, version: int = VERSION) -> Dictionary:
	for level in levels(version):
		if level.id == id:
			return level
	return {}

static func index_of(id: String) -> int:
	var all := levels()
	for i in all.size():
		if all[i].id == id:
			return i
	return -1

static func unlocked(index: int, profile: Dictionary) -> bool:
	var all := levels()
	for prior in index:
		if not profile.has(all[prior].id):
			return false
	return true
