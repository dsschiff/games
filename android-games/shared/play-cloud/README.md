# Optional Google Play Games cloud recovery

Work in progress for the approved continuous design cycle. No game currently
loads this integration, and no cloud-enabled APK has been distributed. Local
gameplay/saves remain unchanged and require no Google account or network.

`cloud_backup.gd` transports a complete existing save envelope, bound to its app
package. It validates through the owning game's existing decoder. A checksum
detects corruption; it does not authenticate progress. Device-local revisions
must never rank cross-device saves. Conflicting progress needs readable summaries
and an explicit player selection; do not merge or auto-restore active runs.

The native Kotlin transport builds against Godot4.7.2 and pinned Google Play Games
v2 22.1.0. Independent source review clears staging/readback verification,
awaited original-client cleanup, consumed conflict handles, request generations,
account revalidation and bounded inputs. Twenty-one JVM regressions cover these
boundaries, including delayed Google Tasks. Game integration and live sync remain
unfinished. A successful SDK commit is submitted, possibly cached offline; it
is not server-durability or cross-device-sync proof.

Build and native unit tests from repo root: `python scripts/build_play_cloud.py`.
The builder downloads checksum-pinned official Gradle8.14.3, keeps dependency
caches on F:, reuses the existing SDK/JDK, writes ignored local settings and
records `.artifacts/cloud-native/build.log`. No account IDs or credentials are
embedded. Each game still needs its real Play Games project ID, matching signed
Android client, tester access and Saved Games enabled in Play Console.

Codec regression (real Dead Run decoder), from repo root:

```powershell
& C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --path android-games/dead-run --script <absolute-repo>/android-games/shared/play-cloud/tests/backup_tests.gd
```

The first pass verifies27 checks, with local-state preservation, exact opaque
roundtrip, wrong package, malformed/truncated data, UTF-8 byte limits, recomputed
corrupt-save checksums and future-schema rejection. This is not native network,
authentication, conflict or device acceptance.

`tests/real_save_bindings.gd` adds60 local checks across all six owning game
decoders. Representative records include a genuine old Dead Run active road,
actual Android active/result saves, fresh Tower input-earned progress and
explicitly qualified feedback/checkpoint fixtures. It compares the entire
decoded context, retains every opaque save byte and rejects future schemas even
when both inner and transport checksums are recomputed. Final Hook/Tower store
hashes were refreshed after write hardening. The manifest pins the test script,
codec, six logs/results and inputs; `.artifacts/cloud-save-bindings/manifest.json`
is machine-local evidence, not network or account acceptance.

Run with the owning project as `--path`, the absolute shared test script after
`--script`, and these arguments after `--`:
`--decoder=res://scripts/save_store.gd --save-file=<complete-save-file>
--package=<actual-app-package> --report=<output-json>`. Dead Run uses
`res://scripts/campaign_store.gd`. Use `--headless --audio-driver Dummy`.
Choose a real or explicitly labelled app-written fixture; never treat these
local checks as a restore commit, plugin UI, live authentication or cloud sync.

Before shipping: serialize restoration with
Dead Run autosaves; commit through each existing imported-save transaction and
confirm exact destination readback before replacing live state; resume restored
active runs paused; add opt-in UI; verify genuine two-device/offline/account and
conflict cases; update privacy/data declarations and signed delivery records.

Primary implementation references:
- https://developer.android.com/games/pgs/android/android-signin
- https://developer.android.com/games/pgs/android/saved-games
- https://developers.google.com/android/reference/com/google/android/gms/games/SnapshotsClient
- https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html
