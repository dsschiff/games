"""Bounded cached CPU probe; never imports, renders, or calls an OS clipboard."""
from __future__ import annotations
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def sources():
    return {p.relative_to(PROJECT).as_posix(): sha(p) for p in sorted(PROJECT.rglob("*"))
            if p.is_file() and not any(x in p.relative_to(PROJECT).parts
            for x in (".artifacts", ".godot", "__pycache__"))}

def main():
    folder = PROJECT.parents[1] / ".artifacts" / ("copy-controls-cpu-" + datetime.datetime.now(
        datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    folder.mkdir(parents=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        env[key] = str(folder / key)
        Path(env[key]).mkdir()
    before = sources()
    command = [str(GODOT), "--headless", "--audio-driver", "Dummy", "--path", str(PROJECT),
               "--script", "res://tests/recovery_copy.gd", "--quit-after", "4000", "--",
               "--report-dir=" + str(folder)]
    code = 124
    with (folder / "godot.log").open("w", encoding="utf-8") as stream:
        try:
            code = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                  timeout=120).returncode
        except subprocess.TimeoutExpired:
            stream.write("\nERROR: copy-control probe timeout\n")
    after = sources()
    log = (folder / "godot.log").read_text(encoding="utf-8")
    report_path = folder / "recovery-copy.json"
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else None
    errors = [line for line in log.splitlines() if any(s in line for s in (
        "SCRIPT ERROR", "ERROR:", "WARNING:", "ObjectDB instances leaked"))]
    passed = code == 0 and report is not None and not report["failures"] and not errors and before == after
    record = {"passed": passed, "command": command, "exit_code": code, "source_before": before,
              "source_after": after, "report": report, "raw_errors": errors,
              "files": {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob("*")) if p.is_file()},
              "limits": "Existing cache; no editor/import/native/render/OS clipboard. Synthetic contexts/faults, actual touch and scroll geometry."}
    (folder / "receipt.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": passed, "folder": str(folder), "checks": report["checks"] if report else None,
                      "failures": report["failures"] if report else [], "errors": errors}, indent=2))
    raise SystemExit(0 if passed else 1)

if __name__ == "__main__":
    main()
