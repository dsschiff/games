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
| Dead Run | Does Retry/return flow make sense after an ending, and is the growing crew readable under pressure? Correct phase-blind Resume and verify terminal controls. | Builder active |
| Frontline | Tested solo8/12 vs funded12/12, tutorial-only idle win; delivered actual recruit feedback, HQ marker and committed-save verification as signed0.3.2/code6. | Private update delivered; physical acceptance deferred |
| Gear | Do board, role and exit choices remain consequential and visibly connected to the army? | Queued |
| Hearthguard | Does gathering versus investing stay meaningful through distinct later maps? | Queued |
| Hook | Do chained hits, recovery and enemy telegraphs reward positioning? | Queued |
| Tower | Do arithmetic, route choice and Undo remain readable as puzzle ideas develop? | Queued |

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
