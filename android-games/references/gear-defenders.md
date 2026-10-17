# Gear Defenders reference and original game brief

Reviewed 2026-10-17. Candidate original title: **Gear Bastion**. Status: **observed store-linked promotional creative and sampled sustained gameplay; ready for independent interpretation review**. This is a selected representative creative, not a claim to identify the precise ad Daniel previously saw.

## Exact sources

| ID | Source | Provenance and use |
| --- | --- | --- |
| G1 | https://play.google.com/store/apps/details?id=com.iogame.gearworld | Official listing, MOBIBRAIN; its trailer thumbnail resolves to YouTube ID S-EyqmFMw_0. Identifies the advertised game. |
| G2 | https://www.youtube.com/watch?v=S-EyqmFMw_0 | Store-linked 18.901-second promotional creative, title “Gear Defenders,” unlisted upload by “Business Simulation.” Official provenance is the store link, not the channel name. Watched in browser, sound muted. |
| G3 | https://www.youtube.com/watch?v=EKsNmmKn7GM | Usman's Gaming, “Gameplay Walkthrough Part 1 - Levels 1 & 2,” 2026-01-04; duration 8:32.961. Player-recorded sustained core reference. Sampled opening, middle of level 1 and level 2; not an exhaustive playthrough. |
| G4 | https://www.youtube.com/watch?v=8XuHy6hyDPk | Additional candidate walkthrough by Prohan Gamer; discovered but not visually reviewed. Do not use for observed claims. |
| G5 | https://www.youtube.com/watch?v=aMGkye6yZ7g | Rong, “Gear Defenders: Nightmare Lv110,” 5:50.021. Later-game recording directly sampled after initial prototype review; see addendum below. |

## Timestamped observations

Times are media times. Fixed samples were paused and time read from the visible video's DOM; ranges describe moving observations without frame precision.

| Source/time | Directly observed |
| --- | --- |
| G2 00:02.919 | Portrait composition: upper battlefield, horizontal castle wall with three exits, lower socket board. Gold circular core beside connected cream gears; soldier pictures on generator gears, numeric gears below. Units march upward from exits and fight enemies. |
| G2 00:08.655 | Denser lower network of blue “2” gears interspersed with troop generators around a central yellow core. Several generators show 0.22/s. Many orange-haired ranged units fill the battlefield. Purple “-1” pieces and a video-reward badge are visible. |
| G2 00:16.923 | Level 26, wave 12/12. Very dense blue-haired troop army fights near the top; a large connected generator/number-gear arrangement below. The wall health remains visible between the two regions. |
| G2 approximately 00:17–00:18 | Victory/reward presentation; promotional montage ends. The cuts do not establish real elapsed production or upgrade time. |
| G3 approximately 00:20–00:49 | Level 1 early waves. Sparse board with core and sword generator, initially 0.17/s then 0.2/s; a numeric gear changes from 1 to blue 2. Sword units leave wall to attack green enemies. Wall health 325; population/food indicator 2/15. Camera remains fixed. |
| G3 approximately 02:00–02:40 | Level 1 wave 4/5. Two sword generators and blue 2 gears remain on lower board while units fight above. Core/network construction and battle coexist rather than switching to a separate RPG. |
| G3 06:15.226 | Level 2 wave 4/6. Ranged and sword units fight together; visible arrows. Lower board now includes a ranged generator and blue 2 gear; 8/15 resource indicator, wall health 303. Same portrait camera and simultaneous board/battle layout. |

## Comparison and uncertainty

The selected short creative and sustained samples share the distinctive core-network construction, troop production, wall defense and fixed split portrait layout. Preserve that loop. The creative compresses early-to-late board development and very large armies into 19 seconds; its pacing and displayed abundance are not a measured simulation rate. We have not established exact gear ratio equations, merge rules, all lane assignment rules, upgrade prices, whether placement pauses combat, or late-game balance. Do not infer those from gear labels alone. No original app was installed or played locally. The source identity/ad relationship is established; exact mechanical equivalence remains a review judgment with these limits.

## Implementation contract (our design, not claimed reference facts)

Repeated action: inspect approaching threats, drag gear/generator pieces into a powered network, allocate production between three gates, merge or replace pieces, and watch the resulting army hold the wall. The placement and readable spawning must remain the main game through the final encounter.

- **Camera/visual match:** fixed portrait 2D view, roughly upper 55% battlefield / lower 35% gear board with a wall between; compact illustrated units, clear outlines, restrained bright colors and animated rotating teeth. Original brass automata, beetle raiders and cliff foundries; no copied characters, UI logos or screenshots. Battlefield depth is top-down with slight illustrated elevation, not a platformer.
- **Input:** drag from tray to sockets; drag installed pieces to rearrange; tap for stats; long press preview; explicit merge confirmation. Show green powered path and red invalid placement. Touch targets at least 48 dp, keep finger from hiding placement destination. Pause and speed controls available without purchases.
- **Power rules:** orthogonally adjacent gears connected to core become powered; direction of rotation alternates. Numeric drive gears raise effective generator speed using a bounded, inspectable multiplier (cap 3x). Unpowered generators visibly stop. Merging equal drive gears frees space but changes reachable connections; show before/after production and affected units. These rules are intentionally designed, not reverse engineered.
- **Consequential choices:** restricted socket shapes, core relocation on selected stages, scarce deployment budget, melee blockers versus fragile ranged damage, three gate pressure, armor-piercing/splash roles and repair-versus-production spending. Forecast the next wave. No dominant all-purpose generator; enemy counters must be visible and learnable.
- **Battle:** independent troops emerge through a selected gate, auto-acquire enemies and attack. A clear bounded unit cap avoids unreadable or runaway armies. Enemies reaching wall damage it; zero wall health loses. Destroy all waves wins. Early waves 20–35 seconds; full encounter target 2–4 minutes, with active placement choices every 10–20 seconds. Targets require playtesting.
- **Complete arc:** 12 handcrafted encounters in three regions, 4 generator roles, 4 drive modifiers, 6 enemy roles, 3 bosses, roughly 40–55 minutes. Each region introduces a rule then recombines it. Unlocks add options; do not require grinding old levels. Retrying grants no escalating permanent power that hides a bad strategy.
- **Replay:** seeded challenge maps and an endless mode after campaign; limited-budget medals, optional no-wall-damage goals, alternative starting kits. No daily attendance or real-time waits.

## Acceptance and review gates

1. Independent reviewer can align our first, middle and final campaign footage with G2/G3 composition and the repeating powered-placement → visible spawning → wall-defense loop. A board with decorative gears and generic shooting fails.
2. Demonstrate a disconnected generator stopping, reconnection restarting, two meaningfully different winning builds, a counter-based failed build that can be corrected by rearrangement, win, loss and immediate retry.
3. Gear changes visibly change units per second; production remains bounded and deterministic under seeded simulation tests. Wall/lane targeting, merge costs, modifier caps and save restoration get rule tests.
4. Record touch drag accuracy, frame pacing with the heaviest intended army, readable threat/health state, sound/reduced effects, onboarding, local export/import and interrupted-save recovery. Save versioned campaign, unlocks, loadout and active battle; update must preserve the prior save.
5. No advertisements, network dependencies, purchases, accounts or energy. Performance target 60 fps and heavy encounters above 30 fps requires measured phone evidence.

## Remaining reference work

Review full G3 rather than only samples; preserve a local permitted comparison clip under ignored `.references/` through coordinator. Audio was muted; original audio should be created and tested rather than described as matched.

## Later-game addendum, 2026-10-17

G5 was sampled at 01:00.425, 03:00.659, 05:00.691 and 05:30.857. At 01:00 the lower board has generators, numeric 1 gears, negative -2 modifiers, more than one gold core-like disk, food 0/46, a purchasable piece tray and **Battle/Refresh** buttons. At 03:00 a “Necro Summon” presentation appears over the same board; production rates include 0.72/s and 0.43/s, a green x1.5 modifier and purple 4. At 05:00 the expanded setup includes 8, x1.5, 1, 2 and -2 pieces, four differently illustrated generators and an upgrade/refresh shop. At 05:30 the upper field is crowded with units and spell effects while lower generators show rates; three wall lanes still divide the same board/defense composition.

This adds direct later-game evidence that powered-board construction and generated-unit defense persist beyond levels 1–2. It also corrects a possible overinterpretation: the interface can emphasize the board/tray between fights, so the prototype should support an explicit preparation phase and start-battle action rather than require constant live rearrangement as a claimed reference fact. The later recording appears sped up and has dense effects; its elapsed battle seconds cannot set our pacing targets. Exact gear arithmetic, multiple-core function and negative-modifier effects remain unverified. G3 and G5 remain sampled recordings, not continuous exhaustive observation or original-app play.
