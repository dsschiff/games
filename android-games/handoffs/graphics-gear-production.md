# Gear Bastion graphics production handoff

The original stylized 3D overhaul is complete as a conditional software candidate.
Physical-phone testing remains deferred. Daniel's earlier successful phone install
was user-reported with an unknown version; it is not evidence for this APK.

Final worker `9ccf4a7a878e291afdf1750338e6e26cd6b96ba7`, integrated as
`7eb9e0419f6ae79533719b0c2e21d5907715db00`. Retained clean worktree:
`C:/projects/active/_worktrees/games-gear-bastion-20261017`, branch
`codex/gear-graphics`. Graphics thread `01a14ecf-ca7d-7ff1-a858-ca1aa9682d76`
can be archived after this handoff lands; keep source, private raw evidence and
the original functional branch. Do not archive/delete the worktree or artifacts.

## Candidate and delivery

- Version **0.4.0 / Android code8**, package `com.dsschiff.gearbastion`.
- APK SHA256 `4e68eb6395bd13ea46b56b0cf25e332144cf49ce66c552527c67bfad07216ad1`,
  60,736,214bytes. Signature verified, no requested permissions/network access.
- Stable clean build source SHA256
  `a6eef6ddb182e92294b5cae3af607e5815cc59373dbd562b1dd9206dcb8a2e67`.
- Private APK/build: `C:/projects/active/games/.artifacts/gear-bastion/20261018T173328584413Z/`.
- Private bundle: `C:/projects/active/games/.artifacts/releases/gear-bastion-0.4.0-graphics/`.
  Includes APK, install notes/checksums, unchanged before/native-after/dense-boss
  clips, unfolded/landscape images, build/native records and independent reviews.
  Simple responsive page is prepared; browser page QA was not run while Hearth
  owns the renderer. All three movies fully decode and file/media links verify.
- Final bundle manifest SHA256
  `e21414e9411b02d8cb42998ab209b9da691bd33a2be966df80d67197174c2d5a`.

## What changed and why it is accepted

28 reproducible original modeled assets, including12 skinned character roles,
dimensional gears/sockets/conduits/board and distinct regional scenery. Movement,
weapon/contact poses, attacks, hits, falls and effects are driven by presentation
events while rules/RNG/economy/progression/saves remain authoritative and unchanged.
The prior sizing correction expands the useful field and places controls beside
the board in wide windows. No ads, purchases, accounts, servers or artificial waits.

Actual actor/effect node reserves are bounded and fully reset, including rigs,
materials, health, contact and epoch/ID ownership. Dense captain/siege fights now
use a localized screen-space cutaway and temporarily suppress only crossing
friendly health bars. Bodies, equipment and ordinary falls remain readable while
logical positions and all authored geometry remain unchanged. Per-viewport shader
caches release with their owner; other live viewports remain intact.

Independent full opening/heavy/later/reset/restore/legacy review plus pooled
reuse/carapace and corrected captain/siege films support all8 quality areas at3/4.
Do not retroactively pass earlier rejected films. Final source teardown delta is
reviewed additively and does not change the active visual loop. Coordinator
repeated468 pool/reset,1098 occlusion and12 actual cache-lifecycle checks unchanged.
Earlier12071 presentation/1462 input and637 boss-layout checks remain retained.
Unpaced host timing is explicitly render-loop submission timing, not phone/GPU
presentation FPS, controlled speedup or fun acceptance.

## Actual Android evidence and its limits

Signed7-to8 update preserves both genuine slots byte-for-byte before first launch;
actual installed APK bytes independently match the final build. Native controls
move ranger3 from cell1,2 to0,2 then Undo; landscape exits1-to0-to1; whole packet
otherwise matches exactly. Native Resume advances actual combat15-to21.2seconds,
then Back pauses. Copy, real invalid typing/rejection, Paste and Import use the
Android clipboard. Import's recoverable=false transaction flag is explicitly
qualified; ordinary later saves restore true with whole saved meaning retained.

Cover1080x2520, inner1968x2184, native1080x2400 and landscape2184x1968 are directly
captured. Cold portrait restoration is visible at26; warm inner restoration at31.
Image32 is a Godot splash and **only** its accompanying raw save comparison proves
disk retention, not loaded wide cold UI. Initial black startup images are rejected.
A premature Home snapshot27 caused a retained failed comparison; corrected Home
boundary29/30 is byte-identical across two reads, then31 warm/32 cold disk/33 stopped
retain complete meaning. Twenty comparisons pass; the premature witness stays failed.
Identical revision ties are accepted only when raw slot bytes are identical;
conflicting ties still reject. Fractional serialization tolerance is1e-12 only.

Native screenrecord is the unchanged actual variable-rate original. Its packet PTS
strictly increase and it fully decodes with the original demux timebase; default
null encoder DTS-rounding warnings remain preserved. It is not measured phone FPS.
No new whole native campaign, physical Fold7, IME, sound, heat/battery, human pacing
or fun acceptance is asserted. Emulator left at native1080x2400; Gear is stopped,
latest genuine campaign save retained at21.733333seconds, revisions1268/1267.

Authoritative tracked indexes:
`evidence/gear-3d-production-candidate.json`, `evidence/gear-graphics-native.json`.
Reviews: `gear-production-final-astra.md`, `gear-pooling-role-closure-astra.md`,
`gear-boss-visibility-closure-astra.md`, `gear-graphics-native-astra.md`.
Private preserved inspection/closure/review/build receipts are linked from indexes.

After archive, reuse this builder slot for the queued bounded Frontline pooling
0.3.1/code4 follow-up, then Hook graphics. Hearth continues its serialized production
batch. Dead Run and Tower still require their complete graphics overhauls; the
six-game root goal remains active.
