"""Source-bound actual gameplay recording; run only in the granted GPU slot."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from run_graphics import PROJECT, GODOT, execute, sources


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["opening", "heavy", "later", "reset", "restore", "legacy", "metrics", "reuse", "prepare-captain", "prepare-siege", "prepare-carapace", "captain", "siege", "carapace"])
    parser.add_argument("--seconds", type=float, default=40)
    parser.add_argument("--movie", action="store_true")
    parser.add_argument("--native-frames", action="store_true")
    parser.add_argument("--resume-from", type=Path)
    parser.add_argument("--inspection", action="store_true", help="Short boss inspection; does not assert defeat/outcome closure")
    args = parser.parse_args()
    if args.stage == "metrics" and (args.movie or args.native_frames):
        parser.error("Metrics must run at actual wall clock without movie/readback")
    if args.movie:
        parser.error("Use --native-frames: the internal movie writer startup canvas differs from the native window on this host")
    if args.movie and args.native_frames:
        parser.error("Choose one capture writer")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run = PROJECT/".artifacts/graphics-production"/("motion-"+args.stage+"-"+stamp)
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
        folder = run/key.lower(); folder.mkdir(); env[key] = str(folder)
    provenance = {"kind": "fresh actual app"}
    expected = None
    slots = []
    if args.stage in {"heavy", "later", "metrics", "reuse"} and not args.resume_from:
        name = "final-boss" if args.stage == "later" else "middle"
        source = PROJECT/".artifacts/campaign-pressure-motion"/(name+".json")
        index = PROJECT/"evidence/decision-pressure-checkpoint.json"
        indexed = json.loads(index.read_text(encoding="utf-8"))["clips"]
        allowed = {row["snapshot_sha256"] for row in indexed}
        assert sha(source) in allowed, "Starting save is not pinned in the original earned evidence index"
        slots = [(source, "bastion-save.json")]
        provenance = {"kind": "indexed genuine prior input-suite save", "source": str(source), "sha256": sha(source), "index": str(index), "index_sha256": sha(index)}
    elif args.stage in {"reset", "restore", "prepare-captain", "prepare-siege", "prepare-carapace", "captain", "siege", "carapace", "metrics"}:
        assert args.resume_from, "Reset/restore require authentic prior motion run"
        parent = args.resume_from.resolve()
        assert parent.is_relative_to((PROJECT/".artifacts/graphics-production").resolve())
        receipt = json.loads((parent/"receipt.json").read_text(encoding="utf-8"))
        report = json.loads((parent/"motion-report.json").read_text(encoding="utf-8"))
        assert receipt["passed"], "Prior motion run failed"
        assert receipt["gameplay_report_sha256"] == sha(parent/"motion-report.json"), "Prior gameplay report changed"
        for name, digest in report["raw_save_slots"].items():
            source = parent/"slots"/name
            assert sha(source) == digest
            slots.append((source, name))
        assert slots, "No app-written slots retained"
        provenance = {"kind": "byte-exact app-written slots from prior passed run", "parent": str(parent), "parent_receipt_sha256": sha(parent/"receipt.json")}
    if slots:
        user = run/"appdata/Godot/app_userdata/Gear Bastion"
        user.mkdir(parents=True)
        for source, name in slots:
            shutil.copyfile(source, user/name)
            assert sha(source) == sha(user/name)
        best = max(slots, key=lambda pair: json.loads(pair[0].read_text(encoding="utf-8")).get("revision", 0))[0]
        expected = run/"expected-start.json"
        shutil.copyfile(best, expected)
    import_before = sources()
    preflight, _ = execute([str(GODOT), "--headless", "--editor", "--import", "--quit", "--path", str(PROJECT)], run, env, "import")
    before = sources()
    # Retain byte-exact executed inputs, excluding private runtime/artifact trees.
    snapshot = run/"executed-source"
    for name in before:
        target = snapshot/name; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(PROJECT/name, target)
        assert sha(target) == before[name]
    command = [str(GODOT), "--path", str(PROJECT), "--audio-driver", "Dummy", "--resolution", "720x1680", "--position", "0,0"]
    fixed = args.movie or args.native_frames
    if fixed:
        command += ["--fixed-fps", "30"]
    if args.movie:
        command += ["--write-movie", str(run/"continuous.avi")]
    command += ["-s", "tests/graphics_motion.gd", "--", "--run-dir="+str(run), "--stage="+args.stage, "--seconds="+str(args.seconds)]
    if fixed: command += ["--capture-fixed-fps=30"]
    if args.native_frames: command += ["--native-frames"]
    if expected: command += ["--expected-start="+str(expected)]
    if args.inspection: command += ["--inspection"]
    result = preflight
    if preflight["passed"]:
        result, output = execute(command, run, env, "execution", timeout=max(180, int(args.seconds*5+120)))
        result["passed"] &= "SUITE_COMPLETE: PASS" in output
    after = sources()
    passed = result["passed"] and before == after
    media = {}
    if passed and fixed:
        movie = run/"continuous.mp4"
        convert = ["ffmpeg", "-hide_banner", "-y"]
        convert += ["-framerate", "30", "-i", str(run/"frames/%06d.png")] if args.native_frames else ["-i", str(run/"continuous.avi")]
        convert += ["-an", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(movie)]
        encoded, _ = execute(convert, run, env, "encode", timeout=180)
        decoded, _ = execute(["ffmpeg", "-v", "error", "-i", str(movie), "-f", "null", "-"], run, env, "decode", timeout=180)
        probe = subprocess.check_output(["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(movie)], text=True)
        (run/"media-probe.json").write_text(probe, encoding="utf-8")
        passed &= encoded["passed"] and decoded["passed"]
        stream = json.loads(probe)["streams"][0]
        media = {"path": str(movie), "sha256": sha(movie), "probe": json.loads(probe), "encoded": encoded, "fully_decoded": decoded, "normal_simulation_speed": True, "fps_is_not_performance": True, "padding": {"pixels": "native 1:1; no scaling", "canvas": [stream["width"], stream["height"]]} if args.native_frames else None}
    gameplay = run/"motion-report.json"
    if passed:
        data = json.loads(gameplay.read_text(encoding="utf-8"))
        assert data["stage"] == args.stage and not data["failures"] and data["frame_count"] > 0
    receipt = {"stage": args.stage, "passed": passed, "source_before": before, "source_after": after, "source_unchanged": before==after, "import_source_before": import_before, "import_source_after": before, "result": result, "starting_save": provenance, "gameplay_report_sha256": sha(gameplay) if gameplay.exists() else None, "media": media, "limits": "Desktop actual input/process-loop motion. Silent review movie; fixed cadence is not performance. No Android/phone acceptance."}
    (run/"receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps({"run": str(run), "passed": passed, "source_unchanged": before==after}), flush=True)
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
