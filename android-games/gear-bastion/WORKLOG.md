# Gear Bastion worklog

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
