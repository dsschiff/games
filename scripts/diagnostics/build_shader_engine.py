"""Build only the pinned opt-in x86_64 engine probe; never install or export a game."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import subprocess
import sys

ENGINE_COMMIT = "ed1daf0bf001b61586d9930840f2f1394092c079"
PATCHED_SHADER = "3910d99e05237527675855b23a9a3992df0dd744dc548a14c8beb24ed44e6d68"
FLAGS = ["platform=android", "target=template_release", "arch=x86_64", "production=no", "debug_symbols=no", "lto=none", "swappy=yes", "cppdefines=GAMES_SHADER_CACHE_DIAGNOSTIC", "extra_suffix=games_shader_diag", "-j4"]


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def pin(path):
    return {"path": str(path.resolve()), "bytes": path.stat().st_size, "sha256": sha(path)}


def git(engine, *args):
    return subprocess.check_output(["git", "-C", str(engine), *args]).decode("utf-8").strip()


def source_map(engine):
    paths = subprocess.check_output(["git", "-C", str(engine), "ls-files", "-z"]).decode("utf-8").split("\0")
    return {name: {"bytes": (engine / name).stat().st_size, "sha256": sha(engine / name)} for name in paths if name}


def write(path, value):
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--scons", required=True, type=Path)
    parser.add_argument("--sdk", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    engine, scons, sdk, out = (p.resolve() for p in (args.engine, args.scons, args.sdk, args.out))
    if git(engine, "rev-parse", "HEAD") != ENGINE_COMMIT:
        parser.error("Unexpected engine revision")
    dirty = git(engine, "diff", "--name-only").splitlines()
    if dirty != ["drivers/gles3/shader_gles3.cpp"] or git(engine, "diff", "--cached", "--name-only"):
        parser.error("Unexpected engine tracked changes")
    shader = engine / "drivers/gles3/shader_gles3.cpp"
    if sha(shader) != PATCHED_SHADER:
        parser.error("Unexpected diagnostic shader bytes")
    versions = {d.metadata["Name"].lower(): d.version for d in importlib.metadata.distributions(path=[str(scons)])}
    if versions.get("scons") != "4.10.1":
        parser.error("Pinned SCons 4.10.1 required")
    ndk = sdk / "ndk/29.0.14206865"
    properties = (ndk / "source.properties").read_text(encoding="utf-8")
    if "Pkg.Revision = 29.0.14206865" not in properties:
        parser.error("Unexpected Android NDK")
    compiler = ndk / "toolchains/llvm/prebuilt/windows-x86_64/bin/clang++.exe"
    compiler_version = subprocess.check_output([str(compiler), "--version"], text=True)
    swappy = [engine / "thirdparty/swappy-frame-pacing" / arch / "libswappy_static.a" for arch in ("arm64-v8a", "armeabi-v7a", "x86", "x86_64")]
    if not all(p.is_file() for p in swappy):
        parser.error("Pinned upstream Swappy libraries required")
    out.mkdir(parents=True, exist_ok=False)
    started = datetime.now(timezone.utc).isoformat()
    before = source_map(engine)
    write(out / "source-before.json", before)
    command = [sys.executable, "-c", "import sys; sys.path.insert(0, sys.argv.pop(1)); import SCons.Script; SCons.Script.main()", str(scons), *FLAGS]
    env = os.environ.copy()
    env.update({"ANDROID_HOME": str(sdk), "ANDROID_SDK_ROOT": str(sdk), "PYTHONDONTWRITEBYTECODE": "1", "NO_COLOR": "1", "TERM": "dumb", "TEMP": str(out / "temp"), "TMP": str(out / "temp")})
    (out / "temp").mkdir()
    initial = {"schema": 1, "purpose": "Local diagnostic engine only; no native run or production fix claimed", "engine": str(engine), "engine_commit": ENGINE_COMMIT, "started": started, "command": command, "cwd": str(engine), "shader": pin(shader), "runner": pin(Path(__file__)), "ndk_properties": pin(ndk / "source.properties"), "compiler": pin(compiler), "compiler_version": compiler_version, "scons_version": versions["scons"], "swappy": [pin(p) for p in swappy], "source_files": len(before), "source_before": pin(out / "source-before.json")}
    write(out / "started.json", initial)
    print(json.dumps({"status": "building", "receipt": str(out / "started.json"), "log": str(out / "build.log"), "jobs": 4}), flush=True)
    with (out / "build.log").open("xb") as log:
        result = subprocess.run(command, cwd=engine, env=env, stdout=log, stderr=subprocess.STDOUT)
    after = source_map(engine)
    write(out / "source-after.json", after)
    # Upstream Android SConscript moves the linked library out of bin/.
    library = engine / "platform/android/java/lib/libs/release/x86_64/libgodot_android.so"
    libraries = [library] if library.is_file() else []
    inspected = []
    for library in libraries:
        raw = library.read_bytes()
        inspected.append(pin(library) | {"elf_x86_64": raw[:6] == b"\x7fELF\x02\x01" and int.from_bytes(raw[18:20], "little") == 62, "diagnostic_prefix_present": b"GAMES_SHADER_CACHE_DIAGNOSTIC " in raw})
    success = result.returncode == 0 and before == after and len(inspected) == 1 and inspected[0]["elf_x86_64"] and inspected[0]["diagnostic_prefix_present"]
    receipt = initial | {"finished": datetime.now(timezone.utc).isoformat(), "exit_code": result.returncode, "status": "compiled" if success else "failed", "source_unchanged": before == after, "source_after": pin(out / "source-after.json"), "build_log": pin(out / "build.log"), "libraries": inspected, "native_tested": False, "production_fix": False}
    write(out / "manifest.json", receipt)
    print(json.dumps({"status": receipt["status"], "manifest": str(out / "manifest.json"), "source_unchanged": before == after, "exit_code": result.returncode}), flush=True)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
