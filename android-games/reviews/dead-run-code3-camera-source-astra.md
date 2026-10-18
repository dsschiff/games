# Dead Run code3 camera-only source review

**Disposition: no new P1/P2 found. The source/geometry correction is supported and may proceed to the actual code2→3 update and native viewport verification. The previously observed Android inner-camera P2 is not yet closed at the candidate level.** This review does not promote code3 or substitute headless geometry for rendered/native evidence.

Reviewed worker63406d0 integrated as `de0d110f596b69f98c1ff42e022540334b71fb05`, relative to the integrated f9609eb validation baseline. No game tests, device, GPU, browser, clipboard, or builds were executed by this reviewer; only saved evidence was read/hash-checked and this ignored report written.

## Production scope and reasoning

The production diff is limited to `scripts/main.gd`, `scripts/campaign.gd`, and version metadata in project.godot/export_presets.cfg. Rules, definitions, save schema/validation, actor geometry, touch input, UI layout and camera pose are unchanged. Code/name are3/0.2.1; package, permissions, ABIs and export route are unchanged.

`main.gd:285–297` derives horizontal FOV from the authored base and actual viewport aspect, keeping KEEP_WIDTH. For width/height above1080/2400, multiplying the horizontal half-angle tangent by the aspect ratio preserves native vertical coverage. At native and narrower cover ratios the expansion is1, preserving their existing projection. The campaign override at `campaign.gd:49–50` supplies46°, while legacy retains58°. Camera creation/rebuild immediately calls the helper (`campaign.gd:69`, `main.gd:125`), and layout reapplies it (`main.gd:330`). Values are derived from authored FOV, so resize round trips cannot accumulate expansion. The code changes neither camera position nor control coordinates and does not clamp crew state or crop/stretch the viewport to conceal the defect.

At the actual1968×2184 inner aspect, the accepted measurements are80.728° campaign and95.967° legacy horizontal FOV. These are supported scene frusta, with additional side scenery; no problematic FOV clamp is implicated at the reviewed dimensions. This is a three-size device-envelope check, not a claim about every arbitrary extreme aspect or visual quality on every display.

## Regression integrity and binding

I read CAMERA-CHECKPOINT.md/json and the complete `tests/camera_projection.gd`. The test instantiates the actual campaign scene, its real parked legacy child, and standalone legacy scene in a SubViewport with rendering disabled. It uses actual Camera3D projection matrices, unproject_position and frustum checks. Bounds come from authored mesh AABBs and the rescue caption's real font AABB in camera-facing billboard coordinates; the test requires both line and caption to be present. It deliberately sets synthetic crew/weapon/lateral/threat fixtures, not naturally earned gameplay, and says so.

There are108 envelopes over native1080×2400, cover1080×2520 and inner1968×2184, campaign crew5/20 and all three weapons, legacy crew3/5/12, center and both reachable lateral limits. Both bob extrema, recruit parts, full footprint, line/caption, nearby threats and a road-width near-space box are checked with explicit side/top/bottom margins. I verified that every tested group is nonempty: minimum counts crew288, footprint8, near-road8, threats336, line/caption16. This avoids vacuous passing of an absent geometry group. Resize signals, rebuild-before-layout, repeated layouts and round trips compare actual projections and state.

Independently rehashed all **540 accepted worker artifact rows plus179 old-source sensitivity rows**: no mismatch. The final same regression against old runtime has862 checks/180 assertion failures/108 envelopes, with no script errors; the new worker run has862 checks/zero failures/108 envelopes. I compared the72 native/cover envelope records directly: all are exactly equal old→new. The retained old failures are not erased or relabeled as passing. The initial parse failure remains historical.

All28 declared current runtime LF bindings and three test/runner bindings matched this coordinator source. Root's independent `root-code3-camera-camera-headless-20261018T105211666982Z` receipt and all183 artifact rows also verified:862 checks/zero failures, source unchanged, no unexpected errors. Receipt SHA256: `fd7f29f6d7e07aad0d822f5c54686a0b7f87a8d34d5d086175be94c8c25bdfac`.

The accepted campaign smoke and11-check legacy migration smoke are separately retained. They are bounded compatibility checks, not a new full24-road campaign run. Original movies retain their old runtime bindings; no code3 playback is claimed.

## Build evidence and remaining native gate

The saved build manifest hashes to `95e2de115c2b03e9e12ee23e0506fbc92bde756a7162439c86b1da3e97142de6`; it records clean unchanged source `f99965a125f955478366a4b45912d1e8e6fb4ead488d8d05b49fd2ee7b26214e`, signed code3, no permissions, successful export. I independently hashed the actual APK to `ab1a8863fdb92815278924e146092c864b38309baf57fa521e99944b400a415c`. Signature/package inspection is the recorded pipeline result, not a signature tool rerun by me.

Before candidate-level P2 closure, preserve the genuine earned code2 body through the actual update and inspect the new native/cover/inner frames, including full crew, footprint, rescue line and nearby playfield; verify return to original geometry and retained progress. The existing code2 cropped image remains valid negative evidence. Physical Fold7 touch/folding, soft IME, sound, FPS, human pacing and fun remain unverified. The five other candidates remain frozen and outside this review.
