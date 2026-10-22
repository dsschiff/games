"""3D presentation checks and a normal-speed actual-input clip.

    python android-games/tower-trials/tools/graphics_check.py view    # headless + rendered graphics_view.gd
    python android-games/tower-trials/tools/graphics_check.py clip    # 60 fps movie of tests/challenge_motion.gd
    python android-games/tower-trials/tools/graphics_check.py tour [--label after] [--size 720x1280]
                                                                     # rendered review frames (tests/graphics_tour.gd)

Everything is written under this game's ignored .artifacts/graphics/.
The movie clock is 60 fixed engine fps, so playback at 60 fps is normal
speed; it is not a device FPS measurement.
"""
from pathlib import Path
import argparse
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
GODOT = "C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"
FFMPEG = "C:/Users/Daniel/AppData/Local/Microsoft/WinGet/Links/ffmpeg.exe"
OUT = ROOT / ".artifacts/graphics"


def environment():
    env = os.environ.copy()
    for key, tail in [("APPDATA", "AppData/Roaming"), ("LOCALAPPDATA", "AppData/Local"), ("TEMP", "tmp"), ("TMP", "tmp")]:
        target = ROOT / ".artifacts/runtime" / tail
        target.mkdir(parents=True, exist_ok=True)
        env[key] = str(target)
    return env


def godot(arguments, log):
    command = [GODOT, "--audio-driver", "Dummy", "--path", str(ROOT), "--fixed-fps", "60"] + arguments
    result = subprocess.run(command, env=environment(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace", timeout=300)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(result.stdout, encoding="utf-8")
    print(result.stdout)
    bad = any(word in result.stdout for word in ["SCRIPT ERROR:", "ERROR:", "FAIL:"])
    return command, result.returncode or int(bad)


IMPORT_ARGUMENTS = ["--headless", "--editor", "--import", "--quit"]


def needs_import(project):
    """True when the project has no imported resources yet (fresh worktree: .godot/imported absent or empty)."""
    imported = Path(project) / ".godot/imported"
    return not (imported.is_dir() and any(imported.iterdir()))


def view():
    if needs_import(ROOT):
        _, imported = godot(IMPORT_ARGUMENTS, OUT / "import.log")
        if imported:
            return imported
    _, headless = godot(["--headless", "--script", "tests/graphics_view.gd"], OUT / "view-headless.log")
    _, rendered = godot(["--script", "tests/graphics_view.gd"], OUT / "view-rendered.log")
    return headless or rendered


def clip():
    folder = OUT / "motion"
    folder.mkdir(parents=True, exist_ok=True)
    movie = folder / "tower-graphics-challenge.avi"
    command, code = godot(["--write-movie", str(movie), "--script", "tests/challenge_motion.gd"], folder / "capture.log")
    if code:
        return code
    mp4 = folder / "tower-graphics-challenge.mp4"
    encode = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", str(movie), "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
              "-r", "60", "-c:v", "libx264", "-crf", "21", "-preset", "fast", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
              "-an", str(mp4)]
    subprocess.run(encode, check=True, timeout=180)
    (folder / "commands.json").write_text(json.dumps({"capture": command, "encode": encode,
        "clock": "60 fixed engine fps written by --write-movie; played at 60 fps this is normal speed; not measured device FPS",
        "input": "tests/challenge_motion.gd injects only touch events; game _process resolves moves"}, indent=2), encoding="utf-8")
    return 0


def tour(label, size):
    _, code = godot(["--resolution", size, "--script", "tests/graphics_tour.gd", "--", "--label=" + label, "--size=" + size],
                    OUT / "tour" / label / "tour.log")
    return code


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["view", "clip", "tour"])
    parser.add_argument("--label", default="current")
    parser.add_argument("--size", default="720x1280")
    args = parser.parse_args()
    sys.exit(view() if args.mode == "view" else clip() if args.mode == "clip" else tour(args.label, args.size))
