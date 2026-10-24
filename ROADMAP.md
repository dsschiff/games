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

- Play preparation follow-up: reusable locally signed AAB pipeline qualified on
  Tower0.4.2/code8 with101/0 tooling checks and independent raw-artifact review.
  Existing signing identity retained. Account verification, separate upload-key/
  Play App Signing setup and genuine Play acceptance remain open; no upload.

- Gear0.4.2/code11: bounded native update/recovery now audited16/0 owning-context
  comparisons; strict shader-warning gate failed. Initial capture stall is retained
  as a separate failed attempt. New builds await retry-marker regression/fix. No upload.

- Hook local Import recovery and terminal bootstrap/commit source are CPU/source
  reviewed, including independent871/0 +12/0. Existing0.3.2 APK unchanged. Next:
  arena identity correction landed; equivalent retry-marker safety comes before new build/native recovery.

- Hook arena score identity source/CPU correction complete: historical aliases
  and best scores preserved, root188/0 and independent review clear. New signed
  candidate/native update awaits retry-marker safety. Selected best-clear feedback
  is now source/CPU reviewed573/0; no new binary or native display acceptance.

- Gear code11 bounded native update/Import/both recovery choices are independently
  audited16/0 owning-context comparisons; strict engine warning gate remains
  failed. Read-only recovery copy buttons pass source/root386/0, native export
  pending. New APK builds held while equivalent retry-marker regressions/fixes
  follow a newly reproduced Dead failure. No upload or phone acceptance added.

- Dead whole local recovery source/CPU clear with independent53/0+7/0; full
  campaign/legacy/bullets/profile/settings retained and retries freshly validate
  every marker/copy. Direct pending export usability and new signed native
  candidate remain next. Existing0.4.1/code7 private APK is unchanged.

- Frontline recovery retry admission source clear: every current marker/copy
  validated before each choice. Root107/0 helper and26/0 actual-input/fresh-owner
  checks pass using existing cache; earlier worker cache failure retained.
  Higher-version signed/native candidate remains next;0.3.4/code8 unchanged.

- Hook marker retries now freshly verify every surviving record and complete
  archived code. Root172/0 and source/evidence review clear; existing871/188/573
  recovery/arena/feedback regressions pass. New signed/native candidate next.

- Gear0.4.3/code12 local signed candidate now independently audited for bounded
  update/Import/recovery/copy behavior:10 owning-context comparisons/0,7 pending
  and7 cleared markers,2 exact whole-code clipboard copies. Retry-marker source
  root437/0 clear. Shader warning still fails strict log gate; rendering, real
  storage interruption, physical/cloud and exact private transfer remain open.

- Dead direct retained-code Copy controls now independently source/CPU reviewed,
  root434/0 actual-touch checks pass. Signed0.4.2/code8 packaging/source clear;
  actual native7to8/full-context/Copy and transfer gates remain open. Existing
  private0.4.1/code7 stays available; no newer upload.

- Tower whole local recovery source/CPU reviewed: root608/0 with208 actual touch
  events. Complete campaign/challenge/parked data and uncertain animation gated;
  verified choices adopt paused. New signed/native/OS clipboard checks remain.

- Hearth complete local recovery source/CPU independently reviewed: root874/0,
  338actual touch events. Stable feedback layout and standalone missing-UI
  adoption corrections verified; historical failures retained. New signed/native/
  rendered/OS clipboard checks remain;0.3.1/code5 unchanged.

- Dead0.4.2/code8 native update/recovery passes14 full-context comparisons/0,
  10pending/10cleared journals and both actual Android-app Copy/Paste/Import
  roundtrips. Original battle/ten bullets restored, owned emulator closed. Sealed
  packet independently audited; shader-warning and external large-code clipboard gates
  remain failed/unresolved. No upload.

- Hook0.3.3/code9 signed local candidate built from reviewed recovery/marker/
  arena feedback source. Actual APK/source/signer/raw logs independently clear.
  Native8to9/full-context choices/clipboard/readability next; no upload.

- Tower named medal feedback source/CPU independently clear:793/0 root repeat,163 actual taps/326 touch events; this-clear vs collected/best and eligible Journey goals preserved. Normal rendered/native readability, higher signed/native candidate and human comprehension remain next.

- Hook0.3.3/code9 bounded native packet independently audited24/0 whole contexts,7pending/21cleared markers, four selected arena score views and full original restoration. FirstExport false-unavailable feedback, missing pendingCopy/View and strict shader-warning remain open; physical/cloud/real interrupted storage unverified.

- Hearth held build-range preview source/CPU independently clear:root1111/874/44,366actualpreviewevents, strict clean/stable source. Exact pinned base range, ordinarytapbuy and context/multitouch cancellation preserve rules/saves. Matched normal1x rendered/native usefulness and higher signed candidate remain next.

- Hook clipboard confirmation and exact retained pendingCopy/View source+packaging reviewed. Root42/1028/871strictclean; signed0.3.4/code10 prepared at8ede5cd withsame2527signer. Actual native9to10/firstExport/pendingCopy/View/wholecontexts next; no upload.

- Hearth matched preview capture harness source/CPU independently clear:exact17/17opening and22/22boss contexts/input/frames/bytes,76artifact audit. Rootnormal1x serialrender before/after and pixelusefulness next; historical recipes failclosed, no runtime change.

- Prepared Hearth0.3.2/code6, Tower0.4.5/code11 and Frontline0.3.5/code9 from reviewed source with metadata-only version changes. Independent actualAPK ZIP/signature/metadata/source/pipeline/config/raw-log review CLEAR; same2527signer, no permissions/nondebug. Local candidate paths/hashes indexed without changing delivered URLs. Hearth genuine5to6/Home/cold preserves whole state/profile/settings/campaign in5comparisons/0; old and new native logs both retain cached-shader warning, so strict native gate FAIL. Normal Import/recovery-choice/OSclipboard, Tower normalCopy/Frontline retry native, physical/cloud and exact upload gates remain open. See evidence/recovery-signed-candidates-20261024.json.

- Frontline 0.3.5/code9 now has independently reviewed native update/recovery evidence: 37 complete-context comparisons, 13 read-only admission replays, and five rejected choices with all 14 files and owner PID unchanged. Both healthy choices and the normal 8,248-byte Paste/Import route retain the whole chosen context; the original Switchyard save and nine archives are restored. The cached-shader warning still fails the strict native gate. Explicit fixtures, empty parked/skirmish fields, renderer failures and native storage-fault limits remain qualified. New Dead multiplier and Frontline recap/Journey feedback source passes independent CPU review; normal-rate rendering and later signed candidates remain next. No upload. See evidence/frontline-native-marker-20261024.json and the game checkpoints.

- First-pair presentation cycle: matched normal-speed desktop review exposed an unreadable Dead multiplier caption; shorter fractions and contrast now distinguish partial charge, applied multiplier and earned threshold. The independent analog-bar cue remains unproven. Full 2,734-tick/28-input gameplay and raw-save parity is preserved; 396 fixture checks and matched 18/18 route checks pass. Frontline recap, Journey and latest-clear matched passages pass 38/38 with complete state/input/save parity and bounded visual review. Local signed Dead 0.4.3/code9 and Frontline 0.3.6/code10 include these reviewed changes; actual APK/source/signature/raw-log audit is independently clear; details are in evidence/first-pair-rendered-20261024.json. No newer upload; Android update/presentation, strict cached-shader warning, physical/human and cloud gates remain open. Retained movies/stills and exact cleanup manifests preserve the evidence after 4,018 redundant PNGs (1,936,005,579 bytes) were removed.

- Android update/touch cycle: Dead 8to9 retains the whole ten-bullet campaign context in7 comparisons/0; a separately settled same-process Home pair is readable, with earlier black/splash observations retained. Frontline9to10 retains whole context4/0 but real row-body swipes exposed a Journey usability defect missed by wheel-only proof. A single row input-filter correction passes172 focused checks and signed0.3.7/code11 packaging; actual10to11 swipes reach mission12, drag-return/CANCEL preserve15files, two ordinary selections each commit once, and16 complete comparisons preserve original progress/all13archives through Home/cold. Independent bounded native packet review is clear; details are in evidence/first-pair-native-20261024.json. Gear has an analogous recovery-row-only fix independently source/CPU reviewed467/0; signed/native touch verification is next (evidence/gear-touch-navigation-20261024.json). Strict native shader warning, native recap/multiplier approach, physical/human/cloud and newer private-transfer gates remain open.

- Gear Bastion 0.4.4/code13 now has independently reviewed Android12to13 touch/recovery evidence: 25 complete owning-context comparisons with zero failures across26 phases,15 pending checks, six resolved journals and11 unchanged archives. Recovery-row swipes, drag-return, CANCEL, Back/Home/cold and both explicit choices preserve or adopt the whole chosen save; each choice commits once. The sealed457-pin packet includes exact raw saves, commands, harnesses, selected native images and verified emulator shutdown. Journal-only fixtures use already retained codes; no active-save injection or induced storage failure is claimed. Final cold view is Journey/Resume Defense with the original battle stored. Native cached-shader warnings remain strictFAIL; physical/FPS/audio/human/cloud and newer upload gates remain open. See evidence/gear-touch-navigation-20261024.json.

- Hearthguard Journey and recovery row-body scrolling now reuse the existing ScrollContainer drag cancellation through three scoped input-filter lines. Actual focused engine input reproduces the old24/3 failures; final source and root repeat each pass334/0 with1,280 events/20 activations across four layouts, complete live/synthetic saved context and raw fault-backend preservation, and unchanged176-file source maps. Independent source/checkpoint/38-artifact review is clear; historical kinetic-navigation test failures remain retained. Existing0.3.2/code6 predates this fix. Higher signed/native touch verification is next; native/physical/clipboard/cloud/human/upload acceptance remains open. See evidence/hearth-touch-scroll-20261024.json.

- Hearthguard 0.3.3/code7 includes the reviewed Journey/recovery row-scrolling fix and passes independent signed packaging plus bounded Android6to7 checks. The sealed292-pin native packet passes40 owning-context comparisons (39cross-phase/source and one read/decode consistency check),17 pending transactions and seven resolved journals across41 phases. Actual Journey swipes reach the final row; drag-return/CANCEL/disabledtap/Close/Back preserve both active files. Short-viewport summary and View-code scrolling retain all five pending files; ordinary Journey selection and both explicit recovery choices each commit once. Two genuine app-written codes are explicit archived/journal fixtures, not normal Import or storage-failure proof. The whole original defeat/3gold context and visible result survive cold launch; the viewport is restored and owned emulator stopped. Cached-shader warnings remain strictFAIL; clipboard, native storage faults, physical/FPS/audio/human/cloud and newer upload gates remain open. Next: Hook9to10 and Tower10to11 clipboard protocols. See evidence/hearth-touch-scroll-20261024.json.

- Hook clipboard/touch cycle: actual9to10 firstExport1755B and both retainedCopy/View/opposite-choice/PasteImport/cold routes pass32 whole-context comparisons; native button-body swipes expose an independently reproduced scrolling defect. Exactly two local input-filter lines fix the six recovery buttons; source/CPU1395/0 with8616events and signed0.3.5/code11 packaging are independently clear. Actual10to11 preserves18install files; matched row-body swipes now reachCopy/View, reverse/dragreturn/CANCEL/Back/Home/cold retain19pendingfiles, and both choices commit once. Twenty-eight owning-context comparisons pass (27cross-phase/chosen plus one retained-original baseline), with16pending/eightresolved checks and16original archives unchanged. FirstExport/Previous1755B andImported1450B exact clipboard readbacks and app-copiedPrevious normalImport restore the full original legacy context. Historical failed swipe and30/3 navigation expectation packet remain retained; native has zero projectiles/empty earned profile, with rich CPU fixtures separate.

- Tower0.4.5/code11 now has actual10to11 exact11-file install preservation and14 whole comparisons/0 in16phases: firstCopy282B exact native clipboard readback and checked feedback; ordinaryUndo followed by normalPasteImport/cold restores the entire original route, Undo flag, medals and settings, with nine original archives unchanged. Editorfocus/longpress did not establish softIME or manual touch-copy. The combined1549-pin native packet, source/packaging, selected pixels, both restored originals and owned emulator shutdown are independently qualified clear. Cached-shader warning remains strictFAIL; native unavailable/delayed-copy fault injection, storage interruptions, physical/FPS/audio/human/cloud and newer uploads remain open. Shared shader-cache rejection diagnosis is next; native Dead/Frontline presentation checks also remain. See evidence/hook-tower-native-copy-20261024.json.
