"""Narrow CRLF/LF index regression; never modifies any index or saved artifact."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

from production_sources import PROJECT, PLAN, acceptance_index_identity, resolve


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", type=Path, help="Optional read-only second checkout's actual tracked index")
    args = parser.parse_args()
    plan = json.loads(PLAN.read_bytes())
    raw = (PROJECT / plan["acceptance_index"]).read_bytes()
    lf = raw.replace(b"\r\n", b"\n")
    crlf = lf.replace(b"\n", b"\r\n")
    first = acceptance_index_identity(plan, lf)
    second = acceptance_index_identity(plan, crlf)
    assert first["text_lf_sha256"] == second["text_lf_sha256"] == plan["acceptance_index_lf_sha256"]
    assert first["actual_raw_sha256"] != second["actual_raw_sha256"]
    assert first["recorded_original_raw_sha256"] == second["recorded_original_raw_sha256"] == plan["acceptance_index_original_raw_sha256"]
    rejected = []
    for name, changed in [("trailing-whitespace", lf + b" "), ("bare-CR", lf.replace(b"\n", b"\r", 1)), ("content", lf.replace(b"accepted_receipts", b"changed_receipts", 1))]:
        try:
            acceptance_index_identity(plan, changed)
        except AssertionError:
            rejected.append(name)
        else:
            raise AssertionError("Accepted non-line-ending change: " + name)
    entries = {}
    for key in plan["earned_sources"]:
        code, packet, entry = resolve(key)
        assert hashlib.sha256(code.encode("utf-8")).hexdigest() == entry["selected_envelope_sha256"]
        entries[key] = {"revision": packet["revision"], "selected_envelope_sha256": entry["selected_envelope_sha256"]}
    other = acceptance_index_identity(plan, args.index.read_bytes()) if args.index else None
    source_hashes = {name: hashlib.sha256((PROJECT / "tests" / name).read_bytes()).hexdigest()
                     for name in ["production_sources.py", "production-plan.json", "run_production.py", "source_index_checks.py"]}
    result = {"passed": True, "checked_source_sha256": source_hashes, "scope": "LF/CRLF-only tracked-index identity and11 exact original artifact/envelope resolutions; no Godot/full campaign/render",
              "lf": first, "crlf": second, "rejected": rejected, "other_checkout": str(args.index) if args.index else None,
              "other_checkout_identity": other, "exact_sources": entries}
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = PROJECT / ".artifacts" / ("source-index-portability-" + stamp + ".json")
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"passed": True, "exact_sources": len(entries), "rejected_changes": rejected, "other_checkout_identity": other, "report": str(output)}, indent=2))


if __name__ == "__main__":
    main()
