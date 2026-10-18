extends RefCounted
## Authored presentation only; never consumes simulation RNG or edits a definition.
const AREAS := [
	{"name": "Ash Gate", "ground": "c8c3b5", "path": "d8d0b9", "rock": "687c82", "cap": "d9e3df", "accent": "cfab52", "landmark": "watchtower", "terrain": "snow", "rim": "b3c6c3"},
	{"name": "Switchyard", "ground": "bcb6a7", "path": "d1c6ad", "rock": "69787b", "cap": "b8beb6", "accent": "b98b4e", "landmark": "rail_wagon", "terrain": "rail", "rim": "84958e"},
	{"name": "Signal Ridge", "ground": "aebcaf", "path": "d1ceba", "rock": "687f84", "cap": "d6ddd2", "accent": "6eafbc", "landmark": "signal_dish", "terrain": "ridge", "rim": "8da4a1"},
	{"name": "The Iron Drill", "ground": "b7a991", "path": "d0bda0", "rock": "7a7970", "cap": "c4bda8", "accent": "d3a148", "landmark": "quarry_crane", "terrain": "quarry", "rim": "999d89"},
	{"name": "Broken Bridge", "ground": "b6bbb2", "path": "cfd1c2", "rock": "617b80", "cap": "c5d2cb", "accent": "739f9d", "landmark": "bridge_arch", "terrain": "bridge", "rim": "819e9a"},
	{"name": "Glass Quarry", "ground": "bec9c6", "path": "d8d9c8", "rock": "71949a", "cap": "d5e4df", "accent": "78b9b8", "landmark": "crystal_spire", "terrain": "glass", "rim": "9cbab8"},
	{"name": "Night Relays", "ground": "8b9d9d", "path": "b5bcb0", "rock": "596e7d", "cap": "9db4bf", "accent": "e4c579", "landmark": "relay_mast", "terrain": "night", "rim": "748d9b"},
	{"name": "The Brood Carrier", "ground": "b6b8a6", "path": "ced0b7", "rock": "727c71", "cap": "c0c8ae", "accent": "a6ba7b", "landmark": "repair_gantry", "terrain": "depot", "rim": "8e9d83"},
	{"name": "Red Causeway", "ground": "c1ad94", "path": "d6c6a8", "rock": "947d6d", "cap": "c6b39c", "accent": "d2a16a", "landmark": "floodgate", "terrain": "causeway", "rim": "b9a28b"},
	{"name": "Mortar Gardens", "ground": "acb59f", "path": "d1c9ad", "rock": "718475", "cap": "bdc6ac", "accent": "c4b46b", "landmark": "orchard_tree", "terrain": "orchard", "rim": "8fa186"},
	{"name": "Last Supply", "ground": "b7bba8", "path": "d4ceb5", "rock": "778679", "cap": "ccd0b8", "accent": "d4b958", "landmark": "supply_truck", "terrain": "supply", "rim": "9fae93"},
	{"name": "Foundry Liberation", "ground": "adafa7", "path": "c8c6b4", "rock": "697578", "cap": "b7c2bf", "accent": "d7a65b", "landmark": "foundry_stack", "terrain": "foundry", "rim": "879696"}
]

static func describe(state: Dictionary) -> Dictionary:
	var index: int = int(state.definition.index) if int(state.catalog) == 2 else 0
	var result: Dictionary = AREAS[index].duplicate(true)
	result["index"] = index
	result["variant"] = 0
	result["style"] = "authored"
	if int(state.catalog) == 2 and state.definition.mode == "skirmish":
		result.variant = int(state.definition.seed) % 3
		result.style = state.definition.style
		result.accent = ["c9b16e", "84b6ac", "a8a7c2"][result.variant]
	return result
