# Hearthguard — first playable

Original offline angled-overhead 3D road defense, Godot **4.7.2**, GDScript.
This is the defining-loop review slice, not the complete six-game deliverable.

Move the teal lantern warden with a floating left-thumb stick. Collect the five
loose gold coins, approach the **5 GOLD** pad and explicitly tap **BUILD BOLT**.
The tower fires at the advancing ash column. Collect three-gold battle drops
near the road, then invest **15** in the downstream Heavy tower. Heavy deals two
damage per shot; Bolt deals one. Prioritize the enemy furthest along the road
inside each tower's 4.8-unit coverage. Four leaks breach the eight-point refuge.
Twenty stopped enemies produce a no-leak win. The warden is a collector/builder,
without attacks, hero damage, dash or mounting in this slice.

Crossing a pad never spends. A fresh battle starts at zero wallet with five
finite, reachable original supply coins. No kill or coin can reward twice.
There are no settlement menus, accounts, networking, ads, purchases, energy,
construction waits or repeated resource farming requirements.

Pause holds the entire battle. Sound and reduced effects are saved locally.
Back closes transfer first, then returns between the pause log and game;
Android Back-to-quit is explicitly disabled. Cold loading an active battle
starts paused. Retry restarts this battle's actors, supply coins, wallet and
towers while retaining attempts, wins, best stopped count, no-leak seal and
settings. No wallet is carried between attempts, so Retry cannot farm money.

Save codes contain version 1, the complete battle/profile/settings, revision
and a SHA256 checksum over the exact payload. Two alternating slots retain
the latest checked candidate. Staged ordinary saves are recoverable; staged
imports are ignored until promotion. Import checks all state before replacing
anything, then commits storage before changing live memory. Malformed input
or a failed import write preserves the current complete live state and save.
Copy/Paste use the platform clipboard; the TextEdit also supports native touch
focus and editing. A code is a local backup, not a secure proof of achievements.

## Desktop verification

Run from the assigned repository root:

```powershell
python android-games/hearthguard/tests/run_desktop.py rules --label review
python android-games/hearthguard/tests/run_desktop.py headless --label review
python android-games/hearthguard/tests/run_desktop.py rendered --label review
python android-games/hearthguard/tests/run_desktop.py movie --label review
```

Every invocation creates a unique ignored `.artifacts/` directory **inside this
game folder**, isolates APPDATA/LOCALAPPDATA, freezes executed source bytes,
records hashes/command/logs and refuses a successful result on script errors,
missing completion markers or source changes during execution. Rendered
clipboard tests on Windows require the interactive desktop session; the
restricted sandbox cannot open its clipboard. No Android tools are invoked.
The movie route starts fresh and runs continuously through both investments
and several seconds of combat; it injects only engine touch events. The full
route proves loss, Retry, natural win, active pause/reload/resize, touch focus,
real code editing and valid/invalid import. Synthetic storage-fault adapters
are explicitly confined to separate fault assertions. Rule fixtures never
stand in for earned playthroughs.

The portrait logical canvas is 720 pixels wide. Action hit targets are at least
96 pixels, corresponding to 48dp at 360dp cover width. Desktop profiles exercise
720×1680 (Fold7 cover ratio) and 1000×1110 (approximate inner ratio) with active
state retention. These are window proportions, not measured physical safe
areas, folding, phone performance, audio audibility or human pacing/fun.

## Reference boundary and original assets

The repository's `android-games/references/kingshot.md` and direct-playback
follow-up in `android-games/reviews/three-action-references-astra.md` select
K2's **move → nearby coins → priced pad → firing tower → further investment**.
Third-party Kingshot attribution and exact source pickup/input/debit rules
remain qualified. Our explicit button, prices, damage, budget, finite supply,
lantern warden, Copper Pass layout and mesh/tone artwork are original choices.
All models, materials, UI and synthesized short tones are authored in source.
No commercial footage, external art, signing material or local saves enter Git.

The next milestone is independent Astra review of this playable loop and exact
evidence, then a refined full campaign: a meaningful 30–60-minute initial arc,
10 maps across 3 regions, three tower families with forks, six enemy roles and
three bosses, seeded replay and no-leak mastery. Android export/update/offline
lifecycle and physical Galaxy Z Fold7 checks belong to the coordinator and
remain separate. Do not expand or substitute this slice for that full game
before first-loop review approval.
