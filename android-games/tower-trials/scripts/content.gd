extends RefCounted
## Version 1 is immutable: existing saves always replay the original definitions.
const VERSION := 1
const V1 = preload("res://scripts/catalog_v1.gd")

static func levels(version: int = VERSION) -> Array:
	return V1.levels() if version == 1 else []

static func by_id(id: String, version: int = VERSION) -> Dictionary:
	for level in levels(version):
		if level.id == id:
			return level
	return {}
