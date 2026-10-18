"""Pinned genuine app-written inputs; no generation of campaign state or clears."""
import hashlib
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
PLAN = PROJECT / "tests/production-plan.json"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def envelope(code):
    data = json.loads(code)
    assert hashlib.sha256(data["payload"].encode()).hexdigest() == data["sha256"]
    return json.loads(data["payload"])


def resolve(key):
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    entry = plan["earned_sources"][key]
    index = PROJECT / plan["acceptance_index"]
    assert sha(index) == plan["acceptance_index_sha256"]
    accepted = json.loads(index.read_text(encoding="utf-8"))["accepted_receipts"]
    assert any(row["path"] == entry["receipt"] and row["sha256"] == entry["receipt_sha256"] for row in accepted)
    path = (PROJECT / entry["path"]).resolve()
    assert path.is_relative_to((PROJECT / ".artifacts").resolve())
    receipt_path = PROJECT / entry["receipt"]
    assert sha(receipt_path) == entry["receipt_sha256"]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    assert receipt["passed"] and receipt["source_unchanged"]
    assert sha(path) == entry["sha256"]
    relative = path.relative_to(receipt_path.parent).as_posix()
    assert any(row["path"] == relative and row["sha256"] == entry["sha256"] for row in receipt["artifacts"])
    code = path.read_text(encoding="utf-8")
    if entry.get("slot_key") is not None:
        code = json.loads(code)[entry["slot_key"]]
    assert hashlib.sha256(code.encode()).hexdigest() == entry["selected_envelope_sha256"]
    packet = envelope(code)
    assert packet["revision"] == entry["revision"]
    return code, packet, entry


def summarize(packet, seconds=40):
    state = packet["state"]
    campaign = state["schema"] == 2
    definition = state.get("definition", {})
    roster = definition.get("roster", [])
    live = sorted({roster[int(e["id"])]["role"] if campaign else ("raider" if e["id"] < 10 else "armor") for e in state["enemies"]})
    future = sorted({e["role"] for e in roster[int(state["spawned"]):] if e["t"] <= state["time"] + seconds})
    return {"schema": state["schema"], "stage": definition.get("stage"), "region": definition.get("region"),
            "phase": state["phase"], "simulation_seconds": state["time"], "live_roles": live,
            "live_enemies": len(state["enemies"]), "next_window_seconds": seconds, "scheduled_roles_in_next_window": future,
            "clears": len(packet.get("campaign", {}).get("clears", [])),
            "limits": "Source inventory and scheduled roles, not observed new rendered motion or review acceptance"}


if __name__ == "__main__":
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    for key in plan["earned_sources"]:
        _, packet, _ = resolve(key)
        print(key, json.dumps(summarize(packet)))
