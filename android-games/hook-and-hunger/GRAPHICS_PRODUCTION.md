# Hook and Hunger original 3D production checkpoint

CPU implementation is complete for first rendered inspection. **Graphics quality,
normal-speed motion, performance, Android update and release readiness have not
been established.** This session had no render slot and used no rendered Godot,
browser, Computer Use, native app, video, emulator, ADB or host clipboard.

The assigned base is `29653752fce58fd9b8eeea841ae43187e7e4a938`, branch
`codex/hook-graphics`. Only this game directory changed. Root owns review,
integration, GPU scheduling, signing, export, native validation and delivery.
The old functional branch and private saves/evidence are retained.

## Implemented

- Original CPU Blender kit: **35 GLBs**, including a brass-helmet salvage diver,
  six ordinary creature roles, Bellkeeper and five campaign boss actors (the
  four beacon encounters include the Sun/Moon pair), four distinct weapons,
  four continuous beveled terrain shelves and fourteen tropical prop modules.
  No paid, downloaded or copied artwork. The supplied Top Force still informed
  rounded forms, directional lighting and grounded composition only.
- All thirteen actors have actual eighteen-joint armatures and skinned modeled
  limb segments, plus an imported authored breathing channel. Runtime poses
  articulate thighs, knees, feet, shoulders, forearms, torso, head and crests:
  distance-driven movement, smooth facing/start/stop, attack windup/contact/
  recovery, charge, recoil, damage, collapse and diver victory. Visual quality
  of those poses remains pending direct rendered inspection.
- Chained attacks use the unchanged 0.36-second rule clock. The actual authored
  `ContactTip` reaches the rule impact point at half swing. Links join the
  articulated `ChainSocket` hand to the actual authored `ChainEye`, with explicit
  same-call skeleton/BoneAttachment synchronization. Weapon reach, selected
  cleave, recovery and damage remain rule-owned. Nothing in an animation callback,
  mesh bound or pose moves actors, resolves collision or applies damage.
- Original tropical composition covers the legacy two-pen entry, every one of
  the twelve campaign passages, all four island palettes, seeded arenas and the
  harbor ending. Palms, coral, reef rocks, buoys, brass fences/doors, modeled
  forges, salvage chests, boats, beacons, kiln works, wrecks and crystal choirs
  provide regional landmarks and separated foreground/middle/far scenery.
  Four beacon lights and a sailing fleet mark the final rule victory.
- Scenery uses complete transformed mesh bounds, beyond a conservative actor
  envelope that includes the large articulated bosses. Continuous shelves have
  room for those bodies. Low navigation inlays mark the unchanged rule limits;
  opaque shoulder fences and scenic props sit farther outside them. Authored
  collision rocks remain at the exact saved-definition coordinates/radii.
- A scene-owned adapter duplicates immutable snapshots. Contact, swing,
  purchase, hurt, fall and terminal observations have an epoch and serial;
  contacts group once per rule crossing. Hydration/Retry/pause/import/rebuild
  clear transient effects and cursors. No presentation RNG touches rule order.
- Compatible actor/effect/salvage/projectile reserves are scene-owned and bounded
  to twelve per key/64 total inactive objects. Active rule objects are never
  capped. Reuse resets transforms, bones, facing, health, warning geometry,
  socket, motion, event and effect lifetime state. Owner caches have no mutable
  static/default lifetime and cannot clear another live viewport.
- Existing touch/keyboard movement, native TextEdit, guarded clipboard handling,
  save/import, progression, arena return and Back/lifecycle meanings are retained.
  Owned gesture release is handled before GUI consumption; new gestures still
  begin through unhandled world input. HUD/menu rectangles adapt to the actual
  viewport and Android safe-area query. Floating control and dock sign clearance
  use the real control origin. Headless resize/input tests cover native, cover,
  inner, square, intermediate and wide dimensions.

## Sources and reproduction

`art/source/build_assets.py` is the complete original generator. Use pinned
Blender4.5.14 background mode, factory startup and two CPU threads. It does not
render. Stable sculpt names, deterministic triangle order and stable area normals
remove observed exporter ordering/normal drift. Two fresh final exports match
byte-for-byte for **all 35 GLBs**, including skins, animations and weapon markers.

`art/manifest.json` records each asset's hash, byte length, mesh/skin/joint/
animation counts and Blender bounds, plus raw and normalized-LF generator hashes.
`tests/verify_kit.py` independently verifies GLB framing, mesh names, material
presence, skin weights/joints, animation channels and authored weapon markers.
Godot's actual imported Skeleton3D, Skin and AnimationPlayer are tested too.

Private generation logs, failed attempts, repeat exports and receipts are in
`.artifacts/graphics-cpu/`. `evidence/graphics-cpu.json` is the current compact
index of successful invocations, failures, exact source bindings and next action.
Each test invocation first completes headless import, then copies/hashes executed
sources, uses isolated APPDATA/LOCALAPPDATA/TEMP/TMP and stops on source drift.
Raw sources, logs, historical exports and private userdata remain in this worktree.

## Verified on CPU

- 214 presentation checks: actual imports/skins/channels, same-call sockets,
  articulated poses for every creature, all thirteen compositions, whole-bounds
  clearance, 360 full-state steps per map with/without presentation, immutable
  snapshots, once-only contacts, reset/reuse, reserve limits, harbor cues and
  independent live-viewport cache lifetime.
- All **37 historical earned campaign/arena exports** match their existing raw
  receipts, decode under the current save code and match a control through 120
  continuation steps each. This authenticates old earned contexts; the new CPU
  continuations are synthetic invariants, not newly earned progression or graphics
  evidence. No new whole campaign was run to replace a save.
- 108 seven-profile real engine input checks verify transformed touch, release/stop,
  Pause/Resume, Back, full context retention, usable controller rectangles,
  uniform scaling within integer viewport rounding, native text focus/typing,
  invalid import, valid import, fresh observation epochs and cold paused restore.
- Retained successful unchanged-game checks: 57 legacy rules/faults, 81 campaign/
  migration, 8 import rejection, 18 actual-input legacy purchase/defeat/Retry/win,
  32 headless Unicode/transfer and 31 prior save-boundary regressions. These ran
  against the graphics implementation. Subsequent final edits affect scenery/
  ending presentation only; the final focused presentation/input/earned-context
  invocations are separately bound in the evidence index.
- Normalized source comparison proves `engine.gd`, `rules.gd`,
  `campaign_rules.gd`, `campaign_data.gd`, `save_store.gd`, `save_files.gd`,
  export configuration and `progress.json` equal the assigned baseline. Exact
  equations, RNG/tick order, schemas/definitions, package, signing configuration,
  offline/no-ads/no-purchases/no-accounts/no-waits contract are unchanged.

No result above proves rendered appeal, native Android dispatch/IME, OS clipboard,
physical touch/folding, FPS, audio, heat, pacing or fun. Landscape here is a CPU
window dimension; Android retains the explicit portrait orientation policy.

## Retained failures and limits

All failures remain under ignored `.artifacts`; none is silently promoted to a
pass. The index distinguishes initial GDScript typing/import errors, an inspection
SceneTree callback signature error, the first noncanonical exporter differences,
the one-call stale gate visual, early input assertions that sampled before the
queued release was delivered, integer viewport rounding, and an incorrect expected
historical-export count (actual37, all37 authenticated/equivalent).

The CPU short-inspection preparation passes import, script parsing, historical
receipt authentication and source freeze. **It has never executed a renderer.**
There are no new screenshots, movies, timing intervals, APKs, native update claims
or independent Astra visual acceptance from this checkpoint.

## Concrete next action for root

Grant one short frozen rendered inspection before long footage. From this game
directory, after that explicit grant:

```powershell
python -B tests/run_inspection.py --checkpoint stage-00-start --seconds 8 --execute --native-frames
```

The default without `--execute` performs CPU preparation only. It authenticates
the existing earned packet/index, imports/parses before freezing all source,
preserves a copy of the input and executed sources, and checks drift afterwards.
The actual window **and** image framebuffer must be720x1280; full PNGs are retained.
Fixed30 cadence is for inspection and establishes no performance measurement.
There is no lifecycle bypass or automatic Resume after a genuine focus pause.

Inspect original frames for lighting/skin/pose, hand-to-eye chain continuity,
actual contact/recovery, HUD/safe-area composition and scenic occlusion. Correct
real findings, then source-bind normal1x opening/heavy/later and all-used-role/
island/legacy/arena/ending observations. Existing earned stage and wave snapshots
are available; `stage-11-wave-5` includes the final encounter. Prepare separate
true unpaced host timing with explicit opt-in VSync/cap disabling/readback, raw
intervals/hardware/draw/primitive metrics, drops and eligibility. Fixed movies
cannot substitute for that timing.

Root's independent Astra motion review, genuine signed4-to5 install-over update,
full saved-context/native controls/transfer/lifecycle/layout validation and private
before/after bundle remain mandatory. Only at actual candidate freeze should all
current metadata become **0.3.0/code5**. Project/export/progress still identify the
retained **0.2.2/code4 functional baseline**; do not export this CPU review checkpoint
as a new release. Additional physical-phone testing remains user-deferred and
does not block continued graphics work. Do not mark release ready from this file.

## First rendered pass (2026-10-21)

The first render was blown out to white. Cause: in the Compatibility renderer a
shadow-casting DirectionalLight3D is drawn in a second additive pass whose result
is summed after sRGB encoding/tonemapping. Measured on a bare test scene: ambient
alone 0.518, sun alone 0.424, shadows off 0.651 (correct linear sum), shadows on
0.941 (the encoded values added). With ambient 0.64, sun 1.05 and Filmic, every
lit surface clipped. The GLB materials were correct (no vertex colours, no emission).

Fix (presentation only): linear tonemap, ambient 0.40 and sun 0.30 calibrated for
that display-space sum, orthogonal sun shadows. `kit.gd` grades the neutral GLB
materials by name into a warm tropical palette, with a distinct hue per creature
role and the diver as the only saffron. `island.gd` adds turquoise sea, shallows,
shoreline foam, sand tone patches, shells and dune grass as three MultiMeshes. The
camera is now a perspective follow tilted 50 degrees, with full weapon reach always
inside the narrow axis. Telegraphs, the reach ring and impact bursts are unshaded
translucent decals, and world labels use the HUD face and colours at 3x resolution.
GLBs, manifest and generator are unchanged.
