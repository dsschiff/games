# Dead Run original 3D graphics production

Branch `claude/dead-run-graphics`, based on `22a7ef7`. Only this game directory
changed. Presentation only: rules, campaign rules/data, save files and schemas,
tick order, RNG, spawning, collision, damage, package id, signing, export
presets, project/version metadata and delivery metadata are byte-identical in
normalized LF form (proof below). Root still owns review, integration, export,
signing, emulator/native checks and delivery. Not a release candidate.

## What changed on screen

- **Camera.** Lower elevated chase view (`(0, 9.5, 8.5)` looking at
  `(0, 0, -14)`), authored horizontal FOV 51 (was 46). The whole near road,
  the widest footprint and all edge positions stay inside the existing
  projection margins; the road recedes into depth fog toward a visible horizon.
  Wider windows keep native vertical coverage and reveal more street at the
  sides (the existing `frame_camera()` rule, unchanged).
- **Crew.** Chunky blue-uniformed soldiers (helmet, goggles, vest, pack,
  two-handed carbine) on a skinned 19-joint rig. Distance-driven run cycle,
  steering lean, per-fire recoil on the actual rule fire tick, muzzle flash at
  the authored `Muzzle` bone, cheer on victory, backward fall when a member is
  lost, scale-in plus gold ring when a recruit joins. Shoulders are narrow so
  every body stays inside the rule's 0.24 m member half-width: the gold
  footprint still bounds the whole crew.
- **Infected.** Six skinned roles with distinct silhouettes and colours:
  drifter (grey-green, reaching shamble), runner (red hood, sprinting arms),
  plated (road-sign breastplate, bucket helm), spitter (glowing throat sac and
  back pustules, head-throw windup and a lobbed glob to its spit mark),
  cluster (small purple fungus-capped crawlers), bulwark (hulking brute behind
  a striped concrete slab). Hit flinch, impact sparks (pale for armour, role
  ichor for flesh), damage bar when hurt, kill burst plus additive pop and a
  ground splat, then the body lies on the moving road and shrinks away.
- **Gates.** White posts and lit header, translucent blue (positive) or red
  (negative) panel exactly at the rule width, large signed number with
  "CREW", sparks and a number pulse on every shot that changes the value.
- **Rescues and hazards.** Rigging cranes and flood pumps are trucks that drive
  on the sidewalk with the convoy; their boom holds the cage of three riggers
  or the intake pump over the rule lane at head height, so infected pass under
  rather than through them. Health bar, sparks on hits, burst on rescue.
  Carts are loaded hand-carts scaled to the rule width. Attack marks are
  orange, pulsing translucent decals that turn solid red when they fire.
- **Bosses.** Cable Matron (skinned, suspended from cables, sweeping arms on
  attack telegraphs), Toll Ram (skinned brute behind a striped toll plate,
  walks backward with the convoy), Spore Bell (hanging fungal bell, bobbing
  and turning), Ferry Eater (giant sea creature on a floodwater surge with two
  separately damaged arms and an exposed core), and the ordinary-road evac
  blockade (wheeled scrap barricade). Name plus HP readout and bar above each.
- **Districts.** Canal Works (canal with seawall and bollards, warehouses,
  containers, dock cranes, vans), Market Viaduct (guard-railed deck above a
  market level of awnings and apartments), Reservoir Ring (embankments, green
  pipes with valves, storage tanks in the water), Ferry Approach (pier with
  palms, lifebuoys, sandbags, dock cranes, terminals and the ferry at the
  horizon, which casts off after the final earned victory). Each has its own
  sky, fog colour, ground and far skyline silhouettes plus clouds.
- **Scrolling.** All street dressing, road tiles (plain, crosswalk, arrows and
  manhole variants), lane dashes and water ripples scroll at the rule road
  speed derived from the tick, so gates, carts and scenery share one moving
  ground. Gait phase advances by ground-relative distance per character
  (crew 1.9 m/s forward; each infected `role speed - 1.9`, which is negative
  for slow roles, so they backpedal with planted feet).
- **HUD.** Same labels, texts and buttons; added a translucent rounded strip
  behind the status block, text outlines and a matching pause button.
- **Reduced effects.** Removes muzzle flashes, sparks, pops, splats, gate
  pulses, join rings, telegraph pulsing and camera shake. Keeps tracers,
  telegraph decals (orange/red), labels, bars and all character animation.
- **Legacy canal bridge.** `main.gd`/`legacy_view.gd` are unchanged; the legacy
  view keeps its simpler primitive look and still runs (covered by the full
  input journey and the projection test's two legacy passes).

## Kit

`art/source/build_assets.py` is the complete original generator (pattern
adapted from this portfolio's Hook and Hunger generator). Pinned Blender
4.5.14, background mode, factory startup, two threads, no render:

```powershell
& "C:/projects/active/.game-toolchain/blender/4.5.14/blender-4.5.14-windows-x64/blender.exe" --background --factory-startup --threads 2 --python art/source/build_assets.py
python -B tests/verify_kit.py
```

43 GLBs: crew, six infected roles, two skinned bosses (Matron, Ram), Bell,
Ferry Eater and its arm, blockade, three road tiles and 27 props. Every part
carries its sRGB colour as a vertex colour; each asset exports as one opaque
`Palette` mesh plus at most one unshaded `Glow` mesh, so a crowd actor is one
draw call and scenery layers are one MultiMesh per mesh. Triangle order and
normals are canonicalized; a second fresh export to a separate folder matched
**43/43 GLBs byte-for-byte**. `art/manifest.json` records hashes, sizes,
mesh/skin/joint/animation/triangle counts and bounds. GLBs are marked binary
in this directory's `.gitattributes` (as Hearthguard does) because the root
`android-games/** text eol=lf` rule would otherwise rewrite them.

Colour note for future kits: Godot 4.7.2's importer/Compatibility path treats
glTF `COLOR_0` as sRGB-encoded. Writing Blender's linear `.color` with the
sRGB hex values gives exact on-screen colours (measured 737b88 in, 727b87
out); writing `.color_srgb` double-darkens.

## Presentation architecture (`scripts/presentation/`)

- `kit.gd`: loads GLBs, assigns two shared materials (vertex-colour lit,
  vertex-colour unshaded glow), extracts static meshes for MultiMesh layers.
- `actor.gd`: one articulated character. Rest-relative bone rotations;
  run/backpedal gait, recoil, flinch, fall, cheer, spawn scale, fade. It never
  moves its root; rules do.
- `street.gd`: district environment, lighting, fog, sky, skyline, and the
  scrolling MultiMesh scenery table (fixed authored placements plus an integer
  hash; no RNG). Lighting follows Hook's measured Compatibility fix: linear
  tonemap, ambient 0.42, shadowed sun 0.30, orthogonal shadows.
- `fx.gd`: bounded pools: tracer MultiMesh (600), particle MultiMesh (320),
  splats (36), 20 muzzle flashes, 10 kill pops, 8 floating numbers, 6 spit
  globs. Tracers are drawn at the exact rule bullet x/z each tick.
- `adapter.gd`: built fresh by every `build_world()` (load, Retry, import,
  road change), so all transients, pools and cursors reset. `sync(state)` runs
  inside the existing `refresh()`: it places rule-owned roots and starts each
  effect once by comparing against its own last observed values (enemy hp+armor,
  gate hits, side hp, boss hp/arms, crew count, hazard count, `next_spit`).
  The first sync after a build hydrates silently. `frame(dt, frozen)` runs from
  `_process` and receives `dt = 0` while paused, on the map, in transfer or in
  legacy mode. Infected visuals are pooled per role (max 16 reserves per
  role) and attach to lightweight per-enemy anchors that keep the old
  `actors["enemyN"]` registry; each anchor carries a hidden role-sized bounds
  box so the projection test still measures authored geometry.

Nothing in the presentation writes rule state, calls rule RNG or changes tick
order. `presentation_tests.gd` steps four roads (incl. three bosses) with and
without the renderer and compares the full serialized state.

## Evidence

Rendered frames: real 720x1280 windows (Compatibility, RTX 5070 Ti host),
policy-driven real touch-drag input and the real Start button, fixed 60 fps.
Later roads are opened with a **labelled visual fixture** profile in isolated
app data; these frames are not earned progress. Copies, contact sheets and the
pre-overhaul frames are in `C:/tmp/games-review-20261021/deadrun/`.

Frames (all `after-*.png`), plus `sheet-before-after.png`,
`sheet-after-districts-bosses.png`, `sheet-after-sizes.png` and a 25 s
fixed-step movie-writer clip of the opening road (`after-opening-road-clip.mp4`):
early Canal Works road with gate, crane truck and recruits; Work Crew and Crowd
Control crowds with gates (Canal, Market Viaduct); Spillway (Reservoir Ring);
all four district bosses (Cable Matron, Toll Ram, Spore Bell, Ferry Eater with
both arms) and the last-ferry victory; native 720x1280, reduced effects, inner
1000x1110 and tall cover 720x1680 windows. `before-*.png` are the pre-overhaul
release-freeze frames from the same roads.

Final runs on the committed presentation code (isolated app data each):

| Suite | Result |
| --- | --- |
| `python scripts/portfolio.py test dead-run` | passed: 139 rules + 34 legacy input checks |
| `tests/verify_kit.py` | passed: 43 assets, 9 skinned, all hashes |
| `tests/run_graphics.py presentation --headless` | 22/22 (state equality on roads 1, 12, 18, 24; pools; hydrate; pause; reduced effects) |
| `run_desktop.py camera-headless` | 862/862, 108 envelopes at 1080x2400, 1080x2520, 1968x2184 |
| `run_desktop.py campaign-headless` | 115/115, full 24-road actual-input journey, legacy view, ending, replay |
| `run_desktop.py campaign-rules` / `rules` / `validation-headless` | 226/226, 139/139, 3548/3548 |
| `exhaustion` / `migration` / `platform` / `clipboard` headless | 17/17, 11/11, 8/8, 14/14 |
| `tests/run_graphics.py frames` (rendered) | 16/16 harness checks, every scenario state rule-valid |

The camera projection test's authored FOV expectation moved from 46 to 51 with
the new camera; every margin, resize, round-trip and state check is unchanged.

Harness note: the legacy `tests/playthrough.gd` writes its `*-slots.json`
files into the project folder when run without a capture folder (as
`portfolio.py test` does). On a tree without those files the first portfolio
run therefore reports "Project source changed while command ran" even though
all checks pass; the immediate second run passed. This is pre-existing and was
left unchanged; the stray files are deleted afterwards and are not committed.

Protected files, normalized-LF SHA-256 versus base `22a7ef7` (all 12
identical): `scripts/rules.gd`, `campaign_rules.gd`, `campaign_data.gd`,
`campaign_store.gd`, `save_store.gd`, `save_files.gd`, `copy_confirm.gd`,
`clipboard_backend.gd`, `export_presets.cfg`, `project.godot`,
`delivery-metadata.json`, `DELIVERY-METADATA.md`. `main.gd` and
`legacy_view.gd` are also untouched.

Reproduce (from this directory):

```powershell
python -B tests/run_graphics.py import
python -B tests/run_graphics.py frames --scenario early,dense,cluster,reservoir,matron,ram,bell,ferry,sizes
python -B tests/run_graphics.py frames --scenario early --movie
python -B tests/run_graphics.py presentation --headless
python -B tests/run_graphics.py lineup
```

## Honest limits

- Infected density is whatever the unchanged rules spawn: usually 3 to 10
  live infected, not the hundreds-strong hordes of the reference ads. No
  decorative fake crowds were added, because they would misrepresent threats.
- Rule positions update at 60 Hz; there is no sub-tick interpolation of roots,
  so displays above 60 Hz will show 60 Hz motion.
- The visual cage/pump sits above head height; bulwarks (1.9 m tall) can clip
  its underside. Tracers rise from 0.75 m to 1.15 m with distance so they meet
  elevated targets; far rounds can pass a little above small clusters.
  Infected still walk through carts and the centre blockade, as before.
- Toll Ram walks backward at road speed to hold its rule distance; the Ferry
  Eater and Spore Bell avoid feet entirely. Slow roles backpedal slightly.
- Bone poses are procedural on rigid-skinned segments; elbows and knees can
  show small seams at extreme poses.
- No host frame-time measurement, no phone FPS, no Android build, no audio
  change and no human review of motion at normal speed were done here. The
  short clip, if present, is fixed-step movie-writer output, not timing data.
