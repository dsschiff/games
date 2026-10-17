# Campaign presentation checkpoint

Source 0.3.1/code 5 adds nine gates in three acts and three reduced-budget seeded replays. This checkpoint is for independent review; it does not establish full v1, human enjoyment, final fidelity or physical-phone performance.

## Implemented and exercised

- The open field expands during combat; preparation expands the board/shop. Secondary utilities live in a native Menu. Numbered wall arches allocate future production. Touching toothed wheels turn in alternating directions, with original role portraits and power/rate feedback.
- Produced troops are real capped actors during their two-second generator-to-arch march. They cannot attack or be targeted until deployed. Their source socket, route time, role and exit survive saving. The first enemy formation receives the same opening travel allowance. Old snapshots without deployment retain their earlier timing.
- Twelve original actor kinds, shadows and white hit silhouettes share a 1664×256 runtime atlas at twice logical resolution. Bob, health and reduced-effects behavior remain independent. This adapts the measured isolated atlas experiment; its old emulator measurements do not establish campaign or phone FPS.
- Schema 4 pins encounter rules, starting kit, costs, rates and actor statistics separately from the profile. Compressed portable codes preserve both. Retry validates its reconstructed kit. Active Practice replacement is guarded; cancel preserves state and confirmed replacement clears Undo.
- The primary portfolio input runner now executes the full campaign and all three replay wins. The retained tutorial/Iron Trial input runner is `tests/legacy_playthrough.gd`. Replay results preserve best medals and return to the trials menu.

## Evidence

Game-local ignored evidence is under `.artifacts/`:

- `visual-rules-final.log`: 161 checks, no failures.
- `visual-headless-cleanup.log`: 65 actual-input checks, nine campaign clears and three seeded replay clears; normal profile/run restoration and Back/menu behavior. Audio is stopped before test teardown.
- `visual-final-input.log`: rendered actual-input route, including typed portable import. The final rerun also includes Back closing the collapsed utility menu.
- `actor-render-2.log` and `actor-render/`: 13 rendered checks covering all twelve colored/white cached silhouettes, with all-kind health/flash and calm-effects frames.
- `visual-nearby.log`: both approaches win all 54 exact-step cases (nine gates × two comparably funded builds × seeds 1700/1701/1702).
- `visual-replay.log`: both approaches win all 18 exact-step reduced-budget cases (three replay gates × two builds × seeds 1729/1730/1731); minimum wall 180/220.
- `campaign-motion/early.mp4`, `middle.mp4`, `final-boss.mp4`: twelve-second fixed-30-FPS desktop replays of genuine input-suite saves. These show new generated troops and real engagements; they are not real-time performance tests or human play footage. The checked-in evidence index records hashes and scope.

The selected full input route takes 1,830.93 simulated combat seconds (30.5 minutes), excluding preparation, mistakes and replay. Main-route walls remain 220/220. Initial campaign-core checks are preserved in the earlier commit/worklog; Android evidence for that core does not cover these presentation/deployment changes.

## Open review gates

The campaign is bounded and completable, but its decision pressure is not yet accepted. A previous pre-staging sweep found all-guard/all-ranger/all-mortar approaches each win the mortar introduction; casualties and wall damage differ substantially. Three-second delayed setup lost both Glass Arrows cases in that earlier sweep. Current static mixed layouts also beat Three Fronts and Furnace Tide without gate changes or salvage spending. Those results do not support claims that their advertised decisions are required. Per-encounter mistake/correction evidence and pacing/cap-pressure review remain open; many successful runs spend most combat time at the 120-actor cap.

Independent early/middle/final motion comparison, current campaign Android cold-map/Back/lifecycle/update checks, safe areas/fold behavior, actual sound/clipboard, and physical-phone performance remain pending. No adb command or new export was performed during the coordinator hold. No website or shared tooling changes are included.
