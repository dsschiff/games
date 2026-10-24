extends RefCounted
func available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
func put(text: String) -> bool:
	if not available(): return false
	DisplayServer.clipboard_set(text)
	return true
func get_text() -> String:
	return DisplayServer.clipboard_get() if available() else ""
