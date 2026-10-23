extends SceneTree
var checks := 0
var failures := 0
var Backup: GDScript
const Store = preload("res://scripts/campaign_store.gd")
const PACKAGE := "com.dsschiff.deadrun"

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", description)

func _initialize() -> void:
	Backup = load(get_script().resource_path.get_base_dir().path_join("../cloud_backup.gd"))
	var validate := func(raw: String) -> Dictionary: return Store.decode(raw)
	var context := Store.fresh()
	var original := JSON.stringify(context)
	var local := Store.encode(context, 17)
	var packet: Dictionary = Backup.encode(PACKAGE, local, validate)
	check(packet.get("ok", false), "valid actual Dead Run save encodes")
	var decoded: Dictionary = Backup.decode(PACKAGE, packet.text, validate)
	check(decoded.get("ok", false) and decoded.save == local, "opaque bytes round trip")
	check(decoded.decoded.context == Store.decode(local).context, "complete actual game context retained")
	check(decoded.decoded.revision == 17, "local revision retained without ranking")
	check(JSON.stringify(context) == original, "source context not mutated")
	check(not Backup.decode("com.dsschiff.frontlinefoundry", packet.text, validate).ok, "wrong game rejected")
	check(not Backup.encode(PACKAGE, "broken", validate).ok, "invalid local save rejected before upload")
	check(not Backup.encode("", local, validate).ok, "empty package rejected")
	check(not Backup.decode(PACKAGE, packet.text, Callable()).ok, "missing decoder rejected")
	for value in ["", "{", "[]", "null", "42", "true"]:
		check(not Backup.decode(PACKAGE, value, validate).ok, "malformed remote rejected")
	var base: Dictionary = JSON.parse_string(packet.text)
	for change in [{"format": 99}, {"package": "wrong"}, {"save": false}, {"sha256": []}, {"save": "truncated"}]:
		var altered := base.duplicate(true)
		altered.merge(change, true)
		check(not Backup.decode(PACKAGE, JSON.stringify(altered), validate).ok, "invalid transport field rejected")
	var broken := base.duplicate(true)
	broken.save = "invalid but checksummed"
	broken.sha256 = String(broken.save).sha256_text()
	check(not Backup.decode(PACKAGE, JSON.stringify(broken), validate).ok, "transport checksum cannot authorize corrupt game state")
	var oversized := "x".repeat(Backup.MAX_BYTES + 1)
	check(not Backup.decode(PACKAGE, oversized, validate).ok, "oversize rejected")
	check(not Backup.encode(PACKAGE, oversized, validate).ok, "oversize upload rejected")
	var unicode := "界".repeat(1000000)
	check(not Backup.decode(PACKAGE, unicode, validate).ok, "limit counts bytes, not characters")
	check(not Backup.decode(PACKAGE, packet.text.left(packet.text.length() - 3), validate).ok, "truncated packet rejected")
	var future: Dictionary = JSON.parse_string(local)
	var body: Dictionary = JSON.parse_string(future.payload)
	body.version = 999
	future.payload = JSON.stringify(body)
	future.sha256 = String(future.payload).sha256_text()
	broken.save = JSON.stringify(future)
	broken.sha256 = String(broken.save).sha256_text()
	check(not Backup.decode(PACKAGE, JSON.stringify(broken), validate).ok, "future game schema rejected by owning decoder")
	check(JSON.stringify(context) == original, "all rejected remote inputs preserve local context")
	print("Cloud backup codec: ", checks, " checks, ", failures, " failures. Native network/account verification separate.")
	if failures == 0: print("SUITE_COMPLETE: PASS")
	quit(0 if failures == 0 else 1)
