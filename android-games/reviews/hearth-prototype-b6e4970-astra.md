# Hearthguard defining-loop review

Reviewed frozen worker `b6e497063964e9efc92f00112db064aa0c6bf43f`, integrated as `8ad6177`. Source inspected only from `.artifacts/reviews/hearth-prototype-b6e4970/source/`. This is an independent static and visual first-loop review, not independent execution of game tests, Android acceptance, or full-campaign acceptance.

**Verdict: conditional GO for campaign expansion. No P1/P2 defect found in this bounded review.** The prototype preserves the selected movement/collection/construction/defense identity and demonstrates a consequential second investment. The coordinator's independent rerun and early Android export/input/lifecycle checks remain required; the current 43.617-second successful route is a prototype, not the required 30–60-minute initial arc.

## Evidence and direct playback

The reviewer independently read these file hashes:

- `review-package.json`: `ba12c7cd47bba3e9f1d3463847b9e83035168119a2b864843ca89bf2b6fc2cf0`.
- `evidence/.artifacts/freeze1-movie-20261018T032413941224Z/continuous.mp4`: `4ee4c52bdb7564a926b0c0f2ab9ec70f34c09e7684df0db18ae4a68a45f6f92e`.

The coordinator's package binds 12 executed source files, all 14 tracked files by normalized content, 181 artifacts, and 31 decoded PNGs. That complete binding verification is coordinator evidence; this reviewer did not independently rehash every entry.

The full 24.033-second movie was directly played from the opening to the end without seeking, then replayed, with consecutive settled screenshots during playback. Checkpoints were sparse, approximately opening, 12 seconds, 20 seconds and ending, rather than frame-by-frame inspection. The movie is a continuous original fixed-rate desktop capture through both investments and several seconds of combat. It does not contain the full victory route. Its final blank background follows the test's scene removal (`tests/playthrough.gd:130-137`); it is not evidence of a natural gameplay black-screen failure.

Eight original PNGs were directly viewed: rendered `02-natural-defeat`, `03-actual-retry`, `11-natural-victory`, `06b-active-inner`; movie `05-before-bolt`, `06-bolt-constructed`, `07-visible-firing`, `10-heavy-investment`. The reviewer-created browser tab was closed; the server remains coordinator-owned.

Inspected frozen logs contain PASS sentinels for 56 rules/storage checks, 44 headless input checks, 46 rendered input checks and 9 movie checks. These are builder executions, not executions by this reviewer; the coordinator's independent rerun was pending when this report was written.

## Fidelity, readability and appeal

The visible loop is the intended close, angled overhead 3D activity: a moving teal warden collects conspicuous gold beside a winding road; priced pads become persistent defenses; bolts fire into an advancing column; road rewards finance the downstream tower. Both pads, the avatar and useful road coverage remain visible together. The directly viewed terminal images clearly distinguish four-leak defeat, a fully restocked Retry, and a 20-stopped/no-leak victory. The inner-proportion image keeps the battlefield and controls readable, although actual phone safe areas and touch comfort are untested.

The exact recorded movie checkpoints make the economy legible: before Bolt, wallet 5/spent 0 at 1.45 seconds; after construction, wallet 0/spent 5 at 2.067 seconds; Heavy built with wallet 0/spent 20 and six kills at 18.917 seconds. The full rendered input route reaches victory at 43.617 seconds, 20 kills, no leaks and wallet 42. The simulated timing is not a measured human completion time.

This matches the selected K2 activity, whose earlier independent direct viewing is recorded in `three-action-references-astra.md`. K2's Kingshot attribution remains third-party indexed; the current review did not rewatch K2 or establish official advertiser provenance. Explicit Build, exact 5/15 debits, pickup radius, damage and targeting are original playable rules, not verified universal commercial mechanics. Avatar shooting, dash, mounting and avatar health are not missing prototype requirements.

Nonblocking presentation work for the campaign: Bolt and Heavy currently share nearly the same silhouette and rely on labels to distinguish them; give later families/forks a recognizable shape and firing effect. `WARDEN` can overlap a pad price in the before-build PNG, but the contextual button repeats the full type and price, so the purchase remains legible. Keep that redundant price information. The current sparse column and coin density work as an introduction; later pressure should approach the reference's abundant moving column without covering prices or travel routes with effects.

## Correctness and evidence integrity

- **Causal construction and combat:** `rules.gd:41-47` checks phase, occupancy, distance and funds before one exact debit. `:49-57,81-97` limits range, targets the furthest-along enemy, applies real damage, emits a visible shot and creates one identified reward on death. The visuals consume those events (`main.gd:503-517,622-628`); this is not decorative fire disconnected from kills. Damage is immediate with an animated visual bolt, an acceptable original simplification.
- **Consequence:** the synthetic counterfactual in `tests/run_tests.gd:73-86` builds only Bolt and naturally loses, while the funded two-tower rule route wins. The actual-input route independently earns both constructions and reaches its terminal state. This establishes consequence, not multiple viable strategies: the prototype still has one prescribed spending sequence.
- **Accounting and state bounds:** `rules.gd:134-189` validates finite values, occupied-pad spending, unique/resolved actor IDs, killed-versus-leaked partition, refuge damage, coin ownership, reward value and wallet-plus-spent conservation. Initial coins have their fixed reachable locations; battle drops follow the road. No routine current-route crash or duplicate reward path was found. Campaign data will need fresh bounds rather than simply increasing current constants.
- **Retry and lifecycle:** `main.gd:394-402` replaces the battle budget/actors/towers with a fresh run while preserving profile/settings. `:514-517` records results only at the live transition. Pause/focus loss stops movement and saves; a cold active run opens paused (`:50-66,404-430`). The inspected tests prove engine notifications/ordinary scene reload and desktop window ratios, not real Android HOME, Back, folding or process death.
- **Persistence/import:** `save_store.gd:35-58` selects the highest checked candidate and writes the other slot. Recoverable ordinary staging is separated from unpromoted imported staging. `main.gd:485-498` validates and commits storage before replacing memory. Write/readback/rename failures are checked; the newest recovery candidate remains untouched. The focused synthetic fault tests cover failed import retention and sole staged-candidate survival. `save_files.gd:9-21` checks write/flush errors and only removes the older destination for promotion.
- **Actual input scope:** the natural route uses ScreenTouch/drag events and normal processing (`tests/playthrough.gd:63-128,277-327`), with state reads steering its policy. It does not inject earned money or force a terminal redraw. Transfer tests use touched TextEdit plus injected keys; the headless valid-text fallback is explicitly a fixture (`:173-175`). The synthetic storage adapter is not an actual disk failure. Desktop clipboard/touch focus does not prove Android IME or Unicode composition. The tests should remain described at those limits.

## Conditions for substantive campaign expansion

1. Preserve active movement, local battle drops, explicit priced construction and visible defense response in early, middle and final maps. Do not turn this into a stationary build board or settlement timer.
2. Keep the proposed 10 maps/three regions as a planning target, but make maps differ in coverage geometry, travel distance, simultaneous route pressure and spending timing. The existing 5-then-15 sequence is an introductory lesson; ten copies with larger enemy HP would fail the goal. Retain the three tower families/forks, six enemy roles and three bosses where each creates a distinct decision. Actor attacks or health are unnecessary additions to achieve this depth.
3. Demonstrate two genuinely viable funded layouts on late maps and a diagnosable failed choice corrected through Retry/refit. Vary routes, threat order and timing when checking policies; do not tune every map solely to one omniscient nearest-coin script. Once both prototype towers are bought, remaining movement has no strategic use; later maps need further useful investment decisions during pressure, without forced collection after combat is already resolved.
4. Pin complete run definitions, stable map IDs and schema/catalog versions before expanding data. Preserve existing version-1 prototype saves with an explicit legacy path or migration; attempts/wins from this single pass must not invent campaign clears. Retry restores the selected run's definition and starting budget. Test malformed snapshots, duplicate rewards, sold/upgraded occupancy/refunds, spawn completion and recovery at the new limits.
5. Deliver the full meaningful initial arc, final victory, alternate budgets/routes, seeded replay/endless and no-leak mastery. Preserve immediate Retry, no grind and no empty-field resource deadlock. Content counts and scripted simulation minutes cannot establish 30–60 minutes of enjoyable human play; pacing/fun remain human playtest obligations.

Before a software candidate, complete independent shared-harness verification, signed offline APK checks, real update retention and Android touch/transfer/Back/HOME/cold restoration. Physical Galaxy Z Fold7 input/folding/safe areas, heavy-wave FPS, audible sound and human appeal remain separate, unclaimed gates. None of those pending checks is permission to shrink the full-game scope or stall independent work while phone feedback awaits Daniel.

## Coordinator execution follow-up

Independent root execution subsequently passes56rules,44headless and46rendered
checks on the unchanged original runtime. The first rendered route reached the
natural outcomes but failed one immediate Windows clipboard-get assertion with
a backend access error. It remains archived as failed; the unchanged serial
rerun has zero failures and no backend error. Four raw packets and receipts are
indexed by `android-games/evidence/hearth-first-loop.json` and copied to canonical
storage with SHA-256 readback. This is coordinator execution evidence, not an
additional test run by Astra.

Metadata-only worker477f812 (integratedf9260e4) adds the Android preset and stable
UID/icon metadata. All14original tracked files remain LF-equivalent, including
the reviewed runtime/tests. Root's signed, permission-free0.1.0/code1 APK builds
with stable source86a1787c…; native first-loop and later campaign/update checks
remain pending. The conditional first-loop GO does not accept the full game.
