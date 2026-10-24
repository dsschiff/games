# Confirmed save destination

A rename result alone previously let Hook report a committed save when the
intended stable destination was missing, torn or a stale but valid envelope.
The actual Import handler then replaced live state/profile/settings and said
"Imported", although a normal disk reload restored the prior context. The
fault matrix reproduced 63 failures in 444 checks before the writer fix.

Store.write now returns success only after the destination exists, its readback
matches the exact staged text, and the existing decoder accepts it. The newest
old stable slot or recoverable committed temporary remains untouched. Import
already uses uncommitted staging, so an unsuccessful rename cannot become an
active import on reload; no staging/schema/migration redesign was necessary.

The controller has a default-null save_io seam passed to its existing read,
import and autosave Store calls. Production still selects save_files.gd through
Store's existing null default. Fault tests use this seam to click the actual
Import button and invoke its owning handler with the real Store, instead of
reimplementing adoption logic in a fake importer.

The labelled rule-derived fixtures cover legacy, campaign and arena contexts,
including nonempty campaign medals/records, settings, arena scores and a complete
parked campaign ending. Across all nine source→incoming pairs, failed writes,
failed renames, missing destinations, corrupt destinations and stale-valid
wrong destinations preserve every active/profile/settings field, avoid world
rebuild and report storage failure. The newest old slot stays byte-exact.
Successful imports restore exact whole meaning and expected destination bytes.
Normal writes additionally protect both newest stable and recovered-temp slots.

The final save matrix passes 444/0; legacy rules 57, campaign 81, malformed import 8
and heavy-save review 31 pass with unchanged source during the batch. Exact
receipts and runtime source identities are in SAVE_COMMIT_AMENDMENT.json.

Disk checks materialize each fault backend's files and instantiate the normal
production scene without an injected backend. These reloads occur in the same
headless engine process. They do not prove process-kill, physical disk power-loss
or Android restart behavior. All execution used headless/Dummy audio, with no
renderer, GPU, OS clipboard, ADB, browser, version bump or export.

Only main.gd's default-null IO seam and save_store.gd's postrename confirmation
change runtime source. Decoder, envelopes, save schemas, combat rules, catalog,
existing charge adapter and original art are unchanged. The combat movies remain
bound to their earlier exact source; this later storage-only fix requires root's
combined-candidate decision/rebuild before publication. Native update/recovery
acceptance remains separate. No old failure receipt was relabelled successful.

The final broader batch passes opening input18, resize/input108, contact37 and
presentation214, with unchanged source during execution. Its preceding batch
remains failed: the fresh-opening contact probe inherited graphics_input's saved
context, then accessed a missing target after its launch assertion failed. Only
that verified stalled headless child was stopped. The contact probe now clears
its isolated save slots before loading its fresh opening; production gameplay
and the captured charge adapter are unaffected. No historical failure was erased.
