# Hearthguard 0.3.0 / code 3 — independent native evidence review

Reviewed 2026-10-18 by Astra, read-only CPU/files/original stills. **Conditional software candidate clearance; no substantive native blocker found.** This is additive to `hearth-production-final-astra.md`, which independently assessed the full desktop production motion. No new browser playback, Godot process, ADB action, export, game mutation or test suite was run for this review.

## Identity and provenance

- Primary packet: `.artifacts/graphics-overhaul/hearth-graphics-native/report.json`, independently rehashed as `b1d85e609c6bb57f400edaf41e38786e88a52978b990757a6e4fc542812bd329`. Preserve this original report; the rotation qualification below is additive.
- Canonical build: `.artifacts/hearthguard/20261018T182945982997Z/manifest.json`; root source `b974ba283b9106b3e8ca381268b274c91bca9ad2`, runtime/art freeze `042d7c2e1abd2bcf3be300e715bdfa1375f6c8a0` and the previously disclosed helper/docs-only commits. Manifest records clean, unchanged source, successful Godot 4.7.2 import/export, signature verification, package `com.dsschiff.hearthguard`, version 0.3.0/code 3 and no permissions.
- Independently rehashed actual 59,073,994-byte APK: `d2cadff5f81074bccfc88954799e23eeb39546e6c873e1bcf5e9891e1a088455`. Retained successful Android `pm path` and `sha256sum` commands return that exact hash for the installed `base.apk`; this is installed-binary evidence, not just a local build label.
- `device.py` hash `c57e7870e5c5b5dd88dceb3df1eb7d0ade9c7a4cf26d296bfcef908e36d0a67a`; `record_native.py` hash `cb5594402deb77527e7dc85b73ac07152a734db73124f95182fa3adc8809d1a7`. The helpers perform native inputs/readback, not fabricated game-state injection. The retained first missing-emulator command failed before installation; subsequent commands and actual package update succeeded. That failure remains historical evidence.

## Independently recomputed save and input evidence

All **26 snapshot sets / 52 present raw envelopes** revalidated against their recorded byte counts, raw SHA-256, payload SHA-256, revision, committed flag, phase and time. All **16 recorded whole-context comparisons** were independently recomputed from the highest eligible raw slot; all comparison-file hashes match the primary report. Both ordinary slots exist throughout, and no ambiguous highest-revision tie was encountered.

Both actual code-2 ordinary slots match the earlier genuine retained code-2 baseline, the second preinstall read and code-3 pre-first-launch read **byte for byte**. Revisions 479/478 and the entire envelopes survive installation. No clear-data/replacement-save step is present.

Comparison covers every packet key, nested dictionary, array and value, including state, profile, settings, campaign, parked state and legacy snapshot. Revision is the usual sole exclusion. Booleans, array shapes and integer-valued numbers are exact; only genuinely fractional serialization values receive the declared `rel_tol=abs_tol=1e-12`. This does not discard RNG, actors, progression or cooldowns.

The initial settled load advances revision 479 to 480 while preserving whole meaning and simulation time 6.08333333333332. Actual portrait input moves x/z from 3.07809383813292/3.47086983174086 to 4.65841486789286/1.64742852002383; unfolded input subsequently reaches 4.7/0.588875933084641 at time 9.66666666666673. Retained commands contain real input and Back, and the corresponding game image shows the live modeled encounter.

Invalid `INVALID_CODE3` entry/rejection leaves the full saved meaning unchanged. Actual Copy/Paste restores the genuine envelope; import changes revision 485 to 486 and **ordinary-slot committed true to false**, explicitly and only for that import comparison. I checked this against SaveStore's actual reader/writer: uncommitted ordinary slots are eligible; uncommitted temporary slots are not. The import is not incorrectly compared against a stale committed fallback. Subsequent ordinary save restores the flag normally. At effects-off, the sole nonrevision change is `/settings/reduced_effects`; actual restoration returns the complete packet to the earlier meaning.

Cover and unfolded holds, intermediate resize, requested-wide resize and return, stable active-Home/warm return, unfolded cold load, modal Back, and final Home/force-stop retain the full intended context. Active-Home and subsequent stable reads hold time 16.7833333333337 at revision 497; settled cold load reaches revision 498 without gameplay advancement, and final stopped revision 500 retains the same meaning. Final commands show Home, package force-stop and `wm size reset` before the final raw read.

## Original native image review

Directly inspected original captures 03, 07, 12, 13, 14, 18, 19, 26, 27 and 28. Checked the original PNG headers for all 25 indexed captures against declared dimensions.

- 03 is the settled restored portrait game/menu, not a splash. 07 is actual unfolded play with modeled raiders, commander, physical pads, circular control and full priced action controls. No material clipping/overlap is visible in those sampled native surfaces.
- 12 visibly rejects the invalid code; 13 displays the pasted genuine JSON and paste feedback; 14 returns to the paused game after import. These observations agree with raw-save semantics, rather than relying solely on button labels.
- 18 is a fitted 1100×1400 intermediate paused surface. 26 is the settled 1968×2184 cold-loaded inner game/menu. 27 contains the complete inner transfer dialog with visible Copy/Paste/Import/Back controls; 28 returns to the fitted paused menu after native Back.
- **Additional qualification: 19 is visibly a rotation transition**, with a tilted game surface, gray corner regions and clipped top edge. Do not count it as settled fit evidence. Its independent raw save-retention comparison is valid. Requested 2184×1968 produced a 1968×2184 capture under the existing portrait activity policy; native landscape layout is not proved. Settled inner acceptance rests on 26 (and the earlier inner play), not 19. This is an evidence-label correction, not a demonstrated persistent layout defect.
- 02 is Godot startup; 25 is startup rather than the settled cold view. Neither supplies loaded-UI acceptance. 03 and 26 supply that evidence respectively.

## Native recording and disposition limits

Independently rehashed unchanged `17-native-active.mp4`: 2,611,754 bytes, SHA-256 `5568a86531d930a2cb4c1fa8193095bdf4c5534a7c4a1ee1b4557bb3f57ce676`. Retained probe records original 1080×2400 H.264, 255 frames and 9.553867 seconds. The native recorder uses actual Resume then Back with no resize/retime operation; retained full-decode log is empty and the primary report records successful full decode. I did not launch a duplicate decoder or replay this short film for a new motion score. Its `r_frame_rate=90000/1` is VFR metadata, **not a rendered FPS result**.

The signed candidate is supported for software handoff within these bounds. Prior all-eight desktop quality judgments remain separate; this native encounter is not a new heavy/later/campaign-completion proof. Sound is OFF, and no physical-phone, audio, soft-keyboard/IME, thermal, phone performance or human-fun acceptance is claimed. Desktop landscape evidence also remains separate. No new phone gate or broad campaign rerun is warranted by this bounded review.
