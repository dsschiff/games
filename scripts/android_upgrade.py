"""Verify a real different-APK upgrade on an already booted test emulator.

Never operates on physical devices. Initial test-data removal requires the
explicit reset flag; nothing is uninstalled or cleared after the old save exists.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import time

from android_smoke import evaluate_expectations, lookup_path, scale_action
from portfolio import REPO_ROOT, artifact_record, inspect_apk, read_config, tool_environment

NUMERIC_COMPARISON = {"integer_valued_numbers": "exact", "fractional_floats": "math.isclose",
                      "relative_tolerance": 1e-12, "absolute_tolerance": 1e-12,
                      "booleans": "exact type and value", "nonfinite_numbers": "rejected"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_apk_pair(old: dict, new: dict, package: str) -> dict:
    for label, metadata in (("old", old), ("new", new)):
        if metadata.get("package") != package:
            raise ValueError(f"{label} APK package differs from requested package")
        if metadata.get("signature_verified") is not True:
            raise ValueError(f"{label} APK signature was not verified")
        if metadata.get("internet_permission") is not False or "android.permission.INTERNET" in metadata.get("permissions", []):
            raise ValueError(f"{label} APK is not verified offline")
        code = metadata.get("version_code")
        if not isinstance(code, str) or not re.fullmatch(r"[0-9]+", code):
            raise ValueError(f"{label} APK version code is invalid")
    old_code, new_code = int(old["version_code"]), int(new["version_code"])
    if old_code < 1 or new_code <= old_code:
        raise ValueError("New APK must have a strictly larger actual version code")
    return {"from_version_code": old_code, "to_version_code": new_code}


def semantic_subset(old, new) -> bool:
    """Preserve old JSON meaning while permitting migration-added object keys."""
    if isinstance(old, bool) or isinstance(new, bool):
        return type(old) is type(new) and old == new
    if isinstance(old, dict):
        return isinstance(new, dict) and all(key in new and semantic_subset(value, new[key])
                                             for key, value in old.items())
    if isinstance(old, list):
        return isinstance(new, list) and len(old) == len(new) and all(
            semantic_subset(left, right) for left, right in zip(old, new))
    if isinstance(old, (int, float)) and isinstance(new, (int, float)):
        if not math.isfinite(old) or not math.isfinite(new):
            return False
        if old == new:
            return True
        # JSON round trips can move fractional doubles by a few final digits.
        # Keep IDs, counts and integer-valued currency exact, even at large values.
        return (isinstance(old, float) and isinstance(new, float)
                and not old.is_integer() and not new.is_integer()
                and math.isclose(old, new, rel_tol=1e-12, abs_tol=1e-12))
    return type(old) is type(new) and old == new


def compare_preserved_paths(old: dict, new: dict, paths: list[str]) -> dict:
    return compare_mapped_paths(old, new, preservation_mappings(paths, []))


def preservation_mappings(paths: list[str], specifications: list[str]) -> list[tuple[str, str]]:
    """Resolve explicit identity paths and OLD=NEW mappings, without guessing renames."""
    def validate(path):
        if (not isinstance(path, str) or not path or path != path.strip()
                or any(not part or any(char.isspace() for char in part) for part in path.split("."))
                or "=" in path):
            raise ValueError("Preserved paths must be nonempty unambiguous dot paths")

    pairs = []
    for path in dict.fromkeys(paths):
        validate(path)
        pairs.append((path, path))
    for specification in specifications:
        if not isinstance(specification, str) or specification.count("=") != 1:
            raise ValueError("Preserved path mapping must be OLD=NEW")
        source, target = specification.split("=")
        validate(source)
        validate(target)
        pairs.append((source, target))
    if not pairs:
        raise ValueError("At least one explicit nonempty preserved save path or mapping is required")
    sources, targets = set(), set()
    for source, target in pairs:
        if source in sources or target in targets:
            raise ValueError("Duplicate or ambiguous preserved path mapping")
        sources.add(source)
        targets.add(target)
    return pairs


def compare_mapped_paths(old: dict, new: dict, mappings: list[tuple[str, str]]) -> dict:
    # Validate direct callers too; missing paths must fail rather than disappear.
    pairs = preservation_mappings([], [f"{source}={target}" for source, target in mappings])
    records = {}
    for source, target in pairs:
        label = source if source == target else f"{source} -> {target}"
        try:
            before, after = lookup_path(old, source), lookup_path(new, target)
            records[label] = {"old_path": source, "new_path": target,
                              "preserved": semantic_subset(before, after), "before": before, "after": after}
        except (ValueError, TypeError, OverflowError) as error:
            records[label] = {"old_path": source, "new_path": target, "preserved": False, "error": str(error)}
    return {"passed": all(record["preserved"] for record in records.values()), "paths": records}


def installed_version_code(output: str) -> int:
    codes = set(re.findall(r"(?m)^\s*versionCode=(\d+)\b", output))
    if len(codes) != 1:
        raise ValueError("Installed package did not report one unambiguous version code")
    return int(codes.pop())


def save_file_metadata(output: str) -> dict:
    match = re.fullmatch(r"\s*(\d+):(\d+):(\d+)\s*", output)
    if not match or int(match[3]) < 1:
        raise ValueError("Saved file did not report valid modification time, inode and size")
    return {"modified_epoch_seconds": int(match[1]), "inode": int(match[2]), "bytes": int(match[3])}


def fresh_save_write(before: dict, after: dict) -> bool:
    return after["modified_epoch_seconds"] > before["modified_epoch_seconds"]


def require_expectation_spec(spec: dict, label: str) -> None:
    if not isinstance(spec, dict):
        raise ValueError(f"{label} expectations must be an object")
    for key in ("expected_save", "expected_numeric"):
        if key in spec and not isinstance(spec[key], dict):
            raise ValueError(f"{label} {key} must be an object")
    if not spec.get("expected_save") and not spec.get("expected_numeric"):
        raise ValueError(f"{label} saved-state assertions are required")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from-apk", required=True, type=Path)
    parser.add_argument("--to-apk", required=True, type=Path)
    parser.add_argument("--package", required=True)
    parser.add_argument("--save", required=True, help="Relative app-data JSON path, e.g. files/bastion-save.json")
    parser.add_argument("--actions", required=True, type=Path, help="Old-version input fixture with saved-state assertions")
    parser.add_argument("--preserve-path", action="append", default=[], help="Repeat for unchanged critical dot paths; arrays use numeric indices")
    parser.add_argument("--preserve-map", action="append", default=[], metavar="OLD=NEW",
                        help="Repeat for explicitly renamed critical dot paths, e.g. state=active_run")
    parser.add_argument("--expected-version", required=True, type=int, help="Expected NEW saved JSON schema version (APK codes are inspected independently)")
    parser.add_argument("--schema-path", default="version")
    parser.add_argument("--new-expectations", type=Path, help="Optional extra expected_save/expected_numeric JSON for the new version")
    parser.add_argument("--reset-test-data", action="store_true", help="Before old APK setup only, remove this emulator package and its test data")
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--config")
    parser.add_argument("--settle-seconds", type=float, default=6.0, help="Foreground settle before background/persist; default 6 seconds covers a 5-second autosave")
    args = parser.parse_args(argv)
    if not re.fullmatch(r"emulator-[0-9]+", args.serial):
        parser.error("Only an explicit emulator serial is supported; physical devices are refused")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", args.package):
        parser.error("A valid Android package is required")
    if not re.fullmatch(r"[a-zA-Z0-9_./-]+", args.save) or ".." in args.save or args.save.startswith("/"):
        parser.error("Save must be a safe relative app-data path")
    if args.expected_version < 1 or not 1 <= args.settle_seconds <= 30:
        parser.error("Expected save version must be positive and settle time must be 1-30 seconds")
    root = args.root.resolve()
    output = root / ".artifacts/upgrades" / args.package / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output.mkdir(parents=True)
    report = {"schema_version": 1, "scope": "real different-APK emulator upgrade; declared semantic paths only",
              "physical_phone_tested": False, "screenshots_need_visual_review": True,
              "package": args.package, "serial": args.serial, "result": "failed", "checks": {},
              "reset_test_data_authorized": args.reset_test_data, "preserve_paths": args.preserve_path,
              "numeric_comparison_policy": NUMERIC_COMPARISON,
              "runner_sha256": sha256(Path(__file__))}
    transcript = []
    adb_started = False
    adb, env = None, None
    inputs = {}

    def check(name: str, condition: bool):
        report["checks"][name] = bool(condition)
        if not condition:
            raise ValueError(f"Verification failed: {name}")

    def run(*words, binary=False, timeout=45):
        command = [adb, "-s", args.serial, *map(str, words)]
        try:
            result = subprocess.run(command, capture_output=True, env=env, timeout=timeout, check=False)
        except subprocess.TimeoutExpired:
            transcript.append({"argv": command, "timeout_seconds": timeout})
            raise
        decoded = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        transcript.append({"argv": command, "exit_code": result.returncode,
                           "stdout": f"{len(result.stdout)} binary bytes" if binary else decoded, "stderr": stderr})
        if result.returncode or (not binary and any(marker in decoded for marker in ("Error:", "Exception", "Failure ["))):
            raise RuntimeError(f"adb failed: {' '.join(map(str, words))}: {decoded[:1000]} {stderr[:1000]}")
        return result.stdout if binary else decoded.strip()

    def screenshot(label):
        (output / f"{label}.png").write_bytes(run("exec-out", "screencap", "-p", binary=True))

    def snapshot(label):
        raw = run("exec-out", "run-as", args.package, "cat", args.save, binary=True)
        (output / f"{label}-save.json").write_bytes(raw)
        report.setdefault("save_hashes", {})[label] = hashlib.sha256(raw).hexdigest()
        metadata = save_file_metadata(run("exec-out", "run-as", args.package, "stat", "-c", "%Y:%i:%s", args.save))
        report.setdefault("save_file_metadata", {})[label] = metadata
        data = json.loads(raw)
        if not isinstance(data, dict):
            raise ValueError("App-written save must be a JSON object")
        return data

    def launcher():
        activity = run("shell", "cmd", "package", "resolve-activity", "--brief", args.package).splitlines()[-1]
        if not activity.startswith(args.package + "/"):
            raise ValueError("App launcher was not resolved to the requested package")
        return activity

    def launch_background(label):
        run("shell", "am", "start", "-W", "-n", launcher())
        time.sleep(args.settle_seconds)
        check(label + "_process_alive", bool(run("shell", "pidof", args.package)))
        screenshot(label + "-foreground")
        run("shell", "input", "keyevent", "KEYCODE_HOME")
        time.sleep(1)
        return snapshot(label)

    def assertions(label, data, spec):
        evaluation = evaluate_expectations(data, spec)
        report.setdefault("saved_state_expectations", {})[label] = evaluation
        check(label + "_assertions", bool(evaluation["checks"]) and all(evaluation["checks"].values()))

    try:
        action_spec = json.loads(args.actions.read_text(encoding="utf-8"))
        require_expectation_spec(action_spec, "Old-version fixture")
        actions = action_spec.get("actions")
        if not isinstance(actions, list) or not any(action.get("type") in ("tap", "swipe") for action in actions if isinstance(action, dict)):
            raise ValueError("Old-version fixture must contain actual tap or swipe input")
        if action_spec.get("requires_fresh_emulator_app_data") and not args.reset_test_data:
            raise ValueError("This fixture requires --reset-test-data before old-version setup")
        mappings = preservation_mappings(args.preserve_path, args.preserve_map)
        old_paths = [source for source, _ in mappings]
        new_paths = [target for _, target in mappings]
        report["preservation_mappings"] = [{"old_path": source, "new_path": target} for source, target in mappings]
        report["old_preserve_paths"], report["new_preserve_paths"] = old_paths, new_paths
        for path in [args.schema_path]:
            if not path or any(not part for part in path.split(".")):
                raise ValueError("Preserved/schema paths must be nonempty dot paths")
        new_spec = json.loads(args.new_expectations.read_text(encoding="utf-8")) if args.new_expectations else {}
        if not isinstance(new_spec, dict):
            raise ValueError("New expectations must be an object")
        exact = new_spec.setdefault("expected_save", {})
        if not isinstance(exact, dict) or (args.schema_path in exact and exact[args.schema_path] != args.expected_version):
            raise ValueError("New expectations conflict with the declared save schema version")
        exact[args.schema_path] = args.expected_version
        require_expectation_spec(new_spec, "New-version")
        report.update(old_fixture=action_spec, old_fixture_sha256=sha256(args.actions), new_expectations=new_spec)
        config = read_config(root, args.config)
        env = tool_environment(config)
        adb = str(Path(config["android_sdk"]) / "platform-tools/adb.exe")
        metadata = {}
        for label, source in (("from", args.from_apk.resolve()), ("to", args.to_apk.resolve())):
            before = sha256(source)
            archived = output / "apks" / f"{label}.apk"
            archived.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, archived)
            check(label + "_archive_unchanged", before == sha256(source) == sha256(archived))
            inputs[label] = (source, before, archived)
            inspection = output / f"{label}-inspection"
            inspection.mkdir()
            metadata[label] = inspect_apk(archived, config, env, inspection)
            report.setdefault("apks", {})[label] = {"original_path": str(source), "archive": artifact_record(archived, root),
                                                    "metadata": metadata[label]}
        check("different_apk_bytes", inputs["from"][1] != inputs["to"][1])
        report["version_transition"] = validate_apk_pair(metadata["from"], metadata["to"], args.package)
        check("valid_signed_offline_increasing_version_pair", True)
        run("wait-for-device")
        adb_started = True
        check("emulator_booted", run("shell", "getprop", "sys.boot_completed") == "1")
        report["device_model"] = run("shell", "getprop", "ro.product.model")
        report["android_api"] = run("shell", "getprop", "ro.build.version.sdk")
        existing = run("shell", "pm", "list", "packages", args.package).splitlines()
        if args.reset_test_data and "package:" + args.package in existing:
            run("uninstall", args.package)
            report["initial_setup_uninstalled_test_package"] = True
        run("install", "--no-incremental", "-r", inputs["from"][2], timeout=90)
        check("old_code_installed", installed_version_code(run("shell", "dumpsys", "package", args.package)) == report["version_transition"]["from_version_code"])
        run("shell", "svc", "wifi", "disable")
        run("shell", "svc", "data", "disable")
        check("offline_radios_disabled", True)
        run("logcat", "-c")
        run("shell", "am", "force-stop", args.package)
        run("shell", "am", "start", "-W", "-n", launcher())
        time.sleep(args.settle_seconds)
        check("old_process_alive", bool(run("shell", "pidof", args.package)))
        dimensions = re.findall(r"size: (\d+)x(\d+)", run("shell", "wm", "size"))[-1]
        display = tuple(map(int, dimensions))
        report["display_pixels"] = display
        if action_spec.get("reference_display"):
            actions = [scale_action(action, tuple(action_spec["reference_display"]), display,
                                    tuple(action_spec.get("viewport", [720, 1280]))) for action in actions]
        report["actual_old_input_actions"] = actions
        for action in actions:
            kind = action["type"]
            if kind == "tap":
                run("shell", "input", "tap", int(action["x"]), int(action["y"]))
            elif kind == "swipe":
                run("shell", "input", "swipe", *[int(action[key]) for key in ("x1", "y1", "x2", "y2", "duration_ms")])
            elif kind != "wait":
                raise ValueError(f"Unsupported input action: {kind}")
            time.sleep(min(10.0, max(0.0, float(action.get("wait_seconds", 0.2)))))
        screenshot("old-after-input")
        run("shell", "input", "keyevent", "KEYCODE_HOME")
        time.sleep(1)
        old_save = snapshot("old-before-upgrade")
        assertions("old_input", old_save, action_spec)
        check("old_critical_paths_exist", compare_preserved_paths(old_save, old_save, old_paths)["passed"])
        run("shell", "am", "force-stop", args.package)
        # The upgrade boundary: no uninstall, data clear, or imported fixture writes.
        run("install", "--no-incremental", "-r", inputs["to"][2], timeout=90)
        check("new_code_installed", installed_version_code(run("shell", "dumpsys", "package", args.package)) == report["version_transition"]["to_version_code"])
        installed_save = snapshot("new-installed-before-launch")
        report["install_retention"] = compare_preserved_paths(old_save, installed_save, old_paths)
        check("installer_preserved_critical_paths", report["install_retention"]["passed"])
        migrated = launch_background("new-after-launch")
        check("new_app_wrote_save_after_launch", fresh_save_write(
            report["save_file_metadata"]["new-installed-before-launch"], report["save_file_metadata"]["new-after-launch"]))
        report["migration_preservation"] = compare_mapped_paths(old_save, migrated, mappings)
        check("migration_preserved_critical_paths", report["migration_preservation"]["passed"])
        assertions("new_after_launch", migrated, new_spec)
        run("shell", "am", "force-stop", args.package)
        reloaded = launch_background("new-cold-relaunch")
        check("new_app_wrote_save_after_cold_relaunch", fresh_save_write(
            report["save_file_metadata"]["new-after-launch"], report["save_file_metadata"]["new-cold-relaunch"]))
        report["relaunch_stability"] = compare_preserved_paths(migrated, reloaded, new_paths)
        check("relaunch_critical_paths_stable", report["relaunch_stability"]["passed"])
        report["relaunch_old_preservation"] = compare_mapped_paths(old_save, reloaded, mappings)
        check("relaunch_retained_old_critical_paths", report["relaunch_old_preservation"]["passed"])
        assertions("new_cold_relaunch", reloaded, new_spec)
        for label, (source, expected, archive) in inputs.items():
            check(label + "_input_and_archive_remained_unchanged", sha256(source) == expected == sha256(archive))
        report["result"] = "passed"
    except (OSError, ValueError, TypeError, KeyError, IndexError, OverflowError, RuntimeError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
    finally:
        if adb_started:
            try:
                logcat = run("logcat", "-d", "-s", "godot", "Godot", "AndroidRuntime")
                (output / "logcat.txt").write_text(logcat, encoding="utf-8")
                report["runtime_warnings"] = [line.strip() for line in logcat.splitlines() if "WARNING:" in line]
                clean = not ("SCRIPT ERROR:" in logcat or "FATAL EXCEPTION" in logcat or re.search(r"\bE\s+godot\s*:\s*ERROR:", logcat))
                report["checks"]["no_runtime_errors"] = clean
                if not clean:
                    report["result"] = "failed"
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                report["logcat_collection_error"] = str(error)
                report["result"] = "failed"
        (output / "transcript.json").write_text(json.dumps(transcript, indent=2), encoding="utf-8")
        (output / "manifest.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"Evidence: {output}")
    return 0 if report["result"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
