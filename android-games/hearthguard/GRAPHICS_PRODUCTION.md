# Hearthguard graphics production

CPU implementation frozen for the first rendered inspection on branch
`codex/hearthguard-graphics`. Only `android-games/hearthguard/` changes. Version
remains 0.2.0/code2; coordinator owns the eventual reviewed freeze/version bump.
No rendered Godot run, browser playback, Android export, ADB, clipboard, push or
phone test was performed. Gear retains exclusive renderer ownership. This is
CPU readiness, not visual acceptance or a completed graphics candidate.

## Implemented

- Original reproducible Blender4.5.14 CPU generator, provenance/dimension/hash
  manifest and 30 GLBs. Twelve distinct skinned roles have modeled clothes,
  faces, boots, hands, equipment and 18 joints; three dimensional tower families,
  three regional houses and settlement props cover all ten named compositions.
- Articulated stance/swing legs, ankle compensation, smooth turns and stop/start,
  weapon attacks/recoil, local HP reactions, death, refuge contact and victory.
  Citizens patrol/work outside traversable body bounds. Tower crews handle their
  mounted equipment without a duplicate handheld crossbow. Reduced effects
  retains essential coins/prices/health/status and omits optional pulses.
- Campaign and legacy consume deep snapshots and stable actor/coin IDs. Tick
  observations never drive damage, spawning, timing or saved meaning. Pause,
  Retry, import and hydration reset transients. Resume retains its first real
  tick's stamped observations; terminal snapshots stop gait despite the last
  movement delta. These two early Astra findings have focused regression checks.
- Uniform orthographic fitting reserves the HUD/actions. Full transformed model
  bounds clear traversable bodies, and projected opaque scenery clears fixed
  HUD/action/stick rectangles at native1080x2400, cover1080x2520, inner1968x2184,
  intermediate1100x1400, landscape1600x1000 and wide2560x1440. Actual ScreenTouch
  and drag/release preserve exact rule displacement through each viewport's
  inverse input transform. Menus, Journey, transfer, terminal and ending fit.
- Rules, catalog, save store/files, seeded RNG, complete schemas, package,
  signing and offline contract remain unchanged. No shared records/tooling or
  other games were edited.

## Checked evidence

Paths below are relative to this game directory. All successful execution
receipts report source unchanged, zero unexpected errors and passing exits.

| Evidence | Result |
| --- | --- |
| `.artifacts/cpu-final10-checks-20261018T160020025084Z/` | 328 CPU checks, no failures;118 post-import source pins. Import/parse preflight precedes binding; executed source, raw logs, report and receipt retained. |
| `.artifacts/graphics-baseline-campaign-rules-20261018T155336487821Z/` | Existing123 campaign checks pass; scripted full arc1845.883s is simulation time. |
| `.artifacts/graphics-baseline-legacy-rules-20261018T155344633061Z/` | Existing56 legacy rule checks pass. |
| `.artifacts/graphics-kit/stable-indices-reproducibility.json` | All30 GLBs byte-identical across separate Blender CPU processes. Stable triangulation, triangle ordering, normals and deterministic mesh names. |

The final CPU report also compares every complete old/new state and exact event
for1600 policy ticks each on maps1/6/10 and1000 legacy ticks, pins the five
functional files to baseline `c36df6e`, samples actual skinned crossbow vertices
through three aim/recoil poses with same-call BoneAttachment synchronization,
and samples all three towers' visible weapon geometry through aim/recoil.
Fresh legacy bootstrap/routing is a synthetic unit fixture; it is explicitly
separate from genuine earned native update evidence.

Retained failures include `cpu-first`, `cpu-parse2`, `cpu-boundaries4`,
`cpu-input-diagnostic5` and `cpu-projected-clearance7`. A test initially omitted
the native-to-logical transform; corrected real-input checks use the actual
viewport transform. Projected checks found foreground piers/trees/props over the
joystick; corrected authored placements pass. Early export drift and corrected
reproducibility receipts remain in `graphics-kit/`. A separate manual parse
command initially lacked isolated user data and was denied creation of the
normal AppData directory; all later execution uses the isolated runner.

Astra independently closed both early source-boundary findings against the
320-check receipt and all118 matching pins; the coordinator retains
`.artifacts/reviews/hearth-source-boundary-closure-astra.md`. Later328-check
coverage adds actual tower tip aims and fresh legacy routing. No new independent
eight-area visual review has occurred.

## Next action / renderer request

Request one short, source-frozen first inspection after the coordinator explicitly
grants rendering. Prepared entry point (do not run while Gear owns the slot):

```powershell
python -B tests/run_graphics.py inspect --render --movie --seconds 8 --label graphics-first
```

The runner imports headlessly before binding, rejects execution-time drift,
records native unretimed frames and raw input and decodes encoded output. Correct
actual image findings before longer clips. `capture`, `closure`, `tour` and
`legacy` passages are prepared but have only passed CPU parsing. Their rendered
behavior and image quality remain unverified.

Reuse genuinely earned sources in
`.artifacts/campaign-final-headless-20261018T044447829884Z/`: `middle-earned.code`
and `final-earned.code` preserve app-written active map6/map10 checkpoints;
`earned-epilogue-saves.json` retains the actual full campaign. Do not fabricate
unlocks or replay unchanged full campaigns after art edits. Later normal1x
opening/heavy/later passages, focused reset/resize/legacy entries, separate
real-time host timing with raw tails/draw counters, full Astra visual review,
root integration/export and genuine2-to3 emulator update remain outstanding.
Physical-phone testing is deferred and does not block those steps; no phone FPS
or human-fun claim is made.

## Bounded pooling follow-up

CPU-only follow-up adds scene-owned inactive reserves: maximum4 per actor role,
24 actors total,16 per compatible effect kind and64 effects total. Active
combatants/effects are never capped. Corpses and contact actors share the role
pool; projectiles, pulses, coins and coin labels reuse actual nodes. All pose,
gait, bone scale/position, mounted mode, health, socket and effect transforms
reset before reuse. Scene teardown clears reserves and frees retained instances.

`.artifacts/pool-first-pool-checks-20261018T161803413384Z/` passes49 focused
checks with unchanged sources: actual instance/mesh/material reuse, reserve caps,
overflow release, reset equivalence to fresh actors, Retry/load, contact/pause,
Resume/dedupe, terminal gait, complete save retention and teardown.
`.artifacts/pool-preserved-art.json` verifies every original art file unchanged
frome581026. No broad campaign repeat or rendered run was used. Root's first
inspection separately found composition/crest/label/lighting problems and a
450x800 internal movie; those findings are the next scoped correction. Gear
retains the render slot, so a second inspection awaits explicit grant.
