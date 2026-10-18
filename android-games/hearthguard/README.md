# Hearthguard

Original offline angled-overhead3D road defense, Godot **4.7.2**, GDScript.
Version **0.2.0/code2** adds ten maps across Copper March, Lantern Fens and
Glasswind, a conclusive ten-beacon ending, no-leak seals, replay options and
seeded endless watches. Android/native and physical-phone acceptance are separate.

Move the lantern warden with a floating left-thumb stick. Collect nearby gold,
approach a marked pad and explicitly choose a priced construction or upgrade.
Real tower damage and local battle rewards finance further investment while
roads remain under pressure. Crossing a pad never spends. There are no hero
attacks, hero damage, settlement timers, networking, accounts, ads, purchases,
energy gates or required resource farming.

| Family | Build | Forks | Role |
| --- | ---: | --- | --- |
| Bolt | 10 | Pierce30 / Volley32 | Armor penetration / two targets |
| Mortar | 12 | Siege36 / Scatter34 | Piercing burst / wider group blast |
| Beacon | 9 | Prism30 / Winter28 | Chained magic / area slow; magic counters shades |

Families have distinct silhouettes and firing effects. Forks stay fixed for
that construction; Sell refunds70% of the total investment and frees the pad
for a paid refit. Upgraded towers cycle First/Strong/Weak targeting. Full prices,
fork explanations and refunds appear on contextual controls. Range rings,
health bars, heal pulses and silence labels explain combat. Reduced effects
remove pickup bobbing and impact/heal flashes, keeping essential shot/health
feedback. Sound is locally synthesized and switchable.

Raiders, runners, armor, swarms, menders and shades require different coverage,
burst, penetration and slowing. The Ram cycles a shield; the Matriarch heals
its adjacent column; the Ash Regent changes roads and silences nearby towers.
The HUD forecasts the next role/road and the terminal identifies the last leak.
Every watch has a finite reachable startup supply and one-time reward ownership.
Retry resets the selected battle's actors, budget, supply and towers while
retaining earned results/settings. Wallets do not carry across attempts.

Journey unlocks maps by winning, then offers standard/rich/lean budgets,
mirrored roads and selectable seeds. Replacing an active watch requires an
explicit decision; Keep Watch retains it. No-leak records apply under any
selected options. The final watch unlocks the ten-beacon epilogue and seeded
endless; endless records are separate from campaign clears. A loss immediately
retries the same pinned definition without farming or an energy restriction.

## Saves and the shipped prototype

Envelope2 keeps the original prototype profile beside a separate campaign
profile. Envelope1/schema1 saves automatically open Legacy Copper Pass on the
unchanged version1 rules with old actors, drops, wallet, towers, settings and
results intact. Those results invent no campaign clears. Its pause menu can
park the old run and open Expedition; Journey can return to that legacy pass.
Both modes preserve the other mode's parked run.

Campaign schema2 pins full catalog1/generator1/rules2 definitions, map/seed/options,
pads, enemy roster/stats/times, tower prices/fork stats, spawn progress, wounds,
status, owned coins, transaction ledger, cooldowns and target priorities.
Retry uses that exact definition. Keep catalog1/rules2 immutable in future
updates; add versioned paths instead of retuning shipped saves. Imports reject
unknown/malformed definitions, missing profiles and invalid accounting.

Two alternating checked slots preserve the newest valid candidate. Ordinary
staging can recover; unpromoted imported staging cannot become current.
Validation and storage promotion precede live replacement. Invalid imports
and failed writes retain the entire current state/save. Versioned bounded
codes carry SHA256 checksums; they are local backups, not secure achievement
proofs. Touch TextEdit and Copy/Paste are available. Active cold loads start
paused. Android Back-to-quit is disabled; Back closes panels first.

## Verification

From the assigned repository root:

```powershell
python android-games/hearthguard/tests/run_desktop.py rules --label legacy
python android-games/hearthguard/tests/run_desktop.py headless --label legacy
python android-games/hearthguard/tests/run_campaign.py rules --label campaign
python android-games/hearthguard/tests/run_campaign.py headless --label campaign
python android-games/hearthguard/tests/run_campaign.py rendered --label campaign
python android-games/hearthguard/tests/run_campaign.py movie --label early --segment early
```

Runners use unique ignored namespaces, isolated user data, exact source copies
and hashes, raw input, app-written saves and logs. Rules/storage fixtures are
synthetic. Engine routes use ScreenTouch/drag/GUI/key input and normal processing
with read-only steering policies; no earned money/progress injection or forced
terminal redraw. Early/middle/final movies are separate continuous clips;
any load of a genuinely earned checkpoint is declared. Scripted simulation
minutes do not establish human duration or enjoyable pacing.

The initial arc targets30–60minutes. Primary targets are at least96 logical
pixels at720wide (48dp at360dp cover width). Desktop cover/inner resizing does
not establish physical folding/safe areas. Root owns signed APK export, actual
code1-to2 update retention, native lifecycle/Back/clipboard and independent
Astra release review. Fold7 identity/version, IME, touch comfort, audible sound,
measured phone FPS and human fun remain unverified. No Android tools, shared
SDK/editor setting changes or public release are performed by this builder.

## Provenance and checkpoints

K2's selected movement/coins/priced-pads/firing/further-investment activity is
recorded in the repository reference brief. Third-party Kingshot attribution
and exact commercial input/debit rules remain qualified. The warden, all mesh
art, UI, sounds, layouts, prices and rules are original. No commercial footage,
external art, signing material or local saves enter Git.

CHECKPOINT.md/json and DELIVERY-METADATA.md / delivery-metadata.json remain
unchanged historical code1 records. Campaign evidence uses a new namespace
and campaign-checkpoint.json. Neither the prototype nor desktop software
evidence substitutes for the complete campaign or physical-phone acceptance.
