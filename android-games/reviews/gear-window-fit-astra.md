# Gear Bastion 0.3.3/code7 window-fit review

2026-10-18. Read-only source, evidence-file and saved-image review of `C:/projects/active/_worktrees/games-gear-bastion-20261017/android-games/gear-bastion`. No runtime, rendering, GPU, ADB, browser, clipboard or device operations by this reviewer. No tracked/game files changed.

**Disposition: desktop window-fit candidate supported; no new P1/P2 blocker found in this bounded delta.** Proceed to the coordinator's already planned signed code6→7 update and native/cover/inner emulator input checks. Those checks are pending, and this review does not accept the six-game 3D overhaul or establish physical-phone performance/usability.

## Source and artifact pin

Worker HEAD during review was `501f6dcd36b31f1236556e141350ad2430f9d33d`; the layout delta was uncommitted while the worker finished documentation. The inspected game source remained stable across beginning/end checks. Reviewer inventory SHA256: `9aa887fa814ea4b5c88dc86391389f5c7f8339b67bbda16b2edd957145fd5dc4`. This hash covers a sorted compact JSON dictionary of relative paths → raw SHA256 for all non-hidden `.gd`, `.godot`, `.cfg` and README.md files under the game. It is not a whole-project/build fingerprint and deliberately excludes ignored outputs and later checkpoint records.

Independently verified **all 18 LF-normalized source bindings and all 140 PNG hashes** in `evidence/window-fit.json`; zero mismatches. Evidence JSON SHA256: `16a2d4331fc0f425c796a9269144e469518cb8b93ac517eefd38f86c331c5bf7`.

- Main: `26d1e0a218b3e5020bda6768ac95134ad14a72050b59176f4787211d1e8bc6d4`.
- Layout: `6d7a4a3002ab09cec610be95eb120d4d38360628de9788f038e5743cf776229b`.
- Campaign view: `28efc54b388964debbea91661b9c3f0b67be0180e5b711ba1f8e4a06375c288e`.
- Campaign UI: `bf3314722545e40ad41bd594074c5a84b21db3bb3df65d5e5e6896492a5f7e8b`.
- Rendered report: `e411ce2d919dee18e78861c56067e0646f91af9a81ebf7510d23315ca3e4ca94`.
- Headless report: `cb72da65434528f5b016f83602f4b826dc4711b19ec6406d2bafac05ceac88a8`.

Final pin independently rechecked after worker commit: **`45baca53cf6b422db98813a92a2be05198aa9f0b`**, clean `git status`. The source inventory and evidence JSON hashes above are unchanged and all 18 source bindings still match. Coordinator reports integration as `33ab8d7`; this reviewer did not independently inspect that integration. Android export/update validation remains pending separately.

## Findings

The change addresses the identified cause rather than merely filling old letterbox gutters. Project aspect changes from `keep` to `expand`, with sensor orientation enabled. `window_layout.gd` computes battlefield, wall, board, tray and controls from available size. The cover gains battlefield height; wide layouts put shop/tools on opposite sides of the board. Circular gears and character textures retain their shape; actor positions/projectiles share the expanded field mapping while authoritative battle coordinates remain fixed.

Drawing and interaction share the same board/control geometry. `main.gd` places/scales the root uniformly inside the usable rectangle and converts incoming viewport positions with `to_local()` once. `cell_center/cell_at` remain inverse in layout coordinates. Resize cancels drag ownership, clears drag state and sets an out-of-bounds drag start, preventing the stale release from moving/buying a piece. The source and focused checks support state-preserving resize; runtime game state is not resized or rescaled.

Safe-area computation maps Android display coordinates through the viewport screen-transform inverse, then intersects with the viewport. This actual Android branch has not been exercised by the desktop synthetic-inset checks. The planned native checks are the appropriate next confirmation. The root's uniform fallback scale below its normal minimum avoids shape distortion; tested logical layouts keep the board and controls in bounds. No unsupported claim about physical 48-dp targets follows from logical-pixel assertions alone.

Embedded dialogs are fitted to the usable rectangle before and after popup and when a visible dialog survives resize. Scroll containers, narrower content minima and theme-level Close-button minima remove the prior fixed-width assumptions. Existing Back precedence remains transfer → guide → menu → confirmation → game pause/map, with runtime quit-on-back disabled as before. Desktop Escape/GUI dismissal evidence is separate from native Android Back.

Independently compared six authoritative modules against `6e26b3c`: `battle_rules.gd`, `gear_rules.gd`, `save_store.gd`, `save_files.gd`, `campaign_profile.gd`, and `campaign_data.gd` are **LF-identical**. Reviewed `main.gd` diff changes layout/input coordinate conversion and dialog plumbing without changing tick scheduling, purchase/move costs, profile awards, save schema or import acceptance. Legacy drawing is consolidated through the adaptive campaign view and has dedicated input/geometry checks. Existing visual assets are retained; this is the window-fit checkpoint preceding 3D asset work.

## Direct visual inspection

Viewed these original saved PNGs under `.artifacts/window-fit/rendered/`:

- `1080x2520-battle.png`: battlefield fills tall available space; full board/tray, three exits, status and controls visible.
- `1968x2184-battle.png`: expanded battlefield, centered full board and flanking controls; no old fixed-width pillarbox region or stretched gear silhouettes.
- `2184x1968-save.png`: complete transfer window, readable code, Copy/Paste/Import and Close within view.
- `1080x2520-map.png`: all nine mission cards and bottom navigation visible. This image retains the test's synthetic safe-area override even though its filename lacks `safe`; its outer margins are not evidence of old aspect letterboxing.
- `1968x2184-safe-defeat-fixture.png` and `2184x1968-safe-victory-fixture.png`: terminal panels and Retry/Next fit alongside board/tools within synthetic safe insets.

No visual clipping/overlap blocker found in this sample. Only these six images were visually inspected; hashing all 140 images is not a claim to have viewed all of them. Crowd animation/3D quality and dense live boss play are outside this narrow window-fit review.

## Verification scope and limits

Read both final reports and `.artifacts/window-fit-runtime/final-cpu.log`: each final run reports **9,893 checks, 1,169 injected input events, zero failures**. Read rules log: **164 checks, zero failures**. These are verified worker artifacts, not newly rerun reviewer suites. Original `input-expanded.log` remains present with **9,830 checks / 21 failures / 1,169 events** and `FAIL`; it is retained failed history, not averaged into or relabeled as the final pass.

Test source confirms real Input.parse_input_event tray drags, refit, move/Undo, exit changes, Begin, modal opening/Close/Escape, invalid/valid Import button activation, and post-resize movement. The exercise uses fresh injected state fixtures and explicitly advances simulation by eight seconds with `game.advance(8)`; it is genuine input-driven geometry/control evidence with simulated battle progression, **not a continuous real-time play session**. Text is assigned directly for import tests; no clipboard/IME test is claimed. Terminal fixtures are generated with rules/policy and assigned to the UI for drawing/Retry checks; they are not newly earned UI-driven wins/losses. Map/challenge/ending views are selected directly for layout inspection, not earned-progression evidence.

Seven window sizes and synthetic insets are covered, including cover, inner, landscape and intermediate shapes. Existing progress/settings/content preservation is checked through whole serialized context comparisons around resize/export/import. Installed-phone APK version remains unknown; nothing here establishes that Daniel's prior installed build was code6. Native signed6→7 update retention, Android safe-area mapping/Back/input and emulator geometry remain pending coordinator work. No whole-campaign rerun or extra physical-phone gate is added.
