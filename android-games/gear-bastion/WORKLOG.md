# Gear Bastion worklog

Current candidate: [0.3.2 / code 6](DECISION_PRESSURE_CHECKPOINT.md). Earlier versioned records are retained below; the latest entry is at the end.

## 2026-10-17 17:58 America/Indianapolis — 0.2.1 signed build

After the coordinator's Android all-clear, the shared pipeline built clean committed source **7d67a1e**, with unchanged source fingerprints and no dirty project files. Signed official-template **0.2.1/code 3**, target 36/min 24, arm64-v8a+x86_64, no permissions. APK: `.artifacts/gear-bastion/20261017T215725197087Z/gear-bastion.apk`; manifest beside it. Size **57,099,799 bytes**; SHA-256 `f740422926578e6cc5fd340c5a17c698badbd1f43dc07b2054dfd46c04978612`. Only completion documentation changes follow this build.

The coordinator reports the immutable 0.1/code1→0.2/code2 upgrade passed 21 critical saved-state paths, schema migration, subsequent saves and cold relaunch. That result does not cover the 0.2.1 staged-backup amendment. No adb or 0.2.1 Android launch was performed here. Next gate remains the coordinator's narrow review before campaign authorization.

## 2026-10-17 — 0.2.1 narrow staged-backup amendment

Root's independent d13387b probe found that a sole valid `.bak.tmp` was read successfully, then overwritten in place during backup staging. A truncating write failure could destroy the last known good candidate. The fix reuses/renames that staged file when its bytes exactly equal the already-validated prior source; no rewrite occurs. If rename fails, the staged bytes remain untouched. If a later new-save write/rename fails, the prior source is already protected in `.bak`.

Added ten focused checks: normal staged-only load, avoidance of an injected destructive staged write, successful replacement/normal primary load, staged-rename failure with zero writes, and later write/rename failures preserving prior data. Direct rules now pass **107 checks**. No battle, board, input, save-schema or campaign behavior changed. Source version is **0.2.1/code 3**, schema remains 3.

The coordinator's independent nearby-seed probe also narrows the balance claim: A wins only the curated seed 1701 and loses 1700 at 61.07s / 1702 at 51.67s. B and the live-refit strategy win all three; both single-role builds lose all three. This is independently reported d13387b evidence, read from coordinator `.artifacts/coordinator-checks.json`; no balance adjustment was made here. A is not a robust second strategy, and the campaign gate remains held.

Shared validation passed **107 rule checks** and **51 headless input checks / 356 pointer events**, with both completion markers and unchanged source fingerprints. Evidence: `.artifacts/gear-bastion/20261017T215550440176Z/manifest.json`; only completion metadata was updated afterward. Prior rendered UI evidence belongs to 0.2.0; this amendment changes no drawing/input. Exports and adb were held during the coordinator's immutable 0.2.0 upgrade test; the later all-clear/build is recorded above. No 0.2.1 Android runtime acceptance is claimed.

## 2026-10-17 17:46 America/Indianapolis — reviewed fixes and Iron Trial

Addressed the prototype review in the game-owned scope; campaign expansion remains held. APK source version is **0.2.0/code 2**, with stable package/signing and migration from schema-2 prototype saves. Save schema 3 adds ordered revisions and saved production turns.

- Writes check both write and flush errors, then exact readback/validation before rename. The newest valid prior state is backed up before overwriting an interrupted temporary file. Recovery ranks revisions before timestamps and prefers newer valid recoverable temporary progress over older primary/backup data. Write, flush, readback, rename and backup failures have injected regressions.
- All main persistence calls feed a persistent visible failure warning. Save offers export; successful retry clears the warning. Import replacement must succeed before in-memory acceptance; failed import temporary files are unaccepted at next launch. Normal app-written primary save/reload tests are separate from recovery/storage-failure fixtures.
- Full generator buffers dispatch only with current power. Saved stable-ID round-robin turns prevent board-order starvation and display the next ready role at cap. Reversed board order, repeated single vacancies, disconnected buffers, reconnection and all-unpowered vacancy cases are tested.
- Imports reject duplicate actor IDs within/across factions, wrong-faction kinds, nonpositive maximum health and health above maximum.
- Added **one** restricted-board, fixed-54-brass Iron Trial with no kill income. Long-range spitters require screening; armored crowd-cleaving carapaces require ranged support. Refit changes future production for the actual price difference. There is no campaign, new generator family or grind progression in this checkpoint.

### Actual-input trial outcomes at seed 1701

| Plan | Spend | Result | Simulated time | Friendly losses |
| --- | ---: | --- | ---: | ---: |
| A: two guards + two flank ranger generators | 52 | Win, wall 160/160 | 98.17s | 82 |
| B: three gate-screening guards + one supported ranger | 50 | Win, wall 160/160 | 91.03s | 70 |
| C: four guards, all connected; 3.24/s versus A's 2.74/s | 48 | Defeat | 65.63s | 206 |
| R: three rangers + two paid drives, all connected | 54 | Defeat in opening pressure | 23.17s | 45 |
| C repaired at 36s by refitting two generators, keeping connectivity | 52 final | Win, wall 160/160 | 96.47s | 167 |

This is deterministic encounter evidence, not broad campaign balance validation. At repair the all-guard build has lost 44 troops and faces visible carapaces. Both single-role extremes fail; the two mixed plans cost within four percent. All input-suite actions use real touch/keyboard events, with simulation time alone accelerated.

Rules: **97 checks passed**. Shared headless input: **51 checks**, **356 pointer events**, passed. Rendered desktop input: **56 checks passed**, **370 pointer + 5,731 keyboard events**, Dummy audio. Both suites emit `SUITE_COMPLETE: PASS`. Inspected save-error state, both mixed builds, unshielded defeat, connected counter failure, live refit and repaired victory. Frames/reports: game-local `.artifacts/review-playthrough/`. Storage faults are labeled separately from normal primary restoration.

Shared tests: `.artifacts/gear-bastion/20261017T214712692584Z/manifest.json`. Shared build: `.artifacts/gear-bastion/20261017T214754547937Z/manifest.json`. Source fingerprints were unchanged during both commands. The official-template APK is **0.2.0/code 2**, target SDK 36/min 24, arm64-v8a+x86_64, no permissions, signature verified; **57,099,799 bytes**, SHA-256 `dd3bb862182cd213d9947913a99e4b232ba16c4098a83219e97de870d1392f7a`. Only completion metadata was updated afterward. The old immutable prototype artifact was not changed.

No adb/emulator command was issued by this builder. Earlier coordinator 0.1 Android checks do not validate changed code. Different-APK 0.1→0.2 upgrade, changed-code Android lifecycle, real flush failure/durability, physical Fold7 behavior, actual sound, clipboard and phone performance remain pending. Android Back/modal/pause behavior is recorded for the later phone-RC gate; Home/resume evidence does not establish Back behavior.

Next: coordinator/Astra independently reviews this owned checkpoint and runs the real different-APK update test. No full campaign expansion before that gate.

## 2026-10-17 17:14 America/Indianapolis — prototype review checkpoint

Implemented one three-wave tutorial encounter with a fixed portrait battlefield, three-exit wall and continuously interactive powered socket board. Orthogonal core flood fill drives real guard/ranger production; adjacent powered drive levels add 25% each, bounded at 3x. Disconnection stops production. Equal-drive drag merges and one-step move/merge undo are immediate; cancelled and invalid placement retain the old board. Brass prices, forecast, role counter, cap feedback, victory/defeat/retry, pause/speed, original vector/procedural art, synthesized tones, mute/reduced effects, version-2 local saves and a portable JSON dialog are present.

### Verification actually completed

- Godot 4.7.2 imports and launches the scene. Rules suite: **39 checks passed**, nonzero failure exit and `SUITE_COMPLETE: PASS`. Covers graph cycles, capped modifiers, production, resources, rejected placements, deterministic seeded battles, shell counter, army bounds, queued production decisions, active save continuation, corrupt-primary backup recovery and v1 migration.
- Actual input suite, shared headless pipeline: **31 checks passed**, **146 pointer events**, completion marker present. Inputs disconnect/reconnect, change production, merge/undo, cancel an outside drop, purchase, allocate a gate, win with two different layouts, rescue a failing strategy, lose, retry, pause/speed/settings, save/reload and resize a live battle. Game actions use `Input.parse_input_event`; simulated time advances through fixed rule steps.
- Rendered desktop input suite: **34 checks passed**, **156 pointer plus 4,909 keyboard events**. Adds real save-dialog export text and valid/invalid import through typed input. OpenGL compatibility on RTX 5070 Ti; Dummy audio. Inspected onboarding, disconnection, live clash, two army layouts, repair/victory, defeat, portable-save dialog and both Fold7 aspect captures. Frames are viewport captures; letterbox bars outside the viewport are not included.
- A disconnected layout takes wall damage (171/220 at 20 simulated seconds); reconnection during battle wins with 101/220. Leaving the same layout disconnected loses with zero troops produced. This is a connectivity recovery example, not a validated campaign counter-balance study.
- Full-board idle production stays at **120 troops** with one reinforcement buffered per generator. A 120-troop/90-raider headless stress case remained bounded; latest shared desktop sample: 120 rule steps in 522.7 ms, worst step 9.1 ms. These are CPU rule timings, not FPS or phone performance.
- Desktop windows resized during an active battle to **1080 x 2520** and **1968 x 2184**, with state preservation and real gear input checked after each transition. Portrait composition remains centered. Actual phone identity, DPI, safe areas and fold lifecycle are unverified.
- Shared build pipeline exported against the **unmodified official template**, verified signing, package/version, both requested ABIs and absence of permissions. Actual target SDK **36**, min SDK **24**. Coordinator clarified SDK35 was an initial engineering assumption, not a user requirement; the rejected override/custom-manifest approach is absent from source.

### Evidence

- Shared tests: `.artifacts/gear-bastion/20261017T211054429925Z/manifest.json` in this worktree.
- Shared official-template build: `.artifacts/gear-bastion/20261017T211149104303Z/manifest.json` and `gear-bastion.apk`.
- APK: 57,091,452 bytes; SHA-256 `557732780aa69e958b897b78e80feed53f37346697ab49b42acb299422117178`; package `com.dsschiff.gearbastion`, version `0.1.0` / code 1. Signature verified by shared pipeline.
- Game-local rendered logs, PNGs and reports: `android-games/gear-bastion/.artifacts/`. Shared manifests fingerprinted unchanged source while each command ran; milestone documentation was written afterward. Coordinator will independently build the committed checkpoint.

### Limits and next action

Prototype only. No campaign expansion occurred. Await independent coordinator/Astra prototype review before the three-region campaign and replay work. Baseline layout intentionally wins this tutorial; demanding resource/counter balance has not been validated. The initial encounter lasts approximately 80 simulated seconds, not the planned full initial arc.

Physical-phone acceptance remains pending. No game APK was launched on Android in this builder session; no Android background/resume, actual APK update, Fold7 transition, actual sound, clipboard or measured FPS claim is made. Desktop clipboard access reported `Unable to open clipboard`; typed-input import was verified instead. Backup corruption and prior-version restoration are test fixtures; app-owned active-state restoration is separately exercised by input plus scene reload.

Changes are confined to the game directory. No shared scripts, references, root records, docs website, remote branches or publication state were changed. APKs, runtime state, reference material and screenshots remain ignored.
# 2026-10-17 — Campaign core checkpoint, source 0.3.0 / code 4

Nine provisional encounters now form three acts, with restricted sockets, fixed budgets, mixed waves, mortar production, three bosses, progression medals, an ending and a seeded replay menu. Active runs pin content, starting kits, actor statistics, costs and rates; schema 4 stores the independent campaign profile. Schemas 1–3 migrate without inventing clears. Portable saves use bounded gzip/base64 codes. Android Back handling closes a modal, pauses a live defense, then opens the map and saves; physical Android verification remains pending. Local original tones and opt-in render-frame timing capture are implemented; no new FPS claim is made.

Verification at this checkpoint: **156 rule checks passed**, including the independent WIP findings (missing schema-4 profile recovers intact backup, invalid retry kits rejected, nonzero boss HP/scaled actor HP bounded, six-second cooldown saves/restores). Headless actual-input campaign: **56 checks**, all nine clears. Rendered desktop actual input with Dummy audio: **57 checks**, all nine clears plus typed compressed export/import. Total combat was **1,825 simulated seconds (30.4 minutes)**; time is accelerated, not a measured human session. Practice now uses the same active-defense confirmation; cancel preserves state, confirmed replacement clears Undo, and subsequent Undo/save remains valid. Evidence remains game-local and ignored: `.artifacts/campaign-rules.log`, `.artifacts/campaign-headless.log`, `.artifacts/campaign-rendered.log`, `.artifacts/campaign-input/`.

This is an intermediate core checkpoint, not full-game acceptance. The nine default-input wins all preserve the 220-health wall and spend substantial time at the 120-unit cap; broader policy pressure and decision quality remain under review. Nearby seeds, timing variants, single-role baselines, replay wins and encounter-specific mistakes/corrections are still being checked. Scene-dominant illustration, meshed gear portraits, real generator-to-gate staging and early/middle/final motion comparison remain required. No APK export or adb work was performed: the coordinator's performance worker owns that lane. The build section below describes prior 0.2.1 evidence, not a campaign APK.

# 2026-10-17 — Campaign presentation checkpoint, source 0.3.1 / code 5

Completion metadata: source `c9c3011` passed the shared test pipeline (161 rules, 65 full-route input checks) from a clean checkout with unchanged fingerprint `f1df7eac9f7847f5423e7a79cd3ec31614a766d74f2f79760df2c9bab0ff3830`. Shared test manifest: `.artifacts/gear-bastion/20261017T231835942598Z/manifest.json`. After the coordinator's all-clear, official-template export passed: `.artifacts/gear-bastion/20261017T232010721642Z/manifest.json`, APK57,255,454bytes, SHA-256 `91443384b50bd95d96455848b37185f59626229ddac818c96e9f485b225a9bda`, signed0.3.1/code5, no permissions. Source stayed unchanged during export. No adb command was issued. Independent fidelity, current Android and balance gates remain open; this follow-up changes metadata only.

Adapted the coordinator's measured actor-atlas experiment for all twelve original campaign actor kinds. The new open field, touching toothed gears and role portraits replace the earlier campaign graph-panel presentation; preparation expands the board/shop, Menu collapses secondary utilities, and wall arches are the actual exit controls. Production creates saved, capped, untargetable staging actors that visibly march from their source sockets through the arches before combat. Initial enemy timing gives the same travel allowance. Reduced effects preserve role colors and suppress bob/white hit flashes. Original SVG bodies omit baked shadows so the atlas shadow remains independent of bob/flash.

Rules: **161 passed**. Primary input now runs the full campaign and all three replay wins, replacing the legacy-only portfolio entry point; the earlier **51-check** tutorial/Iron Trial suite remains `tests/legacy_playthrough.gd` and passes. Latest full headless route: **65 checks**, **1,026 pointer + 5 keyboard events**, nine campaign and three replay wins. Rendered route: **66 checks**, plus typed compressed import. Atlas: **13 rendered checks** over all twelve kinds and both body/flash rows. Full-route combat: **1,830.93 simulated seconds (30.5 minutes)**. Both approaches win **54/54** current exact-step nearby-seed cases; reduced-budget replay builds win **18/18**, with the weakest replay wall at180/220.

Early, middle and final-boss motion files replay genuine actual-input save snapshots at fixed30FPS; they are visual evidence, not device performance measurements. See `CAMPAIGN_CHECKPOINT.md` and the game-owned evidence index for paths, hashes and limits. No reference pixels or paid assets are used. Campaign source version/code advanced so its next APK is distinguishable from the coordinator's independently verified core0.3.0/code4 APK.

The source remains a review checkpoint. Independent fidelity review, per-encounter mistake/correction and cap/pacing review, current changed-code Android verification, physical phone/fold/safe-area checks and actual sound/clipboard remain open. Static mixed builds currently win Three Fronts and Furnace Tide without reallocation or spending; their advertised decisions are not validated as necessary. Earlier baseline/timing evidence is preserved with its pre-staging scope. No redraw workaround was applied for the withdrawn map-render interpretation. Source edits remain game-owned; no adb/export occurred while held by the coordinator.

# 2026-10-17 — Code 6 bounded decision/HUD/terminal-render candidate

Source 0.3.2 / code 6 is declared before freeze. The campaign retains all nine encounters, three seeded replays and schema 4 saves. Gate 7's snapshot-pinned exit-specific reserve formation prevents a neglected flank being silently covered by the old global idle grid; older snapshots retain their old formation. Gate 8 has denser, shorter late formations and two useful focused ranger-refit spending plans, at 76 and 72 brass. Banking remains a viable alternative. The abandoned splash-heavy expansion is reported as a weaker efficiency choice, rather than forcing a role-specific hard counter.

Actual-input primary route now tests one weak choice plus Retry correction per encounter. **82 headless / 83 rendered checks pass**, with all nine comparisons and all three replay wins. Gate 7 preserves wall 215 versus 81 at the same 82-brass spend; gate 8 saves 20 brass and 78 troops and earns 3 rather than 2 medals. Current rules **164 passed**, actor rendering **13 passed**. Nearby exact-step main-route cases **54/54**, changed-encounter three-second response cases **12/12**; cohort replacement and final-text-only wording differences are explicit in the indexed provenance. Fixed-role/no-production controls are 45 attempts, 4 unavailable-role attempts, 10 wins, 35 losses; no single-role policy clears the whole arc.

Boss health/phase/enrage moved below the wall, and Rally moved beside the board. Natural terminal transitions now request redraw before idle rendering stops; pause/resume notifications also invalidate their changed UI. The standalone rendered regression **10/10 passes** without any post-transition capture redraw. The coordinator independently ran its identical bytes against immutable code 5: exactly the two expected natural victory/defeat paint failures, exit 1, source hash unchanged. This is meaningful sensitivity evidence for the fix; current Android verification remains pending. Headless playback is skipped to avoid a Dummy-audio teardown leak; actual sound remains a separate phone gate.

Corrected combat 1,796.4 s; weak-choice witnesses plus corrections 3,100.5 s, excluding preparation/replays. Corrected cap time 1,288.4 s/71.7% remains an honest pacing/readability warning. No empty wave waits or cap increase were added. New frozen 12 s fixed 30 FPS movies use `.artifacts/campaign-pressure-motion/`, keeping prior code 5 movies/snapshots unchanged. See `DECISION_PRESSURE_CHECKPOINT.md` and both game-owned evidence indexes. All generated UID sidecars are included. No adb or code 6 export was run; the coordinator owns the next independent source/motion/Android checks. No further exploration sweep is needed before that candidate review.

