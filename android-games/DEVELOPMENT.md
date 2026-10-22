# Android development

Use the pinned toolchain in `toolchain.json`. The portable Windows installation lives outside tracked source in `C:/projects/active/.game-toolchain`; `GAME_TOOLCHAIN_ROOT` can override that location. The existing HTML/CSS website in `docs/` is independent.

## Commands

From the repository root:

```powershell
python scripts/install_toolchain.py --accept-licenses --with-emulator
python scripts/portfolio.py status
python -m unittest discover -s tests/tooling -v
python scripts/portfolio.py test input-2d combat-3d
python scripts/portfolio.py build input-2d combat-3d
```

The installer verifies pinned download checksums, keeps SDK/editor configuration local, and does not change global PATH or Windows virtualization settings. It requires the configured Java installation. SDK license acceptance is explicit in the installer command. Emulator acceleration is a host prerequisite; do not change Windows features automatically.

The runner discovers actual `project.godot` files recursively under `android-games/`. A missing project is not an implemented game. Test mode requires both rule and input-driven playthrough suites; absent playthrough coverage is partial with a nonzero exit. Each suite must print `SUITE_COMPLETE: PASS` only after its assertions finish and return zero. Runtime/parse errors invalidate a zero process exit.

## Evidence and saves

Logs, APKs and SHA256 manifests live in ignored `.artifacts/<project>/<run>/`. Manifests record tool versions, Git revision/dirt, project source fingerprints before and after execution, exit codes, and APK hashes. Source drift invalidates the run. A successful APK export is separate from installation, gameplay, lifecycle, update and physical-phone evidence.

Desktop test runs isolate `user://` under per-run writable AppData. Ordinary build/runtime tooling uses child-process environment overrides rather than changing Daniel's Windows profile. Production Android saves use each app's sandbox.

Keep stable app identifiers and signing identities across updates. Signing keys, export credentials, footage and machine data stay outside Git. Reinstalling an APK with replacement must preserve app data; uninstalling is not an update test.

The technical probes verify normal gameplay save/readback and recovery from a corrupt primary or an older valid primary when a newer temporary save is present. Production games must additionally support export/import and prior-version compatibility.

## Android navigation

Home/background and system Back are separate test paths. Godot 4.7 documents a distinct [Android Back notification](https://docs.godotengine.org/en/4.7/classes/class_node.html#class-node-constant-notification-wm-go-back-request), and [`SceneTree.quit_on_go_back`](https://docs.godotengine.org/en/4.7/classes/class_scenetree.html#class-scenetree-property-quit-on-go-back) defaults to true. Each complete game's navigation should explicitly close the active modal first, then pause or return to its menu while saving predictably. Test actual Android Back followed by relaunch and save readback; a passing Home smoke does not cover it. These are release checks, not a claim that the current prototype has lost data.

## Performance evidence

Keep opt-in capture local. Record actual render-frame intervals before simulation-delta clamping, device/OS/renderer, encounter and actor counts, effects settings, warmup, capture duration and frame count. Report median/p95/p99 intervals and slow-frame counts; label excluded pause/loading periods. Desktop fixed-step CPU timings and emulator observations cannot establish phone FPS. Android's [rendering guidance](https://developer.android.com/google/play/vitals/render) explains that non-View OpenGL games may lack the usual rendering statistics; verify measurement coverage before treating `gfxinfo` output as game-frame evidence. The 60fps target and heavy-encounter floor require actual physical-device captures and a separate playability check.

## Release signing and Google Play

Published builds are release-signed with one key shared by all of Daniel's personal apps (certificate SHA-256 `25:27:B2:60:9A:62:20:58:B0:19:83:18:B8:AD:D4:41:64:6E:A4:2A:B9:D5:20:C5:36:13:1F:58:28:1B:F0:3F`; RSA 4096, valid to 2126). The keystore and a `KEY=VALUE` file with `ANDROID_RELEASE_KEYSTORE`, `ANDROID_RELEASE_KEY_ALIAS`, `ANDROID_RELEASE_KEYSTORE_PASSWORD` and `ANDROID_RELEASE_KEY_PASSWORD` live outside Git; the agentic-workflow credentials map names the folder.

```powershell
python scripts/portfolio.py build dead-run --release --signing-env <signing file> --expect-signer-sha256 2527B2609A622058B0198318B8ADD441646EA42AB9D520C536131F58281BF03F
```

The values reach Godot only as `GODOT_ANDROID_KEYSTORE_RELEASE_*` variables in the child process. The manifest records the signer digest and fails a debuggable or wrongly signed APK. Release APKs are not debuggable, so `run-as`-based emulator fixtures cannot read their saves; run those fixtures on a debug build of the same commit. Publishing is described in `INSTALL.md` and the private releases repo README.

**Google Play (planned, not started).** Register this same key as the Play App Signing key ("use my own app signing key": export it with Google's PEPK tool using the encryption key Play shows), so Obtainium installs update from Play without reinstalling. Play also asks for an upload key; a separate upload key is safer, and losing it is recoverable, unlike the app signing key. Nothing has been uploaded.

**App bundles (.aab).** Play wants an `.aab`. The Godot projects export APKs with the prebuilt template (`gradle_build/use_gradle_build=false`); Godot writes an `.aab` only through a Gradle build. Per game that means installing the Android build template into the project (`godot --headless --path android-games/<game> --install-android-build-template`, which adds an `android/` directory to keep out of version churn), setting `gradle_build/use_gradle_build=true` and `gradle_build/export_format=1` in the preset, then `--export-release Android <game>.aab` with the same signing variables. That is a real build change per game, so it is recorded here and not done yet. Planetfall's Capacitor project can produce one with the standard Gradle task (`gradlew bundleRelease` in `apps/planetfall-pwa/android`, with the same signing variables); not run yet.

## Verification labels

- **Implemented:** source and intended behavior exist.
- **Automatically verified:** named rule/input/packaging checks have actual evidence.
- **Ready for phone testing:** verified APK is delivered with known limits.
- **Phone tested:** a physical-device check has been recorded; emulator results do not qualify.

The probes are pipeline fixtures. They do not count as completed games, final artwork, reference-fidelity acceptance or measured phone performance. Desktop QA may use the Dummy audio driver when WASAPI is inaccessible; this does not verify actual sound output.
