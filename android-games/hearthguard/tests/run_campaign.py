"""Source-bound isolated campaign evidence; no Android/export/editor commands."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
from run_desktop import PROJECT, GODOT, sources


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["rules", "headless", "rendered", "movie", "legacy"])
    parser.add_argument("--label", default="campaign")
    parser.add_argument("--segment", choices=["early", "middle", "final"])
    parser.add_argument("--checkpoint")
    args = parser.parse_args()
    run = PROJECT / ".artifacts" / f"{args.label}-{args.mode}-{datetime.now(timezone.utc):%Y%m%dT%H%M%S%fZ}"
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ["APPDATA", "LOCALAPPDATA"]:
        env[key] = str(run / key.lower())
        Path(env[key]).mkdir()
    command = [str(GODOT), "--path", str(PROJECT), "--fixed-fps", "60"]
    if args.mode in ["rules", "headless", "legacy"]:
        command += ["--headless"]
    else:
        command += ["--disable-vsync", "--max-fps", "0", "--position", "0,0"]
    script = "res://tests/campaign_checks.gd" if args.mode == "rules" else ("res://tests/legacy_compatibility.gd" if args.mode == "legacy" else "res://tests/campaign_journey.gd")
    command += ["--script", script]
    if args.mode == "movie":
        command += ["--write-movie", str(run / "continuous.avi")]
    command += ["--", "--capture-dir=" + str(run)]
    if args.segment:
        command += ["--segment=" + args.segment]
    if args.checkpoint:
        command += ["--checkpoint=" + str(Path(args.checkpoint).resolve())]
    before = sources()
    (run / "source-hashes.json").write_text(json.dumps(before, indent=2))
    for name in before:
        target = run / "executed-source" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((PROJECT / name).read_bytes())
    with (run / "godot.log").open("w", encoding="utf-8") as log:
        try:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1800)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
    output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
    okay = code == 0 and "SUITE_COMPLETE: PASS" in output and not any(x in output for x in ["ERROR:", "SCRIPT ERROR:", "Parse Error:"])
    receipt = {"command": command, "exit_code": code, "passed": okay, "source_unchanged": before == sources(), "artifacts": []}
    for p in sorted(run.rglob("*")):
        if p.is_file():
            receipt["artifacts"].append({"path": p.relative_to(run).as_posix(), "bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()})
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2))
    print(output)
    print(run)
    print("CAMPAIGN_RESULT", "PASS" if okay and receipt["source_unchanged"] else "FAIL")
    raise SystemExit(0 if okay and receipt["source_unchanged"] else 1)


if __name__ == "__main__":
    main()
