# Combat feedback and danger-footprint increment

A gold impact now means the diver actually damaged or defeated a creature. The
weapon still launches and resolves on its existing timing when movement makes a
swing miss, but a miss no longer produces a successful-hit burst. Front armor
gets a separate pale blocked impact. Genuine hits remain visible even if a tender
heals the lost hull in the same tick, because the rule-owned hit flash still proves
contact. Pause, hydration and repeated refreshes replay no impact.

Ground strips now cover the existing player-centre danger widths: 0.8m for line
attacks, 0.9m for charge sweeps and 0.5m for projectile direction cues. Previously
the central strip was only 0.575m wide on each side, and the projectile branches
only 0.25m. Line/charge paint includes the round collision endcaps using a
conservative rectangle, including rotated aims. The rules test the diver centre,
so the visual does not add the diver body radius again. Projectile strips remain
windup direction cues, not a claim to mark every future projectile position.

This preserves chain release/contact timing, targeting, damage, shields,
recovery, salvage, purchases, enemy geometry, pinned campaign definitions and
save schemas. Only scripts/presentation/adapter.gd changes runtime behavior.
Android code6, app identity, signing and all original art remain unchanged. No
new level, resource, currency, consumption or player-growth mechanic was added.
The qualified Butcher Hero source boundary remains in ../references/butcher-hero.md.

## Evidence

DESIGN_INCREMENT.json binds private run logs/reports and final runtime source.
All execution was CPU/headless with Dummy audio. No renderer, Android, clipboard,
browser or cloud service was used.

- Baseline actual input: the joystick approaches a creature and starts a chain;
  retreating before contact leaves its hull unchanged, yet the old observer emits
  gold contact. Re-approaching produces real damage. Five failures in 11 checks
  reproduce that false hit plus undersized line/charge/branch danger strips.
- Final focused regression: 53 checks pass. Actual engine input proves miss and
  genuine contact; explicit fixtures cover blocked feedback, healing within the
  hit tick, grouped events, immutable state, no hydration replay, exact danger
  widths and rotated line/charge endpoint coverage for ordinary/boss sizes.
- Final-runtime presentation suite: 214 checks pass, including actor/pool resets,
  read-only state, chain attachment/contact pose, essential reduced-effects
  telegraphs and side-by-side full-state stepping on all 13 prologue/campaign maps.
- Existing opening input: 18 checks pass with actual movement, chain attack,
  salvage, the 36-salvage Tidecutter purchase (power100 to200/full hull), stronger
  pen, natural loss/Retry, victory and reload. This verifies the existing earned
  progression loop; it is not a newly invented upgrade system.
- Legacy rules57, campaign81, import8, save-review31 and resize/input108 checks
  pass. Those broad runs preceded only the final paint-endcap extension; their
  combat/save modules and the hit-result classification equal the final source.

Reproduce:

```powershell
python android-games/hook-and-hunger/tests/run_graphics.py contact_feedback presentation_tests
python android-games/hook-and-hunger/tests/run_graphics.py run_tests campaign_checks import_regression review_save_regressions graphics_input playthrough
```

The CPU runner now keeps source hashes in place instead of making duplicate
source snapshots, uses Dummy audio, and requires the suite's explicit PASS marker.
Existing failure receipts stay failed; synthetic fixtures never become earned
progression or phone evidence.

Independent rendered discrimination of swing/miss/hit/block, readable paint at
normal speed, genuine Android update retention, physical touch/folding/safe
areas, phone performance, audible sound and human pacing/fun remain unverified.
The coordinator owns serialized runtime work, version/signing and private release.
