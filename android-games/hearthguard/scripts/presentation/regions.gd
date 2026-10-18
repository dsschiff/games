extends RefCounted
## Authored composition for all ten campaign maps. No procedural gameplay content.
const MAPS := [
	{"landmark": "Copper market", "props": ["market", "anvil", "well"], "grove": 0},
	{"landmark": "Reed tollhouse", "props": ["reeds", "well", "lantern"], "grove": 1},
	{"landmark": "Cinder forge", "props": ["anvil", "banner", "boulder"], "grove": 2},
	{"landmark": "Twinwater quay", "props": ["reeds", "market", "lantern"], "grove": 0},
	{"landmark": "Lantern sanctuary", "props": ["lantern", "well", "reeds"], "grove": 1},
	{"landmark": "Brood marsh", "props": ["reeds", "boulder", "banner"], "grove": 2},
	{"landmark": "Glasswind shrine", "props": ["monolith", "lantern", "well"], "grove": 0},
	{"landmark": "Broken waystones", "props": ["boulder", "monolith", "banner"], "grove": 1},
	{"landmark": "Last watch bellcourt", "props": ["banner", "anvil", "lantern"], "grove": 2},
	{"landmark": "The ten beacon court", "props": ["monolith", "banner", "well"], "grove": 0}
]

static func describe(state: Dictionary) -> Dictionary:
	var stage: int = int(state.definition.stage) if state.schema == 2 else 0
	var region: int = int(state.definition.region) if state.schema == 2 else 0
	var palettes := [
		{"ground": "94a674", "edge": "68785a", "road": "cfb58a", "water": "87b6b3", "sky": "c4d2c3", "house": "cottage", "tree": "oak"},
		{"ground": "7ca49a", "edge": "527d79", "road": "c3ba91", "water": "639d9f", "sky": "bdcfcd", "house": "stilt_house", "tree": "oak"},
		{"ground": "b8cacc", "edge": "7f9a9f", "road": "d5cbb2", "water": "7db0b8", "sky": "d4dfe0", "house": "ridge_house", "tree": "pine"}
	]
	var result: Dictionary = palettes[region].duplicate(true)
	result.merge(MAPS[stage], true)
	result.stage = stage
	result.region = region
	return result
