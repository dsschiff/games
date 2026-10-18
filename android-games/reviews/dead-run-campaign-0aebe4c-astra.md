# Dead Run campaign: independent static and playback review

Reviewed frozen original runtime `0aebe4c144aec08fc781d653f5f979fa0a6d8789`, then the two-validator-only amendment `f9609eb8cf03b99a814ae09e6334b5762fbbeea4`. No game tests, engine, Android, clipboard or device operations were executed by this reviewer. No tracked files changed.

## Playback and provenance

All three original recordings played from zero to `ended=true`, at rate 1, without seeking: early **79.016667s / 4,741 frames**, middle **113.983333s / 6,839**, final **128.983333s / 7,739**. Exact SHA256s, read-only playback states and UTC checkpoints are in `astra-playback-and-review.json`; original bindings are `media-bindings.json`. The owned Brave tab 413128733 was closed. Root may stop server/session31324 and reuse the foreground slot. No browser attempt failed.

These are three separate continuous recordings. Middle/final load genuine journey-written ready checkpoints, not an uninterrupted 37-minute campaign. Consecutive CUA screenshots were directly inspected during playback and retained in the conversation tool outputs; this is not a claim to inspect every decoded frame. All three final player images were blank; I did not infer an application black-frame failure. I separately directly viewed original `segment-early-victory.png`, `segment-middle-victory.png`, `segment-final-victory.png`, and `stage-24-final-threat.png` from their bound capture directories. Those show Road Restored (1/24 and12/24), Last Ferry Away (24/24), and the final boss with both outer arms respectively.

## Fidelity and visible consequences

The selected identity survives: portrait forward road, lower-screen squad whose gold footprint expands, continuous forward fire, signed gates whose values improve under fire and apply on crossing, ordinary roadside crane investment amid infected pressure, and lateral positioning. Existing source comparison is to the qualified Last Human footage; exact arithmetic, 20-person cap, weapons and bosses remain original design rather than verified universal commercial rules.

Early checkpoints show the crane counter and growing crew, then later crew10 after gate consequences; the raw terminal reports one rescue and15 lost. The full clip was played, but the negative crossing itself fell between captured screenshot checkpoints, so its exact arithmetic is supported by source/input evidence rather than an independently isolated visual frame sequence here. Middle shows Fan's wider projectile spread, a cart beside a positive gate, a countdown and orange spit lane, crew19 then20, and Toll Ram's shield/flank instruction and diminishing HP. Finale shows two roadside opportunities, a negative gate later converted positive, flood and cart consequences (crew20→18→17), recovery to20, and the Ferry Eater core phase with an orange sweep marker. The raw boss capture separately establishes visible outer-arm geometry; both arms had already broken by the approximately108s playback checkpoint. No unsupported claim that every arm hit was individually observed.

No new consequential HUD clipping, obscured near-field hazard or formation/footprint mismatch was observed. The high-level stage/crew/tool/progress information stays separated from the road. Gates and immediate orange hazards read better than distant infected and their tiny health marks. That scale difference is a **P3 phone-readability concern**, not demonstrated physical-device failure.

The later clips reach the crew cap and defeat the boss before the road ends, followed by comparatively sparse cleanup/countdown stretches (middle approximately98–111s, finale approximately121s near end). Carry **pacing and cap-heavy difficulty** to human playtest. The same road composition repeats; weapons, paired gates, carts, marked attacks, side-target disabling effects and boss weakpoints are substantive source differences, but three clips and37.67 scripted simulation minutes cannot establish that all24 roads sustain30–60 minutes of enjoyable human decisions. The same-road/same-weapon opposite-side-priority input follow-up is meaningful strategic evidence; the earlier alternatives that differed mostly in timing remain qualified.

## Two P2 defects and narrow amendment

Root independently reproduced the original findings in `.artifacts/verification/dead-run-campaign-adversarial-1338838-20261018T081940862440Z/assessment.json` (six headless processes, five script errors, unchanged source). A fresh **playing** checked import with Rivet period24.0000000001 passed validation and decoding, then ordinary stepping failed at modulo (`campaign_rules.gd:205`); this is not an observed process crash. A synthetic late cancelled boss hazard with null/array boss rejected the save but emitted script errors at the premature `boss.dead` access (`campaign_rules.gd:303`, preceding its former330 guard). Those are real validation defects even when a boolean result says rejected.

The amendment diff changes only `campaign_data.gd:same` and the placement of existing boss validation in `campaign_rules.gd:valid`. Integral operands now require exact equality, nonfinite values reject, legitimate whole-number JSON floats still normalize after validation, and existing fractional-only tolerance remains. Complete boss shape/value/death validation now precedes every dependent hazard access; pre-spawn checks remain after tick validation. Definitions, gameplay, UI and save schema did not change. Static review finds both fixes correctly targeted, with no new blocker.

I read `AMENDMENT-VALIDATION.md/json` and `tests/validation_tests.gd`: all875 integral leaves are individually perturbed, direct and correctly checksummed decode rejection are checked, whole-float controls step through24 ticks/firing, and ten malformed boss forms exercise the cancelled-hazard path. Synthetic late/profile fixtures are explicitly labelled. Old-source sensitivity must fail on engine errors even if rejection booleans pass; the documented strict runner does so. Builder reports3,548 focused checks plus226 rules/115 journey/11 genuine migration checks and unchanged24 outcome records. **Independent new-pin reruns were pending when this report was written**; no reviewer execution claim. Close the two P2s upon the root's exact amended-source reproducer and regression confirmation. Original media stays bound to0a, not repinned.

## Bounded disposition

Visual/source direction clears continued software-candidate work, conditional on the two P2 fix confirmations and remaining platform gates. Parked legacy and campaign contexts, whole settings, durable-before-live import, exhaustion-before-reward, stable ledgers and delayed clipboard confirmation were reviewed in source; no additional concrete P1/P2 was found. This is not full Android update/clipboard/IME acceptance, physical-phone folding/touch/FPS/sound verification, or human pacing/fun acceptance. No requirement or uncertainty is waived by the clip completion or test counts.


---

# Additive P2 closure: Dead Run f9609eb

This note supplements, and does not rewrite, `astra-playback-and-review.md/json`. Reviewed fix: worker `f9609eb8cf03b99a814ae09e6334b5762fbbeea4`, root integration `0e246ba37d067356a13b440efae1f5f04a057690`.

**Both P2 findings are closed. No remaining P1/P2 was identified within the completed source, visual and focused-amendment review scope.** The near-integral firing-period import now rejects before modulo arithmetic; malformed boss data now rejects before the dependent cancelled-hazard dereference. The previously inspected two-function diff and meaningful old-source sensitivities are now supported by root's completed independent executions.

## Independently checked evidence

I read the completed assessment, source-binding record, four-suite summary and behavior comparisons, and recomputed these exact SHA256 values:

- `.artifacts/verification/dead-run-campaign-adversarial-f9609eb-20261018T083345620622Z/assessment.json`: `c7ff64dc2919931f28d5332dd36f01b56c2ff904df51fffafbb3b085dc9bf0db`.
- Adjacent `integration-bindings.json`: `b635f3101b84d7e7d975446c581cbe77c6fb019b93e6fbdac6ed9b11c442fc35` (83 tracked files bound by LF content; root/worker raw fingerprints are intentionally distinct).
- `.artifacts/dead-run-campaign-f9609eb-independent/index.json`: `c845c430ed91998f18a48340676dc6da1462f052502bc7e63ff7434e205c6577`.

All **817 indexed evidence files** matched their declared hashes on this read. I also separately hashed the old/new reproducer and all six old/new correctly checksummed input files: every pair matched, and every new input matched its assessment hash. Both reproducer copies hash to `f7f2b7bb3b1b76b8c8bf462d37c74b65b9a813d3a74a8b906660cf9863db89c8`.

The same six-case reproducer now reports all six complete/exit0 with no script errors, warnings or stderr, compared with five retained original script errors. Canonical period/boss controls remain accepted; near/outside periods and null/array boss cases reject cleanly. The boss fixtures remain explicitly synthetic late structural states, not naturally earned runs.

The separate independent headless suites passed **3,548 focused validation, 226 campaign rules, 115 whole-journey input and 11 genuine revision384 migration checks**, with no unexpected errors. The record reports unchanged root raw fingerprint `829fdd47ee4c78e0959620af3cab6cd9dfb85597fd674bfd480bc62152a46b64` before/after all runs. All24 journey outcome records and driven ticks match the old independent baseline; the journey report hashes themselves match. The entire genuine384 legacy body and settings match exactly, with the new campaign profile empty; migration report hashes also match. This is root execution evidence inspected by Astra, not tests executed by Astra.

## Disposition and limits

The validation defects no longer block progression toward a software candidate and the pending Android gates. Original three-clip footage remains bound to `0aebe4c`, without repinning: gameplay, definitions, UI and schema were unchanged by the validator-only fix. Original failed probes and the earlier pending review remain intact.

All previous P3/readability, sparse post-boss/cap-heavy pacing and human-fun concerns remain. Native campaign update, clipboard/IME/lifecycle, physical folding/touch, audible sound and phone FPS are not accepted by these headless results. No Android, browser, GPU, clipboard, engine/test execution or tracked-source action was performed during this closure review; only read/hash checks and this ignored additive note.
