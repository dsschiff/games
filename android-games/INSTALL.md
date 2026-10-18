# Personal Android builds

These are local debug-signed APKs for Daniel's own use. They are excluded from Git and have no store release. Current build paths and hashes are in `delivery.json`.

## Gear Bastion 0.3.2 / code 6

The software candidate is ready for phone testing. It contains nine campaign encounters, three seeded replays, medals, an ending, versioned local saves, portable save codes, sound and reduced-effects settings. Its original brass foundry produces troops that march through three arches and defend against beetle raiders.

On the build PC, the verified APK is:

`C:/projects/active/games/.artifacts/gear-bastion/20261018T002003656002Z/gear-bastion.apk`

SHA-256: `bb009b600b24c3498363889b0099d361f19ce1bd4fee24a8b704eb3906e3f72b`

Transfer that file to the phone using USB or a private file-transfer route. Open it from Files and allow that specific app to install it if Android requests permission. Keep the existing installation when updating: install over it rather than uninstalling, so local saves remain available. Updates must use the same signing identity. The build has no requested Android permissions and works offline.

With an authorized USB-debugging connection, the equivalent PC command is `adb -s <confirmed-phone-serial> install -r <apk-path>`. Identify the actual phone before selecting its serial; the development emulator is a different device. Do not run a data-clear or uninstall as an update step.

## Play and preserve progress

Choose the first gate on the journey map. Drag gears from the tray into sockets; connect troop generators to the gold core. Adjacent drives increase production. Begin defense, then move/refit gears and choose exits as threats change. Retry resets the encounter while keeping earned campaign progress. Clearing a gate unlocks the next. The in-game guide explains roles and power links.

Menu contains speed, mute, calm effects and save/export. Copy the portable save code to a private text file before changing devices. Paste it into the save dialog and choose Import to restore. Keep the complete code. Invalid codes leave the current game intact. Active battles restore paused.

## Phone checks still required

Galaxy Z Fold7 is the working target from Daniel's description; exact model and Android version await a connected phone. Test cover and unfolded displays, actual folding during battle, touch accuracy and safe areas, audible sound, full-session pacing and heavy-encounter frame timing. The targets are 60 fps and above 30 fps during heavy encounters; neither is a measured phone result yet. Dense formations and lengthy time at the troop cap remain playtest limitations. Automatic route duration is not a measured human session.

The emulator verified actual offline play, natural victory/defeat screens, Retry, save-preserving updates and lifecycle behavior. Source rules, full nine-encounter input routes and replay checks also passed independently. These establish a software candidate, not physical-phone acceptance or a judgment that the full game is fun.
