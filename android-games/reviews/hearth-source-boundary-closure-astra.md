# Hearthguard source boundary closure

2026-10-18. Additive to `hearth-early-source-astra.md`; historical findings remain preserved. CPU/read-only inspection of source and existing receipts only. No tests, Godot, Blender, browser, GPU or device operations were run by this reviewer.

**Both identified boundary defects are closed in the inspected source and focused CPU evidence.** No further boundary blocker is identified. This permits the planned first bounded rendered inspection once a clean candidate and render slot are available; it does not approve visual quality or release readiness.

## Resume event preservation — closed

`settlement.gd:227` now deep-copies each event together with its observation time. Both production callers—`main.gd:517` and `campaign_main.gd:391`—pass `state.time` immediately after their actual rules tick. On hydration, line 250 retains only batches for the exact current time when the app is running; held-state hydration clears them. The retained events then pass through the ordinary deduplication/observation path.

This fixes the actual first-resumed-tick ordering without moving combat or altering damage timing. Tests explicitly queue a fresh shot after advancing time, transition paused→running and assert one new emitted attack plus a real transient; a separate stale-time batch is rejected with no additional attack or effects. The preservation filter applies to all event kinds, including heal; the focused execution assertion directly exercises shot, not a separate heal fixture.

## Terminal locomotion — closed

`settlement.gd:421` now supplies movement velocity only when unpaused **and** `target_phase == "playing"`. Victory and defeat therefore receive zero velocity even if interpolation retains the final movement delta. Actor gait stops, travel settles toward zero, and finite corpse/victory presentation can still finish.

The focused test first creates movement, enters victory with that previous delta still present, presents 120 frames, then asserts zero travel and unchanged gait. The explicit fixture exercises victory; the same source predicate also covers defeat. No saved-state mutation is introduced.

## Evidence binding and source state

Latest completed matching receipt: `.artifacts/cpu-clearance-corrected8-checks-20261018T155726139300Z/receipt.json`, **320 checks / 0 failures**, source unchanged during execution. Both Resume assertions and the terminal assertion pass. Independently rehashed the receipt-bound `presentation-report.json`, `source-hashes.json` and `godot.log`; all match. **All 118 recorded source/resource pins match the current files** at this inspection, including the boundary callers and tests.

Earlier `cpu-boundaries4` and `cpu-projected-clearance7` failures remain historical; their passing boundary subchecks do not convert their overall failed runs to passes. The latest matching run supersedes them for this closure.

Existing baseline receipts separately show campaign **123/0** and legacy **56/0**, both source-unchanged during their executions. Current rules, campaign rules/catalog and save store/files remain byte-exact to HEAD. `stable-indices-reproducibility.json` records 30/30 repeat-export hashes equal; this is asset reproducibility evidence, not visual acceptance.

Worker HEAD remains `c36df6e0dcdda2f38670965090664c682777a2e8`; graphics work is still dirty/untracked. Relative to the early review, settlement, both main callers and presentation tests changed as expected. Actor and adapter pins remain unchanged. The following hashes were stable across this closure's reads:

| File | SHA-256 |
|---|---|
| scripts/presentation/settlement.gd | f7f9c5cfeb6ae84613becfb4e520879c72623d10626c6b0727c19701a6317660 |
| scripts/main.gd | 34ae1690113a0450a19ca6cc9561e3486566ce5044964624c5e312423733ad76 |
| scripts/campaign_main.gd | caad2877fadbba9b03711084e512764106d31c619fe3ff476adeb236bc449a72 |
| tests/presentation_tests.gd | a46c1a96abf5d4a330070f6b3226be37acf572e4a88db6292b1d2ede41930951 |

No still or motion review was performed here. First rendered inspection, subsequent eight-row normal-motion assessment and eventual native candidate evidence remain distinct outstanding work. No broad campaign repeat or physical-phone gate is added.
