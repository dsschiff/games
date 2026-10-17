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
