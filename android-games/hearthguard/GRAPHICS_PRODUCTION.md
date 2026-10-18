# Hearthguard graphics production

Current stage: CPU follow-ups ready for a second short rendered inspection.
Only `android-games/hearthguard/` changes. Version stays0.2.0/code2; root owns
integration, reviewed freeze/version bump, Android exports and native updates.
The builder has performed no rendered execution, browser playback, ADB,
clipboard, push or phone testing. Gear retains the exclusive render slot until
root explicitly grants another inspection. Visual acceptance remains open.

## Source history and implementation

- Original freeze `e581026930e55a6ef5626fe2bfb7f3275e784ca0`, integrated by root
  asd2bf769:30 reproducible original GLBs, twelve articulated skinned roles,
  three tower families, regional settlements, immutable snapshot/event adapter,
  stable IDs, adaptive controls and campaign/legacy presentation.
- Separate pooling commit `2ca853c`: actual scene-owned inactive reserves,
  maximum4 per actor role/24 actors total and16 per compatible effect kind/64
  effects total. Active combatants/effects are never capped. Corpses and contact
  actors return to the role pool; projectiles, pulses, coins and value labels
  reuse instances. Root/model/bone/gait/mounted/health/socket/effect state resets
  before reuse; teardown clears reserves and frees retained instances.
- Current composition correction responds to root's directly viewed native
  `root-first-inspect-20261018T161522767389Z/passage-end.png`: complete transformed
  scenery/citizen silhouettes now participate in fitting; ten authored staggered
  regional clusters replace paired vertical rows, with quiet gaps. Shoulder
  placement clears complete traversable bodies and projected controls.
- Header crest now ignores its80px texture minimum, stays40px, and reserves real
  text inset for both title and subtitle. Essential price/type text is larger.
  Ground palettes, key/fill light and exposure are muted for the second visual
  check. Road ribbon winding now matches upward-facing Godot primitives; the
  prior culled ribbon left only individual pavers visible.
- Rules, definitions/arithmetic, collision, RNG, saves/schema, package/signing,
  transfer/Back and offline contract remain unchanged. Astra independently closed
  both early Resume/terminal source findings; pooling retains focused tests for
  first resumed tick events, dedupe, hydration and terminal gait.

## Checked artifacts

Paths are relative to this game directory. Successful receipts include isolated
userdata, CPU import/parse before source binding, exact executed-source copies,
zero unexpected errors and unchanged sources. Old evidence/failures remain.

| Evidence | Result |
| --- | --- |
| `.artifacts/cpu-final10-checks-20261018T160020025084Z/` | Original freeze328 checks/118 pins; independently repeated by root. Not rerun as a broad suite for these follow-ups. |
| `.artifacts/graphics-baseline-campaign-rules-20261018T155336487821Z/` and `graphics-baseline-legacy-rules-20261018T155344633061Z/` | Preserved123 campaign/56 legacy checks; unchanged functional files remain pinned. |
| `.artifacts/pool-first-pool-checks-20261018T161803413384Z/` | Pool commit49 focused checks;122 pins. |
| `.artifacts/pool-final-pool-checks-20261018T162819252184Z/` | Current49 focused checks;124 pins. Actual node/mesh/material reuse, caps/overflow release, fresh-pose equivalence, corpse/contact, Retry/load/pause, Resume/dedupe, terminal/save and teardown. Eleven rule seconds only; synthetic presentation fixtures, no invented earned progression. |
| `.artifacts/composition-glyphs-composition-checks-20261018T162805383919Z/` |192 focused checks;124 pins. All ten maps at720x1280/native1080x2400/cover1080x2520/inner1968x2184/intermediate1100x1400/landscape1600x1000/wide2560x1440. Full silhouettes/control clearance, road front faces, crest bounds and actual generated text geometry. Minimum projected two-line price56.03px/type27.00px; this does not establish rendered legibility. |
| `.artifacts/graphics-kit/stable-indices-reproducibility.json` | All30 original GLBs byte-identical across independent Blender CPU processes. |
| `.artifacts/pool-preserved-art.json` | All64 original art files unchanged by the pool follow-up. GLBs remain unchanged by the composition correction. |

The initial `composition-first` report used billboard culling bounds to estimate
text height; `composition-glyphs` supersedes that measurement using actual text
mesh faces. Original failed parse/input/projection/export runs remain retained.

## Capture correction and next step

Root's first rendered still is native720x1280. Its internal writer movie is
actually450x800 despite the CLI/root window size: retain that original as a
low-resolution inspection, with no sustained combat or native-movie claim.
Future `--movie` use is rejected. Following Gear's existing capture pattern,
`--native-frames` records frame_post_draw pixels at1:1, then encodes at ordinary
fixed30 cadence with no scaling/retiming. Ordinary clips reject any actual source
frame other than720x1280. Resize passages use declared padding and retain every
native dimension/offset. Encoding checks canvas/count and fully decodes. This
new capture path has passed CPU parsing only; root must verify it while rendered.

After explicit GPU grant, request one bounded second inspection before long clips:

```powershell
python -B tests/run_graphics.py inspect --render --native-frames --seconds 16 --label graphics-second
```

Sixteen fresh simulation seconds should reach the first incoming combat rather
than repeating only the first8s; inspect the actual result before claiming that.
Correct concrete original-image findings before longer opening/heavy/later1x
passages, reset/resize/legacy passages and separate real-time timing. Reuse genuine
`middle-earned.code`, `final-earned.code` and `earned-epilogue-saves.json` in
`.artifacts/campaign-final-headless-20261018T044447829884Z/`; do not fabricate
unlocks or replay unchanged campaigns. Full independent eight-area review,
root's signed2-to3 emulator update and final delivery remain outstanding.
Physical-phone testing is deferred and never blocks this graphics work; no phone
FPS or human-fun claim is made.
