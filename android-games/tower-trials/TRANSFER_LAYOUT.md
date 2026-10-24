# Tower transfer-note spacing

The status beneath the transfer Return button now derives its first baseline from Return's bottom edge plus the actual font ascent and an eight-pixel gap. Only this note uses normal font-height row spacing. The optional final lines() parameter preserves size+5 for every existing caller. Width516, font19, maximum three lines, all four transfer hit rectangles and their actions are unchanged. Store, codec, rules, schema, catalog, saves, version and export settings are unchanged. The existing unconditional normal Copy success message is a separate unresolved clipboard-protocol limitation; this increment only fixes its placement.

The retained isolated baseline measured font19 ascent21 and height27. Baseline893 put the first note font cell at y872..899 across Return804..884. The corrected baseline is913, so the first cell starts at892, eight pixels below Return. Transfer-only27px steps keep three complete font cells in y892..973, inside the1066px logical canvas. This is conservative font-metric nonintersection, not proof of actual glyph-pixel readability.

The existing layout_probe suite now observes the actual production transfer lines() call, delegates its arguments unchanged, and measures the emitted text_at baselines with the same live font. It checks one-, two- and three-line production-wrapped notes at cover344x642, inner690x829 and wide1066x600. Actual ScreenTouch opens the real menu/transfer panel and activates unchanged Return. Full validated synthetic campaign and active-challenge fixtures include pinned catalog2 campaign actions/Undo, profile/settings, a pinned challenge snapshot/actions/Undo/record and parked campaign. Repeated drawing and geometry queries retain complete data/state plus all four opaque raw save slots byte-exact; no clipboard action is invoked. Earlier room/Retry/Undo/map/resize checks remain in the same suite.

Final CPU/Dummy packets:

- `.artifacts/transfer-layout-final-utf8-20261024T101158008851Z`:235/0,17 actual touch taps, strict clean, raw source before/after unchanged.
- `.artifacts/transfer-layout-final-medals-20261024T101159121026Z`: existing medal/input regression793/0,163 taps, strict clean, same final source.
- `.artifacts/transfer-layout-import-20261024T100512221383Z`: the sole authorized editor import passed with all tracked raw source unchanged. No substitute cache or assets used; no new UIDs generated.

All earlier reports are retained and qualified. The first289/108 baseline observer mistakenly included underlying result text; isolation corrected that before the235/72 baseline (54 Return-clearance failures plus18 font-cell-separation failures). The211/54 scoped baseline and211/0 first fix checked only Return clearance, so the211/0 packet is partial, not final multiline acceptance. Parent requested retaining note-local separation; the final implementation restores that check. The initial separated235/0 packet passed despite unrelated UTF8 punctuation damage caused by my Windows default text decoder. The relevant medal regression exposed that mistake as793/8. A byte-exact base main comparison passed793/0. The final candidate was reconstructed bytewise from base with only intended ASCII edits; both final235/0 and793/0 pass, and the unrelated text is unchanged. No preexisting medal defect is claimed.

`TRANSFER_LAYOUT.json` binds the source, unchanged base files, raw reports and this note. The ignored source-bound runner is retained with the evidence for exact reproducibility. Direct equivalent (set isolated APPDATA/LOCALAPPDATA/TEMP/TMP and a fresh capture directory):

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --fixed-fps 60 --path android-games/tower-trials --script res://tests/layout_probe.gd -- --capture-dir=<isolated-evidence-folder>
```

The exact executed argument vectors and isolated environment paths are in each report. No renderer, Android/OS clipboard, emulator, native build, upload or publication was used. Root owns the native candidate recheck, actual glyph/readability assessment and human acceptance. No broader readability or clipboard-success claim is implied.
