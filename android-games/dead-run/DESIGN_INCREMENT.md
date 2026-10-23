# First continuous-design increment

The completed road now offers Retry (and Next Road after a campaign win), with no
Resume after Home, close, transfer, Back or cold restore. Ready roads keep Start;
active roads still pause and resume. Campaign and the parked legacy bridge share
the phase-aware suspension behavior. Import feedback names the action available
for the imported phase. The result includes actual crew gain/loss and stopped
infected, and explains that Retry starts fresh while restored roads stay unlocked.

The warning line prioritizes the earliest unresolved damaging lane attack,
independent of array order. When no attack remains, the nearest approaching gate
or cart precedes the boss tactic. Toll Ram and Ferry Eater health no longer replace
a live attack countdown; their world health bars remain available.

Only a frozen defeated blockade scene receives mesh clearance. The largest
49-person crew has 0.25 metres between equipment and the blockade (5/25 crew have
0.97 metres). During active combat the blockade retains its original transform,
projectile relation, rule position and contact timing. This is a terminal
composition correction, not a change to active collision geometry.

No rules, catalogs, encounter definitions, progression, save formats, signing,
package identity or Android version/preset changed from base 4552e7b. No content
or artificial grind was added. Reference boundaries in ../references/last-human.md
remain unchanged, including qualified commercial gate arithmetic.

## Evidence

`DESIGN_INCREMENT.json` binds source and private run receipts/logs. All invocations
use isolated app data and Dummy audio. CPU checks used no GPU; the separately
authorized rendered pass used the desktop GPU. No clipboard, Android or browser
was used.

- Original defect reproduction: 9 failures in 23 checks, including natural loss
  and earned victory. Measured old blockade overlap: 1.50m at 5/25 crew, 2.22m at 49.
- Final focused input: 49 checks pass, with actual Godot GUI touches/drag producing
  natural loss, Retry and victory; active Pause/Resume; Home/transfer/Back/close;
  cold whole-terminal-state restore; Next Road; legacy natural loss/Retry.
- Engine notifications: 9 checks pass. Legacy Back now starts a real active bridge
  before checking exactly one pause/save across the inheritance chain. The first
  7/8 run retained an obsolete ready-state pause assumption; that failure is not
  relabelled as a pass.
- Presentation: 22 checks pass, including whole authoritative state equivalence
  against a presentation-free control across opening/middle/final roads, bounded
  pools, pause freezing, hydration and essential reduced-effects telegraphs.
- Genuine code4 continuation/upgrade: 10 checks pass. Legacy rules: 139 checks pass.
  Campaign/storage: 289 checks pass. These three execute before the final
  terminal-only presentation clamp; their authoritative rule/save sources are
  identical to the final implementation.
- Warning and geometry fixtures are explicitly synthetic and never persisted as
  earned progress. They verify earliest fire tick, reversed array order, boss2/4
  priority, resolved fallback, cart/gate order, state immutability, max-crew
  separation and unchanged active target transform.

Reproduce the focused check:

```powershell
python android-games/dead-run/tests/run_graphics.py design --headless
python android-games/dead-run/tests/run_graphics.py platform --headless
python android-games/dead-run/tests/run_graphics.py presentation --headless
```

The runner records LF source hashes, rejects source drift, and reuses source in
place instead of making repeated source snapshots. It can run existing rules,
campaign-rules and genuine code4 checks in isolated app data too.

## Rendered evidence and unresolved failure

The input-driven desktop run passes 51 assertions and produces natural loss,
Retry and earned victory layouts, including cover/inner sizes. A distinct
nonpersistent rule-policy fixture reaches active Toll Ram/Ferry Eater attacks;
its warning remains visible with world boss health. The 49-crew geometry image
is explicitly labeled synthetic and hides the result card only for inspection.
All saved PNGs fully decode; these are desktop pixels, not Android screenshots.

**The strict full rendered run remains FAIL.** Four GL texture allocations of
349,524 bytes each leak during engine shutdown (1,398,096 bytes total). Both the
original failure and attempted closure logs/receipts remain indexed. Returning
from the test scenario, freeing its scene and draining rendering did not remove
these errors. The boss-only warning fixture exits cleanly; that narrower pass
does not override the full failure. No log filters or expected-error exception
were added. The pre-existing windowed teardown defect remains unresolved and
requires a separate resource-lifetime diagnosis.

## Remaining acceptance

The builder inspected result/warning/geometry stills; independent visual review
and natural-speed transition quality remain open, as do Android Home/Back/cold
behavior, physical Fold7 touch/folding/safe areas,
surge frame rate, audible sound or human fun. No APK was exported or installed.
The coordinator owns independent review, serialized rendered/native validation,
higher-version packaging and private delivery. Physical testing remains deferred.
