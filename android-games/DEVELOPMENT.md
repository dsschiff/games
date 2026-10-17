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

## Verification labels

- **Implemented:** source and intended behavior exist.
- **Automatically verified:** named rule/input/packaging checks have actual evidence.
- **Ready for phone testing:** verified APK is delivered with known limits.
- **Phone tested:** a physical-device check has been recorded; emulator results do not qualify.

The probes are pipeline fixtures. They do not count as completed games, final artwork, reference-fidelity acceptance or measured phone performance. Desktop QA may use the Dummy audio driver when WASAPI is inaccessible; this does not verify actual sound output.
