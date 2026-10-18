# Hearthguard campaign review — 6c0b0ef

Reviewed 2026-10-18. **Conditional software-candidate go; no confirmed new P1/P2 in this bounded static and visual review.** The implemented campaign preserves the selected movement → local coins → priced construction → active defense identity. It can advance through the coordinator's independent runtime, signed APK and actual upgrade/native gates. This is not full phone, human pacing or fun acceptance.

## Exact scope and evidence

Worker `6c0b0ef5ae3b273ceca18fa0ccf8f7211fd45699`, initially integrated as `11a3f93`. Reviewed the frozen package `.artifacts/reviews/hearth-campaign-6c0b0ef`, committed game source, campaign checkpoint/README, full handoff, prior prototype review and qualified Kingshot reference. Package SHA256: `3db6c6ba5a303fb135b31ea0f037513c840dd59fb11cc4560e12e119be7d13e2`. Coordinator game fingerprint: `53c3569a91f2d9ee43f3dcdcc780b6806ad5e8e00758a9bfbf720b256bdc5ddd`.

Read the binding report for 43 executed project files, all 45 tracked LF equivalents, 991 receipt-bound files and 181 preserved historical files. These counts are coordinator verification evidence, not an assertion that I separately rehashed every file. I did not run Godot, tests, Android, ADB, builds or exports.

Directly played all three original MP4s from start to end without seeking, taking consecutive settled screenshots and confirming each browser `ended` state at its full duration. This is complete playback with sampled visual observations, not frame-by-frame inspection. One owned browser tab was closed afterward; the coordinator may stop server 18194.

| Clip | Duration | SHA256 |
| --- | --- | --- |
| `final-early-20261018T051417307925Z/continuous.mp4` | 52.25s | `9cffaa4d0bfb5ddf7bd83649d006b0160c12f0ba71c01ef41c6be2fe542d7497` |
| `final-middle-20261018T051513910285Z/continuous.mp4` | 36.25s | `06789a93c11847a2d18e7cee570f54dd163e8a3a4a4fae254536855c234765bc` |
| `final-final-20261018T051555360282Z/continuous.mp4` | 34.7s | `db0a797696ab02acb2320a1f9252cd51e27488d96bd468cfcb69443bd1a86d5a` |

Paths above are relative to package `artifacts/.artifacts/`. Early starts fresh. Middle/final load byte-identical app-written checkpoints from the declared actual-input journey, respectively SHA256 `075b678b9bc069b2edba78e256d7eb2fef037ef76ce0ce445f63a2998d6c4d57` and `a8d5862e34214c1e762ea945951d172724ee6efd8e75fcc3a2dded590ce185cb`. These are separate continuous clips, not an uninterrupted full campaign. Final's additional paid-refit policy is separately bound.

Direct raw PNG inspection included opening natural defeat, map-five wrong-road defeat and paid refit, middle and final segment endings, final Siege refit, earned epilogue, alternate final-layout victory, and tall-cover/inner layouts. The middle/final movies finish with a brief empty shutdown view; their raw segment-ending PNGs show the natural victory UI. I do not infer a gameplay black-screen defect from that recording tail.

## Correctness and persistence

- `scripts/campaign_rules.gd:39–71,312–411` ties purchases, forks and 70% sales to an independently replayed ledger. Wallet, spent and refunded totals reconcile against uniquely owned starting/battle coins. Killed, leaked and living IDs partition the spawned roster; leak damage reconciles with refuge integrity. This is substantive validation, not merely a checksum around arbitrary state.
- `campaign_rules.gd:221–226` validates the complete pinned catalog definition, including family prices/stats, roster, paths and selected seed/budget/mirror/endless options. Retry reuses that definition (`campaign_main.gd:365`); a later catalog revision must retain catalog1 semantics rather than modifying the existing generator in place.
- The reviewed validators and regressions cover tiny positive enemy HP, actual exhausted victory/defeat, floating spawn-boundary tolerance, malformed or missing campaign profiles, duplicate rewards and actor partitions. The ordinary tick removes kills before leak processing and resolves zero integrity before victory (`campaign_rules.gd:132–179`); I found no analogue of Dead Run's zero-crew revival edge here.
- `save_store.gd:12–79`, bootstrap routing and legacy bridge preserve the old rules/state/profile/settings separately from new campaign progression. Schema1 does not fabricate campaign clears. Active and parked legacy terminals require coherent legacy profile meaning; new campaign credited state must agree with its profile. Validated durable import precedes replacing live state, and failed staging is excluded from normal recovery until committed. Archived code1 desktop compatibility is useful evidence, but is not the pending actual Android install-over.
- Context-latched purchases verify the selected pad, family, fork, investment and priority before acting (`campaign_main.gd:336–352`). Journey replacement has Keep/Confirm handling; lifecycle/menu paths stop held movement. No new consequential control or storage flaw was established in the reviewed source/tests.

## Fidelity, presentation and substantive content

The opening clearly shows collected gold funding a Bolt, kills producing nearby drops, and later Mortar/Pierce purchases changing the battlefield. Middle playback shows a moving collector among two roads, additional lower towers/upgrades, visible mortar projectiles and the distinct Matriarch. At approximately 9s/20s/33s, the active state progresses from 87 to 91 to 98 stopped, with funds changing and lower defenses becoming upgraded. The raw result is 101 stopped/zero leaks. Final playback retains eight actual paid defenses and a paid Siege refit, a large Regent and visible projectiles; raw final result is 141 stopped/zero leaks. The separate alternate funded finale wins with five leaks and refuge 3/16, a materially different outcome rather than duplicated screenshots.

These observations preserve K2's selected action-defense identity. K2 remains third-party-attributed creative; its exact debit ledger, controls and authentic input causality remain unproven. Explicit buy buttons, original tower families, prices, role rules and bosses are permissible design choices. Avatar weapons, damage, dash and mounts are not newly imposed requirements.

**Nonblocking visual finding:** improve the Regent's contrast before polish/phone readability acceptance. In the final clip around 17–25s its pale body and small light health bar blend into the white road. Its dark-outlined name still identifies it, so this is not a demonstrated blocking inability to locate the boss. Relevant source: `campaign_main.gd:552,563–581`. A darker silhouette/outline and backed health bar would make remaining HP easier to judge without adding a new mechanic. Prices and terminal buttons are readable in the inspected captures; no clipping blocker was found in the supplied tall/inner layouts.

The campaign exceeds the two-purchase prototype: finite local budgets, three firing families, forks, refunds, target priority, six role rules, three distinct boss behaviors, sequential clears, ending, no-leak records and seeded endless are implemented. Same-definition alternatives are explicitly checked on maps 7/8/10; map9 also has standard-definition routes using different policy variants across rule/journey evidence. Wrong-side construction loses, actual Retry/refit corrects it, and the finale has a separately input-earned alternate layout.

The limit is strategic breadth, not missing numerical content. `campaign_catalog.gd:36–41,90–92` reuses six/eight pad positions and one/two sinusoidal roads; most policy wins follow common family/build orders (`tests/campaign_policy.gd:5–43`). Role mixes, road-switch timing and bosses add real variation, but the evidence does not establish ten equally distinct human decisions or broad policy robustness. Later fully upgraded layouts can accumulate surplus gold and become mostly collection/spectating. Keep that as a specific human pacing question; do not equate 10 clears, 7–16 transactions per map or 30.77 simulated minutes with a compelling 30–60-minute human arc.

## Remaining gates

Preserve both full rendered builder receipts as **FAILED**: each has 78 functional checks, zero assertion failures and engine exit0, but logs `Unable to open clipboard` on immediate Windows Copy/readback. Headless, movie and layout receipts do not erase that host-backend failure. Coordinator independent controlled rendered/clipboard evidence and actual native transfer/lifecycle checks must be reported separately.

Before accepting a software candidate, retain independent exact-source results and the actual code1→2 upgrade preserving the genuine old state/profile/settings with zero invented campaign clears, followed by cold resume, Back/Home, native import rejection/fresh valid import and representative new-campaign controls/outcomes. Physical Fold7 touch/IME/folding/safe areas, audible sound, measured heavy-wave FPS, complete-session pacing and human fun remain open. No extra game system or speculative refactor is required by this review.
