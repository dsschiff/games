# Tower Trials original 3D graphics production

**Status: software candidate with a 2026-10-22 polish pass, not independently reviewed, not phone tested.**
Desktop-verified only (headless and windowed Godot 4.7.2). No APK was built,
no emulator update from code4 was run and nothing was installed on a device.
Root owns review, integration, export, signing, emulator/native checks and
delivery records (`graphics-overhaul.json`, `delivery.json`, `ROADMAP.md`).

Version 0.4.0 / Android code 5 (was 0.3.1 / code 4). Presentation only: the
rules, catalogs, challenge generator, content and save files are byte-identical
(sha256 before/after below). Input targets, button rectangles, Back policy and
all 2D labels are unchanged.

## Polish pass (2026-10-22, branch claude/tower-polish)

Judged against the user's Top Force still and the finished Frontline, Hook and
Dead Run previews, the first candidate was weak: room fronts rendered as flat,
clipped-white plaster panels (the compatibility renderer's post-sRGB shadowed
light pass, same trap as Hook); spirits were small pale wisps under 2D numbers;
the courier was one rigid model sliding along an arc; nothing marked a hit, a
gain or a claim; all four chapters used the same night coast; the ending was 2D.

- **Dimensional chambers.** Every rule room is now an open diorama: plank floor,
  wainscot and plaster back wall, arched windows, sconces, ceiling joists, stone
  pilasters, lintel and keystone. Stone bands above and below close the gaps
  between floors; stretches of a column without a chamber are flush ashlar
  masonry with lit slits (`tower_segment`), so towers read as solid buildings.
- **Lighting.** Ambient .42 and a .34 shadowed key light with a linear tonemap
  (Hook's calibrated values). Plaster now measures about 0.65 luminance instead
  of clipping; the rendered test fails any open chamber that clips to white.
- **Three enemy classes** by strength: chime wisp (1-9), armoured chime knight
  (10-99), crystal-cored golem (100+). They stand on the chamber floor, bob,
  and face the courier. Rescue/keeper rooms show a caged lantern keeper; the
  cage lifts on claim and the keeper hops during the rescue celebration.
- **Animated courier encounters.** The courier is a jointed rig (body, two
  legs, staff arm; procedural run, leap, strike, recoil, absorb and slump
  poses). Inside main's existing 0.9 s rule beat it leaps from the watch into
  the chamber (first 30%), then for each step of the rule's order (trap or
  shield first, then enemies left to right) steps up, winds up and slams the
  lantern staff. Defeated enemies topple back and dissolve; a losing strike
  shakes the enemy and knocks the courier back. The last 16% is absorption:
  staff raised while gold light orbs fly from each defeated enemy into it.
- **Hit and gain feedback.** Spark bursts and shock rings at each impact;
  floating `+N` per enemy, `TRAP -N`, `SHIELD`, `TOO STRONG` / `EQUAL LOSES`;
  on resolution a big `+gain` pops over the chamber, the HUD power box flashes
  with its own `+gain`, and teal light streams from the chamber to the watch.
- **Visible tower growth.** The new watch floor springs up with an elastic
  rise after the light arrives, the roof rides up with it and bursts; the
  courier leaps home. Winning a watch adds a keeper-rescued fireworks burst.
  Your watch is a timber-framed, lit-window tower that visibly towers over the
  quay by the late chapters.
- **Readable numbers.** Enemy strengths are 2D badges (dark plate, gold rim,
  outlined white numeral) above each enemy's head; tags sit in a dark pill;
  claimed rooms show a teal CLAIMED pill and a hanging courier banner;
  selection adds a second gold outline.
- **Chapter environments.** Lantern Coast (moonlit night, lighthouse, village),
  Salt Archives (amber dusk, low sun, stepped sandstone archive stacks), Glass
  March (misty teal dawn, glass shard clusters), Last Meridian (violet night,
  gold horizon, great clock ring, drifting aurora). Tower stone and rocks take
  each chapter's tint. Seeded Challenges map family to chapter look.
- **3D ending.** Twelve answering watches on the quay, the clock ring behind,
  lanterns rising continuously and the courier with staff raised in front.
- **Window shapes.** The board stays a uniform letterboxed fit; the 3D world
  extends to fill cover 1080x2520, inner 1968x2184, native 1080x2400 and
  landscape (more sky, sea, cliffs and village; nothing stretches). These five
  shapes are now in `tests/graphics_view.gd`.

Input and rules are unchanged. The fight plays only inside the existing
pending window that main already used (and that already blocked room taps
and Undo for 0.9 s); its timing is untouched. Everything after resolution
(pops, light stream, floor growth, return leap, celebration) runs on the
view's own clock: Undo, Retry, Back and the next room tap work immediately,
and a new move just starts from the watch anchor. Back/pause freezes all of
it. Reduced effects keeps the courier on the watch, drops sparks, orbs,
shake, bob and the elastic growth, and keeps the number pops and HUD flash.
`main.courier_point()` is now the resting anchor only; the 2D in-flight arc
and `+POWER/CLASH` text were removed in favour of the 3D encounter.

## What changed on screen (first candidate, 0.4.0)


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

Polish-pass results (desktop Godot 4.7.2, not a phone): rules 3503/0,
input 1173/0, rendered campaign 1217/0 (two earlier rendered runs stopped
mid-campaign when the test window lost focus and main's existing focus-out
pause froze a move; the third and a final run on the finished code passed unattended), graphics view 252/0
headless and 289/0 rendered across eight shapes, challenge motion clip 48/0,
tour 50/0. Before/after contact sheets:
`C:/projects/active/games/.artifacts/releases/graphics-20261021/previews/tower-before.png`
and `tower-after.png` (opening, strike, absorb, claim pop, mid-chapter
Salt Archives, late Last Meridian, tall watch before the final rescue, ending).

## Kit

`art/source/build_assets.py` is the complete original generator (helpers and
canonical export adapted from this portfolio's Dead Run generator). Pinned
Blender 4.5.14, background mode, factory startup, two threads, no render:

```powershell
& "C:/projects/active/.game-toolchain/blender/4.5.14/blender-4.5.14-windows-x64/blender.exe" --background --factory-startup --threads 2 --python art/source/build_assets.py
```

22 GLBs: room, tower_column, tower_segment, tower_roof, home_floor,
home_roof, courier_body, courier_leg, courier_arm, spirit, spirit_knight,
spirit_golem, banner, keeper, cage, cliff, lighthouse, cottage, archive,
crystal, meridian, moon (the single rigid `courier` was replaced by the three
rig parts). Vertex-coloured; one opaque `Palette` mesh plus at most one
unshaded `Glow` mesh per asset. A second fresh export of the polish kit to a
separate folder (`-- --output=<dir>`) matched 22/22 GLBs byte-for-byte. `art/manifest.json` records hashes, sizes, triangle counts and
bounds. One Blender unit is 100 design pixels of the 600x1066 board.

## Presentation architecture

`scripts/presentation/tower_view.gd` is a `Node3D` child of `main`.
`main.sync_view()` runs at the start of every `_draw()` and passes a fresh
dictionary (screen, level, state, selection, room rects, blocked reasons,
home stride, courier anchor, flight fraction, pending room and forecast
win, chapter, reduced, frozen). It is not a
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
python android-games/tower-trials/tools/graphics_check.py tour --label after --size 720x1280
```

`tests/graphics_tour.gd` (polish pass) seeds progress through the app's own
save format, then plays by touch: the opening watch with a frame-by-frame
encounter (walk, arrive, strike, fall, absorb, claim pop, settled), the
richest key/bridge/trap board in chapters 2-3, a late chapter, the tall
watch before and during the final rescue, and the ending. Frames go to
`.artifacts/graphics/tour/<label>/`.

`tests/graphics_view.gd` (new) uses actual touch input and the
`back_policy.gd` Back path. At eight window shapes (600x1066, 480x1040,
cover 1080x2520, inner 1968x2184, native 1080x2400, 960x900, 1600x900, back
to 600x1066), before and after a move and after
Back/Journey/Resume, it checks one room model per rule room, spirits equal to
rule enemies per room, claimed/collapsed/selected tints, watch floors equal
claimed rooms + 1, and that projected room fronts, watch roof and courier rest
anchor land within 1.5 px of their 2D anchors. It checks that the courier
leaves the watch mid-move and fights inside the chosen chamber, that Undo is
offered the moment the rule resolves, that post-move animation settles within
1.5 s with the courier back on its anchor, the rule resolves through natural updates, first Back
pauses and freezes the presentation, a resize while paused stays aligned,
second Back opens Journey and hides the board, and Resume restores the board
with an identical state. Rendered runs also save frames under
`.artifacts/graphics/rendered/` and require every open chamber to render as a
lit, unclipped interior in the actual frame (at least 9 of 35 probes above
0.45 luminance, at most 3 pure white).

`graphics_check.py clip` writes a 60-fixed-fps `--write-movie` capture of the
existing touch-only `tests/challenge_motion.gd` to
`.artifacts/graphics/motion/tower-graphics-challenge.mp4` (480x854, 60 fps,
about 20 s); played at 60 fps it is normal speed. It is not a device FPS
measurement.

## Not done

- Independent visual review; Daniel's visual acceptance.
- Android export, emulator update from code 4 via `scripts/android_upgrade.py`,
  Fold7 install (Daniel).
- Journey and Challenge menus keep their 2D panels over the chapter's 3D
  backdrop (by design: they are lists).
- No measured frame time on device. Effects are pooled (64 sparks, 8 rings,
  40 orbs, 34 ending lanterns); nothing is allocated per hit.
- The courier rig is procedural posing of rigid parts (no skinned mesh); at
  phone size it reads as running, striking and recoiling, but there is no
  squash or cloth. Fights with four or five steps get about 0.1 s per strike
  because the existing 0.9 s rule beat was deliberately not lengthened.
- After a move the selected room stays selected, so the forecast panel reads
  "ROUTE CLOSED / Already claimed" until the next tap. That is existing main
  input behaviour, left unchanged here; worth a separate input decision.
- Landscape/emulator validation of the new shapes on a device remains with
  the root emulator stage.

Code note (no change made): the `view == null` 2D fallback branches in
`main.gd` (lines 638-704) are unreachable, because `main` always creates the
3D view.

## Rule and save files unchanged

sha256 recorded before any edit (09:13Z) and after the final change; identical. `git diff --name-only origin/main` touches none of them.
Polish pass: recomputed on LF-normalized bytes before the first edit and after the last (2026-10-22); all nine identical to the values below, and `git diff --name-only origin/main` still touches none of them.

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
