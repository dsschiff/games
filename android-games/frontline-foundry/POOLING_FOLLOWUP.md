# Bounded actor and effect reuse

0.3.1/code 4 source candidate, based on landed `d3a36847ec750b92e0c9a3210dee67b67aad010e`.
The accepted 0.3.0/code 3 art, eight-area review, native update evidence and all
historical source-bound movies remain historical. This is an allocation/lifecycle
follow-up, not new art or a campaign rewrite. Root owns independent review,
serialized rendering grants, APK export/signing, genuine code3-to4 native update,
Back/transfer/lifecycle checks and the private bundle. Further phone testing is
deferred; no physical performance or human-play claim is made here.

## Implementation

`scripts/presentation/outpost.gd` owns hidden, disabled reserve nodes that remain
its children. An acquired actor retains its original model, skin, skeleton,
attached kit, sockets, labels and health geometry. The key is role plus team;
the role determines the authored primary weapon and loadout, and team determines
the uniform/health palette. Authoritative entity IDs and adapter epochs are not
pool keys. A departed compatible actor can serve a new ID; a killed enemy keeps
the original .85-second corpse interval before entering the reserve. A changed
role/team under an existing ID is explicitly replaced with a compatible lease.

| Reserve | Global inactive cap | Per compatible key | Visible behavior |
| --- | ---: | ---: | --- |
| Actors | 24 | 4 per role/team | No active actor limit from these caps |
| Effects | 36 | 18 per shape kind | Existing optional tracer/pulse limit of 36 retained |
| Essential warnings | Shares effect reserve | Separate Storm/Drill shape keys | Never suppressed by inactive caps or Reduced Effects |

Overflow inactive nodes are freed. Tracers retain their own mutable BoxMesh;
pulses and warning kinds retain separate TorusMeshes. Reacquisition restores
transform, length/radius, material/color, overlay, layers, transparency, visibility
and process mode before use. This avoids sharing a mutable shape between active
effects. Persistent warning keys, optional effect lifetimes, damage timing and
the adapter's dedupe rules are retained.

`actor.gd` captures authored transforms/visibility/material overrides and label
settings once. Reuse resets those nodes, every bone pose, root/model transforms,
gait, travel, aim, health, hit/death/recoil/repair state, equipment visibility,
status text and current contact attachments. Contacts synchronize in the same
call with the actual posed bone or turned/recoiling barrel. Pause/resume does
not exchange otherwise stable logical actors merely because the epoch changes.

Packed-scene and palette dictionaries are now owner-local, rather than static
process dictionaries. All inactive nodes free with their outpost. Owner exit
clears its resource dictionaries even when the viewport survives; it cannot clear
another live owner's caches. Retry/load replaces the owner using the existing
scene/input/save path. New owners start with empty reserves and counters.

The 47 GLBs, manifest and generators are unchanged. Rules/RNG/definitions,
progression, save schema/meaning/storage, package/signing, input/Back/transfer,
Reduced Effects and orientation/window policy remain unchanged. Only version
metadata advances consistently to 0.3.1/code 4.

## Verification and evidence boundaries

`tests/pooling_tests.gd` uses explicitly synthetic CPU controls to test actual
instance identity, contaminated-state reset for all fourteen compatible actor
roles, same-call contact, reserve saturation/overflow, unlimited active actors,
essential warnings, fresh authoritative IDs, corpse expiry, epoch/dedupe,
pause, real Retry GUI, complete durable/cold context and cross-viewport owner
release. Another control compares complete state and consequential events after
each of 600 actual rule ticks with and without the pooled presentation.
These fixtures do not establish visual quality or earned progression.

`tests/graphics_benchmark.gd --require-reuse` instead boots an unmodified genuine
earned save and validates complete state/profile/settings/career before boot.
Its existing read-only policy drives real touch/GUI inputs. It observes actual
node IDs across fresh entity leases and records model/rig identities and pool
counters; it never acquires/retires nodes or calls gameplay/animation handlers.
The passage must observe actor/model/rig and effect reuse and bounded reserves.
At its end a real GUI pause writes the complete current context; exact raw
app-written slots are retained in `reuse-save/`, with hashes and provenance.

The runner isolates all user-data/temp directories, imports with the pinned
headless editor, archives the executed sources and verifies they remain unchanged.
Each run has a unique path; failures are retained. CPU capture cadence is capped
at 60 process frames to avoid a competing headless busy loop and is never used
as a performance sample. Rendered movies and separate unpaced frame timing require
the coordinator's explicit serialized grant. Timing excludes movie/fixed-FPS,
frame PNG capture and framebuffer readbacks during its measured interval.

Commands (from this worktree):

```powershell
python -B android-games/frontline-foundry/tests/run_graphics.py pooling --label pooling
python -B android-games/frontline-foundry/tests/run_graphics.py checks --label pooling-regression
python -B android-games/frontline-foundry/tests/run_graphics.py capture --seconds 55 --require-reuse --resume-from android-games/frontline-foundry/.artifacts/paced-rendered-20261018T064825390242Z/earned-final --label pooling-genuine-cpu
# Only after serialized GPU grant:
python -B android-games/frontline-foundry/tests/run_graphics.py capture --render --movie --seconds 55 --require-reuse --resume-from android-games/frontline-foundry/.artifacts/paced-rendered-20261018T064825390242Z/earned-final --label pooling-dense
python -B android-games/frontline-foundry/tests/run_graphics.py capture --render --measure-frames --seconds 55 --require-reuse --resume-from android-games/frontline-foundry/.artifacts/paced-rendered-20261018T064825390242Z/earned-final --label pooling-realtime
```

The genuine input boundary is retained from the original passed actual-input
campaign capture at Foundry time145.4667, not the installed emulator slots.
`tests/pooling-source.json` pins the source directory, raw slot hashes and original
parent receipt hash; the runner checks every link and allows no fallback. The runner copies raw slots
without rewriting packets. The coordinator's separately preserved native code3
baseline is not injected, cleared or changed by builder work.

Final run paths, source bindings and review limits are recorded below as completed.

## CPU freeze handoff

The final source passes93 focused pooling checks in
`.artifacts/pooling-freeze-cpu-pooling-20261018T183003087975Z/` and103 presentation
regression checks in `.artifacts/root-final-pooling-regression-checks-20261018T185415123053Z/`.
The coordinator reverified all receipt artifact hashes and current source files
for both; no later runtime change is included. The final actor helper uses null
defaults and explicit owner dictionaries, avoiding implicit shared default caches.

The earlier pinned genuine55s CPU passage showed mortar20-to22 and sapper23-to26
actor/model/rig identity reuse and103 effect reuses. It precedes that final cache
ownership correction; it remains historical rather than final-source visual proof.
The forthcoming short genuine rendered passage must verify reuse again. All47
GLBs and other authored art files remain unchanged. Exact CPU receipts and limits
are indexed in `tests/pooling-cpu-accepted-20261018.json`.

The builder turn was interrupted by the environment refresh. Root completed the
last focused regression and this handoff from retained files. No rendered execution,
APK export/install, emulator manipulation, clipboard or push occurred in this
worktree. Astra source review, one short actual reuse film and separate unpaced
timing remain required before the root-owned signed code4/native update and bundle.

## Timing-only harness correction

The final-source55.4667s movie passes with both real actor/model/rig reuses.
Its subsequent first timing attempt is failed and retained: actual playback
paused at26.1333s and hit the90s wall bound. Raw metadata also exposes VSync1,
so this attempt cannot be described as uncapped. No heavy samples were reached.

Timing mode now explicitly disables VSync and FPS caps, asserts no movie/fixed
capture, and handles an observed pause through actual GUI Resume, retaining
each interruption in the report. Game focus/lifecycle handlers are unchanged.
The sampler retains up to120000 raw rows and reports any dropped rows explicitly.
These changes affect tests only; the actual app runtime/art and accepted movie
remain at78cb4bd. A new separate timing receipt is required; the failure is not
relabeled or overwritten.
