"""Source-bound isolated campaign validation; no SDK, ADB, editor or global writes."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")


def sources():
    suffixes = {".gd", ".uid", ".godot", ".tscn", ".svg", ".import", ".cfg", ".py"}
    return {str(p.relative_to(PROJECT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(PROJECT.rglob("*")) if p.is_file() and p.suffix in suffixes
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["rules", "balance", "input", "rendered", "movie", "cold", "legacy", "clipboard", "decisions"])
    parser.add_argument("--label", default="campaign")
    parser.add_argument("--resume-from", type=Path)
    parser.add_argument("--clip", choices=["early", "middle", "final"], default="early")
    parser.add_argument("--clipboard-destination", action="store_true")
    args = parser.parse_args()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run = PROJECT / ".artifacts" / f"{args.label}-{args.mode}-{stamp}"
    run.mkdir(parents=True)
    env = os.environ.copy()
    env["APPDATA"] = str(run / "appdata")
    env["LOCALAPPDATA"] = str(run / "localappdata")
    Path(env["APPDATA"]).mkdir()
    Path(env["LOCALAPPDATA"]).mkdir()
    if args.resume_from:
        previous = args.resume_from.resolve()
        if not previous.is_relative_to((PROJECT / ".artifacts").resolve()):
            parser.error("resume source must be an isolated artifact within this game")
        if (previous / "appdata").is_dir():
            shutil.copytree(previous / "appdata", Path(env["APPDATA"]), dirs_exist_ok=True)
        else:
            target = Path(env["APPDATA"]) / "Godot/app_userdata/Frontline Foundry"
            target.mkdir(parents=True)
            for p in previous.glob("frontline-save-*"):
                shutil.copy2(p, target / p.name)
    command = [str(GODOT), "--audio-driver", "Dummy", "--path", str(PROJECT)]
    command += ["--resolution", "720x1280", "--position", "0,0"] if args.mode in {"rendered", "movie", "clipboard"} else ["--headless"]
    script = {"rules": "campaign_tests", "balance": "campaign_balance", "decisions": "decision_probe", "cold": "campaign_cold", "legacy": "campaign_legacy", "clipboard": "campaign_clipboard"}.get(args.mode, "campaign_input")
    command += ["--fixed-fps", "60", "--script", f"res://tests/{script}.gd", "--quit-after", "2" if args.mode in {"rules", "balance", "decisions"} else "100000"]
    if args.mode == "movie":
        command += ["--write-movie", str(run / "continuous.avi")]
    command += ["--", "--capture-dir=" + str(run), "--report=" + str(run / "rules-report.json")]
    if args.mode == "movie":
        command += ["--movie-only", "--clip=" + args.clip]
    if args.clipboard_destination:
        command += ["--clipboard-destination"]
    before = sources()
    (run / "source-hashes.json").write_text(json.dumps(before, indent=2))
    (run / "source-hashes-lf.json").write_text(json.dumps({name: hashlib.sha256((PROJECT / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest() for name in before}, indent=2))
    for name in before:
        target = run / "executed-source" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((PROJECT / name).read_bytes())
    with (run / "godot.log").open("w", encoding="utf-8") as log:
        try:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1200)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
    output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
    okay = code == 0 and "SUITE_COMPLETE: PASS" in output and not any(x in output for x in ["ERROR:", "SCRIPT ERROR:", "Parse Error:"])
    receipt = {"command": command, "exit_code": code, "passed": okay, "source_unchanged": before == sources(), "engine": str(GODOT), "scope": args.mode, "resume_from": str(args.resume_from) if args.resume_from else None, "artifacts": []}
    for p in sorted(run.rglob("*")):
        if p.is_file():
            with p.open("rb") as stream:
                sha = hashlib.file_digest(stream, "sha256").hexdigest()
            receipt["artifacts"].append({"path": str(p.relative_to(run)).replace("\\", "/"), "bytes": p.stat().st_size, "sha256": sha})
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2))
    print("\n".join(output.splitlines()[-35:]))
    print(run)
    print("CAMPAIGN_RESULT", "PASS" if okay and receipt["source_unchanged"] else "FAIL")
    raise SystemExit(0 if okay and receipt["source_unchanged"] else 1)


if __name__ == "__main__":
    main()
