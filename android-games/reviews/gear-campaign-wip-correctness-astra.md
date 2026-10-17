# Campaign WIP correctness review

Astra statically reviewed all20files in the immutable uncommitted snapshot `.artifacts/reviews/campaign-wip-20261017-2240/`, verifying its hash manifest. Locations below refer to that snapshot, not the changing builder branch. This is a pre-freeze review; no final campaign acceptance. Root sent all findings to the builder for correction and regression coverage.

## Open findings

1. **P2 — Practice replaces an active campaign run and retains Undo.** `scripts/main.gd:387` bypasses the abandonment confirmation used by `request_mission`, replaces state, retains `undo_board`, then persists. A campaign board with pieceID≥6 can be restored by Practice→Undo into tutorial `next_id=6`, failing the save validator's piece-sequence check. Route Practice through guarded replacement and centralized transient-state reset. Cover cancel-preserves-run and confirmed-reset-clears-Undo.

   Root independently reproduced this in the copied snapshot using fixture setup plus production action-handler calls, **not actual UI input**. Initial camp09/nextID7 decoded successfully; Map→Practice silently changed it to tutorial/nextID6 while retaining six Undo pieces; Undo then produced `Invalid piece sequence`. Local probe/result/log are in that snapshot directory. The initial harness omitted fixture spending; it was corrected before this successful reproduction. Two ObjectDB exit-cleanup warnings in the helper are not a claimed production-game leak.

2. **P2 — Missing schema4 profile silently empties progression.** `scripts/save_store.gd:144` defaults absent `profile` to `Profile.fresh()` even for version4. An otherwise valid newest primary missing that field is accepted and outranks an intact backup; subsequent persistence loses earned clears. Default fresh profiles only for schemas1–3. Require schema4 profile and test higher-revision incomplete-primary recovery to intact progression backup.

3. **P2 — Accepted snapshot can generate an invalid Retry board.** `scripts/campaign_data.gd:120` validates starter coordinates individually without rejecting core overlap, duplicate starter cells or starter/core outside allowed sockets. A valid current active board can import the config, then Retry constructs an overlapping/off-board initial kit via `main.gd:144` and `battle_rules.gd:44`; persistence rejects it. Validate the complete generated starting board and socket membership before accepting the snapshot. Test malformed variants and a valid altered-kit round trip/Retry.

4. **P2, imported/future-config scope — Accepted configuration exceeds generated-state save bounds.** `campaign_data.gd:137` accepts attack periods up to300 while `save_store.gd:129` limits cooldowns to5. An accepted period6 becomes unsaveable after an attack. A nonempty boss with `boss_hp=0` is also accepted, then spawns with zero health and reaches a division by zero in boss logic. Align configuration/generated-state bounds, including scaled health; test accepted configurations through spawn/attack/save/restore. **Current catalog does not use these offending values.**

## Preserved conclusions and limits

The previous staged-backup preservation, failed-import handling, revision ordering, global actor-ID and faction checks remain present; these findings do not reopen them. Legacy migration supplies an empty profile without inventing campaign clears, and Retry uses the saved configuration. Keep that architecture and correct navigation/validation at its boundaries.

Astra did not execute Godot, tests or Android. Root additionally executed copied-snapshot recovery/import invariants: schema4 primary revision9 missing its profile was selected with no clears over an intact revision8 backup with camp01clear; core-overlap, duplicate-starter and outside-socket configs imported successfully but each Retry failed decoding; accepted period6 produced a valid pre-attack save, then an actual battle tick set cooldown6 and decoding failed with `Invalid unit counters`. Zero-boss-health config/import acceptance was confirmed; its runtime division was deliberately not executed. These are isolated logic/configuration fixtures, not actual-input or Android results. Harnesses, outputs and snapshot hashes are indexed in [the evidence record](../evidence/gear-campaign-wip-review.json).

Findings remain open until changed source and meaningful regression execution are reviewed; live builder work may already supersede the snapshot. Physical phone, full campaign balance/fun, final fidelity and release acceptance remain pending.
