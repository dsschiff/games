# Hearthguard early graphics source review

2026-10-18; CPU/files only. No Godot, Blender, GPU, browser, ADB or device execution by this reviewer. Active dirty worker: `C:/projects/active/_worktrees/games-hearthguard-20261018`, HEAD `c36df6e0dcdda2f38670965090664c682777a2e8`. No visual scores or graphics acceptance.

## Findings requiring focused correction

1. **The first resumed simulation tick loses its real attack/heal observations.** `campaign_main.gd:391` and `main.gd:505` queue the events returned by the newly executed rule tick, then call synchronize. `presentation/adapter.gd:25` treats paused→running as hydration; `settlement.gd:233–249` clears the pending batch on hydration. Thus an actual shot on that first resumed tick still damages its target but gets no corresponding projectile/operator pose. Preserve fresh post-resume observations while discarding genuinely stale pre-boundary observations, or synchronize the resume boundary before advancing rules. A focused shot-on-first-resumed-tick assertion is sufficient; no rule timing change is needed.

2. **Terminal actors can continue walking in place from the last movement delta.** At victory/defeat the rules stop advancing time. Adapter ingestion only replaces `previous` when time advances (`adapter.gd:28`), leaving the final movement interval indefinitely. `settlement.gd:411` continues deriving nonzero velocity from it whenever not explicitly paused, and passes that to `Actor.pose` each frame. A surviving commander or enemy can therefore keep advancing gait while its position remains fixed under the terminal screen. Stop locomotion when the simulation is terminal, or consume the final interpolation interval and then settle velocity; preserve the intended finite death/victory feedback. Assert terminal pose settling without changing saved state.

Both are concrete source-path findings, not rendered observations. They were reported to the coordinator promptly. Existing CPU passes do not cover these two sequences.

## Architecture and invariants

The new adapter constructs its own actor records, deep-copies towers/coins and copies primitive ID arrays. Previous/current interpolation snapshots do not alias rule dictionaries. Definition identity, backwards time and held-state boundaries reset an epoch; the transient observation cursor is bounded to 512 keys. Queued events are deep-copied. Presentation clocks and deterministic phase offsets use no gameplay RNG.

Independently compared current files with HEAD: `rules.gd`, `campaign_rules.gd`, `campaign_catalog.gd`, `save_store.gd`, `save_files.gd` and `bootstrap.gd` are byte-exact. Attack events remain the existing rule outputs, including tower family/fork/target/area in campaign and legacy pad/target events. Graphics do not schedule combat or modify save schemas. Campaign and legacy both route through the shared presenter; import and campaign replacement rebuild it, while Retry uses the adapter's backwards-time reset. The ordinary startup scene routing and parked legacy save paths remain intact.

Actor `socket_position()` explicitly forces skeleton updates and synchronizes its BoneAttachment from the WeaponTip global pose before reading the marker, addressing the deferred-transform problem encountered in the prior games. Tower projectiles read the authored tip under the actual turret after applying aim; recoil also acts on that parent. Current tests inspect actual imported skin vertices and turret geometry. No source evidence of a generic pad-origin shot substitution was found. Correct aim/contact still needs actual rendered observation.

Scenery records transform all eight corners of manifest mesh bounds rather than just origins or unrotated extents. The generator computes export bounds from world-transformed object corners. Ten regional compositions share the original rule road/pad coordinates. The camera fits a fixed 3D play/body box into the usable field with uniform scale, not independent X/Z distortion, and rebuilds call layout once UI exists. These are useful safeguards, not proof that scenery is attractive, fully visible or unobtrusive in motion. Region variants/legacy framing and safe-area visuals remain for the planned bounded rendered work.

## Evidence status and limitations

Preserved early runs `cpu-first-checks-20261018T153836810997Z` and `cpu-parse2-checks-20261018T153914573485Z` failed. The latter's inheritance parse error and float assertion are historical/in-progress repairs, not additional present findings. Completed `cpu-integration3-checks-20261018T154104330706Z` reports **245 checks, zero failures, source unchanged during that run**. Its log includes 4,800 campaign policy ticks across maps 1/6/10, 1,000 legacy ticks, actual imported geometry/projection and app input/pause/Retry checks.

That passing receipt does **not** bind the current full asset snapshot: subsequent changes affect the generator/manifest, all 30 GLBs, actor/settlement scripts and presentation tests. The builder is actively completing deterministic export and integration. A new `graphics_passage.gd` also appeared during review and was not reviewed here. No clean/frozen acceptance is inferred. Finish the focused fixes and source-bound checks already underway before the first short rendered inspection; no whole-campaign repeat or physical-phone gate is requested.

## Observed source pins

The following GDScript/helper hashes were unchanged between this review's two explicit pin reads. Art generation was active; its listed hashes describe the final read only.

| File | SHA-256 |
|---|---|
| presentation/actor.gd | ed0526f329a879941e2c1f5d31be9bf1d65e1f7f39823ee26978258e26b91e4e |
| presentation/adapter.gd | ed79b6365060fa1f33b2b350ed6ca5308d6e6172bd15960deea0c05e4dd0cd63 |
| presentation/settlement.gd | eb9a255f9ffce2bcceb2a285609f2250f2c656f34f3a713389b86c93dcdba9b4 |
| presentation/regions.gd | 6bfed42c0095b006bdb005d07228ff45594fe0aeb2f476a02ecffba1a7c72361 |
| scripts/main.gd | 98239cdb45284d6dced20a676b45ec982f5ebf0baba0b14ce05f927b5ddbcbd5 |
| scripts/campaign_main.gd | 29d6651c4a102e86729585e88368b8aca03e374ce5d1898b945e24ae794316e0 |
| tests/presentation_tests.gd | dd1e9426bb96228b6eb85a5904de9c39867cdecb5bc5427e9727209f9493a6e5 |
| tests/run_graphics.py | 62ee42cf9eb9c6f71b8e4c53984248b998ee14b6f5d9f5744b163dfead23d58d |
| art/source/build_assets.py | 0b8138354926704533cc81f902c0d7b3ebcd10e7d7f49c6814c4bae156d99d66 |
| art/manifest.json | f178ddff290eb6696baccd3bf5a2d1c02f541b7ff97c9d20977f0a94887ac9b3 |
