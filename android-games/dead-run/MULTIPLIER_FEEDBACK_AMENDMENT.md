# Dead Run multiplier charge feedback

Base: origin/main 64cd050331613604fb3489468dd758264e1bfe15. Runtime scope is only scripts/presentation/adapter.gd. Version remains 0.4.2/code8. Rules, thresholds, contacts, target/panel geometry, pulse behavior, timing, Store, both catalogs, schema and complete save meanings remain unchanged.

The original panel kept SHOOT x2 unchanged at 10 actual hits. It now reads NEXT 10/40 below the existing applied-value numeral. Both numbers are cumulative: for a later x2 gate working toward x3, NEXT 71/140 means 71 actual contacts toward the pinned next threshold of 140. Shots and misses do not charge it. At cap the existing CREW caption returns. Only the caption font/outline shrink to measured string-plus-outline bounds inside the existing panel; measurement repeats only when the caption changes. No bar or new target is added.

## Actual-input proof and precise limits

The frozen fresh-owner driver selects road 1 and Start through real GUI touch, steers using ScreenTouch/ScreenDrag through normal production processing, partially charges the gate, steers away for 60 ticks, returns, crosses it, then presses Pause. It never injects progress or calls gameplay handlers. Partial charge is 10 hits at tick2251, then 15 hits at tick2311 on return while the gate remains x1. In-flight contacts continue during the move. The earned threshold is a natural 35-to-40 volley at tick2457; this is NOT a one-hit 39-to-40 demonstration. Crossing applies x2 once; final paused state is tick2737. The earlier centered route overshot 28-to-43; it is retained, not relabelled as exact-threshold proof.

Unchanged-presentation baseline 300 checks/97 failures and final 300/0 use identical driver and runner bytes. Their 28 raw input events, all 2734 whole-context tick hashes, five complete observation contexts, final complete context, complete Store readback and raw alternating slot strings/bytes match exactly. Only adapter.gd differs in their 239-entry raw source maps; all before/after maps are stable. Intended caption/font fields differ. This proves simulation/save parity for this bounded route, not all possible gameplay.

Separate typed, nonpersistent label fixtures cover 96 sets: catalog1/current x24 roads xauthored/seed61723. They exercise zero, threshold-1/threshold/threshold+1, later threshold/cap, actual value numeral, pinned initial/step, mirrored/seeded positions, crossed hiding, unchanged additive labels and hydration without state mutation. String width plus both outline margins is measured against the original panel interior. These deliberately constructed presentation dictionaries are not earned progression and are never saved. The earned owner remains completely unchanged by them. Current catalog1 has no multiplier gates; its existing additive labels remain covered.

The final focused packet is .artifacts/graphics/multiplier-canonical-final-multiplier-20261024T124753Z. The existing presentation regression is .artifacts/graphics/multiplier-regression-presentation-20261024T123925Z, 22/0. The canonical baseline/final pair uses the identical engine-canonical test UID uid://c8katwah6l0cw. A tiny ResourceUID round-trip check found that the initial manually assigned text mapped to this same numeric ID (7109752070939700454); only that packaging string was normalized. The earlier presentation22/0 regression has the exact final runtime; its test-UID metadata text predates this equivalent normalization. The probe source was deleted after binding its exact command/output in a small receipt. The final pair maps also contain the two then-current amendment/checkpoint documents; their later audit updates are separately pinned here. All other 237 current bytes match the final map.

The final focused run and existing presentation regression both exit0; their raw logs contain no ERROR, SCRIPT ERROR, WARNING or ObjectDB leak. The new multiplier runner mode strictly rejects those warnings in addition to errors. Godot4.7.2, existing source-matched cache, headless, fixed60 simulation, Dummy audio; no import/editor/render/native/OS clipboard/build/export was run.

Historical packets remain failed: the initial test parse error; the harness Unicode assertion error; the old centered/edge baseline runs; and the final unchanged-presentation baseline. None is filtered or converted to success. A failed Python UTF-8 read left the old harness running once; that duplicate failed packet is retained. These are small necessary evidence packets, not source/asset backups.

## Repeat and remaining acceptance

From the worktree root: python android-games/dead-run/tests/run_graphics.py multiplier --headless --label root-multiplier

Relevant existing regression: python android-games/dead-run/tests/run_graphics.py presentation --headless --label root-multiplier-regression

Do not use the synthetic all-fixture tail as a production motion recipe. A later root-granted matched normal1x route-only capture must establish the caption's salience during camera approach and truthful first-minute feedback. CPU font bounds are not pixel readability, measured FPS, Android/physical-phone acceptance, discoverability, comfort or fun. No content/balance/replay-mastery change is included.

Independent source/checkpoint review: Astra CLEAR for this source/CPU scope. The audited pre-disposition checkpoint was adae620c27f1aa1af4e6afd11a3729705932136907602ccee22ee99676708ed9; only these disposition fields changed afterward. Root owns later integration, serialized rendering, version/export/native and human review.
