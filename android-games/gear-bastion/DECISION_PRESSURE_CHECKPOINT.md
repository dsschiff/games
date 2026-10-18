# Code 6 decision, HUD and terminal-render candidate

Source 0.3.2 / code 6 preserves the nine-gate campaign, three seeded replays and schema 4 profile/run saves. It is ready for independent software-candidate review. Current Android, physical-phone and human pacing/fun acceptance remain pending. No adb or code 6 APK export was performed by this builder.

## Changes

Three Fronts reserves now hold near their assigned exit. Previously the generic idle formation dispersed troops across the whole wall, silently covering neglected flanks. The behavior is pinned in the encounter snapshot; older snapshots without the flag retain their prior holding behavior. Preparation names the West/East/Center sequence. The troop cap remains unchanged.

Furnace Tide uses shorter, denser later formations: 100 rather than 80 enemies in the third wave, 120 rather than 96 in the fifth, with four-enemy packs. The third-wave interval is 1.0 s and the final interval 0.8 s. Its late enemy-health/damage modifiers provide pressure without adding solved wave waits. The final useful spending plans are focused ranger refits, rather than the initially explored expensive splash expansion. Banking can also win: the decision is how to allocate salvage efficiently, not a requirement to spend every grant.

Boss health, phase and volley/enrage information now occupy the resource strip below the wall. Rally moved beside the socket board. Neither covers the boss or upper-field engagements. The normal process loop explicitly requests redraw on victory/defeat and pause/resume notifications, retaining event-driven idle rendering. This fixes the independently confirmed code 5 stale-terminal frame. Headless tests skip audio playback; rendered and app audio paths remain present.

## Actual-input mistake and Retry correction

Every pair below uses real input events with simulation time accelerated. The full route remains the primary `tests/playthrough.gd`; no fabricated progression is injected. Victory, defeat, same-state recovery, compressed typed import, Practice/Undo and all three seeded replay wins remain covered.

| Gate | Weak choice | Correction and observed result |
| --- | --- | --- |
| 1 | Disconnected starter: defeat | Connect and fund production: win, wall 220 |
| 2 | Unshielded rangers: defeat | Mixed screening: win at the same 56-brass spend |
| 3 | Guard-only captain attempt: defeat, 781 losses | Ranged support: win, 97 losses |
| 4 | Guard-heavy build: win, 219 losses, 72 spent | Mixed splash/ranged build: 47 losses, 74 spent |
| 5 | Exposed rangers on the broken board: defeat | Reconnect the kit and protect the flanks: win |
| 6 | Guard-only escort attempt: defeat | Mixed damage survives the escorts and engine |
| 7 | Leave all production at the original exit: wall 81 | Same 82-brass kit with reallocation: wall 215 |
| 8 | Splash and drive expansion: 253 losses, 92 spent, 2 medals | Focused ranger refits: 175 losses, 72 spent, 3 medals |
| 9 | Guard-only final assault: defeat | Mixed army: win, wall 220 |

The correction need not rescue an already-finished run live. The tests use Retry and revised preparation, with actual in-battle gate/refit/purchase inputs where relevant. Gate 7 trades 11 additional casualties for 134 preserved wall health. Gate 8 saves 20 brass and 78 troops while finishing 6.37 s sooner; both choices clear it.

## Verification and limits

- Rules: **164 passed**. Full headless input: **82 passed**,1,324 pointer + 5 keyboard events. Rendered full input with Dummy audio: **83 passed**,1,328 pointer + 6,679 keyboard events. All nine decision comparisons and all three curated replay wins pass.
- Rendered natural termination: **10 passed**, including untouched victory/defeat frames and no continuing idle redraw. The atlas is fully initialized before the measurement, and the test requests no redraw after the natural transition. The coordinator ran the identical probe against frozen code 5 and observed exactly the two expected terminal-paint failures, with an unchanged source fingerprint.
- Rendered actor atlas: **13 passed**, covering all twelve kinds and normal/white-hit silhouettes. No new performance claim follows from those rendering checks.
- Nearby seeds 1700/1701/1702: **54/54** exact-step main-route cases pass. Three-second delayed responses on the two changed encounters: **12/12** pass. Complete final Furnace Tide cohorts replace their earlier draft cohorts; the other encounters retain identical mechanics. Final guidance wording changed after the mechanical probes. The checked-in case file records this provenance explicitly.
- The two Furnace Tide plans spend 76 and 72 brass. Both win every tested nearby seed, including the delayed responses. Static banking also wins the three tested seeds; it remains a valid alternative rather than a falsely claimed failure.
- Fixed-role/no-production controls: **45 attempted**, including **4 unavailable-role attempts**, leaving 41 valid controls. Of the 41 valid controls, 10 win and 31 lose; the four unavailable-role attempts also lose. The mortar introduction permits all three troop roles. No tested single-role policy clears the whole campaign. These are bounded policy controls, not exhaustive balance validation.

The selected corrected route lasts **1,796.4 simulated seconds (29 m 56 s)**; all nine weak-choice witnesses plus corrections total **3,100.5 simulated seconds (51 m 41 s)**, excluding preparation and replay. These are automated simulation durations, not observed human playtime. The army is at the 120-unit cap for **1,288.4 s (71.7%)** of corrected combat. That remains a pacing/readability concern. Rally and 2× speed can shorten familiar fights; no empty waits were added to reach a duration target.

Frozen source/clip hashes, actual-input comparisons, natural-terminal proof and exact-step cohorts are indexed in `evidence/decision-pressure-checkpoint.json` and `evidence/decision-pressure-policy-cases.json`. New movies are under `.artifacts/campaign-pressure-motion/`; the earlier code 5 motion/snapshot files remain unchanged. The new early/middle/final-boss movies replay genuine input-suite saves for 12 s at fixed 30 FPS, rather than measuring device FPS.

The residual gates are independent HUD/terminal-motion review, current code 6 Android update/lifecycle/Back/clipboard checks, physical Fold 7 geometry/safe areas/sound/performance, and human pacing/fun. The crowded army still needs that review; its cap was not raised to hide the issue. The prior code 5 Android data/progression successes do not validate this changed presentation or terminal invalidation fix.
