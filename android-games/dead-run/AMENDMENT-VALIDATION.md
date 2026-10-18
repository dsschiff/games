# Campaign validation amendment

Amends builder commit `0aebe4c144aec08fc781d653f5f979fa0a6d8789`, independently
integrated by root as `133883877f64202a2c58ca1c608a446e968911b3`.
Only two production functions change. Definitions, gameplay, balance, UI, schema,
version and export preset remain unchanged.

## Corrections

`campaign_data.gd: same` now requires exact numeric equality whenever either
operand is an integer or a mathematically integral float. Thus `24.0` remains a
valid JSON representation of 24, while `24.0000000001` cannot pass as a pinned
firing period. Nonfinite numbers are rejected. The existing fractional-float
round-trip tolerance remains restricted to finite, genuinely fractional operands.
The unchanged importer validates before normalizing valid whole-number floats;
it never casts or rounds a malformed fractional period into acceptance.

`campaign_rules.gd: valid` performs the existing boss shape/value/death checks
before hazard validation can read boss death. Missing, null, array, scalar and
malformed dictionaries reject cleanly. The pre-spawn chronology check remains
after tick validation. No boss conditions or hazard rules were relaxed.

## Evidence

Nine headless runs passed with zero script errors. [AMENDMENT-VALIDATION.json](AMENDMENT-VALIDATION.json)
binds exact runtime deltas, raw/LF execution manifests, receipts, retained
sensitivities and artifact hashes. **1,610 new artifact rows** were verified.

| Coverage | Checks |
| --- | ---: |
| Focused validation/import suite | 3,548 |
| Campaign rules, all roads, seeds and storage faults | 226 |
| Complete actual engine-input journey, ending, alternatives and replay | 115 |
| Genuine code1 migration/parking/import/cold restoration | 11 |
| Individual period-near, boss-null/array/missing and whole-float controls | 4 each |

The focused suite mutates all 875 integral definition leaves on the final-road
schema by a representable near-integer amount. Each mutation must fail the direct
validator and a correctly checksummed import. It also covers periods above/below
the integral boundary and outside the old tolerance, ten malformed boss forms
with a cancelled source=-1 hazard, finite-number handling and large-int precision.
Valid whole-number-float definitions normalize and step through ordinary modulo
firing cleanly. Late boss/profile fixtures are explicitly fabricated structural
fixtures, not earned gameplay or native evidence.

The **same final regression and runner bytes** were executed in an isolated plain
source copy containing the frozen production files. Old period-near produces
three failed assertions and the int/float modulo error. Old boss-null, boss-array
and missing-boss each produce two script errors, one through direct validation
and one through checked import. Those old boolean-return assertions can appear
to pass despite the engine errors; the strict runner correctly rejects each run.
All corresponding corrected cases pass with zero errors. The whole-number-float
control passes on both sources. Malformed checked-save bytes agree across each
old/new pair. Raw failed logs, commands, fixtures, sources and receipts remain in
`.artifacts/p2-final-regression-old-project/.artifacts/`.

Root's original reproducer and raw outputs were also copied byte-for-byte into
`.artifacts/p2-root-adversarial-origin/`, with an origin receipt. Initial local
sensitivity runs and the earlier successful 3,542-check test draft remain retained;
the final suite adds two additional period-boundary cases for 3,548 checks.

All 24 new journey outcome records exactly equal the frozen journey. The genuine
revision384 native fixture's entire legacy body and settings compare exactly with
the new migrated desktop snapshot, and its new campaign profile is empty.

All **2,720 frozen campaign receipt rows** and AVI/MP4 hashes were reverified.
`CAMPAIGN-CHECKPOINT.json/md`, original GDScript tests and movie files remain unchanged.
Original footage is bound to the frozen commit; it is not repinned or claimed as
new-source footage. The amendment documents were added after headless capture;
each run retains its actual executed raw/LF sources. Only the two production
files differ among the 28 runtime files.

Reproduce from the assigned worktree:

```powershell
python android-games/dead-run/tests/run_desktop.py validation-headless
python android-games/dead-run/tests/run_desktop.py validation-headless --validation-case period-near
python android-games/dead-run/tests/run_desktop.py validation-headless --validation-case boss-null
python android-games/dead-run/tests/run_desktop.py campaign-rules
python android-games/dead-run/tests/run_desktop.py campaign-headless
python android-games/dead-run/tests/run_desktop.py migration-headless
```

No new rendered/GPU/clipboard/foreground use, shared edits, pushes, exports,
APK/ADB/device operations, agents, repositories or worktrees. Stop after the
scoped clean follow-up commit for independent root rerun, Astra closure and native
gates. Physical-device performance, IME and human pacing/fun remain separate.
