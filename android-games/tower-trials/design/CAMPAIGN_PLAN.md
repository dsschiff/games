# Campaign preparation while the loop is reviewed

This is authoring preparation, not an expansion approval or a claim that 36 puzzles are built. The playable checkpoint remains the immutable four-watch version 0.1.0/code1 at `3b4643b`. Coordinator owns its APK/device work and Astra appeal review.

## Arc and duration target

Four coastal chapters of nine mandatory watches, with a distinct finale per chapter. Six integrated tutorials teach addition/equality, ordered rooms, keys, one-way bridges, shields/traps, and the shield/multiplier conflict. Teach each rule separately before requiring a combined solution. The current four-watch slice deliberately compresses that introduction for review; campaign authoring must separate the compressed Glass Causeway lesson before harder combinations.

| Chapter | Watches | Purpose | Finale requirement |
| --- | --- | --- | --- |
| Lantern Coast | 1–9 | Six tutorials, two reinforcements, first complete route | Forecast ordered rooms; preserve the only key through a visible fork |
| Salt Archives | 10–18 | Keys and one-way commitments; non-terminal keeper rescue | Rescue the stranded keeper before sealing that balcony; spend two keys in a deliberate order |
| Glass March | 19–27 | Shield budgeting, traps and sun-lens choices | Carry protection through a lethal trap, consume it, then reach the multiplier before the ordered final guard |
| Last Meridian | 28–36 | Combined resources, alternative solutions and treasure tradeoffs | Multi-step route with ordered enemies, two door costs, a keeper-before-seal constraint and a clear final rescue |

Early watches target 30–60 seconds, later watches 2–3 minutes with planning and optional replay. This is a **human-playtest target**, not a measurement from accelerated automation. A 36-puzzle count alone does not establish a meaningful 30–60-minute journey. Check representative first/middle/final human solving times and failure explanations before claiming duration. Add decisions rather than animation delays, repeated filler rooms or grind.

Later watches should contain 6–8 meaningful rooms and more than one plausible early choice; limit numbers to arithmetic that remains readable. Distinct topology/resource obligations must accompany numerical changes. Keep 48-dp input targets; use a deliberate board pan only if a larger tower cannot remain legible. Growth must remain visible without climbing into the HUD after six claims.

## Stable saves and the old-version fixture

Preserve catalog1, puzzle IDs and the code1 rules' meaning permanently. Never replay a legacy action list against a changed definition. A full-campaign catalog2 can introduce tutorial sequencing and richer rooms, but must locate the active catalog1 puzzle by stable ID and keep undo/retry on that catalog until the run ends or the player deliberately starts a current definition.

If catalog2 changes presentation order, migrate **display indexes by ID**, not active definitions. Keep earned prototype clears/medals and explicitly handle newly inserted mandatory tutorials: they remain playable requirements, never synthetic clears. Validation must allow legitimate historic clears even when new intervening tutorials were inserted. Current content ordering must not make a valid old active run unloadable.

The coordinator will create a real touch-earned code1 Android active route and install the later, higher-code APK over it without reset/import. Compare the entire reconstructed state, action/undo history, earned profile and settings at the update boundary; then perform a natural next action and undo/retry on the updated app. Different-version Android update evidence remains pending.

## Bounded proof cases

`prepared_cases.gd` holds six inactive route/rule stress cases for solver and state-space exploration. They are not in the campaign selector. Their purpose is to expose resource/order mistakes before authoring all later watches. No uniqueness claims. Keep this preparation separate from the reviewed runtime.

Seeded challenge generation is a required replay feature. Generator v1 adds four bounded structural grammar families, complete-state win/medal/loss witnesses, deterministic seed/options, a verified fallback and separately validated saved snapshots. It supplements the authored journey; generation does not substitute for campaign content. Final acceptance requires the generated mode as well as authored replay medals.
