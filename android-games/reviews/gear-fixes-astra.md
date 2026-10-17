# Gear fixes and constrained-trial review

2026-10-17. GPT-6 Astra High reviewed worker `d13387b` (integrated as `a0e59d7`), source/tests and rendered captures/report. No reviewer execution, Android operation, commercial footage playback or phone testing. The initial static approval below is superseded by the confirmed recovery finding.

## Resolution: campaign gate cleared after narrow preservation fix

Worker `7d67a1e` / integrated `8ba1294` reuses matching validated staged bytes before promotion. Astra's narrow static re-review confirmed the fix and ten added preservation assertions. Coordinator's independent run `.artifacts/gear-bastion/20261017T215818617760Z/manifest.json` passed 107 rule and 51 actual-input checks against unchanged clean source `0ebee54a139c678488f0f4e6149994497b9dc541a5ba17996a6664c1198ced13`. This satisfies the conditional gate. Subsequent `034e7f3` / integrated `49bee21` updates build records only. Full campaign implementation is authorized; final release, Android latest-build and physical-device checks remain separate.

## Reopened finding and required fix (resolved above)

Coordinator ran an additional fault probe against the unchanged integrated source. With only `path + ".bak.tmp"` containing a valid revision8 save, initial recovery succeeds. Injecting a partial write failure on `.bak.tmp` during the next save returns failure and leaves no valid recovery copy. `save_store.gd:112–117` rewrites the sole known-good staged backup before protecting it.

Astra confirmed the defect and reopened the gate. Minimal fix: if `.bak.tmp` already exactly matches validated `previous.source`, reuse/promote it without rewriting. Otherwise use the existing checked-write path. Regressions must cover the sole valid staged backup with write failure, failure renaming it to `.bak`, and successful promotion followed by failed new-primary temporary write. Existing immutable build/evidence must remain intact. Campaign expansion may resume once this narrow preservation fix and regressions pass.

## Findings resolved in this checkpoint

The reviewed implementation checks write/flush/readback, ranks save revisions, marks failed import temporary files unaccepted, preserves in-memory state until import replacement succeeds, and surfaces persistent save failures. Powered-only dispatch and saved stable-ID round-robin allocation resolve the disconnection/starvation findings. Imports reject global duplicate actor IDs, wrong factions and invalid health bounds. Normal restoration, injected storage faults and actual input are labeled separately.

Iron Trial supplies two comparably funded differently composed wins (50/52 brass), connected single-role failures and a paid live correction while preserving the board/army composition. This supplies the missing prototype strategy witness. It does not establish broad campaign balance or fun.

## Coordinator seed probe

Fixed trial layouts were also run at seeds1700,1701,1702 using the same rules and costs. A loses1700/1702 and wins1701. B and the paid adaptive repair win all three; all-guard and all-ranger extremes lose all three. Raw script/report are ignored local evidence at `android-games/gear-bastion/.artifacts/coordinator_checks.gd` and `coordinator-checks.json` in the coordinating worktree.

Astra classifies A as seed-sensitive, not a robust alternative. These results do not reopen the prototype strategy gate, but later campaign encounters require nearby seed/timing and baseline-policy checks. Do not tune only these three seeds or require every reasonable layout to win every variant.

Other campaign cautions: the carapace's 96% guard-damage reduction is a hard counter to use sparingly; avoid compulsory role checklists. Current-wave guidance should explain the opening spitters rather than always display a carapace warning. Android/update, final fidelity, actual storage-fault durability and physical-phone acceptance remain separate.
