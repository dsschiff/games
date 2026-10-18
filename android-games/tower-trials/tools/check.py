"""Run pinned Godot with game-private runtime state and preserved logs."""
from pathlib import Path
import argparse
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["rules", "input", "rendered", "import"])
    args = parser.parse_args()
    runtime = ROOT / ".artifacts/runtime"
    env = os.environ.copy()
    for key, tail in [("APPDATA", "AppData/Roaming"), ("LOCALAPPDATA", "AppData/Local"), ("TEMP", "tmp"), ("TMP", "tmp")]:
        target = runtime / tail
        target.mkdir(parents=True, exist_ok=True)
        env[key] = str(target)
    command = [str(GODOT), "--audio-driver", "Dummy", "--path", str(ROOT)]
    if args.mode != "rendered":
        command += ["--headless"]
    if args.mode == "import":
        command += ["--editor", "--import", "--quit"]
    else:
        command += ["--fixed-fps", "60", "--script", "tests/run_tests.gd" if args.mode == "rules" else "tests/playthrough.gd"]
    log = ROOT / f".artifacts/campaign/{args.mode}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=600)
    log.write_text(result.stdout, encoding="utf-8")
    print(result.stdout)
    bad = any(word in result.stdout for word in ["SCRIPT ERROR:", "ERROR:", "FAIL:"])
    return result.returncode or int(bad)

if __name__ == "__main__":
    sys.exit(main())
