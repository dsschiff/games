# Named Tower replay goals

A slower treasure replay now explains what it achieved. The result separates **This clear** from **Collected**, with cumulative **Best** and the current **Par** aligned separately. Current moves remain in the HUD. Journey names the missing eligible medal goals, or says **All medals earned**, instead of showing an anonymous count. The existing Clean label now says **No Undo**, including Challenge Records, so it does not imply avoiding traps or damage.

Only `scripts/main.gd` changes at runtime. The display derives this-clear medals from the won state, moves, treasure and current route's Undo flag; cumulative names and best come from the existing campaign profile or the exact pinned Challenge record. It never calls award or writes data, and never announces anything as newly earned. No persistent flags, controls, rules, catalogs, schema, save behavior, version or export settings change. Journey uses actual authored-room treasure eligibility; an unoffered Treasure medal cannot prevent all-earned. The growing watch and existing Next/Replay, Retry, Undo and Journey hit targets remain unchanged.

## Reproduction and bounded fix

The valid unchanged-runtime baseline `.artifacts/design-cpu-20261024T084823522204Z` has **171 checks / 31 feedback failures / 114 actual taps**, with 228 observed ScreenTouch press/releases. Gameplay, known medal masks and complete cold-retention checks passed; emitted result/Journey text omitted the named information. The raw failure stays failed. The earlier 169/45 attempt is retained separately: it incorrectly expected tapping the current Journey entry to reset that route, and compared live storage metadata directly with the newly committed revision. The corrected harness uses the real Retry control and excludes only revision/recoverable from full-context meaning comparisons.

An intermediate 171/4 packet caught a test observer selecting the earlier Moves HUD line instead of the result region; its failed packet remains. Expanded actual font checks then failed **36 of 534** assertions: three stacked lines overlapped and clipped above Next. The runtime now uses two visual rows: This clear at 19px, then Collected and right-aligned Best/Par at 17px. The actual font bounds are y799–826 and y831–855, leaving Next at y862. Maximum collected width361 plus metrics106 leaves53px between them in the 520px text span. No hit rectangle moved or font was reduced to squeeze three rows.

## Final CPU evidence

Frozen packet `.artifacts/design-cpu-20261024T085905918294Z` passes every suite with zero strict log errors, zero exit statuses, explicit PASS markers and unchanged executed source:

| Suite | Checks / failures |
| --- | --- |
| New medal feedback | **793 / 0**, 163 actual taps, 326 observed ScreenTouch events |
| Existing whole Import recovery | 608 / 0, 208 recorded ScreenTouch events |
| Existing combined rules/save | 3,503 / 0, including 3,105 Challenge checks |
| Existing full campaign input | 1,364 / 0, 588 taps, 36 watches |
| Existing Challenge input | 176 / 0, 116 taps |
| Existing headless graphics correspondence | 252 / 0 |

The new test earns all campaign progress through actual engine input from a fresh save. It exercises an Undo win (mask3), No Undo replay (11), then another Undo clear that leaves the cumulative No Undo medal intact. At `archive_02`, the three-move par route earns11/best3; the explicit five-move treasure detour earns current13, collected15, best3. Equivalent pinned Challenge UI generation/replay checks separate record identity and parked campaign ownership, with treasure off and on. Normal uninstrumented shipping scenes cold-load the exact persisted bytes and complete data; observed cold won routes make no new-award claim.

The test-only PaintObserver inherits the production owner, records `text_at` arguments and delegates drawing unchanged. It observes emitted labels and coordinates, not pixels. Actual font ascent/descent/width bounds are checked against result, Next and Journey rectangles at344×642,690×829 and1066×600 through the real stretch transform. Read-only typed layout cases cover every authored eligibility mask, longest names, valid maximum best values and the existing Challenge fallback-record label; these are labelled layout inputs, not injected or newly earned progress. Repeated presentation queries/drawing preserve the complete data/state and exact file bytes. The single new script UID was allocated through ResourceUID in a direct headless invocation; no editor import occurred.

`MEDAL_FEEDBACK.json` pins all retained failures, final packet artifacts, current normalized source, unchanged base files and UID receipt. Superseded passing packets were removed after the final batch verified them; their small report hashes remain in that record. Historical recovery and motion records remain untouched.

Reproduce from the repository root with the existing imported cache:

```powershell
python android-games/tower-trials/tools/design_check.py --skip-import medal_feedback
python android-games/tower-trials/tools/design_check.py --skip-import medal_feedback import_recovery run_tests campaign_playthrough challenge_playthrough graphics_view
```

All automated work used headless Godot4.7.2/Dummy audio. No renderer, editor import, emulator, Android/native operation, OS clipboard, build, upload or publication was used. Headless emitted-text/font geometry does not establish raster readability or replay motivation. Short normal-speed rendered/native checks and human comprehension/fun remain coordinator gates.
