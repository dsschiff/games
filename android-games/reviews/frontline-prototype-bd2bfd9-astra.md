# Frontline Foundry — first-loop review

Reviewed 2026-10-18. Frozen worker `bd2bfd9d1758aa8cc7b3f6235884502ae3070a83`, integrated `cdf86a054483b56e1f2f255b2bc89c63b315e853`.

**Conditional go for campaign expansion. No confirmed P1/P2 correctness blocker in this bounded review.** The first loop establishes a connected commander, equipment base and adjacent battle: investment creates individually armed reinforcements that leave the queue, attack, take damage and change the outcome. It is promising enough to build on. This is neither full-game acceptance nor Android acceptance.

## Evidence and review scope

- Independently read frozen rules, save files/store, main input/rendering/lifecycle, rule controls, actual-input playthrough, separate-process restore, checkpoint packaging, README/CHECKPOINT, the handoff and qualified Top Force reference direction. No game tests, builds or Android commands were executed by this reviewer.
- Directly played the **whole 76.833-second continuous original movie**, from start to natural end, in the owned Brave tab at the coordinator's local server. After context compaction interrupted the first inspection, replayed from the beginning without seeking. Settled checkpoints included approximately 0, 21, 32, 47, 58, 74 and 76 seconds; the preceding pass also provided approximately 9 and 22 seconds. These are sampled observations of continuous playback, not exhaustive frame inspection. No montage or speed change is asserted. The final dark frame is the recording's ending, not a gameplay failure.
- Directly inspected original PNGs `07-visible-arming`, `08-departure`, `08b-recruit-combat`, `11-vehicle-combat`, `13-natural-victory`, `16-commander-defeat`, `17-immediate-retry` from `final-movie-20261018T041309653470Z`, plus `release-rendered-20261018T041715640833Z/02-hq-defeat.png`.
- The movie shows the successful route, actual Retry, commander-defeat route and another Retry. HQ defeat and the transfer/restore checks are separate evidence; they are not claimed to appear in that movie. The movie and main journey use actual engine touch/GUI events with ordinary simulation; synthetic paired controls in `tests/run_tests.gd:97` isolate reinforcement effects separately.
- Reviewed coordinator binding metadata: 26 declared source bindings, all 28 tracked LF equivalents, 300 declared artifact hashes, 284 copied artifacts and 16 verified cache artifacts intentionally not copied. These totals are coordinator verification, not a new independent rehash of every artifact by this reviewer. Accepted builder receipts report 69 rules, 40 headless input, 42 rendered input, 7 separate-process restore and 19 movie checks. Independent coordinator execution is a separate gate.
- The accepted movie's README toolchain-path correction and the packaging utility amendment are explicitly identified metadata differences. Runtime and input-test bytes are bound unchanged. The earlier Windows clipboard failure remains in `.artifacts/visual-rendered-20261018T035933744195Z/godot.log`; it is excluded from accepted evidence rather than silently replaced.

Identity hashes:

| Artifact | SHA-256 |
| --- | --- |
| Complete MP4 | `9e2fc629d6c3cf72ef5c47cd5dc0dcda4d055bf828a9cf3595cafb0ed89d8675` |
| Full review-package.json | `48b3c1dbdfb5a0b3ca175fd13991bf21cd3dac390217e851b2fd5120f1172e8a` |
| binding-verification.json | `8b7b360043e39f1d8c4230b255713e36b90bab08fcd44f3af9049f8331fa4d79` |
| Recruit combat PNG | `7264b71bdde22ce3c5d4b60fced3c3de56ce1b81ca80f34e58783423ca5c510b` |
| Natural victory PNG | `74ca851156b6f2393cabf76e3963f15bacb6a282645cf26561573177bb209c4a` |
| HQ defeat PNG | `da34ad9b810f2dcbde91312b5889a08df5403ca00aa82d3462fbc610605a6b7f` |

## What the slice establishes

The camera keeps the field, sandbag boundary, commander and two purchase stations together. The 8-scrap rifle purchase changes station appearance, consumes a finite stock and starts staggered arming; weapons appear on the actual departing recruits. The later 14-scrap rover has a distinct chassis and cannon. White rifle barrels, the large rover silhouette, gold commander, orange enemies and purple armored enemies remain distinguishable. Scrap drops, purchase prices and supplied states are readable. The HUD and terminal cards in the full raw captures are not clipped.

The causal chain is implemented rather than decorative: `scripts/rules.gd:71–107` consumes equipment and advances each recruit through arming, departure and combat; its own shot/damage counters and enemy HP change through `hit`. Real earned drops fund the second purchase. Armor changes damage effectiveness (`rules.gd:48–54`), making the rover more than a recolored rifle. The no-supply and rifle-only controls lose, while the complete route wins. The synthetic safe-commander comparison supports the reinforcement claim without being presented as human input.

The successful capture ends at 48 simulated seconds with ten stops, commander 92 and HQ 120. Separate captures clearly explain HQ breach versus commander loss. Immediate Retry restores the starting battle and supplies while retaining profile/settings. `rules.gd:172–178` guards one-time result recording; the import path writes successfully before replacing current memory (`main.gd:479–492`). The validator checks finite bounds, role/ID ownership, unique reward accounting and equipment conservation. Alternating-slot recovery selects the highest validated revision and excludes uncommitted import staging. No concrete normal-play corruption or duplication defect was found in this scope.

The selected T3 creative still has a **Top General** end card whose exact official Top Force mapping is unproven. The prior direct T3/T4/T5 source review supports the connected equipment/reinforcement/base theme. This pass does not newly view those commercial videos or convert inferred controls/economy into verified commercial rules. Explicit purchase taps, exact stock/costs, commander autofire and the armor formula are permissible original choices.

## Concrete campaign follow-ups

1. **Show incoming damage causally.** Enemy damage is applied at `rules.gd:120–143` without an attack event; `main.gd:494–516` and `622–628` draw friendly shots only. During the commander-loss sequence health decreases and the terminal cause is clear, but the source of each hit is much less legible than outgoing fire. Add a restrained enemy shot/contact cue and recipient hit reaction before using denser encounters to test tactical choices. This is a presentation limitation, not a confirmed first-loop P2: health, enemy proximity and defeat are already visible, and no unverified dodge mechanic is required.
2. **Make departure respect the pictured opening.** `rules.gd:89–98` moves recruits directly to their formation slots; the side sandbags drawn at `main.gd:149–151` intersect the outer recruits' route. The combat capture shows one recruit already beyond the left sandbags while others depart centrally. Give the route a gate waypoint, or make the boundary visually traversable. The current route reaches combat correctly; this is a visual continuity repair, not a stranded-unit defect.
3. **Reduce central label overlap.** `08b-recruit-combat.png` overlaps TO FRONT/YOU; later views stack rifle HP, rover HP, SENTRY and YOU. Use fewer persistent labels or offset them without hiding health. The stations and action button remain understandable, so this does not block the first loop.
4. **Do not multiply the current passive ending into the campaign.** After both purchases the winning commander stays safe while the complete formation clears much of the remaining wave. That is acceptable for the demonstration; twelve copies with larger numbers would not satisfy the intended initial arc. Later missions should change which station/role to fund first, where collection exposes the commander, which adjacent threat needs intervention and why a vehicle/support choice helps. Preserve the visible weapon-to-recruit-to-battle chain in every expansion. Multiple fronts, ammunition carts, medics and blueprints are not mandatory source-fidelity requirements.

## Expansion and remaining gates

Carry forward the brief's substantive campaign, ending and replay ambition: provisional 12 missions, four roles, three support buildings, six enemy roles and three bosses should be justified by distinct decisions, not treated as acceptance through counts. Demonstrate multiple useful investment orders across varied encounters, ordinary failure/Retry corrections, and counterfactual controls beyond the two current passing/failing layouts. Seeded replay must alter meaningful encounter decisions while keeping deterministic, bounded, saveable configurations. Preserve catalog-1 active battles and profile/settings on expansion; do not invent campaign clears from a prototype win.

Proceed after the coordinator's independent source-bound checks, retaining this version as the genuine old-APK upgrade fixture. APK export/install/update, native Back, clipboard/IME, lifecycle and actual Android rendering remain separate software gates. Physical Fold7 cover/inner behavior, touch comfort, FPS, audible sound and human fun remain unverified. Neither this short slice nor scripted completion proves the required 30–60-minute meaningful initial arc. Full campaign fidelity and appeal require another frozen review.

The owned review tab is closed. The coordinator can stop the movie-only server on port 18192.
