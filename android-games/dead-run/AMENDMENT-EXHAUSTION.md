# Exhaustion precedence amendment

Amends frozen `8d7187e`. A last-crew contact could reduce crew to zero, then an
already queued crane hit could recruit three before defeat was decided. The revived
positive crew made the clamped loss ledger inconsistent, so the run failed save
validation. The production change moves the existing exhaustion decision before
firing/queued impacts, after every gate/enemy has completed movement/contact. It
does not loosen validation or alter encounters, arithmetic, saves, preset or version.

The fatal boundary now ends at tick1227/defeat/crew0/joined4/lost7, with crane1,
unclaimed reward and queued bullet frozen. The paired surviving contact still
awards exactly three: crew3 → contact crew1 → crane crew4, joined9/lost8/crane0.
Both validate, save, decode and cold-restore. Fixtures are **synthetic valid imports**,
not earned routes or reachability proof. Actual GUI Import/Resume and ordinary
engine processing produce the outcomes; there is no direct gameplay-handler call
or model replacement by the test. Code-box fixture assignment is explicitly labelled.

## Amended-source verification

- 139 rules/storage checks, including the paired boundary regressions.
- 34 existing headless normal-route input checks.
- 35 existing interactive rendered input checks, with real Copy/Paste.
- 17 focused headless GUI Import/Resume/save/restore checks.
- 17 focused rendered GUI checks and six fully decoded boundary PNGs.
- 395 new receipt artifact hashes verified; 289 original receipt artifact hashes reverified unchanged.

All five suites executed the same unchanged 27-file source set. Raw bundle
`7db7e08641e50c159ea437575a27544c6bb050821d1cfa6309e4953e0d569320`; LF bundle `18d5f271d33270f2a2e777d3d1a339f5d79c487dbfb5c1326cf00f4033028f2d`. Exact per-file raw/LF hashes, receipts,
raw inputs, checked app-written slots, snapshots and decoded PNGs are bound in
AMENDMENT-EXHAUSTION.json. These two additive reports were written after execution.

Running the new139-check rules suite with the exact OLD production rules produces
five expected fatal-boundary failures (validity/decode/no revival/no payout/terminal
stability); the paired living case passes. This is preserved defect sensitivity,
not an old-suite acceptance pass. The first GUI helper attempt clicked a clipped
fresh-ready menu; its failed packet is retained and corrected input setup is recorded.
Coordinator's isolated old-source probe was copied byte-for-byte into ignored
artifacts for provenance; the coordinator checkout was read only.

The amended normal headless route has16 model snapshots matching the original
within1e-9 except the three terminal-loss bullet positions, intentionally frozen one
tick earlier. Natural loss remains tick2072; victory remains tick3000/crew6/crane0/
final0/kills24/leaks0. The original continuous87.233-second movie, old receipts and
failure history remain unchanged. That movie belongs to OLD source8d7187e; it is
not relabelled as an exact-amendment recording. New boundary captures and fresh
normal-route execution cover this amendment separately.

Reproduce with `python android-games/dead-run/tests/run_desktop.py rules`,
`exhaustion-headless`, `exhaustion-rendered`, `headless` or `rendered` from the
assigned worktree. Each run has isolated APPDATA/LOCALAPPDATA. Real Windows
clipboard suites require the exclusive coordinator window and interactive context.

Freeze scoped amendment and STOP for root independent testing/Astra P2 closure.
No campaign expansion, shared edits, push, agents/goals/chats, APK export or ADB.
0.1.0/code1 stays unchanged because no original APK was exported/installed. Physical
Fold7/IME/touch/folding/safe areas/sound/FPS/human pacing/fun remain unverified.
