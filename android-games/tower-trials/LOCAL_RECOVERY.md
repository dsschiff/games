# Whole-save local Import recovery

Tower now keeps an uncertain Import paused until the player explicitly checks the imported complete save or rolls back to the previous complete save. The earlier checked-destination Store fix remains unchanged; a transient destination read failure can still occur after the higher revision has been written. This owner-level transaction handles that uncertainty.

The pre-fix real-owner packet `.artifacts/design-cpu-20261024T072119777543Z` has 16 checks, six failures and 12 recorded ScreenTouch events. In both campaign and generated-challenge cases, the old owner retained its live data and said “current route kept,” while a fresh production owner loaded the imported higher revision. The packet retains complete before/live/incoming/raw-selected data. This is an injected read-fault reproduction, not an Android or power-loss test.

Before changing active slots, Import freezes room advancement, actions, settings, Back and lifecycle saves. It archives the encoded complete live data, the exact supplied intake bytes, and every readable decoder-valid primary, primary stage, backup and backup stage. At most six distinct SHA-identified codes belong to one private recovery record. Ordinary autosaves do not create archives. Existing save schema, owning decoder, Store, rules, puzzle snapshots, version and export configuration are unchanged.

The complete data includes campaign catalog and watch, route actions and Undo use, earned campaign profile, all settings, active campaign/challenge kind, the complete pinned challenge bundle and its actions/Undo use, challenge records, and the parked campaign or challenge. The immutable original describes the persistent data before the unfinished room outcome: `pending` and its elapsed `beat` are not saved actions. While Import is uncertain, that live pending result, beat, selection and data remain untouched. After either explicit choice is verified, `load_run` resets the unfinished animation under existing cold-save semantics. No old completion may append into the adopted route.

Startup reads the private recovery record before ordinary active-save selection or `load_run`, and binds that single validated decision. A readable pending record loads the original complete data paused. An undecodable record or missing/unreadable choice blocks play and saving without selecting a default or inspecting active slots. A transient read can be retried. Without any pending record, the previous corrupt-save/default startup policy remains unchanged.

Every Retry Import or Keep Previous freshly validates both present record artifacts. Every existing artifact must decode to the entire intended record, including the full copies list; disagreement, unreadable or torn artifacts block without mutation. Matching sole base, sole stage or matching pair is reused without promotion or truncation. Only a truly absent pair may create a new record. Every archived code is revalidated before the owning Store writes. Complete checked disk meaning and replay must match the chosen save, followed by confirmed removal of both record artifacts, before live adoption. Only revision/recoverable storage metadata are excluded from meaning equality. A retained helper must establish current record admission again before any later write.

Recovery shows summaries first and separate Retry Import / Keep Previous choices. Copy Previous and Copy Imported perform a direct platform-capability check, set the exact retained code and require accepted write plus exact readback before reporting success. Copy feedback is separate from unresolved storage feedback and is brought into view in an allocated row. View Previous/Imported Code offers a read-only manual fallback after one guarded layout wait. Copying and viewing never release recovery or alter the retained codes. Known in-memory choices remain exportable when metadata is torn; an unknown cold record offers only Retry Recovery Read. Permanently torn/conflicting metadata is deliberately blocked rather than overwritten or automatically repaired. Keep the app installed to retain the local files. This is not cloud backup or an unlimited archive browser.

## Bound evidence

`LOCAL_RECOVERY.json` pins the current source, unchanged base files, all retained failure packets, final combined packet, existing regression packet and UID allocation receipt. The final packets use cached resources with headless Godot 4.7.2 and Dummy audio; the runner rejects ERROR, WARNING, Parse Error, FAIL and ObjectDB leak lines and checks source stability.

| Final packet | Result |
| --- | --- |
| `.artifacts/design-cpu-20261024T074208838352Z` | 608 checks, zero failures, 208 recorded ScreenTouch events |
| `.artifacts/design-cpu-20261024T074235015350Z` | Store 70; rules/save 3,503; challenge rules 3,105; campaign input 1,364 with 588 taps over 36 watches; challenge input 176 with 116 taps; Back 67 with 16 requests; geometry 252 with 3 taps and 2 Back requests; all zero failures |

The combined matrix exercises both explicit choices across current campaign, active challenge, parked challenge and catalog1 contexts; all six retained codes; full immediate live/disk adoption and subsequent fresh owners from materialized real files; admitted mid-beat animation and failed choices; archive/stage/promotion/readback/cleanup faults; both conflicting-record orders; every archived code recheck; same-owner failed-write retry; retained helper after clear; single-read startup windows; unknown startup with zero active reads; exact legacy intake; actual copy controls and synchronous fake reentry. Copy acknowledgments and View reachability are geometry-tested at 344×642, 690×829 and 1066×600 through the project stretch transform. These are headless control/layout checks, not rendered readability approval.

The campaign base fixture is the existing app-written, touch-earned campaign code with retained clears and Undo, with provenance in `tests/fixtures/save-commit-before.provenance.json`. Settings variants and seed-137 challenge/parked contexts are labelled synthetic test setup. They are not claimed as newly earned Android progress. Materialized-file bootstrap means a fresh shipping scene in the same test process, not an OS kill, native restart or physical power loss. Clipboard tests use a synchronous fake or the production headless-unavailable guard; no OS clipboard was touched.

The initial typing/seed-name parse failures are retained. The first expanded copy packet had 255 checks and three first-show View scrolling failures. The intermediate deferred-scroll/pre-settle observations are retained too; the final test explicitly waits for the guarded layout work, while direct copy feedback remains synchronous. No errors are filtered or suppressed. Three new script UIDs were allocated through ResourceUID in a direct headless script, without editor import.

Reproduce from the repository root:

```powershell
python android-games/tower-trials/tools/design_check.py --skip-import import_recovery
python android-games/tower-trials/tools/design_check.py --skip-import --part animation import_recovery
python android-games/tower-trials/tools/design_check.py --skip-import save_commit run_tests challenge_rules campaign_playthrough challenge_playthrough back_policy graphics_view
```

No render, emulator, Android/native recovery, OS clipboard, build, publication, cloud, performance or human pacing/fun acceptance is implied. Those remain coordinator gates.
