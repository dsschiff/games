# Gear Bastion — early 3D source review (Astra)

2026-10-18. **Disposition: proceed to the bounded rendered checkpoint. No source blocker identified. This is not visual, performance, benchmark, Android, or release acceptance.**

## Source and evidence boundary

Inspected worktree: `C:/projects/active/_worktrees/games-gear-bastion-20261017`. Inspection began against dirty code-7 baseline `45baca53cf6b422db98813a92a2be05198aa9f0b`; it concluded at clean candidate **`f67112c590d0db67ade6814416ec752a1d6a2422`**. The 14 final pins below did not change between hashing and end-of-review comparison and match the commit, allowing Git CRLF normalization. No runtime/art drift was found against the inspected CPU/import/input receipts. Test additions during the wider review account for the earlier 6,912/6,926 versus final 6,932 totals; they do not make the earlier dirty state a frozen candidate.

Read the rule delta, adapter, actor, foundry, main/campaign presentation integration, authored generator/helpers, manifest and actual GLB JSON/skin structure, focused tests and receipts. No Godot process, browser, renderer, ADB, clipboard, physical device or new test campaign was used by this reviewer.

Evidence inspected:
- `.artifacts/graphics-production/checks-20261018T134249944833Z/receipt.json`: pass, source unchanged. Current CPU report: **6,932 checks, 2,236 event recipients, zero failures**. The side-by-side test compares whole dictionaries for 4,500 ticks across camp_04, camp_09 and legacy iron_trial, with additional isolated boss-volley fixtures. The stored baseline is byte-exact `git show 45baca5:.../battle_rules.gd` after removing only `class_name BattleRules\n`.
- `input-20261018T134220790534Z/receipt.json` and `input/headless/report.json`: **1,462 checks, 194 input events, zero failures, rendered=false**. Receipt correctly says source_unchanged=false: only three generated test UID files appeared during that run. Current runtime/art pins match. These are real dispatched Godot input events under a headless test harness with an isolated fake save backend, not native Android or live framebuffer evidence.
- `fresh-import-20261018T134125440882Z/receipt.json`: pass, source unchanged. Later helper/test-only changes are distinct from the validated runtime. The runner imports before loading GLBs and requires a suite-completion marker.
- All **22 actual GLB files** match manifest SHA-256. Twelve actor GLBs contain 16–18-joint skins; every skinned primitive has JOINTS_0/WEIGHTS_0. Authored generator/helper hashes match the manifest. No baked animation clips are present; runtime skeletal articulation is explicit and is not rejected merely for that choice.

## Architecture findings

| Area | Source assessment |
|---|---|
| Rules, RNG, saves and timing | Optional presentation arrays are appended after existing authoritative damage. The diff does not alter damage, target ordering, cooldowns, movement, spawning, random/serial state or save schema. Main still steps the same fixed Battle.STEP and immediately hands each substep's events to presentation. Whole-state comparisons support this bounded preservation claim. |
| Primary, splash and volley identity | Serial IDs are global across both sides. Primary/splash share attacker-and-tick identity; recipient dedupe includes kind and target. Separate attack dedupe produces one firing action while retaining each recipient reaction. Volley uses a distinct suffix and therefore cannot swallow a same-tick normal attack. Existing wall/volley rule damage remains authoritative. |
| Socket and defeat | The contact marker is transformed from manifest model space into the actual Weapon rest frame. Fire poses the skeleton, forces bone updates and synchronizes the BoneAttachment before the immediate tracer is created, addressing deferred-transform staleness. The focused assertion compares the actual marker to the animated bone-derived point. Removed living instances become bounded 0.9-second articulated corpses; normal hit/recoil/death channels are implemented. This proves binding, not attractive contact motion. |
| Interpolation and lifecycle | Adapter snapshots copy scalar/vector values, so pose interpolation cannot mutate rules. Attempt epochs and explicit hydration clear old actors, corpses, effects and both dedupe layers. Retry, mission/challenge start, legacy replacement and successful import call reset. Loaded active battles hydrate paused. Resume does not reset and discard its first event batch. Terminal velocity is zero, avoiding endless march after outcome. Pause exits before pose/effect clocks advance. |
| Field, board and input | The retained fitted 2D layout is the coordinate authority. Orthographic ground projection/unprojection maps board centers consistently; 3D presentation does not replace existing picking. Deployment follows the selected generator through its lane arch before reaching the rule point. Board topology, power links, rate/OFF/lane overlays and existing HUD warnings remain tied to rules. Resize refits the camera, repositions live actors, rebuilds board/scenery, clears transient effects and cancels held input. |
| Entry routes | Main owns one shared presentation for campaign, challenge/replay and legacy routes. Initialization, replacement and import were inspected; no separate stale 2D-only gameplay route was found. Map/menu UI remains 2D. |

## Material risks for the already-planned rendered checkpoint

1. **Crowd rendering is still unproven.** Actors carry roughly 7,804–9,808 triangles and 3–6 material primitives each. At 120 friendly/90 enemy caps, skinning, shadow passes, health meshes and scene-node traversal can be material costs despite pooled materials and a 48-effect cap. The SubViewport also stays UPDATE_ALWAYS behind the map/pause UI. Use the already-planned actual draw-call/frame-tail evidence; do not convert fixed capture cadence or CPU success into an FPS claim.
2. **Check contact and locomotion in actual motion.** Immediate damage is preserved and the animation starts at contact/recovery. Analytic socket agreement does not establish barrel direction, readable melee reach, convincing foot planting or insect articulation. Insect legs inherit Torso aim, so lateral attack turns deserve observation in the planned footage. No motion/style score is assigned from source.
3. **Check the projected causal chain at useful size.** Ground-point round trips do not prove tall model silhouettes, arch depth, wall impacts, board labels and touch targets are visually aligned or unobscured. The existing fit tests establish coordinate behavior; the next render establishes readable generator → gate → troop → target flow.
4. **Evidence scope stays bounded.** The adapter/event count checks demonstrate dedupe and recipients, not every visible effect; effects may be dropped at the deliberate 48-node budget. Headless save-transfer tests use an isolated backend. Cold-load appearance, pause/resume continuity, reduced-effects readability, final art quality and genuine frame behavior remain for the planned rendered/runtime evidence, with no request to repeat whole campaigns or add a physical gate.

No new broad test requirement or style-only blocker is raised. The authored, rigged pipeline is technically on track for visual review. Keep version 0.3.3/code 7 and release boundaries separate until the production workflow deliberately advances them.

## Inspected final SHA-256 pins

```json
{
  "scripts/battle_rules.gd": "c97273c0566793b724253889806cd13a14285b1847cd76d2718c01e466fac6cf",
  "scripts/main.gd": "bed108818b26911452fd5b0670181a33001dec0a12410d9433b34586f527c347",
  "scripts/campaign_ui.gd": "ef6dd2fe896df5f2380010d82dac10d5b23c78090bafcec31067ad0f9d2bbe02",
  "scripts/campaign_view.gd": "3fcaae1aa408a98c0cf047b1b8eed4e124167ad27f77b3df15c68990c0764ea6",
  "scripts/window_layout.gd": "6d7a4a3002ab09cec610be95eb120d4d38360628de9788f038e5743cf776229b",
  "scripts/presentation/adapter.gd": "60ac48cc7d515b5c26967102e221fa539caaa6a8b86c0e60534f3e6db6058e13",
  "scripts/presentation/actor.gd": "db973e40dee2884f998e8ac828cb26d69890d34cae6bcc46a56ebcfad3c418ae",
  "scripts/presentation/foundry.gd": "60c9cc863a90814fb070f2c2860c55853f529ef41f0cd2bd5d78ba0eb3660af8",
  "art/source/build_assets.py": "b07ec1271cf35c99ae8604f9a3909629ff49447ecf55dd8c90fd5ffac945b483",
  "art/source/mesh_tools.py": "ef6336d19019b76d6d7f81556ac649b50ccffb865bbd2a2da6802197f3b162fb",
  "art/manifest.json": "7de1f607ffe90400701493ed8f3c8ff01c86be689cc616ec850c0be747375218",
  "tests/presentation_tests.gd": "3ae092e948a742ed7d962d2c895521b843fc680fe2a7054c49cdade8248cc6e1",
  "tests/graphics_input.gd": "abf2df550f37edd9a8b6d482186bbff9c65dd563b57a7da1df53f20a323968b2",
  "tests/run_graphics.py": "d16c3a21a63502eef3be68bfb5b489f9a8668b0d0feea47f4d01e658c6a6a516"
}
```

