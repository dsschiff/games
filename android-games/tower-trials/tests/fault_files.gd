extends RefCounted
## Fault-injection backend only; normal app-save tests use the real filesystem.
var files: Dictionary = {}
var times: Dictionary = {}
var fail_suffix := ""
var fail_mode := ""
var write_count := 0
var written_paths: Array[String] = []
var rename_count := 0
var rename_replacement := ""

func exists(path: String) -> bool:
	return files.has(path)

func read_text(path: String) -> String:
	return str(files.get(path, ""))

func modified(path: String) -> int:
	return int(times.get(path, 0))

func write_text(path: String, source: String) -> bool:
	write_count += 1
	written_paths.append(path)
	if fail_suffix != "" and path.ends_with(fail_suffix):
		if fail_mode == "write":
			files[path] = source.left(10)
			return false
		if fail_mode == "flush":
			files[path] = source
			return false
		if fail_mode == "readback":
			files[path] = source.left(10)
			return true
	files[path] = source
	times[path] = write_count
	return true

func rename(from: String, to: String) -> bool:
	rename_count += 1
	if fail_mode == "rename" and from.ends_with(fail_suffix):
		return false
	if fail_mode in ["rename_missing", "rename_corrupt", "rename_wrong_valid"] and from.ends_with(fail_suffix):
		files.erase(from)
		times.erase(from)
		if fail_mode == "rename_missing": files.erase(to)
		else: files[to] = "{" if fail_mode == "rename_corrupt" else rename_replacement
		return true
	files[to] = files[from]
	times[to] = times.get(from, write_count)
	files.erase(from)
	times.erase(from)
	return true
