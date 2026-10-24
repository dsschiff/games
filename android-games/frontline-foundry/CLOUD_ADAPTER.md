> Historical dormant increment at `bd6e6e7`. Its local Import boundary was
> fixed separately. Current optional game-side UI work is described in
> [CLOUD_UI_AMENDMENT.md](CLOUD_UI_AMENDMENT.md). This retained snapshot does not
> describe current delivery or establish live cloud sync.

# Dormant cloud recovery adapter

This source increment adds a testable recovery controller. The released game does
not load it: there is no cloud button, native singleton lookup, account request,
upload, SDK conflict resolution, or automatic restore. The default typed port
reports **Not configured**. Existing offline scenes, rules, saves, art, export
presets and app version are unchanged.

The implementation is in `scripts/cloud/`. `codec.gd` is an exact byte copy of
`android-games/shared/play-cloud/cloud_backup.gd`, SHA-256
`a2fa77e5066fe226b441dcaa199cb4ed9c45b365adc2470959cea6d1e24d5b43`.
`vendor-source.json` pins that origin. `backup.gd` delegates the envelope contract
to the copy and uses Frontline's existing `Store.decode` to validate the complete
opaque save. It additionally bounds and validates native packet base64, UTF-8
and the packet checksum. The CPU runner checks the pin, exact vendor parity,
and bidirectional compatibility with the actual shared file. This vendoring is
needed for Godot project resource isolation; coordinator-owned packaging can
replace it later.

The future owner must supply a complete paused capture and three mandatory
synchronous callbacks: acquire a freeze, release it, and atomically adopt a whole
decoded context. The freeze must prevent gameplay, settings/mode changes,
autosaves and lifecycle writes while allowing cancellation. Releasing it must
leave play paused. Adoption returns the full adopted context and is checked
against a fresh capture. A signal connection, including a deferred connection,
does not satisfy this contract. `restore_committed` is a notification after
verified durable write and verified synchronous adoption.

The explicit flow is open, connect, check saves, inspect exact whole codes and
SHA-256 identities, select one record, then separately confirm replacing this
device's context. Device revisions are never compared to rank cloud copies.
Account identity is checked again immediately before writing. Complete live
state/profile/settings/career and exact bytes/existence of every local slot and
temporary candidate must still match the opening capture. Before committing,
immutable content-addressed files preserve the captured live code, every valid
local raw slot, and every remote choice. Each copy is read back and decoded;
failed preservation stops the restore. These files survive rotating-slot writes
and can be retrieved by their returned IDs through `Copies.get_code`. A user
interface for discovering/exporting those copies is still unimplemented.

Only the existing owning `Store.write(imported=true)` may commit the selected
whole context. It checks exact destination bytes and its decoder. A failed
commit cannot emit the successful-restore notification. After preservation, any unconfirmed write (including `Store.write(false)`) or a
successful write with uncertain later readback or incomplete adoption enters
`RECOVERY_REQUIRED`: the owner stays frozen, cancel/reopen cannot resume it, and
`retry_adoption()` must first repeat an unconfirmed write until exact destination
verification succeeds, then confirm the disk and complete adoption. The writer
can return false after a good rename if a verification read is transiently
unavailable, so false is not treated as proof that disk stayed old. Destroying the
adapter in that state leaves the owner's recovery freeze intact. A future owner
must preserve that blocked state until recovery completes; destroying the modal
must never implicitly resume old live state or autosaves.

Request IDs include the controller instance identity. Dismissed, duplicate and
previous-instance results cannot adopt. Returned conflict resources are recorded
before rejecting an account mismatch, then discarded using their owning account
and the port's original-client cleanup contract. Cleanup must be acknowledged
before reopening. The future native port must own acquired resources and late
callbacks independently of the UI, await original-client closes on abandonment,
and never replace an unavailable transport with the fake test port. No cloud
resolve/write operation exists in this increment.

Run CPU validation with:

```powershell
python android-games/frontline-foundry/tests/run_cloud.py
```

The matrix uses explicitly synthetic decoder-valid legacy, ready campaign and
active campaign contexts, including parked legacy context, settings, profile,
skirmish records and pinned mission definitions. It exercises both explicit
remote choices with unrelated revisions, exact copies surviving autosave
rotation, storage faults, stale live/disk/account state, dismissal and resource
cleanup, mandatory synchronous adoption and post-write uncertain readback.
Transport/account behavior is simulated; it does not establish real cloud sync.

**Known existing local Import boundary, outside this runtime scope:** both shipped
`main.import_code` and `campaign_main.import_code` can report “Storage failed.
Entire current save kept.” after rename succeeded but the second destination
verification read was temporarily unreadable. Live state stays old, but once
reads recover the newly valid higher-revision slot wins cold selection. The
fixture calls the actual existing handlers, then materializes their candidate
files and reads them through production `Store.read`. This proves handler and
file-based cold selection behavior, not a process/native restart or actual
touch input. The raw pre-adapter-fix975-check/4-failure receipt is retained. The
adapter now blocks and requires a verified-write retry for this uncertainty;
fixing the existing local Import UI remains a separate coordinator task. The
989-check final matrix includes eight explicit observations reproducing that
known unfixed boundary; passing those checks does not mean the Import issue is
fixed.
Current campaign rules and fresh isolated engine-touch input also pass. A
separately attempted legacy input suite failed its genuine earlier-save fixture
prerequisite; that failure is retained and is not replaced with synthetic earned
progress. Receipt paths and source hashes are in `CLOUD_ADAPTER_CHECKPOINT.json`.

Remaining integration depends on a packaged native port/resource contract,
per-game Play Games IDs, the existing signing identity registered with its OAuth
Android client, Saved Games enablement, tester access and the required account
and data/privacy setup. These were not created or guessed. Real account denial,
offline/cached behavior, account switching, two-device conflicts, server sync,
signed Android updates and rendered restore usability still need validation.
There was no dependency download, backend, GPU/emulator/browser, APK export,
version change, push or publication in this task.
