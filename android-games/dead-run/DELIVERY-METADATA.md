# Standard-template SDK override correction

Metadata-only correction after failed attempts at `9952c89` and `0771fa8`.
Root's first Android export rejected the Min/Target SDK overrides because this
preset uses the standard non-Gradle template. The next attempt changed their
values to the strings `"0"`, which remained nonempty overrides and failed with
the same errors. **Both `gradle_build/min_sdk` and `gradle_build/target_sdk` key
lines are now removed entirely**, matching Hearthguard's standard preset.
Gradle remains disabled; no custom template or tool installation. The zero-string
attempt did not establish a working export; the corrected export remains pending.

The official pinned Godot4.7.2 template supplies min SDK24/target SDK36, as recorded
in Hearthguard's existing `DELIVERY-METADATA.md` and `delivery-metadata.json` from
its read-only template manifest inspection. This amendment does not independently
export or inspect a Dead Run APK. Root will verify the resulting APK's actual SDKs,
package, ABIs, permissions and signature. Package com.dsschiff.deadrun, version
0.1.0/code1, arm64-v8a+x86_64 and no enabled/custom permissions remain unchanged.

All runtime, tests, UID/icon metadata and prior reports stay byte-for-byte unchanged
from9952c89. Existing runtime evidence and original old-source movie retain their
original bindings. Only the two SDK override key lines and these delivery records
change. `delivery-metadata.json` binds the preset, unchanged runtime/tests and
retained copies of both root failed-export consoles/manifests. No runtime suites were
repeated for this metadata-only change.

No builder APK export/build, ADB, clipboard, device operation, shared-file edit,
global setting edit, push, campaign activation, agents/goals/chats or credential
change. Freeze scoped metadata commit and stop for root's export/native checks.
