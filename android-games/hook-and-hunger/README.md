# Hook and Hunger

An original offline, portrait 3D salvage-diver action game. **First appeal slice, not the complete campaign.** Godot 4.7.2 / GDScript; no third-party assets, services or permissions.

Drag the floating stick to move (mouse drag or WASD on desktop). The anchor launches toward the nearest visible creature in reach; damage happens at chain contact, not launch. Move out of red windup circles and use rocks for cover. Walk through gold salvage drops. Clear the shoal, return to the mint forge and press its purchase button: 36 salvage buys the visibly larger Tidecutter, increases power 100→200, damage 12→32, reach 2.5→3.6, adds cleave, and restores hull to 100. Cross the opened gate and defeat the Bellkeeper. Pause contains settings and local save export/import.

Retry retains the bought weapon, wallet, defeated enemy IDs, collected reward IDs and remaining drops. Surviving enemies restore their starting health/position; each fixed enemy can award exactly one reward. The dock is safe. The first pen has 42 total salvage against a 36 purchase cost, so no repeated farming or waiting is required.

`scripts/rules.gd` contains deterministic combat/economy independent of rendering. Original geometry, crystal creatures, diver, chain links and anchor silhouettes are generated in `scripts/art.gd`; short original tones are synthesized locally. Alternating checked save slots recover interrupted normal writes while keeping the newest valid candidate untouched; an uncommitted failed import cannot activate on restart.

Run from this isolated checkout with the pinned portable executable:

```powershell
$game = 'C:/projects/active/_worktrees/games-hook-and-hunger-20261018/android-games/hook-and-hunger'
$godot = 'C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$env:APPDATA = "$game/.artifacts/manual-userdata"
& $godot --headless --editor --path $game --import --quit
& $godot --headless --path $game --script tests/run_tests.gd
& $godot --headless --fixed-fps 60 --path $game --script tests/playthrough.gd
& $godot --path $game
```

`tests/playthrough.gd` clears saves in its **isolated test APPDATA** before starting. Never point this test at a player's save directory. It drives real engine touch events and GUI mouse clicks, rather than mutating game state. `-- --capture-dir=<existing absolute directory>` writes raw input events, checked state snapshots and rendered PNGs. Add `--write-movie <ignored path.avi> --fixed-fps 60` before the script argument for deterministic motion. Fixed-rate movie capture is not a phone FPS measurement.

See `evidence/appeal-checkpoint.json` for exact final artifacts and source hashes. Android export, independent appeal/fidelity review, campaign expansion, different-version update, and physical Fold7 touch/fold/sound/performance remain outstanding. The coordinator owns Android/shared tooling and review integration; this directory owns the game only.

The selected source baseline is movement → visible extending chained weapon/contact → resources → weapon/power purchase with health recovery → stronger gated encounters. Our contextual targeting and exact numbers are original control/economy choices. Reeling, consumption, permanent player body enlargement and manual twin-stick aiming are not asserted as reference behavior or implemented requirements.
