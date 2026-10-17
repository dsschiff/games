# Gear Bastion campaign architecture

2026-10-17. GPT-6 Astra High design review based on the committed tutorial and written reference observations. No footage playback, game execution or phone acceptance in this review. This guides authorized implementation after the save/dispatch/strategy gate; it does not waive that gate.

The campaign should repeat preparation of a productive gear network, an abundant visible army, and a response when enemies expose a weakness. Preparation between battles is supported by the Nightmare samples; continuous dragging is not compulsory reference behavior.

## Arc and content

Start with three acts and approximately 9–12 encounters, adjusting after actual playthrough timing. Act 1 teaches connectivity, adjacent bonuses, merging, guard/ranger composition, constrained budgets and connection-versus-rate placement. Act 2 introduces one distinct third role, restricted sockets and mixed formations; alternate placement, composition and timing decisions. Act 3 combines changing fronts, sustained pressure and a multi-phase siege with the same visible board/army/wall composition.

Target 30–60 minutes through distinct decisions and satisfying battles. Record successful-clear time, preparation, failures and optional challenges separately. Advance cleared waves promptly or allow sending the next wave; do not pad solved fights with waits or idle farming. Each encounter must earn inclusion by adding a decision.

Guard provides efficient short-range protection. Ranger provides fragile ranged damage, useful against armored single targets but needing protection. Mortar is slow bounded splash that favors dense targets and sacrifices single-target efficiency. Add a fourth role only if it creates a demonstrated choice. A support role must not create invulnerability or erase frontline investment.

Use ordinary raiders, fast flankers, armored attackers and dispersed/ranged threats before inventing more roles. Introduce behaviors clearly before mixing them. Bosses alter the familiar problem: armored leader with escorts, siege pressure on the wall, and a final concentrated-versus-spread push. Forecast response windows; do not disable the board, erase builds arbitrarily or substitute another minigame. Toughness should enable decisions, not extend a solved fight.

## Implementation boundaries

- Encounter data owns sockets, starting board, budget, allowed generators, enemy groups, triggers and objectives.
- Deterministic reusable rules own connectivity, production, fair dispatch, movement, targeting, damage and rewards.
- Profile progression owns access, unlocks and earned medals; presentation consumes simulation events.
- Keep rules consistent. Prefer rearrangements of understood mechanics to bespoke exceptions. Preserve army abundance with bounded simulation and readable formations; record cap time so additional production remains meaningful.

Use a versioned save envelope separating profile from active run. Preserve encounter definition version, seed/RNG, board, resources, actors, buffers, dispatch cursor, waves and settings. Retain a compact active configuration snapshot or explicit content migration so updates do not silently invalidate an ongoing battle. Test resumed versus uninterrupted outcomes and recoverable prior saves.

## Content acceptance

For each encounter document its intended decision and demonstrate two comparably funded viable approaches with meaningfully different composition, placement or spending; an understandable mistake; and a useful correction through actual gameplay rather than injected state or extra resources. Check nearby spawn offsets, modest timing changes and placement changes so success is not one brittle scripted solution.

Run campaign baselines: unchanged starter board, cheapest-generator spam, single-role spam, no spending and simple balanced spending. Their outcomes expose dominant policies and automatic victories. Passive tutorial victory is acceptable; the whole campaign must not share it. Record wall margins, production/survival by role, spending, cap time and idle waiting; these explain results but do not certify fun.

After the finale, curated seeded challenge variants and optional efficiency/wall-damage medals provide replay. Add endless play only after readable scaling and strategic variety hold. Full campaign implementation begins after the present fix/challenge checkpoint passes independent review.
