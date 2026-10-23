"""Build the optional Android cloud transport with pinned official tooling."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
GRADLE = "8.14.3"
SHA256 = "bd71102213493060956ec229d946beee57158dbd89d0e62b91bca0fa2c5f3531"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gradle-home", type=Path, default=Path("F:/games-workspaces/tooling/gradle"))
    parser.add_argument("--cache", type=Path, default=Path("F:/games-workspaces/tooling/gradle-cache"))
    args = parser.parse_args()
    config = json.loads((ROOT / "toolchain.json").read_text(encoding="utf-8"))
    home = os.environ.get("GAME_TOOLCHAIN_ROOT", config["toolchain_root"])
    for key in ("android_sdk", "java_home"):
        config[key] = config[key].replace("{toolchain_root}", home)
    args.gradle_home.mkdir(parents=True, exist_ok=True)
    executable = args.gradle_home / f"gradle-{GRADLE}/bin/gradle.bat"
    if not executable.exists():
        archive = args.gradle_home / f"gradle-{GRADLE}-bin.zip"
        if not archive.exists():
            pending = archive.with_suffix(".part")
            print("Downloading pinned official Gradle distribution", flush=True)
            urllib.request.urlretrieve(f"https://services.gradle.org/distributions/gradle-{GRADLE}-bin.zip", pending)
            if hashlib.file_digest(pending.open("rb"), "sha256").hexdigest() != SHA256:
                pending.unlink()
                raise RuntimeError("Gradle archive checksum mismatch")
            pending.replace(archive)
        with archive.open("rb") as stream:
            if hashlib.file_digest(stream, "sha256").hexdigest() != SHA256:
                raise RuntimeError("Cached Gradle archive checksum mismatch")
        with zipfile.ZipFile(archive) as bundle:
            for name in bundle.namelist():
                if not (args.gradle_home / name).resolve().is_relative_to(args.gradle_home.resolve()):
                    raise RuntimeError("Unsafe Gradle archive path")
            bundle.extractall(args.gradle_home)
    env = os.environ.copy()
    env.update(JAVA_HOME=config["java_home"], ANDROID_HOME=config["android_sdk"], ANDROID_SDK_ROOT=config["android_sdk"], GRADLE_USER_HOME=str(args.cache))
    native = ROOT / "android-games/shared/play-cloud/native"
    sdk = Path(config["android_sdk"]).resolve()
    if not sdk.is_dir():
        raise FileNotFoundError(f"Android SDK absent: {sdk}")
    (native / "local.properties").write_text("sdk.dir=" + sdk.as_posix() + "\n", encoding="utf-8")
    command = [str(executable), "--no-daemon", "--console=plain", "--max-workers=2", ":library:testReleaseUnitTest", ":library:assembleRelease"]
    run = ROOT / ".artifacts/cloud-native"
    run.mkdir(parents=True, exist_ok=True)
    source_files = sorted((native / "library/src").rglob("*.kt")) + [Path(__file__).resolve(),
        native / "build.gradle.kts", native / "settings.gradle.kts", native / "gradle.properties",
        native / "library/build.gradle.kts", native / "library/src/main/AndroidManifest.xml"]
    source_hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in source_files}
    result = subprocess.run(command, cwd=ROOT / "android-games/shared/play-cloud/native", env=env, check=False,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0), timeout=900)
    (run / "build.log").write_bytes(result.stdout)
    sys.stdout.buffer.write(result.stdout)
    print(f"\nGradle exit: {result.returncode}; log: {run / 'build.log'}", flush=True)
    tests = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    for report in (native / "library/build/test-results/testReleaseUnitTest").glob("TEST-*.xml"):
        suite = ET.parse(report).getroot()
        for key in tests:
            tests[key] += int(suite.attrib.get(key, "0"))
    unchanged = source_hashes == {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in source_files}
    aar = native / "library/build/outputs/aar/library-release.aar"
    passed = result.returncode == 0 and tests["tests"] > 0 and tests["failures"] == tests["errors"] == tests["skipped"] == 0 and unchanged and aar.is_file()
    (run / "receipt.json").write_text(json.dumps({"passed": passed, "command": command, "exit_code": result.returncode,
        "source_unchanged": unchanged, "source_sha256": source_hashes, "jvm_tests": tests,
        "aar_sha256": hashlib.sha256(aar.read_bytes()).hexdigest() if aar.is_file() else None,
        "scope": "Real pinned Android/GMS/Godot compile and controllable JVM resource/lifetime tests; no account/device/live cloud test."}, indent=2) + "\n", encoding="utf-8")
    print("Native receipt:", run / "receipt.json", "PASS" if passed else "FAIL", tests)
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
