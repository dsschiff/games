"""Isolated graphics runner: import, kit verification, rendered inspection frames.

Every run gets its own APPDATA/LOCALAPPDATA/TEMP under ignored .artifacts and
records the command, log and LF source hashes. Rendered modes open a real
720x1280 window; nothing here uses Android, ADB, the clipboard or signing.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from datetime import datetime, timezone

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")
SCRIPTS = {"lineup": "res://tests/art_lineup.gd", "frames": "res://tests/graphics_frames.gd",
           "presentation": "res://tests/presentation_tests.gd"}


def lf_hashes():
    return {str(p.relative_to(PROJECT)).replace("\\", "/"): hashlib.sha256(p.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
            for p in sorted(PROJECT.rglob("*")) if p.is_file()
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["import", *SCRIPTS])
    parser.add_argument("--label", default="run")
    parser.add_argument("--scenario", default="all")
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run = PROJECT / ".artifacts" / "graphics" / f"{args.label}-{args.mode}-{stamp}"
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        env[key] = str(run / key.lower())
        Path(env[key]).mkdir()
    command = [str(GODOT), "--path", str(PROJECT)]
    if args.mode == "import":
        command += ["--headless", "--editor", "--import"]
    else:
        command += ["--headless"] if args.headless else ["--resolution", "720x1280", "--position", "0,0"]
        command += ["--fixed-fps", "60", "--script", SCRIPTS[args.mode], "--",
                    "--capture-dir=" + str(run), "--scenario=" + args.scenario]
    before = lf_hashes()
    (run / "source-hashes-lf.json").write_text(json.dumps(before, indent=2))
    with (run / "godot.log").open("w", encoding="utf-8") as log:
        code = subprocess.call(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1800)
    output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
    errors = [line for line in output.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
    okay = code == 0 and not errors and (args.mode == "import" or "SUITE_COMPLETE: PASS" in output)
    after = lf_hashes()
    receipt = {"command": command, "exit_code": code, "passed": okay, "errors": errors[:40],
               "source_unchanged": {k: v for k, v in before.items() if not k.startswith("art/models/") or k.endswith(".glb")} ==
                                   {k: v for k, v in after.items() if not k.startswith("art/models/") or k.endswith(".glb")},
               "pngs": sorted(p.name for p in run.glob("*.png"))}
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2))
    print(output[-6000:])
    print(run)
    print("GRAPHICS_RESULT", "PASS" if okay else "FAIL")
    raise SystemExit(0 if okay else 1)


if __name__ == "__main__":
    main()
