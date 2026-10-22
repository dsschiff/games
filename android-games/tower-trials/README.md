> Graphics work: see [GRAPHICS_PRODUCTION.md](GRAPHICS_PRODUCTION.md). Graphics candidate frozen as 0.4.0/code5 (original stylized 3D presentation). Status 2026-10-22: signed APK built, rules 3503+3105 and input 1363 checks pass, genuine emulator code4-to-5 update keeps the whole save, a real room tap plus Enter plays the move and shows the courier fight on the emulator, and Android lighting matches desktop frames. Not phone tested. Evidence: `android-games/evidence/tower-graphics-candidate.json`.

# Tower Trials

Offline numbered-room tower puzzle, graphics software candidate **0.4.0 / Android code5** (original 3D presentation over unchanged rules and saves; not independently reviewed, not phone tested; see `GRAPHICS_PRODUCTION.md`). Previous software candidate: 0.3.1 / code4. Thirty-six authored watches, four coastal chapters and an ending. Astra approved the first loop and the bounded code2 authored/motion candidate. The seeded Challenge amendment now implements the remaining replay requirement; Astra approved the seeded amendment for software-candidate validation. Code4 fixes a confirmed native Android Back-to-quit defect; coordinator Android retesting remains pending.

Tap a room, read its forecast, then Enter. Tap the forecast for every combat/resource step. Power must be strictly greater than each enemy, resolved left to right; defeated strength is added. Claiming a room sends power to a visibly taller home watch. Keys, collapsing bridges, keeper rescues, shields/traps and sun lenses create route decisions. The first six watches introduce the main rules; later chapters combine them.

Undo restores the entire action, including keys, shields, rescued keepers and sealed routes. Retry starts a fresh attempt and preserves earned clears. Journey has four chapter tabs and a touch-scrolling list; completed watches can be replayed for par, clean-run and treasure medals. Settings contains the persistent rules/medal guide, sound, reduced effects and text export/import. Back closes overlays, pauses the route, then opens Journey.

All 36 puzzles and all 14 offered treasure routes have solver witnesses. The smallest-enemy-first policy fails on 18/36. Shortest routes total 177 moves, with 3–8 per puzzle; the authored room/resource signatures differ independently of enemy strengths. These results establish deterministic content and consequential routes, **not unique solutions, human appeal or measured 30–60-minute solving duration**. The latter remains a playtest target. Seeded Challenge mode adds four deterministic structural grammars, bounded solver/attempt budgets and verified backups. Settings → Seeded Challenges exposes version, family, seed, weave and treasure options. Active snapshots, Undo/Retry and separate challenge medals are saved independently of campaign progress; the record book supports replay.

Use pinned portable Godot 4.7.2. From the isolated repository root:

```powershell
python android-games/tower-trials/tools/check.py import
python android-games/tower-trials/tools/check.py rules
python android-games/tower-trials/tools/check.py input
python android-games/tower-trials/tools/check.py rendered
python android-games/tower-trials/tools/capture.py
```

The helper stores runtime AppData, logs and captures only under this game's ignored `.artifacts/`. Current evidence is in `.artifacts/challenge-v1/`; the code2 `.artifacts/campaign/` and first-loop `.artifacts/prototype/` packets remain immutable. The Challenge movie starts from a fresh save and uses actual family/seed/options controls. The combined suite earns its campaign progress through input; the historical code2 movie uses unchanged app-written journey checkpoints. All new actions use actual engine Input events and natural updates. Fixed-rate captures are not phone FPS measurements. Automated runs use Dummy audio; audible device output remains unverified.

Version3 saves replay stable puzzle IDs against an immutable catalog and rule version. `catalog_v1.gd` and `rules_v1.gd` preserve code1 runs and Undo/Retry semantics. Newly inserted tutorials are real requirements; migration preserves historic clears without fabricating new ones. Regression fixtures include an unchanged touch-created code1 save. A committed import remains eligible as a backup; only its uncommitted `.tmp` staging file is excluded from recovery.

Every custom button has an 80-logical-pixel minimum hit dimension: 48dp at a 360dp-wide cover viewport. Four-floor boards keep conspicuous enemy numbers and large room targets; the home watch compresses floor spacing as it grows. Desktop aspect/input tests do not establish physical Fold7 safe areas, folding, sound or performance.

Later route hints are optional. Cold-restored defeat retains its visible cause.

See `BACK_POLICY_CHECKPOINT.md`, `CHALLENGE_CHECKPOINT.md`, `CAMPAIGN_CHECKPOINT.md`, `progress.json`, `WORKLOG.md` and `evidence/challenge-v1.json` for exact checks and source/artifact bindings. Coordinator owns Android export/device/update work. No APK or phone acceptance is claimed here. Original procedural/SVG art and local generated tones; no network service, account, ads, purchases, energy restrictions or artificial waits.
