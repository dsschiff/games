# Frontline production graphics — final Astra review

2026-10-18. **Accept the production graphics candidate at the contract's coherent/convincing level: all eight rows score 3/4. No remaining substantive source or visual blocker identified.** This extends the previously accepted outpost benchmark to the reviewed production regions, roles, bosses and entry/reset paths. It is not Android installation/update acceptance, phone performance proof, a fun assessment, or a claim that every frame/region encounter was inspected.

## Source and evidence boundary

Runtime/art freeze: worker `dca06bf7b31a6c113e969133562adb1776826c4f`, on production `998dce3063eeedd2e60954b89b2796a0771ca257`; coordinator runtime integration `e5aeb5e`. Worker final HEAD `df2b8d77b5666dae68d3df39aed00a8d1920790e` adds only GRAPHICS_PRODUCTION.md. End-of-review status is clean; diff from dca06bf is that document alone. Actor/outpost/Ranger hashes rechecked at end match the inspected freeze:
- actor: `2c574586cea4104bcd684873be6f9d36e92039705c5882239d05107a27088759`
- outpost: `0604fb223e0282b03edd179f6217cb5c8e6d5591a7aa727b622ec970ac2c77d6`
- Ranger GLB: `e8ce03a7576554575f2d58430ae744d0b8eb5583d08ba0357f5db2c991764941`

Read the original quality contract and directly viewed Daniel's Top Force reference again. It supports the bright modeled form, beveled surroundings, grounded shadows and readable clearing target; it does not establish animation or frame rate.

Seven exact packet movies were SHA256 checked and played naturally from start at 1× to ended in one owned Brave tab (IAB unavailable; background visibility unsupported). No mid-play seek, speed change or pause was performed. Full playback is evidenced by visible DOM audit, **not a claim of continuous human vision**: my visual observations are screenshots sampled during playback, supplemented by original full-resolution PNGs. Short legacy/Ranger passages had sparse browser samples; their original native captures and source/socket checks supply the close detail. Browser end frames sometimes turn dark after media finishes; the retained untouched final PNGs establish game end state rather than treating that browser surface as game rendering.

Audit: `../graphics-overhaul/frontline-production-review/astra-playback-audit.json`. It preserves all visible event names/wall times/media times, common state fields, and sample times. Owned tab 413128837 closed; GPU/browser slot explicitly released. No Godot, ADB, device or clipboard operation by reviewer.

| Passage | Full duration | Source qualification |
| --- | ---: | --- |
| opening | 119.900 s | Historical production998; general opening/equipment/front coverage |
| carrier | 72.400 s | Historical998; earned mission8 continuation |
| storm | 46.067 s | Historical998; genuine earned mission12 continuation |
| legacy | 6.967 s | Corrected dca; genuine catalog1 restore/resume and explicit campaign entry |
| ranger | 12.367 s | Corrected dca; actual Ranger combat |
| drill | 180.367 s | Corrected dca; earned mission4 continuation, boss defeated, **23/24 stopped and one enemy remains**, not a new mission clear |
| retry | 4.933 s | Corrected dca; genuine victory Retry/brief/live-pause; native frames padded, not distorted |

The already-retained contiguous Drill final30s excerpt (parent150–180s, SHA `8c50b137f5aa7a3970f48523868d3d1b3c5eed5b87eb2fde60c288ce0b822f93`) was played four additional full natural passes because tool-turn latency missed the short boss lifetime. Final batched screenshots resolve that gap at parent156.077–159.088s. This is repeated observation of the same run, not extra gameplay evidence. All seven original SHA values remain in review-packet.json.

## Independent quality scorecard

Scores use the original 0–4 contract; 3 means coherent and convincing, not exceptional. Each row passes independently.

| Contract row | Score | Observed basis and limits |
| --- | ---: | --- |
| Original asset craft | **3** | Full-resolution regional/legacy/Ranger originals show shaped boots, limbs, helmet, grip and distinct weapons; modeled station stocks, HQ windows/door/roof equipment, rounded sandbags and dimensional terrain. Carrier boom, Storm body/pods and Drill nose distinguish the heavy silhouettes in actual passages. Ranger's corrected long barrel is visible. Repeated kit elements still look standardized; not a4. |
| Locomotion and facing | **3** | Opening commander positions/turns around29,58,86,113s and corrected Drill passage show locomotion poses separate from stationary crew aim. Close excerpt samples150–155s show commander returning from pickup with alternating travel poses, stopping at the gate, while crews retain separate facing. No rigid capsule translation or conspicuous pose pop in sampled movement. Tiny foot contacts are not verified for every frame. |
| Attacks and contact | **3** | Carrier54s and Storm30s show aimed crew/boss exchange; corrected legacy native resumed-play capture has a tracer at the aimed rifle tip with target-local health feedback. Corrected Drill parent156.8–159.1s shows the large vehicle advancing, crew aim following it, short localized tracers and clear target silhouette. Source/socket geometry closes the known origin defects. Boss removal/state is supported by later samples and retained outcomes; I do not invent a sampled view of every death frame. |
| Lighting and materials | **3** | Characters, HQ and beveled defenses read as volumes under a consistent directional light; grounding shadows distinguish bodies from terrain. Bright yellow/green/red actors separate from the field across the12 palettes. Some cliff caps are nearly white and shadows harder than the supplied reference, limiting polish but not flattening the modeled scene. |
| Environment and composition | **3** | Directly inspected corrected regional originals across all12 districts (region1 also covered by opening). Landmarks/palettes distinguish rail, signal, quarry, night, orchard, supply and foundry settings. Foreground stations, defended gate and open approach remain legible. Corrected lateral scenery stays outside the real commander corridor. The common clearing and repeated oval ground patches remain obvious; this is coherent production reuse, not exceptional bespoke level composition. |
| Reinforcement causality | **3** | Opening progresses from empty front through equipped crews/rover to six active slots; real station stock and front state remain spatially connected. Corrected Drill shows deployed crews and rover occupying front positions while commander returns to equipment/pickups. Native equipping/deployment/purchase captures and actual-input receipts support the transitions between sampled views. |
| HUD and readability | **3** | Compact top status, contextual large action button, objective/next threat, touch controls and color/silhouette separation remain readable. Decision cost belongs in the large2D action button, not tiny world labels. Retry around1.0s visibly places long Foundry brief in its scroll body above fixed support action; final4.933s live pause menu fits. The scene is shown at native dimensions in originals; browser scaled playback is not phone legibility testing. |
| Motion coherence and restraint | **3** | No sampled T-pose, synchronized bobbing-only army, uncontrolled shake or persistent effect cloud. Corrected excerpt shows independent crew/commander turning and short fire effects without obscuring the field. Retry resets victory into ready/live state without stale victory effects. Previously accepted pause/resume/cold-load/reduced-effects closure remains applicable because its relevant mechanisms are preserved; this production packet is not falsely represented as a new full replay of those prior checks. |

## Closure of concrete source findings

- **Ranger physical muzzle:** parsed actual corrected geometry reaches Z=-1.1599999666, while the socket is Z=-1.1649999656, approximately0.005 beyond the cap. Long barrel and scope were authored. Three aim/recoil cases check the weighted cap, not a decorative marker substituted for geometry.
- **Same-call attachment synchronization:** the prior0.911021 mismatch was reproduced, then eliminated by forcing skeleton transforms and updating the BoneAttachment pose before sampling its child socket. Outpost samples after pose application. No rule damage/cooldown timing moved into animation.
- **Scenery/traversable geometry:** full transformed mesh bounds, including yaw/scale/hierarchy, drive lateral/rear placement. All12 districts and three seed styles clear commander bounds plus0.275 radius. Corrected originals no longer visually contradict that corridor.
- **Preservation/provenance:** all47 old/new GLBs parsed:24 byte-identical,22 mesh-name-only JSON differences with exact binary buffers, only Ranger geometry changed. Rules, campaign rules, definitions, save store and boot remain exact from accepted3a12e04 after LF normalization. Root's independent103 focused checks passed. Those checks support architecture, not visual scores.
- **Entry/reset:** catalog1 routing and genuine backup survive explicit campaign entry; genuine earned Journey selects all12 districts plus support/seeded menus. Tour covers briefs and first2.8s per region, not new campaign progression. Retry retains earned career/profile. Signed APK/native update validation remains root-owned.

## Performance and remaining boundary

Corrected real-time sample:2649 warmed active frames over44.212s, median16.666ms, p95 16.754ms, p99 18.151ms, none above33.333ms. Live-boss subset968frames/16.161s, p99 18.177ms. Peak1018 draw calls,288650 primitives,734 nodes, **seven combatants**. The frame_post_draw monotonic harness excludes movie writer/fixedfps/frame readbacks and resets across ineligible pauses/modals. These are desktop render-loop submission intervals on RTX5070Ti/Ryzen7950X3D at720×1280 Compatibility, not GPU/OS presentation timestamps, maximum crowd load or phoneFPS.

Production graphics candidate is acceptable for the next existing native release checks. APK code2→3 update/save/native rendering checks are still pending outside this review; no physical-phone or new whole-campaign gate is added. Optional later polish: reduce repeated ground-patch rhythm, preserve more tone on pale cliff caps, and enrich regional composition within the proven movement bounds. Those are not blockers or requirements to recapture this accepted candidate.
