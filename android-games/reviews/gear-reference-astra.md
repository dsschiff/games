# Gear reference interpretation review

2026-10-17. Reviewer: GPT-6 Astra High. Scope: the recorded observations and proposed design in `references/gear-defenders.md`; the reviewer did not independently watch the footage.

**Verdict: ready for prototype, not final campaign fidelity acceptance.**

Preserve the portrait battlefield, wall exits, powered lower board and visible troop production. The defining demonstration is drag a drive into the powered network, visibly alter generator units/second, see troops leave the wall and hold or lose it while board interaction remains available.

## Required implementation decisions

- Use orthogonal connectivity flood-fill from the core. Generator speed is base rate multiplied by `1 + 0.25 * sum(adjacent powered drive levels)`, capped at 3x. This is our original deterministic rule; no cyclic or path-dependent amplification.
- Treat gate assignment, orthogonal connectivity, merges, core relocation and the multiplier cap as original choices rather than observed reference facts.
- Preserve the growing-army payoff; start with a 120-troop cap and measure density/readability/performance before finalizing it. Keep production choices consequential at the cap.
- Keep direct placement/rearrangement/merge responsive. Invalid placement preserves the original arrangement; do not add routine confirmation dialogs without a demonstrated need.
- Build progression around learned decisions: connectivity and melee/ranged balance, constrained boards/counter-pressure, then combined sustained pressure. Add roles/bosses only when they create different responses.

## Prototype acceptance

Input-driven playthroughs must demonstrate disconnection/reconnection, perceptible production change, two viable layouts, a repairable failed strategy, victory, defeat and immediate retry. Preserve uninterrupted comparison footage with both board and battle visible.

Before final campaign fidelity acceptance, review the full sustained walkthrough and a late-level recording. Existing samples establish the central loop but not exact late-game balance, gear math or gate behavior.

