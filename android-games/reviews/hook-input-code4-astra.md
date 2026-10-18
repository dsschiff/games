# Hook code4 touch and clipboard review

Reviewed frozen worker `283522ea2a5cc77ffdbdd0ee753143fd1674b334`, integrated `3669375`, against code3 `bde8994c8fd55369dd9588035c4c3c3c7d3fda03`. Scope: independent static review of the production delta and focused regression, inspection of frozen reports/logs, and direct viewing of three rendered PNGs. No game/test/build/ADB execution by this reviewer.

**Verdict: no new P1/P2 finding. The source-level touch/export defect is closed; native Android acceptance remains conditional on the coordinator's actual code3-to-code4 update and platform checks.** Earlier campaign visual approval and both save-validator closures remain applicable.

## Production correction

- `project.godot:27` enables touch-to-mouse emulation for native GUI controls. `scripts/main.gd:309-312` filters only emulated mouse events at the world `_unhandled_input` boundary, retaining original finger ownership and ordinary mouse support. This avoids disabling emulation before TextEdit receives it.
- `scripts/main.gd:616-624` still exports/selects the complete checked code, copies it through the supported DisplayServer clipboard, compares exact readback, and reports copying only on equality. Failure/unsupported-display messages do not claim success.
- `scripts/main.gd:625-629` guards Paste on clipboard support. Save format, validation, campaign rules, definitions and progression are outside this runtime delta.

## Defect sensitivity and test integrity

`tests/native_transfer.gd:25-47` replaces unrelated clipboard contents with a sentinel, checks exact exported clipboard content, focuses TextEdit with injected ScreenTouch, and sends Ctrl+A plus Unicode key events for `INVALID Ω漢🙂`. The test neither assigns TextEdit text nor calls `grab_focus`. Its scrolling uses mouse-wheel events, so it is not evidence of Android scrolling or IME dispatch.

`tests/native_transfer.gd:49-81` checks whole state/profile/settings in memory and durable storage. Invalid import must keep the revision unchanged; valid Paste/Import must produce a strictly newer revision and match the whole decoded export. This prevents the original silent reimport from masquerading as rejection. The fixed rendered report records rejected revision 1 and valid-import revision 2.

`tests/native_transfer.gd:99-132` tests real finger drag/release while injecting explicit emulated mouse motion/release; those copies cannot redirect or stop the owning finger. Button taps count exactly one pressed signal (`:134-152`). Any recovery mouse-click fallback fails the suite (`:87`); accepted runs report zero fallbacks.

The accepted sensitivity namespace is `baseline-sensitive`, not the restricted clipboard-denied attempt or earlier interactive test. Its copied test and final test have identical SHA-256 `b8da087239867e00f2f19ea3de086f9226435077f55daaeb1bde6078b02241f6`, independently compared during this review. Frozen reports show code3 failing 13/36 checks, code4 rendered passing 36/36 with the actual Windows clipboard, and headless passing 32/32 while explicitly substituting typing for unavailable clipboard support. These are inspected builder results, not independent executions by this reviewer.

## Evidence inspected

Paths below are relative to the worker game's `.artifacts/review-input-code4/` namespace and indexed by `evidence/native-input-code4.json`:

| Evidence | SHA-256 |
| --- | --- |
| `baseline-sensitive/native-transfer.json` | `b38d8935a960683e71a1835c5bdd6f177379e6dd82c93578be59774791ad48e3` |
| `fixed-rendered/native-transfer.json` | `0ffaee22674482254dbdc0a5a9a9ff47499d16e3cc57434184de53458ca6a1d0` |
| `fixed-headless/native-transfer.json` | `60a3c69796eda5578c84ce221ab7a1d50ca2bebba0ee3a8768d1339672e29904` |
| `fixed-rendered/typed-unicode-invalid.png` | `85c8421979f1c81b4e388a7581097dc943f99cfb954bb8929c60c47f60877e6a` |
| `fixed-rendered/native-invalid-rejected.png` | `3b6f87e30da759d51a8c5d7c54e443d19886ecf0fe430511650db61a6334c853` |
| `fixed-rendered/native-valid-imported.png` | `9d7e157538498cdd0c149f58220646010fd7b40b441e12b5985f74dba13a63d2` |

All three PNGs were directly viewed: actual Unicode text, readable invalid-save/current-progress-retained feedback, and successful imported/resume feedback. Fixed rendered log contains the PASS sentinel and no clipboard backend error. Restricted failed attempts remain excluded from accepted clipboard evidence.

## Remaining gates

Coordinator-owned binding verification, independent focused execution, signed APK update retention and actual Android TextEdit focus/soft keyboard/clipboard checks remain separate. Desktop event injection and Windows clipboard evidence do not prove Android IME, physical Fold7 touch/folding/safe areas, audible sound, phone FPS, human pacing or fun. No full 174-check route rerun or new movie review is claimed for this input-only amendment.

## Native follow-up and conditional software-candidate verdict

**Code4 may advance as a conditional software candidate for physical-phone testing and allow work on the next games. No new game-source P1/P2 is established by this diagnostic. Soft-keyboard display and IME composition remain unverified; the native packet is correctly marked `partial_ime_unresolved`, not PASS.** This supersedes the earlier pending-update/clipboard status only to the extent documented below. It does not accept physical-phone usability or close the portfolio's device gate.

This follow-up inspected the coordinator's saved upgrade/platform manifests, assertions and decoded durable packets; it did not execute Android, change its configuration, run game tests, or independently view the new native PNGs. The coordinator owns their direct visual review. Evidence paths below are coordinator-relative:

- `.artifacts/upgrades/com.dsschiff.hookandhunger/20261018T031739728048Z/manifest.json` records actual code3-to-code4 installation, migration and cold relaunch with all 24 checks passing, preserving complete `state`, `profile`, `settings` and `committed` paths. Code4 APK SHA-256 is `2391343d79096cf766f2e68daf7db19c84053aca489d0b3e29b2d9a834241c77`; manifest SHA-256 independently read here is `beb3857f26d5b702bed1cb9f26c6007ad95f5ad24909575ce0bd9e01af15aba4`.
- `.artifacts/emulator/com.dsschiff.hookandhunger/code4-native-platform-20261018T032626184418Z/manifest.json` records eight successful checks and the one unresolved keyboard check. These cover actual typed-invalid rejection, Export/clipboard/Paste/fresh Import, Back, Home/cold reload, emulated cover/inner resizing and original-size restoration, and absence of runtime errors. Recorded source SHA-256 is `b61b029a6c946a41b014b51332ac94e9503e5ba1fd4285e002c8a5f329fb7233`; manifest SHA-256 is `105eea4b995813a0f9be06c54d620d03eee45ab204d95fc56dc2eff0d8b936c5`; assertions SHA-256 is `6a0a65c6be0780d0ebae2752879eec4d8a0177055ae0a1abe6582e8db537434d`.
- Independent read-only comparison found the before/after invalid-import decoded files byte-identical, SHA-256 `95902ea04bc5cdabeb5948e9af866707e41fb18141d42e2d97786a308878129c`, both revision 573. Valid Paste/Import reaches revision 575 with exact decoded `state`, `profile`, `settings`, `committed` and `version` equality. Thus typing did not silently reimport the unchanged valid code as happened before the touch fix.
- The latest `code4-native-platform-20261018T033114199591Z/manifest.json` was also read: the same source, eight true checks, IME false, and the same manifest SHA-256 `105eea4b995813a0f9be06c54d620d03eee45ab204d95fc56dc2eff0d8b936c5`. The coordinator corrected the observer's menu swipe to start on the instruction label, then directly viewed the visible INVALID/rejection and restored-code/imported feedback PNGs. That is coordinator visual evidence, not this reviewer's independent viewing. Earlier partial and failed diagnostic namespaces remain retained.

### Why the missing IME does not currently justify another game patch

The exact installed engine commit `ed1daf0bf` contains a deterministic hardware-keyboard guard: [`GodotEditText.java:301-304`](https://github.com/godotengine/godot/blob/ed1daf0bf/platform/android/java/lib/src/main/java/org/godotengine/godot/input/GodotEditText.java#L301) returns from `showKeyboard()` when `hasHardwareKeyboard()` is true, before posting the native focus/show request. [`GodotInputHandler.java:118-120,182-186`](https://github.com/godotengine/godot/blob/ed1daf0bf/platform/android/java/lib/src/main/java/org/godotengine/godot/input/GodotInputHandler.java#L118) detects either a non-NOKEYS, non-hidden hardware keyboard configuration or an external alphabetic keyboard. Both exact-revision primary sources were read independently in this diagnostic.

The saved `code4-native-platform-20261018T031941728544Z/input-method-focused.txt` shows `qwerty/v/v`, a served Godot GL render view, null editor input connection and no keyboard-show request. The coordinator additionally confirmed the app activity's `qwerty/v/v` and an internal AT Translated Set 2 keyboard. Its internal/nonexternal status does not avoid the configuration branch of the guard. The coordinator's fresh-empty-field packet `code4-empty-field-ime-diagnostic-20261018T032522115359Z` excludes long export text as the sole cause. Godot control focus and hardware-style injected typing can still work while the engine suppresses the native editor connection.

This is strong source-backed evidence for the engine/emulator hardware-keyboard path, not proof from an instrumented branch trace. Android's `show_ime_with_hard_keyboard=1` cannot override a return before the Android show call. The coordinator reports `hw.keyboard=no` already in AVD configuration and false in running hardware configuration; therefore the earlier suggested simple toggle/reboot is withdrawn as unsupported for this VM. No VM surgery or speculative ScrollContainer/deferred-focus patch is required for conditional software-candidate progression.

### Required device follow-through

On a physical phone without a connected hardware keyboard, verify touch focus opens the on-screen keyboard, actual IME-entered text reaches the field, invalid Import preserves the whole save/revision, and Export/Paste/valid Import still commits correctly. Check keyboard dismissal and content reachability as well. If no show request occurs there with hardware detection false, reopen an actionable input defect. Retain the emulator IME failure and excluded encoding/logging attempts as evidence; do not relabel them passed. Native Unicode composition, physical folding/safe areas, FPS, audible sound, human duration/pacing and fun remain open. The known keyboard path needs verification, but does not require delaying independent work on other games.
