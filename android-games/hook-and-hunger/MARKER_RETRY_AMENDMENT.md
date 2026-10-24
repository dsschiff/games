# Hook local Import retry-marker correction

Source-only follow-up at `daf4eb1`. Runtime changes are confined to `scripts/import_recovery.gd`; Store, codec, save schema, rules, UI, arena identity/best-clear feedback, version, presets, shared/native code and art are unchanged. New checks use complete decoder-valid **synthetic** legacy/campaign/arena contexts, including active projectiles, `profile.ending` with parked finale, settings and opaque raw slot codes. They are not earned-play claims.

The pre-fix packet has **174 checks / 35 failed assertions / 16 ScreenTouch events**. Actual Import could verify an incoming active write but fail cleanup. Retry Import or Keep Previous then consumed the sole base/stage marker during a false-success missing/corrupt promotion. Immediate ownership and fresh production reload could disagree. The same packet exposes cached readiness, conflicting/unreadable artifacts and absent all-archive validation. Its raw `ERROR:` entries are assertion `push_error` output; the packet remains failed.

The minimal correction matches the reviewed all-present-marker contract: read invalidates durable readiness; every resolve freshly validates admission; persist compares the entire owning-decoded intended record with **every** present base/stage artifact and reuses only unanimous valid artifacts without mutation. Only an absent pair may create the staged marker. Every retained code is reverified before the owning Store writes. A valid sole stage remains usable; successful cleanup invalidates retained-helper readiness. No fallback deletes or replaces uncertain metadata.

Final bounded marker run: **172/0, 16 actual touch events**. Four campaign-projectile/arena-parked-finale Retry/Keep cases verify immediate whole live+disk context and paused adoption, then materialize real files and recreate the production owner. Helper cases separately check sole base/stage, both choices, all six exact raw/live/incoming codes, reverse conflicts under partial cleanup, same-owner retries after Store/readback uncertainty, unreadable/torn/missing/stale records, complete copies-list identity, retained helpers, and corruption of projectile-bearing/parked-ending raw archives. Counts include file-path checks and therefore vary with materialized artifact count between failing/successful paths; no check was dropped to hide the failure.

One frozen-source run also passes **recovery871/0, arena identity188/0 and arena feedback573/0**. All passing logs are strict-clean (no ERROR, WARNING, or ObjectDB leak), with exact source before/after/current equality. The prior automatic-repair expectation for permanently corrupt journal metadata now correctly requires pending blocked recovery. The original baseline and final packets are bound in [MARKER_RETRY_CHECKPOINT.json](MARKER_RETRY_CHECKPOINT.json).

```powershell
python android-games/hook-and-hunger/tests/run_graphics.py --skip-import --marker-retry import_recovery
python android-games/hook-and-hunger/tests/run_graphics.py --skip-import import_recovery arena_score_key arena_feedback
```

Existing imported assets were reused. No editor import, renderer/GPU, emulator/ADB, browser, clipboard, native build/signing, upload or push occurred. Same-process fresh owners from materialized files are not OS-kill, native restart, power-loss, flush durability, rendered readability or physical-phone acceptance. Root owns integration and those gates.

Persistently torn/conflicting metadata stays blocked; Retry cannot repair it automatically. Known validated in-memory choices remain exportable. A cold owner without decodable recovery metadata offers retry-read/local retention and cannot enumerate those archive codes through this UI. Optional cloud work remains separate.
