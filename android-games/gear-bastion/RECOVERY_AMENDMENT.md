# Gear local Import durability amendment

This bounded source change preserves progress schema 4, its version 1-3 decoding, all active encounter snapshots, campaign/profile meaning, settings, gameplay rules, art, version and export configuration. Gear stores one active campaign or practice run plus the shared campaign profile; it has no parked second run to invent or discard.

## Reproduced defects

At base `ef217f9`, the owning Store accepted a backend rename returning true even when the promoted destination was missing, corrupt or stale. The first source-bound CPU receipt records **56 checks / 36 failures**; actual Import adopted the incoming context or claimed success without the required durable destination. After adding destination verification, a successful rename followed by an unreadable readback still produced **59 checks / 3 failures**: old live context, incoming cold context and the inaccurate “current game retained” claim. Both failure packets remain unchanged. They are injected faults, not observed phone failures.

## Transaction and owner

Ordinary Store writes now require the promoted backup and final destination to contain the exact staged bytes and pass the owning decoder. If a failed backup promotion consumed the sole valid `.bak.tmp`, the writer re-establishes that exact stage before returning false. Ordinary saves retain their bounded four-candidate rotation; they do not create recovery archives.

Import first preserves the exact incoming code, a complete encoded live context (including unsaved settings/profile) and every readable valid raw primary, `.tmp`, `.bak` and `.bak.tmp` code in content-addressed local copies. These copies are outside active candidate rotation. Only after those copies and a checksum-checked pending journal are promoted and read back may Import modify active slots. A journal stage also blocks bootstrap if its promotion was uncertain. The small journal is private recovery bookkeeping, not a progress schema revision.

The single Gear owner reads recovery once before choosing its startup context. A readable pending record supplies the original whole context; an unreadable marker blocks default presentation and all gameplay/save routes. Board edits, mode/mission changes, Retry/Begin, settings actions, simulation, periodic autosaves, lifecycle saves and Back cannot bypass this gate. The pending panel leads with previous/imported summaries, offers Retry Import or Keep previous whole save, and permits read-only viewing/export of both exact codes. Missing/torn recovery retains a retry-read explanation and local files; it never silently bootstraps a default.

Both choices use the owning Store, verify the complete state/settings/profile, and verify absence of both journal locations before synchronous adoption from that same checked context. A false or uncertain write/read/delete leaves the original live context frozen. A retained helper invalidates its journal admission after cleanup and must persist a marker before a later write. Successful adoption remains paused and names the next actual action: Begin, Resume or Retry.

## CPU evidence

`RECOVERY_CHECKPOINT.json` pins exact receipt hashes, current normalized-LF source hashes and unchanged compatibility files. All runs use isolated APPDATA/LOCALAPPDATA/TEMP/TMP and headless Godot 4.7.2 with Dummy audio. Final tests:

- Destination and original transient read regressions: **65/0**, 24 touch events. Current assertions require pending ownership and original whole context on fresh bootstrap.
- Journal matrix: **353/0**, 234 touch events. Eighteen practice/campaign original/imported choices; both explicit GUI choices; immediate live and disk equality before teardown; real-file fresh-owner bootstrap; unsaved settings via actual menu input; all four raw candidates plus live/incoming exact copies; missing/corrupt/stale destinations; first and second post-commit reads; archive/stage/marker/cleanup faults; torn/missing recovery; owner destruction/reopen; one-read startup windows; retained helper re-entry; schema 3 and Iron Trial; rule-derived victory/defeat; cover/inner/landscape inset geometry and scrolled button input.
- Existing transfer/presentation input: **1466/0**, 202 events. Its Import assertion now expects deliberate paused adoption of the same complete context.
- Existing rules: **164/0**. Existing real-input phase/lifecycle/terminal suite: **39/0**, 136 events. Those two packets precede only the final phase-specific recovery message and runner receipt-collection changes; those exact later source differences are listed in the checkpoint.
- Final headless editor import generated no source changes; the four new script/test UIDs are included. Runtime logs reject errors, warnings and ObjectDB leaks. Harness-target/typing/report-collection failures are retained separately, not reclassified as passes.

Re-run from the repository root:

```powershell
python android-games/gear-bastion/tests/run_recovery.py --prepare --journal
python android-games/gear-bastion/tests/run_recovery.py
python android-games/gear-bastion/tests/run_recovery.py --input
python android-games/gear-bastion/tests/run_recovery.py --rules
python android-games/gear-bastion/tests/run_recovery.py --phase-input
```

## Remaining gates

These are CPU/source checks with synthetic fixtures and typed backend faults. `physical_boot()` destroys an owner and creates a fresh one from actual materialized files **in the same process**; it is not an OS/native restart, power cut or filesystem flush guarantee. CPU geometry does not establish rendered readability. Coordinator review/integration, Android recovery input/cold checks, physical Fold7, clipboard export and actual interrupted storage remain separate gates. No cloud lease, native transport or online protection is implemented here, and no release/build/version change is included.
