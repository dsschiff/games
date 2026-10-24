extends RefCounted
var files := {}
var fail_write := false
var fail_rename := false
var missing_destination := false
var corrupt_destination := false
var wrong_destination := false
var replacement_text := ""

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
	var source: String = files[from]
	files.erase(from)
	files.erase(to)
	if not missing_destination:
		files[to] = "torn destination" if corrupt_destination else replacement_text if wrong_destination else source
	return true

func remove(path: String) -> bool:
	files.erase(path)
	return true
