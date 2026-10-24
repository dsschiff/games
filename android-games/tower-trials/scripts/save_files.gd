extends RefCounted
## Small filesystem boundary; fault-injection tests implement the same methods.

func exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func modified(path: String) -> int:
	return FileAccess.get_modified_time(path)

func write_text(path: String, source: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(source)
	var stored := file.get_error() == OK
	file.flush()
	var flushed := file.get_error() == OK
	file.close()
	return stored and flushed

func rename(from: String, to: String) -> bool:
	return DirAccess.rename_absolute(from, to) == OK

func remove(path: String) -> bool:
	return not exists(path) or (DirAccess.remove_absolute(path)==OK and not exists(path))
