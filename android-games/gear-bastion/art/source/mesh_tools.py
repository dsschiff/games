"""Original-asset mesh/export helpers adapted from the accepted Frontline pipeline.
No Frontline model geometry is reused. Blender CPU export only.
"""
import math
import hashlib
import json
import struct
from pathlib import Path

import bpy

OUT = Path(__file__).resolve().parents[1] / "models"
OUT.mkdir(parents=True, exist_ok=True)
MATERIALS = {}
PARTS = []


def material(name, color, roughness=0.78, metallic=0):
    if name in MATERIALS:
        return MATERIALS[name]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    MATERIALS[name] = mat
    return mat


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    PARTS.clear()


def finish(obj, name, mat, bone=None):
    obj.name = name
    obj.data.materials.append(mat)
    if bone:
        PARTS.append((obj, bone))
    return obj


def block(name, location, scale, mat, bevel=0.055, bone=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Sculpted edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        modifier = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, name, mat, bone)


def oval(name, location, scale, mat, bone=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return finish(obj, name, mat, bone)


def cylinder(name, location, radius, depth, mat, bone=None, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    if rotation:
        obj.rotation_euler = rotation
    bevel = obj.modifiers.new("Soft rim", "BEVEL")
    bevel.width = min(0.025, depth / 5)
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return finish(obj, name, mat, bone)


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB",
                              export_yup=True, export_animations=False,
                              export_skins=True, export_extras=True, export_texcoords=False)
    canonicalize(OUT / (name + ".glb"))


def canonicalize(path):
    """Remove sub-micrometer parallel-normal float noise from Blender exports.

    Weighted-normal/bevel evaluation can differ in last float bits across fresh
    CPU processes. Quantize float accessors to 10 micrometers/1e-5 units, keeping
    original topology, indices, material groups, transforms and rigid weights.
    """
    raw = bytearray(path.read_bytes())
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    binary_start = 28 + length
    widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    for accessor in doc["accessors"]:
        if accessor["componentType"] != 5126 or "bufferView" not in accessor:
            continue
        view = doc["bufferViews"][accessor["bufferView"]]
        width = widths[accessor["type"]]
        stride = view.get("byteStride", width * 4)
        start = binary_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        for row in range(accessor["count"]):
            for col in range(width):
                offset = start + row * stride + col * 4
                value = round(struct.unpack_from("<f", raw, offset)[0], 5)
                struct.pack_into("<f", raw, offset, 0.0 if value == 0 else value)
    # Recompute vertex normals in stable triangle order from quantized geometry.
    # Blender's parallel weighted-normal accumulation otherwise changes final
    # float bits at quantization boundaries. Exported split indices retain hard
    # edges; deterministic area weights retain sculpted bevel face transitions.
    def start_and_stride(index, width):
        accessor = doc["accessors"][index]
        view = doc["bufferViews"][accessor["bufferView"]]
        start = binary_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        return accessor, start, view.get("byteStride", width)

    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            if "NORMAL" not in primitive["attributes"]:
                continue
            pa, ps, stride = start_and_stride(primitive["attributes"]["POSITION"], 12)
            positions = [struct.unpack_from("<3f", raw, ps + i * stride) for i in range(pa["count"])]
            ia = doc["accessors"][primitive["indices"]]
            fmt, size = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}[ia["componentType"]]
            _, ins, instride = start_and_stride(primitive["indices"], size)
            indices = [struct.unpack_from("<" + fmt, raw, ins + i * instride)[0] for i in range(ia["count"])]
            normals = [[0.0, 0.0, 0.0] for _ in positions]
            for i in range(0, len(indices), 3):
                a, b, c = [positions[indices[i + j]] for j in range(3)]
                u = [b[j] - a[j] for j in range(3)]
                v = [c[j] - a[j] for j in range(3)]
                cross = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
                for j in range(3):
                    for axis in range(3):
                        normals[indices[i + j]][axis] += cross[axis]
            _, ns, nstride = start_and_stride(primitive["attributes"]["NORMAL"], 12)
            for i, normal in enumerate(normals):
                length = math.sqrt(sum(x * x for x in normal))
                if length > 1e-15:
                    values = [round(x / length, 6) for x in normal]
                    struct.pack_into("<3f", raw, ns + i * nstride, *values)
            # glTF's dedup/triangulation encounter order can vary even when all
            # authored surfaces are equal. Canonical vertex records and oriented
            # triangles make that ordering irrelevant without changing topology.
            streams = []
            components = {5121: 1, 5123: 2, 5125: 4, 5126: 4}
            for semantic, index in sorted(primitive["attributes"].items()):
                accessor = doc["accessors"][index]
                width = widths[accessor["type"]] * components[accessor["componentType"]]
                _, start, step = start_and_stride(index, width)
                values = [bytes(raw[start + i * step:start + i * step + width]) for i in range(accessor["count"])]
                streams.append((start, step, width, values))
            records = [b"".join(stream[3][i] for stream in streams) for i in range(pa["count"])]
            order = sorted(range(len(records)), key=lambda i: records[i])
            first = {}
            remap = {}
            for new, old in enumerate(order):
                remap[old] = first.setdefault(records[old], new)
            for start, step, width, values in streams:
                for new, old in enumerate(order):
                    raw[start + new * step:start + new * step + width] = values[old]
            triangles = []
            for i in range(0, len(indices), 3):
                tri = tuple(remap[x] for x in indices[i:i + 3])
                triangles.append(min(tri, tri[1:] + tri[:1], tri[2:] + tri[:2]))
            for i, value in enumerate(x for tri in sorted(triangles) for x in tri):
                struct.pack_into("<" + fmt, raw, ins + i * instride, value)
    path.write_bytes(raw)


