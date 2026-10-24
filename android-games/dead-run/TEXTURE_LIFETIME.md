# Dead Run texture lifetime investigation

The original full rendered terminal-design run remains a strict failure: four
349,524-byte GL texture allocations were reported at shutdown. Nothing in this
investigation relabels that failure or suppresses error output.

`tests/texture_lifetime.gd` adds real-input runtime prefixes to the existing
source-bound graphics runner (`lifetime` mode). Each case begins from isolated
fresh app data, uses the actual GUI Start/Retry/map/transfer paths and normal
physics for natural defeat or policy-driven victory, and ends through the same
deferred scene release plus render-frame drain as the failing harness. It adds
weak explicit-font observations and node/resource counts; it does not retain
font resources, purge caches, alter rules, or infer an engine defect.

CPU preparation passes all twelve prefixes: campaign Start20/60, natural defeat,
terminal Home/transfer/Back, Retry20, active/defeat reload, natural victory,
victory reload, legacy Start20/defeat/Retry-to-map. Each final headless teardown
returns to one root node, 24 resources and zero observed explicit-font survivors.
The source-bound logs and exact receipts are indexed in TEXTURE_LIFETIME.json.
These are CPU ownership/input observations and cannot clear a GL shutdown leak.

The inventory distinguishes actual play from short startup: campaign Start60
keeps eight default-font 72px effect labels empty/hidden; natural defeat has
three populated with -1. Legacy renders additional default-font sizes. This is
an observation for the prefix comparison, not a diagnosis of font ownership.

## Rendered prefix results

After the coordinator granted the exclusive renderer, actual campaign Start20,
Start60, natural defeat, defeat plus Home/transfer/Back and defeat plus Retry20
all passed the raw strict shutdown gate. Legacy Start, natural defeat, Retry and
map exit also passed. The populated effect text path by itself does not reproduce
the failure. No browser, clipboard, ADB or native operation was used here.

The full harness with weak geometry-font observations then reproduced the exact
failure: 51 assertions pass, followed by four GL textures (IDs 33-36), each
349,524 bytes, leaking at shutdown. A matched run with only `p = null` at the
end of each geometry iteration, before the next world rebuild, failed identically.
Both returned one node, 24 resources and no observed geometry-font survivors at
the drain. The proposed local geometry-adapter reference explanation therefore
has no supporting causal result; the speculative null assignment was reverted.

Retained packets:

- `.artifacts/graphics/ownership-original-design-20261024T002540Z`: strict FAIL.
- `.artifacts/graphics/ownership-release-design-20261024T002933Z`: strict FAIL.
- `.artifacts/graphics/ownership-observe-design-20261024T002503Z`: CPU 49 checks
  pass; warning_pixels returns immediately headlessly, so this does not exercise
  its rendered rebuild/await path.

The GPU was released to root after the paired run. Runtime source is unchanged;
exact ownership and a fix remain unproven.

## Prepared next comparisons

The coordinator prioritized actual campaign victory followed by cold reload,
before legacy/geometry. `campaign-win-reload` was CPU-validated with seven checks
and uses real app-written persistence. `geometry-before-warning` separately
prepares only the synthetic tail (CPU 23 checks); it does not claim earned
progress or execute rendered warning work headlessly. `full-runtime-prefix`
(CPU 19 checks) reuses the original terminal and legacy input helpers to cover
all actual play/lifecycle/reload/legacy operations before the geometry tail.

The latter two inherit terminal_design to reuse its helpers, adding one script
resource to the CPU baseline (25 rather than 24). Their queued-free/drain still
returns to one node and no observed explicit-font survivors. All receipts are
indexed in the JSON record. Further rendered invocations require a new slot.

Example (CPU only):

```powershell
python android-games/dead-run/tests/run_graphics.py lifetime --headless --label probe-start20 --scenario campaign-start20
```

The coordinator must grant the renderer slot before omitting --headless.

## Minimal rendered reproduction

The next granted comparisons separated real play from the synthetic tail:

- `render-win-reload-lifetime-20261024T005933Z`: actual Start, natural defeat,
  Retry, policy-earned victory and complete app-written cold reload pass seven
  checks and the strict raw shutdown gate. Final drain: one node, 25 resources,
  no observed explicit-font survivors.
- `render-geometry-before-warning-lifetime-20261024T010245Z`: fresh app plus only
  the 5/25/49-crew geometry fixtures followed by the original warning fixtures
  passes 25 assertions but FAILS strict shutdown with four 349,524-byte textures
  (GL IDs 25-28). Final drain also reports one node, 25 resources and no observed
  explicit-font survivors. Original full-run IDs were 33-36; GL IDs do not prove
  these are the same individual allocations, only the same count and sizes.

Actual gameplay, terminal transfer, victory, cold reload and legacy are not
required for this smaller reproduction. It narrows the fault to this fixture
sequence/render-resource interaction; it does not yet establish a runtime owner,
font issue, engine defect, or a correction. The GPU was returned immediately
after this isolation. No runtime source changed.

CPU-ready smaller reductions preserve the unmodified runtime: `geometry-only`
(23 checks), `single49-before-warning` (19), `single49-only` (19), and
`geometry-no-pixel-before-warning` (23). They vary repeated fixture rebuilds,
the 49-crew capture/yield and the warning tail. Their headless success only
validates setup/teardown; warning_pixels does not execute its rendered branch
headlessly. No further rendered result is claimed for these prepared cases.

## Repeated fixture rebuild discriminator

The coordinator granted only two quick reductions, both now completed:

- `render-geometry-only-lifetime-20261024T010657Z`: the 5/25/49 geometry sequence,
  with the 49-crew capture and no warnings, passes 23 assertions but remains a
  strict FAIL (four 349,524-byte textures, IDs 25-28).
- `render-single49-before-warning-lifetime-20261024T010719Z`: only the 49-crew
  geometry plus the full warning capture sequence strictly PASSES 21 assertions.

Warnings and actual gameplay are unnecessary. The distinguishing tested sequence
is repeated geometry world rebuilds before the first awaited render/capture.
This does not identify the exact texture owner or establish a runtime/font/engine
fault. The disproven p=null intervention remains reverted. GPU was returned
immediately after these two results; no further probe was run. A possible future
matched comparison is normal frame/render draining between fixture rebuilds,
which has not been implemented or tested here.

## CPU-ready cadence comparison and ownership trace

No renderer was run for this preparation. The same `geometry-only` harness now
accepts mutually exclusive optional flags:

- No flag: original repeated rebuild/capture cadence, CPU 24 checks pass.
- `--drain-between-rebuilds`: one normal process frame, a frame_post_draw await
  only when rendered, then another process frame after each fixture world;
  CPU 27 checks pass. Complete fixture-state equality is checked across drains.
- `--drain-after-fixtures`: the same three added drain cycles after all fixture
  rebuilds, rather than between them; CPU 25 checks pass. This controls for
  merely waiting longer before teardown. Default final teardown is unchanged.

All resource observations store WeakRefs only. They read the source's ownership
chains: `campaign.gd:65` removes and queues the previous world, then replaces
its Adapter; Adapter owns Kit, Street, Fx and the explicit SystemFont; its world
nodes include Label3Ds referencing that font. Street and its WorldEnvironment
node both reference Environment, which references Sky and ProceduralSkyMaterial.
Kit caches loaded PackedScenes, shared mesh parts and original materials. Fx
uses pooled Label3Ds with implicit/default fonts; those engine-side font/cache
objects and GL allocation ownership are not exposed by these weak observations.
No cache clearing, explicit resource purge or runtime lifecycle edit was added.

The no-drain CPU control reaches four simultaneously live observed world/font/
environment/sky generations before its first frame. Old Adapter/Street/Fx/Kit
instances already expire as replacements occur; queued old world nodes still
reference their font/environment resources. Between-rebuild drains reduce the
observed live generations to one after each fixture. Matched end-only drains
also eventually reduce them to one. Every watched object expires after final
teardown in all three CPU cases. This identifies concrete concurrent reference
owners, but does not map a leaked GL texture ID to one of them or prove a fix.

A byte-level metadata inventory of all 43 original GLBs reports zero image and
texture entries. Imported bitmap resources are therefore absent from those GLB
files; this does not exclude generated sky, font or renderer textures. The small
ignored inventory and exact binary hashes are indexed by TEXTURE_LIFETIME.json.

CPU packets: cadence-control-lifetime-20261024T011329Z,
cadence-between-lifetime-20261024T011333Z, and
cadence-after-lifetime-20261024T011335Z. All previous strict rendered failures
remain retained. These new cases are CPU-ready only, awaiting coordinator grant.

```powershell
python android-games/dead-run/tests/run_graphics.py lifetime --headless --label cadence-control --scenario geometry-only
python android-games/dead-run/tests/run_graphics.py lifetime --headless --label cadence-between --scenario geometry-only --drain-between-rebuilds
python android-games/dead-run/tests/run_graphics.py lifetime --headless --label cadence-after --scenario geometry-only --drain-after-fixtures
```

## Reviewed bounded strict closure

The three rendered cases executed identical 214 LF source hashes: baseline
strict FAIL (24 assertions), between-rebuild drains strict PASS (27), and the
same three added drain cycles only at the end strict FAIL (25). Both failures
retain four 349,524-byte allocations. This distinguishes fixture scheduling
from simply delaying final shutdown, without a resource purge or error filter.

Only seven lines in the original terminal_design geometry loop were changed:
each separate frozen fixture now receives process_frame / frame_post_draw /
process_frame cadence, plus a whole-state equality assertion. Product source
remains identical to edeb2d1. CPU full passes 52 checks; rendered full passes
54 (all original 51 plus three state checks), zero raw errors, exit zero,
source unchanged, and all ten PNGs fully decode. Successful packet:
`.artifacts/graphics/cadence-full-render-design-20261024T012650Z`.

Astra independently verified the matched/full source maps, exact seven-line
diff, raw 54/0, all ten PNG hashes/decodes, and empty product-source delta. Final
disposition: **bounded strict rendered gate clear**. The review receipt is
`astra-disposition.json` in the successful packet. The correction concerns
synthetic fixture scheduling. Old failed stress receipts remain FAIL and retained.
No exact GL allocation owner, font/engine bug or production stress-leak guarantee
is inferred. Native Android, physical performance, sound and human acceptance
remain separate. No additional renderer run is authorized by this record.
