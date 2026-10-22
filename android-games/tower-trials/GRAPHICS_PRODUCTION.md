# Tower Trials original 3D graphics production

**Status: software candidate, not independently reviewed, not phone tested.**
Desktop-verified only (headless and windowed Godot 4.7.2). No APK was built,
no emulator update from code4 was run and nothing was installed on a device.
Root owns review, integration, export, signing, emulator/native checks and
delivery records (`graphics-overhaul.json`, `delivery.json`, `ROADMAP.md`).

Version 0.4.0 / Android code 5 (was 0.3.1 / code 4). Presentation only: the
rules, catalogs, challenge generator, content and save files are byte-identical
(sha256 before/after below). Input targets, button rectangles, Back policy and
all 2D labels are unchanged.

## What changed on screen

- **Night coast in 3D.** The painted gradient backdrop is replaced by a
  moonlit procedural sky, a sea plane to the horizon, a stone quay, stacked
  weathered headlands with moss caps, a lighthouse with a turning lamp, a row
  of lit cottages, a moon and stars.
- **Rule towers.** Each tower column is a banded stone shaft with buttresses
  and a slate roof with a brass finial. Every rule room is a modeled stone
  room front (plaster panel, pilasters, lintel, sill, iron brackets, mortar
  courses on the sides). Room state is a tint of the same model: open
  (plaster), blocked (grey-blue), selected (warm), claimed (teal),
  collapsed (dark, dropped back and tilted).
- **Lost-chime spirits.** One modeled bell-shaped wisp with a dark face and
  glowing eyes per rule enemy, idle bobbing; dimmed when the room is blocked;
  hidden once the room is claimed or collapsed.
- **Your watch.** Stacked cottage floors (door, lit shuttered windows, bell),
  one per claimed room plus the base, with a teal roof, pennant and lantern.
- **Courier.** Modeled cloaked courier with staff and lantern; follows the
  existing rule-timed flight arc (same `beat / 0.9` curve) with a lean, and
  idles on the watch roof.
- **2D layer.** Numbers, tags, room names, HUD, panels, buttons, overlays and
  menus are drawn exactly as before. Prerequisite and collapse connectors are
  trimmed to the gaps between rooms so they never paint over room fronts.
- **Reduced effects.** Disables spirit bob, courier idle bounce and the
  lighthouse turn (in addition to the existing flight-arc removal).
  Pause, menus, transfer, guide and details freeze all presentation motion.

## Kit

`art/source/build_assets.py` is the complete original generator (helpers and
canonical export adapted from this portfolio's Dead Run generator). Pinned
Blender 4.5.14, background mode, factory startup, two threads, no render:

```powershell
& "C:/projects/active/.game-toolchain/blender/4.5.14/blender-4.5.14-windows-x64/blender.exe" --background --factory-startup --threads 2 --python art/source/build_assets.py
```

11 GLBs: room, tower_column, tower_roof, home_floor, home_roof, courier,
spirit, cliff, lighthouse, cottage, moon. Vertex-coloured; one opaque
`Palette` mesh plus at most one unshaded `Glow` mesh per asset. A second fresh
export to a separate folder (`-- --output=<dir>`) matched 11/11 GLBs
byte-for-byte. `art/manifest.json` records hashes, sizes, triangle counts and
bounds. One Blender unit is 100 design pixels of the 600x1066 board.

## Presentation architecture

`scripts/presentation/tower_view.gd` is a `Node3D` child of `main`.
`main.sync_view()` runs at the start of every `_draw()` and passes a fresh
dictionary (screen, level, state, selection, room rects, blocked reasons,
home stride, courier point, flight fraction, reduced, frozen). It is not a
copy of the game state: `level` and `state` are passed by reference
(`main.gd:114`), and `tower_view.gd` only reads them; it never writes to them
or to the save. Its board is rebuilt only when the level, rects or camera change.

Alignment: a perspective camera (vertical FOV 38, keep height) looks straight
down -Z at the z = 0 plane from the board centre, at the distance that makes
the visible height equal `main.layout()`'s letterboxed board. A camera
perpendicular to a plane maps it affinely to the screen, so room fronts at
z = 0 sit exactly under their 2D labels at any window shape while side
faces show real parallax. Raised objects (courier, spirits, watch floors) are
pulled toward the camera axis by `(D - z) / D` so they project onto their 2D
anchors too.

## Checks

```powershell
python android-games/tower-trials/tools/check.py import
python android-games/tower-trials/tools/check.py rules
python android-games/tower-trials/tools/check.py input
python android-games/tower-trials/tools/check.py rendered
python android-games/tower-trials/tools/graphics_check.py view
python android-games/tower-trials/tools/graphics_check.py clip
```

`tests/graphics_view.gd` (new) uses actual touch input and the
`back_policy.gd` Back path. At five window shapes (600x1066, 480x1040,
960x900, 1600x900, back to 600x1066), before and after a move and after
Back/Journey/Resume, it checks one room model per rule room, spirits equal to
rule enemies per room, claimed/collapsed/selected tints, watch floors equal
claimed rooms + 1, and that projected room fronts, watch roof and courier feet
land within 1.5 px of their 2D anchors. It checks that the courier leaves the
watch mid-flight, the rule resolves through natural updates, first Back
pauses and freezes the presentation, a resize while paused stays aligned,
second Back opens Journey and hides the board, and Resume restores the board
with an identical state. Rendered runs also save frames under
`.artifacts/graphics/rendered/` and require open room fronts to be lit plaster
in the actual frame.

Ending screen (2026-10-22, software candidate, not independently reviewed,
not phone tested): the twelve watches and the courier are now GLB models
(`home_floor`, `home_roof`, a `moon` lantern per watch, `courier`) placed by
`tower_view.gd` `_ending()` on the old 2D slots; the 2D boxes, roofs, lantern
circles and 2D courier were removed from `draw_ending()`. Title, text and the
Explore button are unchanged. Lit lanterns follow `main.ending_lit()`
(rescued profile entries / 3, capped at 12; 36 rescued lights all twelve);
unlit watches are dimmed. `graphics_view.gd` `ending()` checks twelve
watch models with floor/roof/lantern, lit count equal to `ending_lit()`,
courier and one roof within 1.5 px of their 2D anchors, presentation lit
counts 12 and 5, and that leaving restores the board with identical state.
Rendered frames: `.artifacts/graphics/rendered/ending.png` (fresh profile,
all dark) and `ending-lit.png` (lit=12).

`graphics_check.py clip` writes a 60-fixed-fps `--write-movie` capture of the
existing touch-only `tests/challenge_motion.gd` to
`.artifacts/graphics/motion/tower-graphics-challenge.mp4` (480x854, 60 fps,
about 20 s); played at 60 fps it is normal speed. It is not a device FPS
measurement.

## Not done

- Independent visual review; Daniel's visual acceptance.
- Android export, emulator update from code 4 via `scripts/android_upgrade.py`,
  Fold7 install (Daniel).
- Journey and Challenge screens keep their 2D content over the new 3D coast.
  The ending's watches and courier are 3D (above) but that change is not
  independently reviewed or phone tested, and Daniel has not accepted it.
- No measured frame time on device.
- Animated courier encounters (`GRAPHICS-OVERHAUL.md:20,77`) are not
  delivered. The courier is one rigid model that leans during flight and
  bobs while idle (`tower_view.gd:217,272`); it has no rig, poses or
  encounter animation, which the overhaul says bobbing alone does not satisfy.
- The required window shapes cover 1080x2520, inner 1968x2184 and native
  1080x2400 (`GRAPHICS-OVERHAUL.md:86`) are not in `graphics_view.gd:8`
  (which tests 600x1066, 480x1040, 960x900, 1600x900). They belong to the
  root emulator stage.

Code note (no change made): the `view == null` 2D fallback branches in
`main.gd` (lines 638-704) are unreachable, because `main` always creates the
3D view.

## Rule and save files unchanged

sha256 recorded before any edit (09:13Z) and after the final change; identical. `git diff --name-only origin/main` touches none of them.

```
cacac155762576b19d295a4cb98a900bf7f0a4ba418cff35d132b202923eb7e4  catalog_v1.gd
f9e558d173c64f6a37dfa996efc6075c6279f520b968406cb7234cce614aa9e9  catalog_v2.gd
3706f76799c3eccf8a8739d02bd74a226edd274e6cdbd1358f58f97767812071  challenge_v1.gd
a7a15f49be61f36c28e3d5301effa4185cca27871fc7362361ac7b2ba9fae868  content.gd
5432339e42e95e02b14d64871cade704ccbb87f89a5c002412deed797291d950  rules_v1.gd
5db58d5d73e2a8b584d12548dba71c864be0d6302ac2c9f84ca1ca4ad5b6f8f6  rules.gd
67b532124aab977b2fb103c12d05a9a9152f6d9aee93113b8476796f880859db  save_files.gd
75fbf10cc8e8276237007593e08ac6b8706fc5a3ce78c4ea3ab30a4f7489080b  save_store.gd
d06a857d45adf9e8f04deffa484c2e95497b489cb08ba591b684386ad9bd6867  prepared_cases.gd
```
