> **Design candidate 0.3.2 / code6 (2026-10-23).** Individual recruit feedback follows
> Equip, arming, gate deployment and actual combat contribution; HQ integrity and
> role guidance stay readable above resting controls. Completed-save destination
> bytes are verified before success. Rules, pinned runs and earned progress are
> unchanged. See `REINFORCEMENT_CHECKPOINT.md`; signed/native delivery is tracked
> separately in the portfolio records.

# Frontline Foundry — 0.3.1 / code 4 candidate

The unreleased [reinforcement feedback increment](REINFORCEMENT_CHECKPOINT.md)
(2026-10-23) follows each paid weapon into its individual crew and reports actual
crew contribution, adds counter guidance and an HQ marker above touch controls,
and verifies save destination bytes after rename. Rules and pinned saves remain
unchanged; current CPU/input and focused renderer evidence are in that checkpoint.

The bounded [pooling follow-up](POOLING_FOLLOWUP.md) adds scene-owned inactive
actor/effect reuse to the accepted 0.3.0 graphics. Art, rules and saves are retained.
Status 2026-10-21: signed 0.3.1/code4 built from d7eb746 (pooling plus art-direction pass),
rules 69 and input 40 checks pass, and a genuine emulator code3-to-4 install-over keeps the
whole career/battle/settings. Evidence: `android-games/evidence/frontline-graphics-candidate.json`.
Physical-phone testing remains deferred.

The accepted rigged stylized 3D benchmark is expanded across the campaign,
legacy battle and seeded skirmishes. See [GRAPHICS_PRODUCTION.md](GRAPHICS_PRODUCTION.md)
for the original regional/specialist models, final source-bound captures, desktop
frame timing and remaining independent/native/phone gates. Historical bounded
benchmark evidence remains in [GRAPHICS_BENCHMARK.md](GRAPHICS_BENCHMARK.md).
This builder has not exported or installed a 0.3.0 APK.

An original offline portrait 3D commander/base defense game. Twelve districts,
four recruit roles, three support choices, six ordinary enemy roles, three bosses,
a liberation ending and deterministic seeded skirmishes are implemented.
Builder verification is in `CAMPAIGN_CHECKPOINT.*`; coordinator/Astra/native
acceptance and physical-phone play remain open. The full desktop journeys take
about 37 simulated minutes, not a measurement of human pacing, fun or phone FPS.

Move the gold commander with the floating left stick. Your weapon fires at
nearby living targets while you move. Collect gold scrap in the attached field,
return to a priced equipment station and explicitly tap Equip. Each purchase
creates one finite weapon token for one waiting recruit. That individual arms,
walks through the central gate, attacks, takes damage and can die. Crossing pads
never spends. Three crew members per role and a four-slot later front make
replacement and collection consequential; the first two teaching missions allow
six slots. Death frees a slot without refunding its consumed weapon.

| Recruit | Scrap | Distinct use |
| --- | ---: | --- |
| Rifle | 7 | Cheap rapid fire, weak against armor |
| Breaker | 10 | Pierces armor/nearby Bulwark cover; prioritizes armor |
| Ranger | 10 | Long range; prioritizes mortars, jammers and the Storm Engine |
| Rover | 18 | A supplied cannon on an individual chassis; splash counters clusters |

The first district teaches rifles/rovers, the second adds Breakers, the third
adds Rangers. Choose one support in Sortie Kit, then explicitly build it at the
center pad for 14 scrap. Ward reduces incoming commander/recruit/HQ damage by
35%. Relay increases firing range, commander damage and capture speed. Recovery
spends a finite 200-point budget repairing living allies; it cannot revive a
fatal casualty. Selection is free; one building per attempt; Retry permits refit.

| District | Objective and pressure |
| --- | --- |
| Ash Gate | Personal fire, scrap, rifles and rover supply |
| Switchyard | Three exposed caches and armored bulwarks |
| Signal Ridge | Two relays and long-range mortar crews |
| The Iron Drill | Exposed wind-up followed by a charging siege engine |
| Broken Bridge | Side relays, bypassing runners and sappers |
| Glass Quarry | Kill every mortar crew under jamming pressure |
| Night Relays | Capture exposed relays against the full enemy mix |
| The Brood Carrier | Boss repairs living escorts from a finite tank |
| Red Causeway | Stop at least 90% of the rush; protect HQ from sappers |
| Mortar Gardens | Hunt artillery across adjacent approaches |
| Last Supply | Three caches, collection risk and specialist investment order |
| Foundry Liberation | Both relays and the Storm Engine; avoid marked ground strikes |

Drones fight defenders, runners bypass them, Bulwarks cover escorts, mortar crews
bombard HQ/troops, sappers detonate, and jammers suppress nearby recruits. Red
incoming bolts, recipient pulses, repair beams and ground warnings explain effects.
Reduced Effects removes hit pulses while retaining essential warning information.

Waves provide live collection/reinvestment windows. No ads, purchases, accounts,
servers, energy, offline production, compulsory income grind or real-world
training waits exist. Each sortie starts with its own finite budget. Victory
requires the objective/minimum stops and surviving commander/HQ; bosses and
required mortar crews must be killed. Fatal strikes precede victory, healing and
pickups. Retry restocks immediately and opens the brief for refit/Launch, retaining
the whole career/settings. Completing all twelve districts displays liberation.
Free replay records medals; Mixed/Flank/Siege skirmishes use selectable seeds,
complete pinned definitions and separate records. Same seed/style reproduces the
encounter. Skirmish Retry cannot invent campaign clears.

Schema 2 stores the whole active run, stable definitions/seed/options, entity
identities/cooldowns, equipment/reward ledgers, career, legacy profile and settings.
Checksummed alternating slots retain the newest good state. Committed temporary
autosaves can recover; uncommitted imported staging cannot become progress.
Storage failure is visible; cold active restoration starts paused.

Pause → Save / Transfer → Export directly copies a fresh whole-progress code.
Readback follows a short clipboard-history settling interval; unconfirmed or
unavailable copy is reported honestly. Paste restores text; Import validates and
durably commits before replacing memory. Invalid text/storage failure retains
the entire current run/career/settings. TextEdit gets actual touch focus via
mouse emulation; emulated mouse copies are filtered from world movement. Native
Back-to-quit/automatic quit are disabled. Back closes modals before toggling pause.
Buttons are at least 96 logical pixels high at 720px, corresponding to 48dp at
360dp width. Phone IME/touch/folding remain required physical checks.

Installed schema-1 catalog-1/seed-17 battles retain exact original rules and whole
state/profile/settings in explicit legacy mode. Launch pauses that same battle.
Prototype wins never invent campaign clears. Begin Campaign retains the legacy
run/profile as a backup and starts district one. Root's native rev213 update
fixture is separate from the builder's genuine desktop legacy packet.

Use pinned Godot 4.7.2 from repository `toolchain.json`, from the assigned worktree:

```powershell
python android-games/frontline-foundry/tests/run_campaign.py rules --label review
python android-games/frontline-foundry/tests/run_campaign.py input --label review
python android-games/frontline-foundry/tests/run_campaign.py rendered --label review
python android-games/frontline-foundry/tests/run_campaign.py cold --label review --resume-from android-games/frontline-foundry/.artifacts/<completed-input-run>
python android-games/frontline-foundry/tests/run_campaign.py movie --label early --clip early
python android-games/frontline-foundry/tests/run_campaign.py movie --label middle --clip middle --resume-from android-games/frontline-foundry/.artifacts/<completed-input-run>/earned-middle
python android-games/frontline-foundry/tests/run_campaign.py movie --label final --clip final --resume-from android-games/frontline-foundry/.artifacts/<completed-input-run>/earned-final
```

The runner isolates APPDATA/LOCALAPPDATA and freezes exact executed raw/LF source,
commands, logs, raw engine inputs, app-written states, combat events and PNGs.
Full journeys use labelled 8× engine time; movies use 1×. Read-only state policies
drive ScreenTouch/GUI/key events without injected progress, gameplay-handler calls
or forced terminal redraws. Synthetic rule/storage controls are separate. Unique
sortie-prefixed captures retain original journey, alternatives, failures and
corrections. Windows clipboard source/fresh-destination checks need an exclusive
reserved interactive window. Fresh Import validates transfer, not earned play.

Android preset: `com.dsschiff.frontlinefoundry`, **0.3.1/code4**, arm64-v8a+x86_64,
official non-Gradle min24/target36 template, no permissions or embedded credentials.
This builder did not export/install APKs, use ADB, alter SDK/global editor settings,
push or publish. UID/icon metadata uses an isolated copied portable editor with
its existing `shutdown_adb_on_exit=false` setting. All art/audio/encounters are
original. The Top General-to-Top Force creative attribution remains qualified.
Controls/prices/armor/production/caps are original choices. Ammo carts, medic
recruits, manual aim/dodge and dragged blueprints were not added.

Independent acceptance, native update/platform tests and physical Fold7 cover/
inner touch, folding, safe areas, IME, audible sound, FPS and human pacing/fun
remain separate gates. Historical `CHECKPOINT.*` describes the first playable;
`CAMPAIGN_CHECKPOINT.*` describes this campaign candidate.


Dormant optional cloud recovery adapter: see [CLOUD_ADAPTER.md](CLOUD_ADAPTER.md).
This source increment has no game UI/native linkage or working cloud-sync claim.
Its default port reports Not configured; existing offline scenes and exports are unchanged.

Local Import pending/retry/verified-rollback behavior is documented in
[IMPORT_RECOVERY_AMENDMENT.md](IMPORT_RECOVERY_AMENDMENT.md). This local-only
recovery change preserves whole contexts across uncertain writes and bootstrap;
it does not enable the dormant cloud adapter. Native/rendered acceptance remains separate.

Optional Play Games UI/typed native-port work is described in
[CLOUD_UI_AMENDMENT.md](CLOUD_UI_AMENDMENT.md). Missing native lifecycle APIs or
per-game configuration stays explicitly unavailable. CPU fake/real-input evidence
is separate from packaged native and genuine account/cross-device acceptance.
