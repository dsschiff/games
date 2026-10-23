extends RefCounted
## Opaque transport envelope. Only the owning game's decoder decides save validity.
const MAX_BYTES := 2900000
const FORMAT := 1

static func encode(package_id: String, save_text: String, decoder: Callable) -> Dictionary:
	if package_id.is_empty() or save_text.to_utf8_buffer().size() > MAX_BYTES or not decoder.is_valid():
		return {"ok": false}
	var decoded: Variant = decoder.call(save_text)
	if not decoded is Dictionary or decoded.get("ok") != true:
		return {"ok": false}
	var text := JSON.stringify({"format": FORMAT, "package": package_id, "save": save_text, "sha256": save_text.sha256_text()})
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return {"ok": false}
	return {"ok": true, "text": text, "sha256": text.sha256_text()}

static func decode(package_id: String, text: String, decoder: Callable) -> Dictionary:
	if package_id.is_empty() or text.to_utf8_buffer().size() > MAX_BYTES or not decoder.is_valid():
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {"ok": false}
	var packet: Dictionary = parser.data
	if packet.get("format") != FORMAT or packet.get("package") != package_id or not packet.get("save") is String or not packet.get("sha256") is String:
		return {"ok": false}
	var save_text: String = packet.save
	if save_text.sha256_text() != packet.sha256:
		return {"ok": false}
	var decoded: Variant = decoder.call(save_text)
	if not decoded is Dictionary or decoded.get("ok") != true:
		return {"ok": false}
	# Revision numbers are device-local and are deliberately not ranked here.
	return {"ok": true, "save": save_text, "decoded": decoded, "sha256": text.sha256_text()}
