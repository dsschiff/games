"""Bounded matched Tower movies. Coordinator GPU grant required before either mode."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
from PIL import Image
from design_check import ROOT, GODOT, sources

FFMPEG = "C:/Users/Daniel/AppData/Local/Microsoft/WinGet/Links/ffmpeg.exe"
FFPROBE = "C:/Users/Daniel/AppData/Local/Microsoft/WinGet/Links/ffprobe.exe"
VIEW = ROOT / "scripts/presentation/tower_view.gd"
BASELINE = "b4a5899"


def digest(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["before", "after"])
    args = parser.parse_args()
    run = ROOT / ".artifacts" / ("association-" + args.mode + "-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    run.mkdir(parents=True)
    candidate = VIEW.read_bytes()
    source_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    env = os.environ.copy()
    for name in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
        target = run / name.lower()
        target.mkdir()
        env[name] = str(target)
    receipt = {"mode": args.mode, "candidate_commit": source_commit, "baseline_commit": BASELINE,
               "passed": False, "scope": "Same fresh actual touch route, fixed60fps1x; no measured device FPS, human acceptance, save/version change or synthetic earned progress."}
    try:
        if args.mode == "before":
            VIEW.write_bytes(subprocess.check_output(["git", "show", BASELINE + ":android-games/tower-trials/scripts/presentation/tower_view.gd"], cwd=ROOT))
        before = sources()
        (run / "source-executed.json").write_text(json.dumps(before, indent=2), encoding="utf8")
        command = [GODOT, "--audio-driver", "Dummy", "--path", str(ROOT), "--fixed-fps", "60", "--resolution", "600x1066", "--position", "0,0",
                   "--write-movie", str(run / "capture.avi"), "--script", "tests/association_motion.gd", "--", "--capture-dir=" + str(run)]
        receipt["command"] = command
        with (run / "godot.log").open("w", encoding="utf8") as log:
            code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=300).returncode
        output = (run / "godot.log").read_text(encoding="utf8", errors="replace")
        errors = [line for line in output.splitlines() if "ERROR:" in line or "Parse Error:" in line]
        receipt.update(exit_code=code, raw_errors=errors, source_unchanged_during_capture=sources() == before,
                       functional=json.loads((run / "association-result.json").read_text()),
                       strict_run_passed=code == 0 and not errors and "SUITE_COMPLETE: PASS" in output)
    finally:
        VIEW.write_bytes(candidate)
        receipt["candidate_restored_exactly"] = VIEW.read_bytes() == candidate
        (run / "receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf8")
    if errors or not receipt["source_unchanged_during_capture"]:
        raise SystemExit("Raw renderer/source error; preserve failed packet and raw movie")
    if args.mode == "after" and not receipt["strict_run_passed"]:
        raise SystemExit("After strict gate failed; preserve failed packet and raw movie")
    # Baseline functional failures remain FAIL in the receipt. Encoding is useful
    # for the visible A/B comparison; it never reclassifies those assertions.
    movie = run / "capture.avi"
    receipt["raw_movie"] = {"bytes": movie.stat().st_size, "sha256": digest(movie)}
    mp4 = run / "association-1x.mp4"
    encode = [FFMPEG, "-y", "-i", str(movie), "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(mp4)]
    decode = [FFMPEG, "-v", "error", "-i", str(mp4), "-f", "null", "-"]
    receipt["encode_command"] = encode
    receipt["decode_command"] = decode
    for command, name in [(encode, "encode.log"), (decode, "decode.log")]:
        with (run / name).open("w", encoding="utf8") as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
    probe = [FFPROBE, "-v", "error", "-count_frames", "-show_streams", "-show_format", "-of", "json", str(mp4)]
    metadata = json.loads(subprocess.check_output(probe))
    assert len(metadata["streams"]) == 1 and metadata["streams"][0]["r_frame_rate"] == "60/1"
    assert (run / "decode.log").stat().st_size == 0
    receipt["movie"] = {"bytes": mp4.stat().st_size, "sha256": digest(mp4), "metadata": metadata, "fully_decoded": True}
    receipt["pngs"] = []
    for file in sorted(run.glob("*.png")):
        with Image.open(file) as image:
            image.load()
            receipt["pngs"].append({"file": file.name, "size": list(image.size), "sha256": digest(file)})
    receipt["artifacts"] = {p.name: {"bytes": p.stat().st_size, "sha256": digest(p)} for p in run.iterdir() if p.is_file() and p.name not in ["receipt.json", "capture.avi", "capture.wav"]}
    for file in [movie, run / "capture.wav"]:
        if file.exists():
            assert file.resolve().parent == run.resolve() and run.resolve().is_relative_to((ROOT / ".artifacts").resolve())
            file.unlink()
    receipt["verified_superseded_raw_deleted"] = True
    receipt["passed"] = receipt["strict_run_passed"]
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf8")
    print(json.dumps({"run": str(run), "strict_run_passed": receipt["strict_run_passed"], "frames": metadata["streams"][0]["nb_read_frames"], "duration": metadata["format"]["duration"], "raw_deleted": True}, indent=2))


if __name__ == "__main__":
    main()
