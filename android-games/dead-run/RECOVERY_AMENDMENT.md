# Dead Run local Import recovery amendment

Source-only prerequisite for optional backup work. No cloud UI/transport, gameplay rules, save schema, game version, export presets, art or shared tooling changes. The complete schema2 context is the active mode, campaign, legacy bridge, profile (clears/medals/replays/ending), settings and loadout. Both bodies retain their bullets, event/claim ledgers and pinned definitions. The owning decoder preserves them; Gear's projectile-clearing behavior does not apply here.

## Reproduced failure and correction

At `c408eb1`, actual ScreenTouch Import through the campaign owner and legacy child could successfully rename an incoming primary, fail its following read, retain the original live context and say “Journey unchanged.” A fresh owner then selected the higher imported slot. The initial13/6 failure packet had empty bullet arrays. The stronger **16 checks / 6 failures** packet has three parked legacy bullets and five/ten active campaign bullets, plus full synthetic progress/settings/parked bodies. Both packets remain failures; these are injected faults, not observed native failures.

Both owning stores now check destination existence and one buffered exact destination string decoded by that same store. The raw schema1 store no longer performs two inconsistent destination reads. Alternating slots, revision ordering and unpromoted-import-temp eligibility remain unchanged.

Import now freezes host and child before joining any admitted autosave. It then captures host live campaign state plus the child's live legacy/settings copies when present. Exact local copies preserve the live code, every readable decoder-valid raw0/0.tmp/1/1.tmp candidate and incoming code before a checked pending marker can authorize any active write. Existing ready-catalog1 upgrade policy remains: the exact original intake is archived separately from the upgraded selected code, requiring at most seven IDs. Ordinary saves/autosaves do not create archives.

The shipping owner makes one journal/bootstrap decision before `Store.upgrade`, default selection, normal startup save or legacy-child startup write. Readable pending recovery binds the full original context. An unreadable pending marker blocks play, settings, gestures, mission/loadout/retry changes, synchronous/lifecycle saves and new worker admission. Existing raw-slot corruption **without a journal** retains its prior startup behavior; this is not a global corrupt-save rewrite.

Retry Import and Keep Previous Whole Save both use the owning Store, check the complete decoded chosen context, verify both marker paths absent, then adopt synchronously. A false/uncertain write, read or cleanup keeps the original live context blocked. Successful clear invalidates cached admission so a retained helper must recreate the marker before any later active write. Selected contexts and both view owners remain paused after adoption. A rebuilt legacy child cannot write during `_ready`. The pending panel leads with both whole-save summaries; codes are hidden until requested and exposed read-only for export. Back/Home/close cannot release this transaction. Unreadable recovery explains retry/local retention and never silently writes a default.

The standalone schema1 prototype uses the same private journal with a format gate. Shipping startup can resume that old-format transaction through its canonical migration decoder; the prototype fails closed on a full journey marker. Progress schemas remain1/2; private journal bookkeeping version1 is separate.

## Bound evidence

[RECOVERY_CHECKPOINT.json](RECOVERY_CHECKPOINT.json) pins current LF-normalized source, unchanged compatibility/art and all38 evidence packets. Final headless/Dummy sections use isolated APPDATA/LOCALAPPDATA/TEMP/TMP:

| Section | Checks/failures | What it proves |
| --- | --- | --- |
| Whole-choice matrix |199/0|18 actual GUI original/imported choices across campaign-ready, campaign-active and legacy-child; immediate live+disk equality before teardown, both owners paused, and materialized-file fresh owner |
| Typed storage faults |93/0|Archive/stage/marker promotion, missing/corrupt/stale active destination, first/second post-commit reads and cleanup failure/lies |
| Worker barrier |11/0|Real admitted Store worker held before mutation; actual Import from both views observes freeze before join, then worker → archive → journal → chosen active write; later autosave retains selected context |
| Recovery edges |48/0|All seven exact codes, unsaved settings through actual host/child controls, torn/missing markers/archives, one-read startup windows, partial cleanup and retained-helper reopen |
| Private formats |10/0|Exact raw schema1 original, shipping migration/adoption, both prototype choices, and prototype rejection of journey-format journal |
| Compatibility |15/0|Genuine code4 active fixture retains rules/bullets/whole context; actual ready upgrade preserves original intake; rule-derived terminal victory/defeat recovery |
| Current original regression |36/0|Current assertions require pending full-context ownership; explicitly distinguish highest raw slot from journal-owned fresh startup |
| Existing raw rules/storage |139/0|Unchanged schema1 rules and storage contract |
| Existing platform input |9/0|Actual input plus labeled synthetic Back/Home notification inheritance |
| Existing genuine code4 contract |10/0|Pinned active-road retention, continuation and normal Retry upgrade |
| Final summary input smoke |12/0|Same bounded recovery flow after the final both-mode summary sentence |

The38-packet record also retains the original failure baselines, a real early teardown error from an over-broad notification guard, test typing failures, the incomplete combined180s budget run and two format-assertion failures. The notification guard is now limited to actual lifecycle/Back events. Timing showed the complete matrix and fault sections exceeded one180s budget, so the runner exposes bounded parts; default `--journal` means matrix, with a240s budget. The earlier timeout is not a pass.

The format diagnostics retain actual/expected contexts and show raw live ctx exactly equals the owning schema1 migration, while the test's extra schema2 roundtrip normalizes numeric types in its fresh parked campaign. Corrected assertions require **both exact raw context and exact owning canonical roundtrip**, plus the durable raw decoded context; they do not rely only on approximate `Data.same`. Earlier failing packets remain unchanged.

Earlier passing sections retain their exact source. The checkpoint reconstructs the prior summary sentence and prior Import helper; final runtime additionally clears stale journal readiness, revalidates durable admission before every choice, and reuses existing journals only when every artifact is fully validated and identical. Final focused receipts below bind those changes; tests/UID metadata are listed separately. Rules remain unchanged. Four new UIDs were generated and validated with the real headless `ResourceUID` API. No editor/import was run; existing resource cache was reused.

```powershell
python android-games/dead-run/tests/run_recovery.py
python android-games/dead-run/tests/run_recovery.py --journal --part matrix
python android-games/dead-run/tests/run_recovery.py --journal --part faults
python android-games/dead-run/tests/run_recovery.py --journal --part worker
python android-games/dead-run/tests/run_recovery.py --journal --part edges
python android-games/dead-run/tests/run_recovery.py --journal --part formats
python android-games/dead-run/tests/run_recovery.py --journal --part compatibility
python android-games/dead-run/tests/run_recovery.py --rules
python android-games/dead-run/tests/run_desktop.py platform-headless --label recovery
python android-games/dead-run/tests/run_desktop.py code4-headless --label recovery
```

## Final retry-marker amendment

Before commit, sequential faults exposed a second boundary: a verified incoming active write followed by failed/partial cleanup could leave the old live context paused; Keep Previous then consumed the sole marker during a false-success promotion. The complete baseline is29/10. A precedence baseline41/1 and a combined transient-marker-read/missing-promotion baseline41/3 remain retained. A later cached-admission baseline44/2 showed retries bypassed current marker verification after active-write uncertainty. A final53/3 baseline reproduced matching-base/conflicting-stage admission followed by partial cleanup exposing the wrong transaction. Both existing artifacts must therefore agree, even when the first one matches. The initial absent-slot test error and first raw-vs-decoded record equality attempt are also retained failures.

The final helper validates current admission on **every** resolve, clears readiness on read entry, and compares the entire owning-decoded record. It checks every existing base/stage artifact without mutation: any unreadable, torn or conflicting metadata blocks the write. A sole valid matching stage remains sufficient. All archived codes are checked again before active mutation. If both markers are absent, only a new verified marker authorizes writing. Successful cleanup still invalidates retained-helper admission.

Frozen marker-admission source strict headless/Dummy packets: marker admission53/0, storage faults93/0, recovery edges48/0, real admitted-worker barrier11/0, and actual-touch/bootstrap smoke12/0. The53-check section includes both marker locations, exact precedence/reverse, unreadable marker plus false-success promotion, full-copy corruption, active-write uncertainty followed by changed/torn/missing/unreadable metadata, zero active mutation on admission failure, and actual Keep Previous input. Broader199/0 matrix, format/compatibility and original regressions remain historical source-bound passes with the exact helper delta recorded; they were not silently relabeled as current full reruns.

A persistently torn existing marker cannot be repaired by Retry alone. The game stays paused and retains the files; it does not delete uncertain metadata or adopt a default. An owner with already validated choices can export their complete codes. A cold owner that cannot decode either marker shows only Retry Recovery Read and explains local retention; it cannot enumerate those copies through this UI. Even if bootstrap can read one valid artifact, a choice stays blocked until every present artifact can be trusted and agrees. A conflicting later stage also blocks; partial cleanup must not expose a different transaction. Transient failures can be retried; this is an explicit safety/usability limit.

A final presentation regression retained7/2 with12 actual touches: an imported active legacy rescue could say Start because its parked campaign was ready. The shipping owner now delegates next-action guidance to its active legacy child. The final7/0 packet verifies ready/playing/rule-derived terminal legacy imports, exact whole live/disk contexts and paused owners. The earlier focused packets differ only by that exactly reconstructed two-line guidance override; no unrelated broad suite was repeated.

## Limits and next gates

No native build/update, renderer, emulator, clipboard, upload or account operation was performed. `physical_boot()` is same-process fresh-owner creation from real materialized files, not OS-kill/native/power-loss proof. Synthetic complete progress and rule-derived terminal fixtures are not earned gameplay claims; the genuine code4 inputs remain specifically migration-only evidence. Runtime logs were checked for errors, warnings and ObjectDB leaks. Exact-byte/readback checks are not a filesystem flush/power-failure guarantee. Root owns editor/packaging preflight, integration/version/build, native pending-summary/Retry/Keep/cold checks, interrupted storage and physical Fold7/IME/sound/performance acceptance. Goal/release/cloud completion is not claimed.
