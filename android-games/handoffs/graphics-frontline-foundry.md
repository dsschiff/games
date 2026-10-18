# Frontline Foundry Android game: graphics handoff

Old thread `01a14d1d-c90a-7562-b246-6cd243ad96ed`; worker `08c122eb4608d369ff9314110054dd7a812b4047`; worktree `C:/projects/active/_worktrees/games-frontline-foundry-20261018`.
Closeout: clean worker, 59 tracked LF source files match the landed functional baseline `6e26b3c2a3938de1828527630f95fb6a219f61b8`. The canonical APK's complete SHA256 was reverified before archiving. No unfinished source survives only in this chat. Keep the historical branch and ignored evidence; do not delete the worktree or saves.

Baseline: version 0.2.0 / code2; `com.dsschiff.frontlinefoundry`. APK: `C:/projects/active/games/.artifacts/frontline-foundry/20261018T072513236798Z/frontline-foundry.apk`; SHA256 `eef7f08a32dbc61245d29f281f5dc8500786c852019c025f07cd39fc7407d45c`. Build-root raw source `9e58d59a34dc7e12028ba4077217a23a4cdfe03d29ce3056723a099102640195` is distinct from normalized-LF checkout identity. Current evidence: `android-games/evidence/frontline-code2-candidate.json`. All baseline APKs and controls are in `.artifacts/releases/portfolio-20261018/` and `android-games/INSTALL.md`.

## Next work

Follow `android-games/GRAPHICS-OVERHAUL.md` and `graphics-overhaul.json`. The user explicitly rejected current visual quality, chose original stylized3D across all six, and deferred phone testing. Preserve existing rules/content, complete progression/replay, save/import/export/Back semantics and package/signing identity. New graphical builds need higher version codes.

Fresh graphics sessions own only `android-games/frontline-foundry/` in their assigned worktree. Root owns shared tools, records, emulator/export and GPU scheduling; do not start rendered/GPU/ADB work without a slot. Use Python `-B` and isolated test userdata. Do not rerun unchanged full suites on every art adjustment. Archive the graphics session after verified integration and durable closeout.

Frontline establishes the playable quality benchmark while Gear fixes its window layout, then completes its3D overhaul. Remaining pairs: Hearthguard+Hook, then DeadRun+Tower. Record actual source/input-driven clips and visual limits. No phone-performance/fun acceptance may be inferred from headless checks.
