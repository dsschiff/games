extends RefCounted

func exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	return file.get_error() == OK

func rename(from: String, to: String) -> bool:
	# Only the older slot is replaced; the newest checked candidate stays intact.
	if FileAccess.file_exists(to) and DirAccess.remove_absolute(to) != OK:
		return false
	return DirAccess.rename_absolute(from, to) == OK

func remove(path: String) -> bool:
	return not exists(path) or (DirAccess.remove_absolute(path) == OK and not exists(path))
