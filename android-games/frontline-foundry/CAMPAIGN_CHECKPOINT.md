# Campaign review checkpoint — 0.2.0 / code 2

Assigned worktree `C:/projects/active/_worktrees/games-frontline-foundry-20261018`,
branch `codex/frontline-foundry`, base `bd2bfd9d1758aa8cc7b3f6235884502ae3070a83`.
Only the game directory changed. No coordinator-history rebase, other-game edits,
agents/goals/chats, ADB/APK work, SDK/global editor changes, push or publication.

Implemented twelve districts, four distinct recruit roles, three competing
supports, six ordinary enemy roles, three behavioral bosses, conclusive foundry
liberation and deterministic seeded skirmishes. Direct commander travel/fire,
local earned scrap and finite equipment → individual arming → gate deployment →
independent battle effects remain the central activity throughout. Capture,
salvage, artillery hunting, replacement demand and specialist counters vary the
decisions. A good opening followed by safe passive camping loses the tested
middle encounter; this is a bounded policy control, not universal strategy proof.

Successful initial arcs take 2220.617 seconds headless and 2220.167 seconds rendered,
about 37 simulated minutes. The synthetic control takes 2220.5 seconds. Full
desktop routes use 8× engine time; these are not human duration or phone FPS.

Builder checks pass:

- **219 rules/save/fault:** finite definitions/seed determinism; role targeting,
  cover/armor, equipment/cap/queue ownership, gate paths, reward/partition/economy
  conservation, exhausted terminals, dead-only repair rejection, simultaneous
  last-kill/fatal-strike precedence, unsupported/malformed imports, interrupted
  slots/staging and legacy schema preservation.
- **229 headless / 232 rendered engine input:** all twelve wins and ending,
  two differently funded viable late orders, rifle-only loss, actual Retry/refit
  correction, seeded replay, settings, invalid Import and paused resize retention.
- **16 cold/transfer:** separate process restores the complete active career,
  actual Resume, touch focus/edit/Undo, invalid-import retention, labelled storage
  fault, whole valid Import, durable progress and Back ordering.
- **9 legacy:** an unmodified genuinely app-written desktop prototype battle
  retains every old field, resumes original rules, then explicitly enters a zero-
  clear campaign while retaining the whole legacy run/profile/settings.
- **8 Windows source / 6 fresh destination:** reserved interactive direct Export/
  readback, touched edit/rejection, exact Paste, whole-career durable fresh Import
  and continuation. Fresh Import is transfer validation, not earned completion.

Three separately continuous 1× original-game clips show early, middle and finale
play. Early begins fresh; middle/finale use explicitly identified, genuinely
input-earned app-written boundaries. They are not one uninterrupted campaign.
The JSON index gives actual paths, raw/LF executed sources, receipts, raw inputs,
app states, combat events, PNGs and movie hashes. Every sortie has unique capture
names. Original AVIs remain beside normal-speed MP4 encodings. Index/prose files
are excluded from recursive runtime binding; every bound artifact is rehashed
and every PNG decoded before the commit freeze.

Final 450×800 clips (video plus original audio), each fully decoded:

| Clip | Seconds | Local artifact directory |
| --- | ---: | --- |
| Fresh district one | 122.65 | `.artifacts/paced-early-movie-20261018T065825430591Z` |
| Earned mission-eight boundary → victory | 76.267 | `.artifacts/paced-middle-movie-20261018T070047405591Z` |
| Earned finale boundary → liberation/journal | 70.833 | `.artifacts/paced-final-movie-20261018T070239806956Z` |

Each directory contains `continuous.avi`, `continuous.mp4`, `movie-probe.json`,
raw inputs, app saves and its original source-bound receipt. These movie routes
pass 14, 5 and 6 checks respectively. The middle/final resume paths point to
`paced-input-20261018T064540684088Z/earned-middle` and `/earned-final`.

Retained exploratory/failure packets include numeric-arrival over-rejection,
earlier observer filename reuse, the failing pre-fix lethal-cover regression,
focus-dependent Undo, a temporary clipboard-history read lock and a superseded
rendered run closed normally after the combat fix. They are not passing final
evidence. The lethal-cover regression fails once on old code then passes after
applying cover before the remaining-health clamp; positive finite fractional
enemy HP now remains saveable.

The final clipboard packets execute the same corrected combat, save/transfer,
definitions and input sources as the final campaign routes. Earlier normal-speed
clips exposed empty inter-wave stretches. The final schedule spreads the same
enemies across each wave, reducing the longest arrival gap without changing
enemy counts, stats, budgets or objectives. The 37-minute arc and final clips use
this revised schedule; earlier pacing captures remain retained as superseded.
Post-execution packaging/export-filter metadata is explicitly labelled rather
than causing gameplay suites to restart.

Catalog1/seed17 rule source is unchanged. Schema1 state/profile/settings stay
whole in explicit legacy mode; prototype wins do not become campaign clears.
Schema2 adds a separate career and complete catalog2 definitions, including
stable IDs, schedules, costs/stats, queue/formation/gate layout, support effects
and bounded generator options. Checked slots protect stable progress; imported
staging cannot become progress before validation and promotion. Fatal strikes
precede success/pickups/repair, and dead entities cannot be revived.

Incoming bolts/recipient pulses, ground warnings, central gate waypoints, distinct
roles and fewer central labels address the prototype follow-ups. Pause, modals,
48dp controls, touch focus, duplicate-mouse filtering, honest transfer feedback,
Back-to-quit disable and state-preserving resize remain in place.

Root's genuine Android code1/rev213 fixture and native installation/update remain
separate coordinator evidence. This code2 candidate still needs independent/
Astra/native acceptance. Physical Fold7 cover/inner touch/folding/safe areas, IME,
audible sound, measured FPS and human pacing/fun are unverified. The Top General
creative mapping remains qualified. Stop at the clean commit for root review.
