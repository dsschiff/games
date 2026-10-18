# Dead Run responsive camera checkpoint

**0.2.1 / code3**, `com.dsschiff.deadrun`, amends
`f9609eb8cf03b99a814ae09e6334b5762fbbeea4`.
Builder evidence is headless only. Root owns the new APK export, update and native
geometry checks; code3 is not yet a native-verified or physical-phone candidate.

The independently captured code2 inner display clips the formation and rescue
line. Its fully decoded 1968×2184 PNG is preserved at
`.artifacts/camera-code2-native-origin/inner-STOP-review.png`, SHA256
`4b551a803bc096cf2b7d2f7db0c5c5ae77afed44861df66c34b66d41bf21628b`.
The complete 1080×2400 native control is preserved alongside it, SHA256
`046714136e9055a7fa7534fcbf4e541a49aaa8d428e5a9a04445ffe99c438277`.
The origin receipt also binds root's associated state/transcript evidence.

## Camera correction

Campaign retains its authored 46° horizontal FOV and legacy 58°. Native 1080×2400
and cover 1080×2520 projection matrices are exactly unchanged. When the viewport
widens beyond the native aspect, the horizontal FOV expands to preserve native
vertical coverage, revealing more ambient scenery at the sides. Camera position,
orientation, viewport stretching, UI layout and touch handling stay unchanged.

```text
expansion = max(1, viewport_aspect / (1080 / 2400))
horizontal_fov = 2 * atan(tan(authored_horizontal_fov / 2) * expansion)
```

The shared helper runs immediately after camera creation/rebuild and during
layout/resize. Explicit authored-FOV methods prevent cumulative resize changes.
The real parked legacy child and standalone legacy scene share the correction.
Only `scripts/main.gd`, `scripts/campaign.gd` and the two version metadata files
change among the 28 runtime files. Rules, definitions, saves, art, input, pacing,
package, ABIs, permissions and signing/export route remain unchanged.

## Headless evidence

[CAMERA-CHECKPOINT.json](CAMERA-CHECKPOINT.json) binds exact raw/LF execution
sources, receipts, old/new sensitivity and 540 verified artifact rows.

| Check | Result |
| --- | --- |
| Real Camera3D/frustum/source geometry regression | 862 checks passed |
| Formation/footprint/line/near-threat envelopes | 108 complete envelopes |
| Native and cover envelopes compared with old source | 72 exactly identical |
| Same final test/runner against frozen old runtime | 180 inner margin/frustum failures, zero script errors |
| Fresh campaign/save/menu smoke | Passed |
| Actual code1 migration/input/import/cold smoke | 11 checks passed, 112 gameplay ticks |

The regression uses source scenes with actual Camera3D projection matrices,
`unproject_position`, `is_position_in_frustum`, mesh AABBs and the rescue caption's
real font AABB in its billboard basis. Render-target updates are disabled and all
processes use `--headless`. These are synthetic geometry fixtures, not screenshots
or earned gameplay claims.

It covers native, cover and 1968×2184 inner sizes; campaign crews 5/20 with all three
weapons; legacy crews 3/5/12; center and both reachable steering limits; full actor
parts/recruit rings at both bob extrema; the entire footprint and rescue line;
drifter/bulwark meshes near the line; and a near-road envelope spanning the playable
width, two metres high and six metres forward. Every group must remain inside
the real frustum with at least 1.5% side, 2% top and 10% bottom margins. Actual resize
signals, rebuilds, repeated layout calls and four native/inner/cover round trips
verify stable projection, camera pose and complete state preservation.

| Inner display | Old lowest projected bound | New lowest bound | Bottom margin |
| --- | ---: | ---: | ---: |
| Campaign | 122.20% of height | 86.06% | 13.94% |
| Legacy bridge and standalone | 108.41% | 79.17% | 20.83% |

At this aspect, horizontal FOV becomes 80.728° for campaign and 95.967° for legacy.
The native/cover controls remain 46°/58°. All migrated legacy body/settings fields
are exactly equal to the genuine revision384 fixture. Both bounded migration
contexts exactly match the previous source's smoke outcomes.

Original movies, campaign/validation checkpoint manifests and their source
bindings remain unchanged. This record does not repin old footage to code3.
The initial test parse failure, earlier regression drafts and complete final
old-source failure are retained. The final sensitivity is in
`.artifacts/camera-old-source-project/.artifacts/camera-final-old-camera-headless-20261018T104604315705Z/`.
README framing/version notes and these checkpoint documents were added after
capture; all current runtime/test/runner/UID bytes match the accepted raw/LF
execution manifests.

Reproduce from the assigned worktree:

```powershell
python android-games/dead-run/tests/run_desktop.py camera-headless
python android-games/dead-run/tests/run_desktop.py campaign-smoke
python android-games/dead-run/tests/run_desktop.py migration-headless
```

No builder Android/ADB/APK export, clipboard, rendered/GPU jobs, shared-record
edits, pushes or new agents/chats/goals/worktrees. Stop after the scoped clean
commit for root/Astra/new-APK checks. Physical Fold7, IME, audio, FPS and human fun
remain unverified.
