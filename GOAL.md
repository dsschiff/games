# Six personal Android games

Build six complete offline Android games in this existing repository, inspired by Gear Defenders, Butcher Hero, Top Force, Kingshot, Last Human: Final Stand (with Last Z as a comparison), and Hero Wars. Deliver the selected ads' sustained mechanics, camera, pacing and visual character using original assets, or preserve core gameplay when ads accurately represent it.

Each standalone game needs meaningful progression, a complete initial arc targeting 30-60 minutes without padding, replay value, onboarding, sound/reduced-effects settings, win/loss/retry, versioned saves and export/import. No ads, purchases, compulsory accounts, custom account servers, energy restrictions, or monetization-driven waiting. Optional Google Play Games cloud saving is approved; gameplay and immediate local saving remain offline-capable. Existing website and repository visibility remain unchanged.

Daniel specified a Samsung Fold7 on 2026-10-17 and authorized all work within this plan. Use Galaxy Z Fold7 as the working device target, confirming exact model/Android version from the connected physical device. Cover and unfolded displays, safe areas and state-preserving resize/fold transitions are required checks; profiles are recorded in `android-games/device-target.json`. This authorization includes task coordination, setup, builds and validation; retain the plan's separate public-release and paid-service boundaries.

## Stages

1. Select representative creatives, preserve source URLs and observed mechanics, compare sustained core gameplay, and obtain Astra review of each brief.
2. Pin Godot/GDScript and Android tooling; prove representative 2D placement and 3D combat APKs, touch/lifecycle/saving, emulator behavior and eventual physical-phone performance.
3. Complete the Gear Defenders-inspired game end to end before expanding production.
4. Build Hero Wars, Butcher Hero, Kingshot, Top Force and Last Human-inspired games with at most two builders concurrently. Keep independent work moving while phone feedback waits.
5. Review all six, resolve findings, preserve saves across APK updates, and deliver a private/local APK index with installation instructions, controls, release notes, reference comparisons and known issues.

## Completion evidence

For every game: recorded reference comparison; consequential rule/progression/save tests; actual input-driven victory, defeat, retry and later progression; offline Android launch; background/resume and interrupted-save recovery; export/import; update compatibility; readable touch UI; independent Astra release review. Target 60 fps with heavy encounters above 30 fps on the measured phone. A target is not a measured result.

Track implemented, automatically verified, ready for phone testing, and phone tested separately. The root goal remains unfinished until all six release candidates meet their checks and required physical-phone testing is finished. If physical access or feedback becomes the only dependency, deliver verified artifacts and report outstanding checks honestly.

## Work policy

One active coordinating goal; durable milestone records instead of nested goals. Introduce one persistent development chat per game as its work begins. Sol builds; Astra reviews architecture, reference interpretation, difficult defects and release evidence. Each builder has an isolated worktree and exclusive game-directory ownership; the coordinator owns integration/shared tooling. Every iteration advances a named milestone and records changes, actual checks, artifacts, blockers and next action. No public release, paid assets or services. Daniel-only Play internal testing is approved once account setup permits it.



## Approved graphics stage, 2026-10-18

Daniel rejected the current presentation quality and chose stylized3D for all six
games using his Top Force screenshot as the standard. Implement
`android-games/GRAPHICS-OVERHAUL.md`: archive six old game chats after durable
handoffs, establish Frontline's playable benchmark while fixing Gear's window
fill, then complete all six graphical overhauls. Gear installation/play on his
phone is user-reported, with unknown installed version. Further phone testing is
explicitly deferred and does not block graphics development or delivery of
graphics-reviewed/emulator-validated candidates. Physical/human acceptance stays
unverified where not established; the functional baseline is preserved.


## Approved continuous design cycle, 2026-10-23

Daniel approved implementation of `android-games/DESIGN-CYCLE.md`. This is the
active development direction after the graphics stage. First improve Dead Run
and Frontline Foundry, then Gear Bastion, Hearthguard, Hook and Hunger, and Tower
Trials. Planetfall keeps its separate charter. Strengthen player agency, feedback,
pacing, meaningful progression, original 3D presentation and reliable save-compatible
Android delivery rather than maximizing content counts. Existing reviews and failures
remain historical evidence; current source and exact builds decide current status.

Optional Google Play Games authentication/cloud recovery is approved with offline
play retained. Existing saves, app identities and signing continuity are mandatory.
The first cycle ends only when all six have a verified design-and-polish release
and optional cloud recovery is verified. If external setup prevents cloud
verification, record the exact dependency separately and leave that milestone
and the overall goal open while continuing independent work. Never claim
cloud/device/human acceptance from mocks, headless checks or emulator alone.

Continue small verified increments around blocked work. Phone testing remains
deferred without blocking software development. Keep automated testing silent.
The coordinator owns shared code, integration, exports and serialized runtime work;
at most two game builders and one independent reviewer work concurrently.
