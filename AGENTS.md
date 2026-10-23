# Games repository instructions

This repository contains the existing public games hub (`docs/`) and six personal Android projects (`android-games/`). Keep website publication separate from Android development. Preserve existing repository visibility.

Read `GOAL.md`, `ROADMAP.md`, `WORKLOG.md`, and the relevant reference brief before work. Run `python scripts/portfolio.py status` for orientation once the script exists. The coordinator owns root records and shared tooling. Each builder owns one game directory in its own Git worktree; no overlapping shared-file edits.

Use the pinned Godot stable release with GDScript. Prefer typed, testable rules independent of rendering, touch-first controls, versioned local saves, explicit random seeds in tests, and data-driven encounters. One standalone app per game. Match chosen reference mechanics/camera/pacing with original names, art and levels. No ads, purchases, compulsory sign-in, custom account servers, energy gates, or artificial monetization waits. Optional Google Play Games cloud saves are approved in the 2026-10-23 design cycle; offline play and immediate local saving remain required.

Keep SDKs, reference videos, signing material, private runtime data, and APKs out of Git. Store machine tooling under `C:/projects/active/.game-toolchain`; local build/evidence outputs under ignored `.artifacts/`. Never put secrets in export presets. Commit reference source URLs and observations, not third-party footage or copied artwork.

Distinguish implemented, automatically verified, ready for phone testing, and phone tested. Emulator tests do not establish phone performance or fun. Never mark a portfolio milestone complete using only a screenshot or a successful headless exit. Preserve actual input-driven evidence, win/loss/retry/save/update checks, and independently reviewed source comparisons.

Use Sol for builds and Astra for reference/architecture/release review. At most two builders and one reviewer concurrently. Integrate scoped verified commits; preserve another worker's changes. Keep progressing on other games when device feedback is pending. Do not publish website changes, buy assets/services, or publish publicly as part of this goal. Daniel-only Google Play internal testing is approved once account setup permits it; preserve the existing app signing identity.

