extends RefCounted
## Authored presentation only; never consumes simulation RNG or edits a definition.
# Warm, light grounds with a paler central clearing and a cooler hazy rim.
const AREAS := [
	{"name": "Ash Gate", "ground": "cac3b6", "clearing": "dad5cb", "path": "d3ccc0", "rock": "9da8aa", "cap": "e3e4e3", "accent": "cfab52", "landmark": "watchtower", "terrain": "snow", "rim": "cbcbc8", "haze": "e0ded8"},
	{"name": "Switchyard", "ground": "c3bbad", "clearing": "d3cdc1", "path": "cac3b6", "rock": "999d98", "cap": "bdbab0", "accent": "b98b4e", "landmark": "rail_wagon", "terrain": "rail", "rim": "bcb7ad", "haze": "ddd8cd"},
	{"name": "Signal Ridge", "ground": "c4c0b2", "clearing": "d4d0c5", "path": "cec9bd", "rock": "95a3a9", "cap": "e0e3e1", "accent": "6eafbc", "landmark": "signal_dish", "terrain": "ridge", "rim": "c3c6c2", "haze": "dcdfdb"},
	{"name": "The Iron Drill", "ground": "c5baa9", "clearing": "d4ccbf", "path": "cac1b1", "rock": "a89d8f", "cap": "c5baa4", "accent": "d3a148", "landmark": "quarry_crane", "terrain": "quarry", "rim": "beb4a4", "haze": "dfd6c8"},
	{"name": "Broken Bridge", "ground": "c6c0b4", "clearing": "d6d2c9", "path": "cecac1", "rock": "91a2a9", "cap": "d5dad7", "accent": "739f9d", "landmark": "bridge_arch", "terrain": "bridge", "rim": "bdc1be", "haze": "d9dcd8"},
	{"name": "Glass Quarry", "ground": "c9c4b9", "clearing": "d9d6ce", "path": "d1cec5", "rock": "98adb2", "cap": "e0e4e3", "accent": "78b9b8", "landmark": "crystal_spire", "terrain": "glass", "rim": "c6cccb", "haze": "dde2e0"},
	{"name": "Night Relays", "ground": "a09f98", "clearing": "afaea8", "path": "aba9a1", "rock": "788694", "cap": "bdc6ce", "accent": "e4c579", "landmark": "relay_mast", "terrain": "night", "rim": "8a9096", "haze": "88939f"},
	{"name": "The Brood Carrier", "ground": "c3bcad", "clearing": "d3cec2", "path": "cac5b9", "rock": "9da091", "cap": "c9c7b6", "accent": "a6ba7b", "landmark": "repair_gantry", "terrain": "depot", "rim": "bbb9ab", "haze": "dbd9cd"},
	{"name": "Red Causeway", "ground": "c5b7a5", "clearing": "d5cbbd", "path": "ccc1b1", "rock": "b29984", "cap": "cbb8a0", "accent": "d2a16a", "landmark": "floodgate", "terrain": "causeway", "rim": "beac9a", "haze": "e2d6c8"},
	{"name": "Mortar Gardens", "ground": "c2beab", "clearing": "d1cec0", "path": "ccc6b7", "rock": "95a290", "cap": "c4c7b4", "accent": "c4b46b", "landmark": "orchard_tree", "terrain": "orchard", "rim": "b8b9a8", "haze": "d9dacc"},
	{"name": "Last Supply", "ground": "c7bfb0", "clearing": "d6d1c5", "path": "cec8bc", "rock": "99a295", "cap": "cfcfbf", "accent": "d4b958", "landmark": "supply_truck", "terrain": "supply", "rim": "bebcaf", "haze": "dddacf"},
	{"name": "Foundry Liberation", "ground": "c1baae", "clearing": "d1cdc3", "path": "c9c3b7", "rock": "929896", "cap": "c6c9c5", "accent": "d7a65b", "landmark": "foundry_stack", "terrain": "foundry", "rim": "b5b2ab", "haze": "d6d4ce"}
]

static func describe(state: Dictionary) -> Dictionary:
	var index: int = int(state.definition.index) if int(state.catalog) == 2 else 0
	var result: Dictionary = AREAS[index].duplicate(true)
	result["index"] = index
	if result.terrain not in ["snow", "ridge", "night", "glass"]:
		# Snowless districts weather their rock tops instead of capping them white.
		result.cap = Color(result.rock).lightened(.22).to_html(false)
	result["variant"] = 0
	result["style"] = "authored"
	if int(state.catalog) == 2 and state.definition.mode == "skirmish":
		result.variant = int(state.definition.seed) % 3
		result.style = state.definition.style
		result.accent = ["c9b16e", "84b6ac", "a8a7c2"][result.variant]
	return result
