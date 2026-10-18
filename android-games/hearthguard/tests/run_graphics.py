"""Source-bound Hearthguard presentation evidence. Render modes require root's slot.

Headless import completes before execution is bound. Every run has isolated data;
old evidence is additive. Movie cadence is never a measured performance result.
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
    return {p.relative_to(PROJECT).as_posix(): sha(p) for p in sorted(PROJECT.rglob("*"))
            if p.is_file() and p.suffix in suffixes
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["checks", "pool-checks", "composition-checks", "inspect", "capture", "closure", "tour", "legacy"])
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--movie", action="store_true")
    parser.add_argument("--native-frames", action="store_true")
    parser.add_argument("--seconds", type=float, default=8)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--label", default="graphics")
    parser.add_argument("--measure-frames", action="store_true")
    args = parser.parse_args()
    if args.movie:
        parser.error("Use --native-frames; the internal writer recorded 450x800 on this host despite the native 720x1280 window")
    if args.native_frames and (not args.render or args.measure_frames):
        parser.error("Native frame recording requires --render and excludes real-time timing")
    cpu_modes = {"checks", "pool-checks", "composition-checks"}
    if args.render and args.mode in cpu_modes:
        parser.error("Checks are CPU only")
    if not args.render and args.mode not in cpu_modes:
        parser.error("Rendered passages require explicit --render and coordinator's GPU grant")
    run = PROJECT / ".artifacts" / f"{args.label}-{args.mode}-{datetime.now(timezone.utc):%Y%m%dT%H%M%S%fZ}"
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
        path = run / key.lower()
        path.mkdir()
        env[key] = str(path)
    command_import = [str(GODOT), "--headless", "--editor", "--import", "--quit", "--path", str(PROJECT)]
    with (run / "import.log").open("w", encoding="utf-8") as log:
        imported = subprocess.run(command_import, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
    import_output = (run / "import.log").read_text(encoding="utf-8", errors="replace")
    errors = [line for line in import_output.splitlines()
              if any(marker in line for marker in ["ERROR:", "SCRIPT ERROR:", "Parse Error:"])]
    parse_command = [str(GODOT), "--headless", "--path", str(PROJECT), "--check-only", "--script", "res://tests/graphics_passage.gd"]
    with (run / "passage-parse.log").open("w", encoding="utf-8") as log:
        parsed = subprocess.run(parse_command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=60)
    parse_output = (run / "passage-parse.log").read_text(encoding="utf-8", errors="replace")
    errors += [line for line in parse_output.splitlines()
               if any(marker in line for marker in ["ERROR:", "SCRIPT ERROR:", "Parse Error:"])]
    preflight = {"command": command_import, "exit_code": imported.returncode,
                 "passage_parse_command": parse_command, "passage_parse_exit": parsed.returncode,
                 "passed": imported.returncode == 0 and parsed.returncode == 0 and not errors, "errors": errors}
    (run / "import-report.json").write_text(json.dumps(preflight, indent=2) + "\n")
    command = [str(GODOT), "--path", str(PROJECT)]
    command += ["--resolution", "720x1280", "--position", "0,0"] if args.render else ["--headless"]
    script = {"checks": "presentation_tests.gd", "pool-checks": "pool_tests.gd", "composition-checks": "composition_tests.gd"}.get(args.mode, "graphics_passage.gd")
    command += ["--script", "res://tests/" + script]
    if args.native_frames:
        command += ["--fixed-fps", "30"]
    command += ["--", "--capture-dir=" + str(run), "--seconds=" + str(args.seconds), "--mode=" + args.mode]
    if args.measure_frames:
        command += ["--measure-frames"]
    if args.native_frames:
        command += ["--native-frames"]
    if args.checkpoint:
        source = args.checkpoint.resolve()
        if not source.is_relative_to((PROJECT / ".artifacts").resolve()):
            parser.error("Checkpoint must be retained genuine earned evidence in this game")
        frozen = run / "earned-checkpoint.json"
        shutil.copy2(source, frozen)
        assert sha(source) == sha(frozen)
        command += ["--checkpoint=" + str(frozen)]
    if args.mode in cpu_modes:
        baseline = run / "baseline"
        baseline.mkdir()
        for name in ["rules.gd", "campaign_rules.gd", "campaign_catalog.gd", "save_store.gd", "save_files.gd"]:
            raw = subprocess.check_output(["git", "-C", str(PROJECT), "show", "c36df6e:android-games/hearthguard/scripts/" + name])
            (baseline / name).write_bytes(raw)
        command += ["--baseline-dir=" + str(baseline).replace("\\", "/") + "/"]
    before = sources()
    (run / "source-hashes.json").write_text(json.dumps(before, indent=2) + "\n")
    for name in before:
        destination = run / "executed-source" / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / name, destination)
    with (run / "godot.log").open("w", encoding="utf-8") as log:
        if preflight["passed"]:
            try:
                code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                      timeout=300 if args.mode in cpu_modes else max(180, args.seconds * 5 + 90)).returncode
            except subprocess.TimeoutExpired:
                code = 124
        else:
            code = 126
            log.write("NOT EXECUTED: CPU import preflight failed\n")
    output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
    passed = preflight["passed"] and code == 0 and "SUITE_COMPLETE: PASS" in output
    passed &= not any(marker in output for marker in ["ERROR:", "SCRIPT ERROR:", "Parse Error:"])
    passed &= before == sources()
    if args.native_frames and (run / "frames/000000.png").exists():
        encode = ["ffmpeg", "-v", "error", "-framerate", "30", "-i", str(run / "frames/%06d.png"), "-an", "-c:v", "libx264", "-crf", "18",
                  "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(run / "continuous.mp4")]
        encoded = subprocess.run(encode, capture_output=True)
        decoded = subprocess.run(["ffmpeg", "-v", "error", "-i", str(run / "continuous.mp4"), "-f", "null", "-"], capture_output=True) if encoded.returncode == 0 else None
        probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(run / "continuous.mp4")])) if encoded.returncode == 0 else {}
        inventory = json.loads((run / "native-frame-inventory.json").read_text())
        stream = next((row for row in probe.get("streams", []) if row["codec_type"] == "video"), {})
        native_okay = bool(inventory["frames"]) and [stream.get("width"), stream.get("height")] == inventory["canvas"] and int(stream.get("nb_frames", -1)) == len(inventory["frames"])
        if args.mode != "closure":
            native_okay &= all(row["native"] == [720, 1280] for row in inventory["frames"])
        movie = {"encode_command": encode, "encode_exit": encoded.returncode, "probe": probe,
                 "decode_exit": decoded.returncode if decoded else None,
                 "native_inventory_matches_encoded_canvas_and_count": native_okay,
                 "policy": "Native source pixels blitted 1:1; padding only, no scaling/retiming; silent fixed30 cadence is not FPS"}
        (run / "movie-report.json").write_text(json.dumps(movie, indent=2) + "\n")
        passed &= encoded.returncode == 0 and decoded is not None and decoded.returncode == 0 and native_okay
    elif args.native_frames:
        passed = False
    receipt = {"mode": args.mode, "command": command, "exit_code": code, "passed": bool(passed),
               "import_preflight": preflight, "source_unchanged": before == sources(),
               "limits": ["No headless visual acceptance", "No phone FPS or fun claim"], "artifacts": []}
    for path in sorted(run.rglob("*")):
        if path.is_file():
            receipt["artifacts"].append({"path": path.relative_to(run).as_posix(), "bytes": path.stat().st_size, "sha256": sha(path)})
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print((import_output + parse_output)[-7000:] if not preflight["passed"] else "\n".join(output.splitlines()[-16:]))
    print(run)
    print("GRAPHICS_RESULT", "PASS" if passed else "FAIL")
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
