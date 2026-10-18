# Dead Run code2 inner-screen framing — confirmed P2

**P2: supported unfolded geometry crops the player formation and hides the rescue boundary. Do not promote code2 as the conditional software candidate until the responsive-camera fix is verified.**

I directly viewed the untouched native captures at original detail:

- Inner1968x2184, `inner-20261018T103728745096Z/inner-STOP-review.png`, SHA256 `4b551a803bc096cf2b7d2f7db0c5c5ae77afed44861df66c34b66d41bf21628b`: the five-person formation is cut by the bottom image edge. The complete gold footprint, rescue line and its label are not visible. The pause UI remains readable.
- Same packet after reset to1080x2400, `held-STOP-review.png`, SHA `046714136e9055a7fa7534fcbf4e541a49aaa8d428e5a9a04445ffe99c438277`: all five crew, the footprint, rescue line and label are visible.
- Cover1080x2520, `cover-20261018T103658321947Z/cover-STOP-review.png`, SHA `728bdc0aa54e2a0cae55ab0e11ef3a91c8074a6b690ad7e635395b3d4d83962d`: full crew and rescue boundary remain visible.

These are actual screenshot pixels, not a black-preview or decoder ambiguity. Both geometry packets' before/held decoded bytes are independently identical. The clipping occurs below the pause panel at the physical image boundary; removing the panel will not restore offscreen world geometry.

The concrete source cause is the fixed campaign camera transform/FOV at `android-games/dead-run/scripts/campaign.gd:63–66` together with `Camera3D.KEEP_WIDTH`. `campaign.gd:222–223` calls inherited layout, and `scripts/main.gd:316` reapplies KEEP_WIDTH on every resize. There is no aspect-dependent fit to keep the player/boundary envelope on screen. The rescue label is explicitly placed at `campaign.gd:94`; it has not been removed from the scene. The wider inner aspect exposes the insufficient vertical framing. This affects reading the formation footprint and near contact/leak boundary during lateral control, so it is consequential gameplay visibility rather than cosmetic layout polish.

Recommended narrow repair: keep rules, saves and authored state unchanged; apply aspect-aware camera framing after camera creation/rebuild and resize, including the inherited layout path. Fit the complete near gameplay envelope with margin while preserving the current portrait composition: full formation and gold footprint at crew5 and20, both legal lateral extremes, the rescue line and relevant near-threat area. Avoid changing only the initial camera assignment, because inherited layout currently reapplies the policy.

Closure needs a source-bound projection/framing regression at native1080x2400, cover1080x2520 and inner1968x2184, testing formation extents rather than only actor centers; retain this old-code failing capture/control. Inspect the new native inner image and an active gameplay view for complete crew/boundary and usable threat/road scale, and confirm portrait/cover do not regress. Actual signed update must retain the earned campaign/legacy/settings state. A camera-only code3 amendment is appropriate; no broader rule/save rewrite or repeated full campaign is implied.

All previously passed native input/save/upgrade/transfer observations remain valid within their scopes, and this failed inner view must remain preserved. This review itself made no device/GPU/game/source changes. Physical unfolding, touch/IME, audible sound, FPS and human fun/pacing are still unverified; emulator aspect evidence is sufficient to establish this software framing defect but is not a physical-fold test.
