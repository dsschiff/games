"""Headless, silent, source-pinned design regression runs; no renderer or clipboard."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GODOT = "C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"

def sources():
    return {str(p.relative_to(ROOT)).replace(chr(92), "/"): hashlib.sha256(p.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
            for p in sorted(ROOT.rglob("*")) if p.is_file()
            and not any(x.startswith(".") or x == "__pycache__" for x in p.relative_to(ROOT).parts)
            and p.suffix in {".gd", ".tscn", ".godot", ".glb", ".svg", ".cfg", ".py", ".uid", ".import"}}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suites", nargs="+", help="Existing test script basenames")
    args = parser.parse_args()
    if any("/" in n or chr(92) in n or not (ROOT / "tests" / (n + ".gd")).is_file() for n in args.suites):
        parser.error("Use existing test script basenames")
    run = ROOT / ".artifacts" / ("design-cpu-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    run.mkdir(parents=True)
    env = os.environ.copy()
    for name in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
        target = run / name.lower()
        target.mkdir()
        env[name] = str(target)
    report = {"cpu_only": True, "suites": []}
    def invoke(arguments, label):
        command = [GODOT, "--headless", "--audio-driver", "Dummy", "--path", str(ROOT)] + arguments
        with (run / (label + ".log")).open("w", encoding="utf-8") as log:
            try:
                code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
            except subprocess.TimeoutExpired:
                code = -99
        output = (run / (label + ".log")).read_text(encoding="utf-8", errors="replace")
        errors = [x for x in output.splitlines() if any(t in x for t in ["ERROR:", "FAIL:", "Parse Error:"])]
        passed = code == 0 and not errors and (label == "import" or "SUITE_COMPLETE: PASS" in output)
        return {"name": label, "command": command, "exit_code": code, "errors": errors, "passed": passed}
    report["import"] = invoke(["--editor", "--import", "--quit"], "import")
    before = sources()
    (run / "source-before.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
    if report["import"]["passed"]:
        for suite in args.suites:
            if sources() != before:
                break
            report["suites"].append(invoke(["--fixed-fps", "60", "--script", "tests/" + suite + ".gd", "--", "--capture-dir=" + str(run)], suite))
    report["source_unchanged"] = sources() == before
    report["passed"] = report["import"]["passed"] and report["source_unchanged"] and len(report["suites"]) == len(args.suites) and all(s["passed"] for s in report["suites"])
    (run / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"run": str(run), **report}, indent=2))
    return 0 if report["passed"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
