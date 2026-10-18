# Tower Trials software candidate 0.2.0 / code2

Thirty-six authored puzzles, four chapters/finales, six integrated core-rule tutorials, local progression and a final ending. First-loop expansion was approved by Astra after direct playback of the complete prototype clip. **Full-candidate independent review and Android acceptance are still pending.**

The H1 identity remains room choice → short courier clash → deterministic power transfer → visibly growing/claimed watch. Introductory addition is source-supported; strict-greater/equality-loses, ordered rooms and all resource/route rules are our original design choices. No party RPG or pin puzzle.

## Verified content and behavior

- 36/36 authored puzzles have BFS solution witnesses; every one of 14 offered treasure medals has a successful route. Shortest routes total 177 moves, range3–8. Solver state includes power, keys, shields, claims, collapsed routes, rescued keepers, treasure and terminal status; ordered enemies resolve sequentially. No uniqueness claim.
- A smallest-enemy-total-first policy fails on18/36. The serialized room/resource signatures all differ when enemy strengths are removed; this is a bounded authoring comparison, not a graph-isomorphism or balance proof. Exact routes and state witnesses are in the rule report.
- Actual touch-input journey earns all36 clears, all chapter transitions and the ending; nine distinct mistakes reach natural defeat, followed by Undo/Retry correction. Later cold restore retains the complete profile and route. A separate input replay earns an optional treasure medal.
- Claimed/collapsed rooms have no active Enter affordance. Full forecast details expose every ordered combat/resource step, including multi-key/shield grants. Rescued/claimed rooms remain visibly claimed when their old approach is later sealed.
- Version2 validates against the selected saved catalog before indexing it. Catalog1 and its rules are immutable; a genuine touch-created code1 fixture retains exact state, then continues, undoes, retries and transitions to catalog2 through input. Committed-import backup recovery is fixed while failed uncommitted imports remain excluded.
- Four chapter tabs and touch scrolling accommodate nine80-high entries per chapter. All custom buttons have80-logical-pixel minimum hit dimensions (48dp at360dp cover width). Four-floor rooms retain large numbers; nine-floor home growth stays below the HUD. Desktop unfolded resize retains state.

## Evidence

Paths below are relative to this game; all captures/runtime data are ignored. `evidence/campaign.json` binds source bytes (raw and LF-normalized), commands, reports and artifacts.

| Evidence | Path |
| --- | --- |
|398 rule/save checks;36 solution witnesses | `.artifacts/campaign/rules/result.json` |
|994 headless campaign checks;471 touch taps | `.artifacts/campaign/headless/result.json` |
| 1020 rendered campaign checks;471 touch taps | `.artifacts/campaign/rendered/result.json` |
| Actual natural defeat/victory, complete forecast, earned map, ending and unfolded PNG/JSON pairs | `.artifacts/campaign/rendered/` |
|17 headless /20 rendered layout/boundary checks | `.artifacts/campaign/layout-{headless,rendered}/result.json` |
|19 headless /21 rendered legacy-input checks | `.artifacts/campaign/legacy-{headless,rendered}/result.json` |
|26.133-second first/middle/final movie;40 checks | `.artifacts/campaign/motion/tower-campaign.mp4` |
| Movie input report, commands, original AVI and app-written checkpoint provenance | `.artifacts/campaign/motion/`, `.artifacts/campaign/checkpoints/` |
| Content denominators, greedy outcomes and duration qualification | `.artifacts/campaign/content-analysis.json` |
| Final commands/import/rules/input/render logs | `.artifacts/campaign/*.log` |

Movie scenes restore unchanged saves written by the complete actual-input journey, then use touch events and natural game updates. No gameplay fields are injected to manufacture first/middle/final progress. Capture runs at a fixed60-fps simulation clock with Dummy audio; it does **not** measure phone FPS or human solving time. The original prototype's92 indexed artifact hashes remain intact in `.artifacts/prototype/`.

## Remaining acceptance

The30–60-minute journey is an authoring/playtest target. Automated shortest-route playback does not establish human engagement, solving duration, difficulty balance or fun. Human representative/all-journey playtesting remains needed. Replay uses authored medals/branches; no random challenge generator is implemented. Coordinator will assess the requested seeded solver-verified replay after this bounded freeze; that item is not silently treated as accepted.

Coordinator: independently review the first/middle/final motion and full content/save candidate, then export the frozen0.2.0/code2 source and exercise the real code1→2 Android install-over-existing route. Android launch, input, background/Back, keyboard/clipboard, save interruption/recovery and update checks remain coordinator-owned. Physical Fold7 cover/unfolded safe areas/folding, audible output and measured device performance remain unverified. No APK/device or portfolio-completion claim here.
