# Ready-to-Begin design increment

A prepared foundry now starts running with one Begin after opening/closing Menu,
Guide or Save, after synthetic Home/return, or after tapping Pause during setup.
Returning through the map continues to work. The pause flag applies to an active
battle; Begin explicitly clears it when starting the prepared board. Utilities
preserve the board, brass and progression while the player is preparing.

Active Home, close, menus and cold restoration still suspend battle until an
explicit Resume. Ready imports remain ready for Begin; battle imports stay
paused. Terminal Retry starts a fresh attempt with the same encounter snapshot
and preserves all earned profile progress.

Only scripts/main.gd changes runtime behavior. Gear/battle rules, campaign
content, profile logic, saved schema/writers, original art, Android version,
package and signing are unchanged from base c66ee90.

## Verification

DESIGN_INCREMENT.json binds the final runtime and private run receipts/logs.
All tests are isolated, headless and silent (Dummy audio); no GPU, clipboard,
Android, browser or cloud path was used.

- Baseline: 35 checks, 12 failures. Ten failures reproduce five stuck paths:
  Menu, Guide, Save, Home and ready Pause leave phase=battle, time=0 and produced=0
  after Begin. Map return already works. The baseline's menu_resume route is a
  direct ready Pause tap. Two other failures compare raw save serialization;
  comparing complete decoded save meaning avoids that textual false failure.
- Final actual-process input: 39 checks and 136 input events pass. Each of six
  ready paths preserves full save meaning before Begin; the normal process loop
  then advances about eight simulated seconds and produces five defenders.
- The same test uses actual GUI drag/buy input and the normal process loop to
  earn a first-road victory. Victory Retry and a subsequent natural defeat Retry
  keep the full earned profile and encounter snapshot, and each fresh attempt
  advances after one Begin. No direct advance/Battle.tick calls or fabricated
  earned outcomes are used in this test.
- Active synthetic Home freezes the whole active save. A new scene reads the
  app-written disk save and preserves complete decoded state/settings/profile;
  map return waits until explicit Resume. These are desktop engine lifecycle
  checks, not Android Home, process kill or physical-phone evidence.
- Existing rules/storage/campaign regressions: 164 checks pass.
- Existing integration and resize/control regressions: 1466 checks and 202 events
  pass. Transfer now tests invalid and valid Import buttons for both ready and
  battle fixtures, preserving whole contexts and their appropriate pause states.
  The first 1462-check run failed only its obsolete ready-import paused=true
  expectation; that original failed receipt is retained separately.

Reproduce:

```powershell
python android-games/gear-bastion/tests/run_graphics.py phase-input
python android-games/gear-bastion/tests/run_graphics.py rules
python android-games/gear-bastion/tests/run_graphics.py input
```

The focused mode uses fixed simulation frames with the normal process loop;
its simulated duration does not measure human pacing or fun. Existing geometry
and transfer fixtures remain labeled fixtures. Independent review and a genuine
signed Android update remain with the coordinator. No APK was exported, installed
or published; no physical Fold7, frame-rate, audible-sound or cloud acceptance is
claimed.
