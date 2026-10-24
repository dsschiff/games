extends RefCounted
## Game decoder and native wire validation around the byte-identical vendored codec.
const Store = preload("res://scripts/save_store.gd")
const PACKAGE := "com.dsschiff.frontlinefoundry"
const Codec = preload("res://scripts/cloud/codec.gd")
const MAX_BYTES: int = Codec.MAX_BYTES

static func encode(save_text: String) -> Dictionary:
	return Codec.encode(PACKAGE,save_text,Store.decode)

static func decode(text: String) -> Dictionary:
	return Codec.decode(PACKAGE,text,Store.decode)

static func snapshot(packet: Dictionary) -> Dictionary:
	if not packet.get("data") is String or not packet.get("sha256") is String: return {"ok":false}
	if packet.sha256.length() != 64 or not packet.sha256.is_valid_hex_number(false): return {"ok":false}
	var encoded: String = packet.data
	if encoded.length() > ((MAX_BYTES+2)/3)*4 or encoded.length()%4 != 0: return {"ok":false}
	var expression := RegEx.new()
	expression.compile("^[A-Za-z0-9+/]*={0,2}$")
	if expression.search(encoded) == null: return {"ok":false}
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.size() > MAX_BYTES or not utf8_valid(bytes): return {"ok":false}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	if hash.finish().hex_encode() != packet.sha256: return {"ok":false}
	return decode(bytes.get_string_from_utf8())

static func utf8_valid(bytes: PackedByteArray) -> bool:
	var i := 0
	while i < bytes.size():
		var first := int(bytes[i]); var count := 0; var low := 0x80; var high := 0xbf
		if first < 0x80: i += 1; continue
		if first >= 0xc2 and first <= 0xdf: count = 1
		elif first >= 0xe0 and first <= 0xef:
			count = 2
			if first == 0xe0: low = 0xa0
			if first == 0xed: high = 0x9f
		elif first >= 0xf0 and first <= 0xf4:
			count = 3
			if first == 0xf0: low = 0x90
			if first == 0xf4: high = 0x8f
		else: return false
		if i + count >= bytes.size() or bytes[i+1] < low or bytes[i+1] > high: return false
		for offset in range(2,count+1):
			if bytes[i+offset] < 0x80 or bytes[i+offset] > 0xbf: return false
		i += count + 1
	return true
