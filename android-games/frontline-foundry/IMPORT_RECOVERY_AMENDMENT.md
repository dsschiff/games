# Local Import recovery amendment

Local Import now treats an unconfirmed write as pending recovery. It keeps both
complete contexts, blocks play/settings/mode changes and local autosaves, and
offers **Retry Import** or **Keep Previous**. Keep Previous performs a verified
whole-save rollback. Returning to the game happens only after the chosen save
is verified and recovery metadata cleanup is confirmed. No cloud connection,
account request, gameplay balance, save-schema, app version or export changes
are included.

The before evidence is preserved in commit `bd6e6e7` and its
`.artifacts/cloud-cpu-20261024T015237608705Z/receipt.json`: both shipped Import
handlers retained old live state and reported “Entire current save kept” when a
successful rename was followed by a transient second destination-read failure.
After reads recovered, real file-based cold selection chose the imported slot.
Those eight historical observations demonstrate the defect, not a fixed Import.
The current cloud suite retains the same cases and requires pending recovery and
the original complete startup context instead of accepting the old behavior.

`import_recovery.gd` first validates the incoming code with the existing owning
Store decoder. It verifies immutable local copies of the captured live code,
all valid raw save/temporary candidates and the incoming code. Its small local
journal contains those content IDs; it is staged, read back, promoted, read back
and decoded before any active-slot write. The existing progress-save format and
rules remain unchanged. The journal's own version is independent bookkeeping.
The reused Copies helper performs only local storage; cloud Port/Recovery and
native/account operations remain unconnected.

Any uncertain active write/readback leaves the transaction pending. Session
bootstrap checks the journal before choosing either catalog, binds one validated
startup decision into the selected script, loads the complete original context
paused, and prevents autosaves. A readable staged journal also recovers safely.
A damaged recovery record stays blocked and explains that local copies remain;
it cannot offer a known previous choice until that record can be read. With no
safe current context it presents a retry-only view instead of creating a default
campaign. If promotion failed before any active write and no marker survived,
cold startup uses the untouched previous active save; immutable copies remain.

Either explicit choice writes through the owning Store and checks the complete
selected disk context before removing both journal artifacts and confirming
absence. Successful cleanup invalidates admission to active writes: a retained
owner must re-establish the journal before another choice. The strict
870-check/3-failure receipt preserves the reviewer-found counterexample where a
failed scene handoff could otherwise allow a second write without a marker.

The old owner remains frozen until a fresh Boot replaces it. A namespaced,
one-shot in-memory handoff carries the already verified complete context, is
consumed and decoder-validated once, and forces the new owner paused even for
ready or terminal saves. It is not persisted or used as evidence of disk commit.
Failed scene changes discard stale handoff metadata and retain explicit retry.
Fresh Boot also avoids the in-place legacy rebuild that produced four dummy
renderer material errors; those original strict failures are retained, with no
presentation edits or error filtering.

Run CPU checks with:

```powershell
python android-games/frontline-foundry/tests/run_import.py
python android-games/frontline-foundry/tests/run_cloud.py
python android-games/frontline-foundry/tests/run_campaign.py rules --label import-final
python android-games/frontline-foundry/tests/run_campaign.py input --label import-final
```

The focused matrix covers 32 actual-touch choices across legacy/campaign ready
and active contexts, both retry and rollback; 13 fault/interruption boundaries;
four one-read-window journal/archive cases across both catalog directions; and
unsaved live settings, retained-owner retry, invalid handoff, terminal handoff and
damaged-marker bootstrap cases. Complete profiles/settings/career/parked legacy,
pinned definitions and battle state are compared immediately in the new live
owner and after fresh bootstrap. The input code fixtures and fault backend are
explicitly synthetic. The ordinary campaign journey separately uses real engine
input with its established 8x time scale.

All checks are headless with Dummy audio. Materialized-file fresh bootstrap is
process-style evidence, not an OS-kill, Android restart or native update test.
UI bounds and label minimum height are CPU checks, not rendered acceptance.
No renderer/emulator/ADB/browser/clipboard, dependency download, APK, version
change, push or publication was used. Native cold/update/background behavior,
rendered recovery readability, physical Fold7 input, measured phone performance,
audible sound and human pacing remain coordinator-owned gates.

Exact source hashes, final receipts and retained failure paths are recorded in
`IMPORT_RECOVERY_CHECKPOINT.json`. `CLOUD_ADAPTER_CHECKPOINT.json` remains the
historical, unlinked cloud-adapter snapshot at `bd6e6e7`; this local Import fix
supersedes its explicitly noted production Import boundary without enabling sync.
