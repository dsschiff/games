# Reinforcement feedback increment — 2026-10-23

Unreleased source increment from `4552e7b`; no APK/export-version change. The current
catalog2 rules, full definitions, schema, career and legacy mode are unchanged.

The footer follows the last paid weapon's individual recruit: weapon ready,
arming, walking to the gate, through the gate, taking position, holding, or fallen.
Holding/fallen feedback reports actual saved damage. Station/threat hints explain
armor, range and splash counters; the recap sums actual crew damage and names the
highest contributing recruit. No kill credit or invented percentages are inferred.
The world-linked HQ integrity label clamps above touch controls when HQ is below
the usable field. HQ art remains outside commander movement bounds; this does not
claim the whole HQ model is always visible. Guidance and footer clear the stick
and equipment action across the tested profiles.

Save writes now read and validate the destination after a successful rename.
Missing/corrupt destinations report failure and leave the newest prior slot
readable. Tests inject both failures alongside existing write/rename/staging faults.

## Current-rule diagnosis

The corrected 60-route synthetic comparison uses untouched opening, active solo
threat/objective/collection play without purchases, two funded investment orders,
and rifle-only purchases followed by retreat. Untouched and rifle-retreat win only
tutorial Ash Gate (untouched: 15/15, HP120/HQ210/spent0). Active solo wins eight
missions and fails Drill, Carrier, Red Causeway and Liberation (4/8/9/12). Both
funded orders win all12. This is evidence of meaningful equipment on the tested
campaign path, not proof that equipment is required in every mission or optimal
human play. The tutorial remains generous; no global balance change was made.

The first exploratory solo controller was flawed: it chased purchase destinations
while purchases were disabled. Its reported 11 later losses are superseded by the
corrected8/12 solo result. The corrected controller is in `tests/policy.gd` and the
repeatable comparison in `tests/decision_probe.gd`.

## Verification

Exact source-bound receipts and SHA256 values are in
[REINFORCEMENT_CHECKPOINT.json](REINFORCEMENT_CHECKPOINT.json).

- Rules/storage:416 checks, zero failures; full arc2220.5 simulated seconds.
- CPU presentation:109 checks, zero failures; full-state equality for2400 first/
  final district ticks and900 legacy ticks against the original fixture.
- Synthetic decisions:60 policy routes, expected outcomes and valid states.
- Actual engine input:276 checks, zero failures,177 touch taps; twelve natural
  wins, late alternate investment order, rifle-only defeat, Retry recovery,
  seeded replay and save reliability.8x time,2220.62 simulated arc seconds.
- Cold restart:16 checks, whole earned progress/settings retained.
- Focused renderer:47 checks, zero failures, Dummy audio. Actual touch purchase,
  arming/deployment/earned damage; actual commander travel to opposite extremes
  and base at720x1680 cover,1153x1280 inner and2276x1280 landscape logical sizes.
  Raw inputs, app states and14 PNGs remain in its isolated artifact directory.
  Before-change GUI route also passes in `.artifacts/feedback-comparison/before`.

The initial focused after route had five clamp/guidance overlap failures. A later
visual pass caught an advice/joystick edge overlap; the final route explicitly
checks HQ/guidance/footer rectangles against both controls. Two earlier complete
input runs passed all functional checks but fail their source-binding receipts
because test/layout files changed during those runs; they are retained separately.
Only the `frontline-frozen-*` input receipt is claimed as the final bound pass.
A direct presentation attempt also failed for a missing baseline fixture; the
proper runner then passed. No failure is replaced by a later success.

Reproduce with Dummy audio already set in the runners:

```powershell
python android-games/frontline-foundry/tests/run_campaign.py rules --label review
python android-games/frontline-foundry/tests/run_campaign.py decisions --label review
python android-games/frontline-foundry/tests/run_campaign.py input --label review
python android-games/frontline-foundry/tests/run_graphics.py checks --label review
python android-games/frontline-foundry/tests/run_feedback.py --headless
# After the coordinator grants a serialized renderer slot:
python android-games/frontline-foundry/tests/run_feedback.py
python android-games/frontline-foundry/tests/run_feedback.py --before
```

Root owns independent review, integration, Android/native update, and any release.
No ADB, browser, clipboard, audible audio, public publication or paid service was
used. No human fun/pacing, phone touch/folding, measured phone FPS or Android
update result is established here. All renderer processes exited and the slot was
returned. Necessary bound evidence stays for coordinator review; the disposable HQ
probe was removed. Follow-up: inspect recap at phone scale and observe actual
recruit purchases during the next native candidate run.
