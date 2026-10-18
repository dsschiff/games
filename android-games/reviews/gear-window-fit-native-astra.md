# Gear Bastion 0.3.3 native sizing review — Astra

Disposition: **native-fit conditional candidate; no substantive blocker found for this small sizing APK.** This supplements the pinned source/desktop review in `gear-window-fit-astra.md`. It does not accept the planned 3D overhaul, physical Fold 7 behavior, or game quality/fun. Review was read-only CPU/files/images; no new rendering, ADB, browser, or device run occurred.

## Binding and evidence integrity

- Worker remains `45baca53cf6b422db98813a92a2be05198aa9f0b`; coordinator build commit is `33ab8d76eaa74f7a3439350d54cad0fc8511841e`.
- Independently hashed the actual signed debug APK in `.artifacts/gear-bastion/20261018T120200983836Z`: SHA-256 `9d090cb7dc1222c873109dae5adc1364dc07d910c7bed93545d773bf995ae472`, 57,272,268 bytes. Stored inspection shows package `com.dsschiff.gearbastion`, code 7 / 0.3.3, no permissions; stored signature log verifies v2/v3. This is a debug export, not a store release certification.
- Recomputed the 100-file RAW project fingerprint: `6056e5fce1104a60ed01d8ae8f7d46465d584b4c0c359e20ba0ffd219a81ada3`, identical to both build boundaries. Gear project status remains clean. Prior review established unchanged authoritative rules/save modules.
- All 42 native-report file byte counts and hashes independently match. All 79 archived native commands returned zero. Their sequence shows real input, read-only save extraction, display resizing and lifecycle actions; no save-state injection or data reset. The captured Godot/Android log has shader-cache recompilation warnings but no script, parse, or fatal exception evidence.

## Native behavior and persistence

Both primary and backup old-code-6 save slots are byte-identical immediately after code-7 installation and before first launch. The complete old primary and loaded `03` save have equal meaning after excluding only the top-level persistence revision. This comparison covers the entire object, including profile, settings, recoverable state and active run, rather than selected counters.

Native input is corroborated by precise save changes: guard moves from column 0 to 1 and changes gate from lane 0 to 1 (`03→06`); cover drag changes its row 2 to 3 (`06→08`); cover Undo restores the entire `06` meaning (`09`). Inner input adds drive ID 4, costs six brass, and changes guard lane 1 to 2 (`09→11`). Camp 01 refit correctly leaves the locked guard role unchanged. Real map input selects already-earned camp 02; the positive-refit snapshot and its backup prove guard ID 3 becomes ranger ID 3 for two additional brass (46→44, spent 12→14), preserving location, lane, level and earned profile. This is not a fixture-only refit claim.

The live battle reaches about 15 seconds, with 11 units and 19 enemies, before native Back pauses it. Independently compared the full `19` baseline with `21` inner, `23` cover, `26` after Home/force-stop/cold launch, and `28` settled inner saves. No semantic differences remain except top-level revision. Resize-only comparisons are numerically exact; cold-load comparisons contain eight fractional serialization differences, maximum absolute difference `5.684341886080802e-14`. These satisfy the existing fractional-float relative/absolute `1e-12` rule. Integer-valued fields were exact; tolerance did not mask counters, IDs, rewards or structure changes.

## Actual images and limits

Directly inspected native `02` loaded map, `10` inner preparation, `12` landscape menu, `20` rejected transition, `22` cover paused battle, and `27` settled inner paused battle. Loaded map/navigation, full board, flanking controls, battlefield and landscape modal fit their usable rectangles. The top dark reserved area remains visible; this evidence does not establish a physical phone's insets.

PNG headers independently establish `02` at 1080×2400, `10` and `27` at 1968×2184, `12` at 2184×1968, and `22` at 1080×2520. **Do not count `20` as a fit pass:** it is still 1080×2400, visibly distorted with black space on the right immediately after the resize command. The accepted settled inner evidence is `27`, captured later at the actual requested dimensions. This packet establishes eventual settled layout, not a quantified seamless resize latency. Likewise `01` and `24` are splash boundaries; loaded `02` and `25` provide the relevant map evidence.

The earlier safe-area/terminal fixtures remain useful layout fixtures, not native wins or losses. No new whole-campaign or physical gate is warranted for this bounded delta. The archived final commands restore display size, send Home and force-stop Gear without clearing saves. Candidate disposition is limited to the exact APK and source binding above.
