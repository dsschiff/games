# Hearthguard floating-control patch — bounded source review

2026-10-18. Disposition: no substantive source blocker found in this patch. Ready for the already planned corrected normal-speed visual review; this does not close the observed Pad 5 overlap visually or grant production graphics acceptance.

## Inspected boundary

Runtime patch `042d7c2e1abd2bcf3be300e715bdfa1375f6c8a0`, plan freeze `af59a73dc4d171128fbebbe2709d5e6bde665db8`, worker `C:/projects/active/_worktrees/games-hearthguard-20261018`. Actual clean HEAD at final read was `3e76816f72082baee0eb8667e92e661c31658f21`. The later delta is confined to two test helpers: a schema guard before accessing campaign Journey controls, and encoding only when the gameplay report and frame inventory exist. It does not change this runtime/art patch. No game files were edited and no engine, browser, GPU, native device, or test run was started for this review.

Read the main/settlement integration, complete clearance implementation, focused assertions and retained root receipt. These raw SHA-256 pins were checked again at the end and match the root run's corresponding executed-source pins:

| File | SHA-256 |
|---|---|
| scripts/main.gd | a1db9bdc4bfca18f2229dc79eaad823dcb51f9471cac6fc144424bb5a9a9d325 |
| scripts/presentation/label_clearance.gd | 20d81663b6f8b574e5601073033fed4d36db1e4aa3e937876287a84796abc27d |
| scripts/presentation/settlement.gd | a2dbef93b731512a04b800a384818f2b30cd4e2089432bb5dc5021ab1fe7b90b |
| tests/joystick_tests.gd | 6715a54c818822620743466da066f9031c65ac6edf4ca750402d481bc1fa3ad9 |

## Source assessment

- **Rules and input remain isolated.** The patch paints a circular 160-pixel base and 64-pixel knob and offsets presentation labels. It does not move physical pads, rule coordinates, hit regions, floating input origins, movement normalization, physics timing or save handlers. The controls continue to ignore GUI mouse filtering. The existing knob travel can extend two pixels beyond the base; the clearance rectangle's 12-pixel margin covers that extension.
- **Anchors are restored rather than accumulated.** The scene-owned clearance object records each label's original global position once, restores all recorded anchors before recomputing placement, prunes invalid/replaced labels, and clears records on tree exit. Release or pause supplies an empty obstacle; resize already stops movement and updates the camera/field rectangle. These routes restore authored positions instead of making each offset the next frame's baseline.
- **Camera and text changes invalidate placement.** The signature includes control/available rectangles, camera transform, orthographic size and offsets, label identity, text, font size, pixel size and outline size. Actual generated glyph triangles are cached per text/style key and projected with the billboard camera basis. This covers the current static authored anchors and live title/price/SILENCED text changes. It is not a general solution for arbitrarily animated label anchors, which these labels do not use.
- **Placement is bounded and failures stay visible.** Nearest edge/corner candidates precede a bounded 7-by-7 fallback grid. A candidate must fit the field, clear the control and separate from other label rectangles. If none fits, the implementation retains the original label and records its ID in `unresolved`; it does not silently hide information or claim a resolved placement. The current fixtures assert no unresolved labels.
- **Physical association still needs pixels.** Empty-pad labels retain their pad number; constructed pads expose their own tower title. The fallback can move a title farther from its physical pad. Geometry and label identity alone cannot establish whether that association remains obvious in a crowded live view. Assess this in the authorized corrected footage, alongside the original Pad 5 overlap and restoration on release; there is no demonstrated source defect requiring a new test campaign.

## Evidence and limits

Retained root run: `android-games/hearthguard/.artifacts/root-floating-control-joystick-checks-20261018T175237409455Z`. Its receipt reports a successful fresh import/parse preflight, exit 0 and unchanged source; `joystick-report.json` contains **108 checks, zero failures**. Its raw SHA-256 is `3a962e2f546af3c5ce0a63ac755920b3fe2d3d349b1af7880f76eb1802128593`, matching the receipt.

The focused assertions cover seven viewport profiles, two origins and opposing drag directions through actual input events; reproduce the old Pad 5 geometric overlap; verify the floating origin and unchanged input normalization; inspect actual glyph bounds; compare complete state/profile/settings before and after presentation input; and compare one actual gameplay tick with the unchanged rules tick. Release restores anchors, and pause/resume and teardown clear placements/cache. The pause assertion occurs after release, so it is not independent evidence of a held-stick pause transition; that route was inspected in source.

The separate later eight-pad glyph fixture is explicitly synthetic and unsaved. It supports bounded layout coverage only, not earned progression, role exposure or later-game visual acceptance. Text mutation invalidation is supported by the inspected key logic, not claimed as a separate live-mutation test here.

The older full opening at the previous freeze remains historical and retains the real joystick/Pad 5 overlap. The corrected cold-restore passage and genuine earned heavy/later passages have not been visually reviewed in this CPU-only assessment. No motion score, rendered clearance approval, phone performance, audio or fun claim is made.
