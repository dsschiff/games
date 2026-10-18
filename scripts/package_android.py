"""Copy the six verified personal candidates into a new local delivery folder."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import html
import json
from pathlib import Path
import shutil

from portfolio import REPO_ROOT, source_fingerprint


def checksum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_text_lf_fingerprint(project: Path) -> str:
    """Allow Git text-line-ending differences while retaining binary bytes."""
    digest = hashlib.sha256()
    ignored = {".godot", ".artifacts", "build", "builds", "cache", "user_data", "userdata"}
    text = {".gd", ".py", ".md", ".json", ".cfg", ".godot", ".tscn", ".uid", ".svg", ".import"}
    for path in sorted(project.rglob("*")):
        relative = path.relative_to(project)
        if not path.is_file() or any(part in ignored for part in relative.parts):
            continue
        if path.suffix.lower() in {".apk", ".aab", ".log", ".tmp"}:
            continue
        raw = path.read_bytes()
        if path.suffix.lower() in text:
            raw = raw.replace(b"\r\n", b"\n")
        digest.update(relative.as_posix().encode("utf-8") + b"\0")
        digest.update(hashlib.sha256(raw).digest())
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True,
                        help="New private local folder; existing folders are never overwritten")
    args = parser.parse_args()
    delivery_path = REPO_ROOT / "android-games/delivery.json"
    delivery = json.loads(delivery_path.read_text(encoding="utf-8"))
    games = delivery["games"]
    expected = {"gear-bastion", "tower-trials", "hook-and-hunger",
                "hearthguard", "frontline-foundry", "dead-run"}
    if len(games) != 6 or {game["slug"] for game in games} != expected:
        raise ValueError("Delivery must contain exactly the six portfolio games")
    records = []
    for game in games:
        if not game.get("ready_for_phone_testing",
                        game["state"] == "software_candidate_ready_for_phone_testing"):
            raise ValueError(f"Candidate is not ready for phone testing: {game['slug']}")
        project = REPO_ROOT / "android-games" / game["slug"]
        current_raw = source_fingerprint(project)
        if source_text_lf_fingerprint(project) != game.get("source_text_lf_sha256"):
            raise ValueError(f"Current source differs from candidate: {game['slug']}")
        source = Path(game["apk"])
        if source.suffix.lower() != ".apk" or checksum(source) != game["apk_sha256"]:
            raise ValueError(f"Candidate APK mismatch: {game['slug']}")
        records.append({"slug": game["slug"], "version": game["version"],
                        "version_code": game["version_code"], "state": game["state"],
                        "file": f"{game['slug']}-{game['version']}.apk",
                        "bytes": source.stat().st_size, "sha256": game["apk_sha256"],
                        "source_sha256": game["source_sha256"],
                        "packaging_checkout_raw_sha256": current_raw,
                        "source_text_lf_sha256": game["source_text_lf_sha256"],
                        "physical_phone_tested": game["physical_phone_tested"]})
    output = args.output.expanduser().resolve()
    if output.exists():
        raise FileExistsError(f"Use a new delivery folder: {output}")
    output.mkdir(parents=True)
    for game, record in zip(games, records):
        target = output / record["file"]
        shutil.copyfile(game["apk"], target)
        if checksum(target) != record["sha256"] or target.stat().st_size != record["bytes"]:
            raise ValueError(f"Copied APK failed verification: {target}")
    shutil.copyfile(REPO_ROOT / "android-games/INSTALL.md", output / "INSTALL.md")
    manifest = {"created_utc": datetime.now(timezone.utc).isoformat(),
                "scope": "Private personal builds; software candidates for physical phone testing",
                "source_delivery_sha256": checksum(delivery_path),
                "install_guide_sha256": checksum(output / "INSTALL.md"),
                "games": records}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (output / "SHA256SUMS.txt").write_text("".join(
        f"{row['sha256']}  {row['file']}\n" for row in records), encoding="utf-8")
    links = "\n".join(f'<li><a href="{html.escape(row["file"])}">'
                      f'{html.escape(row["slug"].replace("-", " ").title())} '
                      f'{html.escape(row["version"])}</a></li>' for row in records)
    (output / "index.html").write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Personal Android games</title><style>body{font:18px system-ui;'
        'max-width:45rem;margin:2rem auto;padding:0 1rem;line-height:1.6}li{margin:1rem 0}</style>'
        '<h1>Personal Android games</h1><p>Six standalone offline apps. '
        'No ads, purchases or accounts.</p><ul>' + links + '</ul>'
        '<p>Copy an APK to your phone, open it from Files and allow installation '
        'for that app if Android asks. Install updates over the existing app to keep saves.</p>'
        '<p><a href="INSTALL.md">Controls and installation guide</a> · '
        '<a href="SHA256SUMS.txt">Checksums</a></p>'
        '<p>These builds still need physical Fold7 testing: touch, folding, safe areas, '
        'on-screen keyboard, sound, performance and full-session play.</p></html>\n', encoding="utf-8")
    print(json.dumps({"output": str(output), "APKs": len(records),
                      "every_copied_APK_verified": True,
                      "manifest_sha256": checksum(output / "manifest.json")}, indent=2))


if __name__ == "__main__":
    main()
