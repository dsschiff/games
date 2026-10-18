# Local Android toolchain

Run from the repository root with Python 3.11+ (standard library only):

```powershell
python scripts/install_toolchain.py --accept-licenses --with-emulator
python scripts/portfolio.py status
python -m unittest discover -s tests/tooling -v
python scripts/portfolio.py test input-2d combat-3d
python scripts/portfolio.py build input-2d combat-3d
```

Omit project selectors to discover all actual `project.godot` files recursively
under `android-games/`. No placeholder games count as implementation. `--godot`
overrides the executable; `--config` selects another toolchain JSON. Godot must
still match the pinned version. `GAME_TOOLCHAIN_ROOT` relocates machine tooling.
No global PATH, Windows features or system Java settings are changed.

The installer verifies pinned official Godot editor/templates SHA512 and Google
command-line tools SHA256 before extraction. It installs Android platform 35 and
build-tools 35.0.1, plus current platform-tools. Optional emulator/image versions
are resolved by SDK Manager and recorded in the SDK's `package.xml` files; cache
these local packages for exact reuse. Current local command-line tools are 22.0,
platform-tools 37.0.1, emulator 37.2.12 and API 35 Google APIs x86_64 revision 9.
JDK 21.0.11 at the configured Microsoft path is reused. The standard prebuilt
APK path needs neither NDK nor CMake. No Gradle override is used. Godot's 4.7.2
prebuilt template actually targets Android 36; the installed 35.0.1 build tools
successfully sign it, with a logged fallback message. APK minimum SDK is 24.

`_sc_` keeps Godot editor settings/templates/debug keystore in its tool directory.
Only child processes receive local APPDATA, SDK-user/cache, AVD and Java/TEMP
paths. Android adb/emulator on Windows additionally uses the Windows profile's
`.android` state, ignoring some home overrides. On this host those commands must
run in the interactive session outside the restricted sandbox; sandbox errors
misreported usable WHPX acceleration and prevented `.android` creation. No
administrator setup or Windows feature changes were necessary.

The portable editor sets `export/android/shutdown_adb_on_exit = false` so a
parallel editor import/export cannot stop the shared ADB server during a device
test. Godot's Android export poller otherwise issues `adb kill-server` on exit
when this setting is enabled ([4.7 source](https://github.com/godotengine/godot/blob/4.7-stable/platform/android/export/export_plugin.cpp#L441)).
An actual editor import retained server PID18100 and online emulator transport
after the setting changed. This does not remove the interactive-session
requirement above; restricted streamed installs can still stall. Keep failed
transport/install packets separate from accepted gameplay evidence.

## Test and build evidence

Every test starts with isolated per-run `user://` data and imports resources.
`tests/run_tests.gd` and `tests/playthrough.gd` must each exit 0, log no Godot
errors, and print **`SUITE_COMPLETE: PASS`** only after all their assertions run.
Playthroughs run with `--fixed-fps 60`. A rules-only project is partial, exit 2.
No projects or missing suites are skipped/partial, never passed. Failure is exit
1; success is exit 0. Headless tests do not establish Android performance.

Evidence lives under ignored `.artifacts/<project>/<UTC run id>/`: import,
rules/build, optional playthrough, signature and APK-inspection logs, plus JSON
manifests. Source filenames and bytes are fingerprinted before and after the
command; any change invalidates its result. `.godot`, cache/build/output and
runtime data are excluded. Git revision plus dirty status make uncommitted
source explicit. An initial import can create `.uid`/`.import` sidecars; review
and retain them, then rerun for a stable fingerprint. APK manifests contain
SHA256/size, actual package/version/permissions, and verified signature status.
An APK requesting INTERNET fails the offline build check.

## Emulator setup and smoke tests

In an interactive PowerShell session, keep these environment changes local to
that shell. Reuse the existing `portfolio-api35` AVD when present:

```powershell
$env:ANDROID_USER_HOME='C:/projects/active/.game-toolchain/android-user'
$env:ANDROID_AVD_HOME='C:/projects/active/.game-toolchain/avd'
$env:ANDROID_HOME='C:/projects/active/.game-toolchain/android-sdk'
$env:ANDROID_ADB_LOG_PATH='C:/projects/active/.game-toolchain/adb.log'
'no' | & "$env:ANDROID_HOME/cmdline-tools/latest/bin/avdmanager.bat" create avd --name portfolio-api35 --package 'system-images;android-35;google_apis;x86_64' --device pixel_6 --path 'C:/projects/active/.game-toolchain/avd/portfolio-api35'
& "$env:ANDROID_HOME/emulator/emulator.exe" -accel-check
& "$env:ANDROID_HOME/emulator/emulator.exe" -avd portfolio-api35 -no-window -no-audio -no-snapshot -gpu host
```

The last command runs until the emulator stops; use another interactive terminal
for smoke tests. This host has usable WHPX and NVIDIA RTX 5070 Ti GLES 3.1.
SwiftShader's limited fragment uniforms caused blank rendering and shader
errors, so use `-gpu host` here. Dismiss Android's first-run full-screen hint once
before recording touch tests. Do not use `-read-only` if emulator installs/saves
should survive an emulator restart.

Replace `<run>` with the exact successful build run directory:

```powershell
python scripts/android_smoke.py --apk .artifacts/input-2d/<run>/input-2d.apk --package com.dsschiff.probeinput2d --save files/probe-save.json --actions scripts/smoke-actions/input-2d-pixel6.json --serial emulator-5554
python scripts/android_smoke.py --apk .artifacts/combat-3d/<run>/combat-3d.apk --package com.dsschiff.probecombat3d --save files/combat-probe.json --actions scripts/smoke-actions/combat-3d-pixel6.json --serial emulator-5554
```

Run exports and device tests sequentially; Godot and interactive adb may otherwise
compete over the local adb daemon. Smoke scripts disable emulator Wi-Fi/mobile
data, install using `--no-incremental`, resolve the actual exported launcher,
inject taps/drags, read back and assert app-written JSON, background/resume,
reinstall the same APK and compare exact saved bytes, then relaunch. Screenshots,
raw saves, runtime logs and command transcripts remain under
`.artifacts/emulator/<package>/<UTC run id>/`. Same-APK reinstall verifies
installation retention; it does not establish compatibility with a future save
schema or game update. Visual inspection remains necessary. Shader cache
recompilation warnings are retained separately from runtime errors.

Append `--display-size 1080x2520` or `--display-size 1968x2184` for approximate
Galaxy Z Fold7 cover/inner resolution checks. Fixture coordinates map through
the centered 720x1280 viewport, and the previous display override is restored.
This changes generic emulator geometry only: it does not emulate Samsung
hardware, folding posture/lifecycle, Android skin, physical touch or performance.
The exact physical phone identity and real-device tests remain pending.

To stop only this emulator:

```powershell
& "$env:ANDROID_HOME/platform-tools/adb.exe" -s emulator-5554 emu kill
```

## Gear Bastion prototype fixture

`smoke-actions/gear-bastion-pixel6.json` uses the game's 600x1066 viewport.
It requires fresh data in the test emulator: it moves the initial guard away
from the core, reconnects it, moves a drive beside it, starts defense, waits six
real seconds and pauses. Final expectations check the saved battle phase,
guard/drive piece IDs and board positions, elapsed simulation time, troops
produced and wall bounds. Exact and numeric expectations accept dot paths such
as `state.board.1.x` and `state.time`; numeric list segments select array indices.
Missing fields, wrong types and violated bounds fail. A corresponding check is
omitted when no expectations were supplied, with field counts in the manifest.

The optional `checkpoint` labels are metadata only in the general smoke runner.
Intermediate disconnection/reconnection/rate assertions were separately run
against app-written saves and retained in the independent checkpoint report;
they are distinct from the repeatable fixture's final-state assertions.

After installing the prototype once, clear **only its emulator test data** before
each replay, then use its exact independently built APK:

```powershell
& 'C:/projects/active/.game-toolchain/android-sdk/platform-tools/adb.exe' -s emulator-5554 shell pm clear com.dsschiff.gearbastion
python scripts/android_smoke.py --apk .artifacts/gear-bastion/independent-d0e7cce/gear-bastion.apk --package com.dsschiff.gearbastion --save files/bastion-save.json --actions scripts/smoke-actions/gear-bastion-pixel6.json --serial emulator-5554 --display-size 1080x2520
```

Repeat with `--display-size 1968x2184` for the inner resolution approximation.
Do not clear data on a physical phone. These runs preserve save bytes across a
same-APK reinstall; future-version migration and real fold transitions require
separate checks.

## Real different-APK upgrade verification

`android_upgrade.py` prepares a separate evidence packet under
`.artifacts/upgrades/<package>/<UTC run id>/`. Both input APKs are copied and
hashed before use, inspected for verified signatures and no INTERNET permission,
and must have the requested package with a strictly increasing **actual APK
version code**. Installed version codes are also read back from Android.

Run it only after both immutable APKs are available and Android execution has
been authorized. Example command (paths and schema version must match the real
release pair):

```powershell
python scripts/android_upgrade.py --from-apk .artifacts/old/gear-bastion.apk --to-apk .artifacts/new/gear-bastion.apk --package com.dsschiff.gearbastion --save files/bastion-save.json --actions scripts/smoke-actions/gear-bastion-pixel6.json --preserve-path state.board --preserve-path state.gold --preserve-path state.time --preserve-path state.produced --expected-version 3 --reset-test-data --serial emulator-5554
```

`--expected-version` describes the **new saved JSON schema**, at `version` by
default; `--schema-path` can select another dot path. It is independent of APK
version codes. `--new-expectations` optionally supplies additional nested
`expected_save` and `expected_numeric` assertions for the new app state.
The old input fixture must contain real taps/drags and nonempty saved-state
assertions; at least one critical `--preserve-path` or `--preserve-map` is mandatory.

For an intentional saved namespace rename, repeat `--preserve-map OLD=NEW`.
For example, campaign-core schema 4 moves the entire old `state` object to
`active_run`, while `settings` keeps its name:

```powershell
python scripts/android_upgrade.py --from-apk .artifacts/old/gear-bastion.apk --to-apk .artifacts/new/gear-bastion.apk --package com.dsschiff.gearbastion --save files/bastion-save.json --actions scripts/smoke-actions/gear-bastion-0.2.1-upgrade-input.json --preserve-map state=active_run --preserve-path settings --expected-version 4 --new-expectations scripts/smoke-actions/gear-bastion-0.3-upgrade-expectations.json --reset-test-data --serial emulator-5554
```

Mappings are explicit; the verifier never guesses a rename or drops old fields.
Installer retention checks the old names before the new app launches. Migration
checks the declared old/new pairs, cold-relaunch stability checks the new names,
and the final comparison checks the original old values against the cold save's
mapped names. Whole-object comparison permits added dictionary keys but retains
every old key/value and array order/length. Missing paths and duplicate source
or destination mappings fail. Dot paths support explicit array indices.
The manifest records both path sets and every mapping. Numeric rules below are
unchanged by mapping. The campaign expectation fixture requires a fresh profile
with no campaign clears, medals, best records, challenge clears or ending flag;
schema conversion alone does not prove preservation or campaign progress.

The explicit `--reset-test-data` flag may uninstall the specified package and
its data **during initial emulator setup only**, before installing the old APK.
It permits repeating the test when a newer test package remains installed.
Without that flag no uninstall/clear occurs, and a fixture requiring fresh data
is refused. Physical device serials are always refused.

After actual old-version input, backgrounding captures the app-written old JSON.
The upgrade boundary uses `install -r` with no uninstall, clear or fixture writes.
Critical semantic paths must survive installation, the new app's migration/save
and a cold relaunch. Dictionary key order and newly added migration keys are
allowed; old values, list order/length and selected nested fields must survive.
Integer-valued numbers and booleans remain exact. Finite fractional floats allow
only JSON round-trip noise with relative/absolute tolerance `1e-12`; the manifest
records that policy. Material position/time changes and adjacent large integer
changes fail. The original strict-comparison failure packet is retained when
such serialization noise is diagnosed; it is not relabeled as a passing run.
Each new-version launch must also advance the app save's modification time
beyond its pre-launch value, proving a new persist occurred rather than merely
accepting the untouched old JSON. File times, inode and size are recorded;
nonadvancing timestamps fail conservatively. The default foreground settle is
six seconds before backgrounding, covering the current five-second autosave.
Screenshots, raw saves, runtime logs, command transcripts, exact APK archives,
hashes and expectation results remain in the ignored evidence packet. Screenshots
still require visual review. This verifier's source and unit tests alone do not
establish a successful Android upgrade or physical-phone compatibility.

## Gear Bastion 0.2.1 Iron Trial input fixtures

The versioned `smoke-actions/gear-bastion-0.2.1-trial-a-victory.json` and
`gear-bastion-0.2.1-trial-c-defeat.json` target APK code 3 and saved schema 3.
Both select Iron Trial, drag four generators from the tray, assign exits, Begin,
and select 2x speed. A buys two guards and two rangers for 52 brass; C buys four
guards for 48. Final assertions include all purchased piece positions/exits,
budget, encounter, outcome, wall, elapsed simulation time, and the army cap.

Reset only emulator test data before each case, with the code 3 APK installed:

```powershell
$apk = '.artifacts/gear-bastion/20261017T220126111874Z/gear-bastion.apk'
& 'C:/projects/active/.game-toolchain/android-sdk/platform-tools/adb.exe' -s emulator-5554 shell pm clear com.dsschiff.gearbastion
python scripts/android_smoke.py --apk $apk --package com.dsschiff.gearbastion --save files/bastion-save.json --actions scripts/smoke-actions/gear-bastion-0.2.1-trial-c-defeat.json --serial emulator-5554
```

Substitute the A fixture for the mixed-army case. Wait events are bounded to ten
seconds each. A's original 60-second wait ended at simulation time 86.63 before
victory, so that packet remains failed. The same encounter subsequently won at
98.17 simulation seconds after 20 and 10 seconds of recorded continuation at 1x
(the lifecycle reinstall reset speed). Its adjusted 80-second fresh 2x fixture
is prospective and has not been replayed end to end. C's 60-second fixture did
run end to end and captured defeat at simulation time 65.63.

Retry is a separate manual assertion after preserving C's defeat screenshot and
JSON. Tap screen `(900, 1337)` at the reference 1080x2400 geometry, then background
the app and read its real save:

```powershell
$adb = 'C:/projects/active/.game-toolchain/android-sdk/platform-tools/adb.exe'
& $adb -s emulator-5554 shell input tap 900 1337
& $adb -s emulator-5554 shell input keyevent KEYCODE_HOME
& $adb -s emulator-5554 exec-out run-as com.dsschiff.gearbastion cat files/bastion-save.json
```

Require schema 3, `recoverable=true`, a later revision, Iron Trial/ready, 54 brass,
zero spent/time/wave, wall 160, empty actors/production, and exactly the initial
core and drive. The observed Retry packet checked 22 exact fields plus revision
and board count. Actual images, JSON, transcripts and continuation helpers live
under the ignored `.artifacts/gear-bastion/independent-49bee21/verification.json` index and its
linked packets. These two encounter cases do not establish phone performance,
physical folding behavior, or completion of the game's campaign.

Android smoke fixtures may use {"type":"key","key":"BACK"} for actual Android Back. BACK is the only permitted key; unknown action/key values fail. Home lifecycle transitions remain separate runner actions. Code-version fixtures under smoke-actions specify their required starting campaign state and display geometry; do not substitute a tutorial fixture for campaign update evidence.

Code 4 campaign update uses `gear-bastion-code4-campaign-upgrade.json` from an
archived fresh `camp_01` ready save. Preserve entire `active_run`, `profile`, and
`settings` with `android_upgrade.py --preserve-path` for each. Code 4's pinned
config has no `deployment_seconds`; confirm that it remains absent after the
code 5 update, where the runtime default is zero. No reset is needed at this
update boundary.

For code 5, `gear-bastion-code5-campaign-a-ready.json` creates Plan A using the
ready board at logical y=500. Begin uses native `(882,1821)` at 1080x2400;
the running board then moves to logical y=660. `gear-bastion-code5-back-live.json`
requires a running battle and records separate Back pause/map/resume and menu
checkpoints. Main smoke assertions check final JSON only; compare checkpoint
saves and inspect screenshots for intermediate transitions. The original
exploratory sequence is preserved separately and is not the Back assertion
packet.

`gear-bastion-code5-campaign-a-win-continuation.json` resumes that actual Plan A
battle from the cold map and waits 200 real seconds in capped ten-second
actions. It is a continuation, not a fresh complete-board recipe.
`gear-bastion-code5-disconnected-defeat.json` starts mission 1 from the map after
the earned clear, leaving its starter guard disconnected. Preserve the loss
before Retry. From the terminal game view, Retry is `(882,1393)`; require ready,
30 brass, wall 220, zero time/spend/actors, three starter pieces, and exact
profile/settings retention. Geometry fixtures `code5-cover-ready` and
`code5-inner-ready` require this ready save and run respectively with
`--display-size 1080x2520` and `--display-size 1968x2184`; they move the starter
guard out and back while retaining the earned clear. These are emulator
approximations, not physical folding tests.

The immutable code 5 APK passed saved victory/loss assertions but has a confirmed
terminal redraw finding: the live display can retain its prior battle frame
after the saved result changes. Data assertions do not accept that terminal UI.
Keep the original screenshots and the later cold-map-resume terminal screenshot
separate when reviewing this checkpoint.

The code 6 fixtures separate old saved content from fresh content:
`gear-bastion-code6-from-prepared-code5.json` requires the touch-built, paused
code 5 Plan A save and earned `camp_01` clear; preserve entire `active_run`,
`profile`, and `settings`. Use
`--new-expectations scripts/smoke-actions/gear-bastion-code6-upgrade-expectations.json`
to require the pinned definition-1 config and two-second deployment delay after
the update. Its preparation inputs and app-written save files are separate
evidence; the resume-only update fixture does not fabricate a prepared run.
`gear-bastion-code6-old-code5-prepare.json` records those actual preparation
inputs for code 5, starting on the map with a fresh ready mission and the earned
clear retained.

Start a fresh mission through the actual map/confirmation UI before
`gear-bastion-code6-natural-campaign-a-win.json`. It requires definition 2 and
performs real board input, then waits without post-Begin touches. Follow with
`gear-bastion-code6-natural-disconnected-defeat.json`, preserving the earned
profile. In each packet, validate `after-input.png` with `PIL.Image.load()` and
visually require respectively GATE HELD + Next gate or WALL BREACHED + Retry.
This screenshot precedes Home; JSON phase alone does not verify terminal UI.
Keep later lifecycle/resume images separate from the untouched terminal image.

The bounded code 6 clipboard check uses the app's own Copy save button. At
1080x2400 the dialog buttons are Copy `(208,1380)`, Paste `(494,1380)`, and Import
`(776,1380)`. Focus its TextEdit, send actual Android Ctrl-End
(`input keycombination -t 100 113 123`), then type `X`. Require visible `==X`,
Invalid save/current game retained, and unchanged run/profile/settings. Paste
must replace the edited code, and Import must close the dialog with the battle
paused. Resume must advance simulation; Home followed by app resume must hold
the saved run while showing PAUSED. This manual keyboard check does not expand
the smoke runner's BACK-only key whitelist. No clipboard or save-file injection
is involved. Preserve strict serialization-roundoff observations separately;
semantic comparisons use the existing fractional-float-only 1e-12 policy.

Tower Trials code1 has three sequential native-resolution fixtures:
`tower-trials-code1-natural-equality-loss.json` begins from a new first watch;
`tower-trials-code1-natural-first-win.json` uses Retry from that saved loss;
`tower-trials-code1-prepare-campaign-upgrade.json` starts from that victory,
clears the second watch, loses/Undoes the third watch's empty ferry, then takes
the key ferry and changes settings. Require the untouched pre-Home captures to
show LANTERN EXTINGUISHED and KEEPER RESCUED for the first two packets.
The final fixture leaves catalog1/watch_03/actions `["key"]`, power14/Keys1,
two earned clears, sound off, reduced effects on and used_undo true. These
are actual tap-created saves for the future install-r update check; do not
inject the expected JSON or count the old four-puzzle APK as a full campaign.

Hook and Hunger uses checksum-wrapped alternating slots rather than one plain
save file. For its update check, pass `--save files/hook-save
--alternating-envelope` to `android_upgrade.py`. The runner archives each
present stable slot, checks its payload checksum/revision, selects the newest,
and compares the decoded `state` and `settings` fields. A normal first write
can have only slot0. Any corrupt present slot fails the observation; this mode
does not silently treat corruption or a staged `.tmp` as accepted recovery.
Game-level validation and interrupted-save recovery remain separate checks.

The prepared code1 Android packet is indexed in
`android-games/evidence/hook-prototype-code1.json`: actual upward drag and
nearby combat earned two kills/salvage14, hull6, seven hits and approximately
eight simulation seconds. Actual controls set sound off/reduced effects on;
Home retained the whole state/settings. This is an old-version fixture from
the original pre-import-fix APK, not a full-game or update acceptance result.

Tower's tested code1→2 fixture is
`tower-trials-code2-from-prepared-code1.json`, with
`tower-trials-code2-upgrade-expectations.json` as `--new-expectations`.
Use `--schema-path schema --expected-version 2` and preserve every old saved
field except schema/revision: actions, catalog, level, level_id, profile,
settings, used_undo and recoverable. This resumes the separately prepared real
key-ferry route, not a synthetic save. The actual update preserves catalog1.

Run `tower-trials-code2-continue-legacy-key-route.json` from that migrated route
to spend the key and rescue the ferry keeper. Its untouched terminal capture
must show power44/Keys0/KEEPER RESCUED. Then
`tower-trials-code2-natural-campaign-defeat.json` selects catalog2's first watch
through Journey and loses to equality. Follow with
`tower-trials-code2-natural-campaign-retry-win.json`; require pre-Home
LANTERN EXTINGUISHED and KEEPER RESCUED captures, respectively. All three
fixtures preserve the two earlier clears plus the newly earned ferry clear.
These bounded Android outcomes do not establish a full36-puzzle Android run.

The Hook campaign-update precondition now uses actual old-version Retry:
`hook-and-hunger-code2-from-prepared-code1.json` starts from the archived dock
save with hull100, salvage14, two earned kills, one recovery and changed
settings. The preceding raw packet proves HULL BREACHED and the actual Retry;
no JSON is injected. Use the normal six-second launch settle: a one-second
probe captured the Godot splash and did not prove UI readiness. At the safe
dock, old-version enemy AI stays inactive while launch settles.

For the future different-APK test, use `--save files/hook-save
--alternating-envelope --expected-version 2`, preserve whole `state`,
`settings` and `committed`, and pass
`hook-and-hunger-code2-upgrade-expectations.json` as `--new-expectations`.
The precondition has been checked against the real archived code1 packet;
the campaign-APK migration assertions remain unexecuted until that APK is
frozen. Bounds on the setup clock/location do not relax the separate whole
saved-state comparison across the update.
