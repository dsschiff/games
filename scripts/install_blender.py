"""Install checksum-pinned portable Blender for original game asset authoring."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request
import zipfile

from portfolio import REPO_ROOT, read_config

VERSION = "4.5.14"
NAME = f"blender-{VERSION}-windows-x64.zip"
SHA256 = "b9533d2397ac1984db4466fb23a7a4649391cca93f6e84209f9bcc60d071c8b9"
BASE = "https://ftp.halifax.rwth-aachen.de/blender/release/Blender4.5/"


def install(home: Path) -> Path:
    archive_path = home / "downloads" / NAME
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    if not archive_path.exists():
        partial = archive_path.with_suffix(".zip.partial")
        request = urllib.request.Request(BASE + NAME, headers={"User-Agent": "Mozilla/5.0"})
        print(f"Downloading {NAME}", flush=True)
        with urllib.request.urlopen(request, timeout=60) as response, partial.open("wb") as output:
            while block := response.read(1024 * 1024):
                output.write(block)
        partial.replace(archive_path)
    with archive_path.open("rb") as stream:
        actual = hashlib.file_digest(stream, "sha256").hexdigest()
    if actual != SHA256:
        raise ValueError(f"Checksum mismatch for {archive_path}: {actual}")
    destination = (home / "blender" / VERSION).resolve()
    receipt_path = destination / "install-receipt.json"
    executable = destination / f"blender-{VERSION}-windows-x64" / "blender.exe"
    if not receipt_path.exists():
        if destination.exists():
            raise FileExistsError(f"Unreceipted install directory; preserve and inspect: {destination}")
        with zipfile.ZipFile(archive_path) as archive:
            for member in archive.infolist():
                target = (destination / member.filename).resolve()
                target.relative_to(destination)
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with archive.open(member) as source, target.open("xb") as output:
                        while block := source.read(1024 * 1024):
                            output.write(block)
        receipt_path.write_text(json.dumps({
            "version": VERSION, "archive": NAME, "sha256": SHA256, "url": BASE + NAME,
            "manifest_sources": [BASE + f"blender-{VERSION}.sha256",
                f"https://mirrors.dotsrc.org/blender/release/Blender4.5/blender-{VERSION}.sha256"],
            "executable": executable.as_posix(),
        }, indent=2) + "\n", encoding="utf-8")
    result = subprocess.run([str(executable), "--background", "--factory-startup", "--version"],
                            capture_output=True, text=True, check=True)
    if f"Blender {VERSION}" not in result.stdout:
        raise RuntimeError(f"Unexpected Blender version: {result.stdout}")
    print(result.stdout.splitlines()[0], flush=True)
    print(executable, flush=True)
    return executable


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    args = parser.parse_args()
    install(Path(read_config(args.root.resolve())["toolchain_root"]))


if __name__ == "__main__":
    main()
