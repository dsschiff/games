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
SCRIPTS = {"multiplier": "res://tests/multiplier_feedback.gd", "transition": "res://tests/terminal_transition.gd", "lifetime": "res://tests/texture_lifetime.gd", "rules": "res://tests/run_tests.gd", "campaign-rules": "res://tests/campaign_tests.gd",
           "platform": "res://tests/platform_input.gd", "code4": "res://tests/code4_upgrade.gd", "design": "res://tests/terminal_design.gd", "lineup": "res://tests/art_lineup.gd", "frames": "res://tests/graphics_frames.gd",
           "presentation": "res://tests/presentation_tests.gd", "timing": "res://tests/horde_timing.gd"}


def raw_hashes():
    return {str(p.relative_to(PROJECT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(PROJECT.rglob("*")) if p.is_file()
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


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
    parser.add_argument("--input-dir", type=Path, help="transition only: prior genuine app-written defeat slots")
    drain = parser.add_mutually_exclusive_group()
    drain.add_argument("--drain-between-rebuilds", action="store_true", help="lifetime fixture comparison only: await normal process/render frames after each geometry world")
    drain.add_argument("--drain-after-fixtures", action="store_true", help="lifetime end-only control: same added drain count after all geometry worlds")
    parser.add_argument("--movie", action="store_true", help="also write a fixed-60fps AVI via Godot's movie writer")
    args = parser.parse_args()
    if (args.drain_between_rebuilds or args.drain_after_fixtures) and args.mode != "lifetime":
        parser.error("Fixture drain comparisons apply only to lifetime mode")
    if (args.mode == "transition") != (args.input_dir is not None):
        parser.error("transition requires --input-dir; other modes do not accept it")
    if args.mode == "transition" and len(list(args.input_dir.glob("dead-run-save-*"))) != 2:
        parser.error("transition needs exactly two app-written slots")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run = PROJECT / ".artifacts" / "graphics" / f"{args.label}-{args.mode}-{stamp}"
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        env[key] = str(run / key.lower())
        Path(env[key]).mkdir()
    inputs = []
    if args.mode in ("code4", "transition"):
        destination = Path(env["APPDATA"]) / "Godot/app_userdata/Dead Run"
        destination.mkdir(parents=True)
        source = args.input_dir if args.mode == "transition" else PROJECT / "tests/fixtures/code4-midroad"
        for original in sorted(source.glob("dead-run-save-*")):
            (destination / original.name).write_bytes(original.read_bytes())
            inputs.append({"kind": "genuine-prior-app-written-defeat-slot" if args.mode == "transition" else "genuine-code4-app-written-slot", "source": str(original),
                           "sha256": hashlib.sha256(original.read_bytes()).hexdigest()})
    # Sound stays off in every automated run (Daniel works at this computer).
    command = [str(GODOT), "--path", str(PROJECT), "--audio-driver", "Dummy"]
    if args.mode == "import":
        command += ["--headless", "--editor", "--import"]
    else:
        command += ["--headless"] if args.headless else ["--resolution", "720x1280", "--position", "0,0"]
        # timing: unpaced render frames (opt-in host capture, DEVELOPMENT.md).
        command += ([] if args.mode == "timing" else ["--fixed-fps", "60"]) + ["--script", SCRIPTS[args.mode]]
        if args.movie:
            command += ["--write-movie", str(run / "clip.avi")]
        command += ["--",
                    "--capture-dir=" + str(run), "--scenario=" + args.scenario, "--report=" + str(run / "rules-report.json")]
        if args.drain_between_rebuilds: command.append("--drain-between-rebuilds")
        if args.drain_after_fixtures: command.append("--drain-after-fixtures")
    before = lf_hashes()
    raw_before = raw_hashes() if args.mode == "multiplier" else {}
    (run / "source-hashes-lf.json").write_text(json.dumps(before, indent=2))
    with (run / "godot.log").open("w", encoding="utf-8") as log:
        code = subprocess.call(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1800)
    output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
    errors = [line for line in output.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:")) or (args.mode == "multiplier" and any(token in line for token in ("WARNING:", "ObjectDB instances leaked")))]
    okay = code == 0 and not errors and (args.mode == "import" or "SUITE_COMPLETE: PASS" in output)
    after = lf_hashes()
    receipt = {"source_before_raw": raw_before, "source_after_raw": raw_hashes() if args.mode == "multiplier" else {}, "command": command, "exit_code": code, "passed": okay, "errors": errors[:40],
               "source_unchanged": {k: v for k, v in before.items() if not k.startswith("art/models/") or k.endswith(".glb")} ==
                                   {k: v for k, v in after.items() if not k.startswith("art/models/") or k.endswith(".glb")},
               "inputs": inputs, "pngs": sorted(p.name for p in run.glob("*.png"))}
    okay = okay and receipt["source_unchanged"]
    receipt["passed"] = okay
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2))
    print(output[-6000:])
    print(run)
    print("GRAPHICS_RESULT", "PASS" if okay else "FAIL")
    raise SystemExit(0 if okay else 1)


if __name__ == "__main__":
    main()
