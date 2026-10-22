# Frontline graphics production candidate

2026-10-18. Source candidate 0.3.0/code 3. The previously accepted desktop
outpost benchmark is expanded into authored regional scenery, specialist rigs,
equipment and distinct bosses. This document does not establish independent
production acceptance, Android update retention or physical-phone performance.
The coordinator owns those checks and APK export/install.

## Authored presentation

The retained source is `art/source/build_assets.py` plus `world_kit.py`. All 47
GLBs are original authored geometry and material work. No third-party artwork,
downloaded textures, paid assets, network service or runtime dependency is added.
Three independent pinned Blender 4.5.14 CPU export processes produce byte-identical
models and manifest (`.artifacts/production-repro/reproducibility.json`). The game
local Git attribute keeps every GLB byte exact; its long JSON header must never
trigger text line-ending conversion.

The seven consolidated skinned material surfaces remain on each humanoid. Seven
specialist variants have their own proportions, armor and actual primary weapon:
runner carbine, Breaker launcher, Ranger long rifle and optic, Bulwark shield,
mortar launcher, jammer emitter/aerial and sapper detonator/charges. Each rig has
17 authored joints including `PrimaryMuzzle`, parented to the actual weapon tip.
The accepted two-link leg articulation, separate upper-body aim, equipment,
recoil, hit, fallen and victory poses remain. Runtime procedural posing drives
the real skeleton; these are not baked glTF animation clips or bobbing capsules.

The Drill, Carrier and Storm use separate original six-wheel chassis with
animated turret/barrel assemblies. The Drill has a rotating helical tool, the
Carrier has reservoirs and an aimed repair boom, and the Storm has articulated
rocket pods and a charging dish. Real attack/repair/warning observations drive
their presentation. Existing warning footprints and immediate damage resolution
remain authoritative. Vehicle projectiles inherit the actual turned/recoiling
barrel socket. The essential warnings survive Reduced Effects.

Equipment counters and finite visible stock tokens distinguish Rifle, Breaker,
Ranger, Rover, Ward, Relay and Recovery. The remodeled HQ has a door, recessed
windows, awnings, steps, roof equipment and a physically placed cosmetic impact
socket. The pads are light beveled stone. Waiting requests appear only near the
appropriate queue head; equipping has its own cue. Purchased tokens disappear
as the existing finite inventory is consumed. Redundant tiny world labels are
removed; the contextual purchase control still displays the actual role/cost.

| District | Regional landmark and setting |
| --- | --- |
| Ash Gate | Watchtowers, pale ground and snow-capped cliff edges |
| Switchyard | Rail wagon, traversable painted tracks and warmer stone |
| Signal Ridge | Signal dish, cool ridge palette |
| The Iron Drill | Quarry gantry and ochre ground |
| Broken Bridge | Broken stone arch, waterside edges and deck markings |
| Glass Quarry | Faceted crystal bed and pale teal rock |
| Night Relays | Relay masts, blue ambient palette and bright capture rings |
| The Brood Carrier | Repair gantry, reservoirs and depot supplies |
| Red Causeway | Floodgate, warm embankments and waterside edges |
| Mortar Gardens | Branched orchard trees and muted green ground |
| Last Supply | Supply truck, cargo and olive stone |
| Foundry Liberation | Twin foundry stacks, supplies and industrial gray |

Opaque scenery stays outside the playable bounds; painted tracks and deck
markings never add collision. The actor root follows the exact existing x/z
state with cosmetic height over rendered pads/sandbags. Region selection and
seed/style decoration consume no gameplay RNG and never edit a definition.
Legacy uses Ash Gate art; seeded variants retain their actual encounter style.

One shadow sun, an unshadowed fill, shared cached materials/models and 2x MSAA
are used in Compatibility. The palette is deliberately readable and toy-like.
Briefing prose now wraps inside a scrolling body above a fixed support action,
including the long Foundry Retry brief. Menus use consistent olive panels and
buttons. Objective text has a light outline for contrast across regional ground.

## Scope and verification

Compared with accepted `3a12e04`, `rules.gd`, `campaign_rules.gd`, `definitions.gd`,
`save_store.gd`, boot routing and all rule/save meanings remain byte identical.
No timing, damage, targeting, stock, costs, progression, schema, Back behavior,
transfer, package or signing change is part of this production pass. The version
is consistently 0.3.0/code 3. The package remains `com.dsschiff.frontlinefoundry`.

The corrected focused suite passes 103 checks, covering all specialist imports, authored
muzzle attachments, boss wheels/turrets, all twelve region descriptors, genuine
GUI launch/pause/movement across five resizes, immutable visual snapshots,
warning persistence and brief-body separation. Complete original/new states are
equal on each of 4,800 campaign and 900 legacy ticks. Source-bound receipts and
import diagnostics remain under the ignored game-local `.artifacts/` directory.

Rendered evidence is recorded at 1x simulation through real touch/GUI input and
read-only decisions. Resumed clips use unchanged app-written saves whose complete
state/profile/career/settings are checked before boot. A replay tour selects the
twelve genuinely unlocked Journey entries and seeded/support menus through GUI
events; its short regional passages demonstrate art coverage, not a newly earned
campaign completion. The synthetic specialist gallery is explicitly art inspection
only and is never used as gameplay, progression or performance evidence.

Desktop timing uses `tests/frame_sampler.gd` during an actual heavy encounter.
It timestamps `RenderingServer.frame_post_draw` with `Time.get_ticks_usec`,
excludes menus/pause/loading/terminal states and resets interval cursors over gaps.
The first 1.5 eligible seconds are warmup. Raw rows retain actual combatants,
bosses, reduced-effects state, draw calls, primitives, rendered objects, nodes,
static memory and CPU process/physics timings. The heavy subset is a live boss
or at least twelve actual combatants. It records window/framebuffer pixels, CPU,
GPU/driver, engine, renderer, VSync, MSAA and scaling. No movie writer, fixed FPS,
frame PNG capture or framebuffer readback runs during the measured interval.
These are desktop render-loop submission intervals, not OS presentation or GPU
timestamps and not phone FPS. Fixed-movie encoding statistics are excluded from
performance claims.

## Preserved broad production captures and timing

All paths below are relative to this game's ignored `.artifacts/` directory.
Each run retains its exact executed source archive, raw source hashes, import
preflight, engine inputs, complete captured states and artifact-bound receipt.
Each receipt passed with unchanged sources at candidate `998dce3`. The MP4s are full-duration codec
transcodes of the retained native AVIs: no scaling, cropping, retiming or edits.
They are 720x1280 at 30 FPS and decode fully.

| Final production passage | Run directory | Duration | MP4 SHA256 |
| --- | --- | ---: | --- |
| Fresh opening through victory | `production-final-opening-capture-20261018T135701655557Z` | 119.9s | `565ce44cdbc46e4ce22f34c43d0afcf3ae37fc18993914d3f9634b589ed98645` |
| Genuine Carrier continuation through victory | `production-final-carrier-capture-20261018T135934633491Z` | 72.4s | `ea66c3ee017ed03ea2ad20abbf58914a70ea4502f8d5687976e9e6ee4321a4e0` |
| Genuine Foundry/Storm continuation through victory | `production-final-storm-capture-20261018T140054974719Z` | 46.067s | `0e634cf8c58f5ca060ad2a4389425ad3367c644dbe47f54e5a679a35d56b26ed` |

The opening predates addition of the separate legacy evidence harness/runner
mode. All three broad clips precede the independent-review corrections below;
their receipts and source archives remain intact. They establish the broad
production delta at their own candidate, not corrected socket or scenery behavior.
The earlier regional tour (`production-regional-tour-tour-20261018T135522608667Z`)
also predates the objective-text outline and version bump. It is not a fresh
full-campaign proof. Corrected focused passages supersede affected behavior.

`production-realtime-storm-capture-20261018T140229392389Z/frame-timing.json`
records the separate real-time run. Windows 10.0.26100, Ryzen 9 7950X3D (32
logical processors), NVIDIA RTX 5070 Ti, OpenGL 3.3/NVIDIA 610.88, Godot 4.7.2
Compatibility, native 720x1280 window and framebuffer, 2x MSAA, 1.0 render scale,
VSync enabled, no FPS cap and 60 Hz physics. Actual complete saved boundary was
Foundry time 166.8; the live run proceeds naturally to victory. Effects are on.

| Observed sample | Frames | Eligible seconds | Median / p95 / p99 submission ms | Above 33.333 ms |
| --- | ---: | ---: | --- | ---: |
| All warmed active gameplay | 2,649 | 44.219 | 16.666 / 16.759 / 18.335 | 0 |
| Live-boss subset | 967 | 16.149 | 16.666 / 16.767 / 18.300 | 0 |

Peak observed draw calls: 1,018; primitives: 286,370; nodes: 734. This bounded
actual encounter reaches seven combatants by the stated definition, plus the
rendered waiting crews and environment. It is not a synthetic maximum-population
stress test. Raw rows also retain counts above 16.667 ms; the narrow threshold
splits ordinary VSync jitter and must not be treated as a meaningful failure rate
by itself. Desktop results do not establish the deferred phone performance gate.

## Independent-review corrections

Astra identified an unmodeled Ranger barrel extension and transformed scenery
overhangs at `998dce3`. The new regression controls reproduce the actual defects:
the original Ranger cap is at Godot Z -0.9475 while its socket is at -1.16
(0.2125-unit gap). A same-call turned-shot control also reproduces deferred
BoneAttachment synchronization on this engine (0.911021-unit marker/bone gap).
The failed source-bound sensitivity run is retained as
`production-review-sensitivity-checks-20261018T141237025481Z`.

The Ranger now contains a real longer receiver/barrel/muzzle and mounted optic
with a glass lens. The actual Weapon-weighted front cap is at Z -1.16; the socket
is 0.005 units beyond it. The test computes that cap from imported weighted mesh
vertices rather than a promised bone position. Three aimed/recoiling poses
compare the socket against the transformed skinned cap. The common socket sampler
forces current skeleton transforms and synchronizes the attachment transform
before emitting; its same-call marker/current-bone gap is now zero.

Every regional landmark uses the entire imported mesh-node hierarchy's transformed
bounds, including authored scale, runtime yaw and overhang. Right/left placements
are moved until their solids clear X +/-5.1. Rear placements clear Z -7.1, behind
the enemy spawn edge as well as commander bounds. CPU assertions inspect every
actual regional placement across all twelve districts and Mixed/Flank/Siege
skirmishes against the commander rectangle expanded by its .275 body radius.
These are presentation transforms; all rule positions/bounds are untouched.

The corrected 103-check run is
`production-astra-corrections-checks-20261018T141453044137Z`. Three independent
CPU exports again produce byte-identical current models/manifest. Adding Ranger
primitives advances Blender's unused mesh datablock number suffixes in some
other GLBs. `.artifacts/production-astra-asset-delta.json` parses every old/new
GLB: only Ranger has geometry changes; every non-Ranger binary buffer and all
JSON fields are exact after ignoring only mesh names. This proves the metadata
delta rather than assuming it from equal file sizes.

The earlier broad movies remain historical production coverage. Corrected
focused legacy/rifle, Ranger combat, regional replay, Retry and Drill passages
bind to the corrected sources and supersede the affected socket/scenery behavior.

## Corrected rendered handoff

Runtime/art freeze: `dca06bf7b31a6c113e969133562adb1776826c4f` (on `998dce3`).
`.artifacts/production-corrected-bindings.json` indexes every corrected run, receipt,
MP4 hash, exact executed runtime source comparison, full artifact hash readback
and full video decode. All 125 runtime/art files in each corrected run match
committed bytes (text compared with LF normalization; GLBs exactly).
No corrected run changes sources while executing.

| Corrected passage | Run / MP4 | Seconds | SHA256 |
| --- | --- | ---: | --- |
| legacy-legacy | `production-corrected-legacy-legacy-20261018T141558437191Z/continuous.mp4` | 6.967 | `9d190e2efcd27a52ffb2bd259e3b1442692a130b491d3b8ac153992279f4764f` |
| ranger-capture | `production-corrected-ranger-capture-20261018T141724710674Z/continuous.mp4` | 12.367 | `e0916b2fad8c2e44e75e24c7e724c878f1e568defd12cc029f50bb246e32431b` |
| regions-tour | `production-corrected-regions-tour-20261018T141855911702Z/continuous.mp4` | 45.300 | `60aa42aa21786daa5d5e1859602f35718f6d342de8a77bb7f54dc8ebc4167057` |
| drill-capture | `production-corrected-drill-capture-20261018T142011569833Z/continuous.mp4` | 180.367 | `5579dcf20990825bbced7d0695a2b062cbde632b7392e5c3cc51fc4db7ce6ba9` |
| retry-closure | `production-corrected-retry-closure-20261018T142232608584Z/continuous.mp4` | 4.933 | `0c93b8d4a86caf2b9b4d672a1ef9f33139496974cdd58fe38f027cbca9ac6d6f` |

The Drill retains the complete 180.367s native capture and a contiguous 30s
`production-corrected-drill-capture-20261018T142011569833Z/drill-final-30s.mp4` excerpt beginning at parent-movie second 150
(SHA256 `8c50b137f5aa7a3970f48523868d3d1b3c5eed5b87eb2fde60c288ce0b822f93`). Both remain 1x; the excerpt is not a new run.
The natural duration boundary is simulation time 185.133, with the Drill dead
and 23/24 enemies stopped; another enemy is still alive. It does not claim a
new mission clear. The parent continuous movie preserves the earlier play.

The corrected Ranger passage records two shots each from genuine fighting
Rangers 6 and 7 (four new attacks), plus actual commander/other-crew fire.
The legacy passage restores the complete genuine catalog-one active save,
resumes through GUI input, then explicitly enters campaign while retaining the
whole resumed legacy battle/profile/settings as its backup and inventing no clears.
The regional tour selects all twelve genuinely unlocked Journey entries plus
support and seeded menus through real touch/mouse-wheel GUI events. The corrected
Retry passage passes all six actual-input checks and shows the long Foundry brief
inside its scroll body above the fixed support action. It preserves the entire
earned career/profile. These are bounded presentation passages, not phone tests.

Corrected real-time timing: `production-corrected-realtime-capture-20261018T142328598243Z/frame-timing.json`.
Hardware, resolution, VSync, 2x MSAA, effects-on settings and methodology match
prior desktop sample. This new run binds to corrected runtime/art.

| Corrected sample | Frames | Seconds | Median / p95 / p99 ms | Above 33.333 ms |
| --- | ---: | ---: | --- | ---: |
| All warmed active gameplay | 2,649 | 44.212 | 16.666 / 16.754 / 18.151 | 0 |
| Live-boss subset | 968 | 16.161 | 16.667 / 16.745 / 18.177 | 0 |

Observed peaks: 1,018 draw calls, 288,650 primitives, 734 nodes, seven combatants.
Raw metadata and every sampled interval remain available. This is desktop
render-loop submission timing and does not establish phone FPS or maximum crowd load.

Builder visual inspection covers sampled native still frames. Independent normal
1x motion review and native code2-to-code3 update validation remain coordinator-owned.
No builder APK export/install, ADB, clipboard use, push, publication or phone test
was performed. All builder rendering is stopped and the shared render slot released.

## 2026-10-21 presentation pass: follow camera, warm ground, framed perimeter

Presentation only; rules, saves, definitions, main/campaign scripts, project and
export settings are byte-identical (LF-normalized) to `f8a9c7b`.

- **Camera.** Perspective follow camera (50° pitch, 16 m) that leads toward the
  front. Portrait keeps a fixed ~11.4 m world width; wider Fold/landscape windows
  keep height and reveal more world. The frame tracks the commander so the body
  stays inside the frustum at its own depth, including at the base corners.
- **Off-screen cues.** Red arrowheads at the edge of the usable play region (below
  the HUD, above the controls) point at hidden enemies; nearby ones merge with a
  count. An amber arrow points at the HQ for 1.4 s after an off-screen hit. Cues
  hide while paused and stop pulsing under Reduced Effects.
- **Ground.** `scripts/presentation/ground.gdshader`: a warm sand clearing with
  low-frequency value drift, a worn gate-to-HQ track and a cooler hazy rim, plus
  depth fog. Regional palettes in `regions.gd` were rebalanced to light warm sand.
- **Perimeter kit.** `art/source/scenery_kit.py` (deterministic Blender) adds soft
  beveled boulders, snow-shouldered rocks, an outcrop cluster, three pines, a
  striped barrier, sawhorse and fuel drum. Existing GLBs re-export byte-identical.
  About 70 placements per district go through `place_landmark`, so the existing
  bounds test covers them. The stacked pale cliff cubes are gone.
- **Tests.** `presentation_tests.gd` adds camera framing on cover/inner/native/
  baseline profiles, wider-world-on-Fold, edge cues (one cue for a sapper behind the
  controls, none for an on-screen runner, steady under Reduced Effects, none while
  paused) and perimeter clearance.

Headless note: the dummy renderer logs `Parameter "material" is null` when two
outposts coexist and one holds a single instance of an imported GLB. The perimeter
crate stacks keep crate instances plural, so this no longer appears.
