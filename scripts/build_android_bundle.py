"""Build a source-stable offline Android App Bundle in disposable F: staging.

No upload, account setup or configured Play SDK is performed. The selected game
must be clean and tracked. Gradle output never enters the original project.
"""
from __future__ import annotations

import argparse
import configparser
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

from install_toolchain import ASSETS
from owned_process import run_owned
from portfolio import (REPO_ROOT, discover_projects, file_sha256, git_revision,
                       read_config, read_signing_env, resolve_godot, tool_environment)

BUNDLETOOL_SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
TEMPLATE_NAME = "Godot_v4.7.2-stable_export_templates.tpz"
ANDROID_SOURCE_SHA256 = "a15416b528efb0a19a7d187e4d9f4e5336d0689144b111329fb4bd12c4447ad3"
ANDROID = "{http://schemas.android.com/apk/res/android}"
GENERATED = {".godot", ".artifacts", "android", "__pycache__"}
MARKERS = ("ERROR:", "WARNING:", "SCRIPT ERROR", "ObjectDB instances leaked")


def preset_info(text: str, name: str) -> tuple[str, dict]:
    cfg = configparser.ConfigParser(interpolation=None)
    cfg.read_string(text)
    choices = [section for section in cfg.sections()
               if re.fullmatch(r"preset\.\d+", section)
               and json.loads(cfg[section].get("name", '""')) == name]
    if len(choices) != 1:
        raise ValueError("Expected exactly one named Android preset")
    section = choices[0]
    if json.loads(cfg[section].get("platform", '""')) != "Android":
        raise ValueError("Selected preset is not Android")
    options = dict(cfg[section + ".options"])
    for key in ("version/code", "version/name", "package/unique_name"):
        if key not in options:
            raise ValueError("Android preset lacks explicit " + key)
    abis = []
    for key, abi in (("armeabi-v7a", "armeabi-v7a"), ("arm64-v8a", "arm64-v8a"),
                     ("x86", "x86"), ("x86_64", "x86_64")):
        value = options.get("architectures/" + key)
        if value not in ("true", "false"):
            raise ValueError("Each ABI must be explicitly enabled or disabled")
        if value == "true":
            abis.append(abi)
    if not abis:
        raise ValueError("No enabled Android ABI")
    build_dir = json.loads(options.get("gradle_build/gradle_build_directory",
                                      '"res://android/build"'))
    custom = json.loads(options.get("gradle_build/android_source_template", '""'))
    if build_dir not in ("", "res://android/build") or custom:
        raise ValueError("Custom Android templates/build directories need separate qualification")
    return section + ".options", {
        "package": json.loads(options["package/unique_name"]),
        "version_code": int(options["version/code"]),
        "version_name": json.loads(options["version/name"]),
        "abis": sorted(abis),
    }


def bundle_preset(text: str, section: str) -> str:
    """Only the staged preset receives these three unsigned-Gradle options."""
    pattern = r"(?ms)^(\[" + re.escape(section) + r"\]\r?\n)(.*?)(?=^\[|\Z)"
    match = re.search(pattern, text)
    if not match:
        raise ValueError("Android preset options section absent")
    body = match[2]
    for key, value in (("gradle_build/use_gradle_build", "true"),
                       ("gradle_build/export_format", "1"), ("package/signed", "false")):
        line = re.compile(r"(?m)^" + re.escape(key) + r"=.*$")
        body = line.sub(lambda _: key + "=" + value, body) if line.search(body) else body.rstrip() + "\n" + key + "=" + value + "\n"
    return text[:match.start(2)] + body + text[match.end(2):]


def tracked_sources(root: Path, project: Path) -> dict[str, str]:
    dirty = subprocess.check_output(["git", "-C", str(root), "status", "--porcelain",
                                     "--", project.relative_to(root).as_posix()])
    if dirty.strip():
        raise ValueError("Game source must be clean before bundling")
    raw = subprocess.check_output(["git", "-C", str(root), "ls-files", "-z", "--",
                                   project.relative_to(root).as_posix()])
    sources = {}
    for item in filter(None, raw.decode("utf-8").split("\0")):
        source = root / item
        relative = source.relative_to(project)
        if source.is_symlink() or not source.is_file():
            raise ValueError("Missing or linked tracked game source: " + str(relative))
        if any(part in GENERATED for part in relative.parts):
            raise ValueError("Tracked generated/build directory needs separate qualification")
        sources[relative.as_posix()] = file_sha256(source)
    if "project.godot" not in sources or "export_presets.cfg" not in sources:
        raise ValueError("Project and export preset must be tracked")
    return sources


def staged_sources(project: Path) -> dict[str, str]:
    return {p.relative_to(project).as_posix(): file_sha256(p)
            for p in sorted(project.rglob("*")) if p.is_file()
            and not any(part in GENERATED for part in p.relative_to(project).parts)}


def extract_template(archive: zipfile.ZipFile, destination: Path) -> int:
    """Reject traversal, Windows alternate streams, links and name collisions."""
    names = set()
    total = 0
    members = archive.infolist()
    if sum(info.file_size for info in members) > 512 * 1024 * 1024:
        raise ValueError("Android source template exceeds qualified size")
    for info in members:
        name = info.filename.replace("\\", "/")
        parts = PurePosixPath(name).parts
        key = name.rstrip("/").casefold()
        if (not parts or name.startswith("/") or ".." in parts
                or any(":" in part for part in parts) or key in names
                or stat.S_ISLNK(info.external_attr >> 16)):
            raise ValueError("Unsafe Android source template member")
        names.add(key)
        target = destination.joinpath(*parts)
        target.resolve().relative_to(destination.resolve())
        if info.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(info) as source, target.open("xb") as output:
                shutil.copyfileobj(source, output, 1024 * 1024)
            total += info.file_size
    return total


def prepare_template(config: dict, stage: Path) -> dict:
    home = Path(config["toolchain_root"])
    archive = home / "downloads" / TEMPLATE_NAME
    expected = ASSETS[TEMPLATE_NAME][2]
    with archive.open("rb") as stream:
        if hashlib.file_digest(stream, "sha512").hexdigest() != expected:
            raise ValueError("Official export-template archive checksum mismatch")
    # Reuse the one machine template copy. Extract it only from the pinned TPZ.
    source_zip = Path(config["godot"]).parent / "editor_data/export_templates/4.7.2.stable/android_source.zip"
    if not source_zip.exists():
        source_zip.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as templates, templates.open("templates/android_source.zip") as source:
            with source_zip.open("xb") as output:
                shutil.copyfileobj(source, output, 1024 * 1024)
    if file_sha256(source_zip) != ANDROID_SOURCE_SHA256:
        raise ValueError("Android source-template checksum mismatch")
    android = stage / "android"
    build = android / "build"
    build.mkdir(parents=True, exist_ok=False)
    # Match the pinned engine's installer layout without its in-process rescan.
    # https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/export_template_manager.cpp
    (android / ".build_version").write_text("4.7.2.stable\n", encoding="utf-8")
    (build / ".gdignore").write_text("\n", encoding="utf-8")
    with zipfile.ZipFile(source_zip) as template:
        size = extract_template(template, build)
    return {"tpz_sha512": expected, "android_source_sha256": ANDROID_SOURCE_SHA256,
            "unpacked_template_bytes": size, "identifier": "4.7.2.stable"}


def inspect_manifest(xml: str, names: list[str], expected: dict) -> dict:
    manifest = ET.fromstring(xml)
    app = manifest.find("application")
    sdk = manifest.find("uses-sdk")
    if app is None or sdk is None:
        raise ValueError("Bundle manifest lacks application or SDK metadata")
    permissions = sorted(node.get(ANDROID + "name", "")
                         for node in manifest if node.tag.startswith("uses-permission"))
    abis = sorted({name.split("/")[2] for name in names
                   if re.fullmatch(r"base/lib/[^/]+/libgodot_android\.so", name)})
    value = {"package": manifest.get("package"),
             "version_code": int(manifest.get(ANDROID + "versionCode", "-1")),
             "version_name": manifest.get(ANDROID + "versionName"),
             "min_sdk": int(sdk.get(ANDROID + "minSdkVersion", "-1")),
             "target_sdk": int(sdk.get(ANDROID + "targetSdkVersion", "-1")),
             "debuggable": app.get(ANDROID + "debuggable", "false") != "false",
             "permissions": permissions, "abis": abis}
    for key in ("package", "version_code", "version_name", "abis"):
        if value[key] != expected[key]:
            raise ValueError("Bundle differs from selected game preset: " + key)
    if permissions or value["debuggable"] or value["min_sdk"] != 24 or value["target_sdk"] != 36:
        raise ValueError("Offline release bundle permission/debug/SDK policy mismatch")
    return value


def signer_digest(output: str) -> str:
    values = re.findall(r"SHA256:\s*([0-9a-fA-F:]{64,95})", output)
    if len(values) != 1:
        raise ValueError("Expected exactly one bundle signing certificate")
    digest = values[0].replace(":", "").lower()
    if len(digest) != 64:
        raise ValueError("Invalid bundle signing certificate digest")
    return digest


def remove_stage(stage: Path, run: Path) -> dict:
    # Recursive cleanup is confined to the fresh, task-owned staging directory.
    if stage.is_symlink() or stage.resolve().parent != run.resolve() or stage.name != "staged-project":
        raise ValueError("Refusing cleanup outside the owned bundle staging directory")
    size = sum(p.stat().st_size for p in stage.rglob("*") if p.is_file())
    shutil.rmtree(stage)
    return {"path": str(stage), "bytes_removed": size, "removed": not stage.exists()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game")
    parser.add_argument("--output", type=Path, required=True, help="New private directory on F:")
    parser.add_argument("--bundletool", type=Path, required=True)
    parser.add_argument("--gradle-cache", type=Path, required=True)
    signing = parser.add_mutually_exclusive_group(required=True)
    signing.add_argument("--unsigned", action="store_true")
    signing.add_argument("--signing-env", type=Path)
    parser.add_argument("--expect-signer-sha256")
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("The pinned bundle toolchain currently requires a Windows host")
    root = REPO_ROOT.resolve()
    project = discover_projects(root).get(args.game)
    if project is None:
        parser.error("Unknown game")
    run = args.output.expanduser().resolve()
    if os.name == "nt" and run.drive.casefold() != "f:":
        parser.error("Gradle staging may exceed1GB; use the workspace's F: build volume")
    if os.name == "nt" and args.gradle_cache.resolve().drive.casefold() != "f:":
        parser.error("Use the F: volume for the shared Gradle cache")
    if run == root or run.is_relative_to(project) or project.is_relative_to(run):
        parser.error("Bundle output must be outside the game source")
    if run.exists():
        parser.error("Bundle output must be a fresh directory")
    config = read_config(root)
    if config["godot_version"] != "4.7.2.stable.official.ed1daf0bf":
        parser.error("This template/signing pipeline is pinned to qualified Godot4.7.2")
    godot = resolve_godot(config, None, root)
    if file_sha256(args.bundletool) != BUNDLETOOL_SHA256:
        parser.error("bundletool1.18.3 checksum mismatch")
    expected_signer = (args.expect_signer_sha256 or "").replace(":", "").lower()
    if args.signing_env and not re.fullmatch(r"[0-9a-f]{64}", expected_signer):
        parser.error("Signing requires an explicit approved certificate SHA256")
    if args.unsigned and args.expect_signer_sha256:
        parser.error("Unsigned bundles do not have a signing certificate")
    original = tracked_sources(root, project)
    preset_text = (project / "export_presets.cfg").read_text(encoding="utf-8")
    section, expected = preset_info(preset_text, config["export_preset"])
    used_text = bundle_preset(preset_text, section)
    env = tool_environment(config)
    env.update(GRADLE_USER_HOME=str(args.gradle_cache.resolve()),
               GRADLE_OPTS="-Dorg.gradle.workers.max=2 -Dorg.gradle.daemon=false")
    run.mkdir(parents=True, exist_ok=False)
    stage = run / "staged-project"
    stage.mkdir()
    record = {"schema_version": 1, "result": "failed", "game": args.game,
              "scope": "Local offline AAB only; no upload, Play account/SDK, installed Android or cloud sync acceptance.",
              "git_revision": git_revision(root), "pipeline_sha256": file_sha256(Path(__file__)),
              "source_before": original, "commands": [], "unsigned": args.unsigned,
              "bundletool_sha256": BUNDLETOOL_SHA256,
              "helper_sha256": {str(p.relative_to(root)): file_sha256(p) for p in
                                [root / "scripts/portfolio.py", root / "scripts/install_toolchain.py",
                                 root / "scripts/owned_process.py", root / "toolchain.json"]}}
    def save_record():
        (run / "manifest.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    def command(label: str, argv: list[str], child_env: dict | None = None, engine: bool = False):
        log = run / (label + ".log")
        entry = {"label": label, "argv": argv, "state": "admitted",
                 "started_utc": datetime.now(timezone.utc).isoformat(), "timeout_seconds": 900,
                 "process_tree_stopped": False}
        record["commands"].append(entry)
        save_record()
        stderr_log = run / (label + ".stderr.log")
        with log.open("wb") as output, stderr_log.open("wb") as errors:
            outcome = run_owned(argv, env=child_env or env, log=output, stderr_log=errors)
        entry.update(outcome, state="timed_out" if outcome["timed_out"] else "returned")
        text = log.read_text(encoding="utf-8", errors="replace")
        combined = text + "\n" + stderr_log.read_text(encoding="utf-8", errors="replace")
        markers = [line for line in combined.splitlines() if any(word in line for word in MARKERS)]
        entry.update(engine_markers=markers if engine else [],
                     raw_warning_lines=[line for line in combined.splitlines() if "warning" in line.lower()])
        save_record()
        print(label, outcome["exit_code"], flush=True)
        if (outcome["exit_code"] != 0 or outcome["timed_out"] or outcome.get("process_error")
                or not outcome["process_tree_stopped"] or engine and markers):
            raise ValueError(label + " failed; raw log and owned process outcome retained")
        return text
    try:
        for relative, digest in original.items():
            destination = stage / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / relative, destination)
            if file_sha256(destination) != digest:
                raise ValueError("Staged source copy differs")
        (stage / "export_presets.cfg").write_text(used_text, encoding="utf-8", newline="\n")
        staged_before = staged_sources(stage)
        (run / "preset.used.cfg").write_text(used_text, encoding="utf-8", newline="\n")
        record["staged_source_before"] = staged_before
        record["template"] = prepare_template(config, stage)
        actual_version = command("engine-version", [godot, "--version"], engine=True).strip()
        if actual_version != config["godot_version"]:
            raise ValueError("Godot executable differs from the pinned version")
        command("import", [godot, "--headless", "--audio-driver", "Dummy", "--path",
                           str(stage), "--editor", "--import"], engine=True)
        unsigned = run / (args.game + "-unsigned.aab")
        command("bundle", [godot, "--headless", "--audio-driver", "Dummy", "--path",
                           str(stage), "--export-release", config["export_preset"],
                           str(unsigned)], engine=True)
        # Check all game bytes before admitting private-key use.
        record["staged_source_after_export"] = staged_sources(stage)
        record["source_after_export"] = tracked_sources(root, project)
        if record["staged_source_after_export"] != staged_before or record["source_after_export"] != original:
            raise ValueError("Game source changed before signing")
        artifact = unsigned
        if args.signing_env:
            values = read_signing_env(args.signing_env)
            sign_env = env.copy()
            sign_env["GAME_BUNDLE_PASSWORD"] = values["GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"]
            keystore = values["GODOT_ANDROID_KEYSTORE_RELEASE_PATH"]
            alias = values["GODOT_ANDROID_KEYSTORE_RELEASE_USER"]
            artifact = run / (args.game + ".aab")
            java_bin = Path(config["java_home"]) / "bin"
            command("sign", [str(java_bin / "jarsigner.exe"), "-J-Duser.language=en",
                             "-J-Duser.country=US", "-keystore", keystore,
                             "-storepass:env", "GAME_BUNDLE_PASSWORD", "-keypass:env",
                             "GAME_BUNDLE_PASSWORD", "-signedjar", str(artifact),
                             str(unsigned), alias], sign_env)
            verified = command("signature", [str(java_bin / "jarsigner.exe"),
                               "-J-Duser.language=en", "-J-Duser.country=US",
                               "-verify", "-strict", "-verbose", "-certs",
                               "-keystore", keystore, "-storepass:env",
                               "GAME_BUNDLE_PASSWORD", str(artifact), alias], sign_env)
            if "jar verified." not in verified:
                raise ValueError("jarsigner did not verify every required entry")
            cert = command("certificate", [str(java_bin / "keytool.exe"),
                           "-J-Duser.language=en", "-J-Duser.country=US",
                           "-printcert", "-jarfile", str(artifact)])
            actual_signer = signer_digest(cert)
            if actual_signer != expected_signer:
                raise ValueError("AAB signer differs from the approved certificate")
            record["signer_certificate_sha256"] = actual_signer
        java = str(Path(config["java_home"]) / "bin/java.exe")
        base = [java, "-jar", str(args.bundletool.resolve())]
        command("validate", base + ["validate", "--bundle=" + str(artifact)])
        xml = command("manifest", base + ["dump", "manifest", "--module=base",
                                         "--bundle=" + str(artifact)])
        with zipfile.ZipFile(artifact) as archive:
            names = archive.namelist()
            if len(names) != len(set(names)) or archive.testzip() is not None:
                raise ValueError("Duplicate or corrupt AAB members")
            if "base/manifest/AndroidManifest.xml" not in names or "BundleConfig.pb" not in names:
                raise ValueError("Artifact is not an Android App Bundle")
            blocks = [name for name in names if re.fullmatch(r"META-INF/[^/]+\.(RSA|DSA|EC)", name, re.I)]
            if len(blocks) != (0 if args.unsigned else 1):
                raise ValueError("Unexpected AAB signature block count")
        record["bundle_inspection"] = inspect_manifest(xml, names, expected)
        record["staged_source_after"] = staged_sources(stage)
        if record["staged_source_after"] != staged_before:
            raise ValueError("Staged game source changed during import/export")
        record["source_after"] = tracked_sources(root, project)
        if record["source_after"] != original:
            raise ValueError("Original game source changed during bundling")
        record["source_unchanged"] = True
        record["artifact"] = {"path": str(artifact), "bytes": artifact.stat().st_size,
                              "sha256": file_sha256(artifact)}
        if artifact != unsigned:
            record["verified_unsigned_intermediate_removed"] = {
                "sha256": file_sha256(unsigned), "bytes": unsigned.stat().st_size}
            unsigned.unlink()
        record["result"] = "built"
    except (OSError, ValueError, subprocess.SubprocessError, zipfile.BadZipFile, ET.ParseError) as error:
        record["failure"] = str(error)
        print("ERROR:", error, file=sys.stderr)
    finally:
        try:
            record["source_after"] = tracked_sources(root, project)
            record["source_unchanged"] = record["source_after"] == original
            if not record["source_unchanged"]:
                record["result"] = "failed"
                record["failure"] = "Original source stability gate failed"
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            record["source_unchanged"] = False
            record["result"] = "failed"
            record["source_gate_error"] = str(error)
        try:
            if not all(entry.get("process_tree_stopped", False) for entry in record["commands"]):
                raise ValueError("Process-tree lifetime unresolved; staged project retained")
            record["cleanup"] = remove_stage(stage, run)
        except (OSError, ValueError) as error:
            record["result"] = "failed"
            record["cleanup_error"] = str(error)
        record["files"] = {p.name: {"sha256": file_sha256(p), "bytes": p.stat().st_size}
                           for p in run.iterdir() if p.is_file() and p.name != "manifest.json"}
        (run / "manifest.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        print(run / "manifest.json", flush=True)
    return 0 if record["result"] == "built" else 1


if __name__ == "__main__":
    raise SystemExit(main())
