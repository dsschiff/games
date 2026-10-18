# Hearthguard Android game: graphics handoff

Old thread `01a14cf9-259a-7473-8a90-2a4e341e8219`; worker `6c0b0ef5ae3b273ceca18fa0ccf8f7211fd45699`; worktree `C:/projects/active/_worktrees/games-hearthguard-20261018`.
Closeout: clean worker, 45 tracked LF source files match the landed functional baseline `6e26b3c2a3938de1828527630f95fb6a219f61b8`. The canonical APK's complete SHA256 was reverified before archiving. No unfinished source survives only in this chat. Keep the historical branch and ignored evidence; do not delete the worktree or saves.

Baseline: version 0.2.0 / code2; `com.dsschiff.hearthguard`. APK: `C:/projects/active/games/.artifacts/hearthguard/20261018T053956831230Z/hearthguard.apk`; SHA256 `928bb45d102df9d2a55e0ee3e1c51b8b7df0af5ea945d185edbf51e64484676b`. Build-root raw source `53c3569a91f2d9ee43f3dcdcc780b6806ad5e8e00758a9bfbf720b256bdc5ddd` is distinct from normalized-LF checkout identity. Current evidence: `android-games/evidence/hearth-code2-candidate.json`. All baseline APKs and controls are in `.artifacts/releases/portfolio-20261018/` and `android-games/INSTALL.md`.

## Next work

Follow `android-games/GRAPHICS-OVERHAUL.md` and `graphics-overhaul.json`. The user explicitly rejected current visual quality, chose original stylized3D across all six, and deferred phone testing. Preserve existing rules/content, complete progression/replay, save/import/export/Back semantics and package/signing identity. New graphical builds need higher version codes.

Fresh graphics sessions own only `android-games/hearthguard/` in their assigned worktree. Root owns shared tools, records, emulator/export and GPU scheduling; do not start rendered/GPU/ADB work without a slot. Use Python `-B` and isolated test userdata. Do not rerun unchanged full suites on every art adjustment. Archive the graphics session after verified integration and durable closeout.

Frontline establishes the playable quality benchmark while Gear fixes its window layout, then completes its3D overhaul. Remaining pairs: Hearthguard+Hook, then DeadRun+Tower. Record actual source/input-driven clips and visual limits. No phone-performance/fun acceptance may be inferred from headless checks.
