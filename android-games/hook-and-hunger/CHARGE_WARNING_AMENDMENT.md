# Charge warning follow-up

Current state: independently source verified; final refined-warning motion usefulness and the
rendered finale's two leaked ObjectDB objects remain open. This is a follow-up
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
they do not clear a rendered shutdown warning. Independent source proof clears
undercoverage, while useful dense warnings still require final rendered review.
All automated audio uses Dummy. Physical touch/folding, audible sound, measured
phone FPS and human fun remain unverified. Root owns integration, native checks
and release. Production is not frozen for publication here.
