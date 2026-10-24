# Frontline local Import retry-marker correction

This source-only follow-up changes only `scripts/import_recovery.gd` at runtime. No Store, codec, schema, rules, UI, version, export preset, shared/native code or cloud transport change. Full saves retain run/profile/settings/career, campaign progress/records/skirmishes and parked legacy state/profile. Synthetic progress is not earned gameplay evidence.

At base `c382ab1`, a verified incoming active write followed by failed/partial cleanup could leave recovery pending. Keep Previous then rewrote and consumed the sole marker during a false-success missing/corrupt/stale promotion. A later materialized journal/owning Store decision could therefore lose the previous context. Cached `journal_ready` also admitted later active writes despite changed/unreadable/conflicting metadata, and resolve did not revalidate every retained archive. The strict pre-fix helper packet is **88 checks / 25 failures**. An initial invalid synthetic legacy profile (`best_kills=11` above owning cap10) produced an incomplete timed-out harness packet; it remains a failure, not production evidence.

The bounded correction matches the independently reviewed Dead/Gear invariant:

- `read()` clears durable readiness while retaining known in-memory choices for export.
- Every `resolve()` obtains fresh admission before any active write and verifies every complete archived code.
- `persist()` decodes the intended whole record, checks **all** existing base/stage artifacts for exact decoded-record equality, and reuses them without mutation only when every artifact agrees. Cleanup cannot expose a different transaction. Only an absent pair permits creating a new staged marker.
- Any unreadable, torn, stale/conflicting marker or incomplete archive blocks active mutation. A sole matching stage remains usable. Successful cleanup still invalidates retained-helper readiness.

The final **107/0** helper packet is strict headless/Dummy with unchanged before/after source. It checks six distinct byte-exact live/incoming/raw-slot codes, both choices from sole base/stage, partial cleanup, missing/corrupt/stale promotion, reversed conflicting artifacts, unreadable metadata, changed same-owner markers after owning-Store and later readback uncertainty, whole archive-list identity, all-copy corruption, and retained helpers after successful cleanup. Real files are materialized and read through fresh journal and owning Store instances. These are **helper/Store decisions**, not accepted production scene bootstrap or OS/native restart.

The production bootstrap/touch attempt is separately retained as **2 checks / 1 failure / 0 touch events**, with raw resource/Nil errors. This worktree has no imported model cache: `res://.godot/imported/watchtower.glb-4b55c4b99c903385d584b7479e8cb30f.scn` cannot load. No asset import, substitute presentation, renderer, native/emulator or clipboard operation was used. The previous870/0 broader Import packet remains historical; it was not rerun or relabeled as current. Its persistent `journal_corrupt` expectation is updated to require blocked recovery rather than destructive automatic repair.

Coordinator reruns after integration with genuine imported assets:

```powershell
python android-games/frontline-foundry/tests/run_import.py --marker helper
python android-games/frontline-foundry/tests/run_import.py --marker touch
```

The touch part uses exact production assets/boot/session, actual ScreenTouch Retry Import and Keep Previous for campaign/legacy original contexts, immediate full live/disk equality and paused adoption, plus fresh production owners from materialized files. It is prepared and syntax-checked by the helper run, **not accepted** in this cache-missing worktree. Root owns any controlled import, broader regression, integration/version/build/native checks. No publication/upload or working cloud claim.

Persistently torn/conflicting metadata cannot be repaired by Retry alone. Known validated in-memory choices remain exportable; cold recovery with no decodable marker stays blocked with retry-read/local-retention explanation rather than copy enumeration/default adoption. Readback is not a filesystem flush/power-loss guarantee. Native/OS-kill/power-loss/rendered/physical acceptance remains separate.
