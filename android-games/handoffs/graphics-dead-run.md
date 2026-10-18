# Dead Run Android game: graphics handoff

Old thread `01a14d53-a3ae-7f61-ab87-0006aaa25dd4`; worker `63406d0ebd970a9206178f44a55e0aaddb3bfb1f`; worktree `C:/projects/active/_worktrees/games-dead-run-20261018`.
Closeout: clean worker, 87 tracked LF source files match the landed functional baseline `6e26b3c2a3938de1828527630f95fb6a219f61b8`. The canonical APK's complete SHA256 was reverified before archiving. No unfinished source survives only in this chat. Keep the historical branch and ignored evidence; do not delete the worktree or saves.

Baseline: version 0.2.1 / code3; `com.dsschiff.deadrun`. APK: `C:/projects/active/games/.artifacts/dead-run/20261018T105219658505Z/dead-run.apk`; SHA256 `ab1a8863fdb92815278924e146092c864b38309baf57fa521e99944b400a415c`. Build-root raw source `f99965a125f955478366a4b45912d1e8e6fb4ead488d8d05b49fd2ee7b26214e` is distinct from normalized-LF checkout identity. Current evidence: `android-games/evidence/dead-run-code3-candidate.json`. All baseline APKs and controls are in `.artifacts/releases/portfolio-20261018/` and `android-games/INSTALL.md`.

## Next work

Follow `android-games/GRAPHICS-OVERHAUL.md` and `graphics-overhaul.json`. The user explicitly rejected current visual quality, chose original stylized3D across all six, and deferred phone testing. Preserve existing rules/content, complete progression/replay, save/import/export/Back semantics and package/signing identity. New graphical builds need higher version codes.

Fresh graphics sessions own only `android-games/dead-run/` in their assigned worktree. Root owns shared tools, records, emulator/export and GPU scheduling; do not start rendered/GPU/ADB work without a slot. Use Python `-B` and isolated test userdata. Do not rerun unchanged full suites on every art adjustment. Archive the graphics session after verified integration and durable closeout.

Frontline establishes the playable quality benchmark while Gear fixes its window layout, then completes its3D overhaul. Remaining pairs: Hearthguard+Hook, then DeadRun+Tower. Record actual source/input-driven clips and visual limits. No phone-performance/fun acceptance may be inferred from headless checks.
