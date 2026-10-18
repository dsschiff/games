"""Freeze exact accepted campaign execution; indexes/documents are not runtime sources."""
import argparse
import hashlib
import json
from pathlib import Path

from run_campaign import PROJECT, sources

METADATA = {
    "tests/freeze_campaign.py": "Evidence indexer amended after execution to verify receipts and retain history; never loaded by the game.",
    "export_presets.cfg": "Only add CAMPAIGN_CHECKPOINT.json to the Android export exclusion; no gameplay/export-option change.",
}


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("runs", nargs="+", type=Path)
    args = parser.parse_args()
    current = sources()
    lf = {name: hashlib.sha256((PROJECT / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest() for name in current}
    summaries = []
    artifacts = []
    png_count = 0
    accepted = set()
    from PIL import Image

    for value in args.runs:
        run = value.resolve()
        assert run.is_relative_to((PROJECT / ".artifacts").resolve())
        receipt = json.loads((run / "receipt.json").read_text())
        executed = json.loads((run / "source-hashes.json").read_text())
        assert receipt["passed"] and receipt["source_unchanged"], run
        assert executed.keys() == current.keys(), run
        deltas = [name for name in current if executed[name] != current[name]]
        assert set(deltas).issubset(METADATA), (run, deltas)
        if "export_presets.cfg" in deltas:
            old = (run / "executed-source/export_presets.cfg").read_text()
            new = (PROJECT / "export_presets.cfg").read_text()
            assert new.replace(",CAMPAIGN_CHECKPOINT.json", "") == old
        for name, digest in executed.items():
            assert sha(run / "executed-source" / name) == digest, (run, name)
        for item in receipt["artifacts"]:
            path = run / item["path"]
            assert path.stat().st_size == item["bytes"] and sha(path) == item["sha256"], path
        accepted.add(run)
        summary = {"path": str(run.relative_to(PROJECT)).replace("\\", "/"), "scope": receipt["scope"], "executed_raw_source_sha256": executed, "executed_lf_source_sha256": json.loads((run / "source-hashes-lf.json").read_text()), "source_unchanged": True, "post_execution_metadata_deltas": [{"path": name, "executed_sha256": executed[name], "current_sha256": current[name], "reason": METADATA[name]} for name in deltas]}
        for name in ["rules-report.json", "input-report.json", "cold-report.json", "legacy-report.json", "clipboard-report.json"]:
            if (run / name).is_file():
                report = json.loads((run / name).read_text())
                assert report["failures"] == 0
                summary["checks"] = report["checks"]
                if "simulated_arc_seconds" in report:
                    summary["simulated_arc_seconds"] = report["simulated_arc_seconds"]
        summaries.append(summary)
        for path in sorted(run.rglob("*")):
            if path.is_file():
                if path.suffix == ".png":
                    with Image.open(path) as frame:
                        frame.load()
                        assert frame.width > 0 and frame.height > 0
                    png_count += 1
                artifacts.append({"path": str(path.relative_to(PROJECT)).replace("\\", "/"), "bytes": path.stat().st_size, "sha256": sha(path)})
    history = []
    for path in sorted((PROJECT / ".artifacts").glob("*/receipt.json")):
        if path.parent.resolve() in accepted:
            continue
        record = json.loads(path.read_text())
        if "scope" not in record or "source_unchanged" not in record:
            continue
        history.append({"path": str(path.parent.relative_to(PROJECT)).replace("\\", "/"), "classification": "Retained development/superseded evidence; never counted as final acceptance", "passed": record.get("passed"), "source_unchanged": record.get("source_unchanged"), "bindings": [{"path": name, "sha256": sha(path.parent / name)} for name in ["receipt.json", "source-hashes.json", "source-hashes-lf.json"] if (path.parent / name).is_file()]})
    result = {"checkpoint": "frontline-foundry-complete-campaign-0.2.0-code2", "base": "bd2bfd9d1758aa8cc7b3f6235884502ae3070a83", "branch": "codex/frontline-foundry", "engine": "4.7.2.stable.official.ed1daf0bf", "raw_source_sha256": current, "lf_source_sha256": lf, "lf_tree_sha256": hashlib.sha256(json.dumps(lf, sort_keys=True, separators=(",", ":")).encode()).hexdigest(), "runs": summaries, "artifacts": artifacts, "source_scope": "Executable/test/resource files and sidecars; documentation and receipt/index files excluded from recursive source binding", "limits": ["Builder verification only; independent coordinator/Astra/native acceptance pending", "8x engine time scale for full desktop routes, 1x continuous clips; simulated time is not human duration/fun", "Movies start from explicit genuinely input-earned paused boundaries; separate clips are not one continuous campaign", "No APK export/install, ADB, global settings, shared-file edits, pushes or public release", "Authentic Android code1 rev213 update and all physical Fold7/IME/FPS/safe areas/sound/fun remain coordinator/phone gates"]}
    runtime = {name: value for name, value in lf.items() if name not in METADATA}
    result.update({"runtime_lf_tree_sha256": hashlib.sha256(json.dumps(runtime, sort_keys=True, separators=(",", ":")).encode()).hexdigest(), "metadata_exceptions": METADATA, "retained_history": history, "verification": {"original_receipt_artifact_hashes": "all matched", "executed_source_archive_hashes": "all matched", "png_files_fully_decoded": png_count, "movie_decode_evidence": "Each accepted movie has movie-probe.json with full_decode_passed=true"}})
    for item in summaries:
        if item["scope"] == "movie":
            probe = json.loads((PROJECT / item["path"] / "movie-probe.json").read_text())
            assert probe["full_decode_passed"] is True
    (PROJECT / "CAMPAIGN_CHECKPOINT.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"sources": len(current), "artifacts": len(artifacts), "runs": [{k: v for k, v in item.items() if k not in {"executed_raw_source_sha256", "executed_lf_source_sha256"}} for item in summaries], "lf_tree_sha256": result["lf_tree_sha256"]}, indent=2))


if __name__ == "__main__":
    main()
