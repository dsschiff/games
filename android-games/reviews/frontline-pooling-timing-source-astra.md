# Frontline pooling timing harness — bounded source review

2026-10-18, Astra. **Source clear for the separate timing retake; no substantive blocker found.** This is CPU/read-only source and retained JSON inspection, not an executed test, timing pass or visual acceptance.

Inspected clean worker `f8a9c7b2533a838df30827c1adf756a842285591`; status remained empty. Relative to `78cb4bd17b33e60c47749506de5a1f208a48143e`, only `POOLING_FOLLOWUP.md`, `tests/graphics_benchmark.gd` and `tests/frame_sampler.gd` change. App runtime, artwork, rules, lifecycle, inputs and save logic are unchanged. The previous genuine fixed-rate movie remains bound to its historical capture source; it does not establish unpaced performance.

Reviewed pins:

- `tests/graphics_benchmark.gd`: `c505e86bcebefe9b2ebfcc19182cccee3bd5bc827fb34db65f8acdfaebadfb43`
- `tests/frame_sampler.gd`: `996a2abce631be6257476582b777b90a09827b1d14f433a2f21577f3b87cfbe2`
- unchanged `tests/run_graphics.py`: `420029ca17d0ac6a928e7f0352dfbed4a6ef9a37f5144395daa865bc51e9d9bb`

Timing mode sets `Engine.max_fps=0` and disables VSync before starting the sampler, verifies both and rejects movie writer/fixed-FPS invocation. The Python runner separately forbids measurement with movie or native-frame capture. Sampler metadata is recorded after setup and real start/resume input. No runtime script resets these settings. The executed-source manifest includes the sampler even though the smaller benchmark report's selected source list omits it.

If the actual game becomes paused during measurement, the harness records simulation time, wall milliseconds and menu visibility, releases the held touch, and finds/presses/releases the actual visible enabled Resume button through ScreenTouch. Failure to clear pause is an error. It does not assign `paused`, call the handler directly, suppress lifecycle notifications or accelerate the clock. The unchanged wall-clock bound still terminates an unsuccessful run. The new observed-pause record must not be described as a logged OS focus notification: focus loss remains an inference unless separately witnessed.

The sampler excludes held/modal/ready/terminal frames and resets its interval cursor across gaps. Warmup is 1.5 cumulative eligible seconds. `snap` only obtains framebuffer pixels while the sampler is inactive, so in-interval event snapshots are in-memory state records, not PNG readbacks. Instrumentation, input policy, presentation, autosaves and normal host work still contribute to host submission intervals. The 120,000-row cap now explicitly counts dropped eligible rows; final reporting must disclose any nonzero count and the resulting truncated denominator. Render totals are process-wide counters, not isolated actor or GPU timing.

Independently read the failed first run `root-pooling-unpaced-capture-20261018T190505016720Z`: source unchanged, wall-bound error, simulation progress 26.1333333333541 seconds, VSync **1**, 7,651 excluded frames, 2,909 measured rows spanning 24.718096 eligible seconds, and **zero heavy frames**. Its measured intervals cannot validate uncapped or heavy-scene performance. Preserve the run and error; no relabeling is justified.

The new independent receipt must establish actual completion, metadata VSync 0/max_fps 0/time_scale 1, its observed Resume interruptions, raw-row/drop totals and actual heavy denominator. A 55-second requested passage is not automatically 55 measured or heavy seconds. These are normal interpretation checks on the retake, not a request for a new campaign or additional film. This source correction is suitably bounded and does not require repeating the unchanged fixed-rate visual movie.
