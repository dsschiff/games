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
