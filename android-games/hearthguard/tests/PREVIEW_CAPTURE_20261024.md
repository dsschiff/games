# Hearth build-preview matched capture preparation

This harness-only increment extends the existing production runner. Product files,
version0.3.1/code5, rules, catalog, saves and the frozen BUILD_PREVIEW checkpoint
remain unchanged. Historical production recipes retain their042d7c2 runtime freeze,
import behavior and parser; preview options cannot silently change those recipes.
An actual historical opening command fails that old freeze before Godot on the
current runtime. The deliberate expected baseline condition is no prospective
empty-pad ring; candidate presence is separately asserted.

Preview requires explicit `--cached --preview-variant before|after` and either
`--cpu` or `--render --native-frames`. Both use normal30fps process frames and
60Hz rule updates; no state injection, physics disabling, accelerated lead-in,
clipboard or import. Dummy audio is explicit. Preview snapshots only observe
state, with no renderer-only wait. Parse and execution reject all raw warnings,
errors, ObjectDB leaks and crash markers. Complete104-file eligible tracked Git
runtime path sets are checked, including missing paths; binary files are exact
and source text uses only the historical LF/CRLF equivalence policy.

The single9.06MB ignored baseline project is retained at
`F:/games-workspaces/hearth-preview-capture-20261024/.artifacts/matched-baseline-be6423c/project`.
It contains exactbe6423c Git files, the identical three new harness files and a
byte-verified small imported cache. Its manifest binds every original Git blob,
harness override and cache file. Keep this one necessary project until the
coordinator finishes and verifies matched captures; it is not an alternate app.

## Actual input passages

Opening: fresh isolated user data, production main.tscn/bootstrap owner, actual
Begin, joystick collection of all18 opening gold, actual approach to empty pad2.
The recorded passage waits30 process frames, holds the eligible Beacon button
46 frames including its press, drags off and releases, waits30 frames, quick-taps
once, then lingers90 frames on the ordinary occupied-pad ring. Normal combat and
autosaves continue. Press and cancel are checked against pure-rule continuation;
no-preview-save test from the prior frozen CPU suite is not misrepresented as
unchanged disk during a live autosaving capture.

Boss: a separate exact authenticated historical map3 restoration, not uninterrupted
fresh play. The original map03-invest06-saves.json and accepted receipt are resolved
in the explicit original artifact root; archive, selected code, checksum and
revision220 all verify. Ordinary policy input advances from79.9667s to live Ram,
actual joystick approaches an occupied pad, and actual paid Sell releases it at
129.7s with32 gold. The same hold/cancel/quick-tap passage uses Bolt and retains the
truthful RAM warning. No avatar-position or economy edits make the shot possible.

Each CPU pair passes17/0 opening and22/0 boss checks. Full start/end contexts,
all eight complete timeline contexts/app-written packets,138/2982 raw input
events, process/physics counts and final raw save bytes match exactly across the
pair. No save fields are masked or normalized. Only campaign_main.gd and
presentation/settlement.gd differ in the104-file runtime source comparison.
The six actual preflight guards include a temporarily absent baseline model,
restored byte-exactly. An initial cwd-relative Git-tree preflight failed closed;
its exact raw log and original runner are retained, then --full-tree corrected
only the harness query.

## Coordinator commands after source audit and explicit render grant

Run from `F:/games-workspaces/hearth-preview-capture-20261024`. The CPU equivalents
replace `--render --native-frames` with `--cpu`; all keep `--cached`.

```powershell
python -B .artifacts/matched-baseline-be6423c/project/tests/run_production.py preview-opening --cached --preview-variant before --render --native-frames
python -B android-games/hearthguard/tests/run_production.py preview-opening --cached --preview-variant after --render --native-frames
python -B .artifacts/matched-baseline-be6423c/project/tests/run_production.py preview-boss --cached --preview-variant before --render --native-frames --earned-root C:/projects/active/_worktrees/games-hearthguard-20261018/android-games/hearthguard
python -B android-games/hearthguard/tests/run_production.py preview-boss --cached --preview-variant after --render --native-frames --earned-root C:/projects/active/_worktrees/games-hearthguard-20261018/android-games/hearthguard
```

Execute strictly serially. Each visible passage is approximately200 frames/6.7s;
actual native inventories and probe determine final frame counts. The boss has
about49.7s of declared normal-input unrecorded lead-in. Existing native720x1280
PNG capture avoids the historically rejected internal450x800 AVI writer. There
is no AVI/WAV. Encode at30fps with no scaling/retiming, fully decode, probe/hash,
retain selected representative original PNGs and their frame hashes, then remove
verified superseded raw PNGs before the next capture. The existing runner records
every raw frame hash; cleanup is an explicit post-verification coordinator action.
Preserve raw failures. Compare matched input/context/timing again for rendered
runs; headless parity does not guarantee renderer parity.

Independent normal1x review should inspect empty-pad hold, off-button cancel,
one purchase/occupied ring, boss-warning separation and usable footers. Fixed
cadence is not host/phone FPS. Appearance, legibility, Android, physical phone,
human discoverability/comfort/fun and audio acceptance remain open. No rendering
or device execution has occurred for this new harness. Root owns the render slot.

## Frozen CPU checkpoint

```json
{
  "base": "b38fa2e67d5578b39c55ce89e15aef9b417bd0e5",
  "runtime_freezes": {
    "before": "be6423c7ecc12db4b3f8b1c3405902b73e976d82",
    "after": "d27f03c8354f855da694965d41448ce811f09ff9"
  },
  "harness_raw_sha256": {
    "tests/run_production.py": "23cac46e9c57b64f519725d2492555582c010df0a4a314dce71399c1c0029e85",
    "tests/production_passage.gd": "50565befa30cd435fb27c298b9921b040772036265be72e19ff7f66676c45b50",
    "tests/production_sources.py": "56cac1f9bf1184d7bfe9af497b09cf9fe932c8d52d96229cd3afd53802096a44"
  },
  "pairs": [
    {
      "stage": "preview-opening",
      "before": "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-opening-20261024T093657287108Z",
      "after": "F:\\games-workspaces\\hearth-preview-capture-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-opening-20261024T093821987201Z",
      "checks_before": 17,
      "checks_after": 17,
      "input_events": 138,
      "raw_input_equal": true,
      "complete_start_end_equal": true,
      "timeline_keys_exact": [
        "label",
        "process_frame",
        "relative_frame",
        "physics_frame",
        "relative_physics_frame",
        "simulation_seconds",
        "whole_context",
        "app_written"
      ],
      "timeline": [
        {
          "label": "loaded-boundary",
          "process_frame": 2,
          "relative_frame": 2,
          "physics_frame": 5,
          "relative_physics_frame": 5,
          "simulation_seconds": 0.0
        },
        {
          "label": "prepared-empty-pad",
          "process_frame": 67,
          "relative_frame": 67,
          "physics_frame": 135,
          "relative_physics_frame": 135,
          "simulation_seconds": 2.13333333333333
        },
        {
          "label": "before-hold",
          "process_frame": 97,
          "relative_frame": 30,
          "physics_frame": 195,
          "relative_physics_frame": 60,
          "simulation_seconds": 3.13333333333333
        },
        {
          "label": "held-before-cancel",
          "process_frame": 143,
          "relative_frame": 76,
          "physics_frame": 287,
          "relative_physics_frame": 152,
          "simulation_seconds": 4.66666666666666
        },
        {
          "label": "canceled-no-purchase",
          "process_frame": 175,
          "relative_frame": 108,
          "physics_frame": 351,
          "relative_physics_frame": 216,
          "simulation_seconds": 5.73333333333332
        },
        {
          "label": "one-ordinary-purchase",
          "process_frame": 177,
          "relative_frame": 110,
          "physics_frame": 355,
          "relative_physics_frame": 220,
          "simulation_seconds": 5.79999999999998
        },
        {
          "label": "occupied-range-linger",
          "process_frame": 267,
          "relative_frame": 200,
          "physics_frame": 535,
          "relative_physics_frame": 400,
          "simulation_seconds": 8.80000000000002
        },
        {
          "label": "final-held-boundary",
          "process_frame": 271,
          "relative_frame": 204,
          "physics_frame": 543,
          "relative_physics_frame": 408,
          "simulation_seconds": 8.90000000000002
        }
      ],
      "raw_final_slot_bytes_equal": true,
      "raw_final_slot_sha256": {
        "final/hearth-save-0": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf",
        "final/hearth-save-1": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
      },
      "runtime_tracked_count": 104,
      "only_runtime_differences_lf": [
        "scripts/campaign_main.gd",
        "scripts/presentation/settlement.gd"
      ],
      "source_maps_before_after_equal": true,
      "receipt_sha256": {
        "before": "4965594d8cda3bdb092538f1f22a60303d9dc0a822f9a5c5ad5d17ba5f8f9a28",
        "after": "726891d3e27cddf62481d992f7615bf2a411ac0aef8e124e2825adc97f4be262"
      }
    },
    {
      "stage": "preview-boss",
      "before": "F:\\games-workspaces\\hearth-preview-capture-20261024\\.artifacts\\matched-baseline-be6423c\\project\\.artifacts\\production-preview-boss-20261024T093906930969Z",
      "after": "F:\\games-workspaces\\hearth-preview-capture-20261024\\android-games\\hearthguard\\.artifacts\\production-preview-boss-20261024T093920049812Z",
      "checks_before": 22,
      "checks_after": 22,
      "input_events": 2982,
      "raw_input_equal": true,
      "complete_start_end_equal": true,
      "timeline_keys_exact": [
        "label",
        "process_frame",
        "relative_frame",
        "physics_frame",
        "relative_physics_frame",
        "simulation_seconds",
        "whole_context",
        "app_written"
      ],
      "timeline": [
        {
          "label": "loaded-boundary",
          "process_frame": 2,
          "relative_frame": 2,
          "physics_frame": 5,
          "relative_physics_frame": 5,
          "simulation_seconds": 79.9666666666634
        },
        {
          "label": "prepared-empty-pad",
          "process_frame": 1495,
          "relative_frame": 1495,
          "physics_frame": 2991,
          "relative_physics_frame": 2991,
          "simulation_seconds": 129.699999999995
        },
        {
          "label": "before-hold",
          "process_frame": 1525,
          "relative_frame": 30,
          "physics_frame": 3051,
          "relative_physics_frame": 60,
          "simulation_seconds": 130.699999999996
        },
        {
          "label": "held-before-cancel",
          "process_frame": 1571,
          "relative_frame": 76,
          "physics_frame": 3143,
          "relative_physics_frame": 152,
          "simulation_seconds": 132.233333333331
        },
        {
          "label": "canceled-no-purchase",
          "process_frame": 1603,
          "relative_frame": 108,
          "physics_frame": 3207,
          "relative_physics_frame": 216,
          "simulation_seconds": 133.299999999998
        },
        {
          "label": "one-ordinary-purchase",
          "process_frame": 1605,
          "relative_frame": 110,
          "physics_frame": 3211,
          "relative_physics_frame": 220,
          "simulation_seconds": 133.366666666665
        },
        {
          "label": "occupied-range-linger",
          "process_frame": 1695,
          "relative_frame": 200,
          "physics_frame": 3391,
          "relative_physics_frame": 400,
          "simulation_seconds": 136.366666666667
        },
        {
          "label": "final-held-boundary",
          "process_frame": 1699,
          "relative_frame": 204,
          "physics_frame": 3399,
          "relative_physics_frame": 408,
          "simulation_seconds": 136.466666666667
        }
      ],
      "raw_final_slot_bytes_equal": true,
      "raw_final_slot_sha256": {
        "final/hearth-save-0": "29b228e8e08df10203c0dfaba4cd84c2d635dc715de605580acf53984b51e7cd",
        "final/hearth-save-1": "2849b2d96d6a598b4eae87662da77ca6027398af4ef7f3414c6d581a42fece7f"
      },
      "runtime_tracked_count": 104,
      "only_runtime_differences_lf": [
        "scripts/campaign_main.gd",
        "scripts/presentation/settlement.gd"
      ],
      "source_maps_before_after_equal": true,
      "receipt_sha256": {
        "before": "dbdf050bd2eb724ec971b668c1cf1c3e52aff19612f31d9230d9bf79aa4dd812",
        "after": "e859ecbf30e11d0cffb3859534a271851084b2276484fbd728d4333807d2cc06"
      }
    }
  ],
  "guards": {
    "passed": true,
    "checks": 6,
    "rows": [
      {
        "label": "old-recipe-rejects-cached",
        "command": [
          "python",
          "-B",
          "F:\\games-workspaces\\hearth-preview-capture-20261024\\android-games\\hearthguard\\tests\\run_production.py",
          "opening",
          "--cached",
          "--cpu"
        ],
        "exit_code": 2,
        "log_sha256": "651d0b128becd9b61b75e215b2bb2b3e637289a2f16d6ab1317cdef2dac7fae0"
      },
      {
        "label": "preview-requires-variant",
        "command": [
          "python",
          "-B",
          "F:\\games-workspaces\\hearth-preview-capture-20261024\\android-games\\hearthguard\\tests\\run_production.py",
          "preview-opening",
          "--cpu",
          "--cached"
        ],
        "exit_code": 2,
        "log_sha256": "e4f4b421046d979f0503273224a18c27fa9a9f934b52280e234c4044b2f7bf63"
      },
      {
        "label": "cpu-render-mutually-exclusive",
        "command": [
          "python",
          "-B",
          "F:\\games-workspaces\\hearth-preview-capture-20261024\\android-games\\hearthguard\\tests\\run_production.py",
          "preview-opening",
          "--cpu",
          "--render",
          "--native-frames",
          "--cached",
          "--preview-variant",
          "after"
        ],
        "exit_code": 2,
        "log_sha256": "d2179fc739fecb3d133fe768651b8821abce29c5432a8e9b8d063fea947a131c"
      },
      {
        "label": "fresh-rejects-earned",
        "command": [
          "python",
          "-B",
          "F:\\games-workspaces\\hearth-preview-capture-20261024\\android-games\\hearthguard\\tests\\run_production.py",
          "preview-opening",
          "--cpu",
          "--cached",
          "--preview-variant",
          "after",
          "--earned-root",
          "F:\\games-workspaces\\hearth-preview-capture-20261024\\android-games\\hearthguard"
        ],
        "exit_code": 2,
        "log_sha256": "90b000b8ffe4087ebe626ee9c66ac6ef73d80d926b29c787d2375c0d48bb5f90"
      },
      {
        "label": "missing-runtime-model-rejected",
        "command": [
          "python",
          "-B",
          "-c",
          "import sys;sys.path.insert(0,'F:\\\\games-workspaces\\\\hearth-preview-capture-20261024\\\\.artifacts\\\\matched-baseline-be6423c\\\\project\\\\tests');import run_production as r;r.preview_runtime_freeze(r.PREVIEW_FREEZES[\"before\"])"
        ],
        "exit_code": 1,
        "log_sha256": "75ce13df33aac74d971c1c67332ab8efa0e96d430532a1f46026089006fe8640"
      },
      {
        "label": "historical-recipe-retains-old-freeze",
        "command": [
          "python",
          "-B",
          "F:\\games-workspaces\\hearth-preview-capture-20261024\\android-games\\hearthguard\\tests\\run_production.py",
          "opening",
          "--render",
          "--native-frames",
          "--seconds",
          "1"
        ],
        "exit_code": 1,
        "log_sha256": "c08505f6036ef09e78ed6217b46c6c1fcb6519c741a16281f677f8fa3977be8d"
      }
    ],
    "runtime_model_restored_sha256": "5c253fb3e89f954265b8039690178ea7706af09cd83a1470a7f35046810975c5",
    "scope": "Actual parser calls and absent tracked runtime model in the single ignored baseline; failed closed before Godot; original model restored byte-exactly."
  },
  "retained_artifacts": {
    ".artifacts/matched-baseline-be6423c/baseline-bindings.json": {
      "bytes": 35558,
      "sha256": "68ce37e5f8a10cdbf1de821116346b5bfcc6bec9ac42855413f6bc2ddbc2ca9c"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/appdata/Godot/app_userdata/Hearthguard/hearth-save-0": {
      "bytes": 13865,
      "sha256": "29b228e8e08df10203c0dfaba4cd84c2d635dc715de605580acf53984b51e7cd"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/appdata/Godot/app_userdata/Hearthguard/hearth-save-1": {
      "bytes": 13878,
      "sha256": "2849b2d96d6a598b4eae87662da77ca6027398af4ef7f3414c6d581a42fece7f"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/appdata/Godot/app_userdata/Hearthguard/logs/godot.log": {
      "bytes": 94,
      "sha256": "0ce6170b0a490f0ec24061f20698b02eaa1b2047aa54fab03198bc1faa2214e5"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/appdata/Godot/app_userdata/Hearthguard/logs/godot2026-10-24T05.39.14.log": {
      "bytes": 73,
      "sha256": "6d1c065383a27c36804949b6ffa4b09714470b112e5dacc0bd5aeb7b9c147c4e"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/execution.log": {
      "bytes": 97,
      "sha256": "f11ca6651ba2693a8df7f423b01dddc43ee6167a84942e80b393fbf677f68240"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/expected-start.code": {
      "bytes": 13666,
      "sha256": "db142f65ac4483afdbff0172fcabfa8c90cbecb09907a375afe114441f54bbf3"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/expected-start.json": {
      "bytes": 26686,
      "sha256": "22527e0d970b5c3ee8efa843b4b89385b8f3d67245e27758ccf16811a5b22b83"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "cce88973775c604bee792a81ad50cba6553e254972c5f9bdba5e54a9e3d8a733"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/parse.log": {
      "bytes": 75,
      "sha256": "83cf0b082206af2aa236c83064fbcfa76be1e00a4aa3558574b2f65965d9481c"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/passage-report.json": {
      "bytes": 2566,
      "sha256": "bcc87e04598bf47618235c787c38e1941965f033439ce8abad58b78142ab6be2"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/production-report.json": {
      "bytes": 456721,
      "sha256": "b992a10251feb495aee6762fab8d27e3cff0f7b0460835ec82c39d73f922c0ef"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/raw-input-events.json": {
      "bytes": 287527,
      "sha256": "81950ea008bdc343e3c1632eb917c7267bdcaf1f75919beb9d4dcb668677feca"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/receipt.json": {
      "bytes": 17005,
      "sha256": "dbdf050bd2eb724ec971b668c1cf1c3e52aff19612f31d9230d9bf79aa4dd812"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/slots/final/hearth-save-0": {
      "bytes": 13865,
      "sha256": "29b228e8e08df10203c0dfaba4cd84c2d635dc715de605580acf53984b51e7cd"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/slots/final/hearth-save-1": {
      "bytes": 13878,
      "sha256": "2849b2d96d6a598b4eae87662da77ca6027398af4ef7f3414c6d581a42fece7f"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/source-hashes.json": {
      "bytes": 15926,
      "sha256": "2d3c2674c076378ccca95dff735ea65bcf3b366d39cd0c735ab23bfc18352630"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-boss-20261024T093906930969Z/start-provenance.json": {
      "bytes": 2656,
      "sha256": "73aeb6c39fe4857bd0a8a0b2ad2e3869341da332b216ca03709fee5cf15dd6cc"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/appdata/Godot/app_userdata/Hearthguard/hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/appdata/Godot/app_userdata/Hearthguard/hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/appdata/Godot/app_userdata/Hearthguard/logs/godot.log": {
      "bytes": 94,
      "sha256": "0ce6170b0a490f0ec24061f20698b02eaa1b2047aa54fab03198bc1faa2214e5"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/appdata/Godot/app_userdata/Hearthguard/logs/godot2026-10-24T05.37.05.log": {
      "bytes": 73,
      "sha256": "6d1c065383a27c36804949b6ffa4b09714470b112e5dacc0bd5aeb7b9c147c4e"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/execution.log": {
      "bytes": 97,
      "sha256": "f11ca6651ba2693a8df7f423b01dddc43ee6167a84942e80b393fbf677f68240"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "cce88973775c604bee792a81ad50cba6553e254972c5f9bdba5e54a9e3d8a733"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/parse.log": {
      "bytes": 75,
      "sha256": "83cf0b082206af2aa236c83064fbcfa76be1e00a4aa3558574b2f65965d9481c"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/passage-report.json": {
      "bytes": 2054,
      "sha256": "287f1f9ba09cc70641ee6112b8df47cee4361eb01d2b332ec7d895f4bef9e53b"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/production-report.json": {
      "bytes": 343084,
      "sha256": "bfa405b637fafad24c770afcd4bb74af386c5734a8e0a3427cfe456f157a596b"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/receipt.json": {
      "bytes": 14441,
      "sha256": "4965594d8cda3bdb092538f1f22a60303d9dc0a822f9a5c5ad5d17ba5f8f9a28"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/slots/final/hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/slots/final/hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/source-hashes.json": {
      "bytes": 15926,
      "sha256": "2d3c2674c076378ccca95dff735ea65bcf3b366d39cd0c735ab23bfc18352630"
    },
    ".artifacts/matched-baseline-be6423c/project/.artifacts/production-preview-opening-20261024T093657287108Z/start-provenance.json": {
      "bytes": 697,
      "sha256": "1cb247397bb66bdd2615b33e20bd840fdb7b5f2d66e50685e2e3a0b13e9a8617"
    },
    ".artifacts/preview-harness-guards-20261024/cpu-render-mutually-exclusive.log": {
      "bytes": 605,
      "sha256": "d2179fc739fecb3d133fe768651b8821abce29c5432a8e9b8d063fea947a131c"
    },
    ".artifacts/preview-harness-guards-20261024/fresh-rejects-earned.log": {
      "bytes": 589,
      "sha256": "90b000b8ffe4087ebe626ee9c66ac6ef73d80d926b29c787d2375c0d48bb5f90"
    },
    ".artifacts/preview-harness-guards-20261024/guards.json": {
      "bytes": 3238,
      "sha256": "a1aade13ec52daef89e3b9bec2f81dce914e18a37fa52a83bc60faf84fc4e747"
    },
    ".artifacts/preview-harness-guards-20261024/historical-recipe-retains-old-freeze.log": {
      "bytes": 1025,
      "sha256": "c08505f6036ef09e78ed6217b46c6c1fcb6519c741a16281f677f8fa3977be8d"
    },
    ".artifacts/preview-harness-guards-20261024/matched-cpu.json": {
      "bytes": 7476,
      "sha256": "df8e73f1cec587f424b92fcb25c8bf5add2311cf08b5f4a55ead6cf7abc2ad27"
    },
    ".artifacts/preview-harness-guards-20261024/missing-runtime-model-rejected.log": {
      "bytes": 510,
      "sha256": "75ce13df33aac74d971c1c67332ab8efa0e96d430532a1f46026089006fe8640"
    },
    ".artifacts/preview-harness-guards-20261024/old-recipe-rejects-cached.log": {
      "bytes": 621,
      "sha256": "651d0b128becd9b61b75e215b2bb2b3e637289a2f16d6ab1317cdef2dac7fae0"
    },
    ".artifacts/preview-harness-guards-20261024/original-relative-git-tree-failure.json": {
      "bytes": 553,
      "sha256": "8da023c2ddf88e59223d308200fc83b6da77bddc963a9f43ab82525b710eaa1e"
    },
    ".artifacts/preview-harness-guards-20261024/original-relative-git-tree-failure.log": {
      "bytes": 4156,
      "sha256": "7bdd2c0b9943f792bcfd2dab89e05de0c3df1e08dffdb1f4f98c453337457595"
    },
    ".artifacts/preview-harness-guards-20261024/original-relative-git-tree-runner.py": {
      "bytes": 17973,
      "sha256": "f631e7f9c2821f9e9199b1dff303ad9f88849ddfe74334c0295a1bddd7cd08a3"
    },
    ".artifacts/preview-harness-guards-20261024/preview-requires-variant.log": {
      "bytes": 626,
      "sha256": "e4f4b421046d979f0503273224a18c27fa9a9f934b52280e234c4044b2f7bf63"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/appdata/Godot/app_userdata/Hearthguard/hearth-save-0": {
      "bytes": 13865,
      "sha256": "29b228e8e08df10203c0dfaba4cd84c2d635dc715de605580acf53984b51e7cd"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/appdata/Godot/app_userdata/Hearthguard/hearth-save-1": {
      "bytes": 13878,
      "sha256": "2849b2d96d6a598b4eae87662da77ca6027398af4ef7f3414c6d581a42fece7f"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/appdata/Godot/app_userdata/Hearthguard/logs/godot.log": {
      "bytes": 94,
      "sha256": "0ce6170b0a490f0ec24061f20698b02eaa1b2047aa54fab03198bc1faa2214e5"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/appdata/Godot/app_userdata/Hearthguard/logs/godot2026-10-24T05.39.27.log": {
      "bytes": 73,
      "sha256": "6d1c065383a27c36804949b6ffa4b09714470b112e5dacc0bd5aeb7b9c147c4e"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/execution.log": {
      "bytes": 97,
      "sha256": "f11ca6651ba2693a8df7f423b01dddc43ee6167a84942e80b393fbf677f68240"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/expected-start.code": {
      "bytes": 13666,
      "sha256": "db142f65ac4483afdbff0172fcabfa8c90cbecb09907a375afe114441f54bbf3"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/expected-start.json": {
      "bytes": 26686,
      "sha256": "22527e0d970b5c3ee8efa843b4b89385b8f3d67245e27758ccf16811a5b22b83"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "a14c4946e8b24a6e693fa5e425ca04b02613170991f5f4cc9d0b7ff1210f8113"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/parse.log": {
      "bytes": 75,
      "sha256": "83cf0b082206af2aa236c83064fbcfa76be1e00a4aa3558574b2f65965d9481c"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/passage-report.json": {
      "bytes": 2582,
      "sha256": "cb6d1b0bf10ed5dc59d9c54733d32d41ef4ce82c52fea5249c85a444546fbacf"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/production-report.json": {
      "bytes": 457091,
      "sha256": "6c266ec8209908b03dffddffac1a6a9f40a8264c2a45088bf513315b2ee7e133"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/raw-input-events.json": {
      "bytes": 287527,
      "sha256": "81950ea008bdc343e3c1632eb917c7267bdcaf1f75919beb9d4dcb668677feca"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/receipt.json": {
      "bytes": 16927,
      "sha256": "e859ecbf30e11d0cffb3859534a271851084b2276484fbd728d4333807d2cc06"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/slots/final/hearth-save-0": {
      "bytes": 13865,
      "sha256": "29b228e8e08df10203c0dfaba4cd84c2d635dc715de605580acf53984b51e7cd"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/slots/final/hearth-save-1": {
      "bytes": 13878,
      "sha256": "2849b2d96d6a598b4eae87662da77ca6027398af4ef7f3414c6d581a42fece7f"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/source-hashes.json": {
      "bytes": 16228,
      "sha256": "668f76335a4b5be3b610dca5b9324130ec8076cfa7dc71a1f4bc4fde4084bbe6"
    },
    "android-games/hearthguard/.artifacts/production-preview-boss-20261024T093920049812Z/start-provenance.json": {
      "bytes": 2656,
      "sha256": "73aeb6c39fe4857bd0a8a0b2ad2e3869341da332b216ca03709fee5cf15dd6cc"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/appdata/Godot/app_userdata/Hearthguard/hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/appdata/Godot/app_userdata/Hearthguard/hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/appdata/Godot/app_userdata/Hearthguard/logs/godot.log": {
      "bytes": 94,
      "sha256": "0ce6170b0a490f0ec24061f20698b02eaa1b2047aa54fab03198bc1faa2214e5"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/appdata/Godot/app_userdata/Hearthguard/logs/godot2026-10-24T05.38.31.log": {
      "bytes": 73,
      "sha256": "6d1c065383a27c36804949b6ffa4b09714470b112e5dacc0bd5aeb7b9c147c4e"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/execution.log": {
      "bytes": 97,
      "sha256": "f11ca6651ba2693a8df7f423b01dddc43ee6167a84942e80b393fbf677f68240"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/frozen-runtime.json": {
      "bytes": 10977,
      "sha256": "a14c4946e8b24a6e693fa5e425ca04b02613170991f5f4cc9d0b7ff1210f8113"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/parse.log": {
      "bytes": 75,
      "sha256": "83cf0b082206af2aa236c83064fbcfa76be1e00a4aa3558574b2f65965d9481c"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/passage-report.json": {
      "bytes": 2070,
      "sha256": "27ebcc6d95486ed55f56075519d18f11f7a642f054c734fdc4729da9955a59d7"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/production-report.json": {
      "bytes": 343387,
      "sha256": "62164b22653208d34107a3dba06d10b39733239b5d1f93f1d05f94b172538c17"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/raw-input-events.json": {
      "bytes": 13745,
      "sha256": "7d1ec7be6ae370120b830feff103bf60f7742d7990ca24374c32032631b4330b"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/receipt.json": {
      "bytes": 14382,
      "sha256": "726891d3e27cddf62481d992f7615bf2a411ac0aef8e124e2825adc97f4be262"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/slots/final/hearth-save-0": {
      "bytes": 10621,
      "sha256": "6cf852a586b9504d009cd99eac49205bc4bae2f9df0226e740cf58bd2a3895bf"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/slots/final/hearth-save-1": {
      "bytes": 10621,
      "sha256": "2f95aef60b4dee83ed39b743d1a9c7e86c170d7d52d9fca8bb5c725a3c256cef"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/source-hashes.json": {
      "bytes": 16228,
      "sha256": "668f76335a4b5be3b610dca5b9324130ec8076cfa7dc71a1f4bc4fde4084bbe6"
    },
    "android-games/hearthguard/.artifacts/production-preview-opening-20261024T093821987201Z/start-provenance.json": {
      "bytes": 697,
      "sha256": "1cb247397bb66bdd2615b33e20bd840fdb7b5f2d66e50685e2e3a0b13e9a8617"
    }
  },
  "acceptance": "Source/CPU preparation only; renderer remains coordinator-owned and unexecuted for this harness."
}
```
