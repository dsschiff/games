# Android delivery probes

These small original projects verify the delivery pipeline before full game production. They are technical fixtures, not completed entries in the six-game portfolio.

- `input-2d`: touch/button placement, resource constraints, wave outcomes, pause/restart and persisted placements.
- `combat-3d`: a rendered 3D arena, drag movement, automatic combat, encounter outcomes, pause/restart and persisted actors.

Both expose a headless rule suite in `tests/run_tests.gd` and an input-driven scene playthrough in `tests/playthrough.gd`. Use isolated local APPDATA for desktop user data; Android uses the app sandbox. `--fixed-fps 60` lets recorded engine-input playthroughs run without real-time waiting. Passing these probes establishes neither commercial-ad fidelity nor physical-phone performance.
