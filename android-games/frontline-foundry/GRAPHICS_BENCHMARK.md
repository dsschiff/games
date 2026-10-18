# Frontline stylized 3D benchmark candidate

2026-10-18. Implemented and exercised; independent graphics acceptance remains
open. The old functional/fidelity approval does not approve this art. This is
the first playable outpost benchmark, not completion of every campaign region's
final art or a new Android release.

## Implementation

- Original Blender-authored, beveled military soldier, headquarters, equipment,
  sandbags, snow-capped cliffs, crates, sentry, rover and specialist/boss kits.
  `art/manifest.json` inventories 16 GLBs (1,193,308 bytes total). The soldier has
  9,172 triangles, seven consolidated skinned material surfaces and 16 joints.
- `art/source/build_assets.py` is the complete original geometry/rig/material
  source. Pinned portable Blender 4.5.14 LTS, build `62c1db4208e8`; verified archive
  SHA256 is recorded in the manifest. No external artwork, textures or paid
  assets. Three separate CPU export processes produced byte-identical GLBs and
  manifest after deterministic normal/vertex/triangle canonicalization. Unused
  UVs are omitted. Earlier nondeterministic exports remain historical artifacts.
- `scripts/presentation/actor.gd` owns runtime skeletal posing, two-link
  stance/swing locomotion, independent upper-body aim, equipment acquisition,
  recoil, local hits, fallen and victory poses. Wheels, turret and barrel have
  separate motion. These are runtime animations, not baked glTF clips. The rig
  has rigid part weights appropriate to the articulated toy treatment.
- `adapter.gd` copies immutable visual snapshots keyed by entity type and rule
  ID, interpolates independently, bounds event dedupe and resets on pause/load/
  scene replacement. A scene instance owns its local epoch. Replacement detaches
  and disables the old instance before deferred deletion. Rendering never drives
  simulation, targeting, damage, collision, spawning, economics or saving.
- Both legacy catalog 1 and campaign catalog 2 boot through the new outpost.
  `rules.gd` and `campaign_rules.gd` only gain transient observation metadata
  (actor, grouped attack and effect subtype); legacy also emits incoming-hit
  observations. Definitions, schema and save-store implementation are unchanged.
  Splash damage produces one weapon attack with separate target responses.
- Persistent Storm/drill warnings, carrier repair and HQ impact cues are separate
  from projectile effects. Reduced effects keeps rig motion and danger/impact
  information. Paused hydration applies unarmed/equipping/fallen poses immediately.
- Godot 4.7.2 Compatibility remains selected. Shared palettes, one shadow sun,
  an unshadowed fill, corrected color conversion, lower shadow opacity/filtering,
  continuous terrain, a compact HUD and contextual pad labels replace the slab
  and label forest. Project desktop window overrides are now 720x1280 rather
  than 450x800; Android still uses its actual display.

## Reproduction

Run from this worktree with isolated `APPDATA`, `LOCALAPPDATA`, `TEMP` and `TMP`.
The game-local runner creates those directories and archives exact executed
sources, source hashes, commands and outputs. It does not touch ADB, clipboard,
Android export, signing, shared tools or global configuration.

```powershell
python -B android-games/frontline-foundry/tests/run_graphics.py checks
# A coordinator-granted serialized GPU slot is required for either capture:
python -B android-games/frontline-foundry/tests/run_graphics.py capture --render --movie --seconds 145
python -B android-games/frontline-foundry/tests/run_graphics.py capture --render --movie --seconds 90 --resume-from android-games/frontline-foundry/.artifacts/paced-rendered-20261018T064825390242Z/earned-final
```

The opening starts from a fresh isolated profile. The later clip copies the
original app-written slots from a genuinely input-earned, previously accepted
rendered campaign run. Before boot can write anything, the capture script checks
decode and exact full state/profile/settings/career equality against the supplied
boundary. Invalid/mismatched checkpoints fail closed; validation is never relaxed.

`--fixed-fps 30` records 1x engine simulation for normal-speed playback; recording
wall speed and movie CPU/GPU averages do not establish real-time host FPS, frame
time tails or physical-phone performance. ffprobe and full decode determine the
actual encoded dimensions, separately from logical/window/framebuffer values.
No video upscaling, retiming, frame interpolation, cuts or hidden state injection.

## Candidate evidence

All paths below are under this game's ignored `.artifacts/` directory.

| Evidence | Path |
| --- | --- |
| Final 59 focused checks, actual GUI/joystick at five sizes and baseline equivalence | `benchmark720-checks-checks-20261018T123346738996Z/receipt.json` |
| Actual native 720x1280 opening | `benchmark720-opening-capture-20261018T123336529743Z/continuous.mp4` |
| Actual native 720x1280 earned finale | `benchmark720-finale-capture-20261018T123459911247Z/continuous.mp4` |
| Asset reproducibility, three independent exports / 17 identical files | `blender-repro/canonical-order-reproducibility.json` |
| Unchanged existing legacy suite: 69 checks | `relevant-rules/legacy.log` |

Each final capture directory contains `benchmark-report.json`, `receipt.json`,
`source-hashes.json`, `executed-source/` and `movie-probe.json`, plus untouched
actual game screenshots and raw touch records. The focused suite compares the
entire state after each of 2,400 identical-input ticks in districts 1 and 12 plus
900 legacy ticks against rules extracted directly from `501f6dc`. It checks real
legacy/campaign boot, skin bindings/joints, no phantom load effects, first-resume
attacks, grouped splash, frozen loaded poses, terminal gait stop, keyed warnings,
effect routing and real movement after cover/inner/native/landscape/intermediate
resizing. It is source/structural evidence, not art scoring.

Opening: 119.9 encoded seconds, fresh Ash Gate to victory at 119.5833 simulation
seconds; MP4 SHA256 `4c6ce6554fe2d5b67adc45b3cb374c6f7c86955d15e7fddd60903ce0282a2827`.
Finale: 67.4 encoded seconds, genuine Foundry Liberation 145.4667 to victory at
212.5333 simulation seconds; MP4 SHA256
`2485da69468e9d9d0f0dfc3e537dc2d3aade5d6f8a4038545f25e51e9c187f75`.
Both AVI originals and CPU H.264 transcodes fully decode at native 720x1280,
30 FPS, with no rescaling or retiming. All 100 recorded executable/resource
source hashes match current source. `video-transcode.json` binds each MP4 to its
original AVI; `benchmark720-evidence-summary.json` indexes both runs.

Historical low-resolution and washed-out previews remain separate. In particular,
`dense-finale-capture-20261018T121953737629Z` is rejected as finale evidence: the
older retained checkpoint failed the current validator and the old capture policy
silently booted fresh Ash Gate. Its original process-success receipt is retained
with additive `review-rejection.json`. A new invalid-boundary control proves the
fixed policy stops before boot. The later paced checkpoint passes unchanged game
validation and complete-boundary equality. No source save or validator was altered.

## Review and release boundaries

Opening and later normal-speed full playback, grounded gait/grip/aim, boss kit
materials/attachments, shadows, death/victory transitions, composition and all
scorecard categories still require independent root/Astra review. The captured
first mission and finale do not certify unseen regional art. The first review
should cite actual frames/timestamps; skeleton assertions alone are insufficient.

The source remains version 0.2.0/code 2 because this is a benchmark, with no APK
export/install or claimed graphics release. Coordinator must assign a higher
version for a delivered graphical APK and own genuine update/native checks.
Physical Fold7 checks, sound judgment, human pacing/fun and measured real-time
performance are separate and unverified. No new phone testing is required for
this graphics milestone.
