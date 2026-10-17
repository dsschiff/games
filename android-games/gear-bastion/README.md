# Gear Bastion

An original offline Godot 4.7.2 prototype: connect a powered gear foundry while brass automata emerge through a three-exit wall and fight beetle raiders above it. This checkpoint contains one approximately 80-second, three-wave tutorial encounter. It is ready for independent prototype review, not a complete campaign or a phone-tested release.

## Play

- Drag a drive, guard generator or ranger generator from the bottom tray into an empty socket. Brass costs are shown on the tray; defeated raiders return one brass each.
- Drag installed pieces to rearrange the network during battle. A generator disconnected from the gold core reads **OFF** and stops producing. Invalid, outside and cancelled drops retain its old position.
- Drive gears raise only orthogonally adjacent powered generators by 25% per drive level, capped at 3x. The green links show connectivity. A chain transmits power; its speed modifiers do not multiply along the path.
- Drop equal drive gears together to merge them up to level 4. **Undo move** restores the previous move or merge; purchases spend resources and clear this undo slot.
- Tap a troop generator, then an exit button to choose its future troops' gate. Guards absorb damage; rangers pierce shell armor. Gates and allocation are original design choices.
- Tap **Begin defense**. The board remains interactive as the army fights. Protect the wall through all three waves; **Retry now** immediately resets a finished attempt.
- Pause, 2x speed, mute and reduced effects are available. The save menu exposes versioned portable JSON and validates imports before replacement. Saves also persist automatically and resume an active battle paused.

## Rules and presentation

`scripts/gear_rules.gd` owns flood-fill connectivity, deterministic rates, purchases and transactional moves/merges. `scripts/battle_rules.gd` owns fixed-step seeded production, gate spawning, enemy counters, targeting and wall damage. `scripts/save_store.gd` owns versioned validation, atomic replacement, backup recovery and v1 migration. Drawing/input live in `scripts/main.gd`.

There is a 120-troop cap and a 90-raider bound. At cap each generator buffers at most one reinforcement; changing its exit still affects its next spawn. The idle army disperses into a holding formation. All art is original procedural/vector drawing; the short action/outcome tones are synthesized locally. No network permissions, ads, purchases, accounts or paid assets are used.

Portrait canvas: 600 x 1066, preserved with centered letterboxing on other aspect ratios. Board sockets and menu hit areas are at least 80 logical pixels (48 dp if presented 360 dp wide). Galaxy Z Fold7 working profiles are 1080 x 2520 cover and 1968 x 2184 unfolded. Desktop tests resize the live battle to both dimensions and exercise gear input after each resize. Those tests do not establish Android fold lifecycle, physical safe areas, readable on-device text, or touch accuracy.

## Verify and build

Run the coordinator's shared `scripts/portfolio.py test gear-bastion` and `build gear-bastion` after integration. Both suites print `SUITE_COMPLETE: PASS` only at their successful end and exit nonzero on failure. For direct local use, set child `APPDATA`, `LOCALAPPDATA`, `TEMP` and `TMP` to writable local artifact/runtime directories, then run:

```powershell
$godot = 'C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path android-games/gear-bastion --editor --import --quit
& $godot --headless --path android-games/gear-bastion -s tests/run_tests.gd
& $godot --headless --path android-games/gear-bastion --audio-driver Dummy -s tests/playthrough.gd
& $godot --path android-games/gear-bastion --audio-driver Dummy --resolution 600x1066 -s tests/playthrough.gd
```

The rendered playthrough creates ignored PNGs and `report.json` in the game's `.artifacts/playthrough/`; headless reports go in its `headless/` subdirectory. Inputs use `Input.parse_input_event`; only simulation time is accelerated. The UI save import test uses keyboard events because this restricted desktop session cannot open the Windows clipboard. Clipboard convenience buttons are implemented but not verified here.

Android uses the unmodified official template, non-Gradle export, package `com.dsschiff.gearbastion`, min SDK 24, actual template target SDK 36, arm64-v8a and x86_64. There is deliberately no `gradle_build/target_sdk` override. No binary template patcher or custom template is part of this project.

## Review packet and remaining work

Read `WORKLOG.md` and `progress.json` for exact checks and local artifact paths. Useful rendered frames: `03a-first-clash`, `03-battle-first-layout`, `05-battle-second-layout`, `06-failing-strategy`, `07-repaired-victory`, `08-defeat`, and `03-aspect-*`.

The design follows the observed split portrait composition and connected-board → real production → visible army → wall-defense loop in [the source brief](../references/gear-defenders.md). The numeric equation, direct merge/undo, resource prices, troop designs and gate allocation are original rules. The primitive art, tutorial pacing, army abundance and late-game fidelity have not been accepted by an independent review.

Next gate: coordinator/Astra prototype review before campaign expansion. The three-region campaign, 30–60-minute progression, constrained boards, strategic unlocks, additional distinct roles, bosses, seeded challenge/replay and final sound/animation polish remain unfinished. Android launch, background/resume, interrupted Android write recovery, real APK update preservation, physical Fold7 transitions, clipboard/keyboard behavior and measured phone performance also remain pending. Corrupt-save and prior-version tests are injected fixtures, distinct from the app-owned save/reload input test.
