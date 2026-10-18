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

Every invocation first runs pinned Godot with `--headless --editor --import --quit`
under the same isolated environment. This creates the GLB PackedScene cache needed
on a fresh checkout. `import.log` and `import-report.json` record the exact command,
exit code, error diagnostics and source hashes before/after import. Nonzero exit,
timeout or import error diagnostics stop the runner before any test/capture
process starts; `receipt.json` records `command_executed=false`. The executed
source archive and test/capture hashes are taken after a successful import.

This prerequisite was added after candidate `e58a4fd`; it changes only
`tests/run_graphics.py` and this document. Existing final clips retain their
original helper hash and source archives. Runtime GDScript, project configuration,
assets, rules and saved-state validation remain exactly at the captured candidate;
no footage is recaptured for this helper-only difference.

Verification is retained in `.artifacts/import-helper-verification/`: a copied
checkout with no `.godot` cache imports cleanly and passes all 59 focused checks.
A separate no-cache copy with an intentionally invalid soldier GLB emits three
import errors despite Godot exiting 0; the runner rejects it and records
`command_executed=false`. `verification-summary.json` indexes both receipts.

A later focused review fix parents vehicle muzzle sockets to the animated
barrel and locates them just beyond its forward cap. The added geometry control
keeps the hull facing forward while aiming sideways and recoiling; the socket
must stay at the transformed barrel tip throughout. This changes `actor.gd` and
`presentation_tests.gd`, not rules, damage timing or GLB assets. Those changes
postdate the historical full clips. Focused rendered closure evidence for that
declared delta is recorded below; the original full clips retain their own pins.

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

The separate `closure` mode uses real GUI input, the Window size API and actual
app-written saves. `--native-frames` captures each native framebuffer at 1:1 into
a fixed 984x1280 evidence canvas, with padding only. This preserves both the
720x1280 native window and the resized 984x1092 window without stretching/cropping
the recording. These focused MP4s are silent, separate process passages. They
are not stitched into a purported continuous cold-relaunch movie. For example:

```powershell
python -B android-games/frontline-foundry/tests/run_graphics.py closure --stage sideways --render --native-frames --movie-fps 60 --resume-from android-games/frontline-foundry/.artifacts/graphics-closure-earned/sideways
python -B android-games/frontline-foundry/tests/run_graphics.py closure --stage park --render --native-frames --resume-from android-games/frontline-foundry/.artifacts/graphics-closure-earned/park
# Then use that park run's closure-save directory for --stage restore.
```

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
source hashes pin the original captured candidate. `video-transcode.json` binds each MP4 to its
original AVI; `benchmark720-evidence-summary.json` indexes both runs.

## Focused review closure, after the vehicle socket fix

The runtime difference from the original full clips is **only** the six-line
vehicle socket branch in `scripts/presentation/actor.gd` (`24f4175`). Rules, damage
timing, GLB assets, adapter, outpost and project settings are unchanged. Other
executable differences are `tests/presentation_tests.gd` (geometry control),
`tests/run_graphics.py` (import/closure tooling), and the new
`tests/graphics_closure.gd` plus UID. The 60-check source/geometry suite is retained
in `vehicle-socket-review-fix-checks-20261018T125134233352Z/receipt.json`; the old
root-fixed socket fails the same lateral/recoil geometry sensitivity control.

All four focused passages below share the exact same 102 executable/resource
hashes; every receipt artifact/hash was read back, all directly captured PNGs
decoded, and all four MP4s fully decoded. The encoded canvas is 984x1280; native
game pixels are 720x1280, plus 984x1092 during the actual resize passage.

| Passage | Checks | Duration / FPS | Clip under `.artifacts/` |
| --- | --- | --- | --- |
| Actual authoritative lateral rover shot, tracer and recoil; GUI pause | 5 | 14.9167 s / 60 | `focused-sideways-closure-20261018T130653959971Z/continuous.mp4` |
| GUI pause/resume, reduced-effects Storm telegraph, paused and live window resize, app-written cold-save boundary | 18 | 31.3333 s / 30 | `focused-reset-park-closure-20261018T130834682611Z/continuous.mp4` |
| Separate cold process loading that exact complete app-written boundary; reduced-effects warning/motion and resumed pause | 9 | 5.9 s / 30 | `focused-cold-restore-closure-20261018T130957436032Z/continuous.mp4` |
| Genuine terminal victory to actual Retry, ready/Launch/movement/pause, retaining the whole earned profile | 6 | 4.9333 s / 30 | `focused-genuine-retry-closure-20261018T131027480039Z/continuous.mp4` |

`focused-closure-verification.json` indexes all four clip/receipt hashes, actual
native frame sizes and source deltas. Each run retains its raw native frame
sequence, `closure-report.json` (input checks, frame timing, actual shot geometry,
window events), full source archive, original app slots and expected full saved
boundary. The cold run begins exactly at the park run's 192.8 simulation-second
app-written state/profile/settings/career; the two save-slot hashes match. The
initial opening/finale/terminal boundaries were extracted byte-for-byte from
hash-verified raw slot snapshots in the original passed, genuinely input-earned
`paced-rendered-20261018T064825390242Z` run. Their provenance is retained in
`graphics-closure-earned/{sideways,park,retry}/provenance.json`.

These checks and the directly viewed lateral-shot/resize originals support the
focused fix; independent root/Astra playback and acceptance remain pending. No
full campaign or original long-clip rerun was performed for this closure.

Historical low-resolution and washed-out previews remain separate. In particular,
`dense-finale-capture-20261018T121953737629Z` is rejected as finale evidence: the
older retained checkpoint failed the current validator and the old capture policy
silently booted fresh Ash Gate. Its original process-success receipt is retained
with additive `review-rejection.json`. A new invalid-boundary control proves the
fixed policy stops before boot. The later paced checkpoint passes unchanged game
validation and complete-boundary equality. No source save or validator was altered.

## Review and release boundaries

The initial independent Astra review scored seven rows 3/4 and attacks/contact
2/4 because of the old vehicle socket. It also required the short reset passage.
The source fix and focused rendered evidence above await final review; no
acceptance is inferred from checks alone. The captured first mission and finale
do not certify unseen regional art or every actor/attack combination.

The source remains version 0.2.0/code 2 because this is a benchmark, with no APK
export/install or claimed graphics release. Coordinator must assign a higher
version for a delivered graphical APK and own genuine update/native checks.
Physical Fold7 checks, sound judgment, human pacing/fun and measured real-time
performance are separate and unverified. No new phone testing is required for
this graphics milestone.
