"""Isolated Gear recovery CPU checks; no GPU, native, clipboard or network."""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64.exe")
ERRORS = ("SCRIPT ERROR", "ERROR:", "WARNING:", "ObjectDB instances leaked")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    return {p.relative_to(PROJECT).as_posix(): sha(p) for p in sorted(PROJECT.rglob("*"))
            if p.is_file() and not any(x in p.relative_to(PROJECT).parts
            for x in (".artifacts", ".godot", "__pycache__"))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    for mode in ("journal", "marker", "rules", "phase-input", "input"):
        group.add_argument("--" + mode, action="store_true")
    parser.add_argument("--prepare", action="store_true")
    args = parser.parse_args()
    folder = PROJECT / ".artifacts" / ("recovery-cpu-" + datetime.datetime.now(
        datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    folder.mkdir(parents=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        env[key] = str(folder / key)
        Path(env[key]).mkdir()
    preflight = None
    if args.prepare:
        before_import = sources()
        command = [str(GODOT), "--headless", "--audio-driver", "Dummy", "--editor",
                   "--path", str(PROJECT), "--import", "--quit"]
        result = subprocess.run(command, env=env, capture_output=True, text=True,
                                encoding="utf-8", timeout=120)
        output = result.stdout + result.stderr
        (folder / "preflight.log").write_text(output, encoding="utf-8")
        preflight = {"command": command, "exit_code": result.returncode,
                     "source_before": before_import, "source_after": sources(),
                     "errors": any(s in output for s in ERRORS)}
        (folder / "preflight.json").write_text(json.dumps(preflight, indent=2) + "\n", encoding="utf-8")
        if result.returncode or preflight["errors"]:
            raise SystemExit("Preflight failed; retain " + str(folder))
    script, report_name = "save_recovery.gd", "save-recovery.json"
    if args.journal:
        script, report_name = "import_recovery.gd", "import-recovery.json"
    elif args.marker:
        script, report_name = "marker_retry.gd", "marker-retry.json"
    elif args.rules:
        script, report_name = "run_tests.gd", "rules.json"
    elif args.phase_input:
        script, report_name = "ready_phase_input.gd", "phase-data.json"
    elif args.input:
        script, report_name = "graphics_input.gd", "input.json"
    before = sources()
    command = [str(GODOT), "--headless", "--audio-driver", "Dummy", "--path", str(PROJECT),
               "--script", "res://tests/" + script, "--quit-after", "30000" if args.phase_input else "4000"]
    if args.phase_input:
        command += ["--fixed-fps", "60"]
    command += ["--", "--report-dir=" + str(folder), "--run-dir=" + str(folder)]
    code = 124
    with (folder / "godot.log").open("w", encoding="utf-8") as stream:
        try:
            code = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                  timeout=180).returncode
        except subprocess.TimeoutExpired:
            stream.write("\nERROR: recovery timeout\n")
    after = sources()
    log = (folder / "godot.log").read_text(encoding="utf-8")
    path = folder / report_name
    if args.input:
        source = folder / "input" / "report.json"
        if source.exists():
            path.write_bytes(source.read_bytes())
    if args.rules:
        match = re.search(r"RULE TESTS: (\d+) checks, (\d+) failures", log)
        if match:
            path.write_text(json.dumps({"checks": int(match[1]), "failures": [] if match[2] == "0"
                else ["Existing rules failure; see log"]}, indent=2) + "\n", encoding="utf-8")
    report = json.loads(path.read_text(encoding="utf-8")) if path.exists() else None
    errors = any(s in log for s in ERRORS)
    passed = code == 0 and report is not None and not report["failures"] and not errors and before == after
    record = {"passed": passed, "command": command, "exit_code": code, "preflight": preflight,
              "source_before": before, "source_after": after, "report": report, "runtime_errors": errors,
              "files": {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob("*")) if p.is_file()},
              "limits": "CPU/headless/Dummy, synthetic faults and full records, actual GUI input; no native/render/power-loss claim"}
    (folder / "receipt.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": passed, "folder": str(folder), "checks": report["checks"] if report else None,
                     "failures": report["failures"] if report else [], "log": log[-5000:] if not passed else "clean"}, indent=2))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
