extends RefCounted
var files := {}
var fail_write := false
var fail_rename := false
var corrupt_readback := false
var missing_destination := false
var corrupt_destination := false

func exists(path: String) -> bool:
	return files.has(path)

func read_text(path: String) -> String:
	return "broken" if corrupt_readback and path.ends_with(".tmp") else str(files.get(path, ""))

func write_text(path: String, text: String) -> bool:
	files[path] = text.substr(0, 13) if fail_write else text
	return not fail_write

func rename(from: String, to: String) -> bool:
	if fail_rename:
		return false
	files.erase(to)
	if not missing_destination:
		files[to] = "torn destination" if corrupt_destination else files[from]
	files.erase(from)
	return true
