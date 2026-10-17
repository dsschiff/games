# Hero Wars reference and original game brief

Reviewed 2026-10-17. Candidate title: **Tower Trials** (`tower-trials`). Status: **exact official tower ad and sustained RPG passage directly viewed by independent Astra reviewer; prototype direction approved; implementation comparison pending**. Select the numbered-tower puzzle, not pin pulling or a collage of unrelated ads.

## Sources and provenance

| ID | URL | Evidence |
| --- | --- | --- |
| H1 | https://www.facebook.com/herowarsalliance/videos/3547563985326593/ | Verified Hero Wars: Alliance page; dated January 13, 2021; “Hero Wars: Ascend Now.” Exact 18.005-second creative, played in authenticated browser. This is our selected ad, not necessarily Daniel's previously viewed creative. |
| H2 | https://gaming.stackexchange.com/questions/382544/is-the-tower-game-shown-in-the-hero-wars-ad-a-real-game | Discovery trail linking the full H1 ad. Community interpretations are not used as primary mechanics evidence. |
| H3 | https://www.youtube.com/watch?v=jH6xAF_TYV4 | PryGames, “Hero Wars Alliance - Gameplay Walkthrough Part 1,” 2024-11-02; 12:25.061. Sampled player recording, not a local app installation. |
| H4 | https://support-hwa.nexters.com/hc/en-us/articles/23898228203666-Game-Basics | Official game help, core RPG context. |
| H5 | https://support-hwa.nexters.com/hc/en-us/articles/13341501847314-Campaign | Official campaign help, describes chapter battles and hero/team progression. |
| H6 | https://play.google.com/store/apps/details?id=com.nexters.herowars | Official Android identity. Describes team collection, skill upgrades, PvE and online modes. |

## Direct observations

**Timestamp qualification, 2026-10-17:** original table times are browser player seek/read positions, not certified frame timestamps. A later bounded pass on other sources demonstrated that immediate post-seek screenshots can retain an earlier decoded frame. Treat these rows as approximate scene observations unless independently rechecked with a settled frame. This does not invalidate the official creative URL, but millisecond precision must not imply frame accuracy.

| Source/media time | Observed, not inferred |
| --- | --- |
| H1 00:00.230 | Flat 2D portrait creative. Left tower has red enemies 5, 2, 3 in separate floors; right tower holds blue hero 3. Caption instructs defeating enemies and growing a tower. |
| H1 00:02.142 | Animated pointer indicates a room selection. Blue 3 fights red 2 inside that enemy's floor; character placement is the advertised interaction rather than skill-button combat. |
| H1 00:08.858 | Blue hero now 8. Empty rooms and tower transformation/collapse animation make cleared rooms and growing structure visible. |
| H1 00:12.380 | Blue hero now 13, next to a taller tower with enemies marked 11, 42, 23, and floors containing two enemies 6 and 15. Clear escalation from one enemy per room to composite rooms. |
| H3 00:31.522 | Landscape side-view party of five fights monsters; portrait skill buttons, health/energy bars and Auto control below. This is visually and mechanically different from selecting numbered tower rooms. |
| H3 01:00.000 | Victory panel awards party experience/items/currency. |
| H3 03:00.842 | Character Stories/chapter-unlock menu. |
| H3 07:00.563 | Hero experience-potion/leveling screen; several roster members and individual XP bars. |

The rise 3 → 8 → 13 is consistent with adding defeated enemy values (2 + 3 + 5); that exact formula is an **inference**, not a reverse-engineered rule. The creative is animation with a pointer, not proven playable input. Its approximate sub-two-second combat beats are presentation targets, not measured action latency.

Independent direct-playback follow-up: Astra played H1 from its start through the approximately 18-second ending and inspected consecutive checkpoints. The introductory sequence is visibly 3→5→8→13, with brief clashes, disappearing enemy floors and growth of the blue-roofed player's tower. Around 13–16 seconds, a taller tower introduces stronger enemies and multiple numbered enemies in a room. The ending zooms out to larger towers and displays FAIL; the particular cause was not isolated. Addition is supported in these introductory encounters, while a universal formula, equality rule, multi-enemy order and actual touch input remain unproven. Winning must visibly grow or claim the player's tower; a static list of numerical encounters would lose this spatial payoff.

Astra also continuously played approximately 0:30–1:26 of H3 after a settled seek, observing landscape five-character party combat with health/energy portraits and Auto, campaign map/team selection, victory currency/equipment/XP, then a later mission's loot/energy/raid controls and another battle. This independently confirms the bounded party-RPG comparison without establishing absence of tower puzzles across all versions/modes. Times are approximate playback positions, not certified frames. See `../reviews/hero-reference-astra.md`.

## Decision

Make the selected **numbered-room route puzzle** the complete game. The sampled sustained source and official help establish the reference's broader party RPG; they do not establish that tower puzzles are absent in every version/mode. Do not reproduce RPG grind or claim a universal bait-and-switch judgment from four samples. Ad/core mismatch for this selected loop is sufficient to choose the advertised puzzle as the main activity.

## Original design (requirements, not reference claims)

- **Camera and style:** portrait, entire puzzle visible, side-on cross-section of stone/wood towers with large numbered characters and distinct floor outlines. Original masked courier, clock spirits and coastal watchtowers. Slow camera pan only when the level exceeds readable height; no free-roaming 3D arena.
- **Controls and loop:** tap a reachable room or drag courier to it; preview the action, animate the short fight, update power and opened routes, then choose again. Undo one action and restart always available. No reflex demands; a planned sequence drives success.
- **Base combat:** power strictly greater than enemy strength wins and adds enemy strength to power; equality loses and is signposted. Multiple enemies are resolved in displayed order, with a preview that explains intermediate power. This explicit deterministic rule is our design choice. Numbers stay within comfortable mental arithmetic; add shorthand only at later difficulty.
- **Depth beyond smallest-number-first:** doors use visible keys; entering a bridge can collapse the alternative path; a shield can block one trap but prevents taking a power multiplier in the same branch; some rescues must be reached before a one-way door. Optional treasure competes with fastest route. Every rule is visible, introduced alone, then combined. No hidden random combat or purchased rescue.
- **Why the choices matter:** two low enemies may unlock different future rooms; taking the largest immediate gain can strand a key or expend the only shield. A complete solution requires ordering resource/route choices, not merely sorting all enemy numbers.
- **Arc:** 36 authored puzzles in four chapters (about 40–55 minutes), 6 tutorial puzzles integrated into campaign, 4 clear rule families and 4 finale puzzles. Early puzzles 30–60 seconds; later puzzles 2–3 minutes. Unlock chapter for solving its mandatory sequence, with optional challenges never blocking progression.
- **Replay:** optimal move counts, optional treasure/no-undo medals, alternate branches, seeded challenge generator with a solver-verified solution. Campaign puzzles should have multiple sensible near-solutions and a learnable failure; generator is extra, not substitute content.
- **Presentation:** animate power transfer and room ownership, punchy but brief fights, clear danger forecast and tactile selection response. No sexualized rescue imagery, copied characters or copied tower layouts. Original sound cues; reduced motion suppresses shaking while retaining arithmetic/result feedback.

## Acceptance

1. First, middle and final playable recordings remain the H1 interaction: choose a numbered tower room, resolve short fight, visibly gain power and change reachable structure. A party auto-battler or pull-pin game fails this selected brief.
2. Demonstrate a puzzle where greedy lowest-enemy-first is insufficient, a room with ordered multi-enemy resolution, a trap/shield decision, a one-way branch and a clear final rescue/victory. Player can explain the failure using only visible information.
3. Pure rules plus solver verify every authored puzzle is solvable from its advertised starting state, equality handling, key/bridge consumption, multi-enemy order, undo reversibility and no integer overflow. Do not assert unique solutions without exhaustive verification.
4. Input-driven victory, defeat, undo/retry, later-chapter progression and restore after interruption; versioned save/export/import; Android offline launch/resume/update compatibility; text readable at phone size with 48 dp targets. Measure phone performance and fun separately.

## Remaining evidence limits

The official selected ad is old but its URL and visible content were verified now, including independent continuous playback. The sustained recording was sampled rather than exhaustively watched; no claim of late-game RPG coverage. Source validation supports prototype direction. Final fidelity approval still requires comparison with the actual original game's first/middle/final recordings; no implementation or human-pacing acceptance is implied.
