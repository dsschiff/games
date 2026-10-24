# Verified Tower save destinations

The store previously returned the rename result without reading its destination.
Backup promotion also trusted rename. A backend that returned success while
leaving a missing, corrupt, or different-but-valid destination could therefore
report a committed import or continue past an unverified backup.

Before editing storage, the real Store/fault-backend reproduction failed 30 of
70 assertions: all 18 injected false-success cases returned true, and 12 backup
cases cold-adopted the imported context rather than keeping the previous one.
The original failed packet is retained at
`.artifacts/design-cpu-20261024T005512135998Z`.

Only `scripts/save_store.gd` changes at runtime. Both rename stages now require
the destination to exist, match the intended bytes exactly, and decode as a
valid save. Failure restores checked staging bytes if the rename consumed or
changed them, which preserves sole `.bak.tmp` recovery in the injected fault
cases. An unverified backup stops the write before staging the new import.
Existing recoverable=false import staging stays excluded from cold `.tmp`
recovery. A recovery-write failure still reports failure; this does not promise
recovery from a backend that destroys all copies and rejects every restoration.

The main import guard already assigns `data` and calls `load_run` only after a
successful Store.write. It remains unchanged. No UI abstraction or injected
filesystem hook was added to main. Schema, rules, catalog, painter, active
snapshots, version and signing are unchanged.

The before fixture is the exact app-written desktop touch-earned save supplied
by the coordinator's Tower motion run, retaining its earned clears and Undo.
Its SHA-256 and source receipt hash are in
`tests/fixtures/save-commit-before.provenance.json`. Test setup wraps that context
at revision seven to exercise staged recovery; a separately labelled generated
seed-137 challenge variant retains the earned campaign context. Neither variant
is claimed as additional human or Android progress.

Final focused run `.artifacts/design-cpu-20261024T005733366446Z` passes 70 checks.
It covers missing/corrupt/wrong-valid false-success destinations at primary and
backup stages, sole staged-backup survival, exact whole previous cold context,
unchanged caller dictionaries, stopping before new import staging, and normal
staged recovery/next-revision commit. The backend records actual write paths so
the backup-stage check cannot pass merely because a later rename consumed tmp.
The CPU runner now also pins JSON fixtures used by the tests.

The fixed runtime's broad run
`.artifacts/design-cpu-20261024T005617428087Z` passes rules/save 3,503 checks,
challenge rules 3,105, actual campaign input 1,363/587 taps across 36 watches, and
seeded challenge input 175/115 taps. These tests use Dummy audio and headless
Godot. No renderer, browser, clipboard, export, ADB or Android operation was used
for this audit. Native fault injection and power-loss behavior are not claimed.
`SAVE_COMMIT.json` binds all retained receipts, logs and fixture provenance.

Reproduce:

```powershell
python android-games/tower-trials/tools/design_check.py save_commit run_tests campaign_playthrough challenge_playthrough
```

Post-commit verification: `.artifacts/design-cpu-20261024T010357212865Z` also
passes the existing headless graphics_view suite, 252 checks, three actual taps
and two Back requests. No source pin or test expectation changed. Runtime save
fix commit `69ca9f2` remained frozen, and no Dead Run Godot process overlapped.
