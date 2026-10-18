# Gear motion harness — early CPU/source review

2026-10-18. Read-only source and completed artifact inspection; no browser, Godot, GPU, ADB or device operations. This is not visual acceptance. All eight quality rows remain pending normal-speed playback.

## Disposition

Proceed with the already planned corrected evidence runs. No new runtime/rules blocker identified in this bounded delta. The four initially supplied runs cannot establish the requested detailed gameplay/timing claims because their gameplay JSON was overwritten by the process report. The current runner fixes that collision; corrected completed receipts and raw data remain necessary before relying on those claims. Do not reinterpret old process PASS as preserved gameplay evidence.

## Inspected source and drift

Worker HEAD: `bbb8fe1af6d8eea7071e955bcb840d5a72235dc9`. Worktree remains dirty: modified `scripts/frame_capture.gd`; new `tests/graphics_motion.gd`, its UID and `tests/run_motion.py`. These three file hashes were identical at initial and final inspection:

| File | SHA-256 |
|---|---|
| tests/run_motion.py | c2fb974f918364363281b9e26fdba2e67d0934bccbe1ac4772e3c50639f164d5 |
| tests/graphics_motion.gd | adb8c73bb7386aa6b84324a1a1c5795ef9e9a295025328ec6e1b22434f31f8a5 |
| scripts/frame_capture.gd | 15ebfe09e14daf7b52618815e2fe447d781a68685ff1f493a40765f584adbc01 |

This is an inspected snapshot, not a frozen final commit. Relative to each named initial run, the only observed current-source mismatch among its 182 pins was `tests/run_motion.py`.

## Provenance and report separation

The runner creates isolated user directories, imports first, binds source after import, retains byte-exact executed source, and checks source again after execution. Process output now uses `execution.log`/`execution-report.json`; application evidence uses `motion-report.json`. A successful new receipt validates stage, failures and frame count and binds the gameplay report SHA. Encoding uses 30 fps matched to the fixed simulation cadence, with full decode verification. That is normal simulation speed, not measured real-time performance.

Actual inspected historical runs:

- `motion-opening-20261018T152033406816Z`, `motion-heavy-20261018T152609030953Z`, `motion-later-20261018T152953049250Z`: receipt PASS/source unchanged, but `motion-report.json` contains only command/exit/errors/passed/log and has no gameplay SHA binding. These are affected by the known collision.
- `motion-metrics-20261018T153148498589Z`: receipt failed/source changed and the same overwritten report. Its console 11-check PASS does not recover the missing timing rows.
- `motion-opening-20261018T153414830569Z`: in progress during inspection; no completed receipt was available. No outcome inferred.

The middle and final-boss raw save hashes match the corresponding scenes in `evidence/decision-pressure-checkpoint.json`, whose SHA is `e3d3dbf50bd3b8a62c11f805c2093684ba13eb824b95c1329ee6604ec8ca7bbe`. Middle is camp_05 at 36 seconds, four prior clears, 104 allies/one enemy; SHA `f6a4d88b4625b89bcbd3eddd63ce1390a950eb386b46c8628f9e55b579b7b111`. Final is camp_09 at approximately 228 seconds, eight prior clears, 111 allies/one enemy; SHA `5f1f97f31730c76c8741b8dba745186f52757d7d860f2c8e7fa565e3c2e1b898`. These are indexed prior input-generated snapshots, not freshly played campaign progression in this harness. No unchanged whole-campaign rerun is needed.

## Input, reset and save semantics

The new script overrides the inherited run; it does not execute window_fit's injected fixtures or the old accelerated playthrough. Its actual actions reach inherited screen-touch/drag input and the fitted coordinate mapping. Gameplay advances through ordinary process-loop timers; there are no direct battle ticks or game-state assignments in the new harness. `Gear.buy` in reset is a feasibility query preceding actual purchase input.

Opening starts fresh, performs board preparation through input and asserts earned camp_01 victory for a sufficiently long run. Heavy/finale load indexed saves and assert whole decoded run/profile/settings before input; finale additionally requires earned camp_09 victory. Reset requires a genuine passed prior victory, checks Retry namespace/transient reset and profile/definition retention, then paused image/context equality, resizes, reduced effects and parking. Restore copies prior app-written slots byte-exact, checks decoded starting context, paused hydration without phantom shots and actual Resume. Legacy enters practice by actual menu input. These assertions still need completed corrected receipts.

“Whole loaded context” means the existing decoder's semantic result, with numeric absolute tolerance below 1e-9; it is not raw JSON byte equality. In particular, SaveStore.decode intentionally clears transient `projectiles`: the final indexed snapshot contains one. Raw original slot hashes preserve the source separately. Retained successful-run slots are primary and backup; this harness is not interrupted `.tmp` recovery testing. Selection by highest revision is suitable for those successful ordinary slots but does not duplicate every recovery/tie rule of SaveStore.read.

The reset move/Undo check proves net whole-context retention; it does not independently assert an intermediate changed board, so it cannot alone prove that a new move succeeded. Existing focused input coverage remains separate.

## Timing validity and limits

Metrics rejects movie/native-frame modes, passes no fixed-FPS engine argument, verifies no movie writer and samples only after the initial still captures. During sampling, `on_frame` records lightweight observations but performs no texture readback or PNG writing. Metrics stops before the outcome capture. Normal app autosaves remain part of the workload.

The clock is monotonic microseconds at `RenderingServer.frame_post_draw`, measuring render-loop submission intervals rather than OS presentation or GPU duration. Eligibility excludes menus, pause, loading/ready/terminal states and visible modals; gaps reset the previous timestamp. Warmup is 1.5 eligible seconds. All rows remain available, with median/p95/p99, counts above 16.667/33.333 ms and a declared heavy subset of at least 120 total actors. The intended heavy run must actually produce over 60 such samples. No distribution can be accepted from the overwritten metrics run.

Draw calls/primitives are visible 3D SubViewport counters, excluding shadow passes; node count is process-wide. `draw_cpu_usec` is the main 2D `_draw` callback's CPU elapsed time, not complete 3D/GPU work. Fixed-cadence detection now uses the actual movie writer plus the explicit capture marker because Godot strips engine flags. Desktop hardware measurements cannot establish phone FPS, maximum possible crowd performance or fun.

Final closure requires only the planned corrected evidence receipts, clean source binding and actual eight-row motion review—not new broad campaign or physical-phone gates.
