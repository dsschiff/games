# Personal Android builds

These are local debug-signed APKs for Daniel's own use. They are excluded from Git and have no store release. Current build paths and hashes are in `delivery.json`.

## Gear Bastion 0.3.2 / code 6

The software candidate is ready for phone testing. It contains nine campaign encounters, three seeded replays, medals, an ending, versioned local saves, portable save codes, sound and reduced-effects settings. Its original brass foundry produces troops that march through three arches and defend against beetle raiders.

On the build PC, the verified APK is:

`C:/projects/active/games/.artifacts/gear-bastion/20261018T002003656002Z/gear-bastion.apk`

SHA-256: `bb009b600b24c3498363889b0099d361f19ce1bd4fee24a8b704eb3906e3f72b`

Transfer that file to the phone using USB or a private file-transfer route. Open it from Files and allow that specific app to install it if Android requests permission. Keep the existing installation when updating: install over it rather than uninstalling, so local saves remain available. Updates must use the same signing identity. The build has no requested Android permissions and works offline.

With an authorized USB-debugging connection, the equivalent PC command is `adb -s <confirmed-phone-serial> install -r <apk-path>`. Identify the actual phone before selecting its serial; the development emulator is a different device. Do not run a data-clear or uninstall as an update step.

## Gear Bastion controls and progress

Choose the first gate on the journey map. Drag gears from the tray into sockets; connect troop generators to the gold core. Adjacent drives increase production. Begin defense, then move/refit gears and choose exits as threats change. Retry resets the encounter while keeping earned campaign progress. Clearing a gate unlocks the next. The in-game guide explains roles and power links.

Menu contains speed, mute, calm effects and save/export. Copy the portable save code to a private text file before changing devices. Paste it into the save dialog and choose Import to restore. Keep the complete code. Invalid codes leave the current game intact. Active battles restore paused.

## Tower Trials 0.3.1 / code 4

This software candidate is ready for phone testing. It contains 36 authored coastal puzzles, an ending, optional treasure/medals and four seeded Challenge families with separate records. Generated runs retain their exact puzzle snapshot across saves, Undo, Retry and Replay. Both original catalogs remain available to existing saves.

Verified local APK:

`C:/projects/active/games/.artifacts/tower-trials/20261018T024941903573Z/tower-trials.apk`

SHA-256: `20acf7f90dcee4ff8cfc3956bee2375f9ea84a8e7c8bf52776282238b5ca35d0`

Install over the existing Tower Trials app with the same signing identity. Tap a room to read its full forecast, then Enter. Enemy strength must be strictly below courier power. Keys, shields, traps, ordered enemies and collapsing routes can make a tempting choice irreversible. Undo/Retry restore the route; Settings opens rules, save transfer and seeded Challenges. Copy/Paste/Import handles portable saves; campaign progress and generated records stay separate. Android Back closes the active panel, then pauses or returns to the campaign map.

Independent rules, authored/generated input and focused Back checks pass. Actual Android updates preserve both old campaign routes and an active generated snapshot/record. Native generated loss/Undo/Retry/victory/Replay, clipboard transfer, Back, Home/cold and emulated cover/inner resize are verified. The candidate still needs physical Fold7 touch/folding/safe areas, audible sound, measured performance and human pacing/fun review. No complete 36-puzzle Android playthrough or measured 30–60-minute human duration is claimed. Evidence: `android-games/evidence/tower-code4-candidate.json`.

## Hook and Hunger 0.2.2 / code 4

This conditional software candidate is ready for phone testing. It contains a
legacy prologue, twelve passages across four islands, weapon/power purchases,
an ending and seeded harbor arenas. Drag to move; nearby chained-weapon attacks
are automatic. Watch enemy telegraphs, use cover and return to the dock for
upgrades or repairs. Retry preserves coherent earned progress. Pause opens
sound/reduced effects and portable save transfer. Export copies the complete
code; Paste and Import restore it. Invalid codes retain the current save.

Verified local APK:

`C:/projects/active/games/.artifacts/hook-and-hunger/20261018T031647711677Z/hook-and-hunger.apk`

SHA-256: `2391343d79096cf766f2e68daf7db19c84053aca489d0b3e29b2d9a834241c77`

Install over the existing app using the same signing identity. Independent
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

## Hearthguard 0.2.0 / code 2

This conditional software candidate contains ten defense maps across three regions,
three tower families with upgrade forks, six enemy roles, three bosses, an ending
and seeded endless/replay options. Move with the left thumb, collect nearby gold,
approach a pad and choose an explicitly priced tower or upgrade. Bolt, Mortar and
Beacon solve different threats. Selling returns part of the investment. Journey
contains map selection, seeds, budgets, mirrored roads and the ending. Existing
prototype battles remain accessible through Open Expedition / Return to Legacy Pass.

Verified local APK:

`C:/projects/active/games/.artifacts/hearthguard/20261018T053956831230Z/hearthguard.apk`

SHA-256: `928bb45d102df9d2a55e0ee3e1c51b8b7df0af5ea945d185edbf51e64484676b`

Install over the existing app with the same signing identity. The actual code1-to2
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

## Frontline Foundry 0.2.0 / code 2

This conditional software candidate contains twelve missions, four unit roles,
three support choices, six enemy roles, three bosses, an ending and seeded
replays. Drag to move the commander, recruit explicitly priced squads and use
their different ranges and roles to protect headquarters. Mission selection
shows the briefing and budget before Launch. Retry restores the mission while
keeping earned career progress. Pause opens settings and save transfer.

Verified local APK:

`C:/projects/active/games/.artifacts/frontline-foundry/20261018T072513236798Z/frontline-foundry.apk`

SHA-256: `eef7f08a32dbc61245d29f281f5dc8500786c852019c025f07cd39fc7407d45c`

Install over the existing app with the same signing identity. The actual code1-to2
update retains the entire old encounter. Native funded victory, separate natural
defeat/Retry, settings, invalid-code rejection, real Export/Paste/Import, Android
Back, active paused cover/inner resize and Home/cold restoration are verified.
The full campaign was exercised on desktop; representative Android play does
not establish a complete phone campaign or human session duration.

The opening mission also permits an untouched victory. Later currency surplus,
dense formations and pacing remain playtest limits. Physical touch/IME, folding,
safe areas, sound and measured frame timing remain required. Evidence:
`android-games/evidence/frontline-code2-candidate.json`.

## Dead Run 0.2.1 / code 3

This build contains 24 evacuation roads across four districts, three weapons,
six enemy roles, four bosses, an ending, medals and seeded replay. This
conditional software candidate is ready for physical-phone testing.

Verified local APK:

`C:/projects/active/games/.artifacts/dead-run/20261018T105219658505Z/dead-run.apk`

SHA-256: `ab1a8863fdb92815278924e146092c864b38309baf57fa521e99944b400a415c`

Drag sideways to steer the squad; fire is automatic. Shooting numbered gates
changes their signed value. Crossing applies that value, with recruits capped
at 20; a negative crossing can remove crew. Fit the entire gold footprint
through gaps, keep infected off the rescue line and choose when to divert fire
to a roadside rescue. The evacuation map selects unlocked roads and weapons.
Retry restores the encounter while retaining earned progress. Pause opens
sound/reduced effects, the map and save transfer. Export/Paste/Import transfers
the complete save; Android Back closes the active panel or pauses live play.

Install over the existing app using the same signing identity. Actual updates
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
