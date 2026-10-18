"""Bind accepted first-loop evidence without copying portable settings or tools."""
import argparse
import hashlib
import json
from pathlib import Path

from run_desktop import PROJECT, sources


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("runs", nargs="+", type=Path)
    args = parser.parse_args()
    raw = sources()
    normalized = {name: digest((PROJECT / name).read_bytes().replace(b"\r\n", b"\n")) for name in raw}
    metadata_only = {"README.md", "tests/freeze_checkpoint.py"}
    bound = []
    summaries = []
    for supplied in args.runs:
        run = supplied.resolve()
        if not run.is_relative_to((PROJECT / ".artifacts").resolve()):
            parser.error("evidence must be inside this game's ignored .artifacts")
        receipt = json.loads((run / "receipt.json").read_text())
        assert receipt["passed"] and receipt["source_unchanged"], run
        executed = json.loads((run / "source-hashes.json").read_text())
        differences = [name for name in sorted(set(executed) | set(raw)) if executed.get(name) != raw.get(name)]
        assert set(differences) <= metadata_only, (run, differences)
        summary = {"path": str(run.relative_to(PROJECT)).replace("\\", "/"), "scope": receipt["scope"]}
        summary["executed_raw_source_sha256"] = executed
        summary["executed_lf_source_sha256"] = json.loads((run / "source-hashes-lf.json").read_text())
        summary["runtime_and_input_test_bytes_match_checkpoint"] = True
        summary["post_execution_metadata_deltas"] = [{"path": name, "executed_sha256": executed.get(name), "checkpoint_sha256": raw.get(name), "reason": "README toolchain path correction" if name == "README.md" else "Receipt/index packaging utility; never loaded by game or engine test"} for name in differences]
        for report in ["rules-report.json", "input-report.json", "restore-report.json"]:
            if (run / report).exists():
                result = json.loads((run / report).read_text())
                assert result["failures"] == 0
                summary["checks"] = result["checks"]
        summaries.append(summary)
        for p in sorted(run.rglob("*")):
            if p.is_file():
                bound.append({"path": str(p.relative_to(PROJECT)).replace("\\", "/"), "bytes": p.stat().st_size, "sha256": digest(p.read_bytes())})
    import_dir = PROJECT / ".artifacts" / "portable-import"
    for name in ["import.log", "import-second.log", "official-template-manifest.txt", "import-proof.json"]:
        p = import_dir / name
        if p.exists():
            bound.append({"path": str(p.relative_to(PROJECT)).replace("\\", "/"), "bytes": p.stat().st_size, "sha256": digest(p.read_bytes())})
    checkpoint = {
        "checkpoint": "frontline-foundry-first-loop-0.1.0-code1",
        "activation_base": "d771247958d550e4cd4a345ff7db3c310d9ab677",
        "branch": "codex/frontline-foundry",
        "status": "Desktop first loop verified; independent review and all Android/physical gates open",
        "engine": "4.7.2.stable.official.ed1daf0bf",
        "raw_source_sha256": raw,
        "lf_source_sha256": normalized,
        "non_runtime_metadata_sources": sorted(metadata_only),
        "lf_tree_sha256": digest(json.dumps(normalized, sort_keys=True, separators=(",", ":")).encode()),
        "runs": summaries,
        "artifacts": bound,
        "excluded_private_runtime": [".artifacts/portable-import/editor_data", ".artifacts/portable-import/*.exe"],
        "limits": ["First playable only; no complete campaign", "Desktop input/clipboard are not Android or physical-phone evidence", "No APK export/install, ADB, shared-file edits, pushes or public release", "Top General-to-Top Force creative mapping remains qualified", "No human fun, phone FPS, audible phone sound, IME, safe area or physical fold acceptance"]}
    (PROJECT / "CHECKPOINT.json").write_text(json.dumps(checkpoint, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"sources": len(raw), "artifacts": len(bound), "runs": summaries, "lf_tree_sha256": checkpoint["lf_tree_sha256"]}, indent=2))


if __name__ == "__main__":
    main()
