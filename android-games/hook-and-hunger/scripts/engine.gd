extends RefCounted
## Schema1 remains the shipped, immutable prototype's combat interpretation.
const Legacy = preload("res://scripts/rules.gd")
const Campaign = preload("res://scripts/campaign_rules.gd")

static func fresh() -> Dictionary:
	return Legacy.fresh()

static func position(s: Dictionary) -> Vector2:
	return Vector2(s.x, s.z)

static func weapon(s: Dictionary) -> Dictionary:
	return Legacy.weapon(s) if s.schema == 1 else Campaign.weapon(s)

static func roster(s: Dictionary) -> Array:
	return Legacy.ROSTER if s.schema == 1 else s.definition.roster

static func active(s: Dictionary) -> Array:
	return s.enemies if s.schema == 1 else Campaign.active(s)

static func obstacles(s: Dictionary) -> Array:
	if s.schema == 1:
		return Legacy.OBSTACLES
	var result := []
	for b in s.definition.obstacles:
		result.append(Vector3(b.x, b.z, b.radius))
	return result

static func pad(_s: Dictionary) -> Vector2:
	return Legacy.PAD

static func cost(s: Dictionary) -> int:
	return Legacy.COST if s.schema == 1 and s.tier == 0 else (0 if s.schema == 1 else Campaign.cost(s))

static func purchase(s: Dictionary) -> bool:
	return Legacy.purchase(s) if s.schema == 1 else Campaign.purchase(s)

static func retry(s: Dictionary) -> bool:
	return Legacy.retry(s) if s.schema == 1 else Campaign.retry(s)

static func step(s: Dictionary, movement: Vector2, delta: float) -> void:
	if s.schema == 1:
		Legacy.step(s, movement, delta)
	else:
		Campaign.step(s, movement, delta)

static func valid(v: Variant) -> bool:
	return v is Dictionary and (Legacy.valid(v) if v.get("schema") == 1 else Campaign.valid(v))

static func restore(v: Variant) -> Dictionary:
	if not valid(v):
		return {}
	return Legacy.restore(v) if v.schema == 1 else Campaign.restore(v)

static func numeric(v: Variant, lo: float, hi: float, whole: bool = false) -> bool:
	return Legacy.numeric(v, lo, hi, whole)
