# Tower Trials Android game: graphics handoff

Old thread `01a14c6a-7df5-7001-a1a2-b833cd66c2a4`; worker `18dde713656c068bcc5f2d6be7fefacddc412ae1`; worktree `C:/projects/active/_worktrees/games-tower-trials-20261018`.
Closeout: clean worker, 88 tracked LF source files match the landed functional baseline `6e26b3c2a3938de1828527630f95fb6a219f61b8`. The canonical APK's complete SHA256 was reverified before archiving. No unfinished source survives only in this chat. Keep the historical branch and ignored evidence; do not delete the worktree or saves.

Baseline: version 0.3.1 / code4; `com.dsschiff.towertrials`. APK: `C:/projects/active/games/.artifacts/tower-trials/20261018T024941903573Z/tower-trials.apk`; SHA256 `20acf7f90dcee4ff8cfc3956bee2375f9ea84a8e7c8bf52776282238b5ca35d0`. Build-root raw source `70e61c51a8cda175df9faac89d6dae994e7ff364d31b9bb62c4ba5e76640467b` is distinct from normalized-LF checkout identity. Current evidence: `android-games/evidence/tower-code4-candidate.json`. All baseline APKs and controls are in `.artifacts/releases/portfolio-20261018/` and `android-games/INSTALL.md`.

## Next work

Follow `android-games/GRAPHICS-OVERHAUL.md` and `graphics-overhaul.json`. The user explicitly rejected current visual quality, chose original stylized3D across all six, and deferred phone testing. Preserve existing rules/content, complete progression/replay, save/import/export/Back semantics and package/signing identity. New graphical builds need higher version codes.

Fresh graphics sessions own only `android-games/tower-trials/` in their assigned worktree. Root owns shared tools, records, emulator/export and GPU scheduling; do not start rendered/GPU/ADB work without a slot. Use Python `-B` and isolated test userdata. Do not rerun unchanged full suites on every art adjustment. Archive the graphics session after verified integration and durable closeout.

Frontline establishes the playable quality benchmark while Gear fixes its window layout, then completes its3D overhaul. Remaining pairs: Hearthguard+Hook, then DeadRun+Tower. Record actual source/input-driven clips and visual limits. No phone-performance/fun acceptance may be inferred from headless checks.
