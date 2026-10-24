# Android portfolio roadmap

The active portfolio goal is defined in `GOAL.md`. Status reflects evidence, not the ambition of a brief.

| Milestone | Status | Exit condition |
| --- | --- | --- |
| M0 Reference briefs | Final selected-reference implementation fidelity accepted for all six; provenance limits retained | Six sourced reference briefs and Astra review; observations separated from assumptions |
| M1 Android foundation | Emulator verified; physical checks pending | Pinned tooling, reproducible test/build commands, working 2D and 3D Android slices |
| M2 Gear game | Software candidate ready for phone testing; exact code6 Android update, natural win/loss and Retry independently verified | Complete game, progression, replay, presentation and verified APK |
| M3 Hero puzzle game | Software candidate ready for phone testing; authored/generated routes, exact code4 update and native Back/clipboard/resize verified | Complete reference-based puzzle game and verified APK |
| M4 Chained-weapon action game | Conditional software candidate ready for phone testing; native transfer/update verified; physical IME gate explicit | Complete chained-weapon combat/resource-upgrade/exploration game and verified APK |
| M5 Settlement defense game | Conditional software candidate ready for phone testing; ten-map campaign reviewed, actual1-to2/native outcomes/transfer/active lifecycle verified | Complete movement/build/defense game and verified APK |
| M6 Frontline military game | Conditional software candidate ready for phone testing; twelve missions reviewed, actual update/core outcomes/transfer/Back/active lifecycle/resize verified | Complete reference-based military interaction game and verified APK |
| M7 Zombie survival game | Conditional code3 software candidate ready for phone testing; native outcomes/platform, camera correction and whole-earned-save update independently verified | Complete reference-based shooting/survival game and verified APK |
| M8 Portfolio acceptance | Six software candidates; physical portfolio checks pending | Six independent reviews resolved, update compatibility, physical-phone checks and delivery index |

## Functional baseline next actions (superseded by graphics stage below)

1. Final selected-reference implementation fidelity is accepted for all six in `android-games/reviews/portfolio-final-fidelity-astra.md`. Exact commercial equations, advertiser provenance and human pacing remain qualified; physical acceptance remains separate.
2. Keep verified foundation/prototype evidence landed. Physical Samsung checks remain separate from emulator evidence.
3. Keep Gear's verified code6 software candidate frozen for physical-phone testing. Dense/cap-heavy formations, human fun, audible sound and measured physical-phone performance remain explicit limits.
4. Keep Tower's accepted code4 software candidate frozen for phone testing. Required seeded Challenge and prior authored/full-rule checks remain verified; Back correction passes independent67/71checks and review. Actual3â†’4 preserves every prior save field exceptrevision, including generated snapshot/record and separate campaign. Native modal Back/clipboard/Home/cold/cover-inner emulated resize pass. Human pacing/fun and physical Fold7 touch/folding/safe areas/sound/performance remain open.
5. Keep Hook's conditional code4 candidate frozen. Actual update and native typing/rejection/transfer/lifecycle checks pass; physical on-screen IME and other phone checks remain required.
6. Keep Hearthguard code2 conditional candidate frozen for phone testing. Independent full campaign headless/Astra and actual1-to2/native loss/Retry/win/transfer/active resize/cold pass. Windows clipboard failures remain separate; native clipboard success does not erase them. Physical IME/touch/folding/safe areas/sound/FPS and human pacing/fun remain required.
7. Keep Frontline code2 conditional software candidate frozen for physical testing. Actual update, paid victory, separate natural loss/Retry, real clipboard import/rejection, native Back, settings, active Home/cold and cover-inner resize pass bounded review. Later rejected previews have identical clear nonuniform PNGs; earlier actual graphics failures remain separately retained. Keep Dead Run code3 frozen: camera P2 closed, real2-to3 whole-earned-save retention and unfolded live field verified. Inherited code2 win/loss/Retry/progression/transfer/Back remain retained. Six phone-test candidates are frozen.
8. Thread/worktree mapping is in `android-games/threads.json`; executable evidence is indexed under `android-games/evidence/`.


## Active graphics stage

| Milestone | Current state | Exit condition |
| --- | --- | --- |
| G0 Closeout | Complete: six old chats archived, handoffs retained | Six old chats archived; source/saves/evidence retained |
| G1 First pair | Complete: Gear 0.3.3 fit delivered; bounded Frontline 3D benchmark accepted in all eight categories | Actual playable 3D quality reviewed; save-compatible Gear sizing update |
| G2 Full presentation | Gear and Hearthguard original3D/native updates complete; Frontline pooling + art-direction pass built as 0.3.1/code4 and emulator-verified (independent review of the art pass open); Hook original 3D frozen as 0.3.0/code5 with Android lighting matching desktop (independent motion review open); Dead Run original 3D frozen as 0.3.0/code4, then the approved horde pass (rule3: dense packs, pre-boss surges, crew cap 49, multiply gates) frozen as 0.4.0/code5 with drag steering through a surge confirmed on the emulator (independent visual review and phone surge frame rate open); Tower Trials original 3D frozen as 0.4.0/code5 with Android lighting matching desktop and a real room tap plus Enter (courier fight shown) confirmed on the emulator (independent visual review open). All six games now have graphics candidates | Complete Frontline+Gear, Hearthguard+Hook, DeadRun+Tower with original modeled actors/environment and real animation |
| G3 Graphics delivery | Frontline0.3.0, Gear0.4.0 and Hearthguard0.3.0 private bundles ready; Frontline0.3.1/code4 genuine code3-to4 emulator update passed, in `graphics-20261021` bundle; Hook0.3.0/code5 genuine code4-to5 emulator update passed, same bundle; DeadRun0.4.0/code5 horde pass replaces 0.3.0 in the same bundle: genuine code4-to5 update keeps a road in progress under its old rules (Retry starts the horde road) and genuine code3-to5 update moves an unstarted road to the horde rules; Tower0.4.0/code5 genuine code4-to5 emulator update passed, same bundle | Six reviewed higher-version APKs, genuine update retention, emulator/layout checks and before-after clips |

The current work is `android-games/GRAPHICS-OVERHAUL.md`; status/ownership is in
`android-games/graphics-overhaul.json`. Additional phone testing is deferred by
the user and cannot block G0â€“G3. Existing baseline approvals do not establish the
new visual standard. Keep screenshots, normal-speed motion review and measured
frame timing distinct from headless correctness and physical/human acceptance.

### Next actions (2026-10-22)

1. Historical save-durability finding: Dead Run lost both slots after an emulator
   shutdown. Current main now calls `FileAccess.flush()` in all six writers; that
   source change is not hard-power-loss evidence. Verify current interrupted-write
   recovery and kill-after-save behavior before claiming closure. See
   `android-games/evidence/dead-run-hordes-candidate.json`.
2. Independent visual/motion review and before/after clips for Frontline 0.3.1,
   Hook 0.3.0, Dead Run 0.4.0 and Tower 0.4.0 (G2/G3 exit condition).
3. Small fixes: Dead Run extra Resume button after Home on a finished road and crew
   drawn inside the blockade on defeat; Hook dock-label outline and Android joystick
   movement evidence; Frontline HQ partly behind bottom controls; Tower overlapping
   pops in busy rooms; Dead Run windowed presentation run leaks textures at exit.
4. Deferred by Daniel: Fold7 phone testing, phone surge frame rate, human difficulty.


## Active continuous design cycle (2026-10-23)

Authoritative priorities and acceptance: `android-games/DESIGN-CYCLE.md`.

| Milestone | Current state | Exit condition |
| --- | --- | --- |
| D0 Baseline | Current origin/main 4552e7b inspected; six release-signed APKs exist; old status records lag current source | Current baseline and explicit unresolved gates recorded |
| D1 Leading pair | Frontline0.3.2 privately delivered; Dead Run source fixes and strict54/0 harness correction reviewed; signed0.4.1 privately delivered after bounded motion/native clearance | Actual input and independent review support one meaningful private update per game |
| D2 Portfolio | Gear0.4.1, Hearthguard0.3.1, Hook0.3.1 and Tower0.4.1 privately delivered; bounded feedback/motion/save/native checks verified | One meaningful verified design-and-polish release per game |
| D3 Cloud recovery | Reviewed native cancellation31JVM/27codec plus60 real-decoder checks; Frontline optional UI151/0 and native local recovery reviewed; configured account sync unverified | Offline-safe optional cloud path and genuine account/device sync verified; external blockers explicit |
| D4 Delivery | Existing private Obtainium path retained; Play account identity/phone pending as of live2026-10-24T04:01Z check; owner-only Tower Drive handoff verified | Higher-version signed private updates retain real progress; Daniel-only Play testing when available |

Physical/human acceptance remains separate. Development continues while account
verification, independent visual review or phone feedback waits.

- Qualified unpublished refinements: Frontline0.3.4/code8 and Hook0.3.2/code8 signed7to8,19 whole-context comparisons and264 pins clear. Tower0.4.2/code8 earned7to8/claim/cold plus bounded native1x association clear. Optional cloud remains unconfigured; Gear local Import durability prerequisite active. See cycle evidence for exact manifests and fixture limits.
