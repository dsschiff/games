# Gear Bastion worklog

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
