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
