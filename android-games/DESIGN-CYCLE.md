# Continuous game design cycle

Approved by Daniel on 2026-10-23. Coordinator goal: first meaningful design-and-polish
release for all six ad-inspired Android games, with optional Google cloud recovery.
Planetfall stays separate. Start Dead Run + Frontline, then Gear, Hearthguard, Hook,
and Tower. Preserve each selected ad loop with original assets.

## Design and release standard

- Make the first minute understandable and satisfying. Show action, consequence,
  useful reward and next objective through actual gameplay.
- Improve decisions, enemy counters, encounter rhythm and feedback before adding
  levels or systems. Reuse campaigns, medals, loadouts and seeded modes.
- Use mastery and variation for replay; no compulsory grinding, timers or energy.
- Keep touch controls, animation, combat telegraphs and HUD legible at phone size.
- Preserve full earned progress and pinned active-run rules across signed updates.
- Local saves are immediate. Optional Google cloud recovery never gates play;
  validate complete save envelopes, isolate each game/player and preserve divergent
  saves for an explicit player choice. No custom account backend.
- Original stylized 3D; no paid assets/services or public publication. Private
  Obtainium delivery remains available; Daniel-only Play internal testing follows
  account verification, with the same app signing key. Cloud changes require
  accurate privacy/data declarations.

## First priorities

| Game | Design question and initial task | Status |
| --- | --- | --- |
| Dead Run | Terminal Retry, warning priority and crew clearance source fixes landed; corrected fixture cadence passes strict54/0 with all original checks. | 0.4.1/code7 privately delivered; bounded motion/native review clear |
| Frontline | Tested solo8/12 vs funded12/12, tutorial-only idle win; delivered actual recruit feedback, HQ marker and committed-save verification as signed0.3.2/code6. | Private update delivered; physical acceptance deferred |
| Gear | One Begin after ready utilities/Home now starts production; active return stays paused. Signed0.4.1/code10 verified and delivered. | Private update delivered |
| Hearthguard | Save destination readback and failed import/mode-switch preservation pass167 complete-value checks and signed4-to5 native context comparison. |0.3.1/code5 privately delivered |
| Hook | Hit/miss/block feedback corrected; obstacle-deflected charge gap reproduced. Conservative warning correction covers actual stepped paths. | 0.3.1/code7 privately delivered; finale improvement reviewed and0.3.2/code8 native-qualified, unpublished |
| Tower | Resolved encounter arithmetic stays nonoverlapping at earliest legal chaining across all36 towers. | 0.4.1/code7 privately delivered;0.4.2/code8 association/native update reviewed, unpublished |

## Operating loop

Choose the largest observed weakness, implement one bounded increment, run relevant
rules/input/save checks, independently review the actual diff and normal-speed
visuals, then deliver a verified higher-version private build. Commit and land
scoped changes. Record the exact evidence and next action here or in existing
per-game records. Do not turn routine provenance into duplicate session archives.

At most two builders and one independent reviewer. Exclusive per-game worktrees;
coordinator owns shared code, signing and serialized renderer/emulator/clipboard.
New worktrees and large artifacts live on F:. All automated testing uses muted or
Dummy audio. Preserve other sessions and their unfinished work.

Human fun, real Fold7 touch/folding, audible sound and measured phone frame rate
remain unclaimed until tested. A 30-60 minute initial arc is a human target, not
proof from a solver or simulated clock. Continue independent work around external
blockers; do not ask for routine design/implementation permission again.

## Current baseline

Origin/main 4552e7b includes release signing and private Obtainium delivery. Current
six save writers call flush, while older roadmap notes say otherwise; source is
not enough to close historical emulator hard-shutdown loss. Play Console opens
for ShifTech but requests identity documents, followed by phone verification; no
apps were present in the live 2026-10-23 check. Cloud sync is not implemented.

## Cycle progress

- 2026-10-23: active coordinating goal created; isolated F: coordinator, Dead Run
  and Frontline worktrees prepared from 4552e7b. Two builders and one independent
  reviewer active. No new gameplay release or cloud/device acceptance claimed.

- 2026-10-23: Frontline0.3.2/code6 delivered privately after PR9 landed. Root51/0
  actual-input regression, signature/unchanged-source checks and real emulator
  signed5-to6/offline/Home/cold process smoke pass. Native raw whole-save and
  physical/human acceptance remain unclaimed. Evidence: `evidence/design-cycle-20261023.json`.
- Dead Run source fixes integrated locally; full focused rendered route passes51
  assertions but fails strict shutdown gate on four leaked texture allocations.
  Keep release gate open. Gear ready-phase Begin defect independently reproduced.

- Gear0.4.1/code10 privately delivered with same signer. Actual Android Menu/Home
  then one Begin produces6 defenders; complete ready context retained across
  update, complete active context frozen across Home and cold restart. Baseline
  profile empty; earned-profile retention is separate desktop evidence. Hearth
  signed4-to5 context equality and real natural result/log/cold checks pass.

- Hearthguard0.3.1/code5 privately delivered after PR11 landed. Exact asset digest,
  size, notes and private README readback verified. Failed-transaction desktop
  checks and actual native update/log/result/cold checks remain separate evidence.

- Hook0.3.1/code7 and Tower0.4.1/code7 privately delivered with the existing signer.
  Offline6-to7/Home/cold and whole-save comparisons pass. Tower additionally earns
  a real Android clear and cold-restores it; Hook moves and recommits its loaded
  active run. Both pre-update earned profiles were empty. Independent review
  verifies71 native files plus exact private assets/notes/README. Dense Hook
  finale and Tower floor association stay open; optional live cloud is separate.

- Followup source: Frontline local Import870/0 and Tower floor association62/0 independently rerun after integration. Full source review and Tower matched1x motion clear; both need new version/build/native verification before delivery. Optional cloud remains unlinked and live-unverified.

- Frontline0.3.4/code8 and Hook0.3.2/code8 now source-clean/same-signer/native-qualified;19 whole-context comparisons and264 artifact pins independently clear. Summary-first pending recovery and read-only local copies work in the unconfigured Android build. Same-context archive restore/cold verified; distinct-context cloud restore/live SDK sync remains open. Tower0.4.2 native association packet also independently clear. All three source changes landed in PR18; their exact private transfers await specific approval. Gear verified-write/Import prerequisite starts independently; no game rules or progress reset.

- Gear local Import durability prerequisite is implemented and source/CPU reviewed;
  complete context and explicit recovery choices are verified by synthetic fault
  and actual GUI-input checks. Signed0.4.2/code11 retains the existing identity.
  Initial Android attempt stalled during raw-save capture after successful boot;
  no install occurred in that failed attempt, owned runtime stopped and app data
  was not reset. Later bounded native evidence is recorded below. Optional
  cloud is separate. Earlier three refinement sources landedPR18; exact private
  transfers await specific approval. See evidence/gear-local-recovery-20261024.json.

- Hook local recovery now preserves complete opaque codes and whole contexts,
  freezes pending play/writes, and offers explicit verified Retry/Keep choices.
  Terminal loading and due-save ordering fixes pass independent871/12 checks;
  eight strict worker suites/source and artifact audit are clear. No version,
  binary, native, rendered or cloud acceptance is added. The later arena Continue
  score-identity correction landed in PR23; the earlier next-fix note is superseded. See
  evidence/hook-local-recovery-20261024.json.

- Gear code11 native functional evidence is independently audited:16 complete
  owning-decoder comparisons/0,7 pending validations,8 cleared journals,212 pins.
  Strict shader-warning gate failed; raw JSON ULP changes remain qualified. New
  safe Copy Previous/Imported controls pass root386/0 CPU checks, pending a later
  signed native export check. A newly reproduced Dead retry-marker sequence
  requires equivalent Gear/Hook/Frontline regressions before new APK builds.
  Existing successful packets remain bounded historical evidence.

- Hook now exposes selected arena best-clear feedback using the existing
  canonical/legacy-aware lookup, including zero records and honest no-clear text.
  Root573/0 and independent source/evidence review pass. Saves, combat and ranking
  are unchanged. Native/render review follows the separate retry-marker fix and
  later signed candidate; no new APK is included in this source increment.

- Dead local Import recovery is source/CPU reviewed across actual campaign owner
  and legacy child: complete contexts/bullets retained, admitted autosave joined
  after freeze, all-marker/all-copy admission refreshed on every choice. Root
  marker53/0 and phase7/0 pass; old native baseline2/0 preserves ten bullets.
  No new APK/native-candidate acceptance. See evidence/dead-local-recovery-20261024.json.

- Frontline now uses the reviewed all-marker/all-archive retry admission. Root
  helper107/0 and actual-input26/0 pass over complete campaign/legacy career
  contexts;24 real engine touch events, same-process materialized fresh owners.
  Worker cache failure is retained; no import or asset substitution. New signed
  native candidate remains separate: evidence/frontline-marker-retry-20261024.json.

- Hook marker safety source is independently reviewed with root172/0 and one
  frozen871/188/573 regression batch. Full projectile/ending/parked contexts
  retained; no Store/rules/UI/version/build/native claims added.
  See evidence/hook-marker-retry-20261024.json.

- Gear0.4.3/code12 includes reviewed safe copy controls and fresh all-marker/
  all-archive retry admission. Signed/native update and explicit choices verified
  with10 whole owning-context comparisons/0,7 pending/7 cleared markers,2 exact
  Android-emulator clipboard reads. All355 packet+8 update pins reviewed.
  Shader warning remains failed; no blanket rendering/physical/cloud acceptance
  or new upload. Earlier code11 and failed driver/native packets are preserved.

- Dead0.4.2/code8 local signed candidate includes reviewed complete recovery and
  direct retained-code Copy controls. Root434/0 strict headless input and Astra
  APK/source/signer/raw-log audit pass. Native update/exact clipboard checks
  await host resources; code7 baseline and its existing warning are retained.
  No new upload or native/phone/cloud acceptance.

- Tower complete local recovery is source/CPU reviewed, including exact code
  archives, fresh all-marker/all-copy admission and startup before active saves.
  Root608/0 with208touch events; pinned old regressions clear. Native/rendered
  recovery, clipboard and higher-version candidate remain separate; no new APK.

- Hearth whole local recovery is independently source/pin reviewed, with root
  874/0 and338actual touch events. Final old regressions and four real-file
  directions pass. Repeated historical headless AVs are retained with bounded
  allocated-row correction; standalone missing-UI handoff fixed. No Android crash/
  engine-cause conclusion. Version/native/render/clipboard gates stay open.

- Dead0.4.2/code8 bounded native14/0 with10pending/10cleared journals and both
  Android-app code roundtrips now recorded. Explicit fixture archives/metadata
  use genuine ready/battle contexts; no real I/O fault or earned-profile claim.
  Original battle restored/cold, emulator closed. Bounded independent audit clear;
  shader warning and external full-code bridge readback remain open. No upload.

- Hook0.3.3/code9 local signed candidate packaging independently clear; runtime
  equals reviewed2467cd60 and only version/README changed. Recovery/arena identity/
  best-clear feedback included. Native update/full recovery/clipboard/readability
  and exact-transfer authorization remain separate; no upload.

- Tower0.4.4/code10 now has signed8to9to10 native full-context evidence,20 comparisons/0,11pending13cleared journals, real earned medal feedback and corrected transfer-note layout. Both Copy/opposite-choice/Paste/Import/cold roundtrips preserve the complete chosen context; rich Challenge/parked case is explicitly CPU-derived. Original native route restored and owned emulator shut down. Strict cached-shader warning remains failed; no private upload or physical/cloud acceptance. See evidence/tower-native-recovery-20261024.json. Latest read-only ShifTech console still requires identity/phone verification before app setup.

- Hearth coverage preview now has matched normal1x rendered opening/boss evidence: four strict-clean21/21/26/26 passages, same complete gameplay/inputs/timing/rawsaves, and qualified sampled browser review. Hold/cancel/onebuy feedback and Ram warning remain readable. Preview harness waits for actual audio playback release beforeexit; originalfailures preserved. Shipping runtime/version unchanged; higher-version signed/native and physical/cloud checks remain open. See evidence/hearth-normal1x-preview-20261024.json.

- Tower normal transferCopy now confirms exact readback with bounded polling and accurate failure feedback while leaving selected text available for manualcopy. Root42/638 strictCPU checks and five-worker-suite audit pass; pending recovery protocol and all save meanings remain unchanged. Newer signed/native first-tap/timeout/IME/manual-selection verification remains open; existingcode10 APK predates this source. See evidence/tower-copy-confirm-20261024.json.

- Prepared Hearth0.3.2/code6, Tower0.4.5/code11 and Frontline0.3.5/code9 from reviewed source with metadata-only version changes. Independent actualAPK ZIP/signature/metadata/source/pipeline/config/raw-log review CLEAR; same2527signer, no permissions/nondebug. Local candidate paths/hashes indexed without changing delivered URLs. Hearth genuine5to6/Home/cold preserves whole state/profile/settings/campaign in5comparisons/0; old and new native logs both retain cached-shader warning, so strict native gate FAIL. Normal Import/recovery-choice/OSclipboard, Tower normalCopy/Frontline retry native, physical/cloud and exact upload gates remain open. See evidence/recovery-signed-candidates-20261024.json.

- Frontline 0.3.5/code9 now has independently reviewed native update/recovery evidence: 37 complete-context comparisons, 13 read-only admission replays, and five rejected choices with all 14 files and owner PID unchanged. Both healthy choices and the normal 8,248-byte Paste/Import route retain the whole chosen context; the original Switchyard save and nine archives are restored. The cached-shader warning still fails the strict native gate. Explicit fixtures, empty parked/skirmish fields, renderer failures and native storage-fault limits remain qualified. New Dead multiplier and Frontline recap/Journey feedback source passes independent CPU review; normal-rate rendering and later signed candidates remain next. No upload. See evidence/frontline-native-marker-20261024.json and the game checkpoints.

- First-pair presentation cycle: matched normal-speed desktop review exposed an unreadable Dead multiplier caption; shorter fractions and contrast now distinguish partial charge, applied multiplier and earned threshold. The independent analog-bar cue remains unproven. Full 2,734-tick/28-input gameplay and raw-save parity is preserved; 396 fixture checks and matched 18/18 route checks pass. Frontline recap, Journey and latest-clear matched passages pass 38/38 with complete state/input/save parity and bounded visual review. Local signed Dead 0.4.3/code9 and Frontline 0.3.6/code10 include these reviewed changes; actual APK/source/signature/raw-log audit is independently clear; details are in evidence/first-pair-rendered-20261024.json. No newer upload; Android update/presentation, strict cached-shader warning, physical/human and cloud gates remain open. Retained movies/stills and exact cleanup manifests preserve the evidence after 4,018 redundant PNGs (1,936,005,579 bytes) were removed.

- Android update/touch cycle: Dead 8to9 retains the whole ten-bullet campaign context in7 comparisons/0; a separately settled same-process Home pair is readable, with earlier black/splash observations retained. Frontline9to10 retains whole context4/0 but real row-body swipes exposed a Journey usability defect missed by wheel-only proof. A single row input-filter correction passes172 focused checks and signed0.3.7/code11 packaging; actual10to11 swipes reach mission12, drag-return/CANCEL preserve15files, two ordinary selections each commit once, and16 complete comparisons preserve original progress/all13archives through Home/cold. Independent bounded native packet review is clear; details are in evidence/first-pair-native-20261024.json. Gear has an analogous recovery-row-only fix independently source/CPU reviewed467/0; signed/native touch verification is next (evidence/gear-touch-navigation-20261024.json). Strict native shader warning, native recap/multiplier approach, physical/human/cloud and newer private-transfer gates remain open.

- Gear Bastion 0.4.4/code13 now has independently reviewed Android12to13 touch/recovery evidence: 25 complete owning-context comparisons with zero failures across26 phases,15 pending checks, six resolved journals and11 unchanged archives. Recovery-row swipes, drag-return, CANCEL, Back/Home/cold and both explicit choices preserve or adopt the whole chosen save; each choice commits once. The sealed457-pin packet includes exact raw saves, commands, harnesses, selected native images and verified emulator shutdown. Journal-only fixtures use already retained codes; no active-save injection or induced storage failure is claimed. Final cold view is Journey/Resume Defense with the original battle stored. Native cached-shader warnings remain strictFAIL; physical/FPS/audio/human/cloud and newer upload gates remain open. See evidence/gear-touch-navigation-20261024.json.

- Hearthguard Journey and recovery row-body scrolling now reuse the existing ScrollContainer drag cancellation through three scoped input-filter lines. Actual focused engine input reproduces the old24/3 failures; final source and root repeat each pass334/0 with1,280 events/20 activations across four layouts, complete live/synthetic saved context and raw fault-backend preservation, and unchanged176-file source maps. Independent source/checkpoint/38-artifact review is clear; historical kinetic-navigation test failures remain retained. Existing0.3.2/code6 predates this fix. Higher signed/native touch verification is next; native/physical/clipboard/cloud/human/upload acceptance remains open. See evidence/hearth-touch-scroll-20261024.json.

- Hearthguard 0.3.3/code7 includes the reviewed Journey/recovery row-scrolling fix and passes independent signed packaging plus bounded Android6to7 checks. The sealed292-pin native packet passes40 owning-context comparisons (39cross-phase/source and one read/decode consistency check),17 pending transactions and seven resolved journals across41 phases. Actual Journey swipes reach the final row; drag-return/CANCEL/disabledtap/Close/Back preserve both active files. Short-viewport summary and View-code scrolling retain all five pending files; ordinary Journey selection and both explicit recovery choices each commit once. Two genuine app-written codes are explicit archived/journal fixtures, not normal Import or storage-failure proof. The whole original defeat/3gold context and visible result survive cold launch; the viewport is restored and owned emulator stopped. Cached-shader warnings remain strictFAIL; clipboard, native storage faults, physical/FPS/audio/human/cloud and newer upload gates remain open. Next: Hook9to10 and Tower10to11 clipboard protocols. See evidence/hearth-touch-scroll-20261024.json.

- Hook clipboard/touch cycle: actual9to10 firstExport1755B and both retainedCopy/View/opposite-choice/PasteImport/cold routes pass32 whole-context comparisons; native button-body swipes expose an independently reproduced scrolling defect. Exactly two local input-filter lines fix the six recovery buttons; source/CPU1395/0 with8616events and signed0.3.5/code11 packaging are independently clear. Actual10to11 preserves18install files; matched row-body swipes now reachCopy/View, reverse/dragreturn/CANCEL/Back/Home/cold retain19pendingfiles, and both choices commit once. Twenty-eight owning-context comparisons pass (27cross-phase/chosen plus one retained-original baseline), with16pending/eightresolved checks and16original archives unchanged. FirstExport/Previous1755B andImported1450B exact clipboard readbacks and app-copiedPrevious normalImport restore the full original legacy context. Historical failed swipe and30/3 navigation expectation packet remain retained; native has zero projectiles/empty earned profile, with rich CPU fixtures separate.

- Tower0.4.5/code11 now has actual10to11 exact11-file install preservation and14 whole comparisons/0 in16phases: firstCopy282B exact native clipboard readback and checked feedback; ordinaryUndo followed by normalPasteImport/cold restores the entire original route, Undo flag, medals and settings, with nine original archives unchanged. Editorfocus/longpress did not establish softIME or manual touch-copy. The combined1549-pin native packet, source/packaging, selected pixels, both restored originals and owned emulator shutdown are independently qualified clear. Cached-shader warning remains strictFAIL; native unavailable/delayed-copy fault injection, storage interruptions, physical/FPS/audio/human/cloud and newer uploads remain open. Shared shader-cache rejection diagnosis is next; native Dead/Frontline presentation checks also remain. See evidence/hook-tower-native-copy-20261024.json.
