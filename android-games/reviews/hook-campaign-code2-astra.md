# Hook campaign code2 review

2026-10-18 UTC. Reviewer: GPT-6 Astra High. Frozen worker `f0dfbc99720d0ba492461b8c25e6ee71fe24415e`, integrated as `2e96f61`. **Visual direction clears; two P2 save/import defects require correction before software-candidate acceptance.**

Root verified47 raw/LF source bindings,88 declared artifact hashes and all54 tracked files after LF normalization. Root's `99718cd0434936e92f43538eb248c2e41a4ae1ad480790c6d5db85b0b2719af9` differs from worker's `61ea92e15b29755cc7bcc602f4faa8afbda14344da804ff7cc7c373def1bc236` only in recorded checkout line endings. The reviewer inspected frozen source/controllers/captures and directly played each clip start to finish with consecutive checkpoints; it did not execute tests or the commercial app.

| Clip | Duration | SHA256 |
| --- | --- | --- |
| First | 29.467 seconds | `8c54a4083a93c3a64d2681a082a27dd91bbaa99b410c0dc8dbd05c26a9f8f3bc` |
| Middle | 26.333 seconds | `548b7687f207dbf6c239ea369f3a9b1fdc05f987916de80244fa12c156661b57` |
| Final | 28.067 seconds | `21162ad0856d4b59934d7ba70636ddcd7ac5e10b665632f6e6ce49d681305b7e` |

First is the declared unretimed `[3,20] + [37,49.4]` montage; middle is continuous and final is a continuous closing excerpt. Middle/final controllers normally load checkpoint saves earned by the complete actual-input journey, then drive new input. They do not imply uninterrupted recording of the whole campaign. The reviewer also inspected `natural-ending.png`, showing HOMEWARD LIGHTS and the replay action.

The corrected Butcher reference identity survives: angled overhead movement, visible chain contact, collectible salvage, changed weapon/reach, paid power and healing, then stronger encounters. Middle playback shows power300→400 and salvage2146→1906 before shield/flank and projectile combat. Final footage shows line/ring positioning and health pressure. Automatic targeting, salvage fiction and boss patterns remain original choices, not verified commercial rules. Crowded middle-combat labels overlap; readability needs playtesting but is not a demonstrated blocking defect.

## Findings requiring an amendment

1. **P2: Heavy arena refit rejects ordinary post-strike saves.** `campaign_data.gd:18` gives Furnace Refit a0.95-second period, and `campaign_rules.gd:220` assigns that period to cooldown. Validation at`:320` rejects cooldown above0.9. Autosave, background save or export immediately after attacking can therefore fail. Bound cooldown against the selected pinned weapon period, with suitable numeric tolerance. Reproduce old rejection and test immediate heavy-strike validation, encode/decode and durable/lifecycle save.
2. **P2: An accepted empty-current-wave import stalls permanently.** A synthetic `Campaign.fresh(0,1,63)` can move all wave0 IDs from enemies into dead/collected, add their exact rewards to wallet and retain wave0/playing/empty wave_times/strike0 with coherent profile stage0/clears[-1]. Validation at`:360–364` accepts its partition/accounting and wave membership, yet target`:94` finds no actor. Advancement occurs only inside `_strike():137–147`, so the imported encounter has neither opponents nor reachable victory/defeat. Require living current-wave actors for nonterminal combat and coherent all-waves-exhausted victory. Add the exact malformed fixture plus actual GUI Import rejection preserving whole memory, profile/settings and disk. This is an import-validation defect, not an observed ordinary-play stall.

Otherwise static review found coherent retained-death/reward accounting, distinct tactical roles, snapshot-based campaign rules, pinned schema1 execution and alternating recovery slots. Actual-input controllers route movement and GUI actions through input events. Root separately reports passing57legacy/81campaign/8import/9control/174full-journey checks, rendered18opening/10layout/3middle checks, and24 real code1→2 Android upgrade checks. These execution results belong to root evidence, not reviewer execution; they did not expose the two boundary defects above.

Human fun,30–60-minute pacing, physical touch/folding/safe areas, audible sound and phone FPS remain unverified. Owned reviewer tab closed; root stopped server18189 after playback. Findings were assigned to the existing Hook builder in a new evidence namespace; code2 artifacts remain frozen.
