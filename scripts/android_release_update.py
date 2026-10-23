"""Non-destructive signed release update smoke on an already booted test emulator.

Reads no private app files and never clears/uninstalls an app. Screenshots require
human visual review; process continuity is not whole-save-retention evidence.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
from portfolio import REPO_ROOT, inspect_apk, read_config, tool_environment


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--expect-signer", required=True)
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--settle", type=float, default=8)
    args = parser.parse_args()
    if not re.fullmatch(r"emulator-[0-9]+", args.serial):
        raise ValueError("This helper never operates on a physical device")
    config = read_config(REPO_ROOT)
    env = tool_environment(config)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run = REPO_ROOT / ".artifacts/release-updates" / args.package / stamp
    run.mkdir(parents=True)
    metadata = inspect_apk(args.apk.resolve(), config, env, run)
    if metadata["signer_certificate_sha256"].lower() != args.expect_signer.lower():
        raise ValueError("Release signer differs from the approved identity")
    if metadata["package"] != args.package or metadata["debuggable"] or metadata["internet_permission"]:
        raise ValueError("APK identity/offline/release verification failed")
    adb = Path(config["android_sdk"]) / "platform-tools/adb.exe"
    commands = []
    def call(*parts, binary=False):
        command = [str(adb), "-s", args.serial, *parts]
        result = subprocess.run(command, env=env, capture_output=True, timeout=150, check=True)
        commands.append({"args": list(parts), "exit": result.returncode})
        return result.stdout if binary else result.stdout.decode("utf-8", errors="replace").strip()
    if call("get-serialno") != args.serial or call("shell", "getprop", "sys.boot_completed") != "1":
        raise RuntimeError("Emulator is not fully booted")
    before = call("shell", "dumpsys", "package", args.package)
    version = re.search(r"versionCode=(\d+)", before)
    if not version or int(version[1]) >= int(metadata["version_code"]):
        raise ValueError("Expected an already installed lower version; no install performed")
    component = call("shell", "cmd", "package", "resolve-activity", "--brief", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", args.package).splitlines()[-1]
    if "/" not in component or not component.startswith(args.package + "/"):
        raise RuntimeError("Could not resolve installed app launcher")
    wifi = call("shell", "settings", "get", "global", "wifi_on")
    data = call("shell", "settings", "get", "global", "mobile_data")
    report = {"scope": "signed in-place release update and process lifecycle; visual review required; no raw save readback", "before_version_code": int(version[1]), "apk": str(args.apk.resolve()), "apk_sha256": hashlib.file_digest(args.apk.open("rb"), "sha256").hexdigest(), "apk_inspection": metadata, "checks": {}, "commands": commands}
    def screen(label):
        time.sleep(max(0, args.settle))
        pid = call("shell", "pidof", args.package)
        foreground = call("shell", "dumpsys", "activity", "activities")
        report["checks"][label] = {"pid": pid, "foreground": any(args.package in line for line in foreground.splitlines() if "mResumedActivity" in line or "topResumedActivity" in line)}
        if not pid or not report["checks"][label]["foreground"]:
            raise RuntimeError(f"App not alive and foreground at {label}")
        (run / (label + ".png")).write_bytes(call("exec-out", "screencap", "-p", binary=True))
        print(label, "pid=" + pid, flush=True)
        return pid
    try:
        call("shell", "svc", "wifi", "disable")
        call("shell", "svc", "data", "disable")
        call("shell", "am", "start", "-n", component)
        screen("before-update")
        installed = call("install", "-r", str(args.apk.resolve()))
        if "Success" not in installed:
            raise RuntimeError("Installer did not report Success")
        after = call("shell", "dumpsys", "package", args.package)
        if f"versionCode={metadata['version_code']} " not in after:
            raise RuntimeError("Installed version differs from inspected APK")
        call("shell", "am", "start", "-n", component)
        launch = screen("after-update")
        call("shell", "input", "keyevent", "KEYCODE_HOME")
        call("shell", "am", "start", "-n", component)
        resumed = screen("home-resume")
        if launch != resumed:
            raise RuntimeError("Home unexpectedly replaced the app process")
        call("shell", "am", "force-stop", args.package)
        call("shell", "am", "start", "-n", component)
        cold = screen("cold-relaunch")
        report["checks"]["cold_process_replaced"] = cold != launch
        logs = call("logcat", "-d", "-t", "2000", "AndroidRuntime:E", "*:S")
        (run / "runtime.log").write_text(logs, encoding="utf-8")
        report["checks"]["no_app_fatal"] = not (args.package in logs and "FATAL EXCEPTION" in logs)
        if not report["checks"]["no_app_fatal"] or not report["checks"]["cold_process_replaced"]:
            raise RuntimeError("Cold lifecycle or fatal-error check failed")
        report["automated_checks_passed"] = True
    finally:
        if wifi == "1": call("shell", "svc", "wifi", "enable")
        if data == "1": call("shell", "svc", "data", "enable")
        (run / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(run, flush=True)


if __name__ == "__main__":
    main()
