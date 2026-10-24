# Retry marker admission and survivor safety

Actual same-owner Retry Import and Keep Previous could consume the last recovery marker or reuse stale cached admission. A valid stage marker was rewritten/promoted on retry; a backend reporting successful rename with a missing destination consumed it. With an imported active candidate already written, fresh startup could silently select that imported context while the live owner still showed the previous save. Separately, cached `journal_ready` allowed active writes after a marker became torn. A matching base plus a conflicting stage was also dangerous: partial cleanup could remove the base and make the unrelated stage cold-authoritative.

The scoped helper correction uses fresh admission for every resolve. It checksum-decodes the complete intended record, validates **every** present base/stage artifact against that entire record, and reuses matching artifacts without write or promotion. All existing artifacts must agree, so every possible partial-cleanup survivor describes the same transaction. Only an absent pair may create a checked first marker. Every archived code is revalidated before active mutation. A failed read invalidates cached readiness while retaining original/imported whole strings for export. Store, decoder, schema, rules, UI, versions and export are unchanged.

## Evidence

`MARKER_RETRY_CHECKPOINT.json` binds retained raw packets and source pins. The actual-input baseline finished **141 checks / 22 failures**, with **48 touch press/release events** and no raw runtime errors. Both choices demonstrated the sole-stage loss, stale cached admission and conflicting-stage cleanup defects. All four distinct raw candidates plus live and incoming complete codes were archived and compared exactly; actual-file fresh owners exposed the cold-state consequence.

The final serialized existing-cache CPU/headless/Dummy batch passes **437/0 marker**, **353/0 existing journal**, **65/0 Store recovery** and **386/0 pending-copy controls**. All four suites have the same **218** before/after/current source pins, exit zero and no raw errors/warnings. The marker suite has **80 actual touch events**. Its GUI cases cover both choices, sole base/stage survival, post-Store candidate unreadability, stale torn admission, matching-base/conflicting-stage cleanup and actual-file fresh owner recovery with complete state/settings/profile and all six exact archived raw/live/imported codes. Typed cases cover both conflict orderings, torn/checksum/unreadable artifacts, extra record fields, ordered copy lists, bad/missing selected archives and an unreadable additional archive, absent-pair write/rename failure, active missing/corrupt/stale rollback, post-Store read uncertainty, failed-read invalidation and a retained helper after confirmed clear.

A retained **303/18** test failure compared raw in-memory record numbers against owning JSON-decoded numbers in its active-write observer, and incorrectly expected a fault-created torn marker to heal after the transient fault lifted. The observer now compares complete records through the owning journal decoder, without masks; the latter test correctly requires the torn marker to stay blocked. Its explicit backend restoration restores only injected test state. No runtime behavior was changed to satisfy those incorrect test assumptions. One superseded successful probe was removed after final verification; both failed packets and all four final receipts remain.

Rerun from the worktree root, serially:

```powershell
python android-games/gear-bastion/tests/run_recovery.py --marker
python android-games/gear-bastion/tests/run_recovery.py --journal
python android-games/gear-bastion/tests/run_recovery.py
python android-games/gear-bastion/tests/run_recovery_copy.py
```

## Review and limits

Astra cleared the runtime algorithm, coordinated with the independently reviewed Dead Run all-present-marker contract. Astra independently verified all 18 retained artifact hashes, 214 unchanged current/base LF pins, four changed LF pins and all four receipts’ identical 218 before/after/current raw source pins. The scoped source/CPU checkpoint is clear for commit. Permanent torn, unreadable or conflicting metadata keeps play and saves paused. A known owner retaining validated original/imported choices can still export those complete codes. A cold owner with no decodable marker offers only Retry recovery read, without copy enumeration. The product does not automatically repair/delete uncertain metadata. Lifting an injected fault or restoring original marker bytes in a test is not an implemented user recovery feature.

Fresh-owner checks materialize files and rebuild a scene in the same headless process; they do not establish Android restart, power-loss durability, native clipboard, rendered readability or physical-phone behavior. No GPU/native/build/signing/upload/version action occurred. The sealed native Gear packet and all earlier reports remain untouched.
