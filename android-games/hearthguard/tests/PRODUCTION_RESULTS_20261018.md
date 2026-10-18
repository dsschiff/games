# Hearthguard production handoff, 18 October 2026

The authorized batch is complete and the GPU is released. Ten invocations pass:
nine source-bound native movies and one separate uncapped host-timing run. All
6,092 receipt artifact rows were rechecked for exact bytes and SHA256; all
executed source copies match their recorded hashes. The worktree's98 runtime/art
files still match clean042d7c2e1abd2bcf3be300e715bdfa1375f6c8a0, version0.3.0/code3.

The explicit accepted-run index is [production-accepted-runs-20261018.json](production-accepted-runs-20261018.json).
For each run it records the absolute source directory, source-hash index SHA,
receipt SHA, production-report SHA, source provenance SHA, movie SHA, actual
stream/container duration, frame count, runtime freeze and executed helper
revision. Raw slots and frames stay retained. The independent full hash audit is
`.artifacts/production-batch-verified-20261018T181837423840Z.json`.

Evidence paths below are relative to the builder game's `.artifacts/` directory:
`C:/projects/active/_worktrees/games-hearthguard-20261018/android-games/hearthguard/.artifacts/`.

| Passage | Accepted directory | Checks | Native frames | Stream seconds |
| --- | --- | ---: | ---: | ---: |
| Short opening UI/cold closure | production-restore-20261018T175458240947Z | 10 | 277 | 9.233333 |
| Heavy/Fens | production-heavy-20261018T175629952989Z | 8 | 1043 | 34.766667 |
| Later/Glasswind | production-later-20261018T175843497815Z | 8 | 996 | 33.200000 |
| Genuine loss → Retry | production-retry-20261018T180108734690Z | 17 | 106 | 3.533333 |
| Resize/effects/menus/held saves | production-lifecycle-20261018T180216667030Z | 38 | 321 | 10.700000 |
| New-process restore of lifecycle slots | production-restore-20261018T180358427814Z | 10 | 97 | 3.233333 |
| Legacy play → Expedition retake | production-legacy-20261018T180929396675Z | 9 | 198 | 6.600000 |
| Ten earned entries and ending | production-tour-20261018T181046336385Z | 20 | 273 | 9.100000 |
| Separate unpaced host timing | production-timing-20261018T181204508893Z | 11 | — | — |
| Concrete Ram coverage gap | production-ram-gap-20261018T181416554051Z | 14 | 968 | 32.266667 |

All nine movies fully decode and match their native frame inventories. They
total4,279 frames at fixed30 cadence, which is not a performance measurement.
Eight are720x1280. Lifecycle uses1968x2520 with explicitly inventoried native
pixels blitted1:1 and padding only. Movie duration includes held/menu frames;
Retry, Legacy and Tour change scene/timebase, so end-minus-start simulation time
is not a passage duration.

## UI closure and genuine state

The short closure cold-loaded the exact two app-written final slots from the
historical opening, authenticated their whole state/settings/profiles before
boot, remained held, then used ordinary input for8 simulation seconds. Original
native frames90/180 show the actual floating110,850 circular base and knob with
Pad5's price above the obstacle. Frame274 shows release: the price returns to its
authored anchor and the control returns to its idle anchor. This supports the
builder's bounded correction; independent assessment of physical label/pad
association and readability remains pending.

The original60s opening stays historical at576d4af; it was not replayed. Its
receipt/source/movie hashes are separately preserved in the accepted-run index.
The short closure is correctly labeled Restore, not a new full opening or a
heavy encounter.

Heavy reached natural victory at191.566667 simulation seconds before its36s
cap:101 stopped, zero leaked,16refuge. Later reached natural victory at238.016667
before its34s cap:141 stopped, zero leaked,16refuge. These start from distinct
accepted earned saves; they do not constitute a new continuous full campaign.

Retry used the genuine historical loss and checked clean finite restock, the
entire definition and both profiles. Lifecycle checked whole paused context
across1080x2400/1080x2520/1968x2184/1100x1400/1600x1000, actual movement/release,
an effects-toggle pair restoring exact settings, menus/Back and held raw slots.
Cold restore was another Godot process reading those exact lifecycle endpoint
slots. Legacy resumed genuine old play and preserved its complete played state,
profile and settings on entering Expedition. Tour required the genuine earned
epilogue and visited all ten entries and the ending with actual buttons/scroll/
Back, retaining the entire earned profile.

## Actual exposure and selected original frames

The initial actual primary inventory left only Ram missing. The authorized Ram
passage therefore used the pinned genuine map3 source at79.966667, ordinary input
through a declared45s lead-in to125.133333, then the32s recorded encounter ending
held at157.300000. Ram is alive in604 active movie frames; original frames300/650
show the large horned shield-bearing character on the road.

The new042d7c2 runtime alone now has observations of all12 roles and all three
regions; every role exceeds15 consecutive frames for one live actor. This uses
short UI closure + Heavy + Later + Ram, without depending on old-runtime
opening observations. These projected model/ID counts locate review material.
They do not establish visible-pixel quality, animation quality or independent
acceptance of all models. `production-coverage-20261018T181707210444Z.json` also
retains the mixed historical-opening inventory with each source freeze explicit.

Selected builder inspections, with exact original PNG hashes and caveats:

- `floating-control-original-inspection-20261018T175703740180Z.json`: native
  frames90/180/274/276 from short closure, including gesture and release.
- `heavy-original-inspection-20261018T180001078678Z.json`: frames100/240/550,
  Fens, healer, armor, Matriarch, tower titles/prices and circular control.
- `later-original-inspection-20261018T180227757334Z.json`: frames465/622,
  Glasswind and Regent with other live enemies and readable tower labels.
- `lifecycle-original-inspection-20261018T180541586286Z.json`: frames44/78,
  Fold-sized and landscape composition; the tool downscaled these two large
  preview canvases. These establish composition observations only.
- `ram-original-inspection-20261018T182000Z.json`: native frames300/650,
  Ram and normal armored-enemy scale distinction.

Builder also viewed Tour originals region03/region07/earned-ending. No browser
playback or independent motion review occurred here. Root is preparing the
original-clip viewer and Astra review. Native Android, phone performance and
human fun remain separate.

## Uncapped desktop timing

The dedicated40s run disables VSync and the FPS cap, keeps time_scale1, and makes
no framebuffer readback during measurement. It records18,712 eligible intervals
over38.527002s after1.5s warmup;13,394 heavy intervals span28.128648s. There are
zero dropped rows. The all/heavy percentile arithmetic was independently
recomputed from all raw rows.

| Host submission intervals | Median ms | p95 ms | p99 ms | Above16.667ms | Above33.333ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| All eligible | 1.803 | 3.488 | 4.467 | 23 | 0 |
| Heavy: boss or at least6 enemies | 1.843 | 3.539 | 4.511 | 17 | 0 |

Observed maximums:14 live enemies,1051 whole-viewport draw calls and228596
primitives. Hardware is Ryzen9 7950X3D / RTX5070Ti, Godot4.7.2 Compatibility.
Actual timing observations include at least12 cross-ID actor reuses and143
effect-lifetime reuses; these are lower bounds. Raw rows, worst25, last120,
hardware/settings/AA/counters and exclusions stay in `frame-timing.json`.
This is host render-loop submission timing with instrumentation and normal
autosaves in process, not displayed FPS, GPU timestamps, maximum possible load,
phone performance or human fun. Background host load is uncontrolled.

## Failed first legacy attempt and helper delta

`production-legacy-20261018T180510376893Z` is failed and excluded. The shared click
helper accessed `journey_list`, absent from legacy main.gd. The run remained at
the held old save until its180s timeout. The original runner then raised
FileNotFoundError on the missing final native inventory before writing a
receipt. All3366 partial frames, logs, frozen source copies and any encoded
failed movie remain retained. The failure audit is
`legacy-failed-run-audit-20261018T180928348826Z.json`; no final receipt or success
is invented for that attempt.

Clean helper-only commit3e76816 guards Journey-control lookup by schema2 and
skips movie processing when a failed passage has no final report/inventory, so a
failed receipt can be retained. The first six passed invocations use af59a73's
harness; the legacy retake, tour, timing and Ram use3e76816. All share the
identical042d7c2 runtime/art. The narrow actual legacy retake passes; no additional
film, full suite or campaign is requested or run after this batch.

All owned synchronous Godot import/parse/render children returned0 on accepted
runs, and the final runner finished before GPU release. A sandbox Get-Process
query returned0 while the failed legacy capture was actively writing frames;
that query alone is unreliable release proof here. Release rests on completion
of every owned subprocess and the final recording's stopped writes. No rendering
was started after release. No export/sign/install, ADB or clipboard action was
performed by this builder.
