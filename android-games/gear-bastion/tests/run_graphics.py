"""Isolated Gear CPU checks and explicitly selected rendered inspection.

Rendered execution requires the coordinator's serialized GPU grant. This runner
does not export, install, use ADB/clipboard, or infer quality from exit status.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")
BASELINE = "33ab8d76eaa74f7a3439350d54cad0fc8511841e"


def sources(project=PROJECT):
    return {p.relative_to(project).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(project.rglob("*")) if p.is_file()
            and not any(part in {".artifacts", ".godot", ".git", "__pycache__"} for part in p.relative_to(project).parts)}


def execute(command, run, env, name, timeout=180):
    with (run / (name+".log")).open("w", encoding="utf-8") as stream:
        try:
            code = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                  timeout=timeout, cwd=PROJECT).returncode
        except subprocess.TimeoutExpired:
            code = 124
    output = (run / (name+".log")).read_text(encoding="utf-8", errors="replace")
    errors = [line for line in output.splitlines() if any(x in line for x in ["ERROR:", "SCRIPT ERROR:", "Parse Error:"])]
    result = {"command": command, "exit_code": code, "errors": errors,
              "passed": code == 0 and not errors, "log": name+".log"}
    (run/(name+"-report.json")).write_text(json.dumps(result, indent=2), encoding="utf-8")
    return result, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["checks", "input", "deck", "boss-hud", "pooling", "inspect", "fresh-import"])
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    if args.mode == "inspect" and not args.render:
        parser.error("Inspection requires --render and the coordinator's current GPU grant")
    run = PROJECT/".artifacts/graphics-production"/(args.mode+"-"+datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
        folder = run/key.lower(); folder.mkdir(); env[key] = str(folder)
    target = PROJECT
    if args.mode == "fresh-import":
        target = run/"fresh-source"
        shutil.copytree(PROJECT, target, ignore=shutil.ignore_patterns(".artifacts", ".godot", "__pycache__"))
    import_before = sources(target)
    preflight, _ = execute([str(GODOT), "--headless", "--editor", "--import", "--quit", "--path", str(target)], run, env, "import")
    before = sources(target)
    import_changes = {name: {"before": import_before.get(name), "after": before.get(name)}
                      for name in sorted(set(import_before)|set(before)) if import_before.get(name) != before.get(name)}
    result = preflight
    if preflight["passed"] and args.mode != "fresh-import":
        baseline = subprocess.check_output(["git", "show", BASELINE+":android-games/gear-bastion/scripts/battle_rules.gd"], cwd=PROJECT)
        baseline = baseline.replace(b"class_name BattleRules\n", b"")
        (PROJECT/".artifacts/graphics-production/baseline_battle.gd").write_bytes(baseline)
        script = {"checks": "presentation_tests.gd", "input": "graphics_input.gd", "deck": "deck_geometry.gd", "boss-hud": "boss_hud.gd", "pooling": "pooling.gd", "inspect": "graphics_inspect.gd"}[args.mode]
        command = [str(GODOT), "--path", str(PROJECT), "--audio-driver", "Dummy", "--quit-after", "12000"]
        command += ["--resolution", "720x1680", "--position", "0,0"] if args.render else ["--headless"]
        command += ["-s", "tests/"+script, "--", "--run-dir="+str(run)]
        result, output = execute(command, run, env, args.mode)
        result["passed"] = result["passed"] and "SUITE_COMPLETE: PASS" in output
    after = sources(target)
    result["passed"] = result["passed"] and before == after
    data_path = run/"checks-data.json" if args.mode == "checks" else run/"input/report.json"
    if args.mode == "deck":
        data_path = run/"deck-data.json"
    if args.mode == "boss-hud":
        data_path = run/"hud-data.json"
    if args.mode == "pooling":
        data_path = run/"pool-data.json"
    retained_data = None
    if args.mode in {"checks", "input", "deck", "boss-hud", "pooling"} and data_path.exists():
        retained_data = run/"result-data.json"
        shutil.copyfile(data_path, retained_data)
    receipt = {"mode": args.mode, "rendered": args.render, "source_before": before, "source_after": after,
               "import_source_before": import_before, "import_source_after": before, "import_changes": import_changes,
               "source_unchanged": before == after, "result": result,
               "limits": "Source/import/input evidence; no automatic visible-quality, Android or phone acceptance"}
    if retained_data:
        receipt["result_data"] = {"file": retained_data.name, "sha256": hashlib.sha256(retained_data.read_bytes()).hexdigest()}
    baseline_path = PROJECT/".artifacts/graphics-production/baseline_battle.gd"
    if baseline_path.exists():
        receipt["baseline"] = {"commit": BASELINE, "worker_equivalent_rule_blob": "45baca53cf6b422db98813a92a2be05198aa9f0b",
                               "class_name_removed_for_side_by_side_load": True,
                               "sha256": hashlib.sha256(baseline_path.read_bytes()).hexdigest()}
    (run/"receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps({"run": str(run), "passed": result["passed"], "source_unchanged": before == after}))
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
