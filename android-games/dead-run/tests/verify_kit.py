"""Inspect the original Dead Run GLB kit structure/hashes without importing or rendering."""
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1] / "art"


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    generator = (ROOT / "source/build_assets.py").read_bytes()
    errors, rows = [], []
    if hashlib.sha256(generator.replace(b"\r\n", b"\n")).hexdigest() != manifest["generator_lf_sha256"]:
        errors.append("generator canonical source hash")
    names = {r["name"] for r in manifest["assets"]}
    on_disk = {p.stem for p in (ROOT / "models").glob("*.glb")}
    if names != on_disk:
        errors.append("manifest/disk asset set differs: %s" % sorted(names ^ on_disk))
    for record in manifest["assets"]:
        raw = (ROOT / "models" / (record["name"] + ".glb")).read_bytes()
        magic, version, length = struct.unpack_from("<4sII", raw)
        n = struct.unpack_from("<I", raw, 12)[0]
        doc = json.loads(raw[20:20 + n])
        materials = [m["name"] for m in doc.get("materials", [])]
        checks = {"hash": hashlib.sha256(raw).hexdigest() == record["sha256"],
                  "valid_glb": magic == b"glTF" and version == 2 and length == len(raw),
                  "palette_materials": set(materials) <= {"Palette", "Glow"} and "Palette" in materials or materials == ["Glow"],
                  "vertex_colors": all("COLOR_0" in p["attributes"] for m in doc["meshes"] for p in m["primitives"]),
                  "draw_calls_le_2": sum(len(m["primitives"]) for m in doc["meshes"]) <= 2}
        skinned = record["name"].startswith("actor_") or record["name"] in ("boss_matron", "boss_ram")
        if skinned:
            nodes = {node.get("name") for node in doc["nodes"]}
            checks["skin"] = len(doc.get("skins", [])) == 1 and len(doc["skins"][0]["joints"]) == 19
            checks["weights"] = all("JOINTS_0" in p["attributes"] and "WEIGHTS_0" in p["attributes"] for m in doc["meshes"] for p in m["primitives"])
            checks["animation"] = len(doc.get("animations", [])) == 1 and len(doc["animations"][0]["channels"]) > 0
            checks["joints"] = {"Torso", "ThighL", "ShinR", "ArmL", "ForearmR", "Weapon", "Muzzle"} <= nodes
        triangles = sum(doc["accessors"][p["indices"]]["count"] // 3 for m in doc["meshes"] for p in m["primitives"])
        rows.append({"name": record["name"], "triangles": triangles, "checks": checks})
        errors.extend(record["name"] + ": " + k for k, v in checks.items() if not v)
    skinned_count = sum(1 for r in rows if "skin" in r["checks"])
    passed = not errors and len(rows) == len(manifest["assets"]) and skinned_count == 9
    print(json.dumps({"passed": passed, "assets": len(rows), "skinned": skinned_count,
                      "max_triangles": max(r["triangles"] for r in rows), "errors": errors}, indent=2))
    print("SUITE_COMPLETE:", "PASS" if passed else "FAIL")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
