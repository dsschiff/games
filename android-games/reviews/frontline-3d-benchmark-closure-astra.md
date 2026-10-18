# Frontline 3D benchmark — focused closure

2026-10-18. **The two open items in the initial review are closed. Accept the bounded desktop playable 3D benchmark.** Attacks/contact rises from **2 to 3/4**; the other seven independently scored rows remain **3/4**, with their original evidence and sampling qualifications. The initial `frontline-3d-benchmark-astra.md` remains historical and unchanged. This acceptance is not a six-game completion, full regional-art approval, Android release, physical-device result or fun judgment.

## Frozen source and focused evidence

Worker commit `3a12e0455e6e1e0f6c49d68c4d35593a50fbc070` is clean. It includes the reviewed socket fix `24f41752caafbaedc0d0dd624b9797b81918b2d3` and import preflight `047854ed310bb7df1ebd5ecf82d9a5c4d5cde950`. The only runtime change from the original accepted-as-evidence opening/finale source is the six-line cannon socket branch. Assets, rules/damage timing, adapter and outpost are unchanged. New closure harness/runner/docs are declared evidence tooling changes. Independently checked all **102 recorded source pins in each of four runs** against final worker files: no differences.

Independently hashed the served files, matching `frontline-focused-review/review-packet.json`:

| Passage | Duration / encoded cadence | SHA-256 |
| --- | --- | --- |
| Sideways shot | 14.916667 s / 60 FPS | `c54517ac073b58af9ed983b700dcc07412307687b1c2e830157aca6e7e7a96d3` |
| Pause/resize/park | 31.333333 s / 30 FPS | `f2f71794fd6ee134ee241b2b6fa57a5ee342c12ab393d27ce93337936ee1a074` |
| Separate cold restore | 5.9 s / 30 FPS | `27a44a97bd4e33315e1729a5811e9d204c788e7a7833b9eae56e28f44fc518da` |
| Genuine Retry | 4.933333 s / 30 FPS | `a45162bb0241cd20b48a1e58d556999917369dd23dc0e0868aca8bb0439f50ca` |

All four played once from zero to natural `ended` at 1× in owned Brave tab 413128833. Visible DOM records had 39/68/21/19 events, monotonic times and rate 1 throughout; no mid-play seek, speed change or reviewer pause. Condensed audit, including every non-tick event, is `../graphics-overhaul/frontline-focused-review/astra-visible-playback-audit.json`. The tab is closed and the browser/GPU slot released. No Godot render, export or device action was run by this reviewer, and the unchanged long clips were not replayed.

The 984×1280 encoded canvas is correctly labeled padding: source `record_frame()` blits native 720×1280 or 984×1092 images at 1:1 into that canvas, rejects overflow, and never resizes the pixels. Sequential frame inventories contain 895/940/177/148 frames. Encoding commands match fixed-step capture cadence and contain no rescaling, temporal interpolation or stitched cold restart. These are silent validation movies, not real-time host/phone FPS evidence.

## Socket and contact closure

`actor.gd` now parents the vehicle muzzle to the animated Cannon and derives its tip from the mesh's authored local -Y cap. This inherits turret rotation, barrel recoil and parent model scaling. The independent coordinator 60/0 suite records lateral tip `(1.13, .86, .14)`, recoiled tip approximately `(1.027, .86, .14)`, hull yaw zero. No gameplay callback or damage timing moved.

The focused actual-play passage catches an authoritative rover shot at simulation 21.2667, approximately **12.52 s** into the clip, with turret yaw about -0.642 relative to hull yaw -0.447. I inspected playback samples around 11.75–12.28 s and the original `actual-sideways-shot.png` at 12.52 s: the tracer leaves the turned barrel toward the red enemy, rather than the old hull-forward point. The original recoil image at approximately **12.67 s** shows the retracted barrel. The effect's stored origin is the emission-time tip; a later sampled muzzle can differ as recoil/aim continues. This is the narrow source-and-rendered confirmation requested in the original finding. **Attacks/contact now 3/4.**

## Reset, reduced-effects and save closure

The harness uses real GUI button and joystick input; it reads state/poses for assertions and copies app-written save bytes. It does not call gameplay/animation handlers to manufacture the result. Window size changes are explicit live viewport actions. All 5/18/9/6 focused assertions pass.

- **Pause/resume:** park begins in the actual paused mission-12 scene; sampled playback shows the pause menu at 0–0.55 s, resumed movement around 12.8–13.9 s and the final paused menu with Reduced Effects ON at 31.33 s. Independently hashed all eight before/after pause image pairs across the four runs: every pair is byte-identical. The corresponding full-state and joint-pose assertions pass.
- **Resize and danger:** the genuine reduced-effects Storm warning is captured around park 25.83 s; native 984×1092 paused resize is around 27.33 s. I directly inspected the original inner-aspect paused image: menu/status fit with the same encounter. The frame inventory confirms actual window dimensions and return to 720×1280, not resized video. The live-resize check preserves encounter/profile/career and clears stick input; subsequent genuine joystick movement passes.
- **Cold restore:** the restore receipt's two starting slot hashes exactly equal the park run's exported raw slots. Career, profile and settings match independently; the sole state serialization difference between provenance, expected boundary and captures is one near-zero enemy cooldown (`3.87884169228414e-15` versus `3.87e-15`, absolute difference about `8.84e-18`). This is consistent with the game's JSON-normalized equality, not lost progress or a changed integer field. The pre-boot whole-context check passes. In restore playback around 0–0.54 s, the scene is paused; around **1.07–2.13 s**, the commander moves while the red warning remains visible under reduced effects. No sampled phantom attack burst appears.
- **Retry:** the separate clip begins at genuine mission-12 victory (30 stopped, 0 escaped). Around **1.05–1.59 s**, actual Retry opens the ready scene at time 0; around **2.12–2.64 s**, launch and commander movement follow. The same mission definition and earned profile/career are retained; old effects/queued attacks are absent. This closes the reused-ID visual reset passage without replaying the whole campaign.

Visual perception remains sampled screenshots during uninterrupted normal playback, supplemented by original event stills and byte-identical pause images. I do not claim exhaustive frame-by-frame perception or audio review. The observed and source-bound evidence is sufficient to close these two bounded findings.

## Scope carried forward

Unseen regional assets/attack combinations, real-time performance measurement, sound, human pacing/fun and a versioned Android graphics release remain production work as already documented. The brief screen seen during Retry also has crowded/clipped explanatory prose at the narrow view; treat that as a bounded UI follow-up before release, not a newly invented graphics-benchmark gate. Core active-play HUD and the large purchase decision cue retain the initial 3/4 assessment. No new full-campaign or physical-phone gate is introduced.
