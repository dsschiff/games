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

### Gear fix checkpoint and reopened recovery gate

- Integrated worker `d13387b` as `a0e59d7`: schema3, APK0.2.0/code2, fair powered dispatch, surfaced save errors, tightened import validation and Iron Trial. Builder reports 97 rule, 51 headless-input and 56 rendered-input checks. Independent shared rules/input tests pass against clean source `7b9c7320713f3dd90ddd595c887498a68b69d6dce3ebafae91bc1bcc3cffbf37`; Android upgrade evidence is being collected against this immutable source.
- Astra's initial static/visual gate approval was superseded by a coordinator fault probe: when `.bak.tmp` is the sole valid save, attempting to rewrite it during backup preparation can destroy it on partial-write failure. Astra confirmed this P2. Worker is preparing a narrow 0.2.1/code3 fix and preservation regressions; campaign expansion remains held until that fix passes.
- Coordinator tested fixed plans at three nearby seeds. A wins1701 but loses1700/1702; B and the paid adaptive repair win all three; both single-role extremes fail all three. The 50/52-brass plans are comparable resource witnesses, not two robust policies. Raw fault/seed evidence is indexed in `android-games/evidence/gear-fix-adversarial.json`; review amendment is in `android-games/reviews/gear-fixes-astra.md`.

### Real version0.1 to0.2 Android upgrade passed

- Independently rebuilt immutable `a0e59d7`: signed APK0.2.0/code2, permissions[], SHA256 `59014f306a288c79b8945922048a7b9aa6b9e47ed0b115dd961a96ed0dda5f9c`. Clean test/build source fingerprints match; 97 rules and 51 input checks pass.
- Installed old code1, created the boosted-board/eight-troop battle by actual Android input, captured its schema2 save, installed code2 over it without clearing data, then launched/persisted and cold-relaunched. All 21 declared critical gameplay/settings paths survive; schema migrates2→3 and new revision advances2→4. Advancing file modification times/inodes and new schema establish actual new-app writes.
- Coordinator independently checked raw saved JSON, archive hashes, metadata, preservation assertions and inspected the restored paused battle capture. No runtime errors or adb failures occurred in this upgrade run. Exact evidence is indexed in `android-games/evidence/gear-upgrade-0.1-0.2.json`.
- This validates the normal update path for this prototype pair; pending sole-staged-backup preservation fixes and actual device storage faults remain outside it. No physical phone claim. Emulator remains1080x2400; builder export hold released for the narrow0.2.1 fix.

### Preservation fix verified; full campaign authorized

- Integrated narrow worker fix `7d67a1e` as `8ba1294`, then metadata-only `034e7f3` as `49bee21`. Matching valid staged backup bytes are promoted without reopening them for truncation. Ten added assertions cover sole-candidate load, avoided rewrite, failed promotion and failed subsequent primary writes/renames.
- Coordinator independently passed107rules/51input checks against clean unchanged source `0ebee54a139c678488f0f4e6149994497b9dc541a5ba17996a6664c1198ced13`. Astra's narrow static re-review confirms the fix and closes the gate upon that execution result. The previous reopened P2 is resolved; actual device storage-fault durability remains untested.
- Authorized the persistent Gear builder to implement the complete three-act campaign, distinct mortar role, progression/endings, seeded replay/medals, profile/run saves, navigation and presentation under the reviewed architecture. No new game chats yet; Gear remains first. Latest0.2.1 Android verification runs against the immutable coordinator checkout while campaign work stays isolated.

### Latest patch Android migration and comparison precision

- Clean independent0.2.1/code3 test/build source is `38e5f0c35b66cfb18983d14b0614b01a500e258b7aefe42960d7ba938f9d5aec`; signed APK SHA256 `063c4c36046c7cae2f362bb949391ae47f1823c5086ff257702bcf68ce6c9a60`. Rules107/input51 pass against the matching unchanged source.
- Initial exact semantic comparison correctly flagged four fractional JSON round-trip differences (positions, production and spawn clock), maximum absolute change5.7e-14. The failed packet is preserved. Reviewed verifier now permits only fractional-float noise within relative/absolute1e-12; integer-valued numbers, booleans, list order and material differences remain strict. Coordinator independently passed all47tooling tests, including meaningful-change and large-adjacent-integer rejection.
- The real old-code1 to new-code3 upgrade passed with all21declared gameplay/settings paths preserved, schema2→3, actual new-app persistence and cold-relaunch stability. Coordinator independently inspected raw JSON, source/test/build links and APK archives. Exact policy, hashes and limits are in `android-games/evidence/gear-upgrade-0.1-0.2.1.json`.
- Actual touch-driven Android trial outcomes are next. One fixed60-second emulator wait reached battle time86.63 rather than victory; the failed deadline packet is retained and the same encounter continues with bounded waits. This is not a phone FPS result. Full campaign source remains in the builder's separate worktree.

### Android trial outcomes and current handoff

- Actual Android mixed-plan A victory is verified from real app-written JSON and a rendered capture: wall160, spend52, 202troops produced, 66kills, army120, no enemies. The initial60-second deadline and first20-second continuation failed to reach victory and remain failed packets; a further10-second continuation finished the same encounter at simulation98.17s. Cold lifecycle reinstallation reset speed to1 during continuations. The adjusted80-second fresh A fixture is prospective, not replayed end to end.
- Fresh actual-input C fixture ran end to end and verified defeat at simulation65.63s, wall0, spend48, gold6. After preserving defeat evidence, a real Retry tap restored Iron Trial/ready, 54brass, wall160, initial core+drive and empty actors/production. Retry checked22exact fields plus revision and board count.
- Coordinator independently inspected victory/defeat/retry images and raw saved JSON and verified source/fixture hashes. C and Retry runtime logs report no errors. A continuations lack separate post-continuation logcat; initial smoke logs are retained. Evidence and precise limitations are indexed in `android-games/evidence/gear-android-outcomes-0.2.1.json`.
- Android execution is idle and emulator geometry restored1080x2400. Full campaign builder remains live and has begun data/profile/menu integration plus policy sweeps. Initial draft guard spam and long cap-idle periods were caught as exploration failures, not accepted content. All five other game implementations remain unstarted under the staged plan; physical-phone checks remain pending.

### Canonical artifact preservation

- Preserved95selected files (331.6MiB) from the coordinator worktree to the canonical games checkout's ignored `.artifacts/`, retaining relative paths. This includes the original0.1APK, latest0.2.1test/build, successful/strict-failed upgrade packets, actual trial/Retry evidence, and original executed fixture bytes. Every copied file was SHA256-checked; conflicting existing bytes would abort rather than overwrite.
- Receipt: canonical `.artifacts/preservation/gear-bastion-0.2.1.json`, indexed in `android-games/evidence/gear-artifact-preservation.json`. APKs, runtime saves and signing secrets remain outside tracked source; no signing material was part of this copy. These are prototype checkpoints, not final six-game delivery.
- Full campaign work continues in its isolated task. Independent Gear footage comparison, bounded Butcher interaction research and emulator-only heavy-render diagnostics are running; none is a physical-phone acceptance claim.

### Heavy rendering diagnostic and isolated experiment

- Immutable0.2.1/code3 was measured on the generic API35 emulator using its actual SurfaceView presentation layer. Ready/no-actor state presented435frames at38.711fps; an injected copy of the earlier120-unit victory save presented46frames at3.740fps. Each bounded capture lasted approximately11.4seconds. This injected fixture supplies performance state only, not new gameplay or migration evidence.
- Heavy idle victory skips combat simulation. Its GL thread saturated one guest core while composition latency stayed approximately7-11ms, so combat target searches alone do not explain the slowdown. Exact script/engine/emulated-driver/host-GPU costs remain unmeasured. FrameTimeline had zero coverage; no jank or phone-performance acceptance is inferred.
- Coordinator checked the raw per-layer frame totals/FPS and preserved69files (2.8MiB) under the canonical checkout's ignored `.artifacts/performance/gear-bastion-0.2.1-20261017/`. Summary, hashes and preservation receipt are indexed in `android-games/evidence/gear-performance-0.2.1.json`. Ready state,1080x2400geometry and disabled tracing were restored.
- Assigned a bounded isolated experiment from49bee21 in `games-gear-perf-20261017`: cache original troop artwork while preserving120actors, simulation and display resolution. Compare real presentation evidence against the unchanged prototype; do not substitute idle redraw throttling for active-battle performance. Full campaign logic/content continues in its separate builder task while emulator access is reserved for the experiment.

### Direct reference comparisons and campaign correctness review

- Astra directly compared bounded Gear promo/preparation/combat checkpoints with the actual0.2.1 Android captures. Core direction stands; closer visual fidelity requires a larger illustrated battlefield, mechanically meshed gears with role identity, actual production-to-gate marching, clearer silhouettes/crowd spacing and unclipped guidance. Full requested late-wave footage was unavailable after one checkpoint because of the streaming service's simultaneous-playback limit; no continuous40-second inspection is claimed. Full report is `android-games/reviews/gear-footage-comparison-astra.md`; requirements sent to the campaign builder.
- Butcher's settled official-promo follow-up clearly supports combat resources buying weapon/power upgrades and restoring health:30→5currency on a25cost pad and79→4on a75cost pad. A chained blade extends visibly; distinct enemy reel/consumption/permanent player enlargement remains unresolved. Withdrew the pale-giant player-size attribution. Updated only its brief/index entry; hook/reel remains a permissible labelled original choice, not a mechanic Daniel specifically supplied or a certified visual observation.
- Builder reports a first actual-input route through all nine provisional encounters to ending/replay, approximately30.4simulated minutes at1×. This is WIP timing evidence, not human pacing/fun or release acceptance. Exact-step/nearby-seed policies, cap-heavy pacing, rendered readability and full campaign Android checks remain open. Astra is inspecting an immutable20-file WIP snapshot for consequential save/snapshot/migration errors before checkpoint freeze; source remains exclusively builder-owned.

### Campaign pre-freeze correctness findings

- Astra completed static review of the20-file frozen WIP and identified fourP2s: unguarded Practice discards an active run/retains Undo; schema4 missing-profile fallback can erase progression; malformed accepted starting kits produce invalid Retry boards; imported/future configuration bounds can produce unsaveable cooldowns/zero-health bosses. Current catalog is unaffected by the last bounds cases. Report: `android-games/reviews/gear-campaign-wip-correctness-astra.md`.
- Coordinator reproduced Practice/Undo in the copied snapshot through production action handlers with a valid fixture: camp09nextID7 became tutorialnextID6 without confirmation, retained six Undo pieces and then failed save decoding with `Invalid piece sequence`. This is logic-level reproduction, not actual-input/Android evidence. The helper's exit cleanup warnings and corrected initial fixture accounting are recorded; production source was untouched.
- Sent all findings and concrete regression expectations to the campaign builder before freeze. Earlier backup-preservation/import/revision/actor-ID fixes remain resolved. Campaign milestone remains in progress; these new findings require correction/verification before acceptance.
- Further root snapshot probes confirm missing-profile revision9 displaces an intact revision8 progression backup; all three malformed starter variants import then fail Retry save validation; accepted period6 attacks create an invalid cooldown save after an actual battle tick. Zero-boss-health config/import acceptance was confirmed without executing the zero division. Evidence is logic/configuration-level and indexed in `android-games/evidence/gear-campaign-wip-review.json`; no live-builder source or emulator state was touched.

