# Explicit Android save namespace migration review

Astra narrowly reviewed the `a1dffcd` change to `scripts/android_upgrade.py` and its regression tests. **Static approval: no consequential defect found.** Root independently passed all52tooling tests and separately inspected the real upgrade packet.

The new `--preserve-map OLD=NEW` declares renamed paths without guessing or normalizing saves. Identity `--preserve-path` remains supported. Installer retention compares old→old paths; new-app migration compares old→mapped new paths; cold relaunch compares new→new; final retention compares old→mapped new. Missing paths fail. Empty, malformed and duplicate/conflicting mappings are rejected; repeated identical identity paths are intentionally deduplicated.

Numeric semantics are unchanged: integers/integer-valued numbers and booleans stay strict, fractional round-trip tolerance remains1e-12 and nonfinite values fail. The meaningful regressions reject missing actor paths, actor resets, ambiguous mappings, type/numeric changes and cold-relaunch resets.

For Gear core, `state=active_run` plus unchanged `settings` preserves all25old gameplay-state keys while allowing new fields. Separate exact schema4/fresh-profile expectations ensure no invented campaign clears. Actual increasing signed offline code3→4 APK migration passed24checks; root checked raw saved JSON, all preserved state, archive hashes, actual new-save modification times and absence of data clear across the update boundary. See [the evidence record](../evidence/gear-upgrade-0.2.1-0.3.json).

The static review itself did not execute APKs. Actual migration evidence does not certify changed campaign art, final Android campaign playthrough, fault durability, fun or physical-phone performance.
