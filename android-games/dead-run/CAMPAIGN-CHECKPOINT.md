# Dead Run campaign checkpoint

Builder candidate: **0.2.0 / code2**, `com.dsschiff.deadrun`. Base is
`8fe7b0400a449da5c579ee177e1c555813f7a21a` on `codex/dead-run`.
This checkpoint is ready for independent root/Astra review and native update
checks. It does not claim those checks have passed.

## Playable arc

Twenty-four authored roads span Canal Works, Market Viaduct, Reservoir Ring and
Ferry Approach. Rivet converts gates quickly, Lance pierces three enemies and
armor, and Fan spreads two pellets across crowds. Six enemy roles combine with
carts, flood lanes, spitter marks, riggers and pumps. Cable Matron sweeps, Toll Ram
requires flank fire or piercing, Spore Bell changes position and volley pattern,
and Ferry Eater exposes its core after both arms break. Clearing the final road
earns the evacuation ending, road replay and a seeded ferry run.

The authored durations total **135,600 ticks / 2,260 active simulation seconds /
37.67 minutes**. The fixed-rate policy is not a human pacing or difficulty model.
Ordinary waves continue until near each deadline. Late sampled roads reached
12–18 simultaneously visible infected in the whole-journey run. Human assessment
of readability, difficulty, density and fun remains necessary.

## Accepted builder evidence

All sixteen accepted runs passed. Their receipts bind **2,720 verified artifact
rows** and **26 fully decoded PNGs**, including complete executed raw/LF source
snapshots, commands, logs, input events, states and checked slots. Exact paths,
hashes and outcomes are in [CAMPAIGN-CHECKPOINT.json](CAMPAIGN-CHECKPOINT.json).

| Coverage | Checks |
| --- | ---: |
| Campaign rules, ownership, ledgers, validation, faults, all roads, seeds | 226 |
| Whole 24-road engine-input journey, Retry, ending, alternatives, replay | 115 |
| Same late road and Rivet, opposite successful target orders | 9 |
| Genuine code1 migration, headless / rendered | 11 / 11 |
| Clipboard delayed/refused/stale, headless / real Windows / OS locked | 14 / 16 / 19 |
| Engine notification dispatch, headless / rendered | 8 / 8 |
| Legacy rules / normal input / exhaustion input | 139 / 34 / 17 |
| Continuous early / middle / final movies | 4 / 3 / 4 |

The whole journey records 24 earned road outcomes, 50 snapshots, 2,170 raw input
events and 161,072 driven ticks including extra routes and labelled fixtures.
An unattended forward-only choice naturally loses at tick3,879. Actual Retry
restores the same definition/weapon, then succeeds. The first successful route
deliberately crosses a -14 gate, survives with four crew, recovers and finishes
with ten. The finale reaches tick7,500 with twenty crew, both arms/core cleared
and the earned ending. Final boundary-import cases are synthetic and are labelled
as such; they are not presented as naturally earned states.

The original full journey's two late rescue/line policies differed mostly in
timing. A separate actual-input follow-up holds **Twin Piers and Rivet constant**:
left-first claims left/right at ticks987/2,016; right-first claims right/left at
ticks2,208/2,403. Both win with twenty crew. This supplies opposite-order proof
without changing the frozen runtime. Its initial failed text-mode checkpoint
copy remains preserved. The accepted follow-up copies the final movie's genuine
app-written ending slots byte-for-byte, without decoding/re-encoding their bodies.

## Continuous footage

| Segment | MP4 | Frames / duration |
| --- | --- | --- |
| Early, fresh road1, harmful crossing and recovery | [.artifacts/release-freeze-campaign-movie-early-20261018T074655987629Z/continuous.mp4](.artifacts/release-freeze-campaign-movie-early-20261018T074655987629Z/continuous.mp4) | 4,741 / 79.0167s |
| Middle, Toll Ram | [.artifacts/release-freeze-campaign-movie-middle-20261018T075224911519Z/continuous.mp4](.artifacts/release-freeze-campaign-movie-middle-20261018T075224911519Z/continuous.mp4) | 6,839 / 113.9833s |
| Final, Ferry Eater and ending | [.artifacts/release-freeze-campaign-movie-final-20261018T075437015258Z/continuous.mp4](.artifacts/release-freeze-campaign-movie-final-20261018T075437015258Z/continuous.mp4) | 7,739 / 128.9833s |

Both AVI and MP4 were fully decoded; frame counts agree. No cuts, speed changes
or forced terminal redraws. Middle/final start from separate exact ready-slot
loads earned by the complete journey at eleven/twenty-three prior clears. These
are three continuous segments, not one uninterrupted 37-minute recording.
The original 87.233s prototype MP4 remains historical with SHA256
`3518fc3f47a0d5a1798b1def7228cf3495abcd6f9cd1dbeda41d98c43f94a237`.

## Preservation and platform boundaries

The real native code1 fixture's complete state and settings compare exactly,
field-for-field, with both migrated desktop snapshots. Original tick103/crew3,
gate0 hits6/value0 and sound-off/reduced-effects-on remain intact. New campaign
progress starts empty. Schema2 parks the complete legacy body independently;
legacy-view transfer carries the whole journey. Legacy rules/save modules stay
unchanged from the base. Imports promote checked storage before live replacement;
invalid or unpromoted import files cannot erase the prior journey.

All final production scripts/config/scenes/assets match the executed LF snapshots
of every accepted run. Each receipt also retains the exact raw bytes executed.
The late-priority tests/UIDs, runner CLI route and documentation were added after
movie capture; this is not a claim that every test/document byte stayed identical.

A final audit found duplicate Back handling caused by explicitly calling an
already inherited Godot notification handler. The campaign now relies on the
single inherited handler. The retained sensitivity proof shows old paused=false,
revision+2 versus new paused=true, revision+1. Eight engine-notification checks
cover Back, transfer/map closure, application pause and parked legacy guards.
These are synthetic notifications through the real script inheritance chain,
not actual native Android input. The initial observer-output failure is retained.

Clipboard confirmation waits for exact echo and cancels stale feedback on later
actions. Normal suites contain no unexpected errors. The dedicated real Windows
lock case retains nine exact expected `Unable to open clipboard` errors and
verifies success after release. The bounded lock never reads or empties clipboard
contents. Android clipboard and IME remain root/physical checks.

The earlier checkpoint/amendment manifests and **684 historical receipt artifact
rows** were reverified unchanged. Seventeen failed-run receipts are indexed
additively in `.artifacts/campaign-retained-failures.json`; older logs/captures and
the original failure index remain untouched. Superseded pre-notification-fix
movies are historical. Private portable editor/tool files stay ignored and should
be excluded from preservation packages.

The preset uses standard non-Gradle templates, arm64-v8a/x86_64, no permissions
and no SDK override keys. No builder APK/export/install/ADB/device operations,
pushes, shared edits, new chats/goals or agents were performed. Physical Fold7
touch, folding, safe areas, audible sound, heavy-crowd FPS, human pacing and fun
remain unverified. Freeze one scoped commit, then stop for root/Astra/native work.
