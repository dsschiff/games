"""Isolated graphics runner: import, kit verification, rendered inspection frames.

Every run gets its own APPDATA/LOCALAPPDATA/TEMP under ignored .artifacts and
records the command, log and LF source hashes. Rendered modes open a real
720x1280 window; nothing here uses Android, ADB, the clipboard or signing.
"""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import subprocess
from datetime import datetime, timezone

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")
SCRIPTS = {"multiplier": "res://tests/multiplier_feedback.gd", "transition": "res://tests/terminal_transition.gd", "lifetime": "res://tests/texture_lifetime.gd", "rules": "res://tests/run_tests.gd", "campaign-rules": "res://tests/campaign_tests.gd",
           "platform": "res://tests/platform_input.gd", "code4": "res://tests/code4_upgrade.gd", "design": "res://tests/terminal_design.gd", "lineup": "res://tests/art_lineup.gd", "frames": "res://tests/graphics_frames.gd",
           "presentation": "res://tests/presentation_tests.gd", "timing": "res://tests/horde_timing.gd"}


def raw_hashes():
    return {str(p.relative_to(PROJECT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(PROJECT.rglob("*")) if p.is_file()
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


def lf_hashes():
    return {str(p.relative_to(PROJECT)).replace("\\", "/"): hashlib.sha256(p.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
            for p in sorted(PROJECT.rglob("*")) if p.is_file()
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


ROUTE_REFERENCE = {
    "multiplier-feedback.json": "25df229002ac863f1602e90c630e193f5c3fc36c7148b1da6f347e6485fa98ff",
    "raw-input-events.json": "20fa393df69041c216e9691987e53f7b65d8a0eed67a5ad699638bfec2cca9af",
    "receipt.json": "4edc40db48aae8588456a38a850b28dd15539868bbf0256a6553802e1b07b260",
    "source-hashes-lf.json": "d46a2c1c59daa3af071636dfd9e5a943e09794fce0fb896a56ee8dc073ab6c1f",
    "godot.log": "6740bdda25f549495b39882897b9d081e9f217e987a06130e8ae092f3e2293a6",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def runtime_path(name):
    return name.startswith(("scripts/", "art/")) or name.endswith(".tscn") or name in (
        "project.godot", "export_presets.cfg", "icon.svg")


def cache_hashes():
    return {p.relative_to(PROJECT).as_posix(): sha(p) for p in sorted((PROJECT / ".godot").rglob("*")) if p.is_file()}


BASE_ADAPTER_LF = "94c14e440a355b737148f1d86c1b95c110fc8e7a8587ee23b340ddc74b73d18d"
BASE_REPORT_SHA = "7c47967cbff5a286894547b42dcea80d9b28508d1077c0221db35aa658b8d0be"


@contextmanager
def source_variant(name):
    path = PROJECT / "scripts/presentation/adapter.gd"
    candidate = path.read_bytes()
    record = {"name": name, "candidate_raw_sha256": hashlib.sha256(candidate).hexdigest()}
    try:
        if name == "baseline":
            original = subprocess.check_output(["git", "-C", str(PROJECT), "show", "64cd050:android-games/dead-run/scripts/presentation/adapter.gd"])
            if hashlib.sha256(original.replace(b"\r\n", b"\n")).hexdigest() != BASE_ADAPTER_LF:
                raise ValueError("Trusted baseline adapter blob mismatch")
            path.write_bytes(original)
        record["executed_raw_sha256"] = sha(path)
        yield record
    finally:
        if name == "baseline": path.write_bytes(candidate)
        record["restored_raw_sha256"] = sha(path)
        record["restored"] = path.read_bytes() == candidate


def authenticate_route(folder, variant):
    pins = {name: sha(folder / name) for name in ROUTE_REFERENCE}
    if pins != ROUTE_REFERENCE:
        raise ValueError("Canonical prior route artifact hash mismatch")
    receipt = json.loads((folder / "receipt.json").read_text(encoding="utf-8"))
    if not receipt["passed"] or receipt["source_before_raw"] != receipt["source_after_raw"]:
        raise ValueError("Canonical prior route was not a clean stable-source pass")
    expected = {k: v for k, v in receipt["source_before_raw"].items() if runtime_path(k)}
    actual = {k: v for k, v in raw_hashes().items() if runtime_path(k)}
    if set(expected) != set(actual):
        raise ValueError("Complete runtime path-set differs: " + repr(sorted(set(expected) ^ set(actual))))
    frozen_lf = json.loads((folder / "source-hashes-lf.json").read_text(encoding="utf-8"))
    current_lf = lf_hashes()
    for name in expected:
        binary = Path(name).suffix in (".glb", ".png", ".jpg", ".ttf", ".woff", ".ico")
        if (expected[name] != actual[name]) if binary else (frozen_lf[name] != current_lf[name]):
            raise ValueError("Production runtime changed: " + name)
    baseline = None
    if variant == "baseline":
        path = folder.parent / "multiplier-canonical-baseline-multiplier-20261024T124702Z/multiplier-feedback.json"
        if sha(path) != BASE_REPORT_SHA: raise ValueError("Authenticated original presentation report mismatch")
        git_command = ["git", "-C", str(PROJECT), "show", "64cd050:android-games/dead-run/scripts/presentation/adapter.gd"]
        blob = subprocess.check_output(git_command)
        if hashlib.sha256(blob.replace(b"\r\n", b"\n")).hexdigest() != BASE_ADAPTER_LF:
            raise ValueError("Trusted baseline source mismatch before any write")
        baseline = {"path": str(path.resolve()), "sha256": BASE_REPORT_SHA, "adapter_lf": BASE_ADAPTER_LF, "git_command": git_command}
    return {"folder": str(folder.resolve()), "sha256": pins, "runtime_raw": actual,
            "runtime_lf": {k: current_lf[k] for k in expected}, "baseline": baseline}


def route_identity(run, reference, native, variant):
    expected = json.loads((Path(reference["folder"]) / "multiplier-feedback.json").read_text(encoding="utf-8"))
    actual = json.loads((run / "multiplier-feedback.json").read_text(encoding="utf-8"))
    equal = {k: expected[k] == actual[k] for k in (
        "context", "saved", "raw_slots", "tick_contexts", "crossings", "observations", "mismatches")}
    equal["raw_input_bytes"] = (run / "raw-input-events.json").read_bytes() == (Path(reference["folder"]) / "raw-input-events.json").read_bytes()
    if variant == "baseline":
        original = json.loads(Path(reference["baseline"]["path"]).read_text(encoding="utf-8"))
        equal["observations"] = actual["observations"] == original["observations"]
    capture = actual["route_capture"]
    frames = capture["frames"]
    equal["complete_tick_route"] = len(actual["tick_contexts"]) == 2734
    equal["capture_ticks"] = [f["tick"] for f in frames] == list(range(2, 2737, 2))
    equal["capture_clock"] = all(b["physics"] - a["physics"] == 2 and b["process"] - a["process"] == 2 for a, b in zip(frames, frames[1:]))
    tick_hashes = {row["tick"]: row["sha256"] for row in expected["tick_contexts"]}
    equal["captured_whole_contexts"] = all(f["context_sha256"] == tick_hashes[f["tick"]] for f in frames if f["tick"] in tick_hashes)
    events = json.loads((run / "raw-input-events.json").read_text(encoding="utf-8"))
    observed = capture["timed_inputs"]
    equal["input_observer"] = len(events) == len(observed) == 28
    for event, seen in zip(events, observed):
        kind = "drag" if event["kind"] == "world_drag" else "touch"
        equal["input_observer"] &= (seen["kind"] == kind and seen["index"] == event["index"] and seen["position"] == event["position"] and
            seen["physics_frame"] == event["frame"] - capture["clock_origin_physics"] and
            (kind == "drag" or seen["pressed"] == event.get("pressed", event["kind"] == "world_press")))
    equal["five_marks"] = [m["label"] for m in capture["marks"]] == [o["label"] for o in expected["observations"]]
    equal["mark_requests"] = all(m["requested_tick"] == o["tick"] for m, o in zip(capture["marks"], expected["observations"]))
    equal["mode"] = actual["route_only"] and capture["rendered"] == native and capture["simulation_hz"] == 60 and capture["video_fps"] == 30 and capture["time_scale"] == 1.0 and capture["duplicate_live_draws"] == 0
    files = {}
    if native:
        names = [f["file"] for f in frames] + [m["file"] for m in capture["marks"]]
        equal["png_inventory"] = set(names) == {p.relative_to(run).as_posix() for p in run.rglob("*.png")}
        equal["native_dimensions"] = True
        for name in names:
            path = run / name
            data = path.read_bytes()
            equal["native_dimensions"] &= data[:8] == b"\x89PNG\r\n\x1a\n" and (int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")) == (720, 1280)
            files[name] = {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
    else:
        equal["no_headless_pixels"] = not any(run.rglob("*.png"))
    presentation_differences = [{"label": a["label"], "field": field, "current": e[field], "actual": a[field]}
        for e, a in zip(expected["observations"], actual["observations"])
        for field in ("number", "caption", "caption_font") if e[field] != a[field]]
    return {"passed": all(equal.values()), "checks": equal, "presentation_differences": presentation_differences, "frames": len(frames), "duration_seconds": len(frames) / 30,
            "first_tick": frames[0]["tick"], "last_tick": frames[-1]["tick"], "pngs": files,
            "limits": "Post-draw mapping requires rendered review. CPU process-frame plan proves no pixels or visual salience; final paused still is outside the live movie."}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["import", *SCRIPTS])
    parser.add_argument("--label", default="run")
    parser.add_argument("--scenario", default="all")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--source-variant", choices=("current", "baseline"), default="current", help="route only: trusted old adapter swap with exact finally restoration")
    parser.add_argument("--route-only", action="store_true", help="multiplier only: preserve exact earned route, omit all typed fixtures")
    parser.add_argument("--native-frames", action="store_true", help="route only: post-draw native720x1280 PNG every two simulation ticks")
    parser.add_argument("--route-reference", type=Path, help="route only: existing authenticated canonical final packet; no copied source/assets")
    parser.add_argument("--input-dir", type=Path, help="transition only: prior genuine app-written defeat slots")
    drain = parser.add_mutually_exclusive_group()
    drain.add_argument("--drain-between-rebuilds", action="store_true", help="lifetime fixture comparison only: await normal process/render frames after each geometry world")
    drain.add_argument("--drain-after-fixtures", action="store_true", help="lifetime end-only control: same added drain count after all geometry worlds")
    parser.add_argument("--movie", action="store_true", help="also write a fixed-60fps AVI via Godot's movie writer")
    args = parser.parse_args()
    if (args.route_only or args.native_frames or args.route_reference is not None) and args.mode != "multiplier":
        parser.error("Route options apply only to multiplier")
    if args.native_frames and (not args.route_only or args.headless):
        parser.error("Native frames require route-only rendered mode")
    if args.route_only and (args.movie or not (args.headless or args.native_frames)):
        parser.error("Route-only requires headless CPU or native PNG capture; no AVI writer")
    if args.source_variant != "current" and not args.route_only:
        parser.error("Baseline source variant requires route-only")
    if args.route_reference is not None and not args.route_only:
        parser.error("Route reference requires route-only")
    if (args.drain_between_rebuilds or args.drain_after_fixtures) and args.mode != "lifetime":
        parser.error("Fixture drain comparisons apply only to lifetime mode")
    if (args.mode == "transition") != (args.input_dir is not None):
        parser.error("transition requires --input-dir; other modes do not accept it")
    if args.mode == "transition" and len(list(args.input_dir.glob("dead-run-save-*"))) != 2:
        parser.error("transition needs exactly two app-written slots")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run = PROJECT / ".artifacts" / "graphics" / f"{args.label}-{args.mode}-{stamp}"
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        env[key] = str(run / key.lower())
        Path(env[key]).mkdir()
    inputs = []
    if args.mode in ("code4", "transition"):
        destination = Path(env["APPDATA"]) / "Godot/app_userdata/Dead Run"
        destination.mkdir(parents=True)
        source = args.input_dir if args.mode == "transition" else PROJECT / "tests/fixtures/code4-midroad"
        for original in sorted(source.glob("dead-run-save-*")):
            (destination / original.name).write_bytes(original.read_bytes())
            inputs.append({"kind": "genuine-prior-app-written-defeat-slot" if args.mode == "transition" else "genuine-code4-app-written-slot", "source": str(original),
                           "sha256": hashlib.sha256(original.read_bytes()).hexdigest()})
    # Sound stays off in every automated run (Daniel works at this computer).
    command = [str(GODOT), "--path", str(PROJECT), "--audio-driver", "Dummy"]
    if args.mode == "import":
        command += ["--headless", "--editor", "--import"]
    else:
        command += ["--headless"] if args.headless else ["--resolution", "720x1280", "--position", "0,0"]
        # timing: unpaced render frames (opt-in host capture, DEVELOPMENT.md).
        command += ([] if args.mode == "timing" else ["--fixed-fps", "60"]) + ["--script", SCRIPTS[args.mode]]
        if args.movie:
            command += ["--write-movie", str(run / "clip.avi")]
        command += ["--",
                    "--capture-dir=" + str(run), "--scenario=" + args.scenario, "--report=" + str(run / "rules-report.json")]
        if args.drain_between_rebuilds: command.append("--drain-between-rebuilds")
        if args.drain_after_fixtures: command.append("--drain-after-fixtures")
    reference = None
    preflight_error = None
    if args.route_only:
        try:
            reference = authenticate_route(args.route_reference or PROJECT / ".artifacts/graphics/multiplier-canonical-final-multiplier-20261024T124753Z", args.source_variant)
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
            preflight_error = str(exc)
    if preflight_error:
        (run / "receipt.json").write_text(json.dumps({"passed": False, "preflight_error": preflight_error}, indent=2))
        raise SystemExit("Route preflight failed: " + preflight_error + " | " + str(run))
    if args.route_only: command.append("--route-only")
    if args.native_frames: command.append("--native-frames")
    if args.route_only: command.append("--source-variant=" + args.source_variant)
    with source_variant(args.source_variant) as variant:
        cache_before = cache_hashes() if args.route_only else {}
        before = lf_hashes()
        raw_before = raw_hashes() if args.mode == "multiplier" else {}
        (run / "source-hashes-lf.json").write_text(json.dumps(before, indent=2))
        with (run / "godot.log").open("w", encoding="utf-8") as log:
            try:
                code = subprocess.call(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1800)
            except subprocess.TimeoutExpired:
                code = 124
                log.write("\nERROR: Godot run timeout\n")
        output = (run / "godot.log").read_text(encoding="utf-8", errors="replace")
        errors = [line for line in output.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:")) or (args.mode == "multiplier" and any(token in line for token in ("WARNING:", "ObjectDB instances leaked")))]
        okay = code == 0 and not errors and (args.mode == "import" or "SUITE_COMPLETE: PASS" in output)
        after = lf_hashes()
        receipt = {"source_before_raw": raw_before, "source_after_raw": raw_hashes() if args.mode == "multiplier" else {}, "command": command, "exit_code": code, "passed": okay, "errors": errors[:40],
                   "source_unchanged": {k: v for k, v in before.items() if not k.startswith("art/models/") or k.endswith(".glb")} ==
                                       {k: v for k, v in after.items() if not k.startswith("art/models/") or k.endswith(".glb")},
                   "inputs": inputs, "pngs": sorted(p.name for p in run.glob("*.png"))}
        okay = okay and receipt["source_unchanged"]
        if args.route_only:
            receipt["raw_source_unchanged"] = receipt["source_before_raw"] == receipt["source_after_raw"]
            okay = okay and receipt["raw_source_unchanged"]
            receipt["route_reference"] = reference
            receipt["cache_before"] = cache_before
            receipt["cache_after"] = cache_hashes()
            receipt["cache_unchanged"] = receipt["cache_before"] == receipt["cache_after"]
            try:
                receipt["route_identity"] = route_identity(run, reference, args.native_frames, args.source_variant)
            except (OSError, ValueError, KeyError, IndexError) as exc:
                receipt["route_identity"] = {"passed": False, "error": str(exc)}
            receipt["route_output_sha256"] = {name: sha(run / name) for name in ("multiplier-feedback.json", "raw-input-events.json") if (run / name).exists()}
            okay = okay and receipt["cache_unchanged"] and receipt["route_identity"]["passed"]
    receipt["source_variant"] = variant
    okay = okay and variant["restored"]
    if args.route_only:
        receipt["current_runtime_after_restore"] = {k: v for k, v in raw_hashes().items() if runtime_path(k)}
        receipt["runtime_restored"] = receipt["current_runtime_after_restore"] == reference["runtime_raw"]
        okay = okay and receipt["runtime_restored"]
        expected_failure = False
        report = None
        if (run / "multiplier-feedback.json").exists():
            report = json.loads((run / "multiplier-feedback.json").read_text(encoding="utf-8"))
        if args.source_variant == "baseline" and report:
            failed = [row["label"] for row in report["details"] if not row["pass"]]
            expected_failure = code == 1 and report["failures"] == 1 and failed == ["partial actual hits are visible before threshold"]
        receipt["expected_before_presentation_failure"] = expected_failure
        receipt["capture_ready"] = (not errors and receipt["source_unchanged"] and receipt["raw_source_unchanged"] and receipt["runtime_restored"] and
            receipt["cache_unchanged"] and receipt["route_identity"]["passed"] and (okay or expected_failure))
    receipt["passed"] = okay
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2))
    print(output[-6000:])
    print(run)
    print("GRAPHICS_RESULT", "PASS" if okay else "FAIL")
    raise SystemExit(0 if okay else 1)


if __name__ == "__main__":
    main()
