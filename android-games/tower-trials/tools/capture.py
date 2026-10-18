"""Bounded first-loop actual-input movie using the pinned engine and local ffmpeg."""
from pathlib import Path
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GODOT = "C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"
FFMPEG = "C:/Users/Daniel/AppData/Local/Microsoft/WinGet/Links/ffmpeg.exe"

def main():
    folder = ROOT / ".artifacts/campaign/motion"
    folder.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["APPDATA"] = str(ROOT / ".artifacts/runtime/AppData/Roaming")
    env["LOCALAPPDATA"] = str(ROOT / ".artifacts/runtime/AppData/Local")
    command = [GODOT, "--path", str(ROOT), "--audio-driver", "Dummy", "--fixed-fps", "60", "--write-movie", str(folder / "tower-campaign.avi"), "--script", "tests/campaign_motion.gd"]
    result = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=180)
    (folder / "capture.log").write_text(result.stdout, encoding="utf-8")
    print(result.stdout)
    if result.returncode or any(word in result.stdout for word in ["SCRIPT ERROR:", "ERROR:", "FAIL:"]):
        raise SystemExit(1)
    encode = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", str(folder / "tower-campaign.avi"), "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:v", "libx264", "-crf", "21", "-preset", "fast", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-c:a", "aac", str(folder / "tower-campaign.mp4")]
    subprocess.run(encode, check=True, timeout=120)
    (folder / "commands.json").write_text(json.dumps({"capture": command, "encode": encode, "clock": "60 fixed engine fps; not measured device FPS", "input": "tests/campaign_motion.gd injects only touch events; game _process resolves fights"}, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
