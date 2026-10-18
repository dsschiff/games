extends RefCounted
const C = preload("res://scripts/campaign_rules.gd")
const Cat = preload("res://scripts/campaign_catalog.gd")

static func plan(s: Dictionary, variant: int = 0) -> Dictionary:
	var order := [2, 3, 0, 1, 4, 5] if s.towers.size() == 6 else ([2, 6, 7, 3, 0, 1, 4, 5] if variant == 0 else [6, 2, 3, 7, 1, 0, 5, 4])
	if s.definition.mirror:
		for i in order.size():
			if order[i] < 6:
				order[i] = order[i] + (1 if order[i] % 2 == 0 else -1)
	var families := [0, 1, 2, 0, 1, 2, 0, 1] if variant == 0 else [1, 0, 2, 1, 0, 2, 1, 0]
	var desired := -1
	var choice := -1
	var price := 0
	# Build a pair, then invest in their identity before expanding coverage.
	for step in order.size() * 2:
		var pair := step / 4
		var k := pair * 2 + step % 2
		var upgrade := step % 4 >= 2
		if k >= order.size():
			continue
		var pad: int = order[k]
		var tower: Dictionary = s.towers[pad]
		if not upgrade and tower.family == -1:
			desired = pad
			choice = families[k]
			price = s.definition.families[choice].price
			break
		if upgrade and tower.family >= 0 and tower.fork == 0:
			desired = pad
			choice = 1 if tower.family == 1 and variant == 0 else 0
			if s.definition.stage == 8 and tower.family == 0 and variant == 0:
				choice = 1
			price = s.definition.families[int(tower.family)].upgrades[choice]
			break
	var goal := C.position(s)
	if desired >= 0 and s.wallet >= price:
		goal = C.pad_point(s.definition, desired)
		return {"goal": goal, "pad": desired, "choice": choice, "affordable": true}
	var nearest := INF
	for coin in s.coins:
		var q := Vector2(coin.x, coin.z)
		var distance := C.position(s).distance_to(q)
		if distance < nearest:
			nearest = distance
			goal = q
	return {"goal": goal, "pad": desired, "choice": choice, "affordable": false}
