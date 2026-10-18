"""Prepare a short frozen earned-save inspection. Execute only after root grants GPU.

Default is CPU-only preparation. --execute and --native-frames are explicit opts.
No clipboard, browser, emulator, ADB, signing or host settings are used.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from run_graphics import GODOT, PROJECT, sha, sources

INDEX_LF_SHA = "929c1bd706847d941f42290fb5abff90f875ce38c3a020b3cc84a29e592a3e08"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", default="stage-00-start")
    parser.add_argument("--seconds", type=float, default=8)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--native-frames", action="store_true")
    args = parser.parse_args()
    if not 0 < args.seconds <= 12:
        parser.error("This is the short first-inspection harness: use 0-12 seconds")
    index_path = PROJECT / "evidence/campaign-checkpoint.json"
    if hashlib.sha256(index_path.read_bytes().replace(b"\r\n", b"\n")).hexdigest() != INDEX_LF_SHA:
        parser.error("Historical receipt changed")
    index = json.loads(index_path.read_text())
    selected = next((r for r in index["artifacts"] if r["path"] == ".artifacts/campaign-code2-final/" + args.checkpoint + ".json"), None)
    if not selected or sha(PROJECT / selected["path"]) != selected["sha256"]:
        parser.error("Checkpoint absent or historical earned hash mismatch")
    run = PROJECT / ".artifacts" / ("inspection-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        folder = run / key.lower()
        folder.mkdir()
        env[key] = str(folder)

    def invoke(command, name, timeout):
        with (run / (name + ".log")).open("w", encoding="utf-8") as log:
            try:
                code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout).returncode
            except subprocess.TimeoutExpired:
                code = -99
        output = (run / (name + ".log")).read_text(encoding="utf-8", errors="replace")
        errors = [line for line in output.splitlines() if any(s in line for s in ("ERROR:", "SCRIPT ERROR:", "Parse Error:"))]
        return {"command": command, "exit_code": code, "errors": errors, "passed": code == 0 and not errors}

    report = {"checkpoint_receipt": selected, "executed": args.execute, "cpu_preparation_only": not args.execute}
    report["import"] = invoke([str(GODOT), "--headless", "--editor", "--import", "--quit", "--path", str(PROJECT)], "import", 180)
    report["parse"] = invoke([str(GODOT), "--headless", "--path", str(PROJECT), "--check-only", "--script", "res://tests/graphics_inspection.gd"], "parse", 60)
    if not report["import"]["passed"] or not report["parse"]["passed"]:
        (run / "report.json").write_text(json.dumps(report, indent=2))
        print(json.dumps(report, indent=2))
        return 1
    frozen = sources()
    for name in frozen:
        target = run / "executed-source" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / name, target)
    checkpoint = run / "earned-checkpoint.json"
    shutil.copy2(PROJECT / selected["path"], checkpoint)
    command = [str(GODOT), "--path", str(PROJECT), "--resolution", "720x1280", "--position", "0,0", "--script", "res://tests/graphics_inspection.gd"]
    if args.native_frames:
        command += ["--fixed-fps", "30"]
    command += ["--", "--capture-dir=" + str(run), "--checkpoint=" + str(checkpoint), "--seconds=" + str(args.seconds)]
    if args.native_frames:
        command += ["--native-frames"]
    report["planned_command"] = command
    (run / "source-before.json").write_text(json.dumps(frozen, indent=2) + "\n")
    if args.execute:
        if sources() != frozen:
            raise RuntimeError("Source drift before execution")
        report["execution"] = invoke(command, "inspection", 90)
    report["source_unchanged"] = sources() == frozen
    report["passed"] = report["source_unchanged"] and (not args.execute or report["execution"]["passed"])
    (run / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"run": str(run), "passed": report["passed"], "executed": args.execute, "planned_command": command}, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
