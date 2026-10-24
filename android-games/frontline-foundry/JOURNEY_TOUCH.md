# Journey row touch propagation fix

From `833ac3fc0ce87442193ddfe0b4e1f2c46b39c3a6`, the shipping runtime delta
is exactly one added line: Journey mission buttons use MOUSE_FILTER_PASS.
No Store/decoder/rule/catalog/schema/save/version/export change, new gesture
handler, direct scroll assignment, control rectangle, font or label change.
Rows retain the same pressed callback, disabled flag and button-release action.

## Reproduced boundary and diagnosis

Root's actual Android0.3.6/code10 Journey showed four rows. Three ADB row-body
swipes did not move the list: first540,1500→540,750 over700ms, then two
700,1250→700,740 swipes over650ms. Narrow-scrollbar thumb drag
could reach mission12. These are root-observed native failures/successes, bound
by reference below, not new Android execution by this builder. Previous desktop
wheel capture was valid but did not test native row-body dragging.

Pinned Godot4.7.2 engine source explains the distinction:

- [Viewport1632–1635](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/main/viewport.cpp#L1632-L1635)
  stops pointer propagation at STOP controls; wheel events have a separate pass
  exception. Journey row buttons inherited STOP, including disabled future rows.
- [ScrollContainer219–280](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/gui/scroll_container.cpp#L219-L280)
  implements touchscreen drag through mouse emulation, a deadzone and normal
  scroll notifications. Passing row events upward lets that implementation run.
- [BaseButton169–176](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/gui/base_button.cpp#L169-L176)
  cancels a pending button press when scrolling begins. No replacement selection
  or cancellation code is introduced here.

## Focused proof

The failed CPU baseline **25/3** materializes the exact15 native retained files
through their capture manifest and owning Store/production Boot. Three actual
ScreenTouch/ScreenDrag swipes yield offset0, no scroll_started and no reachable
last mission. The complete live context and all15 raw files still match.

Final packet `journey-touch-current-20261024T153019566382Z`: **172/0**, strict
clean logs and exact source-before/after/current equality. The same production
path is exercised at720x1680,1153x1280 and2276x1280. The first three swipes reach
offset776 and mission12. Actual reverse swipes return to the top; the normal
wheel path remains a positive control. Disabled tap, canceled enabled contact,
and an enabled-row drag returning inside its original button emit no selection
and preserve exact full context/raw files. A stationary enabled tap emits exactly
one row activation and selects the requested mission with existing reset/save
semantics. Actual Close and Back remain effective.

All state/profile/settings/career fields and13 immutable archived codes remain
included. Readonly GUI segments preserve exact live dictionaries plus every raw
file/path. Existing Pause navigation and explicit selection/startup writes are
admitted separately. Immediate owning-Store readback and a fresh shipping owner
preserve the complete selected context, normalized on BOTH sides via owning
Store.encode/decode at export revision0, without epsilon or omitted fields.
Direct binary float representation need not equal its JSON-roundtripped form.

Headless has no real touchscreen. The harness enables only test-process
Input.emulate_touch_from_mouse, which the pinned
[DisplayServer515–516](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/display/display_server.cpp#L515-L516)
uses for its touchscreen-availability gate. Production mouse-from-touch remains
unchanged; real engine GUI dispatch, emulated mouse events, ScrollContainer and
button cancellation execute. No scroller property or game-selection handler is
called directly. The setting is not written to project or user preferences.
This is meaningful engine-path regression, not Android driver/native acceptance.
Root must build/install the candidate and repeat the actual native gestures.

## Retained failed attempts and scope

Post-fix36/6 and39/1 packets are retained: my test assumed Close kept the Pause
menu visible in a ready-phase save, assumed reopening reset scroll offset, then
attempted an offscreen row after legitimate inertia. Those assumptions were
corrected with actual Pause/reverse swipes, not product changes. Expanded169/3
retains the incorrect direct-float readback expectation; owning normalization
corrected it. A signal-observer lambda parse-error packet also remains. Earlier
passing40/0,169/0 and172/0 packets predate only later test instrumentation;
current172/0 is the final source-bound gate. Passive observers connect once on
reopen, count zero drag/cancel activations and one stationary-tap activation.

One new test UID was allocated headless/Dummy without editor import. Existing
source-matched imported assets were reused; no renderer/GPU/emulator/ADB/browser/
clipboard/build/export/upload was run by this builder. No broad recovery/rule
suite was duplicated: complete unchanged base bindings are in the checkpoint.
Native touch, pixels, device performance/audio and human acceptance remain open.
