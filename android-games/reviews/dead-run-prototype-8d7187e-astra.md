# Dead Run — first-loop review

Reviewed 2026-10-18. Frozen worker `8d7187e33a18034e69fdc0c94b4bffa2368cf9e4`, integrated `2ef5245069dfa92555f10b93c5e2505139e14a16`.

**Visual/playable direction: conditional go. Correctness: fix one P2 before accepting this checkpoint.** The slice preserves lateral formation steering, continuous forward fire, shot-changing signed gates, visible gain and harm, and a sustained side target competing with ordinary infected pressure. It is a sound direction for expansion. The exhausted-squad/crane-reward ordering can produce an accepted import that becomes unsaveable on the next ordinary step; the planned amendment is not yet reviewed or accepted here.

## P2 — resolve exhaustion before a queued crane reward can revive the squad

`scripts/rules.gd:117–137` applies contact losses and then processes in-flight projectiles. Defeat is decided only at line 138. A final crane hit at lines 93–99 therefore grants three crew after contact has already reduced the last crew member to zero. This contradicts depletion-as-loss and, when a two-crew contact truncates to a one-crew actual loss, creates a positive-crew state rejected by the loss ledger at lines 194–197. `save_store.gd:64` then refuses subsequent saves. The save error is displayed; it does not repair the run.

The reviewer identified this ordering statically. The coordinator independently reproduced it with a **synthetic controlled valid save**, not a naturally earned route: tick 1226, crew 1, joined 4/lost 6, crossed gates +4/−6, crane HP 1/hits 119, an infected reaching contact on the next step, and an in-flight left projectile at z=11.99. Before stepping, both `R.valid` and checked encode/decode accept it. One ordinary `R.step` produces playing/crew 3, joined 7/lost 7, leaks 1/contact 1, crane 0/claimed true, but both validation and decode reject it.

I read the probe, isolated report and stdout. `.artifacts/dead-run-exhaustion-isolated/report.json` records exit 0, no OS/script errors and unchanged source `6ca0146bc88009ae19748b95fc2010e512a8ae72bbb7d3c6221eaeffe32b6f70`. Report SHA-256: `f937236ba04044cb735a9907bcf1b74508b45b7a24f35b52d1631d675e07dd34`; stdout SHA-256: `65e1e7e1cb919ca887287ae07b2db638ce03847ecb6a88053da8a27d464e6926`. The earlier default-APPDATA-denied observer attempt remains separate. This establishes a valid-import/ordinary-step/save-validity defect, not exact natural-input reachability or Android reproduction. I did not execute the probe.

Minimal closure: give depletion deterministic terminal precedence before any subsequent reward can revive the squad, preserve a valid terminal save, and regress the same-tick lethal-contact/final-crane-hit case. Include a paired surviving-contact case that still earns its legitimate crane reward and remains saveable. Check stable terminal stepping and checked save round trips; an explicitly labelled GUI-import fixture followed by ordinary processing can verify app-level retention. Close this only against the frozen fix and its evidence, not the builder's intention to fix it.

## Direct visual evidence

Played the complete **87.233333-second continuous original MP4** from start through its natural ending at the coordinator's loopback server, without a playback seek. A second replay supplied additional late-route observations; attempted Right-key navigation did not move playback, and the replay continued from the beginning. Settled screenshots sampled approximately 0/4/7/12/21/26/33/38/42/47/end in the first pass and 3/14/29/35/39/45/49/56/60/66/72/79/86/87 in the second. These are sampled observations during full continuous playback, not exhaustive frame inspection. The dark final recording frame is not treated as a gameplay failure.

Also directly viewed the original movie PNGs: natural loss, Retry, recruits joining, side target under fire, forward-fire tradeoff, harmful crossing, crane riggers joining, final pressure and objective victory. In particular:

- The first centre gate changes from −6 to +6 under visible forward fire. Its approaching warning remains readable, then the formation grows from three to nine.
- Holding the centre in the first route lets infected pass elsewhere. Crew visibly depletes, the loss panel explains depletion, and actual Retry restores three crew and both original gates.
- In the successful route, the crew moves left and the crane counter falls while infected keep approaching. Returning fire to the road leaves the unfinished crane alive; later left-side windows finish it. The recorded source snapshots bind the pause in crane damage to increased infected kills.
- The second crossing removes six crew, leaving three. Continued steering and fire recover the crane's three riggers and suppress the road. The crane is an ordinary-road opportunity, not merely the final encounter.
- At roughly 72 seconds of the recording, six crew face the arriving centre barricade while remaining infected are present. By the later checkpoint the barricade is gone. The original natural-victory PNG shows CONVOY EVACUATED, six crew and no leaks; its source snapshot is tick 3000 with all 24 infected killed and final HP zero.

The camera, lower-quarter squad and receding bridge match the selected activity. Gate numerals, crew count, warnings and terminal controls are readable in the full raw captures. This is not a joystick arena or shelter-management substitution. The original Spore crane avoids copying the ad's large character while retaining its sustained-fire side-target function.

## Source and test interpretation

Read the qualified Last Human brief including its full 51.581-second L2 follow-up, handoff, README/CHECKPOINT, all game rules/save/main code and the input/rule/fault tests. This pass does not claim a new commercial-footage viewing. L2 remains a user recording of a visibly labelled Last Human ad; authentic advertiser-library provenance and exact commercial equations remain unresolved. Last Z is only a comparison. The prototype's +1 per projectile, +6 gate cap, −6/−12 starts, crew cap 12 and crane reward are explicitly original rules, not measured reference formulas.

Normal targeting selects the nearest intersected object; gates cross once; equipment-free formation growth changes actual projectile count. IDs, pinned encounter values, finite numeric bounds, reward ledgers and checked envelopes are validated. Saves alternate slots, prioritize the highest eligible revision and exclude unpromoted imported temps. Import promotes to disk before changing memory. No additional consequential persistence defect was confirmed in this bounded read.

The input policy reads state and sends actual ScreenTouch/ScreenDrag/keyboard events. It does not inject earned progress or call gameplay handlers. Code-box assignment and the fault adapter are explicitly synthetic fixtures. The rule total includes many per-member footprint checks; it is not 124 independent campaign scenarios. The successful route checks every tick, but cannot establish all simultaneous-event orderings, as the P2 demonstrates. Scene recreation tests are not a separate Android process or OS lifecycle test. Rendered clipboard readback and injected Unicode are desktop evidence, not Android IME acceptance.

The immutable package reports 21 executed source bindings, all 23 tracked LF bindings, 289 accepted receipt-artifact rows and 26 accepted decoded PNGs. The four accepted builder suites report 124 rules, 34 headless input, 35 rendered input and 15 movie assertions. These are reviewed builder/binding records; independent coordinator tests are separate. Earlier restricted clipboard errors remain preserved and excluded. No reviewer test, build, APK or ADB execution occurred.

| Evidence | SHA-256 |
| --- | --- |
| Complete MP4 | `3518fc3f47a0d5a1798b1def7228cf3495abcd6f9cd1dbeda41d98c43f94a237` |
| review-package.json | `94e159789517f95098f0d885ee1866e6fca8bbb005c39b2dc774849a08740874` |
| binding-verification.json | `742b115792361100ebb9915f82e76a8b0c83404994e8f9c60ec675ffece72c55` |
| Recruits joining PNG | `ab9306d758d219e60b077002deafe59ce7c46a0acd96dd658049f01e57433955` |
| Harmful crossing PNG | `819985c60ff09aa412488a0b93e17ac8afd420c5d5af32401c3e1cf0ea72ed58` |
| Objective victory PNG | `c6ab764ddd6fee47e91027403da9efb3e51cdf50c62e7448a8f82551f501fa67` |

## Campaign conditions and limits

The current sparse infected and large empty region above the bridge establish readability but not the source's dense crowd pressure. Improve usable composition and richer visible groups without sacrificing the two-second decision horizon or simply inflating hit points. Keep large side targets present during ordinary stages and show alternate successful lane priorities, not one mandatory scripted sequence repeated with larger numbers.

One concrete visual mismatch should be resolved before narrow campaign hazards: `main.gd:463–464` shifts every crew index above two up to 1.4 world units sideways for 1.5 seconds after each gain. The raw join captures show recruits outside the gold footprint even though bullets and collisions use settled offsets. The cue advertises that footprint as the contact boundary. Clearly distinguish arriving, noncolliding recruits or keep the visual formation/footprint aligned; do not make the player guess which visible bodies count. This does not cause the P2 and is a separate nonblocking prototype presentation issue.

The brief's substantive arc remains: provisional 24 stages/four districts, three weapon families, six enemy roles, four bosses, conclusive evacuation, seeded layouts, rescue/no-loss medals and endless evacuation. Counts must earn their place through different targeting, gate, formation-width and side-opportunity decisions. Bound and pin run definitions for saves/replay; preserve catalog-1 active runs and settings rather than turning a prototype victory into invented campaign progress. Avoid long empty-road tails after all decisions are resolved. One fifty-second winning bridge does not establish a meaningful 30–60-minute arc, human pacing or fun.

After exact P2 closure, proceed through coordinator independent source-bound checks and root Android delivery gates. Native Back/clipboard/IME, cold-process/update preservation and Android rendering are still unclaimed here. Physical Fold7 touch, folding/safe areas, measured FPS, audible sound and fun remain open. Final full-campaign fidelity requires a later frozen review. The owned browser tab is closed; the coordinator may stop the server on port 18193.

## Additive exhaustion closure — 9952c89, 2026-10-18

**The original P2 is closed for worker `9952c89a18e72546609b01e503cf8bfdfb5e6ac0`, integrated as `3d7e4d6`.** The original finding and old-source evidence above remain historical. This is narrow independent static/evidence review, not reviewer execution or full campaign/native acceptance.

The only production delta moves the existing zero-crew defeat decision to `scripts/rules.gd:127–131`, after all gate/enemy movement and contacts but before new firing and queued projectile impacts. It returns immediately. The validator is unchanged. Fatal contact therefore cannot be undone by a later queued crane reward; surviving formations still process that same reward. Subsequent terminal steps remain inert. No encounter, arithmetic, schema, renderer or input changes are hidden in the fix.

Read the exact old/new diff, `tests/exhaustion_fixture.gd`, `tests/exhaustion_playthrough.gd:10–54`, new rule regressions, amendment reports and recorded old-source sensitivity. The fixtures deliberately create valid imported boundary states; they are **not naturally earned or proven touch-reachable**. The GUI test assigns encoded text to the transfer TextEdit, then uses actual GUI Import/Resume and ordinary engine processing. It does not directly replace the live model or call gameplay handlers. Its checks cover whole imported state on disk, natural terminal rendering, complete post-boundary checked saves and scene re-instantiation from those saves. That last check is a desktop scene restore, not an Android process restart.

The fatal fixture now becomes tick1227/defeat/crew0/joined4/lost7, with crane HP1, reward unclaimed and the queued bullet unmoved. The paired surviving fixture goes from crew3 through contact to crew1, then receives exactly three recruits: crew4/joined9/lost8/crane0. Both remain valid and encode/decode successfully. The 17-check rendered report records zero failures; directly inspected `boundary-after-false.png` shows CREW0/Crane1/RESCUE LOST, while `boundary-after-true.png` shows CREW4/Crane0 and the earned-recruit notice. These are correctly labelled controlled-import outcomes.

The new 139-check rule suite against exact old rules records five expected failures specifically for post-step validity/decode, revival/payout and terminal stability; the living case passes. This is useful defect sensitivity, not a renamed old-source pass. The retained first GUI-helper failure is also disclosed. The normal-route comparison reports unchanged model snapshots within 1e-9 except three terminal-loss projectile positions intentionally frozen one tick earlier; loss remains tick2072 and victory tick3000. The original 87.233333s movie remains bound to **8d7187e**. No retake is necessary for this ordering-only closure, and it must not be relabelled as amended-source footage.

Read the coordinator's independent amended-root report at `.artifacts/dead-run-exhaustion-amended-root-20261018T054512420702Z/report.json`: the exact original probe (`768f858030742264131d868cdba22b1810e9cc4f9466188eb067496919355d11`) now records valid input and valid terminal output, exit0 and no engine errors against rules SHA256 `7b3b5e45ef81e97aa9d1b1ebce72e751ed8416f82193913a14492ef58130290c`. Report SHA256: `f29dcbd6313b6c83952d3b0bd3c037ff86f647fc5805dd6061532d7a79c46b3f`. This is coordinator execution, not mine.

Additional evidence bindings: `AMENDMENT-EXHAUSTION.json` SHA256 `20cd768f06f8da87e53b7db97d9d4a57fe9bae3c4584d531b39f7e702a6c0880`; focused rendered receipt `9ed17623581b750877b47a15efe3282de8d04c5d377f611aab77c7330d428a51`; fatal PNG `f26d3391138c017960234ec1a99653d96d617b1474531a8e5f8bfa349e840d91`; surviving PNG `67e249c724aeeef409028791737258bebfb4f319a0507df5803a0c92faa67834`. New executed raw bundle `7db7e08641e50c159ea437575a27544c6bb050821d1cfa6309e4953e0d569320` and LF bundle `18d5f271d33270f2a2e777d3d1a339f5d79c487dbfb5c1326cf00f4033028f2d` are recorded separately from original source.

No new P1/P2 was established in this delta. Proceed through the remaining independent amended-source and root Android delivery gates. Previous formation-arrival presentation and full-campaign conditions remain; no physical phone, IME, FPS, sound, duration or fun claim is added. Code1 need not increment for this pre-first-APK fix, as no original Dead Run APK was exported or installed.
