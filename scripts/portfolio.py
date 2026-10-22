"""Reproducible local Godot tests and debug or release-signed APK builds (Python stdlib only)."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

REPO_ROOT = Path(__file__).resolve().parents[1]


def discover_projects(root: Path) -> dict[str, Path]:
    """Use actual projects, including probes; reject ambiguous short selectors."""
    projects = {}
    home = root / "android-games"
    if home.exists():
        for project in sorted(home.rglob("project.godot")):
            if any(part.startswith(".") for part in project.relative_to(home).parts):
                continue
            slug = project.parent.name
            if slug in projects:
                raise ValueError(f"Ambiguous project basename: {slug}")
            projects[slug] = project.parent.resolve()
    return projects


def read_config(root: Path, config_path: str | None = None) -> dict:
    path = Path(config_path).expanduser() if config_path else root / "toolchain.json"
    if not path.is_absolute():
        path = root / path
    config = json.loads(path.read_text(encoding="utf-8"))
    home = os.environ.get("GAME_TOOLCHAIN_ROOT", config["toolchain_root"])
    for key in ("godot", "android_sdk", "java_home", "blender"):
        if key in config:
            config[key] = config[key].replace("{toolchain_root}", home)
    config["toolchain_root"] = home
    return config


def resolve_godot(config: dict, override: str | None, root: Path) -> str:
    value = override or os.environ.get("GODOT") or config["godot"]
    executable = shutil.which(value) if "/" not in value and "\\" not in value else None
    if executable:
        return str(Path(executable).resolve())
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = root / path
    if not path.is_file():
        raise FileNotFoundError(f"Godot executable missing: {path}; supply --godot")
    return str(path.resolve())


def tool_environment(config: dict) -> dict[str, str]:
    env = os.environ.copy()
    home = Path(config["toolchain_root"])
    env.update(JAVA_HOME=config["java_home"], ANDROID_HOME=config["android_sdk"],
               ANDROID_SDK_ROOT=config["android_sdk"],
               ANDROID_USER_HOME=str(home / "android-user"),
               ANDROID_AVD_HOME=str(home / "avd"))
    # Godot otherwise uses the process-wide user's AppData for saves/logs.
    env["APPDATA"] = str(home / "runtime" / "AppData" / "Roaming")
    env["LOCALAPPDATA"] = str(home / "runtime" / "AppData" / "Local")
    env["TMP"] = env["TEMP"] = str(home / "tmp")
    env["JAVA_TOOL_OPTIONS"] = (env.get("JAVA_TOOL_OPTIONS", "") +
                                ' -Djava.io.tmpdir="' + str(home / "tmp") + '"').strip()
    for key in ("ANDROID_USER_HOME", "ANDROID_AVD_HOME", "APPDATA", "LOCALAPPDATA", "TEMP"):
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    return env


def run_command(command: list[str], log: Path, env: dict | None = None,
                timeout: int = 300) -> int:
    log.parent.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", errors="replace",
                                env=env, timeout=timeout, check=False)
        output = result.stdout
        code = result.returncode
    except subprocess.TimeoutExpired as error:
        output = f"TIMEOUT after {timeout}s\n{error.stdout or ''}"
        code = 124
    except OSError as error:
        output = str(error)
        code = 127
    log.write_text(output, encoding="utf-8")
    print(output, end="" if output.endswith("\n") else "\n")
    # Some Godot script/runtime errors log errors while returning zero.
    if code == 0 and any(marker in output for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR:")):
        return 1
    return code


def file_sha256(path: Path) -> str:
    """Stream a file through SHA-256 in 1 MiB blocks and return the hex digest."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def artifact_record(path: Path, root: Path) -> dict:
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"Artifact absent or empty: {path}")
    return {"path": path.resolve().relative_to(root.resolve()).as_posix(),
            "bytes": path.stat().st_size, "sha256": file_sha256(path)}


def parse_apk_metadata(badging: str) -> dict:
    package = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
    if not package:
        raise ValueError("aapt did not report a valid APK package")
    permissions = re.findall(r"uses-permission[^:]*: name='([^']+)'", badging)
    return {"package": package[1], "version_code": package[2], "version_name": package[3],
            "permissions": permissions, "internet_permission": "android.permission.INTERNET" in permissions}


RELEASE_SIGNING_KEYS = {
    "ANDROID_RELEASE_KEYSTORE": "GODOT_ANDROID_KEYSTORE_RELEASE_PATH",
    "ANDROID_RELEASE_KEY_ALIAS": "GODOT_ANDROID_KEYSTORE_RELEASE_USER",
    "ANDROID_RELEASE_KEYSTORE_PASSWORD": "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD",
}


def read_signing_env(path: Path) -> dict[str, str]:
    """Map a private KEY=VALUE signing file to Godot's release-keystore variables.

    The file lives outside Git (see android-games/RELEASE.md). Values are only placed in the
    child-process environment; they are never written to manifests or logs.
    """
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    missing = [key for key in RELEASE_SIGNING_KEYS if not values.get(key)]
    if missing:
        raise ValueError("Release signing file lacks: " + ", ".join(missing))
    if not Path(values["ANDROID_RELEASE_KEYSTORE"]).is_file():
        raise ValueError("Release keystore file is missing")
    return {godot: values[key] for key, godot in RELEASE_SIGNING_KEYS.items()}


def parse_signer_digest(output: str) -> str | None:
    match = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)", output)
    return match[1].lower() if match else None


def inspect_apk(apk: Path, config: dict, env: dict, run_dir: Path) -> dict:
    tools = Path(config["android_sdk"]) / "build-tools" / config["android_build_tools"]
    with zipfile.ZipFile(apk) as archive:
        if "AndroidManifest.xml" not in archive.namelist() or "classes.dex" not in archive.namelist():
            raise ValueError("APK lacks Android manifest or executable classes")
    code = run_command([str(tools / "apksigner.bat"), "verify", "--verbose", "--print-certs", str(apk)],
                       run_dir / "signature.log", env)
    if code:
        raise ValueError("APK signature verification failed")
    signer_digest = parse_signer_digest((run_dir / "signature.log").read_text(encoding="utf-8"))
    code = run_command([str(tools / "aapt.exe"), "dump", "badging", str(apk)],
                       run_dir / "apk-inspection.log", env)
    if code:
        raise ValueError("APK metadata inspection failed")
    metadata = parse_apk_metadata((run_dir / "apk-inspection.log").read_text(encoding="utf-8"))
    metadata["signature_verified"] = True
    metadata["signer_certificate_sha256"] = signer_digest
    metadata["debuggable"] = "application-debuggable" in (run_dir / "apk-inspection.log").read_text(encoding="utf-8")
    if metadata["internet_permission"]:
        raise ValueError("Offline portfolio APK unexpectedly requests INTERNET permission")
    return metadata


def validate_manifest(manifest: dict, root: Path) -> bool:
    """Check evidence against current bytes; do not accept absent or escaped files."""
    if manifest.get("schema_version") != 1 or manifest.get("result") != "built":
        return False
    record = manifest.get("artifact", {})
    try:
        artifact = (root / record["path"]).resolve()
        artifact.relative_to(root.resolve())
        return artifact_record(artifact, root) == record
    except (KeyError, OSError, ValueError):
        return False


def git_revision(root: Path) -> str | None:
    result = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"],
                            capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else None


def source_fingerprint(project: Path) -> str:
    """Fingerprint source bytes and names, excluding generated/runtime directories."""
    digest = hashlib.sha256()
    ignored = {".godot", ".artifacts", "build", "builds", "cache", "user_data", "userdata"}
    for path in sorted(project.rglob("*")):
        relative = path.relative_to(project)
        if not path.is_file() or any(part in ignored for part in relative.parts):
            continue
        if path.suffix.lower() in {".apk", ".aab", ".log", ".tmp"}:
            continue
        digest.update(relative.as_posix().encode("utf-8") + b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def source_status(root: Path, project: Path) -> list[str]:
    result = subprocess.run(["git", "-C", str(root), "status", "--porcelain", "--",
                             project.relative_to(root).as_posix()],
                            capture_output=True, text=True, check=False)
    return result.stdout.splitlines() if result.returncode == 0 else ["git status unavailable"]


def suite_command(command: list[str], log: Path, env: dict, timeout: int) -> int:
    code = run_command(command, log, env, timeout)
    if code == 0 and "SUITE_COMPLETE: PASS" not in log.read_text(encoding="utf-8"):
        print("Incomplete test evidence: SUITE_COMPLETE: PASS marker absent")
        return 1
    return code


def record_source_stability(manifest: dict, before: str, after: str):
    manifest.update(project_source_sha256=before, project_source_sha256_after=after,
                    source_unchanged=before == after)
    if before != after:
        manifest["result"] = "failed"
        manifest["failure_reason"] = "Project source changed while command ran"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("status", "test", "build"))
    parser.add_argument("games", nargs="*", help="Project directory basenames; default all discovered")
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--config")
    parser.add_argument("--godot")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--release", action="store_true",
                        help="build: export a release APK signed with the private release key")
    parser.add_argument("--signing-env", type=Path,
                        default=os.environ.get("ANDROID_RELEASE_SIGNING_ENV"),
                        help="private KEY=VALUE file with ANDROID_RELEASE_* entries (or ANDROID_RELEASE_SIGNING_ENV)")
    parser.add_argument("--expect-signer-sha256",
                        help="release: fail unless the APK signer certificate SHA-256 matches")
    args = parser.parse_args(argv)
    root = args.root.expanduser().resolve()
    try:
        projects = discover_projects(root)
        config = read_config(root, args.config)
        selected = args.games or list(projects)
        unknown = set(selected) - projects.keys()
        if unknown:
            raise ValueError("Unknown/unimplemented project(s): " + ", ".join(sorted(unknown)))
        if args.command == "status":
            print(json.dumps({"projects": [{"game": slug,
                "path": path.relative_to(root).as_posix(),
                "tests_present": (path / "tests/run_tests.gd").is_file(),
                "export_presets_present": (path / "export_presets.cfg").is_file()}
                for slug, path in projects.items()], "toolchain": config}, indent=2))
            return 0
        if not selected:
            print("SKIPPED: no project.godot files exist; no tests/builds ran.")
            return 2
        if args.release and args.command != "build":
            raise ValueError("--release applies only to build")
        signing = {}
        if args.release:
            if not args.signing_env:
                raise ValueError("--release needs --signing-env or ANDROID_RELEASE_SIGNING_ENV")
            signing = read_signing_env(Path(args.signing_env).expanduser())
        godot = resolve_godot(config, args.godot, root)
        env = tool_environment(config)
        version = subprocess.run([godot, "--version"], capture_output=True, text=True,
                                 env=env, timeout=30, check=True).stdout.strip()
        if version != config["godot_version"]:
            raise ValueError(f"Godot version mismatch: {version}; expected {config['godot_version']}")
        failed = False
        skipped = False
        for slug in selected:
            project = projects[slug]
            out = root / ".artifacts" / slug
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
            run_dir = out / stamp
            run_dir.mkdir(parents=True, exist_ok=True)
            run_env = env.copy()
            # Keep each test's user:// independent of prior runs and player saves.
            if args.command == "test":
                run_env["APPDATA"] = str(run_dir / "userdata")
                Path(run_env["APPDATA"]).mkdir()
            run_env.update(signing)
            manifest = {"schema_version": 1, "game": slug, "command": args.command,
                        "godot_version": version, "started_utc": stamp,
                        "git_revision": git_revision(root), "project": project.relative_to(root).as_posix(),
                        "build_type": ("release" if args.release else "debug") if args.command == "build" else None}
            manifest["pipeline_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
            manifest["toolchain_config_sha256"] = hashlib.sha256(
                json.dumps(config, sort_keys=True).encode("utf-8")).hexdigest()
            source_before = source_fingerprint(project)
            if args.command == "test" and not (project / "tests/run_tests.gd").is_file():
                print(f"SKIPPED {slug}: tests/run_tests.gd missing")
                manifest["result"] = "skipped"
                skipped = True
            else:
                # Import first so resource/class caches exist on clean checkouts.
                command = [godot, "--headless", "--path", str(project), "--editor", "--import"]
                code = run_command(command, run_dir / "import.log", run_env, args.timeout)
                manifest["import_exit_code"] = code
                if code == 0:
                    command = [godot, "--headless", "--path", str(project)]
                    if args.command == "test":
                        command += ["-s", "tests/run_tests.gd"]
                    else:
                        export = "--export-release" if args.release else "--export-debug"
                        command += [export, config["export_preset"], str(run_dir / f"{slug}.apk")]
                    runner = suite_command if args.command == "test" else run_command
                    code = runner(command, run_dir / f"{args.command}.log", run_env, args.timeout)
                    if args.command == "test":
                        manifest["rules_exit_code"] = code
                        playthrough = project / "tests/playthrough.gd"
                        if code == 0 and playthrough.is_file():
                            play_command = [godot, "--headless", "--path", str(project),
                                            "--fixed-fps", "60", "-s", "tests/playthrough.gd"]
                            code = suite_command(play_command, run_dir / "playthrough.log", run_env, args.timeout)
                            manifest.update(playthrough_argv=play_command, playthrough_exit_code=code)
                        elif code == 0:
                            manifest["playthrough_result"] = "missing"
                            skipped = True
                manifest.update(argv=command, exit_code=code,
                                result="passed" if args.command == "test" and code == 0 else "failed")
                if manifest.get("playthrough_result") == "missing":
                    manifest["result"] = "rules_only"
                if args.command == "build" and code == 0:
                    try:
                        manifest["artifact"] = artifact_record(run_dir / f"{slug}.apk", root)
                        inspection = inspect_apk(run_dir / f"{slug}.apk", config, run_env, run_dir)
                        manifest["apk_inspection"] = inspection
                        if args.release and inspection["debuggable"]:
                            raise ValueError("Release APK is unexpectedly debuggable")
                        expected = (args.expect_signer_sha256 or "").replace(":", "").lower()
                        if expected and inspection["signer_certificate_sha256"] != expected:
                            raise ValueError("Release APK signer certificate does not match --expect-signer-sha256")
                        manifest["result"] = "built"
                    except ValueError as error:
                        print(error)
                        manifest["result"] = "failed"
                failed = failed or manifest["result"] == "failed"
            record_source_stability(manifest, source_before, source_fingerprint(project))
            failed = failed or manifest["result"] == "failed"
            manifest["project_git_status"] = source_status(root, project)
            manifest["project_dirty"] = bool(manifest["project_git_status"])
            print(f"{slug}: {manifest['result']}")
            (run_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
            print(f"Evidence: {run_dir.relative_to(root).as_posix()}/manifest.json")
        return 1 if failed else 2 if skipped else 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
