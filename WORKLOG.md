# Android portfolio worklog

## 2026-10-17 Goal activation and foundation

- Daniel approved the six-game staged plan, instructed use of the existing games repository, authorized implementation and Astra consultation.
- Activated the coordinating Codex goal. Created isolated branch `codex/android-portfolio` from `origin/main` at `5df7e1b`.
- Existing hub is plain HTML/CSS served from `docs/`; no game-source or Android tooling existed in this repository at activation.
- Node and Java are available. Godot/adb were not on PATH; standard Android SDK/Studio locations were absent. Tool installation and device testing remain unverified.
- Research, Android foundation and per-game milestones will record actual commands/build hashes/evidence as they finish.

### Verified desktop probes and first game task

- Portable Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`) installed with official SHA512 verification by the toolchain worker. Android export templates and SDK setup are underway.
- Both probe rule suites pass. Save tests exposed JSON integer/float restoration differences; restores now normalize whole-number fields and tests cover restored placement duplicate detection and continued encounter behavior.
- Both input-driven playthroughs pass using `Input.parse_input_event`, including 2D placement/win/lose/pause/retry/reload and 3D drag/release/pause/full encounter win/reload/retry. Commands: Godot `--headless --fixed-fps 60 --path <probe> --script tests/playthrough.gd` with isolated child-process APPDATA.
- Rendered desktop playthroughs also pass; inspected PNGs in ignored `.artifacts/visual/`. These are technical probes, not six finished games, ad-fidelity validation or phone performance evidence.
- Desktop graphics use the NVIDIA OpenGL Compatibility renderer. Restricted-context WASAPI audio failed and fell back to Dummy; actual sound output is not yet verified.
- Gear Defenders reference uses the official store-linked promotional creative and sampled sustained footage. Astra's interpretation review cleared the prototype with explicit mechanical rules and fidelity limits, recorded under `android-games/reviews/`.
- Created persistent Sol High game task `01a14b9d-90d7-73c1-9fd4-9b74cbda3fa9`, exclusive `android-games/gear-bastion/` ownership in separate branch/worktree. It must produce a reviewable prototype before broad campaign construction.

### Device target and standing authorization

- Daniel supplied "Samsung ultra fold 7" and "I give permission for all." Working target is Galaxy Z Fold7; actual connected model and OS remain unconfirmed. Official Samsung profiles are recorded in `android-games/device-target.json`.
- Carry authorization through setup, coordination, builds and validation without repeated routine approval questions. Keep paid services and public/store publication outside the approved plan.
- Require cover/unfolded readability and progress-preserving resize/fold transitions. Emulator results remain distinct from physical Samsung testing.

### Android foundation verified on emulator

- Shared installer, project discovery, source-fingerprinted tests/builds and emulator smoke commands are implemented. Final 25 tooling tests pass. Missing suites and incomplete completion markers fail coverage; source drift invalidates a result.
- Both technical probes pass rule and actual engine-input suites, export signed APKs with no requested permissions and unchanged matching source fingerprints, and run on API35 emulator `emulator-5554` with host NVIDIA graphics. SwiftShader failed real shader limits; this host uses `-gpu host`.
- Each probe passed emulator input, offline launch, app-written JSON state assertions, background/resume and byte-identical save retention across same-APK reinstall at both 1080x2520 and 1968x2184. Resolution overrides were restored. Exact artifact/source hashes and four smoke runs are indexed in `android-games/evidence/foundation.json`.
- Same-APK reinstall is installation-retention evidence, not different-version save compatibility. No physical device is attached; Samsung safe areas, folding lifecycle, sound, actual touch, fun and measured FPS remain unverified.
- Godot uses unmodified official Android templates: actual target SDK36, min24. Installed SDK35/build-tools35.0.1 successfully sign standard APKs. No custom template patching, Windows feature changes or global PATH changes are required.
- Gear builder committed prototype `d0e7cce`: 39 rules, 31 headless-input and 34 rendered-input checks reported; one tutorial encounter, not a full campaign. Independent Astra source/visual review and coordinator Android checks are underway before campaign expansion.

### Prototype interpretation and Gear review gate

- All six sourced prototype directions now have Astra interpretation review. Butcher/Top Force acceptance wording was corrected so deferred original features cannot silently become mandatory. Dead Run preserves the large sustained-fire side target during ordinary road action. Continuous causal footage passages and final implementation comparisons remain open.
- Gear prototype integrated as `17386c6`. Astra's static/visual review passes the real gear-production loop and composition, but holds unrestricted campaign expansion for surfaced/atomic save failure handling, powered/fair buffered dispatch, import validation and a meaningful constrained-budget counter challenge. Exact findings are in `android-games/reviews/gear-prototype-astra.md` and have been sent to the builder.
- Independent Android inputs demonstrate disconnected guard production at 0/s, reconnect at 0.72/s and adjacent-drive boost at 0.90/s, followed by real troop production and pause. Lifecycle/geometry evidence is being finalized separately; this is still a one-encounter prototype.

### Landed checkpoint and independent Android prototype evidence

- Foundation/reference/prototype/review checkpoint `57d0daa` landed on `origin/main`; fetched ancestry and identical local/remote heads verified. `docs/` is unchanged from the starting commit. Canonical checkout independently passed all three projects' rule/input suites with matching source fingerprints, plus 25 tooling tests at that checkpoint.
- Subsequent narrow smoke-tooling improvement adds nested dictionary/array expectations and removes vacuous success flags for absent expectation groups. Final 32 tooling tests pass independently. Gear's fixture asserts 8 exact saved fields and 3 numeric ranges.
- Immutable Gear prototype `d0e7cce` / integrated `17386c6`, source `4ae244a7a75f35dfa448c6304e18f7057ff88d03bb2a83d9856cc0496d2df899`, independently rebuilt and Android-tested. Its signed APK requests no permissions. Two exports differ in whole-file packaging/signature bytes; all 118 uncompressed ZIP payloads match. Details and actual hashes are in `android-games/evidence/gear-prototype.json`.
- Both final geometry smokes pass nested saved-state assertions, offline launch, background/resume and same-APK retention. One intervening adb-offline run failed and is preserved; the cause remains unconfirmed. Device recovered and one bounded retry passed. Emulator restored to 1080x2400. Coordinator inspected the inner-screen actual rendered game capture.
- These results cover the immutable tutorial prototype only. Builder's newer save/dispatch/challenge edits need a fresh committed checkpoint and re-review. Next APK should be version0.2.0/code2 for a real different-APK upgrade from the input-created version0.1.0 save. Physical Samsung testing remains pending.

### Bounded reference follow-up and timing correction

- A four-passage follow-up found that immediate screenshots after video seeking can retain stale decoded frames despite changed player time. All six briefs and index now qualify original millisecond annotations as seek/read positions, not certified frame timestamps. Separately settled checkpoints take precedence where interpretations conflict.
- Gear's preparation-piece change followed by Battle, a displayed 0.2/s rate and troop output is corroborated; exact merge contact/formula remains unresolved. Kingshot's wallet collection, pad funding and completed firing tower are corroborated, while exact debit is obscured.
- Last Human's sustained side-target counter reduction and harmful gate crossing are corroborated. The earlier +1/recruit reading is withdrawn: the settled crossing reduces the squad. Positive recruitment and precise arithmetic remain inferred original prototype rules pending observation. Butcher's inspected passage does not isolate hook/reel/consumption/permanent growth, and the brief preserves that open evidence.
- Gear fix builder remains live. Its rule-level trial reports two equal-cost winning approaches and a connected but inappropriate build that loses; actual input, rendered evidence and an immutable checkpoint are still required before re-review. Shared tooling work now prepares a real different-version APK upgrade verifier; no newer game behavior is claimed verified yet.

### Upgrade verifier prepared

- Implemented an emulator-only different-APK verifier, with signed/offline matching packages, strictly increasing actual APK codes, archived input hashes, old-version real input and saved-state assertions, install-over-existing transition, declared semantic-path preservation, new schema and actual persist evidence, cold relaunch and runtime logs. Initial test-data reset requires an explicit flag and occurs before the old save exists; the upgrade boundary does not clear or import data.
- Coordinator inspected source and independently passed all 44 tooling tests. Source/unit tests do not establish a successful Android upgrade. Execution waits for the builder's next immutable version0.2.0/code2 checkpoint with save schema3.
- Added a separate Android Back release check to development guidance, grounded in Godot4.7 documentation. Home/background smoke coverage does not imply system Back coverage; no actual Back-related progress loss is claimed.

