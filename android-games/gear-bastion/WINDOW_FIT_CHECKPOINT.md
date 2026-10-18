# Gear Bastion 0.3.3 / code 7: window fit

Desktop fit checkpoint, 2026-10-18, based on landed `501f6dcd36b31f1236556e141350ad2430f9d33d`. This is the bounded sizing correction before the approved original 3D overhaul. No 3D assets, gameplay rules, encounter definitions, economy, save schema, package identity or signing configuration changed.

`window_layout.gd` derives the field, three exits, five-by-four board and controls from the safe usable viewport. `canvas_items/expand` supplies additional logical width/height. Tall windows increase battlefield depth. Wide windows place utilities left of the board and the shop right; the field and wall span the width. Actor positions map from simulation space while actor art, circular gears and board cells retain their proportions. Campaign, Practice and Iron Trial use the same layout and renderer. Journey, trials and ending navigation adapt to the viewport.

The root canvas reserves Android safe insets using the inverse screen transform. Touch/mouse events already receive Godot's viewport conversion, then pass once through the canvas's inverse local transform. Resize cancels an in-flight gesture without modifying the saved run. Visible modals refit; menu, guide and transfer content can scroll. Actual dialog confirmation buttons use `AcceptDialog` theme minima because Godot overrides direct button minima during layout. Sensor orientation allows landscape/resizable windows.

## Verified

- Existing rules/save suite: **164 checks, zero failures**. Existing tutorial/Iron Trial actual-input suite with its utility-menu helper adapted to the new UI: **57 checks, 368 pointer events, zero failures**. No unchanged full nine-encounter campaign rerun was performed.
- Focused `tests/window_fit.gd`: **9,893 checks, 1,169 input events, zero failures**, separately in CPU headless and Windows rendered Compatibility runs. Both ended with `SUITE_COMPLETE: PASS` and exit 0; final logs contain no script/engine errors.
- Actual window profiles: **1080×2520, 1968×2184, 1080×2400, 2184×1968, 1200×1600, 900×1300, 600×1066**, plus transposed live resizes and synthetic safe insets. Checks cover physical viewport fill, disjoint/reachable targets, all 20 socket inverse mappings, actual tray purchase/move/Undo/refit/exit selection, populated live fields, Back and actual Close, portable export and valid/invalid Import buttons, open-transfer resize, and whole-save equality across cancelled gestures and move/Undo after resize.
- Two first-encounter terminal rule fixtures are computed once and reused for terminal geometry/captures and actual Retry input. They are labeled fixtures, not earned device results. Ready captures intentionally use paused ready fixtures; this makes the pause overlay visible. Map/trials/ending screens are drawing/navigation fixtures without fabricated progression.
- **140 rendered PNGs** and reports are in `.artifacts/window-fit/`; hashes and text-LF source bindings are in `evidence/window-fit.json`. The rendered host reports NVIDIA GeForce RTX 5070 Ti / driver 610.88; this does not measure phone performance. The worker directly inspected cover/inner/landscape battle, transfer, legacy guide, map, ending and terminal captures. Coordinator independently viewed cover/inner battle and landscape transfer during the checkpoint.

## Executable smoke

Use isolated child `APPDATA`, `LOCALAPPDATA`, `TEMP` and `TMP` directories under the game's ignored `.artifacts/`. Commands run from the repository worktree:

```powershell
$godot = 'C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path android-games/gear-bastion --audio-driver Dummy -s tests/window_fit.gd
# Rendered command requires the coordinator's exclusive GPU slot:
& $godot --path android-games/gear-bastion --audio-driver Dummy --resolution 600x1066 -s tests/window_fit.gd
```

The script exits itself, writes separate headless/rendered reports and captures only in rendered mode. It does not use ADB, Android exports or clipboard. Normal simulation time is advanced explicitly; this is input/layout evidence, not a real-time pacing or performance measurement.

## Retained failures and limits

Earlier failed logs remain in `.artifacts/window-fit-runtime/`: initial test type mismatch, 179 overlap/missing-menu-helper failures, 21 strict numeric-comparison observer failures, then a separate 21-failure floating-time observer plus hidden-popup-position diagnostic. Production fixes removed the six-pixel gate/utility overlap and fit hidden dialogs before popup; the observers were corrected without changing rules. The earlier successful rendered pass had undersized native Close buttons; its log and one original capture remain in `.artifacts/window-fit-before-dialog-theme/`. The final theme-minimum regression is included in both 9,893-check passes. Initial UTF-8/newline editing errors were corrected before validation; those tool outputs are not passing evidence.

The worker's rendered processes exited and the GPU slot was explicitly released. No Android build/export/install, 6→7 update, ADB, clipboard, physical phone/folding/safe-area/IME/audio/FPS or human acceptance is claimed. Root owns signed export, actual preserved-save update and native input/resize review. Further phone testing remains deferred. Wait for coordinator review before full 3D work.
