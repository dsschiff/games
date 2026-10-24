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
