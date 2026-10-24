# Hearthguard row-body touch scrolling

Base: `99c74cc5de41fbcc6fd5a5722e906d75de9676ec`. This is a CPU/headless input correction, not native Android acceptance.

## Reproduced boundary and change

The existing Journey column overflows by 768 pixels. On a 720×1280 viewport, recovery overflows by 24 pixels with summaries and by 256 pixels with View code open. Actual dispatched ScreenTouch/ScreenDrag input on their STOP buttons did not move the scroll position, while wheel events did. The retained initial packet is `.artifacts/touch-scroll-baseline-20261024T161650719863Z`: **24 checks, 3 failures**. All full-context and saved-byte preservation checks in that packet passed.

The correction changes only those two columns' Button filters to PASS. It leaves their signals, actions, hit rectangles, layout and default button factory unchanged. Journey's fixed seed/budget/mirror/Close controls keep STOP. No Store, decoder, catalog, rules, save schema, version, export, recovery transaction or clipboard protocol change is included. Reverse removal of the three inserted ASCII lines reconstructs the pre-edit raw runtime hashes and base Git bytes after newline normalization; existing UTF-8 punctuation is untouched.

## Focused evidence

Run from the repository root:

```powershell
python android-games/hearthguard/tests/run_touch_scroll.py
```

The runner uses the existing source-matching cache, pinned Godot 4.7.2, `--headless --audio-driver Dummy --fixed-fps 60`, fresh isolated environment directories created with `parents=True`, and source-before/after pins. It never imports, renders or calls an OS clipboard API. The new test UID was allocated directly with Godot, without an editor import; its allocation script and strict-clean log are retained.

Final packet: `.artifacts/touch-scroll-current-20261024T162534031686Z`: **334/0**, **1,280 dispatched input events**, **20 observed button activations**, exit 0, no ERROR/WARNING/ObjectDB messages, exact source-before/after equality.

At 720×1280, 720×1680, 1153×1280 and 2276×1280, the test dispatches real engine GUI input through a normal production bootstrap/owner, with an injected in-memory owning Store backend and complete rule-derived synthetic contexts. It does not invoke button handlers or assign scroll positions. It covers row-body scrolling, enabled drag returning inside the original moving row, CANCEL and canceled drag-return, disabled stationary tap and drag, enabled stationary selection exactly once, existing Keep Watch confirmation cancellation, last-row reachability, Journey Close/Back, exact readonly Previous/Imported View, and pending Back remaining blocked. Actual Retry/Keep each dispatch once through the owning Store under a retained write failure. The full state/profile/settings/campaign including parked contexts, option values, pause/pending status, private journal record, original/imported strings and every raw backend path/byte remain exact across the applicable read-only or failed-choice boundaries. Selection may set the existing temporary replacement definition but never resets or saves the watch; Keep Watch clears that definition as before.

Journey moves 0→340 in the measured swipe on every profile, emitting one scroll-start signal. Short recovery moves 0→24 and 0→256 respectively. At 720×1680 recovery fits: zero overflow and no scroll-defect assertion. Wheel is an independent positive control. Input emulation properties are explicitly restored before exit; this remains process-local synthetic touchscreen capability, not hardware emulation or native proof.

All earlier packets remain retained: initial fixed **24/0** (`161906294556Z`); expanded **262/4** (`162216246437Z`), whose four reachability failures began navigation while prior kinetic scrolling was still settling; corrected **294/0** (`162319328427Z`); UID-frozen **294/0** (`162436259599Z`). The test now lets admitted inertia settle for 60 physics ticks before navigation, rather than directly changing a scroll offset. The runtime did not change during that test correction. Earlier maps bind their historical harness versions, not the final expanded test. No failed packet has been replaced.

## Limits and next gate

These are synthetic complete saved contexts and in-memory fault-backend bytes. They are neither newly earned play nor physical-file cold starts, OS-kill/power-loss tests, rendered glyph/layout review, OS clipboard tests, human fun acceptance or Android touch acceptance. Root's next native check should swipe Journey and both recovery shapes, end a drag inside an enabled original row, CANCEL, stationary-tap once, Close/Back and compare full retained data. No broad recovery/rules suite is repeated for this three-line input-propagation change.
