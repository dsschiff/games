"""Isolated desktop evidence. Never uses Android, editor settings or shared scripts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from datetime import datetime, timezone

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")


def sources():
    return {str(p.relative_to(PROJECT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(PROJECT.rglob("*")) if p.is_file()
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["rules", "headless", "rendered", "movie"])
    parser.add_argument("--label", default="run")
    args = parser.parse_args()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run = PROJECT / ".artifacts" / f"{args.label}-{args.mode}-{stamp}"
    run.mkdir(parents=True)
    env = os.environ.copy()
    env["APPDATA"] = str(run / "appdata")
    env["LOCALAPPDATA"] = str(run / "localappdata")
    Path(env["APPDATA"]).mkdir()
    Path(env["LOCALAPPDATA"]).mkdir()
    command = [str(GODOT), "--path", str(PROJECT)]
    if args.mode in ["rules", "headless"]:
        command += ["--headless"]
    else:
        command += ["--resolution", "720x1280", "--position", "0,0"]
    command += ["--fixed-fps", "60", "--script",
                "res://tests/run_tests.gd" if args.mode == "rules" else "res://tests/playthrough.gd"]
    if args.mode == "movie":
        command += ["--write-movie", str(run / "continuous.avi")]
    command += ["--", "--capture-dir=" + str(run), "--report=" + str(run / "rules-report.json")]
    if args.mode == "movie":
        command += ["--movie-only"]
    before = sources()
    (run / "source-hashes.json").write_text(json.dumps(before, indent=2))
    frozen = run / "executed-source"
    for name in before:
        target = frozen / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((PROJECT / name).read_bytes())
    with (run / "godot.log").open("w", encoding="utf-8") as log:
        try:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=480)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
    output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
    okay = code == 0 and "SUITE_COMPLETE: PASS" in output and not any(x in output for x in ["ERROR:", "SCRIPT ERROR:", "Parse Error:"])
    receipt = {"command": command, "exit_code": code, "passed": okay, "source_unchanged": before == sources(),
               "engine": str(GODOT), "scope": args.mode, "artifacts": []}
    for p in sorted(run.rglob("*")):
        if p.is_file():
            receipt["artifacts"].append({"path": str(p.relative_to(run)).replace("\\", "/"), "bytes": p.stat().st_size,
                                          "sha256": hashlib.sha256(p.read_bytes()).hexdigest()})
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2))
    print(output)
    print(run)
    print("DESKTOP_RESULT", "PASS" if okay and receipt["source_unchanged"] else "FAIL")
    raise SystemExit(0 if okay and receipt["source_unchanged"] else 1)


if __name__ == "__main__":
    main()
