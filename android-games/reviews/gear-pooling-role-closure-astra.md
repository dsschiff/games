# Gear pooling and remaining-role closure review

2026-10-18. **Pooling closes; production presentation acceptance remains withheld for captain/siege concealment in dense actual fights.** Carapace coverage is now supported. This is additive to `gear-production-final-astra.md` and `gear-pooling-early-source-astra.md`; it does not rewrite the six historical films or their observed eight-area scores.

## Binding and actual playback

Worker was clean at `cfff7013bfb1ce3e41a11721b84aa8c602d34c7f`. Independently compared 125 art/runtime/config/scene pins from each of the four capture packets against that checkout: no differences. Pool actor/foundry hashes exactly match the earlier source review. The delta from historical `01f650a` is pooling runtime, its focused harness and documentation/evidence; rules/save behavior and authored GLBs are unchanged. Each original MP4, receipt and gameplay report independently matches the root packet hash; receipts pass and declare unchanged source.

| Passage | Native original | SHA-256 | Playback |
|---|---|---|---|
| Reuse | 720×1680, 15.533s | `019a636225e60a857398b5f5f3e2a78c13db590137acc7a0aedf72e71536569c` | Complete 1× to ended |
| Captain | 720×1680, 13.466s | `35627aad06c6f936d489fabe8d2425941ed5a27e7d10af64dc148ea21ec249fe` | Two complete 1× passes |
| Siege | 720×1680, 16.133s | `30130034cd52cb25c47967aa5655af16fa16913153879f5caf3d5d03d21709b5` | Two complete 1× passes |
| Carapace | 720×1680, 33.933s | `086d9b1698ee5aa72f4b7faa67a553c6bb69bcdf2a000ce26aff6aa92171d3ab` | Complete 1× to ended |

Used one owned Brave fallback tab `413128857`, root viewer `http://127.0.0.1:58489/`. Every play began with the visible start-at-1× button and ran naturally to `ended=true`; no post-start seeking, playback acceleration or substituted excerpt. Initial zero-seek events belong to the viewer's start control. Visible DOM records, including the second complete boss passes and Hearth inspection, are retained in `../graphics-overhaul/gear-pooling-review/astra-playback-audit.json`. Tab closed and GPU slot explicitly released. Visual observations are sampled screenshots during natural playback plus directly inspected original native frames, not a claim to have inspected every frame continuously.

## Closed: actual pooling and carapace coverage

The source clearance remains valid: role/side compatible actor/model/rig instances and separate effect nodes are reused with clean transform/pose/contact/health resets, bounded reserves, and ID/epoch ownership kept outside the borrowed node. The 456 focused CPU assertions cover the detailed reset cases. The actual reuse run resumes genuine indexed camp_05 state at time 36, advances to 48.267 and pauses; its report records one actor reuse and 138 effect reuses, with 120 active actors, four inactive actors and 17 inactive effects at the endpoint. Natural playback shows ongoing deployment and troop movement into the dense group, then a settled pause at 14.884s; no visible stale corpse, displaced shot or pool reappearance artifact was apparent in sampled views. Object identity itself is established by source/fixtures, not guessed from pixels.

Carapace's lavender armored shell, projecting mandibles and articulated six legs are clearly distinct in ordinary play. At 0.571s a separate insect advances left of the troop stream; around 10.077s several engage both columns; at 21.579s the enemy bodies, engaged fronts and fallen allied poses remain separable. Native frames `000300.png` (10s) and `000650.png` (21.667s) confirm shell/limb/contact detail at original resolution. The 33.933s endpoint has moved to the next wave and paused with the visible carapace cohort removed. This closes the prior unseen-role coverage for carapace at the existing adequate 3/4 standard, without asserting visibility of every hit or that this short Iron Trial passage clears the whole trial.

## Blocker: captain and siege disappear beneath the friendly crowd

The closer passes did not resolve this. Captain's early red crest is a small sliver above overlapping allied helmets; the body and mandible action cannot be followed. Native captain frame `000090.png` (3s) conceals the boss inside the 106-ally mass; `000240.png` (8s) still leaves its body/contact obscured while the HUD reports Phase 2 / 773 HP. Siege native `000090.png` (3s) and `000330.png` (11s) similarly show a helmet/health-bar mass in place of a readable cannon-bearing boss. Browser samples at 0–1.302s captain and 0–0.995s siege repeat that concealment. Later Gate Held overlays prove an outcome but do not expose the boss's fall/removal animation. Telemetry's attack/hit/defeat flags and zero socket error cannot close this visual requirement.

The cause is presentation geometry/composition: `art/source/build_assets.py:138` authors low insect bodies (boss torso height .46, with captain/siege shell dimensions roughly .55/.58 by .65/.72 by .48/.46), while Foundry places all actors at their rule-projected positions with ordinary depth occlusion. Converging tall friendly bodies occupy the foreground and cover the bosses' body and attack equipment. These are sampled original native frames, so this is not only the browser viewer's downscaling. A separate HUD preserves tactical HP/phase information but does not repair the missing modeled action.

For these two roles specifically, visible attack/contact and dense-scene readability remain **2/4**, below the required 3. Historical eight-row 3/4 judgments covered the previously observed set and do not grant an exception for these newly observed roles.

Bounded correction: make captain/siege silhouettes and attack equipment remain visible in this actual dense encounter, for example by raising/enlarging their authored body and weapon profiles with grounded legs, or by deterministic presentation-only spacing/occlusion treatment around the boss. Preserve logical positions, rule timing, targets, IDs and saves; recompute/authenticate the visible contact socket if geometry changes. A label, sparse showcase or counters alone would leave this issue intact. Reuse these genuine retained boss starts for short normal-speed evidence showing the corrected dense fight, recognizable weapon action/contact and removal. No new whole campaign or replay of the old six films is requested.

## Timing qualification

New standalone metrics run `motion-metrics-20261018T163237858075Z`: independently counted 2,575 raw rows, including 2,425 heavy rows totaling 41.136943s, with nine heavy intervals above 33.333ms; overall maximum 48.706ms. Reported heavy median 16.670ms, p95 18.058ms, p99 22.313ms. The normal real-time sampler has no fixed-FPS/movie writer or still readback during measurement. These are Windows RTX 5070 Ti / Compatibility render-loop submission intervals, not GPU or OS-present timestamps or phone FPS. Visible 3D counters exclude shadow passes; main draw CPU time covers the 2D callback only. This is not a controlled A/B speedup claim and does not waive the visible boss defect.

No Android release/install, physical performance, audio, pacing or fun acceptance follows from this review. Keep the current candidate undelivered until the bounded boss presentation issue is closed.
