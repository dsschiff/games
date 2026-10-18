# Hearthguard graphics production

Current stage: CPU production harness frozen for review; rendered batch awaits grant.
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

## Supported bounded inspection and prepared production

Root integrated the two follow-ups asb560c09/3b58962 and independently passed
49 pooling,328 pooled integration and192 composition checks. Its second native
inspection at ROOT `.artifacts/root-second-inspect-20261018T163818136591Z/` is
720x1280/488frames/16.267s, fully decoded with unchanged sources. Actual input
bought Bolt+Mortar and stopped4 with16refuge. Root directly viewed full scenery,
readable labels, clear crest and visible road; Astra supports closure of all five
bounded findings in `android-games/reviews/hearth-second-inspection-astra.md`.
This supports that inspection, not the full eight-area production milestone.

New source in `tests/` prepares normal1x opening/heavy/later clips, focused real
Retry/lifecycle/reduced-effects/paused resize/new-process restore/legacy/tour,
and separate uncapped heavy timing. Runtime/art remains byte-equivalent to
34ce074; no game script/art/source/version/save change accompanies this harness.
`tests/PRODUCTION.md` has exact commands and limits. `tests/production-plan.json`
pins eleven accepted genuine app-written sources; startup checks complete state,
both profiles, settings, parked legacy, revision/committed/version before boot
can write, then confirms complete meaning after normal boot. Every new process
has isolated userdata and post-import executed-source bindings. Each run retains
raw inputs, whole boundaries and readback-verified app-written raw slots.

Provenance correction: earlier notes pointed to `campaign-final-headless-...044447`,
whose receipt says passed=true but source_unchanged=false. It is preserved and
excluded. Production uses the later accepted `release-headless-20261018T045517382023Z`
and `release-legacy-20261018T045508094423Z`, both indexed in the baseline checkpoint
and verified unchanged. No old run is reclassified or overwritten.

Prepared frame coverage records projected live modeled roles/stable IDs, retiring
actors, regions and observed pool reuse. The inventory flags absent or less than
half-second contiguous live-ID exposure; it cannot approve motion or pixels.
Primary saved windows schedule all minor roles and Matriarch/Regent across the
three regions; Ram is the prospective gap. Queue only actual coverage gaps from
bounded earned encounters. A Ram gap can advance45s of ordinary unrecorded
input from the accepted map3 time80 checkpoint and record32 contiguous seconds;
the lead-in and resulting app-written boundary are retained, never accelerated.

Native capture now proven by root rejects the internal450x800 writer. Production
requires native1:1 frames, checks native dimensions/counts, and fully decodes.
Fixed30 cadence is never FPS. Timing uses the completed Frontline frame_post_draw
method, actual disabled VSync/FPS cap,1.5s eligible warmup, explicit exclusions,
no framebuffer readback during sampling, hardware/AA/settings metadata, complete
raw intervals/counters, worst25/last120 tails, percentiles and scoped pool reuse.

`.artifacts/production-checks-20261018T170706152256Z/` passes48 narrow CPU harness checks with136 source pins,
zero unexpected errors and unchanged sources; all96 frozen runtime/art files
match34ce074. It validates genuine decodes, percentile arithmetic, actual-input
Retry/raw-slot retention, held/scene-reload whole context and timing eligibility.
It does not render, measure performance, prove new-process cold behavior or replay
a full campaign. Initial failed harness parse is retained at
`.artifacts/production-checks-20261018T165926489311Z/`.

No production movies/timing have run yet. Keep GPU ownership with Astra/Gear until
root explicitly grants the batch. Root owns export/ADB/clipboard/shared writes
and actual code2-to3 native update; its installed code2 revisions479/478 backup
and native helper preparation are coordinator evidence, not builder execution.
Physical-phone testing remains deferred with no phone FPS or human-fun claim.

## Portable tracked-index binding correction

Root's independent attempt stopped before execution because this checkout's
`campaign-checkpoint.json` was CRLF and the coordinator's was LF. The failed
root attempt remains retained. The plan now pins the recorded original raw SHA
273a622c... and exact text-LF SHA66a45f7e.... Only this tracked acceptance index
permits CRLF-to-LF byte replacement; bare CR, trailing whitespace and content
changes reject. Provenance records original raw, actual checkout raw and text-LF
identities separately. Receipt/artifact/envelope/raw-slot validation remains
byte-exact; envelope reads/writes now explicitly avoid text newline translation.

The narrow Python regression verifies both newline variants, the coordinator's
actual LF index read-only, all three negative mutations, and all eleven original
source/envelope hashes. It neither runs Godot nor repeats a campaign/full suite.
Timestamped results and checked source hashes are retained under
`.artifacts/source-index-portability-*.json`. No art/runtime/save/version change
or rendered execution accompanies this correction.
