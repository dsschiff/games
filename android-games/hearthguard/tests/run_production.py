"""Source-bound Hearthguard production passages. Root must explicitly grant GPU.

Uses the proven native frame writer and Frontline timing pattern. Never exports,
uses ADB/clipboard or generates progression. Each invocation is a fresh process.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from production_sources import PROJECT, PLAN, acceptance_index_identity, envelope, resolve, sha
from run_graphics import GODOT, sources


PREVIEW_FREEZES = {"before": "be6423c7ecc12db4b3f8b1c3405902b73e976d82", "after": "d27f03c8354f855da694965d41448ce811f09ff9"}
PREVIEW_STAGES = {"preview-opening", "preview-boss"}


def execute(command, run, env, label, timeout, strict=False):
    with (run / (label + ".log")).open("w", encoding="utf-8") as log:
        try:
            code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            code = 124
    output = (run / (label + ".log")).read_text(encoding="utf-8", errors="replace")
    markers = ["ERROR:", "SCRIPT ERROR:", "Parse Error:"] + (["WARNING:", "ObjectDB instances leaked", "Object was deleted while awaiting a callback", "CrashHandlerException"] if strict else [])
    errors = [line for line in output.splitlines() if any(x in line for x in markers)]
    return {"command": command, "exit_code": code, "errors": errors, "passed": code == 0 and not errors}, output


def runtime_freeze(plan):
    rows = {}
    for path in sorted(PROJECT.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(PROJECT)
        if rel.parts[0] not in {"scripts", "art"} and rel.as_posix() not in {"project.godot", "main.tscn", "legacy.tscn", "icon.svg", "icon.svg.import", "export_presets.cfg"}:
            continue
        raw = path.read_bytes()
        old = subprocess.check_output(["git", "-C", str(PROJECT), "show", plan["runtime_freeze"] + ":android-games/hearthguard/" + rel.as_posix()])
        assert raw == old or (path.suffix != ".glb" and raw.replace(b"\r\n", b"\n") == old.replace(b"\r\n", b"\n")), "Frozen runtime/art drift: " + str(rel)
        rows[rel.as_posix()] = sha(path)
    return {"commit": plan["runtime_freeze"], "files": rows, "all_match": True, "policy": "GLB exact, text LF normalization only"}


def preview_runtime_freeze(ref):
    result = runtime_freeze({"runtime_freeze": ref})
    prefix = "android-games/hearthguard/"
    tracked = subprocess.check_output(["git", "-C", str(PROJECT), "ls-tree", "--full-tree", "-r", "--name-only", ref, "--", prefix], text=True).splitlines()
    expected = {name[len(prefix):] for name in tracked if name.startswith(prefix) and (name[len(prefix):].split("/")[0] in {"scripts", "art"} or name[len(prefix):] in {"project.godot", "main.tscn", "legacy.tscn", "icon.svg", "icon.svg.import", "export_presets.cfg"})}
    assert expected == set(result["files"]), "Complete preview runtime path set differs: " + str(sorted(expected ^ set(result["files"])))
    result["complete_tracked_path_set"] = True
    return result


def prepare_start(args, run, env, plan):
    user = Path(env["APPDATA"]) / "Godot/app_userdata/Hearthguard"
    user.mkdir(parents=True)
    expected = None
    if args.resume_from:
        parent = args.resume_from.resolve()
        assert parent.is_relative_to((PROJECT / ".artifacts").resolve())
        receipt = json.loads((parent / "receipt.json").read_text())
        report = json.loads((parent / "production-report.json").read_text())
        assert receipt["passed"] and receipt["source_unchanged"] and not report["failures"]
        assert any(row["path"] == "production-report.json" and row["sha256"] == sha(parent / "production-report.json") for row in receipt["artifacts"])
        candidates = []
        for name, row in report["raw_slot_snapshots"]["final"]["files"].items():
            assert re.fullmatch(r"hearth-save-[01](?:\.tmp)?", name)
            source = (parent / row["path"]).resolve()
            assert source.is_relative_to(parent) and sha(source) == row["sha256"]
            assert any(item["path"] == row["path"] and item["sha256"] == row["sha256"] for item in receipt["artifacts"])
            shutil.copy2(source, user / name)
            assert sha(source) == sha(user / name)
            code = source.read_bytes().decode("utf-8")
            packet = envelope(code)
            if not name.endswith(".tmp") or packet["committed"]:
                candidates.append((packet["revision"], name, code))
        assert candidates
        _, _, code = max(candidates, key=lambda item: item[0])
        expected = run / "expected-start.code"
        expected.write_bytes(code.encode("utf-8"))
        provenance = {"kind": "exact raw app slots from prior passed production process", "parent": str(parent), "receipt_sha256": sha(parent / "receipt.json"), "report_sha256": sha(parent / "production-report.json"), "files": report["raw_slot_snapshots"]["final"]["files"]}
    else:
        key = args.earned or plan["stages"].get(args.stage, {}).get("earned")
        if key:
            code, packet, entry = resolve(key, args.earned_root)
            expected = run / "expected-start.code"
            expected.write_bytes(code.encode("utf-8"))
            (user / "hearth-save-0").write_bytes(expected.read_bytes())
            assert sha(user / "hearth-save-0") == entry["selected_envelope_sha256"]
            provenance = {"kind": "accepted genuine app-written historical envelope", "key": key, "entry": entry, "plan_sha256": sha(PLAN)}
        else:
            provenance = {"kind": "fresh isolated app, no progress or settings injection"}
    if expected:
        (run / "expected-start.json").write_text(json.dumps(envelope(expected.read_bytes().decode("utf-8")), indent=2) + "\n")
    provenance["acceptance_index_identity"] = acceptance_index_identity(plan)
    (run / "start-provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    return expected, provenance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["checks", "opening", "heavy", "later", "timing", "retry", "lifecycle", "restore", "legacy", "tour", "ram-gap", "gap", "preview-opening", "preview-boss"])
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--native-frames", action="store_true")
    parser.add_argument("--movie", action="store_true")
    parser.add_argument("--seconds", type=float)
    parser.add_argument("--lead-in", type=float)
    parser.add_argument("--earned")
    parser.add_argument("--resume-from", type=Path)
    parser.add_argument("--gap-role")
    parser.add_argument("--cached", action="store_true", help="Preview only: use existing imported cache; no editor/import")
    parser.add_argument("--cpu", action="store_true", help="Preview only: same30fps input driver headlessly, no media")
    parser.add_argument("--preview-variant", choices=sorted(PREVIEW_FREEZES))
    parser.add_argument("--earned-root", type=Path, help="Preview boss only: exact retained historical game root")
    args = parser.parse_args()
    preview = args.stage in PREVIEW_STAGES
    if preview:
        if not args.cached or not args.preview_variant:
            parser.error("Preview requires --cached and explicit --preview-variant before|after")
        if args.resume_from or args.earned or args.lead_in is not None or args.seconds is not None or args.gap_role:
            parser.error("Preview has its own bounded actual-input lead-in and timeline")
        if args.cpu == args.render or args.cpu and args.native_frames or args.render and not args.native_frames:
            parser.error("Choose preview --cpu or --render --native-frames")
        if args.stage == "preview-boss" and not args.earned_root:
            parser.error("Preview boss requires authenticated --earned-root")
        if args.stage == "preview-opening" and args.earned_root:
            parser.error("Preview opening must start fresh")
    elif args.cached or args.cpu or args.preview_variant or args.earned_root:
        parser.error("Preview-only options cannot change historical production recipes")
    if args.movie:
        parser.error("Internal450x800 movie writer is rejected; use --native-frames")
    if args.stage == "checks":
        if args.render or args.native_frames or args.resume_from or args.earned:
            parser.error("Harness checks are CPU-only and inspect pinned fixtures")
    elif not args.render and not (preview and args.cpu):
        parser.error("Production rendering requires --render and root's explicit GPU grant")
    elif args.stage == "timing":
        if args.native_frames:
            parser.error("Timing excludes fixed cadence, PNGs and all framebuffer readback")
    elif not args.native_frames and not (preview and args.cpu):
        parser.error("Review passages require native frame recording")
    if args.earned and args.resume_from:
        parser.error("Choose pinned earned source or prior raw slots")
    if args.stage == "opening" and (args.earned or args.resume_from):
        parser.error("Opening must begin fresh")
    if args.stage == "restore" and not args.resume_from:
        parser.error("Cold restore requires a prior passed process's raw final slots")
    if args.stage == "gap" and (not args.earned or not args.gap_role):
        parser.error("A bounded gap clip requires the concrete missing role and a pinned earned source")
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    stage = plan["stages"].get(args.stage, {})
    duration = args.seconds if args.seconds is not None else stage.get("seconds", 8)
    lead = args.lead_in if args.lead_in is not None else stage.get("lead_in_seconds", 0)
    assert 0 < duration <= 120 and 0 <= lead <= 90
    if args.gap_role:
        assert args.stage == "gap"
        _, packet, _ = resolve(args.earned)
        state = packet["state"]
        roles = {state["definition"]["roster"][int(enemy["id"])] ["role"] for enemy in state["enemies"]}
        roles |= {enemy["role"] for enemy in state["definition"]["roster"][int(state["spawned"]):] if enemy["t"] <= state["time"] + lead + duration}
        assert args.gap_role in roles, "Pinned source has no declared missing role in the requested encounter window"
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run = PROJECT / ".artifacts" / ("production-" + args.stage + "-" + stamp)
    run.mkdir(parents=True)
    env = os.environ.copy()
    for name in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
        directory = run / name.lower()
        directory.mkdir()
        env[name] = str(directory)
    frozen_runtime = preview_runtime_freeze(PREVIEW_FREEZES[args.preview_variant]) if preview else runtime_freeze(plan)
    (run / "frozen-runtime.json").write_text(json.dumps(frozen_runtime, indent=2) + "\n")
    if args.stage == "checks":
        fixtures = run / "fixtures"
        fixtures.mkdir()
        inventory = {}
        for key in plan["earned_sources"]:
            code, packet, entry = resolve(key, args.earned_root)
            (fixtures / (key + ".code")).write_bytes(code.encode("utf-8"))
            inventory[key] = entry
        (run / "fixture-provenance.json").write_text(json.dumps(inventory, indent=2) + "\n")
        expected, provenance = None, {"kind": "pinned historical validation fixtures only", "acceptance_index_identity": acceptance_index_identity(plan)}
    else:
        if args.stage == "preview-boss": args.earned = "ram-approach"
        expected, provenance = prepare_start(args, run, env, plan)
    if args.cached:
        cache = PROJECT / ".godot/imported"
        assert cache.is_dir() and any(cache.iterdir()), "Explicit cached preview requires existing imported resources"
        preflight = {"passed": True, "skipped": True, "reason": "Explicit preview --cached; no editor/import", "cache_files": {str(p.relative_to(PROJECT)): sha(p) for p in sorted(cache.iterdir()) if p.is_file()}}
    else:
        preflight, _ = execute([str(GODOT), "--headless", "--editor", "--import", "--quit", "--path", str(PROJECT)], run, env, "import", 180)
    parsed, _ = execute([str(GODOT), "--headless", "--path", str(PROJECT), "--check-only", "--script", "res://tests/production_passage.gd"] + (["--audio-driver", "Dummy", "--verbose"] if preview else []), run, env, "parse", 60, strict=preview)
    before = sources()
    (run / "source-hashes.json").write_text(json.dumps(before, indent=2) + "\n")
    for name in before:
        if preview: continue  # Exact Git runtime freeze and source maps bind preview without duplicate source snapshots.
        target = run / "executed-source" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / name, target)
        assert sha(target) == before[name]
    command = [str(GODOT), "--path", str(PROJECT)] + (["--audio-driver", "Dummy", "--verbose"] if preview else [])
    command += ["--headless"] if args.stage == "checks" or args.cpu else ["--resolution", "720x1280", "--position", "0,0"]
    if args.native_frames or args.cpu:
        command += ["--fixed-fps", "30"]
    elif args.stage == "timing":
        command += ["--disable-vsync", "--max-fps", "0"]
    script = "production_checks.gd" if args.stage == "checks" else "production_passage.gd"
    command += ["--script", "res://tests/" + script, "--", "--capture-dir=" + str(run), "--stage=" + args.stage, "--seconds=" + str(duration), "--lead-in=" + str(lead)]
    if preview:
        command += ["--preview-variant=" + args.preview_variant]
    if expected:
        command += ["--expected-code=" + str(expected)]
    if args.native_frames:
        command += ["--native-frames"]
    if args.stage == "checks":
        command += ["--fixtures-dir=" + str(fixtures)]
    if preflight["passed"] and parsed["passed"]:
        result, output = execute(command, run, env, "execution", max(180, int((duration + lead) * 5 + 120)), strict=preview)
    else:
        result, output = {"passed": False, "exit_code": 126, "errors": ["Not executed after CPU import/parse failure"]}, ""
    passed = preflight["passed"] and parsed["passed"] and result["passed"] and "SUITE_COMPLETE: PASS" in output and before == sources()
    report_path = run / ("production-checks.json" if args.stage == "checks" else "production-report.json")
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    passed &= bool(report) and report.get("failures", 1) == 0
    media = {}
    # A failed/timed-out passage may leave PNGs without its final inventory.
    # Keep a failed receipt instead of crashing while trying to encode it.
    if args.native_frames and report and (run / "native-frame-inventory.json").exists() and (run / "frames/000000.png").exists():
        movie = run / "continuous.mp4"
        encoding, _ = execute(["ffmpeg", "-v", "error", "-framerate", "30", "-i", str(run / "frames/%06d.png"), "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(movie)], run, env, "encode", 240)
        decoding, _ = execute(["ffmpeg", "-v", "error", "-i", str(movie), "-f", "null", "-"], run, env, "decode", 180) if encoding["passed"] else ({"passed": False}, "")
        probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie)])) if encoding["passed"] else {}
        inventory = json.loads((run / "native-frame-inventory.json").read_text())
        stream = next((row for row in probe.get("streams", []) if row["codec_type"] == "video"), {})
        pixels_match = [stream.get("width"), stream.get("height")] == inventory["canvas"] and int(stream.get("nb_frames", -1)) == len(inventory["frames"]) == report.get("native_frame_count") == len(report.get("coverage", {}).get("frames", [])) and bool(inventory["frames"])
        if args.stage != "lifecycle":
            pixels_match &= all(row["native"] == [720, 1280] for row in inventory["frames"])
        passed &= encoding["passed"] and decoding["passed"] and pixels_match
        media = {"sha256": sha(movie) if movie.exists() else None, "probe": probe, "encoding": encoding, "fully_decoded": decoding, "pixel_and_frame_count_match": pixels_match, "policy": "Native1:1 pixels, declared padding only; no scaling/retiming; fixed30 silent movie is not FPS"}
    elif args.native_frames:
        passed = False
    if args.stage == "timing":
        timing_path = run / "frame-timing.json"
        timing = json.loads(timing_path.read_text()) if timing_path.exists() else {}
        passed &= bool(timing) and timing.get("all_frames", {}).get("frames", 0) > 0 and timing.get("heavy_frames", {}).get("frames", 0) > 0
    receipt = {"stage": args.stage, "passed": bool(passed), "source_unchanged": before == sources(), "import": preflight, "parse": parsed,
               "result": result, "start_provenance": provenance, "runtime_freeze": frozen_runtime["commit"], "cached": args.cached, "cpu_only": args.cpu, "preview_variant": args.preview_variant, "media": media, "declared_missing_role": args.gap_role,
               "limits": "Prepared harness is not visual acceptance. Current run distinguishes actual native movies from uncapped host timing. No Android/phone/FPS/fun inference.", "artifacts": []}
    for path in sorted(run.rglob("*")):
        if path.is_file():
            receipt["artifacts"].append({"path": path.relative_to(run).as_posix(), "bytes": path.stat().st_size, "sha256": sha(path)})
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("\n".join(output.splitlines()[-14:]))
    if not preflight["passed"] or not parsed["passed"]:
        print(preflight, parsed)
    print(run)
    print("PRODUCTION_RESULT", "PASS" if passed else "FAIL")
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
