# Android delivery metadata amendment

This amendment adds only an Android export preset, seven generated stable
GDScript UID sidecars, the generated icon import descriptor, and this separate
delivery record. The first-loop `CHECKPOINT.json` / `CHECKPOINT.md` remain the
historical frozen b6e4970 checkpoint. Gameplay, tests, README and original
evidence are unchanged. Campaign expansion remains on hold for root/Astra review.

The `Android` preset follows the existing standalone games: non-Gradle export,
unique package `com.dsschiff.hearthguard`, version **0.1.0 / code 1**, arm64-v8a
and x86_64 only, no enabled permissions or custom permissions, no embedded
signing credentials, and no fixed output path. Root's authorized delivery is
local personal **debug** export only. No store/public release is authorized.

Min SDK **24** and target SDK **36** come from the unmodified pinned Godot
4.7.2 official debug template, confirmed by reading its manifest with `aapt`.
No `gradle_build/target_sdk` override or custom template is used. The official
template contains zero permissions. Actual Hearthguard APK package, SDKs,
architectures, permissions and signature still require root's export checks.
No Hearthguard APK was exported or installed in this amendment.

Two headless editor imports passed without script/import errors. To avoid any
shared editor-setting writes, the import used byte-identical copies of the
existing portable executable pair and its existing configuration in this
game's ignored `.artifacts/` folder. The copied configuration already had
`export/android/shutdown_adb_on_exit=false`; no shared/global settings changed.
APPDATA and LOCALAPPDATA were isolated for each invocation. Generated UID/icon
metadata was identical on the second import, and all original twelve executed
files remained byte-for-byte intact. All fourteen original tracked files and
181 bound checkpoint artifacts were reverified before the amendment freeze.

`delivery-metadata.json` binds the new tracked metadata and the ignored import
logs, receipts, official-template manifest inspection and verification report.
Editor caches, copied tools/configuration, app data, APKs and signing material
are not tracked. No direct ADB command, emulator/phone operation, shared-file
edit, gameplay change or push occurred. Native checks remain root-owned.
