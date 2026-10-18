# Ledger validation follow-up

Parent campaign checkpoint: `2b58feea60f668d1010b0b3722e661bfb392f98b`.
Branch: `codex/frontline-foundry`. Work is confined to this game directory.

The campaign validator checked the ledger array lengths before summing stock,
but validated their entries later. A correctly checksummed imported state with
a nonnumeric stock entry therefore returned rejection while emitting runtime
invalid-operand errors. This follow-up validates every bought/stock/consumed
entry's numeric type, finiteness, integer value and per-role pool bounds before
any ledger reduction or arithmetic. Later receipt and conservation checks stay
in place.

The only executable changes are `scripts/campaign_rules.gd` (validation order)
and `tests/campaign_tests.gd` (193 additional checks). Every position of each
ledger array is tested with a String, Dictionary, null, boolean, Array, negative,
fractional and over-pool value, both directly and through the full correctly
checksummed encode/decode path. A purchased/consumed valid state with whole-number
float entries remains accepted. Existing sub-microsecond arrival and positive
fractional-health cases remain accepted.

Focused headless verification:

| Run | Checks | Script errors | Result |
| --- | ---: | ---: | --- |
| Old validator plus new regressions | 412 | 140 | Expected runner failure |
| Fixed campaign rules/save/fault suite | 412 | 0 | Pass |
| Cold whole-state transfer | 16 | 0 | Pass |
| Genuine desktop legacy migration | 9 | 0 | Pass |
| Original catalog-1 rules | 69 | 0 | Pass |

The expected-failure and fixed rules archives differ only in
`scripts/campaign_rules.gd`; their test bytes are identical. Boolean assertions
alone report zero failures on the old validator, so the runner's explicit error-
log rejection is consequential to this regression. One accidental legacy test
invocation omitted its required fixture and failed its setup guard; that packet
is retained separately from the passing fixture-supplied invocation.

`tests/ledger-validation-checkpoint.json` records the exact candidate raw/LF source
maps, before/after source delta, executed-source maps, receipts, artifact hashes,
check counts and error counts. All original receipt artifact hashes were verified.
Its JSON is inside the already-excluded tests directory.

`CAMPAIGN_CHECKPOINT.md` and `.json` are unchanged. Their full input, rendered,
clipboard and three normal-speed movies remain evidence for parent `2b58`, not
newly executed evidence for this validator follow-up. No encounter definitions,
pacing, gameplay/UI, schema, version/package settings or legacy rule source changed.
The synthetic full arc remains 2220.5 seconds.

No foreground window, global clipboard, ADB, APK, SDK/editor settings, other-game
or shared-file changes, push or parent-chat message was used. Independent root/
Astra finding closure and native acceptance on the new source pin remain open.
