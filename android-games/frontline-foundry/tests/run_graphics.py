"""Isolated, source-bound Frontline graphics checks/captures. No SDK or ADB.

Rendered modes require the coordinator's serialized GPU slot. --render is an
explicit execution choice, never a claim that a slot or art acceptance exists.
"""
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


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def sources():
    suffixes = {".gd", ".uid", ".godot", ".tscn", ".svg", ".import", ".cfg", ".py", ".glb", ".json"}
    return {p.relative_to(PROJECT).as_posix(): sha(p)
            for p in sorted(PROJECT.rglob("*"))
            if p.is_file() and p.suffix in suffixes
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


def import_project(run, env):
    command = [str(GODOT), "--headless", "--editor", "--import", "--quit", "--path", str(PROJECT)]
    before = sources()
    with (run / "import.log").open("w", encoding="utf-8") as log:
        try:
            code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180).returncode
        except subprocess.TimeoutExpired:
            code = 124
    output = (run / "import.log").read_text(encoding="utf-8", errors="replace")
    errors = [line for line in output.splitlines()
              if any(marker in line for marker in ["ERROR:", "SCRIPT ERROR:", "Parse Error:"])]
    after = sources()
    result = {"command": command, "exit_code": code, "passed": code == 0 and not errors,
              "errors": errors, "source_before_sha256": before, "source_after_sha256": after,
              "source_unchanged": before == after, "log": "import.log"}
    (run / "import-report.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["checks", "capture", "closure", "gallery", "tour", "legacy"])
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--movie", action="store_true")
    parser.add_argument("--seconds", type=float, default=145)
    parser.add_argument("--resume-from", type=Path)
    parser.add_argument("--label", default="graphics")
    parser.add_argument("--stage", choices=["sideways", "park", "restore", "retry"], default="park")
    parser.add_argument("--native-frames", action="store_true")
    parser.add_argument("--movie-fps", type=int, choices=[30, 60], default=30)
    parser.add_argument("--measure-frames", action="store_true")
    args = parser.parse_args()
    if args.movie and (args.mode not in {"capture", "gallery", "tour", "legacy"} or not args.render):
        parser.error("Movie recording requires capture --render and the coordinator's GPU slot")
    if args.native_frames and (args.mode != "closure" or not args.render or args.movie):
        parser.error("Native frame recording requires closure --render and the coordinator's GPU slot")
    if args.measure_frames and (args.mode != "capture" or not args.render or args.movie or args.native_frames):
        parser.error("Frame timing requires real-time capture --render with no movie/fixed-step recording")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run = PROJECT / ".artifacts" / f"{args.label}-{args.mode}-{stamp}"
    run.mkdir(parents=True)
    env = os.environ.copy()
    for name in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
        path = run / name.lower()
        path.mkdir()
        env[name] = str(path)
    resume = {}
    expected_start = None
    if args.resume_from:
        source = args.resume_from.resolve()
        if not source.is_relative_to((PROJECT / ".artifacts").resolve()):
            parser.error("resume source must be retained inside this game's isolated artifacts")
        target = Path(env["APPDATA"]) / "Godot/app_userdata/Frontline Foundry"
        target.mkdir(parents=True)
        for path in sorted(source.glob("frontline-save-*")):
            shutil.copy2(path, target / path.name)
            assert sha(path) == sha(target / path.name)
            resume[path.name] = sha(path)
        if not resume:
            parser.error("resume source must contain authentic app-written frontline-save slots")
        packets = []
        for path in sorted(source.glob("frontline-save-*")):
            envelope = json.loads(path.read_text())
            assert hashlib.sha256(envelope["payload"].encode()).hexdigest() == envelope["sha256"]
            packet = json.loads(envelope["payload"])
            if packet["committed"]:
                packets.append(packet)
        expected_start = run / "expected-start.json"
        expected_start.write_text(json.dumps(max(packets, key=lambda item: item["revision"])))
    command = [str(GODOT), "--path", str(PROJECT)]
    command += ["--resolution", "720x1280", "--position", "0,0"] if args.render else ["--headless"]
    script = {"checks": "presentation_tests.gd", "capture": "graphics_benchmark.gd", "closure": "graphics_closure.gd", "gallery": "art_gallery.gd", "tour": "graphics_tour.gd", "legacy": "graphics_legacy.gd"}[args.mode]
    command += ["--script", "res://tests/" + script]
    if args.movie:
        command += ["--fixed-fps", str(args.movie_fps), "--write-movie", str(run / "continuous.avi")]
    elif args.mode == "closure":
        command += ["--fixed-fps", str(args.movie_fps)]
    command += ["--", "--capture-dir=" + str(run), "--seconds=" + str(args.seconds)]
    if args.measure_frames:
        command += ["--measure-frames"]
    if expected_start:
        command += ["--expected-start=" + str(expected_start)]
    if args.mode == "closure":
        command += ["--stage=" + args.stage]
        if args.native_frames:
            command += ["--native-frames"]
    if args.mode == "checks":
        baseline = run / "baseline"
        baseline.mkdir()
        for name in ["rules.gd", "campaign_rules.gd"]:
            raw = subprocess.check_output(["git", "-C", str(PROJECT), "show", "501f6dc:android-games/frontline-foundry/scripts/" + name])
            (baseline / name).write_bytes(raw)
        command += ["--baseline-dir=" + str(baseline).replace("\\", "/") + "/"]
    # A fresh checkout has .import sidecars but no imported PackedScene cache.
    # Complete/verify the CPU-only import before binding the executed sources.
    imported = import_project(run, env)
    before = sources()
    (run / "source-hashes.json").write_text(json.dumps(before, indent=2) + "\n")
    for name in before:
        target = run / "executed-source" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / name, target)
    with (run / "godot.log").open("w", encoding="utf-8") as log:
        if imported["passed"]:
            try:
                code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                      timeout=180 if args.mode == "checks" else max(180, args.seconds * 4 + 120)).returncode
            except subprocess.TimeoutExpired:
                code = 124
        else:
            code = 126
            log.write("NOT EXECUTED: headless import preflight failed; see import.log and import-report.json.\n")
    output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
    report = json.loads((run / "benchmark-report.json").read_text()) if (run / "benchmark-report.json").exists() else None
    passed = imported["passed"] and code == 0 and not any(x in output for x in ["ERROR:", "SCRIPT ERROR:", "Parse Error:"])
    passed &= ("SUITE_COMPLETE: PASS" in output) if args.mode == "checks" else (report is not None and not report["errors"])
    frame_encoding = None
    if args.native_frames and (run / "frames/000000.png").exists():
        encode = ["ffmpeg", "-v", "error", "-framerate", str(args.movie_fps), "-i", str(run / "frames/%06d.png"),
                  "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(run / "continuous.mp4")]
        encoded = subprocess.run(encode, capture_output=True)
        frame_encoding = {"command": encode, "exit_code": encoded.returncode, "stderr": encoded.stderr.decode(errors="replace"),
                          "pixel_policy": "Native game frames blitted at 1:1 into a fixed evidence canvas; padding only, no scaling or temporal retiming", "audio": "silent focused validation"}
        passed &= encoded.returncode == 0
        (run / "frame-encoding.json").write_text(json.dumps(frame_encoding, indent=2) + "\n")
    elif args.native_frames:
        passed = False
    probe = None
    movie_path = run / ("continuous.mp4" if args.native_frames else "continuous.avi")
    if (args.movie or args.native_frames) and movie_path.exists():
        probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie_path)]))
        video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
        probe["meets_native_720x1280"] = video["width"] >= 720 and video["height"] >= 1280
        probe["full_decode_passed"] = subprocess.run(["ffmpeg", "-v", "error", "-i", str(movie_path), "-f", "null", "-"], capture_output=True).returncode == 0
        (run / "movie-probe.json").write_text(json.dumps(probe, indent=2) + "\n")
        passed &= probe["meets_native_720x1280"] and probe["full_decode_passed"]
    receipt = {"mode": args.mode, "command": command, "exit_code": code, "passed": passed,
               "command_executed": imported["passed"], "import_preflight": imported,
               "native_frame_encoding": frame_encoding,
               "source_unchanged": before == sources(), "resume_from": str(args.resume_from) if args.resume_from else None,
               "resume_slot_sha256": resume, "engine": str(GODOT),
               "encoded_movie_dimensions": ({key: next(stream for stream in probe["streams"] if stream["codec_type"] == "video")[key] for key in ["width", "height", "r_frame_rate"]} if probe else None),
               "limits": ["Headless checks do not establish visual quality", "Movie statistics include fixed-step recording/encoding and are not real-time or phone performance", "A capture is not independent graphics acceptance"], "artifacts": []}
    for path in sorted(run.rglob("*")):
        if path.is_file():
            receipt["artifacts"].append({"path": path.relative_to(run).as_posix(), "bytes": path.stat().st_size, "sha256": sha(path)})
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("\n".join(output.splitlines()[-12:]))
    print(run)
    print("GRAPHICS_RESULT", "PASS" if passed and receipt["source_unchanged"] else "FAIL")
    raise SystemExit(0 if passed and receipt["source_unchanged"] else 1)


if __name__ == "__main__":
    main()
