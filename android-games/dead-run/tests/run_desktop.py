"""Isolated desktop evidence. Never uses Android, editor settings or shared scripts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import ctypes
from datetime import datetime, timezone
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")


def sources():
    return {str(p.relative_to(PROJECT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(PROJECT.rglob("*")) if p.is_file()
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["rules", "headless", "rendered", "movie", "exhaustion-headless", "exhaustion-rendered", "campaign-smoke", "campaign-visual", "validation-headless", "camera-headless", "campaign-rules", "campaign-headless", "campaign-rendered", "late-priority-headless", "platform-headless", "platform-rendered", "clipboard-headless", "clipboard-rendered", "clipboard-locked", "migration-headless", "migration-rendered", "campaign-movie-early", "campaign-movie-middle", "campaign-movie-final", "code4-headless"])
    parser.add_argument("--label", default="run")
    parser.add_argument("--earned-checkpoint", type=Path)
    parser.add_argument("--opening-only", action="store_true")
    parser.add_argument("--validation-case", default="all")
    args = parser.parse_args()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run = PROJECT / ".artifacts" / f"{args.label}-{args.mode}-{stamp}"
    run.mkdir(parents=True)
    env = os.environ.copy()
    env["APPDATA"] = str(run / "appdata")
    env["LOCALAPPDATA"] = str(run / "localappdata")
    Path(env["APPDATA"]).mkdir()
    Path(env["LOCALAPPDATA"]).mkdir()
    inputs = []
    legacy = PROJECT / ".artifacts/legacy-code1-source/final-active-fixture-paused-held-dead-run-save-1.json"
    if args.mode in ["campaign-rules", "migration-headless", "migration-rendered"] and legacy.exists():
        target = run / "input-fixtures" / legacy.name
        target.parent.mkdir()
        target.write_bytes(legacy.read_bytes())
        inputs.append({"kind": "actual-native-code1-migration-only", "path": str(target), "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
        if args.mode.startswith("migration-"):
            dest = Path(env["APPDATA"]) / "Godot/app_userdata/Dead Run"
            dest.mkdir(parents=True)
            for slot in range(2):
                original = legacy.with_name(f"final-active-fixture-paused-held-dead-run-save-{slot}.json")
                (dest / f"dead-run-save-{slot}").write_bytes(original.read_bytes())
                inputs.append({"kind": "actual-native-code1-startup-slot", "source": str(original), "sha256": hashlib.sha256(original.read_bytes()).hexdigest()})
    if args.mode == "code4-headless":
        # Genuine code4 app-written slots (see tests/fixtures/code4-midroad).
        dest = Path(env["APPDATA"]) / "Godot/app_userdata/Dead Run"
        dest.mkdir(parents=True)
        for slot in range(2):
            original = PROJECT / "tests/fixtures/code4-midroad" / f"dead-run-save-{slot}"
            (dest / original.name).write_bytes(original.read_bytes())
            inputs.append({"kind": "genuine-code4-app-written-slot", "source": str(original), "sha256": hashlib.sha256(original.read_bytes()).hexdigest()})
    if args.earned_checkpoint:
        assert args.mode.startswith("campaign-movie-") or args.mode == "late-priority-headless", "Earned loads only belong to explicit separate scenario boundaries"
        dest = Path(env["APPDATA"]) / "Godot/app_userdata/Dead Run"
        dest.mkdir(parents=True)
        for p in sorted(args.earned_checkpoint.glob("dead-run-save-*")):
            if p.suffix != ".tmp":
                (dest / p.name).write_bytes(p.read_bytes())
                inputs.append({"kind": "earned-app-written-checkpoint-load", "source": str(p), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()})
    # Sound stays off in every automated run (Daniel works at this computer).
    command = [str(GODOT), "--path", str(PROJECT), "--audio-driver", "Dummy"]
    if args.mode in ["rules", "headless", "exhaustion-headless", "campaign-smoke", "validation-headless", "camera-headless", "campaign-rules", "campaign-headless", "clipboard-headless", "migration-headless", "platform-headless", "late-priority-headless", "code4-headless"]:
        command += ["--headless"]
    else:
        command += ["--resolution", "720x1280", "--position", "0,0"]
    script = ("res://tests/camera_projection.gd" if args.mode == "camera-headless" else
              "res://tests/code4_upgrade.gd" if args.mode == "code4-headless" else
              "res://tests/validation_tests.gd" if args.mode == "validation-headless" else
              "res://tests/campaign_smoke.gd" if args.mode == "campaign-smoke" else
              "res://tests/campaign_visual.gd" if args.mode == "campaign-visual" else
              "res://tests/migration_input.gd" if args.mode.startswith("migration-") else
              "res://tests/platform_input.gd" if args.mode.startswith("platform-") else
              "res://tests/late_priority_input.gd" if args.mode == "late-priority-headless" else
              "res://tests/campaign_tests.gd" if args.mode == "campaign-rules" else
              "res://tests/campaign_input.gd" if args.mode in ["campaign-headless", "campaign-rendered"] else
              "res://tests/clipboard_input.gd" if args.mode.startswith("clipboard-") else
              "res://tests/campaign_movie.gd" if args.mode.startswith("campaign-movie-") else
              "res://tests/run_tests.gd" if args.mode == "rules" else
              "res://tests/exhaustion_playthrough.gd" if args.mode.startswith("exhaustion-") else
              "res://tests/playthrough.gd")
    command += ["--fixed-fps", "60", "--script", script]
    if args.mode == "movie" or args.mode.startswith("campaign-movie-"):
        command += ["--write-movie", str(run / "continuous.avi")]
    command += ["--", "--capture-dir=" + str(run), "--report=" + str(run / "rules-report.json")]
    if args.mode in ["campaign-rules", "migration-headless", "migration-rendered"] and legacy.exists():
        command += ["--legacy-fixture=" + str(target)]
    if args.mode == "validation-headless":
        command += ["--case=" + args.validation_case]
    if args.mode == "movie":
        command += ["--movie-only"]
    if args.mode.startswith("campaign-movie-"):
        command += ["--segment=" + args.mode.removeprefix("campaign-movie-")]
    if args.opening_only:
        command += ["--opening-only"]
    if args.mode == "clipboard-locked":
        command += ["--os-clipboard-locked"]
    before = sources()
    (run / "source-hashes.json").write_text(json.dumps(before, indent=2))
    normalized = {}
    frozen = run / "executed-source"
    for name in before:
        target = frozen / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((PROJECT / name).read_bytes())
        lf = (PROJECT / name).read_bytes().replace(b"\r\n", b"\n")
        normalized[name] = hashlib.sha256(lf).hexdigest()
        lf_target = run / "executed-source-lf" / name
        lf_target.parent.mkdir(parents=True, exist_ok=True)
        lf_target.write_bytes(lf)
    (run / "source-hashes-lf.json").write_text(json.dumps(normalized, indent=2))
    clip_open = False
    lock_proof = {"requested": args.mode == "clipboard-locked", "opened": False, "released": False}
    try:
        if args.mode == "clipboard-locked":
            # No EmptyClipboard/GetClipboardData: only a bounded real OS exclusion.
            for attempt in range(40):
                if ctypes.windll.user32.OpenClipboard(None):
                    clip_open = True
                    lock_proof["opened"] = True
                    break
                time.sleep(0.05)
            if not clip_open:
                raise RuntimeError("Could not acquire the exclusive Windows clipboard test lock")
        with (run / "godot.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
            (run / "process.json").write_text(json.dumps({"pid": process.pid, "command": command}))
            started = time.monotonic()
            while process.poll() is None:
                time.sleep(0.1)
                if clip_open and ((run / "release-clipboard-lock.request").exists() or time.monotonic() - started > 15):
                    assert ctypes.windll.user32.CloseClipboard()
                    clip_open = False
                    lock_proof["released"] = True
                    (run / "clipboard-lock.released").write_text("released")
                current = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
                if "SCRIPT ERROR:" in current or time.monotonic() - started > 5400:
                    process.terminate()
                    process.wait(timeout=15)
                    break
            code = process.returncode
    finally:
        if clip_open:
            ctypes.windll.user32.CloseClipboard()
            lock_proof["released"] = True
        (run / "clipboard-lock-proof.json").write_text(json.dumps(lock_proof, indent=2))
    output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
    errors = [line for line in output.splitlines() if line.startswith("ERROR:")]
    expected_clip_errors = args.mode == "clipboard-locked" and bool(errors) and all(line == "ERROR: Unable to open clipboard." for line in errors)
    okay = code == 0 and "SUITE_COMPLETE: PASS" in output and "SCRIPT ERROR:" not in output and (not errors or expected_clip_errors)
    if args.mode == "clipboard-locked":
        okay = okay and expected_clip_errors and lock_proof["opened"] and lock_proof["released"]
    receipt = {"command": command, "exit_code": code, "passed": okay, "source_unchanged": before == sources(),
               "engine": str(GODOT), "scope": args.mode, "inputs": inputs, "expected_clipboard_os_error_count": len(errors) if expected_clip_errors else 0, "unexpected_errors": [] if expected_clip_errors else errors, "artifacts": []}
    receipt["fully_decoded_pngs"] = []
    for p in sorted(run.glob("*.png")):
        with Image.open(p) as im:
            im.load()
            receipt["fully_decoded_pngs"].append({"name": p.name, "size": list(im.size), "mode": im.mode})
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
