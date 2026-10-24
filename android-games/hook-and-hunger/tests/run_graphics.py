"""CPU-only source-bound Hook graphics checks. Never opens a display or clipboard."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def sources():
    return {p.relative_to(PROJECT).as_posix(): sha(p) for p in sorted(PROJECT.rglob("*"))
            if p.is_file() and not any(c.startswith(".") or c == "__pycache__" for c in p.relative_to(PROJECT).parts)
            and (p.suffix in {".gd", ".uid", ".godot", ".tscn", ".glb", ".import", ".svg", ".cfg", ".py"}
                 or p in {PROJECT / "art/manifest.json", PROJECT / "evidence/campaign-checkpoint.json"})}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suites", nargs="*", default=["presentation_tests"])
    args = parser.parse_args()
    if any(not (PROJECT / "tests" / (name + ".gd")).is_file() or "/" in name or "\\" in name for name in args.suites):
        parser.error("Use existing test script basenames")
    run = PROJECT / ".artifacts" / ("graphics-cpu-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        folder = run / key.lower()
        folder.mkdir()
        env[key] = str(folder)
    report = {"run": str(run), "cpu_only": True, "suites": [], "passed": False}

    def invoke(command, label, timeout=180):
        with (run / (label + ".log")).open("w", encoding="utf-8") as log:
            try:
                code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout).returncode
            except subprocess.TimeoutExpired:
                code = -99
        output = (run / (label + ".log")).read_text(encoding="utf-8", errors="replace")
        errors = [line for line in output.splitlines() if any(s in line for s in ("ERROR:", "SCRIPT ERROR:", "Parse Error:"))]
        return {"command": command, "exit_code": code, "errors": errors, "passed": code == 0 and not errors, "suite_complete": "SUITE_COMPLETE: PASS" in output}

    report["import"] = invoke([str(GODOT), "--headless", "--audio-driver", "Dummy", "--editor", "--import", "--quit", "--path", str(PROJECT)], "import")
    if report["import"]["passed"]:
        frozen = sources()
        (run / "source-before.json").write_text(json.dumps(frozen, indent=2) + "\n")
        for name in args.suites:
            if sources() != frozen:
                report["drift_before_suite"] = name
                break
            result = invoke([str(GODOT), "--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", str(PROJECT), "--script", "res://tests/" + name + ".gd",
                             "--", "--capture-dir=" + str(run)], name, timeout=360)
            result["passed"] = result["passed"] and result["suite_complete"]
            result["suite"] = name
            report["suites"].append(result)
            if not result["passed"]:
                break
        report["source_unchanged"] = sources() == frozen
        report["passed"] = report["source_unchanged"] and len(report["suites"]) == len(args.suites) and all(s["passed"] for s in report["suites"])
        (run / "source-after.json").write_text(json.dumps(sources(), indent=2) + "\n")
    (run / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"run": str(run), "passed": report["passed"], "import": report["import"], "suites": report["suites"]}, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
