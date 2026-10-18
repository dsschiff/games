# Hook and Hunger

An original offline portrait 3D salvage-diver game, built with pinned Godot 4.7.2/GDScript. Software candidate 0.2.1/code3: opening purchase cycle, four islands/twelve campaign passages, four distinct beacon bosses, six enemy roles, three power purchases, a conclusive harbor ending and seeded arena replay. No third-party assets, ads, accounts, services, purchases or requested network permission.

The full code2 Astra review clears the visual direction and identified two save-validation P2s. Code3 corrects the heavy arena refit's post-strike cooldown bound and rejects exhausted-current-wave imports that cannot advance. New regressions reproduce both old failures and verify immediate saving/lifecycle handling plus whole-state/profile/settings retention on GUI import rejection. See `REVIEW_AMENDMENT.md` and `evidence/review-amendment-code3.json`. Code2's original packet is retained unchanged; code3 requests independent amendment recheck and the coordinator's real APK update/Android acceptance.

## Play

Drag the floating stick to move; mouse drag or WASD also work on desktop. The chained weapon launches at the nearest visible creature within its reach circle. Damage occurs at contact, and moving out of reach can miss. Gold crystals are salvage; walk through them. Wave clears sweep the remaining earned drops and repair 15 hull. The safe dock offers immediate free repair, or a priced stronger weapon with full recovery. Neither side can attack across the sanctuary boundary.

Solid red circles: leave before the hit. Hollow rings: step inside the small safe circle or outside the large circle. Red lines: sidestep. Rocks stop chain attacks and projectiles. Shield fronts block damage: walk to a flank while their facing is committed. Violet tenders heal other living creatures; approach them first. Chargers commit to a line, then expose a recovery window. Warden, Kiln, twin lanterns and Crown combine different attack patterns rather than only larger health totals.

The opening forge costs 36 of 42 guaranteed salvage and buys the Tidecutter: power 100→200, damage 12→32, reach 2.5→3.6 and cleave. Cinder's 120 forge adds the Furnace Flail: power 300, damage 58, wider cleave, shorter reach/slower recovery. Lantern's 240 forge adds the larger purple Storm Chain: power 400, damage 78, reach 3.85 and faster recovery. Prices are one-time debits. Power gates block movement and combat until the required purchase. Every gate's starting checkpoint can afford it without farming.

Retry restores full hull at the dock and resets surviving enemies. Weapon ownership, wallet, defeated IDs, collected rewards, drops and cleared waves remain earned; fixed enemies cannot be farmed twice. Settings, progress, replay scores and local save codes work offline. Pause contains sound/reduced effects and export/import; copy the selected export field to retain a private backup. Settings scroll when needed. Controls have at least 100 logical pixel hit height/width, equivalent to 50dp under the 720 logical/360dp cover assumption. Actual phone safe areas and touch are separate checks.

After the ending, Harbor/Replay opens seeded arenas. Refitted Tidecutter, Furnace and Storm all display power 400 and face identical enemies at the same seed: long reach versus heavy cleave/slow recovery versus faster balanced strikes. Scores retain time, hits and recoveries separately for each seed/loadout. Arena rewards cannot inflate campaign salvage; returning restores the exact earned campaign ending.

## Source and saves

`scripts/rules.gd` retains shipped schema 1 definitions and combat behavior, including its exact roster/rewards/weapon values; only the reviewed per-pen import validation was tightened. `engine.gd` dispatches schema 1 saves to these pinned rules. Schema 2 campaign states carry an immutable definition 1 snapshot: roster, geometry, weapons, costs, seed and wave assignments. Future rebalancing must introduce a new definition version rather than changing definition 1 constants. Never reinterpret an active old save using a regenerated current roster.

Save envelope 2 adds campaign metadata beside the active state; envelope 1 migrates without adding/removing active-state fields. Old state still uses schema 1 and is paused on cold launch until Resume. Checked alternating slots protect the newest valid candidate even if only a temporary file survives. A failed uncommitted import cannot activate after restart. Import validation rejects unreachable per-pen rewards, impossible wave/ownership/budget states and malformed definitions. Profile integer counters and saved arena-return states normalize on decode.

All geometry, creatures, diver, chains, weapons and local tones are original procedural assets. `scripts/art.gd` and `campaign_world.gd` build the scene; combat/economy run independently in `rules.gd` and `campaign_rules.gd`.

## Verification

Use isolated test APPDATA: input tests clear their test save slots. Never point these tests at a player's data.

```powershell
$game = 'C:/projects/active/_worktrees/games-hook-and-hunger-20261018/android-games/hook-and-hunger'
$godot = 'C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$env:APPDATA = "$game/.artifacts/manual-test-userdata"
& $godot --headless --editor --path $game --import --quit
& $godot --headless --path $game --script tests/run_tests.gd
& $godot --headless --path $game --script tests/campaign_checks.gd
& $godot --headless --fixed-fps 60 --path $game --script tests/import_regression.gd
& $godot --headless --fixed-fps 60 --path $game --script tests/review_save_regressions.gd
& $godot --headless --fixed-fps 60 --path $game --script tests/playthrough.gd
& $godot --headless --fixed-fps 60 --path $game --script tests/full_journey.gd
& $godot --headless --path $game --script tests/counterfactuals.gd
```

The full actual-input route has 174 checks, all 12 campaign clears, natural losses/Retry, purchases, active export/import, state-preserving cover/inner resizing, ending, three arena wins across two seeds/two loadouts, settings and cold reload. The final automated route uses 34.415 simulated minutes including the prologue; campaign alone 33.664. This supports the30–60minute design target but does not establish human playtime or fun. Pure controls distinguish positioning from unchanged outer-reach holding, and verify all three refits against one fixed seed.

`-- --capture-dir=<existing absolute directory>` preserves input events and earned checkpoints. `tests/motion.gd -- --checkpoint=<earned checkpoint> --seconds=24 --capture-dir=<directory>` continues a checked actual-input checkpoint through ordinary loading and new touch/GUI events. Add `--write-movie <ignored path.avi> --fixed-fps 60` for motion. Fixed-rate NVIDIA desktop movies are not measured phone FPS or audible-output evidence.

The original first loop and full-candidate visual direction were independently cleared. Exact code2 source/artifact hashes remain in `evidence/campaign-checkpoint.json`; code3's fix evidence and final source bindings are in `evidence/review-amendment-code3.json`. Coordinator owns APK export, real code2→code3 install-over update, Android lifecycle/navigation and final integration. Physical Fold7 touch/folding/sound/performance, human pacing/fun and independent amendment acceptance remain outstanding. Runtime is frozen at this review checkpoint; no push or shared-file changes were made.
