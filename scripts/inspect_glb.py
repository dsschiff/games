"""Report structural GLB evidence; this does not establish artistic quality."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct


def inspect(path: Path) -> dict:
    raw = path.read_bytes()
    if len(raw) < 20:
        raise ValueError("Truncated GLB header")
    magic, version, length = struct.unpack_from("<III", raw)
    if magic != 0x46546C67 or version != 2 or length != len(raw):
        raise ValueError("Invalid GLB2 header or file length")
    offset, document = 12, None
    while offset < length:
        if offset + 8 > length:
            raise ValueError("Truncated GLB chunk header")
        size, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        if size % 4 or offset + size > length:
            raise ValueError("Invalid GLB chunk length")
        if kind == 0x4E4F534A:
            if document is not None:
                raise ValueError("Multiple GLB JSON chunks")
            document = json.loads(raw[offset:offset + size])
        offset += size
    if document is None or document.get("asset", {}).get("version") != "2.0":
        raise ValueError("Missing glTF2 document")
    accessors = document.get("accessors", [])
    nodes = document.get("nodes", [])
    animations = []
    for animation in document.get("animations", []):
        targets, durations = set(), []
        samplers = animation.get("samplers", [])
        for channel in animation.get("channels", []):
            target = channel.get("target", {})
            if "node" in target:
                targets.add(target["node"])
            sampler = samplers[channel["sampler"]]
            times = accessors[sampler["input"]]
            if "max" in times:
                durations.append(times["max"][0])
        animations.append({"name": animation.get("name", ""),
                           "channels": len(animation.get("channels", [])),
                           "target_nodes": [nodes[i].get("name", str(i)) for i in sorted(targets)],
                           "duration_seconds": max(durations, default=None)})
    meshes = []
    for mesh in document.get("meshes", []):
        primitives = []
        for primitive in mesh.get("primitives", []):
            attributes = primitive.get("attributes", {})
            count = accessors[primitive["indices"]]["count"] if "indices" in primitive else accessors[attributes["POSITION"]]["count"]
            mode = primitive.get("mode", 4)
            primitives.append({"vertices": accessors[attributes["POSITION"]]["count"],
                               "triangles": count // 3 if mode == 4 else None,
                               "mode": mode, "skinned_attributes": all(k in attributes for k in ("JOINTS_0", "WEIGHTS_0"))})
        meshes.append({"name": mesh.get("name", ""), "primitives": primitives})
    return {"path": path.as_posix(), "sha256": hashlib.sha256(raw).hexdigest(),
            "bytes": len(raw), "generator": document["asset"].get("generator"),
            "node_count": len(nodes), "meshes": meshes,
            "materials": [m.get("name", "") for m in document.get("materials", [])],
            "skins": [{"name": s.get("name", ""), "joint_count": len(s["joints"])} for s in document.get("skins", [])],
            "animations": animations,
            "limits": "Structural inventory only. Requires source provenance and real rendered motion review."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", type=Path, nargs="+")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = json.dumps([inspect(path) for path in args.files], indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    else:
        print(report, end="")


if __name__ == "__main__":
    main()
