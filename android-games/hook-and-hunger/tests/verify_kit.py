"""Inspect original GLB structure/hashes without importing or rendering anything."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    manifest = json.loads((ROOT / "art/manifest.json").read_text())
    generator = (ROOT / "art/source/build_assets.py").read_bytes()
    errors, rows = [], []
    if hashlib.sha256(generator.replace(b"\r\n", b"\n")).hexdigest() != manifest["generator_lf_sha256"]:
        errors.append("generator canonical source hash")
    for record in manifest["assets"]:
        raw = (ROOT / "art/models" / (record["name"] + ".glb")).read_bytes()
        magic, version, length = struct.unpack_from("<4sII", raw)
        n = struct.unpack_from("<I", raw, 12)[0]
        doc = json.loads(raw[20:20 + n])
        checks = {"hash": hashlib.sha256(raw).hexdigest() == record["sha256"],
                  "valid_glb": magic == b"glTF" and version == 2 and length == len(raw),
                  "named_meshes": all("Mesh" in m["name"] for m in doc["meshes"]),
                  "materials": len(doc.get("materials", [])) > 0}
        if record["name"].startswith("actor_"):
            checks["skin"] = len(doc.get("skins", [])) == 1 and len(doc["skins"][0]["joints"]) == 18
            checks["weights"] = all("JOINTS_0" in p["attributes"] and "WEIGHTS_0" in p["attributes"] for m in doc["meshes"] for p in m["primitives"])
            checks["animation"] = len(doc.get("animations", [])) == 1 and len(doc["animations"][0]["channels"]) > 0
            names = {node.get("name") for node in doc["nodes"]}
            checks["chain_bone"] = "ChainSocket" in names
        if record["name"].startswith("weapon_"):
            names = {node.get("name") for node in doc["nodes"]}
            checks["authored_sockets"] = {"ChainEye", "ContactTip"}.issubset(names)
        triangles = sum(doc["accessors"][p["indices"]]["count"] // 3 for m in doc["meshes"] for p in m["primitives"])
        rows.append({"name": record["name"], "checks": checks, "triangles": triangles, "sha256": record["sha256"]})
        errors.extend(record["name"] + ": " + key for key, value in checks.items() if not value)
    report = {"passed": not errors and len(rows) == 35, "errors": errors, "assets": rows,
              "scope": "CPU structural/hash/skin/channel/socket checks; no visual or motion acceptance"}
    if args.output:
        target = args.output.resolve()
        if not target.is_relative_to((ROOT / ".artifacts").resolve()):
            parser.error("Output must stay under this game's ignored .artifacts")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passed": report["passed"], "assets": len(rows), "errors": errors}, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
