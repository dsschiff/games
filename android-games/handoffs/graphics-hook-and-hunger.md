# Hook and Hunger Android game: graphics handoff

Old thread `01a14c6d-ed39-77a3-ba23-93b5210f38b1`; worker `283522ea2a5cc77ffdbdd0ee753143fd1674b334`; worktree `C:/projects/active/_worktrees/games-hook-and-hunger-20261018`.
Closeout: clean worker, 62 tracked LF source files match the landed functional baseline `6e26b3c2a3938de1828527630f95fb6a219f61b8`. The canonical APK's complete SHA256 was reverified before archiving. No unfinished source survives only in this chat. Keep the historical branch and ignored evidence; do not delete the worktree or saves.

Baseline: version 0.2.2 / code4; `com.dsschiff.hookandhunger`. APK: `C:/projects/active/games/.artifacts/hook-and-hunger/20261018T031647711677Z/hook-and-hunger.apk`; SHA256 `2391343d79096cf766f2e68daf7db19c84053aca489d0b3e29b2d9a834241c77`. Build-root raw source `b61b029a6c946a41b014b51332ac94e9503e5ba1fd4285e002c8a5f329fb7233` is distinct from normalized-LF checkout identity. Current evidence: `android-games/evidence/hook-code4-candidate.json`. All baseline APKs and controls are in `.artifacts/releases/portfolio-20261018/` and `android-games/INSTALL.md`.

## Next work

Follow `android-games/GRAPHICS-OVERHAUL.md` and `graphics-overhaul.json`. The user explicitly rejected current visual quality, chose original stylized3D across all six, and deferred phone testing. Preserve existing rules/content, complete progression/replay, save/import/export/Back semantics and package/signing identity. New graphical builds need higher version codes.

Fresh graphics sessions own only `android-games/hook-and-hunger/` in their assigned worktree. Root owns shared tools, records, emulator/export and GPU scheduling; do not start rendered/GPU/ADB work without a slot. Use Python `-B` and isolated test userdata. Do not rerun unchanged full suites on every art adjustment. Archive the graphics session after verified integration and durable closeout.

Frontline establishes the playable quality benchmark while Gear fixes its window layout, then completes its3D overhaul. Remaining pairs: Hearthguard+Hook, then DeadRun+Tower. Record actual source/input-driven clips and visual limits. No phone-performance/fun acceptance may be inferred from headless checks.
