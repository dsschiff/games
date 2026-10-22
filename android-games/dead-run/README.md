> Graphics work: see [GRAPHICS_PRODUCTION.md](GRAPHICS_PRODUCTION.md). Graphics candidate frozen as 0.3.0/code4 (original stylized 3D presentation). Status 2026-10-21: signed APK built, rules 139/input 34/presentation 22 pass, genuine emulator code3-to-4 update keeps the whole save, drag steering confirmed on the emulator, and Android lighting matches desktop frames. Evidence: `android-games/evidence/dead-run-graphics-candidate.json`. Functional 0.2.1/code3 records below remain retained.

# Dead Run — evacuation campaign (0.2.1/code3)

An original offline portrait road shooter for pinned Godot4.7.2/GDScript. Restore
24 roads through Canal Works, Market Viaduct, Reservoir Ring and Ferry Approach,
then evacuate on the last ferry. The authored roads total2260 active simulation
seconds (37.67minutes); this is not a measured human session or a fun claim.
Root independent review, Android update and physical-phone checks remain separate.

## Play

Drag one finger sideways; the crew moves proportionally and fires forward
continuously. Desktop mouse drag also works. The gold footprint matches all
colliding crew, including newly joined recruits. Growing crowds become wider.
Shots improve signed gate numbers; overlapping a gate applies its displayed
result once. Avoid negative gates or improve them before crossing. Carts and
orange attack marks must clear the whole footprint. Marks become red at impact.
Infected contact costs their listed pressure plus one crew; a rescue-line leak
costs their pressure. Loss recaps explain the last actual depletion cause.

Roadside rigging cranes award3 recruits. Flood pumps also cancel later linked
pulses. Shooting them leaves forward infected less suppressed. They appear during
ordinary road action, rather than only as final bosses. Gates, carts, shields,
runner pairs, split crowds, spit marks and pumps create different priorities.
Finish the objective before its deadline and hold the line until the convoy passes.

Three baseline tools are sidegrades, available without grinding:

- Rivet: focused, frequent fire and quick gate conversion.
- Lance: slower volleys bypass armor and pierce up to3 infected. Gates still gain
  one point per projectile, not two damage points.
- Fan: twin spreading pellets sweep wider crowds but concentrate less at range.

Six roles have consistent silhouettes and behavior: drifter, runner, plated,
spitter, cluster and bulwark. District finales use the moving/sweeping Cable
Matron, flank-shielded Toll Ram, shifting Spore Bell/marked volleys, and Ferry
Eater's two arms/exposed core. The final clear earns an evacuation ending.

The map shows unlocked roads, loadout descriptions and earned results. Immediate
Retry keeps the same definition, seed and weapon. Changing a genuinely active road
requires explicit abandon confirmation. Replaying clears improves rescue/no-loss
medals and best crew; it cannot duplicate progression. After all24 clears, enter
an integer seed to replay a generated ferry approach. Generator1 varies wave
lanes/roles/timing and gate/cart/flood lanes, with pinned readable bounds.

Pause contains sound/reduced-effects settings and portable transfer. Back closes
transfer before toggling pause; native autoquit is disabled. Export requests a copy
and confirms it asynchronously for a bounded period. A timeout says unconfirmed,
not definitively unavailable. New exports, editing, Paste, Import and closing the
form cancel stale confirmation. Paste fills the field; Import validates and
promotes to checked storage before replacing the entire live journey/parked bridge.
Save failures stay visible. No ads, purchases, accounts, servers, energy or idle
construction timers.

## Legacy preservation and saves

The exact legacy canal-bridge-v1/seed61723 rules and definitions remain in
scripts/rules.gd. A checked version1 save becomes a schema2 context with the
entire legacy body/settings intact and an empty campaign profile. Old victories
do not create campaign clears, medals, weapons or an ending. The saved active
legacy run opens paused in its own view. Returning to the map parks it; starting
campaign roads does not rewrite its body. Legacy-view transfer also carries the
whole schema2 journey, so it cannot silently discard campaign progress.

New runs carry full catalog1/rule2/generator1 definition snapshots and selected
options. Future catalogs must preserve these definitions rather than mutate them.
Projectiles own unique IDs, recruited-member owners and piercing hit sets; actors,
recruit/loss ledgers, chronological event prefixes, gates, claims and hazard sources
are validated. Every moving position derives from its pinned spawn/tick definition.
Exhaustion is terminal before later rewards, queued shots or completion; a zero
formation cannot revive. A too-late shot does not override an objective deadline.

Both versions use checked alternating slots at user://dead-run-save-0/1. Eligible
ordinary-write temps can recover interrupted saves; unpromoted imported temps
cannot displace the prior save. Reads retain the highest eligible revision.
Cold active restoration starts paused. Schema2 import writes, reads back and
promotes the candidate before changing live memory. Runtime files stay ignored.

## Source boundary

Selected source: Last Human: Final Stand, com.avenue.zombie.gp; Last Z is only a
comparison. Read ../references/last-human.md for qualified observations from L2:
https://www.youtube.com/shorts/xhW1r3ZVJ2Q. Visible recruitment, harmful crossings,
ordinary-road side-target competition and defeat/Retry were observed. Exact
commercial shot/gate/recruit equations and executed drag causality remain open.

Our arithmetic, caps, enemies, weapons, bosses, stages, civilian rescue theme,
meshes, icon and synthesized tone are original. Gate shots add1 (first gate max+5,
others max+6), crossing applies the signed value once, initial crew5/cap20, side
reward3. Full rules/definitions are pinned in campaign_data.gd and campaign_rules.gd.
This does not certify unreadable commercial numerals or copy commercial artwork.
The original87.233s prototype movie and its old-source receipts remain historical.

## Reproduce builder evidence

From the assigned worktree with the existing pinned toolchain:

```powershell
python android-games/dead-run/tests/run_desktop.py campaign-rules
python android-games/dead-run/tests/run_desktop.py campaign-headless
python android-games/dead-run/tests/run_desktop.py migration-headless
python android-games/dead-run/tests/run_desktop.py clipboard-headless
python android-games/dead-run/tests/run_desktop.py platform-headless
python android-games/dead-run/tests/run_desktop.py rules
python android-games/dead-run/tests/run_desktop.py exhaustion-headless
```

Use campaign-visual for a bounded rendered opening; migration-rendered for the
actual native-fixture desktop migration. Coordinate exclusive foreground/Windows
clipboard time BEFORE clipboard-rendered, clipboard-locked or legacy rendered
suites. clipboard-locked temporarily opens the real Windows clipboard without
reading/emptying it; it releases on an explicit request or a15second cap/finally.
Only exact expected clipboard API denial errors qualify that dedicated failure
case; all other errors fail. This is separate from strict error-free normal runs.

All invocations isolate APPDATA/LOCALAPPDATA, retain commands/logs/raw engine
input/app-written slots and freeze raw/LF source bytes/hashes. PNGs fully decode.
Campaign input uses read-only policies and real GUI/touch/drag events through the
whole arc, alternatives, ending and replay. Boundary imports/code-box text and
storage adapters are explicitly labelled fixtures, not earned progress. Migration
uses a byte-bound copy of root's genuinely earned native code1 active fixture;
this is a desktop migration test, not Android install-over evidence.

platform-headless dispatches labelled synthetic engine notifications through the
real script inheritance chain. It catches duplicate native Back dispatch, transfer
close/resume, map closure and parked-legacy guards; it is not actual Android input.
The campaign relies on the inherited notification handler rather than calling it
again with super. The optional full campaign-rendered mode has a90-minute watchdog
because its normal-speed route/alternatives can exceed the earlier20-minute limit.

Continuous campaign-movie-early/middle/final segments use --earned-checkpoint for
middle/final ready saves produced by the full input journey. They are explicit
separate earned-load boundaries, not one uninterrupted campaign recording or
human-duration evidence. Original movies are not relabelled as new-source footage.

late-priority-headless accepts an explicit app-written earned ending checkpoint.
It holds Twin Piers and Rivet constant and verifies opposite successful roadside
orders: left riggers before right pump, then right pump before left riggers. This
supplements the full journey's earlier timing-only rescue/line comparison. Copy
slot files as bytes; text-mode newline conversion can invalidate their checksums.
CAMPAIGN-CHECKPOINT.md/json bind the final evidence and document test-only files
added after movie capture. The production runtime matches all final captures.

## Delivery boundary

Credential-free standard Android preset: com.dsschiff.deadrun,0.2.1/code3,
arm64-v8a+x86_64, no permissions, no SDK override keys. Official template supplies
min24/target36; root verifies the actual APK. Historical code1 SDK-override failures
are recorded in DELIVERY-METADATA.md/delivery-metadata.json. Code2 introduced the
campaign; code3 corrects wide-display camera framing. Native and cover portrait
projections stay unchanged; wider screens retain native vertical coverage while
revealing more ambient scenery at the sides. Camera FOV derives from explicit
authored values on creation and resize. CAMERA-CHECKPOINT.md/json bind the pure
headless projection evidence; root owns the new APK geometry/update checks.
Stable UID/icon metadata uses only a private copied portable editor with isolated
app data and shutdown_adb_on_exit=false. No global toolchain changes.

No builder ADB/APK export/install, shared records, pushes, new chats/goals or agents.
Freeze the scoped campaign checkpoint for independent root/Astra/native update
checks. Physical Fold7 touch/IME/folding/safe areas, audible sound, heavy-crowd FPS
and human pacing/fun remain unverified; no automated result substitutes for them.
