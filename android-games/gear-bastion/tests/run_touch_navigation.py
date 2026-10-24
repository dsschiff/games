"""Focused Gear recovery GUI scrolling regression; existing-cache headless/Dummy only."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
GODOT = "C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"

def source():
    return {p.relative_to(PROJECT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(PROJECT.rglob("*")) if p.is_file()
            and not any(x.startswith(".") or x == "__pycache__" for x in p.relative_to(PROJECT).parts)}

def cache():
    return {p.relative_to(PROJECT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted((PROJECT / ".godot").rglob("*")) if p.is_file()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", action="store_true", help="Run only the first witness; retain failures honestly")
    args = parser.parse_args()
    run = PROJECT / ".artifacts" / ("touch-navigation-" + ("baseline-" if args.baseline else "current-") + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
        folder = run / key.lower(); folder.mkdir(); env[key] = str(folder)
    command = [GODOT, "--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", str(PROJECT), "--script", "res://tests/touch_navigation.gd", "--", "--report-dir=" + str(run)]
    if args.baseline: command.append("--baseline")
    before = source(); cache_before = cache()
    with (run / "godot.log").open("w", encoding="utf-8") as log:
        try: code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=90).returncode
        except subprocess.TimeoutExpired: code = 124
    after = source(); cache_after = cache()
    output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
    errors = [line for line in output.splitlines() if any(x in line for x in ["ERROR:", "WARNING:", "ObjectDB", "Parse Error:"])]
    report = {"command": command, "exit_code": code, "source_before": before, "source_after": after,
              "source_unchanged": before == after, "cache_before": cache_before, "cache_after": cache_after,
              "cache_unchanged": cache_before == cache_after, "raw_errors": errors,
              "passed": code == 0 and not errors and before == after and cache_before == cache_after and "SUITE_COMPLETE: PASS" in output}
    (run / "receipt.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(run); print(output[-2500:]); print(json.dumps({k: report[k] for k in ["passed", "exit_code", "source_unchanged", "cache_unchanged", "raw_errors"]}))
    raise SystemExit(0 if report["passed"] else 1)

if __name__ == "__main__": main()
