extends "res://scripts/save_files.gd"
## Recovery-only checked removal; the ordinary writer boundary stays unchanged.
func remove(path: String) -> bool:
	return not exists(path) or (DirAccess.remove_absolute(path)==OK and not exists(path))
