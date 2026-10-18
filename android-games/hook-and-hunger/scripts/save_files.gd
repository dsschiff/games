extends RefCounted

func exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func read_text(path: String) -> String:
	if FileAccess.get_file_as_bytes(path).size() > 60000:
		return ""
	return FileAccess.get_file_as_string(path)

func write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var okay := file.get_error() == OK
	file.close()
	return okay

func rename(from: String, to: String) -> bool:
	return DirAccess.rename_absolute(from, to) == OK
