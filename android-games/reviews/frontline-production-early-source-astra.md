# Frontline production — early source review (Astra)

2026-10-18. **Hold final production acceptance for the two concrete geometry corrections below and the scheduled final motion review.** The production pipeline is on track, but source/import checks and the regional tour are not art or motion acceptance.

## Inspected boundary

Worktree: `C:/projects/active/_worktrees/games-frontline-foundry-20261018`; game `android-games/frontline-foundry`. Compared against accepted benchmark/closure `3a12e04`. Inspection began with dirty production source targeting 0.3.0/code 3 and concluded at clean **`998dce3063eeedd2e60954b89b2796a0771ca257`**. All sixteen inspected hashes below stayed unchanged and match that commit after Git newline normalization. This commit predates the reported corrections; later fixes must be bound separately.

Read runtime/art deltas, actual GLB JSON/vertex data, focused tests, capture/tour/gallery/legacy and timing harnesses, and their retained evidence. Viewed original tour stills `region-02-live.png`, `region-12-brief.png`, `region-12-live.png`. No Godot, browser, GPU render, ADB, clipboard, device or duplicate long playback was started. No numeric visual/motion scores assigned.

## Findings requiring closure

### 1. Ranger PrimaryMuzzle floats 0.2125 units ahead of its weapon

`art/source/build_assets.py:soldier()` sets the Ranger muzzle tip to Blender Y=1.16, but the rifle branch still builds the ordinary barrel/muzzle: cylinder centered at Y=.91, depth .075. The Ranger branch does not author the described longer primary barrel or mounted optic.

This is confirmed in actual `soldier_ranger.glb`: all Weapon-weighted vertices end at Godot Z=-0.94749999; the PrimaryMuzzle rest chain ends at (0.22, 0.79000002, -1.15999997). Its tracer therefore begins about **0.2125 world units in empty space** ahead of the modeled weapon before pose transforms. The new structural test checks bone name/existence and a broad forward position, so it does not catch this.

Correct the intended long-rifle geometry and socket together (or bind the socket to the actual tip). Add the scoped transformed-tip geometry assertion. Preserve rule damage/shot timing. Final reviewed art/clips must identify the corrected version.

### 2. Regional solid landmarks enter traversable space

`scripts/presentation/outpost.gd:build_region()` puts opaque landmarks at x=±5.9 with ±.45 yaw; scale is .75 for four selected landmarks, 1 for cargo/factory models. The claim that every opaque landmark is outside the playable rectangle is false for the actual assets.

CPU transformation of actual GLB vertices, including node transforms and the runtime yaw/placement, finds:
- Right rail_wagon and supply_truck: x reaches **4.5018569**. Intruding vertices occur at z≈0.068–0.715 and y≈0.112–0.670.
- Right foundry_stack: x reaches **4.5269238**, with intruding solid vertices up to y≈1.12.

Campaign commander centers can reach x=4.7 over z=-6.2…5.9. These solids occupy allowed movement space even before allowing for actor body width; ground_height does not account for them. No collision should be added to fix this graphics-only change. Move scenery beyond its transformed opaque extent plus actor clearance, and check all placements (including rotated/horizon variants) with a bounded CPU geometry check. The current tour views do not exercise edge walking and cannot disprove the overlap.

Both findings were sent promptly to the coordinator. They are presentation correctness issues, not detected rule/save regressions.

## Focused risk to cover with the socket correction

The immediate humanoid projectile path calls pose(0), force_update_all_bone_transforms(), then reads a BoneAttachment global marker. Gear's same-engine integration required explicit attachment synchronization for same-call shots. Frontline's new test still does not compare the actual aimed marker against the current animated bone tip. This review has **not independently reproduced** a Frontline deferred-update failure, so it is a risk rather than a third confirmed blocker. Extend the existing scoped socket assertion through a lateral aim/pose before reading the marker; do not infer correctness solely from the rest bone.

## What the delta supports

- **Rules and storage:** `rules.gd`, `campaign_rules.gd`, `definitions.gd`, `save_store.gd` and `boot.gd` are unchanged from 3a12e04 after Git newline normalization. Production changes do not alter event emission, targeting, damage, RNG, timing, stock, progression or save meaning. The 85-check freeze receipt passes; its whole-state comparisons cover 4,800 campaign plus 900 legacy ticks. No rerun of whole campaigns is requested.
- **Body/pose architecture:** The accepted analytical leg gait, separate torso aim, equip/recoil/hit/fallen/victory channels remain. Seven specialist humanoids now resolve separate skinned resources and three bosses separate vehicle resources. PrimaryMuzzle is an additional authored weapon child; no root motion or rule callback is added. Vehicles retain the accepted barrel-parent socket branch. New repair boom, drill rotor and warning dish respond to observational state/events. Their visible quality remains unjudged.
- **Reset safety:** Adapter snapshots still own values. New queue-head request, jammer and warning fields copy observations; jammer radius 4.7 matches rules. First-resume event preservation, terminal gait stop, pause/transient clearing and cold hydration remain intact. Cosmetic ground height changes only render y, keeping authoritative x/z. It avoids sinking through low pads/sandbags but is not a general solution for scenery overlap.
- **Coverage:** Twelve region descriptors map to twelve distinct landmarks; seeded style/variant decoration does not consume gameplay RNG or mutate definitions. Station resources cover four unit roles and Ward/Relay/Recovery. SupplyToken meshes survive merge_static_surfaces and visibility follows actual finite stock. The contextual 2D purchase button retains role/cost when redundant world labels are hidden.
- **Assets:** All 47 actual GLBs match the current manifest. Three independent export hash maps are identical, including the manifest, and match the inspected files. This verifies reproducibility and provenance, not presentation quality. The requested Ranger correction will supersede the relevant hashes.
- **Briefing:** Wrapping forecast/rules labels now live in a VBox within a ScrollContainer above the fixed support action. The actual 720×1280 Foundry brief still shows the objective and role costs without overlapping that action. This is still evidence for that view, not all-size interaction proof.
- **Legacy:** The production legacy harness checks exact saved battle restoration, real GUI resume, then explicit campaign entry with retained legacy state/profile/settings. Its headless receipt passes; it is not a rendered legacy-motion claim.

## Evidence interpretation and measurement

Regional tour `production-regional-tour-tour-20261018T135522608667Z`: passed, source unchanged, 124 recorded input events, 30 snapshots; all twelve live region indexes 0–11 are present. Every snapshot retains the supplied twelve-clear career. The harness uses actual Journey buttons and wheel events, then 2.8-second passages, support selection and seeded Flank entry. This is genuine earned replay selection and regional coverage, **not newly completed campaigns or meaningful combat/motion coverage per district**.

Gallery `production-art-inspection-gallery-20261018T135304318569Z` is correctly labeled synthetic art inspection, not gameplay. The tour predates the guidance outline, version bump and legacy helper registration; its art/outpost/actor pins match this review. The tour's movie timings are not used for performance.

Real-time run `production-realtime-storm-capture-20261018T140229392389Z` has no --fixed-fps, --write-movie or native-frame flag. The sampler is connected after launch and disconnected before the final screenshot; snapshot PNG readbacks are disabled while active. It samples frame_post_draw with a monotonic microsecond clock, excludes inactive/modal states, resets across gaps and discards 1.5 eligible warmup seconds. Ordinary game saves and in-process policy/instrumentation remain part of workload.

Raw evidence: 2,649 rows / 44.219333 eligible seconds; median 16.666 ms, p95 16.759 ms, p99 18.335 ms; no interval above 33.333 ms. Boss-heavy subset: 967 rows / 16.148543 s, p95 16.767 ms, p99 18.3 ms. Maximum actual combatants was **7**, not a twelve-unit crowd; this qualifies through the explicitly declared live-boss branch. Maximum reported draws 1,018 and primitives 286,370. Host: RTX 5070 Ti, Ryzen 7950X3D, Compatibility, 720×1280, VSync on, 2x MSAA. These are bounded desktop **render-loop submission intervals**, not GPU timestamps, OS presentation timing, worst-case crowd assurance or phone FPS. The harness and report state this accurately.

The timing and 85-check freeze captures match all inspected pins. Final acceptance still needs the coordinator-supplied normal-speed opening/heavy/later clips and focused closure evidence bound to the corrections. An unaffected production opening may be retained if exact source/asset and instantiated-scene comparison shows that no repaired Ranger, scenery placement or socket behavior occurs in it. Shared-source edits alone do not require a whole-campaign rerun, but generic landmark relocation or a socket synchronization change affecting the opening's rifle actors would make its affected presentation historical and require a bounded corrected passage. Do not duplicate the accepted old long clips, add a physical-phone gate, require baked animation or use checks to waive weak visible presentation.

## Inspected SHA-256 pins

```json
{
  "scripts/presentation/actor.gd": "f932c9c600303458f31ac776245f3270fa6640876d398889cdfadd00d99f6ffb",
  "scripts/presentation/adapter.gd": "ae5b1965a5d0b06bd882ebdc63061eb4d797368e3c303905297d0aa7bcc436a8",
  "scripts/presentation/outpost.gd": "0937550a36b7231d76129e45ba9ccd8b8d58b51d622b345cf2dc736a5b8a3cb2",
  "scripts/presentation/regions.gd": "fdd89ff6c4964a28073a38300c600b6e2c1f8d1c2756ae37007d3c912a9614a0",
  "scripts/main.gd": "65b4944ef39e85890dca2351c237191db6ec93d354bc962177064edfe418678a",
  "scripts/campaign_main.gd": "e161d0e5d3dd73ab58e9bcd11de5124fdf7b02c37c56dc66a5e8cf14e27d9096",
  "art/source/build_assets.py": "f1a0ec221d5e6f552073c730c6f9d6d375af5b55b9802e270d76bee1c2caf746",
  "art/source/world_kit.py": "2083c830b7844be9fa3b11586f08c681697fd46d62a028a0496f4f7200e03a6e",
  "art/manifest.json": "ec9246d7f924e9724b8e93529df0f00ebda8511e108a2d1926d1e2cbb30dbee9",
  "tests/frame_sampler.gd": "97fb43384639d85988d486c16a41a5692840ca9b6e36a0c1dfe0d4ee1409cd6b",
  "tests/graphics_benchmark.gd": "6ce8ab5c6a96a731fdf1723d003d125c042cf0de97b8a6f47bb150d9427b20f9",
  "tests/graphics_tour.gd": "3ce3a451aeadf19e8766ea6158a459afb8933960de70f8de1e4ad8c570a7077a",
  "tests/presentation_tests.gd": "a7b898ff61550c3a0f76e923d2307292da1fcc63a6c3ddaf522c3fb78bc659ab",
  "tests/run_graphics.py": "d71f0e2ac435fbf39a2007a891b2fa2496d034b475282a4a535f9668290d940d",
  "project.godot": "55499ec4e02a1d0d87abb5e5e2212744563b8f42f70bdf815f57446f78ccf8d3",
  "export_presets.cfg": "81eff288f28884ead3d6897021448414414d9822815df3605b1f87b397a65daf"
}
```

