# Charge warning follow-up

Current state: independently source verified; all three final refined captures pass
strict execution. Independent normal-speed usefulness review remains pending.
The earlier coarse finale warning is preserved and unexplained. This is a follow-up
to DESIGN_INCREMENT.md, not an approval or replacement for failed evidence.

Actual campaign step() reproduces two gaps in the original straight 6.8m charge
warning: the final full capped step can travel farther, and constrain() pushes
the charger sideways around rocks. At the authored layout 2 rock(0,-2.5,r1.2),
start(-1.4,-7), aim(0,1), dt 1/60, the charger reaches(-1.799934,-2.515413).
A diver at(-2.4,-2.515) takes 27 damage outside the old paint. The baseline has
12 failures in20 checks. No combat, roster, catalog, save, app version or art changed.

The adapter paints maximum speed 8 *(clock .85 + cap .05)=7.2m. Open charges retain
an oriented strip. For constrained routes, conservative reachable bounds include
field clamping and rock projection. Projection away from a rock preserves an
incoming coordinate's side, so the envelope clips unreachable opposite sides.
Every rock is revisited as bounds expand; only exact fixed-point equality ends
the refinement. If the bounded search exhausts, whole-disk closure is the safe
fallback. Accumulated bounds never shrink, and postprojection disk origins are
not clipped back to the field. Damage radius .9 expands the final centre envelope.

The first coarse fix mechanically covered damage but painted the exact left-rock
case on both sides, x[-2.7,+2.7]. Its 68.58m² rectangle was 3.70 times the actual
route bounding box including damage radius. It was rejected for usefulness;
5 opposite-side checks retain that failure. Refinement now paints x[-2.7,-.5],
27.94m², 1.509 times that 18.519m² bounding box. These are bounding-box areas,
not measured swept-union area or evidence of human readability.

Final CPU coverage: 1643 checks across 814 actual step() routes, all passed. This
includes the 3 authored layouts, boundary/rock/open starts,8 unit directions,
zero/nonunit saved-vector cases,60/30/.05/.017/variable timesteps and capped .08,
plus 12 explicitly synthetic overlapping/reversed/three-rock arrangements to
exercise side relaxation. Hull damage, swept segment centres/endcaps, unchanged
observed state and the exact repro's visibly safe opposite side are checked.
Contact 37/0 and presentation 214/0 pass. Existing rules 57 / campaign 81 / opening-input 18
also pass; they preceded only the presentation envelope refinement.

Normal-speed captures and source identities are bound in CHARGE_WARNING_AMENDMENT.json.
The first 30Hz intended-miss movie actually hit and remains failed/excluded.
Corrected 60Hz actual touch proves target hull24→24miss and24→12hit. Armor and
geometry arrangements are always labelled synthetic and are never saved as earned
play. Actual charger/finale continuations load whole historical earned checkpoints
only after matching the tracked campaign-checkpoint.json hashes; safe-goal input
reads visible warning geometry. Other enemy attacks still deal real damage, and
successful avoidance of one charge is not a claim of overall invulnerability.

The coarse finale had functional 6/0, actual defeat and 3 simultaneous charges,
but its strict receipt remains failed for 2 ObjectDB objects leaked at exit.
Two verbose headless natural-defeat controls did not reproduce that leak;
they do not clear a rendered shutdown warning. The final refined verbose capture
below now has clean shutdown; no speculative lifecycle fix or suppression was made.
Independent source proof clears undercoverage, while dense warning usefulness
still requires independent normal-speed review.
All automated audio uses Dummy. Physical touch/folding, audible sound, measured
phone FPS and human fun remain unverified. Root owns integration, native checks
and release. Production is not frozen for publication here.

## Final refined captures

All three 720x1280, 60fps, 1x clips pass strict execution with unchanged source,
Dummy audio, no warnings/errors and clean complete movie decode. Source-before
and source-after manifests are identical across the three runs. The receipt
paths and exact clip identities are bound in the JSON amendment.

| Capture | Checks | Duration / frames | Evidence limits |
| --- | --- | --- | --- |
| `004033301720Z` | 16 / 0 | 8.566667s / 514 | Real opening target hull24→24 miss then24→12 hit; separately labelled armor/line/rock-charge/projectile fixtures. |
| `004104204583Z` | 6 / 0 | 12.016667s / 721 | Hash-authenticated earned stage09, actual touch inside→outside sidestep; one of two recorded charge windows passes avoidance, later other attacks still damage hull. |
| `004147777153Z` | 6 / 0 | 10.85s / 651 | Hash-authenticated earned finale, two target-charge sidesteps, three simultaneous charges, genuine defeat. Verbose shutdown is clean; prior2ObjectDB classes cannot be identified because the warning did not recur. |

These suffixes identify `.artifacts/feedback-motion-20261024T<suffix>/`.
The refined rock fixture preserves a clear opposite side. The finale still shows
dense overlap between boss rings, charge envelopes and other attacks. Successful
input checks do not establish human readability, fun or overall no-damage play.
The original failed coarse finale receipt is unchanged and remains failed.
No production or harness source changed between the committed source verification
and these final captures. All renderer processes exited, the GPU slot was returned
to root, and disposable PNG frame sequences were removed only after verified full
movie decode; frame hashes and representative original PNGs remain.
