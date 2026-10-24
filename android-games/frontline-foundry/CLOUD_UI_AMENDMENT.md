# Optional Play Games controls and local recovery copies

This game-side increment connects an optional entry under **Save / Transfer** to
an actual `PlayCloud` singleton bridge. The bridge requires both metadata-only
`is_configured()` and acknowledged `cancel(id)` in addition to the existing
`request`/`completed` API. Missing plugin, missing lifecycle API or missing app
configuration produces a truthful unavailable panel. It does not substitute a
fake transport. Launch and opening an unconfigured panel make no SDK, sign-in,
network or upload request. No automatic connection, backup or restore is added.

Local saves remain immediate during ordinary offline play. Opening the optional
panel pauses the game and freezes gameplay, settings, mode changes, autosaves
and lifecycle writes until the panel closes or ownership passes to local Import.
Explicit Close irrevocably cancels local adoption and leaves the ordinary game
paused immediately, even if SDK work or native cleanup never finishes. Offline
play/settings/autosaves can then continue. Native cleanup remains independently
owned and blocks another cloud request, not local play. Local retained copies can be browsed and their
complete codes selected/exported without an account, network or clipboard API.
Archive filenames are enumerated without opening every body; only the at-most
twelve displayed/retrieved records are decoded. Archive pages contain at most twelve entries; selecting one opens its exact
opaque code. Using a local copy requires a separate whole-context confirmation.

## Explicit account operations

**Connect** requests sign-in and observes the resulting account. **Check cloud
saves** reads the one Frontline slot. Whole-save summaries show actual mission,
phase, campaign clears/wins, legacy wins and scrap, alongside complete code
identities. No device revision is ranked as newer across devices. The player
can view/export the exact full code before choosing anything.

**Back up this device** and its confirmation are separate actions. An initial
backup attempt supplies an empty expected hash, allowing creation only when the
opened snapshot is empty. If a record already exists, `remote_changed` must be
validated and presented before a separate explicit overwrite confirmation. The
confirmation identifies both complete contexts; verified immutable copies of
local live context, all valid raw local candidates and remote choices are kept
first. The account and exact frozen local/disk identities are checked again
before dispatch. Expected hash protects the opened snapshot; it is **not an
atomic server compare-and-swap** and cannot prove cross-device exclusivity.

If Play Games returns two conflict copies, each is validated and displayed.
**Keep cloud 1/2 for conflict** has its own confirmation and only selects an
existing cloud copy through native `resolve`. It does not restore locally or
upload this device. Another conflict is displayed for another explicit choice;
no automatic merge, repeated resolve or overwrite is performed. A later backup
requires another comparison/confirmation. Newly returned choices are archived
before any destructive next request.

A native `submitted` response is labelled **submitted**, possibly cached offline.
It does not establish server durability or cross-device sync. While write or
resolve is outstanding Close remains available and explicitly warns that the
cloud operation may still complete; dismissal never promises to undo it. Failures
state that a submission may have reached Play Games; the player must check
again. Cleanup acknowledges resource release, never reversal of a remote effect.
No claim of online backup protection is made by unavailable or submitted states.

## Local restore and lifecycle ownership

All remote and local-copy restores call the existing `start_local_import` path.
The new cloud flow never calls `Store.write` or independently adopts live state.
It first archives all complete contexts, rechecks the account for a remote
choice, awaits native resource cleanup, observes the account again after that
cleanup and checks exact local context/disk identity immediately before handoff.
This is a final observation, not an atomic account lock.

`cloud_held` remains set until `ImportRecovery.begin()` establishes
`import_pending`, or returns a proven prewrite failure. The existing durable
journal owns every subsequent uncertain write, retry, explicit Keep Previous,
cleanup, fresh catalog bootstrap and paused whole-context adoption. Closing or
destroying the cloud panel cannot release that Import freeze. Scene replacement
uses the previously reviewed one-shot validated Boot handoff.

The native port retains its cleanup owner independently of the panel. Request
IDs include an instance identity; stale/duplicate completions are ignored.
Cancelled reads cannot deliver a late cloud choice. Account-rejected/invalid
responses go through acknowledged cleanup before another action. Native cleanup
must await all admitted SDK callback flights and original-client snapshot closes.
`close_failed` retains ownership and blocks new cloud admission until explicit
retry. A reopened panel can recover the retained owner, and its Close still
returns immediately to offline play even when cancel never acknowledges. No current-account
`discard_conflict` call is used as a substitute for cancellation.

## Evidence and remaining gates

A fresh worktree first needs its ordinary Godot resource import (`--headless
--audio-driver Dummy --editor --path android-games/frontline-foundry --import
--quit`), using the pinned toolchain. This prepares local caches without rendering.
Canonical UID sources must remain unchanged.

Run `python android-games/frontline-foundry/tests/run_cloud_ui.py` for the focused
CPU suite, plus the existing `run_import.py`, `run_cloud.py` and campaign rules /
fresh-input runners. All use headless Godot and Dummy audio. The new suite uses
explicitly synthetic whole contexts and controllable account/native response
fakes; GUI actions are real ScreenTouch events. Those checks cannot establish
SDK/account connectivity, packaged plugin behavior or real cloud durability.
Failure receipts remain separate from final source-bound proofs.

The coordinator owns shared Kotlin/plugin packaging. No game version, export
preset, app identity, signing material, Play Games ID, tester/account setting,
backend, dependency download, upload, APK build, push or publication is included.
Live setup still depends on Play identity/phone verification, per-game project
and signed client configuration, Saved Games/tester enablement and privacy/data
declarations. Actual denial/offline caching/account switch, two-device conflicts,
server sync, signed native updates, rendered readability and physical Fold7 /
human acceptance remain open. Game-side implementation is not completed live
cloud delivery. Historical dormant adapter and local Import evidence remain
under their earlier checkpoints; this amendment does not rewrite those results.

The pending local Import screen now prioritizes previous/imported whole-save
summaries instead of raw JSON. Its separate read-only recovery-copy viewer keeps
full selectable export codes accessible without a native binding and cannot
release the journal freeze or start another restore. This is new source UI work;
the separately frozen code7 APK's native recovery check does not validate it.
