# Gear pooling: bounded early source review

2026-10-18. Read-only CPU/source review; no Godot, browser, rendering, ADB, test rerun, or worker messages. Worker root: `C:/projects/active/_worktrees/games-gear-bastion-20261017/android-games/gear-bastion`.

**Disposition: no concrete source blocker found.** The inspected implementation addresses the previously missing object reuse requirement. This is an in-progress source assessment, not frozen production or visual acceptance. Rendered reuse/contact/reset closure, the previously unseen captain/siege/carapace roles, and bounded updated timing evidence remain for the already scheduled follow-up. The historical six-film review remains unchanged.

## Binding and evidence

Worker HEAD remains `01f650afc73edaab01be8e5858b410df20babb3c`; pooling is an uncommitted delta. Inspected pins, unchanged at end of this review:

| File | SHA-256 |
|---|---|
| scripts/presentation/actor.gd | `23ce0767f56f2a7f6f20a7f4bc81ecf1e2c6551115195f083d4ac771df7368fa` |
| scripts/presentation/foundry.gd | `a578e38c823e0429cc5950506cc5d2fccc6e933c2ed63330a7008e02db5ebe58` |
| tests/pooling.gd | `b95d639b6616420b76b09f677b73a11c3edc68a266b867aebe3a5514c9645209` |

Actual receipt `.artifacts/graphics-production/pooling-20261018T161754330963Z/receipt.json` records headless execution, exit 0, source unchanged during the run, and PASS. Its log and retained result report **456 checks, zero failures**. I independently matched retained `result-data.json` to receipt SHA `7af2fed56db93f44098418be0612acda41939e8a80469f7b6f2fdfc72ece4c50`, and inspected the assertions rather than relying on the count. Current pool runtime, adapter, rules, save implementation and pool fixture match that receipt. Full receipt-pin comparison finds drift only in `tests/graphics_motion.gd` and `tests/run_motion.py`, which are actively preparing the new bounded captures. Consequently the old CPU receipt does not certify those later harness edits or a final freeze.

## Findings

- **Actual reuse:** Foundry holds inactive actor nodes, including their original model and skeleton, keyed by role plus side. Reacquisition pops those same instances; it does not simply cache a PackedScene/material and instantiate anew. Effects retain MeshInstance3D nodes in separate tracer/impact reserves and share a unit BoxMesh. Focused assertions compare actual actor/model/rig/mesh identities.
- **Reset completeness:** Actor reset restores root identity and side-facing, aim, new-ID gait offset, travel, recoil/hit timers, death state and torso aim; restores authored child transforms/visibility; resets all bone poses; and synchronizes the current Weapon attachment immediately after forcing bone transforms. Health fill is restored before current HP is applied. The fixture contaminates root scale/position, death pose, hidden model/rig, socket transform and health geometry, then compares all twelve reused roles to fresh instances and checks immediate contact. Role/side partitioning preserves fixed meshes, rig layout and side-specific health materials. Pose code does not mutate shared model materials, so no unstated material recoloring reset is needed here.
- **Identity and event ownership:** Pool nodes do not own authoritative IDs. Active/corpse dictionaries continue to use typed IDs and epoch; corpse expiry removes the old mapping before future reuse. Dedupe remains owned by the unchanged adapter/Foundry event sets, not the borrowed node. Hydration retires active/corpse/effect nodes, clears transient maps, advances adapter epoch and repopulates current state. The fixture covers duplicate contacts, corpse-to-new-ID reuse, no old-ID lookup, preserved dedupe across object reuse and accepted repeated attack token only after epoch reset.
- **Bounds and teardown:** Inactive actors are capped at 64 globally and 12 per role/side; active effects retain the previous 48 cap and inactive effects have a separate 48 cap. Overflow is freed deliberately. These are reserve caps, not a claim that active actors plus finite-lived corpses total 64. Hidden reserves remain children of Foundry, so normal parent destruction frees them; no new static node owner outlives the world. The fixture saturates reserves and frees its viewport, though it does not provide a separate post-destruction leak census.
- **Rules/save boundary:** The runtime delta is confined to actor reset and Foundry allocation/retirement. Rules, RNG, adapter snapshot/event identity, save code, event damage timing and board/camera/input mapping are unchanged from the reviewed historical candidate. One fixture also deep-compares state around presentation/contact calls. This review does not inflate that focused assertion into another complete campaign equivalence run.

The reset path does work both on retirement and reacquisition, and reserves can free overflow; the patch therefore does not establish zero allocation or improved frame time by itself. Those are measurement limits, not a reason to reject a bounded reuse design. No additional broad campaign suite or physical-device gate is requested. Recheck these pins against the final commit and new capture receipts before closing the existing production conditions.
