# Kingshot reference and original game brief

Reviewed 2026-10-17. Candidate title: **Hearthguard** (`hearthguard`). Status: **exact indexed defense creative observed and sampled sustained core comparison; creative attribution is third-party indexed, player input inferred**.

## Exact sources

| ID | URL | Provenance |
| --- | --- | --- |
| K1 | https://play.google.com/store/apps/details?id=com.run.tower.defense | Official Century Games Android identity. Describes settlement/survivor management, defenses, heroes and alliances. |
| K2 | https://cdn.admapix.com/f/aHR0cHM6Ly9hZGluc2lnaHRzLTEyNTg4OTI2MjQub3NzLWFjY2VsZXJhdGUuYWxpeXVuY3MuY29tL3ZpZGVvc192My8yMDI2LzEvMS94X3ZfZTM4Yzg3ZjAxZjZjZTQ0ODZiZGQ0ZTk2Mjc3MzM4NDgubXA0.mp4 | Selected exact 56.341-second defense creative. Streamed and visually inspected in browser; no install/download. |
| K3 | https://pub-adf48a42024e40fea45150c01a16dbd0.r2.dev/blog/evidence/8202670970cbbfb7cfd9fcd657aad031d61660d503389d0e4fc0df648af6ae55.json | Frozen third-party index maps K2 to record 9aef093bdca67ee24f4a02724d5671ea and Kingshot iOS 6739554056. Record video fingerprint 501bf3370d8306042968ab765763d47b. This is an attribution trail, not independently verified ad-network delivery. |
| K4 | https://www.youtube.com/watch?v=Y2EgJ-0yv3c | Techzamazing player recording, “Gameplay Walkthrough Part 1,” 2025-03-05; duration 22:25.383. Description identifies Samsung Galaxy S23 Ultra. Sampled opening and minutes 5 and 15. |
| K5 | https://www.pocketgamer.com/kingshot/hands-on/ | Catherine Dellosa's first-hand hands-on report corroborates action-defense advertising versus settlement/resource focus. Supporting context; not substituted for observing K2/K4. |
| K6 | https://www.admapix.com/blog/ad-intelligence/kingshot-ad-strategy-2026 | Discovery page for K3. Its text states automated drafting and limited contact-sheet review; our mechanics notes below come from watching the media, not copying that analysis. |

## Direct observations

**Timestamp correction, bounded follow-up 2026-10-17:** original table times are player seek/read positions, not certified frame timestamps. Immediate post-seek screenshots can retain an earlier decoded frame. Treat those rows as approximate scene observations. The settled checkpoints below take precedence; video sequence evidence is distinct from tested playable input.

| Source/time | Visible content |
| --- | --- |
| K2 approximately 00:05–00:15 | Portrait, angled overhead 3D. Small crowned/blue-cloaked figure on grassy ledge, winding lower road, snowy cliff boundaries. Empty dashed pads have coin prices 15/20/25; a crossbow tower fires across the road at a stream of red enemies. Gold drops scatter densely along the road. |
| K2 00:22.769 | Coin counter 44. Figure stands on a priced pad beside two constructed crossbow towers; bolts strike red and armored units below. More empty build pads remain. |
| K2 00:36.261 | Counter 30, three crossbow towers firing into a dense armored/red column. Figure moves among ledges while coins accumulate along the road. Same continuous action-defense framing. |
| K4 01:01.791 | Portrait stylized town, yellow-roof buildings and dialogue. |
| K4 05:00.741 | Expanded town overview, resource bar and “Build Kitchen” objective; building placements and settlement are the interface focus. |
| K4 15:01.564 | Chapter 3 missions: upgrade town center to 4, build quarry, upgrade quarry to 3, claim rewards. Sustained progression is settlement-task driven in these samples. |

K2 shows movement, currency, build positions and active defenses, but watching a video does not establish whether real input caused each action. Moving onto a pad to spend coins/build is a strong **inference**; precise input, collection radius, tower targeting and economy are unverified. Tiny figure's exact movement speed and frame-to-frame path were not measured. K4 was sampled rather than exhaustively watched, so do not claim all core modes or late-game behavior have been inspected.

## Selected target

Make the active **move → collect battle coins → fund towers → hold an incoming column** scene the primary game throughout. Keep the close 3D overhead angle, contour-separated paths, vivid enemy stream and quickly legible upgrade impact. Avoid turning the game into a settlement timer, hero roster or alliance screen. The reference has real settlement systems; this brief selects its advertised action-defense activity without claiming that every ad or every core mode is identical.

## First prototype boundary after interpretation review

Prove **avatar movement → nearby coin collection → visible pad cost/funding → constructed tower firing → defended incoming wave**, with win/loss/retry. Capture a complete pickup-to-counter-change-to-build cycle before locking exact input/economy. Defer avatar firing, dash, hero death and mounted-avatar assumptions; the prototype must work through movement and tower decisions alone. Original elk theme is an optional art direction, not a reference requirement. Counts and timings below are candidates to assess after this loop feels good.

## Candidate full-game design and deferred ideas

- **World/camera:** portrait angled overhead 3D orthographic-follow camera with restrained zoom; local view shows avatar, at least two build choices and the approaching road. Original frontier warden on mechanical elk, copper watchtowers and ash raiders. Snowy cliffs/green terrain are broad palette cues, not copied levels, meshes or characters.
- **Controls:** floating thumbstick moves; step near a pad to display tower and price; hold contextual Build/Upgrade briefly to spend coins. Coins magnetize only nearby; show a danger outline when collecting on an enemy road. Tap a tower to inspect range and role. Autocrossbow for avatar, optional dash with short cooldown. Explicit build action avoids accidental spending while crossing a pad.
- **Loop/pacing:** first tower within 20 seconds. Enemies continually advance in readable waves; defeated enemies drop coins; collecting and investing produces visible firepower within seconds. Each 3–5-minute map alternates 20–40-second pressure pulses and 10–20-second breathing spaces, with free pause to inspect the next wave. No construction wait or collection chore after the battlefield is clear.
- **Depth:** limited build pads and locally collected money; spend near front for long coverage or near base for safety. Crossbows pierce armored lanes, mortars punish swarms but miss fast units, frost beacons slow but deal little damage. Upgrade damage versus range forks permanently within one run; sell for partial refund. Branching roads create travel risk and coverage tradeoffs. Hero can intercept a leak but cannot replace every tower.
- **Loss/win:** enemies reaching refuge reduce integrity; zero integrity or hero death loses the current wave. Clear all waves and boss to win. Immediate retry at map start or checkpoint; no free purchased revives. Explain what leaked and from which route.
- **Arc:** 10 maps across three regions, 3 tower families with 2 upgrade forks, 6 enemy roles, 3 bosses, 40–55-minute first clear. Early maps teach collecting/building/counters; later maps use simultaneous lanes and limited pads. Final map recombines movement and spending decisions rather than adding only larger health numbers.
- **Progression/replay:** permanent unlocks broaden starting tower kits; maps remain winnable without grinding. Alternate budgets, enemy routes, seeded endless map and optional no-leak medals. No offline idle farm, hunger meter, alliance or real-time town growth required.

## Acceptance

1. Record early/middle/final gameplay beside K2. Avatar actively traverses the defensive map, collects visible drops, builds at marked positions and reacts to moving enemy streams in all three. A stationary tower board or menu city-builder fails.
2. Two viable tower layouts per late map; a failed counter choice can be diagnosed and corrected; demonstrate risky coin pickup, lane leak, boss, win, loss, retry and later unlock. No encounter should force waiting for coins once no threat remains.
3. Rule tests cover coin ownership/spending, pad occupancy, tower coverage and target choice, upgrade fork/sell refund, leaks and checkpoint restoration. Spawn/route data must be explicit; enemy collision/pathing cannot strand a wave indefinitely.
4. On-phone legibility, touch control accuracy, heavy-wave performance, reduced effects/sound, offline play, background/resume, interrupted saves, export/import and update compatibility remain required. Target 60 fps, heavy wave above 30 fps is unmeasured until tested.

## Evidence still open

K2 is an exact accessible creative with product attribution from a third-party snapshot, not a proven original platform ad-library entry. Find an official account/ad-library counterpart if possible. Input and causal economy rules remain inferred; compare the implemented interpretation with the video before claiming fidelity. No audio review, no app install, no physical-phone validation.

## Bounded sequence follow-up: K2 00:00–00:14

The opening was replayed as one contiguous source passage, then inspected with paused checkpoints. At approximately 00:00.7, wallet is 0 and there is an empty 5-cost pad. At settled player position 00:02.817, coins cluster beside the avatar and wallet is 2. At 00:05.071 the wallet is 5, the avatar has moved toward the empty 5-cost pad, and drops remain on the road. At 00:06.198 the avatar occupies that pad, gold particles appear above it and wallet reads 3; the pad's remaining numeral is partly hidden by the avatar. At 00:07.324 a constructed crossbow tower occupies the former pad and fires at the road. By approximately 00:13.8 a second tower is visible near the former 15-cost pad and wallet reads 5.

This supports the temporal sequence **nearby drops and rising wallet → avatar on priced pad with lower wallet → constructed firing tower**. The hidden intermediate pad numeral and simultaneous collection prevent an exact debit ledger; do not claim that the wallet's 5→3 difference is the complete tower price. Build-button versus stand-to-spend input, hold duration, pickup radius and whether these are authentic playable rules remain untested. The principal coin-funded construction gap is substantially narrowed by the visible sequence; original advertiser mapping remains qualified.
