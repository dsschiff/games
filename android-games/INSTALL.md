# Personal Android builds

Daniel's seven personal Android apps (the six games here plus Planetfall from `dsschiff/planetfall`) install and update on his phone through [Obtainium](https://github.com/ImranR98/Obtainium) from the **private** GitHub repo [dsschiff/android-games-releases](https://github.com/dsschiff/android-games-releases). Nothing is published from this public repo. Versions, hashes and release links are in `delivery.json`; release evidence is in `android-games/evidence/release-signing-20261022.json`.

| App | Version | Package id | Release tag |
|-----|---------|-----------|-------------|
| Gear Bastion | 0.4.1 (code 10) | `com.dsschiff.gearbastion` | `gear-bastion-v0.4.1` |
| Tower Trials | 0.4.1 (code 7) | `com.dsschiff.towertrials` | `tower-trials-v0.4.1` |
| Hook and Hunger | 0.3.1 (code 7) | `com.dsschiff.hookandhunger` | `hook-and-hunger-v0.3.1` |
| Hearthguard | 0.3.1 (code 5) | `com.dsschiff.hearthguard` | `hearthguard-v0.3.1` |
| Frontline Foundry | 0.3.2 (code 6) | `com.dsschiff.frontlinefoundry` | `frontline-foundry-v0.3.2` |
| Dead Run | 0.4.0 (code 6) | `com.dsschiff.deadrun` | `dead-run-v0.4.0` |
| Planetfall | 1.0.0 (code 1) | `com.dsschiff.planetfall` | `planetfall-v1.0.0` |

All seven are signed with one release key (certificate SHA-256 `25:27:B2:60:9A:62:20:58:B0:19:83:18:B8:AD:D4:41:64:6E:A4:2A:B9:D5:20:C5:36:13:1F:58:28:1B:F0:3F`), kept outside Git; its location is in the agentic-workflow credentials map. None requests an Android permission (Planetfall declares only an app-private AndroidX receiver permission) and all work offline.

**Google Play later, no reinstall.** Google Play internal testing is planned later. This same key will be registered with Play App Signing as the app signing key, so apps installed from Obtainium will take Play updates in place. Do not let Play generate a new app signing key for these package ids.

**One-time switch from the old builds.** The earlier builds were debug-signed. Android refuses to update an app with a build signed by a different key (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), so each of the six games must be uninstalled once, and uninstalling deletes its local save. Export each game's portable save code first and import it into the release build (step 1 and step 6 below). After this switch, every update installs over the existing app and keeps saves.

## Phone setup (one time)

1. **Save your progress from the old builds.** The six Godot games already on the phone are debug-signed test builds; Android will not update them with the new release-signed builds, so each must be uninstalled once, which deletes its local save. Before uninstalling, open each game, go to its Menu/Pause/Settings panel, open save transfer and tap **Export** (or **Copy**). Paste each code into a private note, one per game, and keep the complete code. Planetfall is a new app; progress from Planetfall in a phone browser stays in the browser.
2. **Install Obtainium.** On the phone, open <https://github.com/ImranR98/Obtainium/releases/latest>, download `app-arm64-v8a-release.apk`, open it and allow your browser to install apps when Android asks. (Alternative: install Obtainium from F-Droid.) Dismiss Obtainium's welcome notes.
3. **Create a read-only GitHub token** (on the phone or the PC): <https://github.com/settings/personal-access-tokens/new>
   - Token name: `Obtainium phone`. Expiration: the longest offered; renew it when GitHub emails you.
   - Resource owner: `dsschiff`. Repository access: **Only select repositories** → `dsschiff/android-games-releases`.
   - Permissions → Repository permissions → **Contents: Read-only** (GitHub adds Metadata: Read-only itself). Nothing else.
   - **Generate token** and copy it.
4. **Give Obtainium the token:** Obtainium → Settings (gear icon) → **Source-specific** → GitHub → **GitHub personal access token (increases rate limit)** → paste → back out to save.
5. **Add all seven apps at once** (pick one route):
   - **Import file:** on the phone, signed in to GitHub, open <https://github.com/dsschiff/android-games-releases/blob/main/obtainium/obtainium-import.json>, tap the download (raw) button, then Obtainium → Settings → **Import/export** → **Obtainium import** → choose the downloaded `obtainium-import.json`.
   - **QR codes:** open this README on the PC and scan each app's QR code in the releases repo README with the phone camera; each opens Obtainium's *Import apps* prompt → **Continue**.
   - **By hand:** Obtainium → **Add app** → URL `https://github.com/dsschiff/android-games-releases` → in the additional options set **Filter release titles by regular expression** to `^<slug>-v` (for example `^dead-run-v`) and **Trim version string with RegEx** to `[0-9]+(\.[0-9]+)+` → **Add**. Repeat per app.
6. **Swap each game to the release build:** Settings → Apps → *game* → **Uninstall** (only after step 1 saved its code). Then in Obtainium tap the app → **Install**; the first time, allow Obtainium to install unknown apps. Open the game and paste the save code into its save transfer → **Import**.
7. **Updates from now on:** Obtainium checks in the background and notifies you; tap **Update** (or the *Install/update apps* bar). Updates install over the existing app and keep saves.

Tested on the Android emulator, not yet on the phone: the import adds all seven entries and matches them to installed apps by package id. The emulator had no token, so the private-repo download step is unverified until the phone has one.

## Building a release

`python scripts/portfolio.py build <game> --release --signing-env <private signing file> --expect-signer-sha256 <digest>` exports with Godot's release template and the private key, verifies the signature and refuses a debuggable APK. Raise `version/code` in the game's `export_presets.cfg` for every published build (and `version/name` for a new version), then publish one GitHub release per version as described in the releases repo README. `scripts/package_android.py` (the older local-folder bundle of debug builds) is superseded by the releases repo.

## Game notes

The notes below were written for the debug-signed builds named in each heading. Controls and save transfer are unchanged in the current release line; later graphics work and verification for each version are recorded in `delivery.json`, `graphics-overhaul.json` and the evidence files.

### Gear Bastion (notes written for 0.3.3 / code 7)

This sizing update expands the battlefield and rearranges controls for cover, unfolded and landscape windows. It preserves existing saves; actual emulator code6-to7 install-over, input, resize and cold launch pass independent review. Further phone testing is deferred. The full 3D overhaul is still in progress. It contains nine campaign encounters, three seeded replays, medals, an ending, versioned local saves, portable save codes, sound and reduced-effects settings. Its original brass foundry produces troops that march through three arches and defend against beetle raiders.

### Gear Bastion controls and progress

Choose the first gate on the journey map. Drag gears from the tray into sockets; connect troop generators to the gold core. Adjacent drives increase production. Begin defense, then move/refit gears and choose exits as threats change. Retry resets the encounter while keeping earned campaign progress. Clearing a gate unlocks the next. The in-game guide explains roles and power links.

Menu contains speed, mute, calm effects and save/export. Copy the portable save code to a private text file before changing devices. Paste it into the save dialog and choose Import to restore. Keep the complete code. Invalid codes leave the current game intact. Active battles restore paused.

### Tower Trials (notes written for 0.3.1 / code 4)

This software candidate is ready for phone testing. It contains 36 authored coastal puzzles, an ending, optional treasure/medals and four seeded Challenge families with separate records. Generated runs retain their exact puzzle snapshot across saves, Undo, Retry and Replay. Both original catalogs remain available to existing saves.

Tap a room to read its full forecast, then Enter. Enemy strength must be strictly below courier power. Keys, shields, traps, ordered enemies and collapsing routes can make a tempting choice irreversible. Undo/Retry restore the route; Settings opens rules, save transfer and seeded Challenges. Copy/Paste/Import handles portable saves; campaign progress and generated records stay separate. Android Back closes the active panel, then pauses or returns to the campaign map.

Independent rules, authored/generated input and focused Back checks pass. Actual Android updates preserve both old campaign routes and an active generated snapshot/record. Native generated loss/Undo/Retry/victory/Replay, clipboard transfer, Back, Home/cold and emulated cover/inner resize are verified. The candidate still needs physical Fold7 touch/folding/safe areas, audible sound, measured performance and human pacing/fun review. No complete 36-puzzle Android playthrough or measured 30–60-minute human duration is claimed. Evidence: `android-games/evidence/tower-code4-candidate.json`.

### Hook and Hunger (notes written for 0.2.2 / code 4)

This conditional software candidate is ready for phone testing. It contains a
legacy prologue, twelve passages across four islands, weapon/power purchases,
an ending and seeded harbor arenas. Drag to move; nearby chained-weapon attacks
are automatic. Watch enemy telegraphs, use cover and return to the dock for
upgrades or repairs. Retry preserves coherent earned progress. Pause opens
sound/reduced effects and portable save transfer. Export copies the complete
code; Paste and Import restore it. Invalid codes retain the current save.

Independent
campaign/input/save checks and real code1→2→3→4 updates retain earned progress.
Native Android first-passage loss/Retry/victory, corrected text editing, invalid
Import, clipboard/fresh valid Import, Back, Home/cold and emulated resize are
verified. The full campaign was exercised on desktop; a complete Android
campaign playthrough and human session duration are not established.

The native platform report remains **partial_ime_unresolved: eight checks pass,
soft-keyboard display unverified**. This emulator reports a visible hardware
keyboard; the pinned Godot engine suppresses its on-screen keyboard in that
configuration. Actual injected native typing edits the focused field and the
Export/Paste/Import buttons work. On a Fold7 without a hardware keyboard, still
verify touch opens the on-screen keyboard, type through that keyboard, dismiss
it and repeat save transfer. This is an explicit required phone check. Evidence:
`android-games/evidence/hook-code4-candidate.json`.

### Hearthguard (notes written for 0.2.0 / code 2)

This conditional software candidate contains ten defense maps across three regions,
three tower families with upgrade forks, six enemy roles, three bosses, an ending
and seeded endless/replay options. Move with the left thumb, collect nearby gold,
approach a pad and choose an explicitly priced tower or upgrade. Bolt, Mortar and
Beacon solve different threats. Selling returns part of the investment. Journey
contains map selection, seeds, budgets, mirrored roads and the ending. Existing
prototype battles remain accessible through Open Expedition / Return to Legacy Pass.

The actual code1-to2
update preserves the entire old battle, results and settings. A natural Android
loss, Retry, funded construction and first-map no-leak victory are verified.
Native settings, invalid-code rejection, clipboard/fresh import, Back, active
emulated cover/inner resize and cold paused restoration also pass. The complete
campaign was exercised on desktop; representative Android play is not all ten maps.

Windows rendered clipboard runs remain failed on host clipboard access; successful
Android clipboard transfer is separate evidence. Physical on-screen keyboard/IME,
actual folding, touch/safe areas, audible sound, measured FPS and human fun remain
required. Regent contrast and late-game pacing are known playtest/polish limits.
Evidence: `android-games/evidence/hearth-code2-candidate.json`.

### Frontline Foundry (notes written for 0.2.0 / code 2)

This conditional software candidate contains twelve missions, four unit roles,
three support choices, six enemy roles, three bosses, an ending and seeded
replays. Drag to move the commander, recruit explicitly priced squads and use
their different ranges and roles to protect headquarters. Mission selection
shows the briefing and budget before Launch. Retry restores the mission while
keeping earned career progress. Pause opens settings and save transfer.

The actual code1-to2
update retains the entire old encounter. Native funded victory, separate natural
defeat/Retry, settings, invalid-code rejection, real Export/Paste/Import, Android
Back, active paused cover/inner resize and Home/cold restoration are verified.
The full campaign was exercised on desktop; representative Android play does
not establish a complete phone campaign or human session duration.

The opening mission also permits an untouched victory. Later currency surplus,
dense formations and pacing remain playtest limits. Physical touch/IME, folding,
safe areas, sound and measured frame timing remain required. Evidence:
`android-games/evidence/frontline-code2-candidate.json`.

### Dead Run (notes written for 0.2.1 / code 3)

This build contains 24 evacuation roads across four districts, three weapons,
six enemy roles, four bosses, an ending, medals and seeded replay. This
conditional software candidate is ready for physical-phone testing.

Drag sideways to steer the squad; fire is automatic. Shooting numbered gates
changes their signed value. Crossing applies that value, with recruits capped
at 20; a negative crossing can remove crew. Fit the entire gold footprint
through gaps, keep infected off the rescue line and choose when to divert fire
to a roadside rescue. The evacuation map selects unlocked roads and weapons.
Retry restores the encounter while retaining earned progress. Pause opens
sound/reduced effects, the map and save transfer. Export/Paste/Import transfers
the complete save; Android Back closes the active panel or pauses live play.

Actual updates
retain the complete old encounter, earned profile and settings. Native win,
loss, Retry, next-road progression, transfer and Back are verified. Code3 fixes
the camera crop on wider displays, preserving the portrait composition.
Independent native visual review closes that correction in emulator scope.
Actual code3 footage shows five crew; crew20 and steering extremes are covered
by headless geometry. The complete campaign
was exercised on desktop, with representative Android play. Authored simulation
duration does not establish a human 30–60-minute session.

Cap-heavy/sparse late-road pacing and small distant threats remain playtest
limits. Physical touch/IME, folding, safe areas, audible sound and measured
performance remain required. Current evidence is indexed at
`android-games/evidence/dead-run-code3-candidate.json`, carrying forward the
retained code2 outcome/platform checks; the camera delta
is documented in `android-games/dead-run/CAMERA-CHECKPOINT.md`.

## Phone checks still required

Galaxy Z Fold7 is the working target from Daniel's description; exact model and Android version await a connected phone. Test cover and unfolded displays, actual folding during battle, touch accuracy and safe areas, audible sound, full-session pacing and heavy-encounter frame timing. The targets are 60 fps and above 30 fps during heavy encounters; neither is a measured phone result yet. Dense formations and lengthy time at the troop cap remain playtest limitations. Automatic route duration is not a measured human session.

Each game evidence index separates full desktop routes from representative Android play, actual updates, unresolved results and physical-phone checks. Software-candidate status does not establish physical-phone acceptance or human fun.
