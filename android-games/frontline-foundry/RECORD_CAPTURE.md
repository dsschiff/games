# Matched production recap/Journey capture harness

Shipping runtime is unchanged from `c1ab02109f23d2deded54591b940a91b5fe7e4bc`.
Only tests/harness metadata and these capture notes/pins are added.

Coordinator command, from this worktree (renderer reservation required):

```powershell
python android-games/frontline-foundry/tests/run_record_capture.py --render --variant both --width 720 --height 1680
```

Default without `--render` is silent CPU/headless/Dummy. Do not run another test,
editor, renderer or build in this worktree concurrently: the wrapper temporarily
substitutes exactly campaign_main.gd and reinforcement_feedback.gd from Git
`64cd050331613604fb3489468dd758264e1bfe15`, then restores their exact original
bytes in finally. Current runtime is c1ab021. All complete eligible production
path sets must agree across old/current/working, every other production byte
must match (text alone permits CRLF normalization), and fixture/cache provenance
must authenticate against the independently accepted606e checkpoint Git hash.
No project copy, asset substitution, editor/import or shipping source change.

Output is `.artifacts/record-matched-<UTC>/<old|current>/`:

- `restored-earned-campaign-B/frames/%06d.png`
- `restored-earned-skirmish/frames/%06d.png`
- `capture-report.json`: full snapshots/raw strings/path sets, actual events,
  relative physics/process ticks, per-image timing, state time, clip windows.
- `godot.log`, source-before/after maps, receipts; outer preflight/restoration.

Encode contiguous PNGs at30fps; do not speed up. **Every displayed comparison
must visibly say Restored earned save, before/after**, not imply a fresh victory.
There is deliberately no test overlay added to the production UI. Caption this
in coordinator encoding/presentation and retain the context in the receipt.
Do not delete raw PNGs before independent review. Coordinator owns encoding,
full decode/PTS/count/duration verification and pixel inspection.

The standalone harness loads only exact previously input-earned B and skirmish
slots, authenticated against accepted hashes, through owning Store and normal
production Boot. No typed stress/boundaries, play_sortie policy or 8x tail runs.
Time scale is1, fixed60Hz; each clip holds recap180ticks, opens Journey by actual
touch, holds top120ticks, sends40 real wheel events at4tick intervals at the same
old/new overlap point, holds bottom150ticks, taps Close/Resume and holds recap
90ticks. B's existing Pause and both Resume saves are admitted and separately
snapshotted. Full live saved meaning stays exact; raw slots/path sets stay exact
across all readonly recap/Journey open/scroll/Close segments. Normal bootstrap's
existing startup save is also separated from the exact fixture intake boundary.
All complete snapshots/raw strings match between old and current at each stage.

The observer is an independent frame_post_draw callback. PNG work adds no route
await; actual physics/process/wall stamps accompany each image. It samples every
2 completed physics ticks, requires every emitted delta==2/save==OK, and requires
the exact count/final sampled tick per declared window. The route ends before
its current tick's draw: B708ticks expects353images through tick706; skirmish706
expects352 through tick704. Those are expected rendered assertions, not CPU
image evidence. Offline deterministic capture is not measured realtime FPS.

## CPU qualification

Final packet `record-matched-20261024T133928060350Z`: old34/0 and current34/0,
strict clean, exact before/after source maps and restoration. Full context/raw
snapshots, gesture payloads, each event/snapshot relative physics tick and final
clip tick counts agree. Default720x1680 is CPU-qualified; optional inner1153x1280
is available but not executed by this task. No PNG/cadence/pixel branch has been
executed here; root must validate it on the reserved renderer.

Earlier packets remain: first34/0 each preserved context but wheel coordinates
differed at old/new scroll centers; next34/0 each matched gestures but predates
stronger provenance/timing/tail gates. Preflight packet133726 failed before any
substitution or Godot launch because my comparator treated binary GLB bytes as
text. All10 affected raw hashes matched accepted pins. The corrected comparator
normalizes only listed text suffixes; binary bytes are exact. Failure record and
executed runner are retained. One new test UID was allocated directly headless
with Dummy audio, no editor/import.

`RECORD_CAPTURE_CHECKPOINT.json` binds harness, notes, all retained CPU packets,
trusted input/cache links and UID receipt. No native clipboard/emulator/render,
build/export/version change, measured device performance, human comprehension,
fun or fresh-victory claim is established by this CPU preparation.

## Rendered and completed1x review qualification

Root rendered the frozen harness at720x1680 with Dummy audio, packet
`record-matched-20261024T134518947480Z`: old38/0 and current38/0, strict clean.
Each variant produced353 campaign and352 skirmish PNGs at exactly two physics
ticks per image, through the required final ticks706/704. Complete live/raw
snapshots, actual input and relative-physics timings match; originals restored
exactly. The original CPU checkpoint ce16be42 and its notes are retained as
historical files; this section supersedes their then-open rendered gate only
for this tested desktop route.

All four continuous.mp4 files have independently verified full decode, uniform
30fps PTS,720x1680 dimensions and frame counts. Campaign duration11.766667s;
skirmish11.733333s. Encoding scope correctly says intended playback1x; it alone
is not proof of actual playback. Root's separate accepted normal1x readback is
linked by exact path/hash in the checkpoint, not copied. That receipt records
both pairs played continuously from start to ended=true at rate1, with complete
portrait frames sampled near2.30/4.68/7.26s (campaign) and2.26/4.62/7.31s
(skirmish). Root assistant observed recap→Journey top→last row/Close without
blocking overlap or wrong result label in sampled views. Astra's nine original
PNG static review was also bounded-clear. This is assistant desktop review,
not Daniel's human acceptance or inspection of every decoded frame.

The accepted receipt explicitly excludes early start/end/partial-viewport
attempts and a late-marker timeout. Actual CUA screenshots/tool readbacks remain
in native chat. The recorded final full-frame observations and ended/rate
readback establish the bounded playback disposition. Root's review tab and
owned loopback servers were closed; no external service/publication occurred.

## Exact PNG retention

After independent verification of all1410 original raw PNGs, root authorized
leaf-only cleanup. `png-retention.json` binds the original rendered receipt
and each original kept/removed pin. Every PNG was dual-checked against its
encoding.raw_frames and the original rendered receipt; complete path sets,
regular files and absence of links/reparse points were verified before unlink.
Each of four frame directories keeps every30th zero-based frame, first/last,
and30/69/140/217/290/330 where valid. **1342 PNGs removed,568993989 bytes;
68 PNGs retained,28626514 bytes.** No unknown file was removed. All four movies,
encoding/probe/full-decode logs, raw input, snapshots/saves and failures remain.

Original render/encoding receipts'1410 raw-frame pins are **historical before
cleanup**, not a promise every original path still resolves. Their earlier
pending-cleanup wording is historical; the retention manifest is authoritative.
The final checkpoint pins only currently retained rendered artifacts plus that
manifest, while preserving original receipt hashes and all original pins there.
Native Android/new APK, other viewports, device FPS/audio, cloud behavior and
human understanding/pacing/fun remain unaccepted by this desktop evidence.
