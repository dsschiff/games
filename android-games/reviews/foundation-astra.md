# Android foundation review

2026-10-17. Reviewer: GPT-6 Astra High. Scope: static review of technical-probe source and shared test/build tooling. The reviewer did not operate the emulator, rerun tests, inspect APK contents, watch commercial footage or test a phone.

## Findings and resolution

1. Save replacement failures were ignored. Both probes now inspect storage write/rename results, surface failures, preserve temporary progress, and prefer a valid interrupted temporary save over an older primary.
2. Missing input playthroughs could be labeled complete. The pipeline now reports rules-only coverage as partial with nonzero status and requires explicit suite completion markers.
3. Build provenance could describe source edited during execution. The pipeline now captures source fingerprints before and after execution and invalidates drift.
4. Corrupt 3D actor identities could collide visually. Save validation now rejects fractional counters, fractional/duplicate/nonpositive actor IDs, and IDs beyond the serial counter.
5. Recovery fixtures had replaced normal-save readback coverage. Both playthroughs now first reload ordinary app-written saves without fixture writes, then separately test newer temporary versus older valid primary and corrupt-primary recovery.

**Final scoped verdict:** previous coverage regression resolved; no remaining blocker from the static foundation review. Execution, export/install, emulator rendering and physical-device acceptance remain separate evidence.

## Executed evidence recorded by coordinator

- `python -m unittest discover -s tests/tooling -v`: 25 tests pass after final geometry/provenance additions (19 at the earlier static checkpoint).
- `python scripts/portfolio.py test input-2d combat-3d`: both rule and actual engine-input suites pass with completion markers and unchanged source fingerprints; normal-save and interrupted-save checks included.
- Signed, provenance-stable APKs exist under ignored `.artifacts/`; APK hashes and install/runtime evidence belong to the build/smoke manifests rather than this static verdict.
- Desktop-rendered snapshots inspected. API35 emulator input, offline launch, background/resume and byte-identical save retention across same-APK reinstall passed for both probes at both Fold7 resolution approximations. Exact manifests are indexed in `android-games/evidence/foundation.json`. This does not establish compatibility with a different APK version, Samsung folding lifecycle or phone performance. Physical-phone testing is outstanding.
