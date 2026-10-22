# Graphics overhaul: approved 2026-10-18

Daniel found the functional builds visually insufficient and supplied a Top Force
screenshot as the quality reference. He chose stylized 3D across all six games,
with a Frontline benchmark and Gear window-fit correction first. He installed
and played Gear on his phone after Android installation/security settings; the
installed version is unknown. This establishes reported installation/play only.
Further phone testing is deferred and must not block graphics development.

## Reference and quality standard

The private user screenshot is preserved under `.references/graphics-overhaul/`
with its SHA256 in `graphics-overhaul.json`. It establishes modeled proportions,
beveled terrain and props, grounded directional shadows, readable team colors,
spatial composition and restrained HUD. Motion quality requires normal-speed
playback, not inference from that still. Existing source briefs still govern
each game's sustained mechanics; the new screenshot raises presentation quality.

Build original authored 3D models, rigs and materials. Primitive capsule soldiers,
static cutout actors and bobbing alone do not satisfy the new character target.
Use appropriate idle, walk/run, attack, recoil, damage, death and victory poses;
smooth turns, foot contact, weapon handling and action transitions. Use coherent
terrain, modular buildings/props, contact shading, controlled effects and audible
interaction cues. Preserve distinct themes rather than reskinning one game six times.

## Architecture and tools

- Keep Godot4.7.2 and Compatibility initially. Root owns portable pinned Blender
  setup and shared production tools. Export original modeled/rigged assets as
  GLB; keep reproducible source and provenance. Built-in image generation may
  provide concept sheets and textures, not substitute for playable 3D scenes.
- Each game owns its presentation adapter, actors, cameras and HUD. Consume
  existing deterministic snapshots/events with stable actor IDs. Interpolate
  visible movement and deduplicate transient effects; reset correctly on load,
  Retry, scene rebuild and pause. Presentation cannot change simulation timing,
  damage, collision, spawning, progression or saved-state meaning.
- Keep 2D controls/HUD readable over the 3D world. Reduced effects removes
  optional flashes/shake/particles but preserves essential telegraphs and cues.
- Preserve package identities, signing keys, versioned saves, exports/imports,
  Back/modal behavior, progression/replay and no-network/offline operation.
  Every new delivered APK has a higher version code. No paid services/assets,
  ads, accounts, purchases, timers or public website/store release.

## Reuse for 2D-board ports

Tower Trials put a 3D world behind an unchanged 2D board and its hit boxes.
Before porting another 2D-board game, read the alignment paragraph in
[tower-trials/GRAPHICS_PRODUCTION.md](tower-trials/GRAPHICS_PRODUCTION.md)
(room fronts on the plane facing a perpendicular camera) and copy the guards in
[tower-trials/tests/graphics_view.gd](tower-trials/tests/graphics_view.gd):
the "room fronts align with 2D labels" check, the "3D presentation is attached"
check that fails when the 3D view is missing, and the rendered frame sample of
lit chamber interiors.

## Sequence and ownership

1. Preserve six functional baselines and exact handoffs, then archive the six old
   app chats through the native archive control. Keep their worktrees, private
   artifacts and this coordinator. Do not delete caches or other sessions' jobs.
2. Start fresh Frontline and Gear graphics chats in the existing saved `active`
   project, explicitly confined to their assigned games worktrees. At most two
   game builders and one Astra reviewer. Root owns integration/shared records,
   signing/export, emulator/clipboard and scheduling GPU work.
3. Frontline produces a real playable outpost benchmark: movement, collection,
   equipment purchase, individually armed recruitment, deployment and combat.
   Review actual 1x footage against the screenshot before expanding production.
4. Gear first fixes its fixed600x1066 `keep` canvas. Use adaptive viewport/layout
   and correct transformed input, not distorted art or a simple background fill.
   Keep its five-by-four board below the battlefield. Narrow windows stack
   controls; wider Fold windows expand the field and flank the board with useful
   controls. Respect safe areas and usable touch targets. Ship this small
   save-compatible correction before its full 3D replacement.
5. Complete Frontline+Gear, then Hearthguard+Hook, then Dead Run+Tower. Carry the
   proven production tools/animation conventions forward. Cover all authored
   regions, enemy roles, bosses, menus and replay scenes, not just opening demos.
6. Archive each graphics chat only after clean integration and a durable handoff;
   create the next chats just in time so six idle sessions do not refill the UI.

## Themes

| Game | Authored 3D treatment |
| --- | --- |
| Frontline Foundry | Rounded military outposts, equipment, animated soldiers and connected front |
| Gear Bastion | Dimensional brass machinery, working generators, automata, beetles and three arches |
| Hearthguard | Lively medieval settlements, priced construction, regional defenses and bosses |
| Hook and Hunger | Tropical environments, chained-weapon animation, salvage and stronger encounters |
| Dead Run | Coastal evacuation streets, readable squad formation, signed gates and roadside rescues |
| Tower Trials | Dimensional tower rooms, animated courier encounters and visible tower growth |

## Evidence and exit conditions

- Astra reviews unretimed opening, heavy and later gameplay footage for every
  game. Show responsive interaction, grounded characters, readable combat and
  spatial depth. Resolve rigid sliding, foot skating, clipping, abrupt movement,
  obscured action and distracting effects. Existing bounded prototype fidelity
  approval does not establish this higher graphics standard or human enjoyment.
- Test cover1080x2520, inner1968x2184, native1080x2400, landscape and intermediate
  windows; exercise real controls after resizing and retain the active encounter.
- Run relevant consequential rules/input/save checks on integration. Reuse
  unchanged evidence rather than repeating every suite after every art tweak.
- Root verifies signed install-over updates with genuine preserved saves, native
  transfer/Back, cold restore and emulator resizing. Keep APKs/runtime/reference
  images/signing data ignored. Keep old failures and source/footage bindings.
- Capture host/emulator frame timing honestly, pool dense actors/effects and
  optimize heavy scenes. Target60fps; no measured Fold7 FPS claim without testing.
- Deliver six graphics-reviewed/emulator-validated APKs with private install
  notes, known issues, checksums and before/after clips. Present previews without
  requiring another phone-testing round. Physical usability/performance and
  human pacing/fun remain explicitly deferred, not waived or represented as done.
