# Tower Trials: readable encounter arithmetic

The first design increment preserves the numbered-room puzzle, route choices,
power transfer, keys, shields, traps, Undo, campaign progression and seeded
challenge saves. The Hero Wars brief supports ordered numerical encounters; the
original game's strict-greater rule and resource routes remain unchanged.

## Reproduced defect

A fresh save earned watch_01 through real engine touch input, then entered Twin
Chimes. The independently rising per-spirit +3 and +7 values and the larger +10
room total intersected in 104 pair/frame comparisons. Entering Wrong Refrain
naturally produced 45 intersections between TOO STRONG and LANTERN OUT. The
baseline focused suite failed 2 of 28 checks; this failure remains preserved at
`.artifacts/design-cpu-20261023T235938013147Z`.

`_draw_fx` painted every popup at its independent room anchor without testing
other live labels. More encounters could therefore make the power transfer
harder to read precisely when order mattered.

## Change

Only `scripts/presentation/tower_view.gd` changes at runtime. Popup placement and
painting now share real font, size, baseline and outline measurements. Later
labels choose the closest free vertical position inside the board feedback area;
a dense group can repack into a vertical stack. Long celebration text fits the
logical board width, including its outline. All existing text, values, colors,
lifetimes, growth/rise, encounter timings and input availability remain. No new
hint or recommended route is shown to players. The test solver chooses automated
inputs only.

## Verification

`python android-games/tower-trials/tools/design_check.py feedback_readability run_tests campaign_playthrough`

Source-pinned run `.artifacts/design-cpu-20261024T000211317275Z` passes:

- Focused geometry/input: 1,232 checks, 412 touch taps, all 36 authored towers
  earned through touch and natural processing. Checks rapid room chaining,
  individual and total values, loss, Undo, shield, large late arithmetic, final
  celebration, reduced effects, and cover/inner/wide viewport bounds. Font and
  outline bounds are independently reconstructed from the actual draw baseline.
- Existing rules/save suite: 3,503 checks, plus 3,105 challenge-rule checks.
- Existing campaign input: 1,363 checks, 587 taps, 36 towers, including existing
  mistakes, Retry, Undo, pending pause, saves and restore checks.

`python android-games/tower-trials/tools/design_check.py challenge_playthrough graphics_view`

Run `.artifacts/design-cpu-20261024T000403604055Z` passes seeded challenge input
175 checks/115 taps and headless 3D correspondence 252 checks/3 taps/2 Back
requests. The latter script name does not imply a rendered run: the runner
always requests `--headless --audio-driver Dummy`. Every suite requires its
explicit PASS marker, zero exit status, no strict error markers and unchanged
source hashes. `DESIGN_INCREMENT.json` binds the retained logs and sources.

## Still open

CPU geometry proves separation and bounds; rendered qualitative readability and
popup motion have not been reviewed. Native Android update/save checks, physical
device performance, sound and human puzzle pacing/fun are not claimed. No release
version, export/signing identity, save format, active snapshot or catalog changed.
