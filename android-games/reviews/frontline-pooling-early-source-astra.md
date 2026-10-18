# Frontline bounded pooling source review

2026-10-18. **CPU/source clear for the planned genuine rendered reuse passage and separate uncapped timing run. No substantive P1/P2 finding in the inspected delta.** This closes the implementation gap of freeing every expired actor/effect instead of retaining bounded reusable nodes. It does not establish final-source visual reuse or performance acceptance.

## Pin and scope

Worker `C:/projects/active/_worktrees/games-frontline-foundry-20261018`, clean HEAD `78cb4bd17b33e60c47749506de5a1f208a48143e` at both reads. Reviewed the commit's actor/outpost changes, complete focused pooling assertions, benchmark/runner additions and accepted CPU index. No engine, render, ADB, browser or test run was launched. No game files were edited.

The commit changes no art/model files, deterministic rule/save code, input/Back handlers or orientation settings. Project/export changes only bump 0.3.0/code3 to 0.3.1/code4. The existing 47-model art set and accepted gameplay rendering remain the baseline; this review is additive.

| Inspected file | Raw SHA-256 |
|---|---|
| scripts/presentation/actor.gd | 6fdd4f67abcdcdcae49ec31070974ec2fac98441b54df47fc5f9dced84ae1673 |
| scripts/presentation/outpost.gd | dcfa4c06133aa91be338112f96b4ebd2ff4663af8b07612319f314b812b58fcb |
| tests/pooling_tests.gd | 98deb0e461ca2ca977408b3b36b765bf54c4029fff97a15752307c0f84e5668f |
| tests/graphics_benchmark.gd | bce765432fd33b3f88b3261e57a7381575348360fa45f2238d1eea70ef75f671 |
| tests/run_graphics.py | 420029ca17d0ac6a928e7f0352dfbed4a6ef9a37f5144395daa865bc51e9d9bb |

## Findings

- **Compatibility keys are appropriate to current authored loadouts.** Actors pool by role and team, retaining the same model/rig and attached primary/role kit. Role determines equipment; team determines body/health palette. Authoritative entity IDs stay outside the compatibility key. A same-ID role/team change retires the old actor and obtains a compatible one. The live units dictionary remains authoritative, so inactive reserve limits do not drop active logical actors.
- **Reuse resets consequential presentation state.** Reset restores root and descendant transforms, visibility, material overrides/overlays, surface overrides, transparency/layers, labels, bone poses and gameplay-facing animation variables: gait/travel, aim, attack/hit/repair timers, death, armed/equip progress, health, warning/jam state and torso yaw. The stored authored rest transforms cover wheels, turrets, barrels and attached kits. Reset forces skeleton transforms and synchronizes BoneAttachments; current same-call socket sampling remains intact. The tests contaminate these properties, compare a complete fresh/reused fingerprint and check aimed/recoiling contact for the exercised roles. Shared materials are restored by reference; current runtime changes do not mutate their intrinsic palette properties.
- **Death/contact ordering remains coherent.** A newly killed enemy moves into an epoch-qualified corpse entry for the existing 0.85-second interval before retirement. Incoming same-step target effects can still find that corpse. Expired corpses return their exact rig to a compatible reserve; acquiring it clears death and hidden status/health state. Removing retired IDs before acquiring new IDs permits genuine same-sync reuse without retaining the old logical identity. Event dedupe remains epoch/attack/recipient based, not node-instance based.
- **Caps distinguish optional effects from essential state.** Inactive actors cap at 24 total and four per role/team; inactive effects at 36 total and 18 per kind. Optional active pulses/tracers retain the existing cap of 36. Essential storm/drill warnings remain outside that optional cap and are reconciled against current state. Tracer and torus types have separate leases; acquisition resets transform, origin, size/radius, material, layers, visibility and kind. Excess inactive nodes are actually freed. Pools remain children of their owner rather than an unbounded off-tree registry.
- **Owner teardown and default caches are corrected.** Packed scenes and palette dictionaries are owner-local. Static helpers use a null default and an explicitly created fresh local dictionary when no owner cache is passed; recursive material processing passes that same local cache. This avoids the earlier implicit shared-default ownership issue. Owner exit clears its dictionaries, and its child reserves die with it. The actual replacement/two-viewport fixture checks weak actor/model/effect/material release and verifies the other live viewport's palette and pose survive unchanged.
- **Reset/load does not change rules or saves.** The existing adapter keeps copied snapshots and resets event epochs; rewinds reset reused living actors, pause clears trails and pending attacks, and real scene replacement discards prior reserves/counters. The focused suite compares state and events on each of 600 actual rule ticks and exercises existing Retry GUI and cold boot with full state/profile/settings/career equality. The terminal used to reach Retry is a declared synthetic fixture, not an earned mission outcome.

## Retained evidence independently verified

`tests/pooling-cpu-accepted-20261018.json` identifies two final-source runs. I independently checked both receipt hashes, every listed artifact hash and every current source pin:

| Run | Actual result | Artifact rows | Current pins |
|---|---|---:|---:|
| pooling-freeze-cpu-pooling-20261018T183003087975Z | 93 checks, 0 failures; receipt passed/source unchanged | 186/186 match | 178/178 match |
| root-final-pooling-regression-checks-20261018T185415123053Z | log confirms 103 checks, 0 failures and SUITE_COMPLETE PASS; receipt passed/source unchanged | 187/187 match | 178/178 match |

The latter retains the existing complete-state campaign comparisons (2,400 ticks each in districts 0 and 11), 900 legacy ticks and presentation/input checks. These are retained successful evidence, not reviewer reruns or newly imposed campaign gates.

The prior genuine 55-second CPU passage with two cross-ID actor/model/rig reuses and 103 effect reuses predates the final default-cache correction. It remains historical and cannot close the final rendered gate. The new runner requires the exact pinned earned source directory, passed/source-unchanged original receipt and original raw slot hashes; no fallback is accepted. The benchmark observes actual cross-ID leases and existing effect counters, checks caps, and saves exact app-written slots after real GUI pause with whole state/profile/settings/career equality. It does not fabricate a victory, change rule state or force a save handler.

## Remaining bounded work

Review the planned continuous 55-second actual reuse movie on this final source, with visible current contacts/defeat/reacquisition and no stale kit, palette or pose; then inspect the separately measured uncapped timing evidence. Counts and synthetic fingerprints alone cannot establish the visible transition. Preserve final capture/source/save bindings and keep the historical pre-fix CPU passage labeled. No full campaign rerun, new broad film set or physical-phone gate is requested. The subsequent exact code3→4 APK/native retention checks remain coordinator work.
