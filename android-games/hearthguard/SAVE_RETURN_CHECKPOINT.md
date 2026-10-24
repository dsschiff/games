# Save and return-flow increment — 2026-10-23

Unreleased source increment from7532385, confined to Hearthguard. No rules,
schema, catalog, encounter, version, signing or app-identity changes.

`SaveStore.write` now verifies that the promoted destination exists, matches the
exact staged bytes and decodes before returning success. The newest checked old
slot is preserved when rename reports success but drops or corrupts the target.
Failed imports retain the entire live campaign/legacy/profile/settings context
and display storage failure. Successful imports clear the old failure banner.

Both mode transitions build a deep staged campaign context. They replace live
parked/legacy fields and route only after verified promotion. Mode-transition
staging uses the existing unpromoted-import flag: a failed rename cannot leave a
recoverable temporary that silently changes modes on the next cold load. Ordinary
autosave recovery remains unchanged. No new save field or migration was added.

Home/focus loss pauses an active watch. Ready and terminal screens stay available
without an extra Resume gate. The manual log return says RESUME for active play,
BACK TO BRIEF for ready, and BACK TO RESULT after victory/defeat. Synthetic
notification coverage is separate from Android lifecycle evidence.

## Evidence

Exact SHA256-bound receipts are in
[SAVE_RETURN_CHECKPOINT.json](SAVE_RETURN_CHECKPOINT.json).

- 167 headless reliability checks pass on unchanged source: all four legacy/
 campaign import directions under missing/corrupt destination faults; failed
 writes and rename failures in both mode-switch directions; complete live-context
 retention; successful whole imports and parked-watch switches; actual cold app
 loads after materializing missing/torn/unpromoted fault slots; both modes in
 ready/active/victory/defeat return phases. Every serialized context value is
 compared after existing JSON normalization, including nonempty campaign and
 legacy records, both parked runs and settings. Text staging and rule-derived
 context fixtures are synthetic; Import/switch/log/Resume actions use engine
 ScreenTouch input. No clipboard is used.
- 127 campaign rule/config/storage checks and56 legacy rule checks pass.
- 44 actual legacy input checks pass: natural loss, Retry, coin collection, two
 paid towers, natural victory, transfer rejection/success, pause/resize and cold
 retention. Headless controls do not establish native touch or physical play.
- 328 CPU presentation/input checks pass. Exact rules/catalog/save_files and the
 full save envelope/decoder/read prefix remain pinned to the prior baseline.
 Only the explicitly authorized write transaction is excluded from its old
 graphics-stage whole-source freeze assertion.

The unchanged runtime baseline fails30 of107 reliability checks. It falsely
accepts missing/corrupt destinations, mutates live parked context before failed
mode promotion, omits failure feedback, and can adopt a committed temporary after
failed mode rename. The first harness run also had two overstrict paused
assertions on successful cross-mode terminal imports; those are qualified in the
JSON record. The first CPU presentation run fails its old whole-writer source pin
as expected; corrected328-check evidence is separate. Historical failures remain.

Reproduce silently from this worktree:

```powershell
python android-games/hearthguard/tests/run_campaign.py reliability --label review
python android-games/hearthguard/tests/run_campaign.py rules --label review
python android-games/hearthguard/tests/run_desktop.py rules --label review
python android-games/hearthguard/tests/run_desktop.py headless --label review
python android-games/hearthguard/tests/run_graphics.py checks --label review
```

All commands use Dummy audio. No renderer, GPU, emulator/ADB, browser, native
clipboard, APK export or physical phone was used. Root owns review/integration,
Android update/lifecycle checks and release. Next: verify the new error and return
labels during the next serialized native candidate check; human pacing/fun,
Fold7 folding/touch and phone performance remain unverified.
