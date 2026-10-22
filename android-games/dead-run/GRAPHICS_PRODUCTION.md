# Dead Run original 3D graphics production

Branch `claude/dead-run-graphics`, based on `22a7ef7`. Only this game directory
changed. Presentation only: rules, campaign rules/data, save files and schemas,
tick order, RNG, spawning, collision, damage, package id, signing, export
presets, project/version metadata and delivery metadata are byte-identical in
normalized LF form (proof below). Root still owns review, integration, export,
signing, emulator/native checks and delivery. Not a release candidate.

## Horde pass: rule3, 0.4.0/code5

Branch `claude/dead-run-hordes` from `bb6a589`. Daniel approved a gameplay
change: the 0.3.0 presentation showed 3 to 10 live infected, far from the
ads' floods. This pass changes rules, so it adds a new catalog and keeps the
old one replaying.

### What changed in play

| | catalog1 (code2-code4) | catalog2 / rule3 (code5) |
| --- | --- | --- |
| Infected per campaign | 1,896 | 13,039 (6.9x) |
| Live infected, median per road | about 3-10 | 9-24 (Canal), 18-31 (Market), 24-34 (Reservoir), 25-37 (Ferry) |
| Live infected, 90th percentile | - | 30-64, 58-78, 68-94, 82-109 |
| Peak on screen (surges) | - | 80, 119, 145, 177 |
| Crew cap | 20 (5 columns) | 49 (7 columns, a 7x7 blob) |
| Fodder HP | drifter 3, runner 2, cluster 1 | drifter 2, runner 1, cluster 1 |
| Tough roles | plated 5+2 armour, spitter 4, bulwark 9+3 | plated 6+3, spitter 5, bulwark 16+5 |
| Weapons | Rivet 24t, Lance 42t pierce 3, Fan 36t 2 pellets | Rivet 20t range 16; Lance 40t, 2 dmg, pierce 4, range 18; Fan 34t, 2 pellets each piercing 2, spread .034, range 15 |
| Gates | +1 per hit, cap +5/+6 | add gates -3 to -(8+3d), cap +8 to +16; multiply gates x1 to x2 (x3 from Reservoir), one step per 40+10d hits, grant crew x (value-1) |
| Roadside rescue | +3 | +6 to +9, HP 160-280 |
| Boss HP | 140/170/190/220, blockade 36, arms 45 | 520/640/720/680, blockade 300, arms 160 |
| Hazard losses | spit 2, boss 2-3, flood 2, cart 3 | spit 3, boss 4-7, flood 5-6, cart 4-7 |

Waves are now packs: rows of three that fan out across most of a lane, led by
the role the catalog1 wave grammar would have spawned (plated, spitter,
bulwark), with flanking packs in the other lanes once a road is 18% through.
Pack size grows through each road (2 + district, up to +6 by the end). In the
14 seconds before every blockade or district boss a surge floods all three
lanes; the HUD says "HORDE SURGE". Weapon range is new: rounds fade at 15 to
18 m, so a horde visibly closes in before it falls, and every weapon still
reaches the bosses at 14 m. Road durations, the 24-road arc (2,260 s active
simulation), deadlines, medals, Retry and seeded replay are unchanged in
shape. The opening road keeps its harmful third gate.

The read-only solver policy (`tests/campaign_policy.gd`) now aims at the lane
position whose fire covers the most urgent pressure and takes worthwhile gates
before they cross. Sweep over all 24 roads x 3 weapons
(`tests/horde_balance.gd`, a development tool, rule fixture only):

| Policy | Wins |
| --- | --- |
| rescue (the fixture used by the tests) | 72/72 |
| line (rescue-last variant: no roadside work before tick 1500) | 71/72; the Last Ferry with Lance loses its opening |
| lagged (steers every 30 ticks from a 10-tick-old reading) | 72/72 |
| sloppy (chases the nearest infected once a second, ignores gates, rescues, marks) | 40/72; loses most roads from Market Viaduct on |
| idle (no steering) | 0/24 |

District bosses fall 10.5 to 22.8 s into their 30 s window under the solver.
End crews range 33-49 with 0-40 lost per road; the bigger losses sit in
Reservoir Ring and Ferry Approach.

### Saves and versioning

- `scripts/catalog1_data.gd` is byte-identical to code4's `campaign_data.gd`
  (git blob `56b2364`). `scripts/catalog1_rules.gd` is code4's
  `campaign_rules.gd` with only its data preload path and a header comment
  changed.
- `campaign_rules.gd` hands any state whose pinned definition says
  `catalog: 1` to the frozen module for every rule entry point (steer,
  adjust, targets, strike, step, valid). A code4 road in progress therefore
  continues under its original rules, never re-simulated under rule3.
- `Store.upgrade` (called on startup and on Import) is the one explicit
  migration: a catalog1 road still in `ready` (loaded, never started) becomes
  the same road, weapon and seed under rule3. Roads in progress and finished
  roads stay catalog1. Retry after a catalog1 road starts the rule3 version of
  that road; that is the one place Retry does not keep the old definition.
- Clears, medals, best crew (now bounded 1-49), replays, settings, loadout and
  the parked legacy canal bridge are untouched. The envelope schema stays 2.
- Regression fixture: `tests/fixtures/code4-midroad/` holds two genuine
  app-written code4 slot files (road 7, Lance, paused at tick 1500, crew 13),
  produced by the unmodified `bb6a589` project with
  `make_code4_fixture.gd.txt`, plus code4's own continuation of that road to
  victory (recorded steering and final state). Its profile clears are a
  labelled fixture. `campaign-rules` checks decode, preservation, no silent
  upgrade, and a tick-for-tick match with code4's final state;
  `code4-headless` does the same through the real scene (install-over on
  desktop, not Android), then checks that Retry yields rule3 and survives a
  cold restart.
- Formation: up to 25 members the rule3 formation equals catalog1's
  (checked for every count). Larger blobs pack their drawn rows tighter; only
  the lateral offset is a rule input.

### Performance

- Rules: targets are z-sorted each tick and each round binary-searches its
  swept interval. Same choice as catalog1 (nearest target, earliest listed on
  ties), cheaper with 100+ live infected. Rule step at the heaviest surge:
  median 0.8-0.9 ms, p95 1.1-1.8 ms on the host.
- Presentation: far fodder (more than 15.5 m out) is drawn as one MultiMesh per
  role in rest pose with a bob, and swaps to a pooled skinned actor when it
  reaches the fighting band or dies. Pools hold up to 48 per role and are
  warmed at road build. Infected beyond 12.5 m pose on alternate frames. Only
  the live window of the enemy list is walked each refresh. Fodder and crew
  beyond 24 skip the shadow pass. The first four kills and six hits of a
  refresh get full bursts, the rest small chips; bodies fade sooner during
  big sweeps. Muzzle flashes are spread over at most 20 shooters. Tracers get
  a small per-shooter spread so a big crew reads as a wall of fire.
- Saves: a heavy road's checked save is about 250-300 KB (encode about 15 ms,
  each checked decode 30-60 ms on the host). In-road autosaves now run every
  10 s on a worker thread from a private snapshot (about 2 ms to copy);
  pause, Back, backgrounding, road changes and every terminal phase still save
  synchronously, after waiting for any pending autosave.

Host timing, opt-in (`python -B tests/run_graphics.py timing`): real
720x1280 window, Compatibility renderer, RTX 5070 Ti, vsync off, unpaced
render frames, 60 warm-up frames excluded, 720 rule ticks from 12 s before
the Convoy Column blockade (road 23), crew 49, 129-130 live infected at peak.

| Run | Live peak | Frame median | p95 | p99 | Frames >16.7 ms | Frames >33.3 ms | Rule step median / p95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Road 1 opening, Rivet (light baseline) | 8 | 1.8 ms | 3.3 ms | 4.4 ms | 2 of 5,789 | 1 | 0.09 / 0.12 ms |
| Road 23 surge, Fan, full effects | 128 | 6.0 ms | 11.1 ms | 18.9 ms | 36 of 1,712 | 0 | 0.76 / 0.96 ms |
| Road 23 surge, Fan, Reduced Effects | 128 | 4.8 ms | 8.9 ms | 17.2 ms | 23 of 2,079 | 0 | 0.75 / 1.02 ms |
| Road 23 surge, Lance, full effects | 122 | 4.6 ms | 8.8 ms | 16.0 ms | 13 of 2,234 | 0 | 0.70 / 0.87 ms |

Earlier runs of the same capture while other work loaded the machine gave
7-11 ms medians and p95 12-19 ms. Before the far-crowd LOD and the 10 s
autosave the surge measured 12-16 ms median.

These are host desktop numbers on a fast GPU with other agents' work on the
machine; they are not phone FPS. The surge is CPU-bound (GPU about 13%
busy), dominated by skinned-actor posing, scene sync and per-actor draw
submission.

### Presentation

- Gates: add gates as before (blue/red with signed number); multiply gates show
  "x1 SHOOT x2" on a grey panel until shooting turns them gold "x2 CREW".
- Threat rings: one MultiMesh of ground rings marks plated (pale gold),
  spitters (acid green) and bulwarks (red, larger) inside a horde. Only tough
  roles carry health bars.
- Reduced Effects: unchanged meaning; it still drops bursts, pops, splats,
  pulses, join rings and shake, keeps tracers, telegraphs, labels, bars, rings.
- Frames: `C:/projects/active/games/.artifacts/releases/graphics-20261021/previews/deadrun-hordes-*.png`
  (early road 1, mid road 9, surge road 11 Fan, surge road 13 Lance, Cable
  Matron, Ferry Eater), rendered at 720x1280 with policy touch-drag input on
  labelled visual-fixture profiles.

### Limits

- Phone frame rate is unmeasured. Host surges run at about 5-11 ms median per
  frame (load-dependent) against 2 ms on the opening road; a phone will be several times
  slower, so 60 fps in Ferry Approach surges is doubtful without further
  work (fewer skinned crew, GPU skinning checks, lower shadow cost).
- The solver policy is strong and reacts every 15 ticks; human difficulty is
  untested. The sloppy and lagged sweeps are the only proxies.
- Crew hits the 49 cap on most roads under the solver; late gates then mainly
  refill losses.
- Bosses at 14 m sit just inside Fan's 15 m range; Fan's boss damage comes
  from its last metre of flight.
- Saves are about 5x larger than code4's; a checked synchronous save on the
  heaviest road costs over 100 ms on the host, so pausing can hitch.
- Godot 4.7 GDScript on a worker thread still slows the main thread during an
  autosave (measured: about 3 ms on the median frame at a surge).

## 0.3.0/code4 graphics pass (presentation only)

The sections below describe the earlier presentation-only pass. Its "byte-identical rules" and
"3 to 10 live infected" statements describe code4; rule3 above supersedes them.

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
