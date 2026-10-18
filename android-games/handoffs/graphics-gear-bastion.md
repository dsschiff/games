# Gear Bastion Android game: graphics handoff

Old thread `01a14b9d-90d7-73c1-9fd4-9b74cbda3fa9`; worker `b6ee0b825414b22a474b2e448129d34ba66e5f61`; worktree `C:/projects/active/_worktrees/games-gear-bastion-20261017`.
Closeout: clean worker, 94 tracked LF source files match the landed functional baseline `6e26b3c2a3938de1828527630f95fb6a219f61b8`. The canonical APK's complete SHA256 was reverified before archiving. No unfinished source survives only in this chat. Keep the historical branch and ignored evidence; do not delete the worktree or saves.

Baseline: version 0.3.2 / code6; `com.dsschiff.gearbastion`. APK: `C:/projects/active/games/.artifacts/gear-bastion/20261018T002003656002Z/gear-bastion.apk`; SHA256 `bb009b600b24c3498363889b0099d361f19ce1bd4fee24a8b704eb3906e3f72b`. Build-root raw source `623e4f84b809ccc81f63198fd701705bcb8dc023ffcf49bc7ab597b5e246ebde` is distinct from normalized-LF checkout identity. Current evidence: `android-games/evidence/gear-code6-candidate.json`. All baseline APKs and controls are in `.artifacts/releases/portfolio-20261018/` and `android-games/INSTALL.md`.

## Next work

Follow `android-games/GRAPHICS-OVERHAUL.md` and `graphics-overhaul.json`. The user explicitly rejected current visual quality, chose original stylized3D across all six, and deferred phone testing. Preserve existing rules/content, complete progression/replay, save/import/export/Back semantics and package/signing identity. New graphical builds need higher version codes.

Fresh graphics sessions own only `android-games/gear-bastion/` in their assigned worktree. Root owns shared tools, records, emulator/export and GPU scheduling; do not start rendered/GPU/ADB work without a slot. Use Python `-B` and isolated test userdata. Do not rerun unchanged full suites on every art adjustment. Archive the graphics session after verified integration and durable closeout.

Frontline establishes the playable quality benchmark while Gear fixes its window layout, then completes its3D overhaul. Remaining pairs: Hearthguard+Hook, then DeadRun+Tower. Record actual source/input-driven clips and visual limits. No phone-performance/fun acceptance may be inferred from headless checks.
