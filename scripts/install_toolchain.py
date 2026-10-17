"""Install verified portable Windows Godot/Android tools; no global PATH edits.

Run with --accept-licenses after reviewing Android SDK terms. --with-emulator
adds the API 35 Google APIs x86_64 image; no Windows features are changed.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import urllib.request
import zipfile

from portfolio import read_config, REPO_ROOT, tool_environment

BASE = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/"
ASSETS = {
    "Godot_v4.7.2-stable_win64.exe.zip": (
        BASE, "sha512", "83decd58fdf67b9d657958a1ae6bf1929c20785315a81effe245874cdc57acb709bf868e00778a96984338c1b29dafdb453c6847747694621c6ecf5da2259993"),
    "Godot_v4.7.2-stable_export_templates.tpz": (
        BASE, "sha512", "ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"),
    "commandlinetools-win-15859902_latest.zip": (
        "https://dl.google.com/android/repository/", "sha256", "90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a"),
}


def fetch_asset(home: Path, name: str) -> dict:
    base, algorithm, expected = ASSETS[name]
    destination = home / "downloads" / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        partial = destination.with_suffix(destination.suffix + ".partial")
        print(f"Downloading {name}", flush=True)
        urllib.request.urlretrieve(base + name, partial)
        partial.replace(destination)
    digest = hashlib.new(algorithm)
    with destination.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    if digest.hexdigest() != expected:
        raise ValueError(f"Checksum mismatch: {destination}; remove it and retry")
    print(f"Verified {name}", flush=True)
    return {"name": name, "url": base + name, algorithm: expected}


def extract(home: Path):
    godot = home / "godot/4.7.2"
    godot.mkdir(parents=True, exist_ok=True)
    for name in ASSETS:
        with zipfile.ZipFile(home / "downloads" / name) as archive:
            for member in archive.infolist():
                parts = Path(member.filename).parts
                if "win64" in name:
                    target = godot.joinpath(*parts)
                elif "templates" in name:
                    if parts[-1] not in ("android_debug.apk", "android_release.apk", "version.txt"):
                        continue
                    target = godot / "editor_data/export_templates/4.7.2.stable" / parts[-1]
                else:
                    target = home.joinpath("android-sdk/cmdline-tools/latest", *parts[1:])
                target.resolve().relative_to(home.resolve())
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(archive.read(member))
    (godot / "_sc_").touch()


def configure_editor(config: dict):
    settings = Path(config["godot"]).parent / "editor_data/editor_settings-4.7.tres"
    body = settings.read_text(encoding="utf-8") if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    for key, value in (("export/android/android_sdk_path", config["android_sdk"]),
                       ("export/android/java_sdk_path", config["java_home"])):
        line = key + " = " + json.dumps(value.replace("\\", "/"))
        if re.search(r"(?m)^" + re.escape(key) + r" = .*", body):
            body = re.sub(r"(?m)^" + re.escape(key) + r" = .*", lambda _: line, body)
        else:
            body += "\n" + line
    settings.parent.mkdir(parents=True, exist_ok=True)
    settings.write_text(body + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--accept-licenses", action="store_true")
    parser.add_argument("--with-emulator", action="store_true")
    args = parser.parse_args()
    config = read_config(args.root.resolve())
    home = Path(config["toolchain_root"])
    if sys.platform != "win32":
        parser.error("Pinned assets are Windows x64; this installer requires Windows")
    if not args.accept_licenses:
        parser.error("Android SDK setup requires --accept-licenses (https://developer.android.com/studio/terms)")
    if not (Path(config["java_home"]) / "bin/java.exe").is_file():
        parser.error("Configured JDK not found; set java_home in local toolchain config")
    home.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        receipts = list(pool.map(lambda name: fetch_asset(home, name), ASSETS))
    extract(home)
    env = tool_environment(config)
    packages = ["platform-tools", "build-tools;35.0.1", "platforms;android-35"]
    if args.with_emulator:
        packages += ["emulator", "system-images;android-35;google_apis;x86_64"]
    manager = home / "android-sdk/cmdline-tools/latest/bin/sdkmanager.bat"
    log = home / "sdk-install.log"
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run([str(manager), "--sdk_root=" + config["android_sdk"], *packages],
                                input="y\n" * 100, stdout=stream, stderr=subprocess.STDOUT,
                                text=True, env=env, check=False)
    if result.returncode:
        print(f"SDK installation failed ({result.returncode}); see {log}")
        return result.returncode
    configure_editor(config)
    receipts.append({"sdk_packages_requested": packages,
                     "note": "SDK manager validates repository package checksums; installed package.xml records versions"})
    (home / "install-receipt.json").write_text(json.dumps(receipts, indent=2) + "\n", encoding="utf-8")
    print(f"Installed/configured portable toolchain in {home}; SDK log: {log}")
    print("Run python scripts/portfolio.py status, test, or build [project-name].")
    return 0


if __name__ == "__main__":
    sys.exit(main())
