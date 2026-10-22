"""Original Tower Trials coastal-watch kit; Blender 4.5.14, CPU export only.

No downloaded geometry, images or libraries. Blender -Y (toward the viewer)
becomes Godot +Z; Blender +Z up becomes Godot +Y. One Blender unit is 100
design pixels of the 600x1066 board, so a room front is 1.8 wide.
Every asset exports as one opaque "Palette" mesh plus an optional unshaded
"Glow" mesh, colours carried as vertex colours.
Run: blender --background --factory-startup --threads 2 --python this_file
Helper and export/canonicalize pattern adapted from this portfolio's Dead Run
generator (same author).
"""
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
for argument in sys.argv:
    if argument.startswith("--output="):
        ROOT = Path(argument.split("=", 1)[1]).resolve()
OUT = ROOT / "models"
OUT.mkdir(parents=True, exist_ok=True)
RECORDS, MATS = [], {}
bpy.context.scene.render.engine = "BLENDER_WORKBENCH"

GLOW = {"Lantern", "Window glow", "Eye glow", "Moon", "Beacon"}
M = {n: c for n, c in [
    ("Stone", "c9bfa8"), ("Stone dark", "8f8a7c"), ("Mortar", "a39b88"), ("Plaster", "f1e4c6"),
    ("Slate", "4d6c7c"), ("Slate dark", "36505f"), ("Timber", "8a5f3c"), ("Iron", "2e3a44"),
    ("Teal", "3fc7a8"), ("Teal dark", "2a8f7c"), ("Gold", "ffd17d"), ("Brass", "d9a54a"),
    ("Cloak", "32baa2"), ("Skin", "f0c58c"), ("Ink", "102c42"), ("Boot", "3a2c24"),
    ("Spirit", "c9e4f0"), ("Spirit shade", "8fb3c9"), ("Rock", "4c6470"), ("Rock dark", "35495a"),
    ("Moss", "4f8a6e"), ("Cottage wall", "d8cdb4"), ("Cottage roof", "8a4a3c"),
    ("Lantern", "ffe08a"), ("Window glow", "ffd98a"), ("Eye glow", "aef6ff"), ("Moon", "f2ead2"),
    ("Beacon", "fff1b0"), ("Red band", "c8463e"), ("White band", "f3efe4")]}


def material(name):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        shader = m.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Roughness"].default_value = .8
        attr = m.node_tree.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        m.node_tree.links.new(attr.outputs["Color"], shader.inputs["Base Color"])
        MATS[name] = m
    return MATS[name]


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes,):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)


def finish(obj, name, mat):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    source = obj.data
    verts = [tuple(v.co) for v in source.vertices]
    faces, smooth = [], []
    for face in source.polygons:
        ids = list(face.vertices)
        start = ids.index(min(ids))
        ids = ids[start:] + ids[:start]
        for i in range(1, len(ids) - 1):
            faces.append((ids[0], ids[i], ids[i + 1]))
            smooth.append(face.use_smooth)
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for f, s in zip(mesh.polygons, smooth):
        f.use_smooth = s
    obj.data = mesh
    bpy.data.meshes.remove(source)
    obj.name = name
    rgb = tuple(int(M[mat][i:i + 2], 16) / 255 for i in (0, 2, 4))
    layer = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for item in layer.data:
        item.color = (*rgb, 1)  # glTF COLOR_0 then carries the sRGB values Godot expects
    obj.data.materials.append(material("Glow" if mat in GLOW else "Palette"))
    return obj


def block(name, at, size, mat, bevel=.03, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new("Rim", "BEVEL")
    mod.width = min(bevel, min(size) * .4)
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if rot:
        obj.rotation_euler = rot
    return finish(obj, name, mat)


def oval(name, at, size, mat, seg=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=at)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for f in obj.data.polygons:
        f.use_smooth = True
    return finish(obj, name, mat)


def cyl(name, at, radius, height, mat, top=None, verts=12, rot=None, smooth=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius,
                                    radius2=radius if top is None else top,
                                    depth=height, location=at)
    obj = bpy.context.object
    if smooth:
        for f in obj.data.polygons:
            f.use_smooth = len(f.vertices) == 4
    if rot:
        obj.rotation_euler = rot
    return finish(obj, name, mat)


def prism(name, at, width, height, depth, mat):
    # Gabled roof: triangle in X/Z extruded along Y.
    x, y, z = at
    w, d = width / 2, depth / 2
    verts = [(x - w, y - d, z), (x + w, y - d, z), (x, y - d, z + height),
             (x - w, y + d, z), (x + w, y + d, z), (x, y + d, z + height)]
    faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (0, 2, 5, 3)]
    mesh = bpy.data.meshes.new(name + "Src")
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat)


# ------------------------------------------------------------------ models
def room():
    # Front face at y=0 facing the viewer; body recedes to +Y. 1.8 x 1.0.
    block("Body", (0, .34, 0), (1.8, .68, 1.0), "Stone", .05)
    block("Panel", (0, -.01, .06), (1.56, .04, .72), "Plaster", .02)
    block("Sill", (0, -.04, -.43), (1.86, .12, .1), "Stone dark", .03)
    block("Lintel", (0, -.03, .46), (1.86, .1, .08), "Stone dark", .03)
    for side in (-1, 1):
        block("Pilaster", (side * .84, -.03, 0), (.1, .08, .92), "Mortar", .02)
        cyl("Bracket", (side * .7, -.07, -.43), .04, .1, "Iron", verts=8, rot=(math.pi / 2, 0, 0))
    for i in range(5):
        block("Course", (0, .36, -.5 + i * .25), (1.82, .62, .02), "Mortar", .005)


def tower_column():
    # Shaft for one tower column, unit tall from z=0, scaled at runtime.
    block("Shaft", (0, .5, .5), (1.68, .9, 1.0), "Stone dark", .04)
    for i in range(8):
        block("Band", (0, .04, .06 + i * .125), (1.7, .04, .015), "Mortar", .004)
    for side in (-1, 1):
        block("Buttress", (side * .88, .45, .5), (.14, .8, 1.0), "Rock", .03)


def tower_roof():
    prism("Roof", (0, .5, 0), 1.98, .52, 1.1, "Slate")
    block("Eave", (0, .5, 0), (2.02, 1.14, .06), "Slate dark", .02)
    cyl("Spire", (0, .5, .68), .03, .36, "Iron", verts=8)
    oval("Finial", (0, .5, .88), (.06, .06, .06), "Brass", 8, 6)


def home_floor():
    # Unit-tall floor of the player's watch, 1.16 wide.
    block("Wall", (0, .3, .5), (1.16, .6, .98), "Cottage wall", .03)
    block("Door", (0, -.01, .42), (.3, .04, .44), "Ink", .02)
    block("Ledge", (0, -.03, .02), (1.2, .1, .05), "Stone dark", .02)
    for side in (-1, 1):
        block("Window", (side * .38, -.015, .52), (.16, .03, .2), "Window glow", .01)
        block("Shutter", (side * .38, -.03, .52), (.2, .02, .03), "Timber", .005)
    oval("Bell", (.38, -.05, .82), (.05, .05, .05), "Gold", 8, 6)


def home_roof():
    prism("Roof", (0, .3, 0), 1.34, .42, .7, "Teal")
    block("Eave", (0, .3, 0), (1.36, .74, .05), "Teal dark", .02)
    cyl("Pole", (0, .3, .6), .02, .5, "Iron", verts=8)
    prism("Pennant", (.12, .3, .66), .24, .18, .02, "Gold")
    oval("Lantern", (0, .1, .3), (.07, .07, .09), "Lantern", 10, 6)


def courier():
    # Little lantern courier, about 0.62 tall, origin at the feet.
    cyl("Cloak", (0, 0, .2), .17, .4, "Cloak", top=.08, verts=14)
    oval("Head", (0, 0, .48), (.12, .12, .12), "Skin", 12, 8)
    block("Visor", (0, -.1, .48), (.22, .04, .05), "Ink", .01)
    cyl("Hood", (0, .02, .58), .13, .1, "Teal dark", top=.03, verts=12)
    for side in (-1, 1):
        block("Boot", (side * .07, 0, .02), (.08, .12, .05), "Boot", .015)
    cyl("Staff", (.2, 0, .3), .015, .56, "Timber", verts=6)
    oval("Lantern", (.2, -.02, .6), (.05, .05, .06), "Lantern", 10, 6)
    block("Cap", (.2, -.02, .67), (.07, .07, .02), "Brass", .005)


def spirit():
    # Lost chime spirit: bell-shaped wisp, ~0.36 tall, origin at the base.
    cyl("Shroud", (0, 0, .12), .15, .24, "Spirit", top=.1, verts=14)
    oval("Crown", (0, 0, .25), (.12, .11, .11), "Spirit", 12, 8)
    oval("Face", (0, -.07, .25), (.08, .04, .07), "Ink", 10, 6)
    for side in (-1, 1):
        oval("Eye", (side * .035, -.1, .26), (.016, .01, .018), "Eye glow", 6, 4)
    oval("Clapper", (0, 0, -.02), (.05, .05, .05), "Spirit shade", 8, 6)
    for side in (-1, 1):
        cyl("Wisp", (side * .15, 0, .06), .03, .12, "Spirit shade", top=.005, verts=6, rot=(0, side * .6, 0))


def cliff():
    # Backdrop headland, about 6 wide and 2.6 tall.
    for i, (x, w, h) in enumerate([(-2.4, 1.6, 1.6), (-1.1, 1.8, 2.3), (.4, 2.0, 2.6), (1.9, 1.6, 1.9), (3.0, 1.2, 1.1)]):
        block("Rock%d" % i, (x, .4, h / 2), (w, .9, h), "Rock" if i % 2 else "Rock dark", .12)
    block("Turf", (.0, .4, 2.6), (2.0, .92, .08), "Moss", .03)
    block("Turf2", (-1.1, .4, 2.3), (1.8, .92, .07), "Moss", .03)


def lighthouse():
    cyl("Base", (0, 0, .2), .42, .4, "Stone dark", verts=16)
    for i in range(4):
        cyl("Band%d" % i, (0, 0, .5 + i * .4), .34 - i * .03, .4, "Red band" if i % 2 == 0 else "White band", top=.31 - i * .03, verts=16)
    cyl("Gallery", (0, 0, 2.12), .34, .06, "Iron", verts=16)
    cyl("Lamp", (0, 0, 2.3), .18, .3, "Beacon", verts=12)
    cyl("Cap", (0, 0, 2.55), .24, .22, "Slate", top=.02, verts=12)


def cottage():
    block("Wall", (0, .35, .38), (.9, .7, .76), "Cottage wall", .03)
    prism("Roof", (0, .35, .76), 1.04, .44, .78, "Cottage roof")
    block("Window", (-.2, -.01, .42), (.16, .02, .18), "Window glow", .01)
    block("Door", (.2, -.01, .25), (.18, .02, .36), "Timber", .01)


def moon():
    oval("Disc", (0, 0, 0), (.36, .1, .36), "Moon", 18, 10)


def canonicalize(path):
    raw = bytearray(path.read_bytes())
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    base = 28 + length
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            accessor = doc["accessors"][primitive["indices"]]
            view = doc["bufferViews"][accessor["bufferView"]]
            fmt, width = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}[accessor["componentType"]]
            start = base + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", width)
            indices = [struct.unpack_from("<" + fmt, raw, start + i * stride)[0] for i in range(accessor["count"])]
            triangles = []
            for i in range(0, len(indices), 3):
                triangle = indices[i:i + 3]
                first = triangle.index(min(triangle))
                triangles.append(triangle[first:] + triangle[:first])
            for i, value in enumerate(v for triangle in sorted(triangles) for v in triangle):
                struct.pack_into("<" + fmt, raw, start + i * stride, value)
            if "NORMAL" in primitive["attributes"]:
                pa = doc["accessors"][primitive["attributes"]["POSITION"]]
                pv = doc["bufferViews"][pa["bufferView"]]
                ps = base + pv.get("byteOffset", 0) + pa.get("byteOffset", 0)
                positions = [struct.unpack_from("<3f", raw, ps + i * pv.get("byteStride", 12)) for i in range(pa["count"])]
                normals = [[0., 0., 0.] for _ in positions]
                for triangle in sorted(triangles):
                    a, b, c = [positions[i] for i in triangle]
                    u, v = [b[j] - a[j] for j in range(3)], [c[j] - a[j] for j in range(3)]
                    cross = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
                    for i in triangle:
                        for axis in range(3):
                            normals[i][axis] += cross[axis]
                na = doc["accessors"][primitive["attributes"]["NORMAL"]]
                nv = doc["bufferViews"][na["bufferView"]]
                ns = base + nv.get("byteOffset", 0) + na.get("byteOffset", 0)
                for i, normal in enumerate(normals):
                    length = math.sqrt(sum(x*x for x in normal))
                    values = [round(x / length, 6) if x else 0 for x in normal] if length else [0, 1, 0]
                    struct.pack_into("<3f", raw, ns + i * nv.get("byteStride", 12), *values)
    path.write_bytes(raw)


def export(name):
    groups = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH":
            groups.setdefault(obj.data.materials[0].name, []).append(obj)
    for mat, objects in sorted(groups.items()):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        objects[0].name = name + "_" + mat
        objects[0].data.name = objects[0].name + "Mesh"
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(c) for obj in bpy.context.scene.objects if obj.type == "MESH" for c in obj.bound_box]
    bpy.ops.object.select_all(action="SELECT")
    path = OUT / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_yup=True,
                              export_animations=False, export_skins=False,
                              export_extras=True, export_texcoords=False,
                              export_vertex_color="ACTIVE", export_active_vertex_color_when_no_material=True)
    canonicalize(path)
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    RECORDS.append({"name": name, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
                    "meshes": len(doc.get("meshes", [])),
                    "triangles": sum(doc["accessors"][p["indices"]]["count"] // 3 for m in doc["meshes"] for p in m["primitives"]),
                    "bounds_blender": {"min": [round(min(p[i] for p in points), 5) for i in range(3)],
                                       "max": [round(max(p[i] for p in points), 5) for i in range(3)]}})


ASSETS = [("room", room), ("tower_column", tower_column), ("tower_roof", tower_roof),
          ("home_floor", home_floor), ("home_roof", home_roof), ("courier", courier),
          ("spirit", spirit), ("cliff", cliff), ("lighthouse", lighthouse),
          ("cottage", cottage), ("moon", moon)]
for asset_name, build in ASSETS:
    clear()
    build()
    export(asset_name)
(ROOT / "manifest.json").write_text(json.dumps({"generator": "source/build_assets.py",
    "generator_lf_sha256": hashlib.sha256(Path(__file__).read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
    "blender": bpy.app.version_string, "rendered": False, "original": True,
    "coordinates": "Blender -Y toward viewer +Z up; glTF +Z toward viewer +Y up; 1 unit = 100 design px",
    "assets": RECORDS}, indent=2) + "\n")
print("TOWER_KIT_COMPLETE", len(RECORDS))
