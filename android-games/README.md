# Personal Android games

Six standalone offline Godot games have software candidates ready for phone testing. The staged goal in the repository root remains open for physical and human acceptance. Reference briefs govern each implementation; commercial titles are design references.

| Directory | Working original title | Reference | Current state |
| --- | --- | --- | --- |
| `gear-bastion` | Gear Bastion | Gear Defenders | Software candidate ready for phone testing; independent campaign/replay, source review and Android update/natural outcomes verified |
| `tower-trials` | Tower Trials | Hero Wars | Software candidate ready for phone testing; authored/generated campaign, save updates and corrected native Back/clipboard/resize checks verified |
| `hook-and-hunger` | Hook and Hunger | Butcher Hero | Conditional software candidate ready for phone testing; update/native transfer verified; phone IME gate explicit |
| `hearthguard` | Hearthguard | Kingshot | Conditional code2 software candidate ready for phone testing; full campaign reviewed, native update/outcomes/transfer/lifecycle verified |
| `frontline-foundry` | Frontline Foundry | Top Force | Conditional code2 software candidate ready for phone testing; twelve-mission campaign reviewed, native update/outcomes/transfer/Back/lifecycle verified |
| `dead-run` | Dead Run | Last Human: Final Stand | Conditional code3 software candidate ready for phone testing; 24-road campaign, native outcomes/platform, corrected unfolded framing and whole-save update verified |

Each app is offline and has independent saves. APKs and signing materials are local artifacts, excluded from Git. The existing public website is not changed by these builds.

See [local builds](delivery.json) and [installation and phone checks](INSTALL.md) for all six current phone-test candidates.

The working phone target is Galaxy Z Fold7, based on Daniel's description. Exact device identity, Android version and physical performance remain unconfirmed. See [device targets](device-target.json), [current milestones](../ROADMAP.md) and [verification records](evidence/).


The six APKs are collected in the private local folder recorded by `local_bundle`
in `delivery.json`. Its index, installation guide, manifest and checksums travel
with the APKs. No store or website release is included.
