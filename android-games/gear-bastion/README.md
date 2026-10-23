> **Design candidate 0.4.1 / code10 (2026-10-23).** Begin starts combat after
> ready-state Menu, Guide, Save, Home and Pause flows. Returning to an active
> battle still requires Resume. Existing rules, layouts and full earned progress
> are preserved. See `DESIGN_INCREMENT.md`; signed/native delivery is separate.

# Gear Bastion

An original offline Godot 4.7.2 defense game: connect a powered foundry while brass automata emerge from generators, march through three wall arches and fight beetle raiders. Source 0.4.0 / code 8 is an original 3D review candidate that retains nine encounters across three foundries, a mortar role, bosses, medals, an ending and three seeded replays. The [3D production record](GRAPHICS_PRODUCTION.md), [historical motion index](evidence/graphics-motion.json), [pooling/role follow-up](evidence/graphics-pooling.json), and [dense-boss correction](evidence/graphics-boss-visibility.json) cover the original articulated actors, foundry scenery, responsive controls and genuine-save captures. Independent eight-category motion review, the coordinator’s signed update checks and physical-phone acceptance remain open. Earlier [decision-pressure evidence](DECISION_PRESSURE_CHECKPOINT.md) is retained separately.

## Campaign

Start on the journey map. Clear a gate to unlock the next; no grind or account is needed. Campaign budgets are fixed, with wave salvage in Furnace Tide. Place gears before Begin, then adjust power, roles and exits during combat. Tap a troop gear and a numbered wall arch to change future troops' exit. Guards screen fire, rangers give efficient single-target damage, and mortars clear dense packs. Refit previews the next role and price difference; existing troops keep their role. Equal drives merge immediately; Undo restores the last move or merge.

Preparation provides the board and shop. Combat keeps both live beneath the modeled battlefield. The Menu contains speed, sound, calm effects, guide and save/export. Back closes a modal, pauses battle, then returns to the map. Cleared gates and medals are separate from the active run. Save schema 4 retains pinned encounter content and accepts older schema 1–3 saves; portable `GB4:` codes include the profile and active run.

The primary `tests/playthrough.gd` exercises the full nine-gate campaign, all nine weak-choice/Retry-correction pairs, all three reduced-budget seeded replay wins, normal save/reload, typed desktop import, Back/menu behavior and guarded Practice replacement. The earlier tutorial/Iron Trial suite remains `tests/legacy_playthrough.gd`. Rules, rendered actor atlas checks, natural-terminal rendering and policy probes are separate. The [earlier visual checkpoint](CAMPAIGN_CHECKPOINT.md) is retained as historical code 5 evidence.

## Earlier tutorial and Iron Trial

The controls and trial evidence below describe the retained practice mode and earlier release.

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

There is a 120-troop cap and a 90-raider bound. At cap each generator buffers at most one reinforcement. Only currently powered generators dispatch; stable-ID round-robin turns prevent board order from starving later roles. The next eligible role is visible while the army is full, and the turn survives saving. Changing an exit still affects its next spawn. The idle army disperses into a holding formation. Actors and props use original Blender-authored meshes with actual skinned joint animation; the compact HUD and controls use 2D drawing. The short action/outcome tones are synthesized locally. No network permissions, ads, purchases, accounts or paid assets are used.

## Iron Trial

Select **Iron Trial** before battle. Its restricted sockets, fixed 54-brass budget, 160-health wall and lack of kill income make the kit consequential. Guards screen long-range spitters; rangers pierce the later carapaces, which shrug off 96% of guard damage and cleave nearby troops. Tap a troop generator, then **Refit** to switch its future production: guard to ranger costs the two-brass price difference, and the reverse refunds two. Connectivity and existing troops remain intact.

The following actual-input cases are verified at the fixed encounter seed 1701; they are not a broad campaign balance study:

| Plan | Spend | Result | Simulated time |
| --- | ---: | --- | ---: |
| Two guards and two rangers, covering both flanks | 52 | Win, wall 160 | 98.17s |
| Three gate-screening guards and one supported ranger | 50 | Win, wall 160 | 91.03s |
| Fully connected four-guard build, higher production than the first winning plan | 48 | Defeat | 65.63s |
| Three unshielded rangers and two extra drives | 54 | Defeat in the opening ranged pressure | 23.17s |
| Four-guard build, refit two generators after visible casualties/armor pressure at 36s | 52 final | Win, wall 160 | 96.47s |

Strategy A is a **curated seed-1701 witness**, not a robust second strategy. The coordinator's independent d13387b probe found A loses seed 1700 at 61.07s and seed 1702 at 51.67s. B and the live-refit plan win all three tested seeds (1700/1701/1702); both single-role builds fail all three. No trial balance was changed in 0.2.1. Nearby-variant and broader policy validation are still campaign gates.

Save schema 3 adds checked write/flush/readback, ordered revisions and a protected backup before replacing an interrupted temporary save. Newer valid recoverable temporary progress wins over an older primary/backup. Failed imports remain unaccepted until primary replacement succeeds. A persistent save-failure warning offers retry/export, and successful saving clears it. Prototype schema-2 saves migrate; the package and user-data location remain unchanged. Fault-injection recovery tests are separate from normal app-written primary save/reload tests.

The 0.2.1 amendment reuses an existing staged `.bak.tmp` when its bytes exactly match the validated prior save. This avoids truncating that file when it is the sole surviving candidate. Focused tests cover ordinary load, a would-be staged-write failure, staged-rename failure and later replacement write/rename failures.

Responsive canvas: `canvas_items/expand` recomposes the battlefield, wall/exits, board and controls from the usable viewport. Tall windows add battlefield depth; windows at least 820 logical pixels wide place utilities left of the five-by-four board and the shop right. Shapes retain uniform scale; simulation positions and saves retain their original meaning. Android safe insets are converted from screen coordinates, and touch/mouse picking converts viewport coordinates into the same local canvas used to draw. Resize cancels stale gestures and refits visible scrollable dialogs. Board sockets and main targets are at least 80 logical pixels at normal minimum size; dialog confirmation buttons use themed 160-by-80 minima. Extremely constrained safe regions shrink uniformly to keep the layout reachable. See [the fit checkpoint](WINDOW_FIT_CHECKPOINT.md) for desktop evidence and remaining Android checks.

## Verify and build

Run the coordinator's shared `scripts/portfolio.py test gear-bastion` and `build gear-bastion` after integration. Both suites print `SUITE_COMPLETE: PASS` only at their successful end and exit nonzero on failure. For direct local use, set child `APPDATA`, `LOCALAPPDATA`, `TEMP` and `TMP` to writable local artifact/runtime directories, then run:

```powershell
$godot = 'C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path android-games/gear-bastion --editor --import --quit
& $godot --headless --path android-games/gear-bastion -s tests/run_tests.gd
& $godot --headless --path android-games/gear-bastion --audio-driver Dummy -s tests/playthrough.gd
& $godot --path android-games/gear-bastion --audio-driver Dummy --resolution 600x1066 -s tests/playthrough.gd
```

The rendered playthrough creates ignored PNGs and `report.json` in the game's `.artifacts/review-playthrough/`; headless reports go in its `headless/` subdirectory. Inputs use `Input.parse_input_event`; only simulation time is accelerated. The UI save import test uses keyboard events because this restricted desktop session cannot open the Windows clipboard. Clipboard convenience buttons are implemented but not verified here.

Android uses the unmodified official template, non-Gradle export, package `com.dsschiff.gearbastion`, min SDK 24, actual template target SDK 36, arm64-v8a and x86_64. There is deliberately no `gradle_build/target_sdk` override. No binary template patcher or custom template is part of this project.

## Review packet and remaining work

Read `WORKLOG.md` and `progress.json` for exact checks and local artifact paths. The review frames include `09-save-failure-visible`, `10-trial-A-battle`, `12-trial-B-battle`, `12b-trial-unshielded-defeat`, `13-trial-connected-counter-failure`, `14-trial-counter-defeat`, `15-trial-live-refit` and `16-trial-repaired-victory`. Original tutorial and Fold7 desktop-aspect frames remain in the same review packet.

The design follows the observed split portrait composition and connected-board → real production → visible army → wall-defense loop in [the source brief](../references/gear-defenders.md). The numeric equation, direct merge/undo, resource prices, troop designs and gate allocation are original rules. The primitive art, tutorial pacing, army abundance and late-game fidelity have not been accepted by an independent review.

Next gate: coordinator/Astra review before campaign expansion. The three-region campaign, 30–60-minute progression, strategic unlocks, additional distinct roles, bosses, seeded challenge/replay and final sound/animation polish remain unfinished. The coordinator reports a real 0.1→0.2 APK upgrade passed; it does not validate the 0.2.1 staged-backup amendment. Current-version Android runtime acceptance, interrupted Android write recovery, physical Fold7 transitions, clipboard/keyboard behavior, Android Back handling and measured phone performance remain pending. Corrupt-save, storage-failure and prior-version tests are injected fixtures, distinct from app-owned save/reload input tests.
