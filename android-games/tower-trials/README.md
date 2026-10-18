# Tower Trials

Four-puzzle playable checkpoint for the numbered-room tower puzzle in `../references/hero-wars.md`. This is the first appeal/fidelity gate, **not the complete 30–60-minute campaign**.

Tap an enemy room, read its forecast, then Enter. Power must be strictly greater than each enemy, resolved left to right; defeated strength is added. Winning claims the room and sends power to a visibly taller home watch. Undo restores the complete route; Retry resets this puzzle and preserves earned clears. Journey replays unlocked watches. Settings contains sound, reduced effects and text export/import.

The first watch follows introductory addition; the second teaches ordered enemies. The key ferry defeats a greedy smallest-first policy: taking 1 collapses the only key route. Glass Causeway has viable shield/trap and sun-multiplier routes. These deterministic rules and authored puzzles are original design, distinct from claims about the source creative's universal mechanics.

Run with pinned Godot 4.7.2, or:

```powershell
python android-games/tower-trials/tools/check.py import
python android-games/tower-trials/tools/check.py rules
python android-games/tower-trials/tools/check.py input
python android-games/tower-trials/tools/check.py rendered
```

Runtime files and evidence live under ignored `.artifacts/` inside this game. The helper uses a private AppData directory and Dummy audio; it does not touch the Android device, shared SDK/configuration, or another game's saves. Actual sound output remains unverified. Android export settings are prepared, but no APK/device acceptance is claimed by this checkpoint.

Saves store a versioned action history against the immutable `catalog_v1.gd` and stable puzzle ID, rather than recomputing a live array index. New catalogs must keep old catalogs available, preserve the version-1 rules' meaning, and explicitly migrate display/progression indexes by stable ID if changed. Recovery checks include partial writes, staged-backup-only recovery and failed-import isolation. Import is applied in memory only after a validated disk commit.

See `CHECKPOINT.md`, `WORKLOG.md` and `evidence/prototype.json` for evidence and limits. All art is original procedural geometry/SVG, with generated local tones; no network services, copied commercial assets, ads, purchases, energy gates or artificial waits.
