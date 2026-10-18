extends RefCounted
func available() -> bool:
	return DisplayServer.get_name() != "headless"
func put(text: String) -> bool:
	if not available(): return false
	DisplayServer.clipboard_set(text)
	return true
func get_text() -> String:
	return DisplayServer.clipboard_get() if available() else ""
