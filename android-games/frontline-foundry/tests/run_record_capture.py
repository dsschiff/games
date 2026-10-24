"""Matched production recap/Journey capture; CPU by default, renderer reserved to coordinator."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
GODOT = Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")
OLD = "64cd050331613604fb3489468dd758264e1bfe15"
CURRENT = "c1ab02109f23d2deded54591b940a91b5fe7e4bc"
SWAP = ["scripts/campaign_main.gd", "scripts/reinforcement_feedback.gd"]
EARNED = PROJECT / ".artifacts/frontline-frozen-input-20261023T231246939291Z"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git_bytes(ref, name):
    return subprocess.check_output(["git", "show", ref + ":android-games/frontline-foundry/" + name], cwd=REPO)


def sources():
    return {p.relative_to(PROJECT).as_posix(): digest(p.read_bytes())
            for p in sorted(PROJECT.rglob("*")) if p.is_file()
            and not any(part.startswith(".") or part == "__pycache__" for part in p.relative_to(PROJECT).parts)}


def pin(path):
    return {"sha256": digest(path.read_bytes()), "size": path.stat().st_size}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", choices=["old", "current", "both"], default="both")
    parser.add_argument("--render", action="store_true", help="Coordinator's reserved renderer only; default is CPU/headless")
    parser.add_argument("--width", type=int, default=720)
    parser.add_argument("--height", type=int, default=1680)
    args = parser.parse_args()
    run = PROJECT / ".artifacts" / ("record-matched-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    run.mkdir()
    initial = sources()
    originals = {name: (PROJECT / name).read_bytes() for name in SWAP}
    def normalized(name, data):
        return data.replace(b"\r\n", b"\n") if Path(name).suffix in {".gd", ".uid", ".godot", ".tscn", ".tres", ".cfg", ".import", ".svg", ".gdshader", ".py"} else data
    # Only these two production sources differ between the requested runtime refs.
    def eligible(name):
        return not name.startswith("tests/") and not any(part.startswith(".") for part in Path(name).parts) and Path(name).suffix not in {".md", ".json"}
    def git_runtime(ref):
        names = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", ref, "android-games/frontline-foundry"], cwd=REPO, text=True).splitlines()
        return {name.removeprefix("android-games/frontline-foundry/") for name in names if eligible(name.removeprefix("android-games/frontline-foundry/"))}
    old_paths, current_paths = git_runtime(OLD), git_runtime(CURRENT)
    working_paths = {f.relative_to(PROJECT).as_posix() for f in PROJECT.rglob("*") if f.is_file() and eligible(f.relative_to(PROJECT).as_posix())}
    assert old_paths == current_paths == working_paths, "Complete production path sets differ"
    runtime = sorted(current_paths)
    bindings = {}
    for name in runtime:
        current = git_bytes(CURRENT, name)
        old = git_bytes(OLD, name)
        actual = (PROJECT / name).read_bytes()
        assert normalized(name, actual) == normalized(name, current), "Current runtime drift: " + name
        assert name in SWAP or normalized(name, old) == normalized(name, current), "Unexpected old/current runtime delta: " + name
        bindings[name] = {"old_git_raw": digest(old), "current_git_raw": digest(current), "working_raw": digest(actual), "current_lf": digest(normalized(name, actual))}
    cache = PROJECT / ".godot/imported"
    assert cache.is_dir() and any(cache.iterdir()), "Source-matching imported cache missing; do not import or substitute"
    cache_pins = {f.relative_to(PROJECT).as_posix(): pin(f) for f in sorted(cache.rglob("*")) if f.is_file()}
    accepted_blob = git_bytes(CURRENT, "RECORD_FEEDBACK_CHECKPOINT.json")
    assert digest(accepted_blob) == "4225f24adc75155bfb39880f865e33276c28aa4eef86ff679203763153d10944", "Accepted provenance checkpoint differs"
    accepted = json.loads(accepted_blob)
    provenance = {}
    for name in ["s13-m11-B-terminal-slots.json", "s16-m07-A-terminal-slots.json", "receipt.json", "input-report.json"]:
        observed = pin(EARNED / name)
        trusted = accepted["original_genuine_input_provenance"][".artifacts/frontline-frozen-input-20261023T231246939291Z/" + name]
        assert observed == trusted, "Accepted earned fixture provenance differs: " + name
        provenance[name] = observed
    cache_receipt_path = ".artifacts/record-cache-20261024T122518758718Z/receipt.json"
    assert pin(PROJECT / cache_receipt_path) == accepted["artifacts"][cache_receipt_path], "Accepted cache receipt differs"
    trusted_cache = json.loads((PROJECT / cache_receipt_path).read_text(encoding="utf-8"))
    assert all(digest(normalized(name, (PROJECT / name).read_bytes())) == value for name, value in trusted_cache["assets_unchanged_lf"].items()), "Imported asset inputs differ"
    assert {f.name: digest(f.read_bytes()) for f in cache.rglob("*") if f.is_file()} == trusted_cache["existing_imported_cache_hashes"], "Imported cache bytes differ"
    preflight = {"old": OLD, "current": CURRENT, "swap": SWAP, "runtime_bindings": bindings, "complete_runtime_paths": runtime, "accepted_provenance_checkpoint_sha256": digest(accepted_blob), "cache": cache_pins, "earned": provenance, "harness": {name: pin(PROJECT / "tests" / name) for name in ["record_capture.gd", "record_capture.gd.uid", "run_record_capture.py"]}, "scope": "Exact Git source substitution in memory-backed try/finally; no project copy, import, altered rules or typed fixtures. Cache inputs identical across refs; existing imported cache hashes bound."}
    (run / "preflight.json").write_text(json.dumps(preflight, indent=2) + "\n", encoding="utf-8")
    variants = ["old", "current"] if args.variant == "both" else [args.variant]
    results = {}
    restored = False
    try:
        for variant in variants:
            for name in SWAP:
                (PROJECT / name).write_bytes(git_bytes(OLD, name) if variant == "old" else originals[name])
            before = sources()
            case = run / variant
            case.mkdir()
            env = os.environ.copy()
            for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
                directory = case / key.lower()
                directory.mkdir()
                env[key] = str(directory)
            command = [str(GODOT), "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", str(PROJECT)]
            command += ["--resolution", f"{args.width}x{args.height}", "--position", "0,0"] if args.render else ["--headless"]
            command += ["--script", "res://tests/record_capture.gd", "--", "--capture-dir=" + str(case), "--earned-dir=" + str(EARNED), "--width=" + str(args.width), "--height=" + str(args.height)]
            if args.render:
                command += ["--capture-images"]
            (case / "source-before.json").write_text(json.dumps(before, indent=2) + "\n", encoding="utf-8")
            with (case / "godot.log").open("w", encoding="utf-8") as log:
                try:
                    code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240).returncode
                except subprocess.TimeoutExpired:
                    code = 124
            after = sources()
            (case / "source-after.json").write_text(json.dumps(after, indent=2) + "\n", encoding="utf-8")
            output = (case / "godot.log").read_text(encoding="utf-8", errors="replace")
            errors = [line for line in output.splitlines() if any(token in line for token in ["ERROR:", "WARNING:", "ObjectDB"])]
            results[variant] = {"command": command, "exit_code": code, "source_unchanged": before == after, "errors": errors, "passed": code == 0 and before == after and not errors and "SUITE_COMPLETE: PASS" in output}
            (case / "receipt.json").write_text(json.dumps(results[variant], indent=2) + "\n", encoding="utf-8")
            if not results[variant]["passed"]:
                break
    finally:
        for name, data in originals.items():
            (PROJECT / name).write_bytes(data)
        restored = sources() == initial
        (run / "restoration.json").write_text(json.dumps({"restored_exact_initial_sources": restored, "sources": sources()}, indent=2) + "\n", encoding="utf-8")
    parity = None
    if all((run / name / "capture-report.json").exists() for name in ["old", "current"]):
        old, current = [json.loads((run / name / "capture-report.json").read_text(encoding="utf-8")) for name in ["old", "current"]]
        # Presentation/timing fields are intentionally not state. Compare every full raw/live snapshot.
        def contexts(report):
            return [{k: v for k, v in snapshot.items() if k in {"clip", "label", "whole", "raw_slots", "owning_read", "boundary"}} for snapshot in report["snapshots"]]
        parity = {"all_complete_snapshots_and_raw_path_sets_exact": contexts(old) == contexts(current), "gesture_semantics_equal": [{k: v for k, v in e.items() if k != "timing"} for e in old["events"]] == [{k: v for k, v in e.items() if k != "timing"} for e in current["events"]], "relative_event_physics_equal": [e["timing"]["physics"] for e in old["events"]] == [e["timing"]["physics"] for e in current["events"]], "relative_snapshot_physics_equal": [e.get("timing", {}).get("physics") for e in old["snapshots"]] == [e.get("timing", {}).get("physics") for e in current["snapshots"]], "clip_ticks_old": [c["ticks"] for c in old["clips"]], "clip_ticks_current": [c["ticks"] for c in current["clips"]]}
    passed = restored and len(results) == len(variants) and all(r["passed"] for r in results.values()) and (parity is None or (parity["all_complete_snapshots_and_raw_path_sets_exact"] and parity["gesture_semantics_equal"] and parity["relative_event_physics_equal"] and parity["relative_snapshot_physics_equal"] and parity["clip_ticks_old"] == parity["clip_ticks_current"]))
    receipt = {"passed": passed, "mode": "rendered" if args.render else "CPU/Dummy only", "variants": results, "restored": restored, "parity": parity, "artifacts": {f.relative_to(run).as_posix(): pin(f) for f in sorted(run.rglob("*")) if f.is_file()}}
    (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(run)
    print(json.dumps({"passed": passed, "results": results, "parity": parity, "restored": restored}, indent=2))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
