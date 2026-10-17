"""Record an emulator APK install/input/lifecycle/update smoke test.

Requires an already booted emulator. Actions JSON contains tap/swipe/wait events.
Checks package launch and save retention; screenshots still need visual review.
This script deliberately refuses physical devices and never claims phone testing.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import time

from portfolio import REPO_ROOT, artifact_record, read_config, tool_environment


def lookup_path(value, path: str):
    """Read explicit dictionary keys and nonnegative list indices in a dot path."""
    if not isinstance(path, str) or not path or any(not part for part in path.split(".")):
        raise ValueError(f"Invalid expectation path: {path!r}")
    current = value
    for part in path.split("."):
        if isinstance(current, dict) and part in current:
            current = current[part]
        elif isinstance(current, list) and part.isdecimal() and int(part) < len(current):
            current = current[int(part)]
        else:
            raise ValueError(f"Missing field or wrong container at {path!r}")
    return current


def evaluate_expectations(saved_state: dict, action_spec: dict) -> dict:
    checks = {}
    failures = []
    exact = action_spec.get("expected_save", {})
    numeric = action_spec.get("expected_numeric", {})
    if exact:
        matched = True
        for path, expected in exact.items():
            try:
                actual = lookup_path(saved_state, path)
                valid = actual == expected and (not isinstance(actual, bool) and not isinstance(expected, bool)
                                                or type(actual) is type(expected))
            except ValueError:
                valid = False
            if not valid:
                failures.append(f"Exact saved-state expectation failed: {path}")
                matched = False
        checks["expected_saved_state_after_input"] = matched
    if numeric:
        matched = True
        for path, bounds in numeric.items():
            try:
                actual = lookup_path(saved_state, path)
                valid = isinstance(actual, (int, float)) and not isinstance(actual, bool) and math.isfinite(actual)
                valid = valid and isinstance(bounds, dict) and bool(bounds) and set(bounds) <= {"min", "max"}
                if valid:
                    valid = all(isinstance(bound, (int, float)) and not isinstance(bound, bool)
                                and math.isfinite(bound) for bound in bounds.values())
                if valid:
                    valid = bounds.get("min", -math.inf) <= actual <= bounds.get("max", math.inf)
            except (ValueError, TypeError, OverflowError):
                valid = False
            if not valid:
                failures.append(f"Numeric saved-state expectation failed: {path}")
                matched = False
        checks["expected_numeric_state_after_input"] = matched
    return {"checks": checks, "exact_fields": len(exact), "numeric_fields": len(numeric), "failures": failures}


def scale_action(action: dict, reference: tuple[int, int], target: tuple[int, int],
                 viewport=(720, 1280)) -> dict:
    """Map a touch through a centered, aspect-preserving portrait viewport."""
    source_scale = min(reference[0] / viewport[0], reference[1] / viewport[1])
    target_scale = min(target[0] / viewport[0], target[1] / viewport[1])
    result = action.copy()
    for axis, keys in enumerate((("x", "x1", "x2"), ("y", "y1", "y2"))):
        source_offset = (reference[axis] - viewport[axis] * source_scale) / 2
        target_offset = (target[axis] - viewport[axis] * target_scale) / 2
        for key in keys:
            if key in result:
                result[key] = round((result[key] - source_offset) / source_scale * target_scale + target_offset)
    return result


def input_command(action: dict) -> list[str]:
    """Translate the supported actual input events; BACK is the only allowed key."""
    kind = action["type"]
    if kind == "tap":
        return ["shell", "input", "tap", str(int(action["x"])), str(int(action["y"]))]
    if kind == "swipe":
        return ["shell", "input", "swipe", *[str(int(action[k])) for k in ("x1", "y1", "x2", "y2", "duration_ms")]]
    if kind == "key" and action.get("key") == "BACK":
        return ["shell", "input", "keyevent", "KEYCODE_BACK"]
    if kind == "wait":
        return []
    raise ValueError(f"Unsupported input action or key: {kind!r} {action.get('key')!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--save", required=True, help="Relative file under the app data directory, e.g. files/probe-save.json")
    parser.add_argument("--actions", type=Path, required=True)
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--display-size", help="Optional emulator resolution approximation, e.g. 1080x2520")
    args = parser.parse_args()
    if not args.serial.startswith("emulator-") or not re.fullmatch(r"[a-zA-Z0-9_.]+", args.package):
        parser.error("An emulator serial and valid package name are required")
    if not re.fullmatch(r"[a-zA-Z0-9_./-]+", args.save) or ".." in args.save or args.save.startswith("/"):
        parser.error("Save must be a safe relative app-data path")
    if args.display_size and not re.fullmatch(r"[1-9][0-9]{2,3}x[1-9][0-9]{2,3}", args.display_size):
        parser.error("Display size must be WIDTHxHEIGHT, each between 100 and 9999")
    root = args.root.resolve()
    config = read_config(root)
    env = tool_environment(config)
    adb = str(Path(config["android_sdk"]) / "platform-tools/adb.exe")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = root / ".artifacts/emulator" / args.package / stamp
    output.mkdir(parents=True)
    transcript = []
    previous_override = None
    changed_display = False
    report = {"schema_version": 1, "scope": "emulator smoke only", "physical_phone_tested": False,
              "package": args.package, "serial": args.serial, "result": "failed", "started_utc": stamp,
              "apk": artifact_record(args.apk.resolve(), root), "checks": {}}

    def run(*words: str, binary=False, timeout=45):
        command = [adb, "-s", args.serial, *words]
        result = subprocess.run(command, capture_output=True, env=env, timeout=timeout, check=False)
        decoded = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        transcript.append({"argv": command, "exit_code": result.returncode,
                           "stdout": f"{len(result.stdout)} binary bytes" if binary else decoded, "stderr": stderr})
        if result.returncode or (not binary and any(s in decoded for s in ("Error:", "Exception", "Failure ["))):
            raise RuntimeError(f"adb failed: {' '.join(words)}: {decoded[:1000]} {stderr[:1000]}")
        return result.stdout if binary else decoded.strip()

    def screenshot(label):
        (output / f"{label}.png").write_bytes(run("exec-out", "screencap", "-p", binary=True))

    def snapshot(label):
        content = run("exec-out", "run-as", args.package, "cat", args.save, binary=True)
        state = json.loads(content)
        if not isinstance(state, dict):
            raise ValueError("Saved state is not a JSON object")
        (output / f"{label}-save.json").write_bytes(content)
        return content

    try:
        run("wait-for-device")
        if run("shell", "getprop", "sys.boot_completed") != "1":
            raise RuntimeError("Emulator boot is incomplete")
        report["device_model"] = run("shell", "getprop", "ro.product.model")
        report["android_api"] = run("shell", "getprop", "ro.build.version.sdk")
        display_info = run("shell", "wm", "size")
        previous = re.search(r"Override size: (\d+x\d+)", display_info)
        previous_override = previous[1] if previous else None
        if args.display_size:
            run("shell", "wm", "size", args.display_size)
            changed_display = True
            time.sleep(1)
        display_info = run("shell", "wm", "size")
        dimensions = re.findall(r"size: (\d+)x(\d+)", display_info)[-1]
        current_display = tuple(map(int, dimensions))
        report["display_pixels"] = current_display
        report["display_scope"] = "Resolution approximation on generic emulator; device hardware unchanged"
        run("install", "--no-incremental", "-r", str(args.apk.resolve()), timeout=90)
        run("shell", "svc", "wifi", "disable")
        run("shell", "svc", "data", "disable")
        report["checks"]["offline_radios_disabled"] = True
        activity = run("shell", "cmd", "package", "resolve-activity", "--brief", args.package).splitlines()[-1]
        if "/" not in activity:
            raise RuntimeError("Launcher activity not resolved")
        report["launcher"] = activity
        run("shell", "am", "force-stop", args.package)
        run("logcat", "-c")
        run("shell", "am", "start", "-W", "-n", activity)
        time.sleep(2)
        report["checks"]["offline_launch"] = bool(run("shell", "pidof", args.package))
        screenshot("launch")
        action_spec = json.loads(args.actions.read_text(encoding="utf-8"))
        actions = action_spec.get("actions", []) if isinstance(action_spec, dict) else action_spec
        if isinstance(action_spec, dict) and action_spec.get("reference_display"):
            actions = [scale_action(action, tuple(action_spec["reference_display"]), current_display,
                                    tuple(action_spec.get("viewport", [720, 1280]))) for action in actions]
        report["actions"] = actions
        for action in actions:
            command = input_command(action)
            if command:
                run(*command)
            time.sleep(min(10.0, max(0.0, float(action.get("wait_seconds", 0.2)))))
        screenshot("after-input")
        run("shell", "input", "keyevent", "KEYCODE_HOME")
        time.sleep(1)
        saved = snapshot("background")
        saved_state = json.loads(saved)
        if isinstance(action_spec, dict):
            expectations = evaluate_expectations(saved_state, action_spec)
            report["checks"].update(expectations.pop("checks"))
            report["expectation_coverage"] = expectations
        run("shell", "am", "start", "-W", "-n", activity)
        time.sleep(1)
        report["checks"]["background_resume_process_alive"] = bool(run("shell", "pidof", args.package))
        screenshot("resumed")
        run("shell", "input", "keyevent", "KEYCODE_HOME")
        time.sleep(0.5)
        run("shell", "am", "force-stop", args.package)
        before_update = snapshot("before-update")
        run("install", "--no-incremental", "-r", str(args.apk.resolve()), timeout=90)
        after_update = snapshot("after-update")
        report["checks"]["same_apk_reinstall_save_identical"] = before_update == after_update
        report["save_sha256_before_update"] = hashlib.sha256(before_update).hexdigest()
        report["save_sha256_after_update"] = hashlib.sha256(after_update).hexdigest()
        run("shell", "am", "start", "-W", "-n", activity)
        time.sleep(1)
        screenshot("after-update-launch")
        report["checks"]["relaunch_after_reinstall"] = bool(run("shell", "pidof", args.package))
        logcat = run("logcat", "-d", "-s", "godot", "Godot", "AndroidRuntime")
        (output / "logcat.txt").write_text(logcat, encoding="utf-8")
        report["runtime_warnings"] = [line.strip() for line in logcat.splitlines() if "WARNING:" in line]
        report["checks"]["no_godot_or_android_runtime_errors"] = not (
            "SCRIPT ERROR:" in logcat or "FATAL EXCEPTION" in logcat or
            re.search(r"\bE\s+godot\s*:\s*ERROR:", logcat))
        report["checks"]["valid_saved_json"] = bool(saved)
        report["result"] = "passed" if all(report["checks"].values()) else "failed"
    except (OSError, ValueError, TypeError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
    finally:
        if changed_display:
            try:
                run("shell", "wm", "size", previous_override or "reset")
                report["display_override_restored"] = True
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                report["display_restore_error"] = str(error)
                report["result"] = "failed"
    (output / "transcript.json").write_text(json.dumps(transcript, indent=2), encoding="utf-8")
    (output / "manifest.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"Evidence: {output}")
    return 0 if report["result"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
