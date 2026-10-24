# Hearth preview playback-release cleanup checkpoint

This is a separate harness-only amendment to the frozen40427f0 capture recipe.
The original BUILD_PREVIEW checkpoint, PREVIEW_CAPTURE_20261024.md, two strict
render failures and all their packets remain unchanged. Source1c657cf changes
only production_passage.gd and preview-only command verbosity inrun_production.py.
All shipping source, art, rules, Store, decoders, versions and export files remain
exact to the prior candidate (text LF/CRLF only; binary files byte-exact).

## Cause and bounded correction

Both root-owned windowed Dummy opening captures completed17/0 and200 frames but
failed the strict gate on one leaked AudioStreamGeneratorPlayback at reference
count1. Verbose identified that class and orphan Master StringName. Shipping
main.gd setup_audio skips all audio construction only for DisplayServer=headless;
a windowed Dummy capture creates a generator/player and retains audio_playback.
Shipping _exit_tree stops the player and nulls that field. The frozen harness
queued the bootstrap and immediately quit, before pending playback release.

The explicit tiny CPU fixture copies that exact generator/stop/null lifecycle.
Immediate quit and four ordinary frames both reproduced the same remaining
playback reference after owner/player weakrefs had expired. Pumping ordinary
frames until the actual playback weakref expired exited cleanly; the audio mix
clock advanced at that release. This supports an asynchronous audio-release
teardown seam. It is not a claim about an engine defect, global resource owner,
font lifetime or native gameplay leakage. The original full input-driven CPU
route with an explicitly installed production-owner generator was clean; retain
that negative result rather than claiming a full-route CPU reproduction.

The correction snapshots every final context and raw slot before teardown,
stops recording, disconnects only its own draw/timing callbacks, and queues the
bootstrap once. It retains only WeakRefs to bootstrap and actual playback,
then pumps ordinary process frames until both expire with a monotonic2s deadline.
A successful observation must be before2000ms; a release first seen at/after the
deadline strictly fails. All preview finish calls await this one-shot cleanup.
Existing held/terminal boundary and zero additional captured frames are asserted.
The saved end context is used after owner deletion. Historical recipes retain
their non-yielding original teardown. No sleep, audio disable, global audio/cache
purge, expected-warning filter or gameplay/capture cadence adjustment is used.

Astra found an initial deadline truth gap; a test reference released by an ordinary
process callback at2000ms made that initial cleanup wrongly pass21/0. Its exact
executed source and raw packet are retained. Final production-owner diagnostics:
normal21/0 acknowledges at36ms; permanent retention21/1 fails at2000ms while playback
is alive; late release21/1 fails at2000ms even though playback is already freed.
Both intentional failures retain their raw ERROR and are not strict-green runs.
The headless audio installation and retention faults are explicitly marked test
fixtures; they do not alter shipping setup_audio or saved settings.

## Current verification and provenance

All four final cached headless/Dummy passages pass: opening21/21, boss26/26.
Before/after138/2982 raw input events, complete start/end contexts, all eight
route/app-written/process/physics timeline observations and final raw slot bytes
are exact without field masks. Audio cleanup is separately recorded after the
final boundary and adds zero captured frames. Normal headless passages have no
playback; the separate actual-owner audio diagnostics cover that resource path.

Root's original baseline render, verbose baseline diagnostic and corrected
baseline each have the same exact200-frame MP4 SHA
1442eb3167bdc6f3b8f4df30d7f321fc463f37305c5d0cb3f7098bc180137d7a.
Full start/end/timeline/native count/raw-slot snapshot dictionaries, raw input
bytes and final raw save files also match. The corrected root render passes21/0,
all strict raw logs, full encode/decode/pixel checks; its cleanup acknowledges
actual playback release in4 ordinary frames/60ms with zero new captured frames.
The two original renders remain strict failures. Broader before/after/boss pixel
review is coordinator-owned and separate; no worker GPU/native execution occurs.

One historical metadata limitation is explicit: the external verbose diagnostic
wrapper inserted --verbose into a COPY of the execution argv; old execute()
recorded the nominal unmodified list. The old verbose receipt command therefore
omits the actual added flag. Its raw verbose log and pinned wrapper establish
what ran. New preview runner commands include literal --verbose, so new receipts
bind the actual flag directly. Historical recipes receive no new verbosity.

Root amended only the two reviewed harness files in the existing single baseline
project and pinned old/new bytes in hearth-baseline-cleanup-amendment-20261024.json.
No second baseline/assets copy is created. Original failed .artifacts are untouched.
Baseline commands remain the frozen recipe's commands; they now use its explicitly
amended two harness files. For the exact gate from that baseline project root:

```powershell
python -B tests/run_production.py preview-opening --cached --preview-variant before --render --native-frames
```

The worker owns only CPU/source work. Root owns all serialized rendering and
any later Android/build/release action. No version bump or native, audio-listening,
physical-phone/FPS, human discoverability/comfort/fun acceptance is claimed.
After this handoff no new scope is started pending parent ownership reconciliation.

## Pinned checkpoint

```json
{
  "base_harness": "40427f0b977e670d86da952cd3d4aaffff1b40fb",
  "cleanup_source": "1c657cfc15a6aa4a1645a4ba073f7dd68b5a25b8",
  "changed_harness_raw_sha256": {
    "tests/production_passage.gd": "9f7d70e9c39745edc799234ba0b0358428415fe678792100edfd72d8000bdcb2",
    "tests/run_production.py": "dd72c15d046d7bcc084efa9f5e59dc48fddbc9d6e99e7fb3212abc28d9c0ca14"
  },
  "unchanged_base_files_lf_sha256": {
    ".gitattributes": "4bbf193eca4c8aa4230b5c504a09e49e6d712485c4a1ccf40a38bd6654be1636",
    "BUILD_PREVIEW_AMENDMENT.md": "308b5f87520ea33ad70c86dcd59cb26605f93dd811b458a8718247ceced44819",
    "BUILD_PREVIEW_CHECKPOINT.json": "30b6ee46f0d98b1aa68ecfd5d70068cb4a6ee5a0a52f746fcee12029edf42a14",
    "CAMPAIGN-CHECKPOINT.md": "802f12e4d6275a6f0ba62f2b5410da86be39eaeb439693d0baa6f2745881d338",
    "CHECKPOINT.json": "3f0ffa84d42840ed33fa82d7e19e5427b79297bab9dccf74057c2cc1dad4efb1",
    "CHECKPOINT.md": "e2ab30f503395333125fff4c199a023621effe053019fc9587232b77511fe0cc",
    "DELIVERY-METADATA.md": "3557ba2e908018b8c4501622ae47fc83c703ce689f3ee35e8933dd04aba5d88a",
    "GRAPHICS_PRODUCTION.md": "a5a3f3bc447aca3252e7f7776f1798fb1683ef8cceff15d6630c7869a3d910a2",
    "IMPORT_RECOVERY_AMENDMENT.md": "44dc7cddafe445155ef0bac9e165df1b6f147a011bd341f30ccc9bc80db0f0b1",
    "IMPORT_RECOVERY_CHECKPOINT.json": "ab0313e5db4a92ff37c4c3ff129bcb39f077a3838adf2f1ced79ce8f45db4fa6",
    "README.md": "e37543ae6630f7ca4a14b2ad1394ab33dd32cd21a4aa99dcae2e5908dfb4b8d0",
    "SAVE_RETURN_CHECKPOINT.json": "cd601f630fb3d81e54c95aebad455788ac0f7b3dc4268ab2b8e9c21616d7eef9",
    "SAVE_RETURN_CHECKPOINT.md": "a02d2e3015b4a4d5eeb0a31a424eab73deffff877acabdb79d62c210a53ec290",
    "SESSION_WRAPUP.md": "8c25342d0e3d04f2e29d54b74aefae87ead029a8ac15e445851460abf550cc76",
    "art/hearth-crest.svg": "9b1e7c8538f3718f1e7456bd015f8ccbd7e5cbee94f93f6985cc1f63a7587067",
    "art/hearth-crest.svg.import": "26c431e88aefd159f3014f929bd4425974ad29f6bccce5e524d1ad0e4ee9a0cd",
    "art/manifest.json": "b2cdead986009489937f8319de5ad47f32ef90b5961eb0fe52b92b62db14bbad",
    "art/models/actor_armor.glb": "2956dac8a1886df3aa92933fa2cb31507cbe8211972c7f5028c7c55c00703d5a",
    "art/models/actor_armor.glb.import": "607bb0c7acfdfcc83faf7bab84f34a5d907cd9476dda23e1575055cb704d5d0e",
    "art/models/actor_citizen.glb": "6134f63b54b6918dc5a7683c84be86dffd697bc4b6eae3a7bbc96e92a645acda",
    "art/models/actor_citizen.glb.import": "8560afe1bddde2e0e0a01cff044d076e5ca5d3359c33718474020d632d796093",
    "art/models/actor_commander.glb": "c71554172a808b53f88d2821e23c7b57b9d3e47ca3362b1ab911805a36e96800",
    "art/models/actor_commander.glb.import": "0f7891f5922bba5ff1371b11a96af1d4b865afd442cd93d2efd3d79c9ed2f789",
    "art/models/actor_defender.glb": "705ba23c8fca3b84e32ae36cbbf2d5d6f57b6b5d684773099e8151e0503b43c1",
    "art/models/actor_defender.glb.import": "652c7bca527cd2bccb21b5982ebca48020ad24fc4f10c51df6d1d70f044394cd",
    "art/models/actor_matriarch.glb": "9e861bcb6f64d8c8a7f786fe2ee0194ab4600008091bea2f1b03dc7a6573ed0e",
    "art/models/actor_matriarch.glb.import": "90931a5c635f3af426caf98a91c55776e1e5a652c416c5d1179aeed19e035f61",
    "art/models/actor_mender.glb": "bf41d87f8d3edac60679336c130ca59280231fb5d2074f93b468fbda9cad672c",
    "art/models/actor_mender.glb.import": "01964bfa749d326a00e8df5527aaeeea1636174d59e5f51b58c727d300b81d2c",
    "art/models/actor_raider.glb": "6e12a2e835359040565e6233c23ef5f3006efbf307f9ad2c5e1f5ae53be4de9b",
    "art/models/actor_raider.glb.import": "5a680f679d269aa445c257539433bcc8f2423328424f2bc36fb86c74bd3e55ef",
    "art/models/actor_ram.glb": "e744a8a00ec30b524bb6028734895fa63f1bbecee3d2deb93c1891fc16f53085",
    "art/models/actor_ram.glb.import": "7cede1335b45f474744d483f185640c8f09e07d02273a27c3001b11153d5a77f",
    "art/models/actor_regent.glb": "76636805665f4ac90fd4ddf32c3ce1f815a9f5d50cdae0196dd0b46cc6b77223",
    "art/models/actor_regent.glb.import": "ba1b4eb33aa8765bced305d6aa1c3f235094250939015509c77ef4de755d4129",
    "art/models/actor_runner.glb": "bd57b9f91203161e38823d39bce70eddd4e522429e2e970a0ec97cb4702a2c68",
    "art/models/actor_runner.glb.import": "e5a6e1801b66552d8726ae7db70f541602d933b7584c62ea32639a8c1f3fb17f",
    "art/models/actor_shade.glb": "a636d8e7edf99b292e22425370ead51f18e30ab525f39ba63d53096bc3140168",
    "art/models/actor_shade.glb.import": "b8b1cd5b0df5eb2d1502a3ca91d7fa9d5ae6c7706047a7d3a79ba485af282029",
    "art/models/actor_swarm.glb": "cce0d503ab48ded4fc855c087b35dc7d094a325ae0bdd734c76b86736f33035c",
    "art/models/actor_swarm.glb.import": "3d043fabc689c4700898cd69fd8c47da68b523bd82fcef5feaafef26d2842d8d",
    "art/models/anvil.glb": "91e40ccba54e1d99548ba2cbe382d82c629556b4279e7b18c5281dde35487c8c",
    "art/models/anvil.glb.import": "a3bccf3cebfcea8d551185f55540c0dc1e6102abeb827eb34197d9c69fd2ce63",
    "art/models/banner.glb": "bdfecbdc6935e6e47b4a7ab559646d62b6698819c60fb074383990054bdd4ba2",
    "art/models/banner.glb.import": "43f838eb7eff8b021a3e1345bdc4b1fc6e782b25c886cd584255eff40ee5a845",
    "art/models/boulder.glb": "20fff9f9ef19a5ff17347fe0a2d34bf67119240b12e5b16bdaffe7c590108599",
    "art/models/boulder.glb.import": "07ab03af12df36b3df98665dc8594ab8617db85571ac57c903455313c25ebabb",
    "art/models/coin.glb": "a37bfaf8ac7dbcf19d25fa11ccd4f4923586c1d7c3ee955ba29ff235c1898962",
    "art/models/coin.glb.import": "81ee8f82a154520ed325855eaa5b8f4081186eafcd34b38366d9f70bd8668385",
    "art/models/cottage.glb": "7ea0b640abffe11f5bf3835cdb7a06cf3a8a09946a5a77f52591028ff4b4238f",
    "art/models/cottage.glb.import": "adb442f7a0ffb1f8248e0e42402d194e7b4db8d58cea8fbf64196f6c573a8b9f",
    "art/models/lantern.glb": "070d966c5b10ed34b186d201f58582abe7adb1c8e26b92c2e5d94308510bba8d",
    "art/models/lantern.glb.import": "7051b41e25db2f6ea8b34f64080342189233d9c522c120a9b212068ae3addac5",
    "art/models/market.glb": "20902fb6c8c51b331d6e5cea09ea6cd08022bd6ab25d5b92dabaca2a36a31375",
    "art/models/market.glb.import": "4e4ad1d66b66cb3a2138bc346816c0fcd93b595d059dfe70decbc2dda0a7255d",
    "art/models/monolith.glb": "fae076717fb01bca891cef59883c232e2f2b41d4e9919d32cc228700e927552c",
    "art/models/monolith.glb.import": "65d77c29f3dbfe92c9adea17348dcfc90d52a13595826c7d588df9ac73d610d6",
    "art/models/oak.glb": "b07601ced5b71bd2b1f6ceef3932efd4481ed5de4f5c00397003e168943ac0ae",
    "art/models/oak.glb.import": "5115d55ef7a6758d991e62a2e254e7a42f0a9643623a95caeeba9f9cf13c4380",
    "art/models/pine.glb": "d41b042a97bbf0ae51c215281363ab79d7582c5975f3244f7d36fe1a2247116b",
    "art/models/pine.glb.import": "8f5c36b79cf967766bb441651592fe114f5f95c4a1d51ead3a79add0e7fcbd4b",
    "art/models/reeds.glb": "69b41c555abcb9e33574530a52f51b395fe842b4c0269e2aa9bb039a529219f8",
    "art/models/reeds.glb.import": "0a762bc541a724cc4666f7026a4d53065c274ceddaa6c17f4503481759c881cb",
    "art/models/ridge_house.glb": "831016896149da6c953810897dd70cae68133c0caabaaf78d174f93827aafcf1",
    "art/models/ridge_house.glb.import": "ff2412420c3f18e65f7a0811dfbdb024cc59357c2cdb097697227c2dbd5fff77",
    "art/models/stilt_house.glb": "09d71c1c31baa9ddfd4a01f77ef2346484525efac84d71373a8800f11bcd6a76",
    "art/models/stilt_house.glb.import": "5c9aa2ff47e132b7ed39a71ea11767c3ff872c625ce1ed8901ac0635031613bb",
    "art/models/tower_beacon.glb": "a138e60577d702c0dd916f6825afe1e8ae860367bcdb5132ca1c17fd0d9e7aa5",
    "art/models/tower_beacon.glb.import": "c2e1ea9aa1b367aa2cc93f10b156b6d23b9fb426c36d1dd92e04778518646c43",
    "art/models/tower_bolt.glb": "f44b36664fc2384d75150beb72141a34d892c9b1fbaa56c14b157d8caad69e79",
    "art/models/tower_bolt.glb.import": "601a3955ce1bf051b5696f2855e893eb0df15fb9cd8b2b189abff79e75a97e1a",
    "art/models/tower_mortar.glb": "9eb5fc3beb94473438e5d4e5aba68b6f5fcd03f885999800c4444fa458f8c3ca",
    "art/models/tower_mortar.glb.import": "7c8be69f2bbd7e14d8a5d00ffd010574a58e9ac2f6a1a7173fe1bb665ff1606f",
    "art/models/wall.glb": "323968f5494c79cbc28e2c3ec8cd8a4a8acffb3d0af2c93d80f22d226dfc737e",
    "art/models/wall.glb.import": "50f674a4495e6758d4e1edf522e4f738f97f10827030a1e2fa18a7cf1147201e",
    "art/models/well.glb": "5c253fb3e89f954265b8039690178ea7706af09cd83a1470a7f35046810975c5",
    "art/models/well.glb.import": "41d4e84ca43fb7c3dea88b3023686fa7d70c3e800fd6e605f2f0c1be0bcbd05f",
    "art/source/build_assets.py": "6780efbf622b1c72d6422eb74a32ce804416dcce2fe6cefef095c8febcd9c0e7",
    "campaign-checkpoint.json": "66a45f7ec813544732e237427ed93c4e35be99aa76111ace72d5e526991d912e",
    "delivery-metadata.json": "e2acb9c9ed41cf7a36de530d9f781ca19c6f045ac2bbe7753886ad7c1ed1439b",
    "export_presets.cfg": "86958972e004ee5dc6a538a26d550ddd78c4c09a6d3444312d319fd272148086",
    "icon.svg": "1fe2f709f71be5250ecbe223a0e12eb785952e6c13b470a0392d8fb5e70c4b2f",
    "icon.svg.import": "2ecc2a4e347e48a82b31c3dd497996dba5fe2c318b0f135d9d6e8875fcd5f11f",
    "legacy.tscn": "24360a50f67b8c2aea5a7fc5fc39e97cd790226647a4ac43732a54df806fe8bc",
    "main.tscn": "9eadab4e604e34c48c84eb3813b4ccf4d691b97fc0e0736eb4f03a02a1978120",
    "project.godot": "58c640c5c978fc793598bd5d4217f3edd6cacd9203aa44ff48082e32c4e70838",
    "scripts/bootstrap.gd": "f326f9a05b4564412f0459dc74d2de06f6359472d2ef2496bbfa4569b9743dd5",
    "scripts/bootstrap.gd.uid": "a9c6edf66f32c03f593735b53157687c9df44672497d3ee6c9e729ee95a7211d",
    "scripts/campaign_catalog.gd": "e97f1a54e95ccadca2bce77c3ed47d380b79d83318f41fd2585480457e1882ec",
    "scripts/campaign_catalog.gd.uid": "d31c0c726aa7098bcc4284b38aeeb51b71f1dc40651d2043333b5bcb32f3fa65",
    "scripts/campaign_main.gd": "9e318e1095053eaeaef9c6c32fd7af10556f3945f15b376932d72173222dae6f",
    "scripts/campaign_main.gd.uid": "b94d5b2ab335211c76a6ce77e712b11166df33a62aae288eaef147d389e36c9d",
    "scripts/campaign_rules.gd": "6b2a2e16113491e4c44c0cbebcd92762cd78ca8dd28c0a8f5ce02f6358b5a01e",
    "scripts/campaign_rules.gd.uid": "837b9f9df66e27449d9117a4bbd0e88481d5c0d86fc79fb897046d1567d6926c",
    "scripts/import_recovery.gd": "85f554728f35fc79f16bd9edbb3392797e6eb1ea25c9e08a5da5b56ea165c036",
    "scripts/import_recovery.gd.uid": "3a54240da70b599452e67d6ebbd55a6ff157ad14d88deba634747a77d18531a9",
    "scripts/main.gd": "0a9354dc803cd0e2648e297841399b22ad6779cac8a3ebce967fefba1af43bc0",
    "scripts/main.gd.uid": "350af2db92aa9754ab3da2043d5d0f9c2175e2a4655025a65dc54ce0e6b7add3",
    "scripts/presentation/actor.gd": "07bbafb26d8eb5f49c354df5eded80938ea4d789082590e9e844b581193385cd",
    "scripts/presentation/actor.gd.uid": "bf1165299d75f88a80e2d1aff9dd4da00df7dec8f23613b0e3051ca26bcb41dc",
    "scripts/presentation/adapter.gd": "ed79b6365060fa1f33b2b350ed6ca5308d6e6172bd15960deea0c05e4dd0cd63",
    "scripts/presentation/adapter.gd.uid": "411ce4b9ec7b1adac7ecf19249c8f573b114a14b30061a712ac31fa13967cd21",
    "scripts/presentation/label_clearance.gd": "20d81663b6f8b574e5601073033fed4d36db1e4aa3e937876287a84796abc27d",
    "scripts/presentation/label_clearance.gd.uid": "da544237a47fa5acf3a30b6e98460f0ab245510b7806f8dccc5a306e22bff908",
    "scripts/presentation/node_pool.gd": "793c6fe42f2d6f9b5407782aa6075b74a3fd667b9bd9b7a3d1193858d527ce3e",
    "scripts/presentation/node_pool.gd.uid": "fbcc1c9e84a63ec62fc722110bb06962fe79245181d3f552547f7b2394e74b27",
    "scripts/presentation/regions.gd": "f86171e824c48af90530ecb3733c5a8c37bc7431e770225d8bcb1ca569a145c1",
    "scripts/presentation/regions.gd.uid": "471ee3042c7708afc37c6cd7864f1b4f14909c50af92b4cdb8ada14af0bc301b",
    "scripts/presentation/settlement.gd": "5cad221c3fcdbdfea0032c850f0ec83f797099424a80eb96c82ac4edff5055a5",
    "scripts/presentation/settlement.gd.uid": "01dbe46e7b13ff9e587c1e549b63478048c02248e521eee6266fd186679d8698",
    "scripts/recovery_copies.gd": "2a11e158fee9c9a60525f736e22a06caf6ab4ec8e1f880941033cab6e0ab1fd8",
    "scripts/recovery_copies.gd.uid": "89d5c91e0315d3eddaf1c863a7777caf4a8d98bba616ea3d6f6230261884a870",
    "scripts/recovery_files.gd": "5a447d6262b798bdcddaa23c44286394cdcf8b4da4b070d6c1204d8a1264a48b",
    "scripts/recovery_files.gd.uid": "35dd2d5760286836458a42e16462ae070d3cb9ac7b5c0f1f106efd87144dfdfb",
    "scripts/rules.gd": "64ec77aa1e43f3d0ceda2c4404286de74c16dcb530da1427619ecfc5c8f57483",
    "scripts/rules.gd.uid": "8940d66b4d4cdc6f2b2e288d8d58f437a3e6966b6ca02cbdc995c9d54d40f060",
    "scripts/save_files.gd": "207f08a69e6c9e435367bf0b394be53fead3461ecfaa7ec124fff5b0172e4eac",
    "scripts/save_files.gd.uid": "c06b0c067af1acb748e472c798741e585fd355b31f690a4fee168a21260123f9",
    "scripts/save_store.gd": "ba0d69d3b6d4cf9794b40df3996bc32aca7c22c241ca0db2af71095af3537a87",
    "scripts/save_store.gd.uid": "b4f8aa18421f8dd3ae5b3994f5d4acd73faa50e1e213fa81a6aae3c276be4733",
    "tests/PREVIEW_CAPTURE_20261024.md": "9792fe93b90b55123ddb1953f76f0ff987f563488f9334b39c931a77d09620c0",
    "tests/PRODUCTION.md": "d8878a6aaab724a4965b8819f029854877af7e3c84608ae5b7243c60ed1c4499",
    "tests/PRODUCTION_RESULTS_20261018.md": "52b9c3f3b0b7e4c11c6404a876289bd054e34e38bc623f466cae8fa7be908162",
    "tests/build_preview.gd": "b7b4be282b5677935e45fd17449dd0a4204ff704e26ef18707d81aaaedced487",
    "tests/build_preview.gd.uid": "e2071d52939891072fcec68c7bb890f2a2c4b16a21ae05b6ded08d488c943f5f",
    "tests/campaign_checks.gd": "b0f1a8c759e75d43797f2fb490d7252abafb3163915884b28246ad8693daabf0",
    "tests/campaign_checks.gd.uid": "a2f9118185f2877fed185c3dbbda09dc625fd8a6e15f212be37f8497bdcf8a18",
    "tests/campaign_journey.gd": "94fa75b36f4777cfb26b417c78b6133e4b53dec54516772faaf99dd87bda7897",
    "tests/campaign_journey.gd.uid": "6f2ae9a5669fda239a79a5a78543f4bd8c471351702d6ce5d800042ac65c8485",
    "tests/campaign_policy.gd": "22f372400340d816a3a8810e34e93c93e95871284a4da08452d2dfc761fb790c",
    "tests/campaign_policy.gd.uid": "31faa899315f45cebfceaffcda594dff9d415127190cde3e06ca117f4e993bf1",
    "tests/composition_tests.gd": "e39274458bcfcdad01a9860b8bc8f9867e9d8197039fddb39012680bbf76167b",
    "tests/composition_tests.gd.uid": "7fba114f4188ad36b64fa0baeefcaa04a62cedf2e3110552a13e28bdd97afe87",
    "tests/fault_files.gd": "4ce4e69951091f42693af2e8494f8a31c12f4b05766bbb0b765e67f13d9b8bf1",
    "tests/fault_files.gd.uid": "775f943b4e9e6a6093785332bbcbb2c53260cb66997ededc5cb3ce6e63c0e166",
    "tests/frame_sampler.gd": "0fea195dd174f76b52e96cf528e0ba773a26eb19568e7e6f3bff501a3a47fa24",
    "tests/frame_sampler.gd.uid": "0cce3d9df513e142ea70e0f8ea0c5cbaf80ada84f24e714093357e1ea45cced4",
    "tests/graphics_passage.gd": "b8afb96de23d03fd6b5e5d5579b4c482c57469cdb8b0c3f38c55742ce84b9826",
    "tests/graphics_passage.gd.uid": "0c792a71fd31716beb857ed7bf952d0e1aa5a9e50bdccc5f56739ffbf1868b3f",
    "tests/import_recovery.gd": "5a1989bfff5626d814ab409074b0ee51bc596c21fb9aa2f07c00e022bf6db007",
    "tests/import_recovery.gd.uid": "f842d4be8e693fc99ff0aabccb5f3af33febee0edc0a8411d7f8e125919a8956",
    "tests/import_uncertainty.gd": "ee5f7dedcefb53e8f2d2d89f3fad11fe666bb9277aedaf6b57e70f8067e8afa0",
    "tests/import_uncertainty.gd.uid": "caa2ef6ac51639260680dd19c4e1b1e230acbe623bf9e1bcf83c59763c8bc215",
    "tests/joystick_tests.gd": "6715a54c818822620743466da066f9031c65ac6edf4ca750402d481bc1fa3ad9",
    "tests/joystick_tests.gd.uid": "7921ac33319eca16840a6bb11b04643ee0dd52eb7925f21a815a8a8d05316d80",
    "tests/legacy_compatibility.gd": "f55e4203308e1897cf2c7d117c1621462654c16b33d9e43f03d158fffeccf38e",
    "tests/legacy_compatibility.gd.uid": "a2266546e4145212752d2d68e3ab4501101ad7d4de631ee74d3bca07bdd05662",
    "tests/playthrough.gd": "0bf57958ee910b32770e3d51c0257753c6a396d926c21772a56b0fb58b3da0d2",
    "tests/playthrough.gd.uid": "952ca44910e0ce8c9657b4645e62cad3b218c3c19d62201ef8ae1466cf5003f2",
    "tests/pool_tests.gd": "0090627e8bc1000f7c3a77ffdd3abb590ce97eab75b39f0341411b4883fde3b4",
    "tests/pool_tests.gd.uid": "c5d6557784f07e554206d313aae20d300d086fed224f1075758594210ac224df",
    "tests/presentation_tests.gd": "19c9c41fb93fbbee1c40c74c8235aacc28e4053e07724713ec6f934fc57e4b1d",
    "tests/presentation_tests.gd.uid": "f79c03fe45c043f0411206bfa491096397a2559613ede946bb1c91af1bc2d697",
    "tests/production-accepted-runs-20261018.json": "0d0fa62b4a2b33ccb9e34b206f5b289812df682647060e82c3e92ac953bdc503",
    "tests/production-plan.json": "c8e19fdc7105e03ead734ca8ad66a6034982c4214f61d2d76290b6e9b4402bb5",
    "tests/production_checks.gd": "5898357533fae2d83e18906707051ea667b144dc52cd9c8a5dd61984aa495520",
    "tests/production_checks.gd.uid": "a65cbc095b4fd53fa334ea55127e8419f09d20208f82a99d9e30396d1c064f0e",
    "tests/production_coverage.py": "87133cc18f33bd25652349ff72eade844d81e42ac4cd0fe0c09b6e846f9acd14",
    "tests/production_observer.gd": "705ed0d102191518e984fecc8eef984931caa5322c56c396526900fe1e16e5d3",
    "tests/production_observer.gd.uid": "bdca85588a2d0408aa4a97d92c4377831fd9687eec6a9a14d88bf77ca2a49cf2",
    "tests/production_passage.gd.uid": "c5d4d299aaae6fab786c64543d35dafb843f3eb66ad5331082efa74e24fe4954",
    "tests/production_sources.py": "56cac1f9bf1184d7bfe9af497b09cf9fe932c8d52d96229cd3afd53802096a44",
    "tests/run_campaign.py": "43d90a8f1e9514faf41953295d0d14f2e83cba0c37010143d29ec5c44ac7cde4",
    "tests/run_desktop.py": "9f920b543ef5c81bd135d0a0940ae777e6a5808109cfd8d23fcdab37c2b97ad4",
    "tests/run_graphics.py": "5bbd32d6692900a2ee9e99064400991f6469ec9350c7188e5fdb8fa0d27d3ea1",
    "tests/run_recovery.py": "852a7f7025ebe63f247d42075725719a0d45919048bf1e2037e30d58f7fd6317",
    "tests/run_tests.gd": "a3ec30b5b0e5f97be649bb131a27b4b6ef035e85b3dfa9cc9192d738188cc3c6",
    "tests/run_tests.gd.uid": "3b5e8eae81237d2d6307e97934c00b4a8bcb6f4054518af22c98f6d7b04290d0",
    "tests/save_reliability.gd": "65870c57097b89a5e3f248f925fbc5beb29abcd77510533811fc0c9184441268",
    "tests/save_reliability.gd.uid": "9f41a63667adeb61b14ce2b89101f87ca4b27afadb9d13d9fdaee7a4d5e24708",
    "tests/source_index_checks.py": "418e49b403cda7eb69fce447e8795d6dc8d4bd69a7a9179d4ff1d87feae541ad"
  },
  "final_cpu": {
    "passed": true,
    "pairs": [
      {
        "stage": "preview-opening",
        "before": "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z",
        "after": "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z",
        "checks": [
          21,
          21
        ],
        "input_count": 138,
        "all_route_context_timing_input_and_slot_bytes_exact": true,
        "cleanup_before": {
          "acknowledged_before_deadline": true,
          "audio_was_present": false,
          "ordinary_process_frames": 1,
          "owner_freed": true,
          "playback_released": true,
          "post_final_captured_frames": 0,
          "wall_milliseconds": 4
        },
        "cleanup_after": {
          "acknowledged_before_deadline": true,
          "audio_was_present": false,
          "ordinary_process_frames": 1,
          "owner_freed": true,
          "playback_released": true,
          "post_final_captured_frames": 0,
          "wall_milliseconds": 4
        },
        "receipt_sha256": {
          "before": "92bbb82903c211252c4a3b44c6198fbb38929e242eac60964d04530fe646f9bb",
          "after": "20bcdb12288adb0882557cefebc499d9f51e09198bb6296867e63a980965e7d8"
        }
      },
      {
        "stage": "preview-boss",
        "before": "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z",
        "after": "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z",
        "checks": [
          26,
          26
        ],
        "input_count": 2982,
        "all_route_context_timing_input_and_slot_bytes_exact": true,
        "cleanup_before": {
          "acknowledged_before_deadline": true,
          "audio_was_present": false,
          "ordinary_process_frames": 1,
          "owner_freed": true,
          "playback_released": true,
          "post_final_captured_frames": 0,
          "wall_milliseconds": 6
        },
        "cleanup_after": {
          "acknowledged_before_deadline": true,
          "audio_was_present": false,
          "ordinary_process_frames": 1,
          "owner_freed": true,
          "playback_released": true,
          "post_final_captured_frames": 0,
          "wall_milliseconds": 8
        },
        "receipt_sha256": {
          "before": "bf82c07e97ab49685404f4c63c5d376ad861a08c5dd5ef458be31de481228e8d",
          "after": "596a47ab3e8dbd86445fe8e4196c48ed19056c66e67290a3295b5e564b9fd5ad"
        }
      }
    ],
    "scope": "All complete route fields/rawinput/rawfinalsavebytes compared without masks. Cleanup observation is separate afterfinalcapture0. Headless normally has noaudio; actualaudiocases separatelybound."
  },
  "root_rendered_baseline": [
    {
      "path": "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z",
      "passed": false,
      "receipt_sha256": "05f0ac608a565e4a4abd248b67e217e357dd70f02064058643cf0bf017b29420",
      "movie_sha256": "1442eb3167bdc6f3b8f4df30d7f321fc463f37305c5d0cb3f7098bc180137d7a",
      "frame_count": 200,
      "checks": 17,
      "cleanup": null,
      "raw_errors": [
        "WARNING: 1 ObjectDB instance was leaked at exit (run with `--verbose` for details)."
      ]
    },
    {
      "path": "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z",
      "passed": false,
      "receipt_sha256": "126c9dd2ce3e8065aceb0a4d14b0a82960f94602aa12bda61ef14cf730d1b451",
      "movie_sha256": "1442eb3167bdc6f3b8f4df30d7f321fc463f37305c5d0cb3f7098bc180137d7a",
      "frame_count": 200,
      "checks": 17,
      "cleanup": null,
      "raw_errors": [
        "WARNING: 1 ObjectDB instance was leaked at exit (run with `--verbose` for details)."
      ]
    },
    {
      "path": "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z",
      "passed": true,
      "receipt_sha256": "6af3f94d2a77d24e2b0b3e822e1f43ae4c797c0a513a998e1f7caf05b9877328",
      "movie_sha256": "1442eb3167bdc6f3b8f4df30d7f321fc463f37305c5d0cb3f7098bc180137d7a",
      "frame_count": 200,
      "checks": 21,
      "cleanup": {
        "acknowledged_before_deadline": true,
        "audio_was_present": true,
        "ordinary_process_frames": 4,
        "owner_freed": true,
        "playback_released": true,
        "post_final_captured_frames": 0,
        "wall_milliseconds": 60
      },
      "raw_errors": []
    }
  ],
  "retained_artifacts": {
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-lifetime-probe-20261024\\drain.log": {
      "bytes": 2049,
      "sha256": "755a043b5633b47211a1d7b045eeaa1ddcd18d52d48c26a90af28f57be62b0fa"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-lifetime-probe-20261024\\immediate.log": {
      "bytes": 2049,
      "sha256": "755a043b5633b47211a1d7b045eeaa1ddcd18d52d48c26a90af28f57be62b0fa"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-lifetime-probe-20261024\\probe.gd": {
      "bytes": 1576,
      "sha256": "1edeacd4cfc1eb7eeddea1666aa598e6117572994e7f03e7a958f598acab34b6"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-lifetime-probe-20261024\\report.json": {
      "bytes": 3084,
      "sha256": "413e85395631de9619461e05b0bd75bfba9ff8e1ebb34bedd504b204d4f8ca10"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-lifetime-typed-probe-20261024\\drain.log": {
      "bytes": 2094,
      "sha256": "0a26c537cbb1618150b989568bc2fd951c46669e6e5947dce08bba286ad15160"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-lifetime-typed-probe-20261024\\immediate.log": {
      "bytes": 1784,
      "sha256": "beb24ea7860a45c91cc61d8465f0bc46a2d5ace6ea12ade73e335bcd1912f99b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-lifetime-typed-probe-20261024\\probe.gd": {
      "bytes": 1887,
      "sha256": "8a25755066e636b0aaeab670ca6c1e8f42c4fa5499047cf42d7923b8570cca17"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-lifetime-typed-probe-20261024\\report.json": {
      "bytes": 2650,
      "sha256": "169cd7c09e1ec06ef69efd95df95a96cbd3c04410442993bb735570df8190d7a"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-release-ack-probe-20261024\\ack.log": {
      "bytes": 1439,
      "sha256": "d2fbd5681b0a5046c2942ff352bd6a3cc0dddf0e01c2c1e3688853e73b94fd21"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-release-ack-probe-20261024\\probe.gd": {
      "bytes": 2409,
      "sha256": "baf189efb4af17bfea60ee1670f911276834aa829c507396715e0642aa81048a"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\audio-release-ack-probe-20261024\\report.json": {
      "bytes": 854,
      "sha256": "b5553dbb2cf9342bb99bd098974b83dc7c62d658151a04cc990f86251a129979"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 6651,
      "sha256": "61ad9a203ee2f81cd369ec4c783a26624b834d257e28bd7c06bf19ad7c84b8f2"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\diagnostic.json": {
      "bytes": 36383,
      "sha256": "8c269416df68c65ac5f8751118984d21d047df07880000722f9ac16830acef1a"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\execution.log": {
      "bytes": 6869,
      "sha256": "4ebe6611367c6962d779c318adf23d1c1051dcd36ef08048e71817fda645a62d"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\passage-report.json": {
      "bytes": 2070,
      "sha256": "27ebcc6d95486ed55f56075519d18f11f7a642f054c734fdc4729da9955a59d7"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\production-report.json": {
      "bytes": 343387,
      "sha256": "62164b22653208d34107a3dba06d10b39733239b5d1f93f1d05f94b172538c17"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\cleanup-cpu-verbose-original-20261024\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\final-four-cpu-parity.json": {
      "bytes": 2952,
      "sha256": "6ea58828b48c97d91bf9b5e5802f718614899c7f71787ecc6a5b73fcbeb6ab42"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 7405,
      "sha256": "57ae1410783cc5d016c730af0ca939f952cc25248030e2562dc824f35c76a016"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\audio_owner.gd": {
      "bytes": 990,
      "sha256": "060d62c1a230c93bbcb0a4ab6b3c9eec00ffb68cf589e94ddbe739a6fcfddc05"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\diagnostic.json": {
      "bytes": 1226,
      "sha256": "4d6ebec8f7fa54d8b6d06929c1628fbdf900fec7fa66608956ebb0124dc4457d"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\execution.log": {
      "bytes": 7629,
      "sha256": "f020f8106ce4d5617fd80aef8dd4f1c896a2a47504692a3615de0fcf460f69b8"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\passage-report.json": {
      "bytes": 2504,
      "sha256": "a6b830df59fcbfd1bcbd9eae118e471eebe1ee6f3f355341d4e0f5716200ba7b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\production-report.json": {
      "bytes": 344062,
      "sha256": "611777bc4a641fca846650232345954c7850f941d1a4c18680a5077d4bece691"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-forced-timeout-20261024\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 7397,
      "sha256": "b83b0e259fd4c8d94d4fd8431a820e5930b5f0046604b11f341b14fe6bb46d11"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\audio_owner.gd": {
      "bytes": 1246,
      "sha256": "79cb9ce5e7cfc927694798e33bc63f03f2542555aa5fd3e4fc3d8f32b5ab65f9"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\diagnostic.json": {
      "bytes": 1222,
      "sha256": "40999d4b25ac09671b09036b53fd38633650e13af23e9f28cb7eaa5b69417603"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\execution.log": {
      "bytes": 7621,
      "sha256": "324f9f4447fb33f64947ba3dae1e96f37f996fdee16dec6d9ab277b6025ab1a0"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\passage-report.json": {
      "bytes": 2504,
      "sha256": "a6b830df59fcbfd1bcbd9eae118e471eebe1ee6f3f355341d4e0f5716200ba7b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\production-report.json": {
      "bytes": 344061,
      "sha256": "bbee14166294d60394fd81fbaee9653287c033b7dd17adb4f57cf69b57f26f1c"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-late-release-20261024\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-parity.json": {
      "bytes": 953,
      "sha256": "b3cfb115ce8fb13bf1c8e96bfb5975e28a3e177dc797e260cfc2a2adcaa2ab94"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 7074,
      "sha256": "565e595670742f07bf499974873000faa32e6d22a1682e5a47972288ffc5738e"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\audio_owner.gd": {
      "bytes": 758,
      "sha256": "2c0f356588e2cef6871c2849eab8890ba0f970bf1c2403d826427d534da83ec9"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\diagnostic.json": {
      "bytes": 1120,
      "sha256": "d3d4e12c9aed979d779c18a04405dbf2369fe9a5aef6236d5e100bc4f4276133"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\execution.log": {
      "bytes": 7293,
      "sha256": "8d97e1ea59dfc1c372a7286fd6ad646b242bbe6e59914090da4a566405089b19"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\passage-report.json": {
      "bytes": 2503,
      "sha256": "96051cded20c23ca9439a390cd650986e65ea62b8b8af611f248c1e910a8656b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\production-report.json": {
      "bytes": 344055,
      "sha256": "8ac7e13b181e9a4a87c4135137055cc7ba274d9ea66f2d0bb54f8335e3628886"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-final-release-20261024\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 7150,
      "sha256": "65821874345503fe723dd3f65aa3a6b4d444690214feff73328bbcf8e4890452"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\audio_owner.gd": {
      "bytes": 1246,
      "sha256": "79cb9ce5e7cfc927694798e33bc63f03f2542555aa5fd3e4fc3d8f32b5ab65f9"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\diagnostic.json": {
      "bytes": 1340,
      "sha256": "96befb8d86b915671b4b56f13c2aa73f743f7dce31721c6b3c56b2e47ceeeac6"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\executed-production_passage.gd": {
      "bytes": 22909,
      "sha256": "14b391889ec93e5aad1fbcb7ddafad68a41ac795aa23186ee7e2256750d52026"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\execution.log": {
      "bytes": 7369,
      "sha256": "52d1601abb47630371f44c72269a085eb2815fbce208d128ca4807b0ea7c958c"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\passage-report.json": {
      "bytes": 2501,
      "sha256": "1a5a8283dea561838badcf314527c343dc160dbbc30675e0156e91874ae992f8"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\production-report.json": {
      "bytes": 344017,
      "sha256": "cd5d2c4d3fb637ed89ce23b72dcb857c584a71cf4c1fe1c5eb75eb41def664f8"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-late-release-before-deadline-fix-20261024\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 7435,
      "sha256": "5d88f7b7a2acdf363e818dc6aad61fb070c1bb4fe65a916402bfcd85d2147410"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\audio_owner.gd": {
      "bytes": 990,
      "sha256": "060d62c1a230c93bbcb0a4ab6b3c9eec00ffb68cf589e94ddbe739a6fcfddc05"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\diagnostic.json": {
      "bytes": 1282,
      "sha256": "32c9d4dc6fc0d747f137743c17ecd674a016486b2b001fde251e74a1bb3a5489"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\execution.log": {
      "bytes": 7659,
      "sha256": "a357ad2d1acee9d2c70329c4363a09e6b962e921d2024b5744712996f45f2825"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\passage-report.json": {
      "bytes": 2502,
      "sha256": "b4aa125dbe3beaec6f04973d766ba86be8860138e5af9657eaf9f28f757b8f8d"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\production-report.json": {
      "bytes": 344019,
      "sha256": "5cc4911b3a303d9ec6dcabc44b3efca1790fa45803782ea9c3ad0982f9685d02"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-forced-timeout-20261024\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-parity.json": {
      "bytes": 769,
      "sha256": "0bfcaf9ad3f92a212fc643ce6571722bf6d0800a51a941e718e04c8b3e5bcb5d"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 7106,
      "sha256": "bb4333f73e1061d333a954c10946c86b8d10f0a1d755fef7ac280c590ba39675"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\audio_owner.gd": {
      "bytes": 758,
      "sha256": "2c0f356588e2cef6871c2849eab8890ba0f970bf1c2403d826427d534da83ec9"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\diagnostic.json": {
      "bytes": 1178,
      "sha256": "458116ed08fb6cd0b05c6843d73b6f614cbd094f3d35049f570c52a6694b0a07"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\execution.log": {
      "bytes": 7325,
      "sha256": "455e77b518f458ada320189cb0ffa145d431494138e9eeccb41665b51c203070"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\passage-report.json": {
      "bytes": 2501,
      "sha256": "1a5a8283dea561838badcf314527c343dc160dbbc30675e0156e91874ae992f8"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\production-report.json": {
      "bytes": 344014,
      "sha256": "6a8331d05978bb16c73667e4248f963bf5622d0cca1febbfb1142b7e79bc6042"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-cleanup-release-20261024\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 7078,
      "sha256": "79982844f7840428e5d0aef4280ef0e9ab0393665280ef684280833ccffb47dc"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\audio_owner.gd": {
      "bytes": 758,
      "sha256": "2c0f356588e2cef6871c2849eab8890ba0f970bf1c2403d826427d534da83ec9"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\diagnostic.json": {
      "bytes": 1100,
      "sha256": "f4b5b16f694922a022aaffd392f303028fcb45d5e47272af6a88572a525d4aa4"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\execution.log": {
      "bytes": 7297,
      "sha256": "e572d090b4ee4e0aed8a43907929c9a2992f57eb08fa24e4e9fd1d89baa13d5b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\passage-report.json": {
      "bytes": 2070,
      "sha256": "27ebcc6d95486ed55f56075519d18f11f7a642f054c734fdc4729da9955a59d7"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\production-report.json": {
      "bytes": 343387,
      "sha256": "62164b22653208d34107a3dba06d10b39733239b5d1f93f1d05f94b172538c17"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\production-audio-owner-original-20261024\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\.artifacts\\rendered-baseline-parity.json": {
      "bytes": 1280,
      "sha256": "743323c46b7ce39180ba8e9a2fe5963f8989b98a2677191508154cbe9595eb3d"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 13865,
      "sha256": "29b228e8e08df10203c0dfaba4cd84c2d635dc715de605580acf53984b51e7cd"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 13878,
      "sha256": "2849b2d96d6a598b4eae87662da77ca6027398af4ef7f3414c6d581a42fece7f"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 8613,
      "sha256": "d98f772df5c812b85a0f80745e8a8e22a9c063af617549926a4c43c1c3f790db"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot2026-10-24T07.01.52.log": {
      "bytes": 555,
      "sha256": "ab4c9ed8136f8046e127be37a8c893aee23862d197b11f60d949872969b00763"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\execution.log": {
      "bytes": 8846,
      "sha256": "76907ca33cb8c3b0aa999a0b4eb0d60c21c7f28b46db1e5c0ed3e9bafd42a960"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\expected-start.code": {
      "bytes": 13666,
      "sha256": "db142f65ac4483afdbff0172fcabfa8c90cbecb09907a375afe114441f54bbf3"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\expected-start.json": {
      "bytes": 26686,
      "sha256": "22527e0d970b5c3ee8efa843b4b89385b8f3d67245e27758ccf16811a5b22b83"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "a14c4946e8b24a6e693fa5e425ca04b02613170991f5f4cc9d0b7ff1210f8113"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\parse.log": {
      "bytes": 719,
      "sha256": "1012e588c1761227229df42f77dede434faf83f3c68fd16f977733be0e681444"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\passage-report.json": {
      "bytes": 3015,
      "sha256": "3b2f977cacf42546c715dd7a4ce5181c5b70a07daca79206be02cd8da7fd8b39"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\production-report.json": {
      "bytes": 457756,
      "sha256": "cfdb38247d0e56f47b9882a0cb7e97f8404b4d9a4eda0c3ab43a9a13eadf563b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\raw-input-events.json": {
      "bytes": 287527,
      "sha256": "81950ea008bdc343e3c1632eb917c7267bdcaf1f75919beb9d4dcb668677feca"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\receipt.json": {
      "bytes": 16973,
      "sha256": "596a47ab3e8dbd86445fe8e4196c48ed19056c66e67290a3295b5e564b9fd5ad"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\slots\\final\\hearth-save-0": {
      "bytes": 13865,
      "sha256": "29b228e8e08df10203c0dfaba4cd84c2d635dc715de605580acf53984b51e7cd"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\slots\\final\\hearth-save-1": {
      "bytes": 13878,
      "sha256": "2849b2d96d6a598b4eae87662da77ca6027398af4ef7f3414c6d581a42fece7f"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\source-hashes.json": {
      "bytes": 16228,
      "sha256": "4ba1e11b08a07f583a0f1992a71570efcbbed846716a9be6cc4ee8a5c1219ecc"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T110144883311Z\\start-provenance.json": {
      "bytes": 2656,
      "sha256": "73aeb6c39fe4857bd0a8a0b2ad2e3869341da332b216ca03709fee5cf15dd6cc"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 6651,
      "sha256": "61ad9a203ee2f81cd369ec4c783a26624b834d257e28bd7c06bf19ad7c84b8f2"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot2026-10-24T07.01.26.log": {
      "bytes": 555,
      "sha256": "ab4c9ed8136f8046e127be37a8c893aee23862d197b11f60d949872969b00763"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\execution.log": {
      "bytes": 6869,
      "sha256": "4ebe6611367c6962d779c318adf23d1c1051dcd36ef08048e71817fda645a62d"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "a14c4946e8b24a6e693fa5e425ca04b02613170991f5f4cc9d0b7ff1210f8113"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\parse.log": {
      "bytes": 719,
      "sha256": "1012e588c1761227229df42f77dede434faf83f3c68fd16f977733be0e681444"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\passage-report.json": {
      "bytes": 2503,
      "sha256": "96051cded20c23ca9439a390cd650986e65ea62b8b8af611f248c1e910a8656b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\production-report.json": {
      "bytes": 344052,
      "sha256": "228183db42115557f08734cd08c342b51445b9ad620e933ab34e3152eb2110f7"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\receipt.json": {
      "bytes": 14428,
      "sha256": "20bcdb12288adb0882557cefebc499d9f51e09198bb6296867e63a980965e7d8"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\source-hashes.json": {
      "bytes": 16228,
      "sha256": "4ba1e11b08a07f583a0f1992a71570efcbbed846716a9be6cc4ee8a5c1219ecc"
    },
    "F:\\games-workspaces\\hearth-capture-cleanup-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T110119364684Z\\start-provenance.json": {
      "bytes": 697,
      "sha256": "1cb247397bb66bdd2615b33e20bd840fdb7b5f2d66e50685e2e3a0b13e9a8617"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\hearth-baseline-cleanup-amendment-20261024.json": {
      "bytes": 1078,
      "sha256": "a7e2c747d3eed9fac982775d2ec1a138fea83c2cd4e0e2b9f6c2fe92424a00f1"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 13865,
      "sha256": "29b228e8e08df10203c0dfaba4cd84c2d635dc715de605580acf53984b51e7cd"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 13878,
      "sha256": "2849b2d96d6a598b4eae87662da77ca6027398af4ef7f3414c6d581a42fece7f"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 8613,
      "sha256": "d98f772df5c812b85a0f80745e8a8e22a9c063af617549926a4c43c1c3f790db"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot2026-10-24T07.01.37.log": {
      "bytes": 555,
      "sha256": "ab4c9ed8136f8046e127be37a8c893aee23862d197b11f60d949872969b00763"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\execution.log": {
      "bytes": 8846,
      "sha256": "76907ca33cb8c3b0aa999a0b4eb0d60c21c7f28b46db1e5c0ed3e9bafd42a960"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\expected-start.code": {
      "bytes": 13666,
      "sha256": "db142f65ac4483afdbff0172fcabfa8c90cbecb09907a375afe114441f54bbf3"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\expected-start.json": {
      "bytes": 26686,
      "sha256": "22527e0d970b5c3ee8efa843b4b89385b8f3d67245e27758ccf16811a5b22b83"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "cce88973775c604bee792a81ad50cba6553e254972c5f9bdba5e54a9e3d8a733"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\parse.log": {
      "bytes": 719,
      "sha256": "1012e588c1761227229df42f77dede434faf83f3c68fd16f977733be0e681444"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\passage-report.json": {
      "bytes": 2999,
      "sha256": "597e599a35d4bebb92b4f7eab5cc377fd967083a157a2a76de11f39a89c1fc01"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\production-report.json": {
      "bytes": 457386,
      "sha256": "281a7ccb1fd2e516d3158a99a28a0eec6aa71848e8ca1f88895dc649d2979bfa"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\raw-input-events.json": {
      "bytes": 287527,
      "sha256": "81950ea008bdc343e3c1632eb917c7267bdcaf1f75919beb9d4dcb668677feca"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\receipt.json": {
      "bytes": 17051,
      "sha256": "bf82c07e97ab49685404f4c63c5d376ad861a08c5dd5ef458be31de481228e8d"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\slots\\final\\hearth-save-0": {
      "bytes": 13865,
      "sha256": "29b228e8e08df10203c0dfaba4cd84c2d635dc715de605580acf53984b51e7cd"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\slots\\final\\hearth-save-1": {
      "bytes": 13878,
      "sha256": "2849b2d96d6a598b4eae87662da77ca6027398af4ef7f3414c6d581a42fece7f"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\source-hashes.json": {
      "bytes": 15926,
      "sha256": "75731c42c75b49a3518856c5855db3a9d4a2ac72fa71c9685a3b103d6853509b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T110129291715Z\\start-provenance.json": {
      "bytes": 2656,
      "sha256": "73aeb6c39fe4857bd0a8a0b2ad2e3869341da332b216ca03709fee5cf15dd6cc"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 193,
      "sha256": "c6344c5175f81ad269c4e294c0bc4bd514fb33ac408f17dbe2d98a135ec3a088"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot2026-10-24T06.35.14.log": {
      "bytes": 73,
      "sha256": "6d1c065383a27c36804949b6ffa4b09714470b112e5dacc0bd5aeb7b9c147c4e"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\CanvasShaderGLES3\\5c2a443430aed63756000ed4fdb23f02b8d89e1b28bd9ba01ddd60635f2085ac\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 32624,
      "sha256": "6eb742faeb8ba6d5a5684f3dc28d901dd2a3533a41f54cd0745739ed7c6603f5"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\CopyShaderGLES3\\b69dbe566cf70bccd27fd9bee4f59d5f4c3b4b0bf0afc490c771cad63be608ad\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 118055,
      "sha256": "93356d887e565f27abb866b976e2631e333de78a025c74f3398f0863e393631c"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\FeedShaderGLES3\\04959e861c350b844d43ff6438c41d016246b8bb1c7ce08d02bc8891823f37dc\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 8261,
      "sha256": "204481ed285a82f453339b5251130a55341309787431d6f973314d70724b00e9"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\PostShaderGLES3\\1548e0d952e335627b9be9dd73291d4d4e68ba4a81fafbfb14e7a07898d5c9c1\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 13656,
      "sha256": "35348b0dc81d24fb83dbe0881b44919b53f215f6dcbfe3aa2126a558ab7d6f02"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\2115c615c01c3a0177be29c6ddcef01907dcf654.cache": {
      "bytes": 758243,
      "sha256": "6a5697145901e64b86193ce4be621534ba401e45de8c16c2f74731bd521ffe76"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 800909,
      "sha256": "fc4fbf1f2b98a74f254475c923f37bdef5b444b08ad1b44f77f46bb6944132f2"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\75dbda390b4d6b8d1bba67e8943ace8a4f64f756.cache": {
      "bytes": 932568,
      "sha256": "b50d8636182c47829bbae203345c79e66bf067a3c42f1e2339100d23ab061bf3"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\77047cd41f429f33ceff24e890e174f5465e755e.cache": {
      "bytes": 822095,
      "sha256": "5758f377d1181904598c9bda071783b6efc413d5871aee0e81e13d7db8d1d97e"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\f2e328ac8a780a17a0c65e242b0c8bc4fc063f03.cache": {
      "bytes": 932126,
      "sha256": "44d502d875e37401a17ddbee87cc3cef6d095e9a65ac56797da4c5e183ea6f60"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SkeletonShaderGLES3\\970fe26b11b78d44548b61268ebac68162e1323b4486fac1e64104917f487957\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 28067,
      "sha256": "21cd9b8807660b279c8b632d3bb16a3004fd93095b2cec23c521128021995a8f"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\continuous.mp4": {
      "bytes": 359408,
      "sha256": "1442eb3167bdc6f3b8f4df30d7f321fc463f37305c5d0cb3f7098bc180137d7a"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\decode.log": {
      "bytes": 0,
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\encode.log": {
      "bytes": 0,
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\execution.log": {
      "bytes": 328,
      "sha256": "4db5d55e841fa94dd40437b08c7bcb92877c7b2addfae344819a490f01d2d614"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "cce88973775c604bee792a81ad50cba6553e254972c5f9bdba5e54a9e3d8a733"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\native-frame-inventory.json": {
      "bytes": 26531,
      "sha256": "d4da6e74d28c24a0d5fd2c24e94a29f3253fb3ef31dd9db6d9c08981fb2ce37d"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\parse.log": {
      "bytes": 75,
      "sha256": "83cf0b082206af2aa236c83064fbcfa76be1e00a4aa3558574b2f65965d9481c"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\passage-report.json": {
      "bytes": 2054,
      "sha256": "287f1f9ba09cc70641ee6112b8df47cee4361eb01d2b332ec7d895f4bef9e53b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\production-report.json": {
      "bytes": 559251,
      "sha256": "2b1628cde89461d9aeef45a1a43ab07e3ef1bd72bc6429e26067c6a8bbddc7ad"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\receipt.json": {
      "bytes": 54537,
      "sha256": "05f0ac608a565e4a4abd248b67e217e357dd70f02064058643cf0bf017b29420"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\source-hashes.json": {
      "bytes": 15926,
      "sha256": "2d3c2674c076378ccca95dff735ea65bcf3b366d39cd0c735ab23bfc18352630"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103507174781Z\\start-provenance.json": {
      "bytes": 697,
      "sha256": "1cb247397bb66bdd2615b33e20bd840fdb7b5f2d66e50685e2e3a0b13e9a8617"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 8561,
      "sha256": "10e64383411f1bfc1ecc9fb720330dd335b1178d2f0cc472c714c3b9a1315d64"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot2026-10-24T06.39.01.log": {
      "bytes": 73,
      "sha256": "6d1c065383a27c36804949b6ffa4b09714470b112e5dacc0bd5aeb7b9c147c4e"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\CanvasShaderGLES3\\5c2a443430aed63756000ed4fdb23f02b8d89e1b28bd9ba01ddd60635f2085ac\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 32624,
      "sha256": "d3f8b527c60012184699aab6a619cd2bc2da20a2d2ec405276de5c45323d671b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\CopyShaderGLES3\\b69dbe566cf70bccd27fd9bee4f59d5f4c3b4b0bf0afc490c771cad63be608ad\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 118055,
      "sha256": "c985fe48f72420ad04dea8f22eb6874b2fbb3bfc0017929b160d77607e1f9dec"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\FeedShaderGLES3\\04959e861c350b844d43ff6438c41d016246b8bb1c7ce08d02bc8891823f37dc\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 8261,
      "sha256": "fb18886da7abd643668372473c2c3abd4314577668542b9ce86b1adbbe2e6290"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\PostShaderGLES3\\1548e0d952e335627b9be9dd73291d4d4e68ba4a81fafbfb14e7a07898d5c9c1\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 13656,
      "sha256": "daffd1b699be80fcca6372707fabec0961078177a484c2e341b760e386446c19"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\2115c615c01c3a0177be29c6ddcef01907dcf654.cache": {
      "bytes": 758243,
      "sha256": "e8cca19e21e59ad630bdae19dd8516e96799c5d3be36246b166dc1eb9209ecb6"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 800909,
      "sha256": "58e6c14565433f0e4234254193a4ddb835a697026cf671826be2d45a6930e3de"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\75dbda390b4d6b8d1bba67e8943ace8a4f64f756.cache": {
      "bytes": 932568,
      "sha256": "30e807fde2bc1be565619d740337d202e55a60ca990938df33765a0737df0d99"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\77047cd41f429f33ceff24e890e174f5465e755e.cache": {
      "bytes": 822095,
      "sha256": "020bea6a61c07107ab2e74b83cf7e508695ce3fabd639dfc9ded9731fc004cbf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\f2e328ac8a780a17a0c65e242b0c8bc4fc063f03.cache": {
      "bytes": 932126,
      "sha256": "622924e0a58b9e1c51f89bd6d9f8b48e2816033f384c9d16f151bb97f82573a3"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SkeletonShaderGLES3\\970fe26b11b78d44548b61268ebac68162e1323b4486fac1e64104917f487957\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 28067,
      "sha256": "db101e632eef9ce52f26b2186bc4121d334aa355936df425dc1f6fc9f6e0a6f3"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\continuous.mp4": {
      "bytes": 359408,
      "sha256": "1442eb3167bdc6f3b8f4df30d7f321fc463f37305c5d0cb3f7098bc180137d7a"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\decode.log": {
      "bytes": 0,
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\encode.log": {
      "bytes": 0,
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\execution.log": {
      "bytes": 9319,
      "sha256": "20097b8e22d1d6ce7f23b3982bf248c14bf124fd1b1f4c3c0fdf6162520163aa"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "cce88973775c604bee792a81ad50cba6553e254972c5f9bdba5e54a9e3d8a733"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\native-frame-inventory.json": {
      "bytes": 26531,
      "sha256": "d4da6e74d28c24a0d5fd2c24e94a29f3253fb3ef31dd9db6d9c08981fb2ce37d"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\parse.log": {
      "bytes": 75,
      "sha256": "83cf0b082206af2aa236c83064fbcfa76be1e00a4aa3558574b2f65965d9481c"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\passage-report.json": {
      "bytes": 2054,
      "sha256": "287f1f9ba09cc70641ee6112b8df47cee4361eb01d2b332ec7d895f4bef9e53b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\production-report.json": {
      "bytes": 559251,
      "sha256": "2b1628cde89461d9aeef45a1a43ab07e3ef1bd72bc6429e26067c6a8bbddc7ad"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\receipt.json": {
      "bytes": 54539,
      "sha256": "126c9dd2ce3e8065aceb0a4d14b0a82960f94602aa12bda61ef14cf730d1b451"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\source-hashes.json": {
      "bytes": 15926,
      "sha256": "2d3c2674c076378ccca95dff735ea65bcf3b366d39cd0c735ab23bfc18352630"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T103854613061Z\\start-provenance.json": {
      "bytes": 697,
      "sha256": "1cb247397bb66bdd2615b33e20bd840fdb7b5f2d66e50685e2e3a0b13e9a8617"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 8561,
      "sha256": "10e64383411f1bfc1ecc9fb720330dd335b1178d2f0cc472c714c3b9a1315d64"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot2026-10-24T06.59.18.log": {
      "bytes": 555,
      "sha256": "ab4c9ed8136f8046e127be37a8c893aee23862d197b11f60d949872969b00763"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\CanvasShaderGLES3\\5c2a443430aed63756000ed4fdb23f02b8d89e1b28bd9ba01ddd60635f2085ac\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 32624,
      "sha256": "f841453f199bd52426f22dab6a206ef718cb810132c9541404cbfcd091988879"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\CopyShaderGLES3\\b69dbe566cf70bccd27fd9bee4f59d5f4c3b4b0bf0afc490c771cad63be608ad\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 118055,
      "sha256": "b8751eeaa7b4483f942f1e7426b4ecaad152829f2deac49cfe645bb0b20ee080"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\FeedShaderGLES3\\04959e861c350b844d43ff6438c41d016246b8bb1c7ce08d02bc8891823f37dc\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 8261,
      "sha256": "f61bd07a8de2a73c4da7b754281bf9546155af232844ff90431b9c26c46872cf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\PostShaderGLES3\\1548e0d952e335627b9be9dd73291d4d4e68ba4a81fafbfb14e7a07898d5c9c1\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 13656,
      "sha256": "9661313f90fd5e39675197f031af310a1d3895ad158e4f858267b26edf4f2270"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\2115c615c01c3a0177be29c6ddcef01907dcf654.cache": {
      "bytes": 758243,
      "sha256": "abce2a725b00cb51660984ea6292fc85ba3c282edca77bd224d87e26dacc7dd2"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 800909,
      "sha256": "4f64c462ae9a56efe65268afa7f00857b2d87e3e2e518fcd80a010d1a42e8f58"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\75dbda390b4d6b8d1bba67e8943ace8a4f64f756.cache": {
      "bytes": 932568,
      "sha256": "54ebbdb1ef1a63867d125a5028f9de139864632c05f0e3d8c9f6bee5659cde90"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\77047cd41f429f33ceff24e890e174f5465e755e.cache": {
      "bytes": 822095,
      "sha256": "57a140fa4e0ac1a2b96d362527499dd1fc3a963a4d32a222933ad1bba947ac14"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SceneShaderGLES3\\9b19357dfa9172b7542ea3efeae4577941551fce5e92f1e1ab4a23c720ad45ac\\f2e328ac8a780a17a0c65e242b0c8bc4fc063f03.cache": {
      "bytes": 932126,
      "sha256": "26b86e6aef905ad3b881b87a163c47135a3414a12f23bf823cfc8018a8baaac2"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\appdata\\Godot\\app_userdata\\Hearthguard\\shader_cache\\SkeletonShaderGLES3\\970fe26b11b78d44548b61268ebac68162e1323b4486fac1e64104917f487957\\6bb7c9a2fd1c4a8fa77cb96555b9b4a720209981.cache": {
      "bytes": 28067,
      "sha256": "106e321acfae8f13bbe92ed48f9500ef56e3c840271c6aec1b004a001f89dea9"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\continuous.mp4": {
      "bytes": 359408,
      "sha256": "1442eb3167bdc6f3b8f4df30d7f321fc463f37305c5d0cb3f7098bc180137d7a"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\decode.log": {
      "bytes": 0,
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\encode.log": {
      "bytes": 0,
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\execution.log": {
      "bytes": 8847,
      "sha256": "3846454c319b54a2aac4634517164c7e64ca1c9a5aedf5004f71383ea640091e"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\frame-retention.json": {
      "bytes": 8767,
      "sha256": "f353291a1ad2eb602cc83f372a060c33d7f6ae56a9d442439b2985196083976a"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "cce88973775c604bee792a81ad50cba6553e254972c5f9bdba5e54a9e3d8a733"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\native-frame-inventory.json": {
      "bytes": 26531,
      "sha256": "d4da6e74d28c24a0d5fd2c24e94a29f3253fb3ef31dd9db6d9c08981fb2ce37d"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\parse.log": {
      "bytes": 719,
      "sha256": "1012e588c1761227229df42f77dede434faf83f3c68fd16f977733be0e681444"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\passage-report.json": {
      "bytes": 2487,
      "sha256": "d61acbe22b5d223c35afdd5f06a244564884cc3799e62ae3b7ace05fde08492e"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\production-report.json": {
      "bytes": 559916,
      "sha256": "4844e68dcd26f8e86a045cc7a63919bad679b22930f3fdd69631fd33ec5bf0a7"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\receipt.json": {
      "bytes": 54480,
      "sha256": "6af3f94d2a77d24e2b0b3e822e1f43ae4c797c0a513a998e1f7caf05b9877328"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\source-hashes.json": {
      "bytes": 15926,
      "sha256": "75731c42c75b49a3518856c5855db3a9d4a2ac72fa71c9685a3b103d6853509b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T105909769686Z\\start-provenance.json": {
      "bytes": 697,
      "sha256": "1cb247397bb66bdd2615b33e20bd840fdb7b5f2d66e50685e2e3a0b13e9a8617"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\appdata\\Godot\\app_userdata\\Hearthguard\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot.log": {
      "bytes": 6651,
      "sha256": "61ad9a203ee2f81cd369ec4c783a26624b834d257e28bd7c06bf19ad7c84b8f2"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\appdata\\Godot\\app_userdata\\Hearthguard\\logs\\godot2026-10-24T07.01.16.log": {
      "bytes": 555,
      "sha256": "ab4c9ed8136f8046e127be37a8c893aee23862d197b11f60d949872969b00763"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\execution.log": {
      "bytes": 6869,
      "sha256": "4ebe6611367c6962d779c318adf23d1c1051dcd36ef08048e71817fda645a62d"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "cce88973775c604bee792a81ad50cba6553e254972c5f9bdba5e54a9e3d8a733"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\parse.log": {
      "bytes": 719,
      "sha256": "1012e588c1761227229df42f77dede434faf83f3c68fd16f977733be0e681444"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\passage-report.json": {
      "bytes": 2487,
      "sha256": "d61acbe22b5d223c35afdd5f06a244564884cc3799e62ae3b7ace05fde08492e"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\production-report.json": {
      "bytes": 343749,
      "sha256": "09e6bb9f27a8749bf476f770564ee2fb928401f704ceb3e3760ebb1a12306be6"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\receipt.json": {
      "bytes": 14487,
      "sha256": "92bbb82903c211252c4a3b44c6198fbb38929e242eac60964d04530fe646f9bb"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\slots\\final\\hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\slots\\final\\hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\source-hashes.json": {
      "bytes": 15926,
      "sha256": "75731c42c75b49a3518856c5855db3a9d4a2ac72fa71c9685a3b103d6853509b"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T110108730789Z\\start-provenance.json": {
      "bytes": 697,
      "sha256": "1cb247397bb66bdd2615b33e20bd840fdb7b5f2d66e50685e2e3a0b13e9a8617"
    },
    "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\verbose_preview_diagnostic.py": {
      "bytes": 628,
      "sha256": "5147e2633b7e77b95dba2b2f969571443f538bd61b8b78bf71bea935841ff2ff"
    }
  },
  "review_status": "Actual two-file source/focused CPU clearance received; final artifact/base-map checkpoint audit pending. No additional source changes."
}
```
