# Frontline Foundry — first playable checkpoint

Original offline portrait 3D commander/base defense prototype. The first loop
is ready for independent desktop review. It is not the complete game, an Android
test result, or a 30–60-minute campaign.

Move a gold commander between the compact foundry and its adjacent sandbag
front. Your weapon fires automatically at living nearby drones. The teal
recruits start without weapons: approach the left pad and tap **Supply Rifles**
to spend 8 scrap. Three individual rifles are handed to the queue one at a time;
armed recruits walk through the gate and attack independently. Their kills drop
gold scrap. Collect it and return to the right pad: 14 scrap supplies the rover's
cannon, then that vehicle leaves the workshop and fights armored drones.

Stop at least 8 of 10 finite siege drones while the commander and HQ survive.
The deliberate successful input route lasts approximately 48 simulation seconds.
Losing either health pool ends the attempt immediately. **Retry Siege** starts a
fresh supplied attempt immediately, retaining the entire earned record and
settings. There are no real-world waits, offline production, ads, purchases,
accounts, energy restrictions, network features, or external assets.

## Explicit original rules

- Floating left thumb stick, unrestricted movement within the connected base
  and front; speed 3.4 units/second. No manual aim, ammunition or dodge.
- Automatic commander fire: 6 damage every 0.55 seconds within 3.6 units.
  The starter sentry fires 3 damage every 0.95 seconds within 4.4 units. Starting
  wallet 8 plus an obtainable 6-scrap cache prevents a zero-money bootstrap lock.
- A station charges only on an explicit contextual button release while within
  1.45 units. Crossing pads never spends. Each station can be supplied once.
  Rifles own exactly three tokens and three recruits; the rover owns one token
  and one chassis. One queue head equips at a time for 0.8 seconds; this is a
  visible handoff animation, not a production or monetization timer.
- Four total combat slots. Each token equips exactly one owned recruit and is
  consumed. Infantry walk to three front positions and attack for 9 damage every
  0.72 seconds; the rover deals 28 every 1.05 seconds. Unpaid recruits never fire.
  Direct unobstructed deployment prevents gate/pathfinding stranding.
- Nearest living in-range target, per-attacker cooldown and actual per-recruit
  shot/damage ownership. Armored drones take 38% damage from small arms; the
  rover pierces armor. Enemy fire can kill commander or individual recruits.
- Unique drop per kill: 5 scrap for light, 8 for armored; only the commander
  collects within 1.35 units. Drones that reach HQ deal 30/50 integrity damage
  and cannot also pay a kill reward. Objective, defeat and attempt accounting
  resolve once. All encounter definitions are immutable **catalog 1 / seed 17**.

## Controls and local reliability

At 720 logical pixels representing 360dp, all action/menu buttons are at least
96 pixels high (48dp); the supply button is 112 pixels high. Pause freezes the
whole battle. Sound and reduced effects are independent persisted settings.
Procedural tones are original. Native Back-to-quit and automatic quit are
explicitly disabled; Back closes the transfer panel first, then toggles pause.
Native Android Back still needs coordinator validation.

Local saves use schema 1, pinned catalog/seed, complete active entities/cooldowns,
profile/settings, revision and SHA-256 payload checksum. Alternating checked
slots protect the newest good copy. Checked committed temporary autosaves may
recover after interrupted promotion; uncommitted imported temporaries cannot
replace progress. Malformed imports and failed storage leave current progress
intact. Save failure is visible in the HUD. A restored active run starts paused.

Pause → Save / Transfer → **Export** generates and directly copies a complete
code, with verified clipboard feedback or an honest failure message. **Paste**
restores clipboard text; **Import** validates and durably commits before replacing
memory. TextEdit receives touch focus using engine mouse emulation; emulated
mouse copies are filtered from world movement. Desktop clipboard and keyboard
checks do not establish phone IME behavior.

## Run and review

Use the pinned Godot 4.7.2 stable executable from the repository's `toolchain.json`.
From the exact assigned worktree, run:

```powershell
python android-games/frontline-foundry/tests/run_desktop.py rules --label review
python android-games/frontline-foundry/tests/run_desktop.py headless --label review
python android-games/frontline-foundry/tests/run_desktop.py rendered --label review
python android-games/frontline-foundry/tests/run_desktop.py movie --label review
python android-games/frontline-foundry/tests/run_desktop.py restore --label review --resume-from android-games/frontline-foundry/.artifacts/<successful-rendered-run>
```

The runner isolates APPDATA/LOCALAPPDATA and freezes executed source, raw/LF
hashes, logs, states, raw input events and readable PNGs under ignored
`.artifacts/`. Rendered clipboard checks need Windows interactive desktop access.
The playthrough uses actual engine ScreenTouch/drag/key input and ordinary
physics processing. It does not inject earned currency/progress or force a
terminal redraw. Synthetic rule/control/storage fixtures are separately labelled.
Movie mode records one continuous original-game route through commander fire,
rifle handoff, deployment, independent attacks, rover escalation, natural victory,
commander defeat and actual Retry. The full input suite separately proves HQ
defeat, pause, resize, scene restoration, settings, clipboard and import retention.

The Android preset is **com.dsschiff.frontlinefoundry**, **0.1.0 / code 1**,
arm64-v8a + x86_64, official unmodified non-Gradle template, zero enabled/custom
permissions and no signing credentials. The pinned official debug template has
min SDK 24 / target SDK 36. No APK has been exported or installed by this builder.
Generated UID/icon metadata comes from an isolated copied portable editor/config;
its existing `shutdown_adb_on_exit=false` remains in force. Shared editor settings
and SDKs were not changed.

## Review boundary

The Top Force brief supports the local equipment-to-front sequence; T3's Top
General end-card attribution remains qualified third-party mapping. Free control,
prices, automatic fire, accounting, queue cadence, caps, targeting and death
rules here are original choices, not measured commercial-game rules. All meshes,
materials, sounds, UI and encounter content are original; no commercial footage
was downloaded or copied.

Independent coordinator tests and Astra appeal/fidelity review are next. Android
export/launch/update, native clipboard/Back/IME/lifecycle, safe areas, physical
Fold7 cover/inner transitions, touch accuracy, sound, measured FPS and human fun
are open. Desktop window ratios are not physical folding evidence. Campaign
expansion is paused until the first loop is reviewed. The eventual meaningful
30–60-minute arc, ending and replay ambition remains: a provisional 12 missions,
4 roles, 3 support buildings, 6 enemy roles, 3 bosses and seeded skirmishes. Three
fronts, ammo, medics, carts, manual aim/dodge and dragged blueprints are deferred.
