"""Focused real-input presentation comparison; no clipboard, ADB or gameplay injection."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from datetime import datetime, timezone
from run_campaign import PROJECT, GODOT, sources


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--before", action="store_true")
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()
    run = PROJECT / ".artifacts" / ("feedback-" + ("before-" if args.before else "after-") + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ["APPDATA", "LOCALAPPDATA"]:
        env[key] = str(run / key)
        Path(env[key]).mkdir()
    command = [str(GODOT), "--audio-driver", "Dummy", "--path", str(PROJECT), "--fixed-fps", "60"]
    command += ["--headless"] if args.headless else ["--resolution", "720x1280"]
    command += ["--script", "res://tests/reinforcement_input.gd", "--", "--capture-dir=" + str(run)]
    if args.before:
        baseline = run / "before_campaign.gd"
        baseline.write_bytes(subprocess.check_output(["git", "-C", str(PROJECT), "show", "4552e7b:android-games/frontline-foundry/scripts/campaign_main.gd"]))
        command += ["--before-campaign=" + str(baseline)]
    before = sources()
    for name in before:
        target = run / "executed-source" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((PROJECT / name).read_bytes())
    with (run / "godot.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
    output = (run / "godot.log").read_text(encoding="utf-8")
    okay = result.returncode == 0 and "SUITE_COMPLETE: PASS" in output and before == sources() and "ERROR:" not in output
    receipt = {"command": command, "exit_code": result.returncode, "passed": okay, "source_unchanged": before == sources(), "source_hashes": before, "files": {str(f.relative_to(run)): hashlib.sha256(f.read_bytes()).hexdigest() for f in run.rglob("*") if f.is_file()}}
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(output[-3000:])
    print(run)
    raise SystemExit(0 if okay else 1)


if __name__ == "__main__":
    main()
