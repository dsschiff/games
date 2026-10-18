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

# Each row describes one separated settlement shoulder cluster: x/z, orientation,
# house scale and tree offset. Mirrored paired rows are deliberately avoided.
const CLUSTERS := [
	[[-6.2, -5.8, .22, .68, -.8], [6.2, -.8, -.30, .72, 1.0], [-6.3, 2.7, -.12, .62, -.9]],
	[[6.3, -6.1, -.18, .66, .8], [-6.2, -1.8, .34, .70, -1.1], [6.2, 3.6, -.42, .61, .9]],
	[[-6.3, -6.6, .40, .72, .8], [6.2, -3.1, -.14, .62, -.9], [-6.2, 2.1, -.24, .66, -.8]],
	[[6.3, -5.7, -.30, .69, -.8], [-6.3, -.7, .25, .64, .9], [6.2, 3.2, .16, .70, -.9]],
	[[-6.2, -6.3, .20, .65, -.8], [6.3, -1.9, -.42, .70, 1.1], [-6.3, 2.3, -.18, .69, -.9]],
	[[6.2, -6.6, -.24, .64, .9], [-6.3, -2.7, .42, .70, -1.0], [6.3, 2.5, .20, .62, .8]],
	[[-6.3, -5.8, .26, .69, -.9], [6.3, -.5, -.20, .63, .9], [-6.2, 2.9, -.36, .65, -.8]],
	[[6.2, -6.8, -.32, .64, .8], [-6.3, -1.3, .42, .69, -1.0], [6.3, 3.4, -.16, .66, -.9]],
	[[-6.2, -6.4, .16, .71, .9], [6.3, -2.5, -.40, .65, -.8], [-6.3, 2.0, -.26, .66, -.9]],
	[[6.3, -6.1, -.28, .68, -.9], [-6.2, -.8, .34, .65, .9], [6.2, 3.3, -.14, .70, -.9]]
]

static func describe(state: Dictionary) -> Dictionary:
	var stage: int = int(state.definition.stage) if state.schema == 2 else 0
	var region: int = int(state.definition.region) if state.schema == 2 else 0
	var palettes := [
		{"ground": "7e8b76", "edge": "68785a", "road": "c3aa87", "water": "87b6b3", "sky": "c4d2c3", "house": "cottage", "tree": "oak"},
		{"ground": "6e8c82", "edge": "527d79", "road": "b4ad8c", "water": "639d9f", "sky": "bdcfcd", "house": "stilt_house", "tree": "oak"},
		{"ground": "9aafb2", "edge": "7f9a9f", "road": "bcb6a2", "water": "7db0b8", "sky": "d4dfe0", "house": "ridge_house", "tree": "pine"}
	]
	var result: Dictionary = palettes[region].duplicate(true)
	result.merge(MAPS[stage], true)
	result.stage = stage
	result.region = region
	result.clusters = CLUSTERS[stage].duplicate(true)
	return result
