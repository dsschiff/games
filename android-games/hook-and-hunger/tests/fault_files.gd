extends RefCounted
var files := {}
var fail_write := false
var fail_rename := false

func exists(path: String) -> bool:
	return files.has(path)

func read_text(path: String) -> String:
	return str(files.get(path, ""))

func write_text(path: String, source: String) -> bool:
	files[path] = source.substr(0, 13) if fail_write else source
	return not fail_write

func rename(from: String, to: String) -> bool:
	if fail_rename:
		return false
	files[to] = files[from]
	files.erase(from)
	return true
