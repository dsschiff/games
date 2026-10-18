"""Original Hearthguard sculpture kit. Blender 4.5.14 CPU export, no rendering.

Blender coordinates: +Y forward, +Z up. glTF/Godot: -Z forward, +Y up.
All forms, materials, rigid skin weights and architectural details originate here.
Run blender --background --factory-startup --threads 2 --python build_assets.py.
"""
import hashlib
import json
import math
import struct
from pathlib import Path

import bpy

OUT = Path(__file__).resolve().parents[1] / "models"
OUT.mkdir(parents=True, exist_ok=True)
PARTS = []
MATS = {}
RECORDS = []


def mat(name, hex_color, metallic=0.0):
    if name not in MATS:
        color = tuple(int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*color, 1)
        m.use_nodes = True
        shader = m.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*color, 1)
        shader.inputs["Roughness"].default_value = .76
        shader.inputs["Metallic"].default_value = metallic
        MATS[name] = m
    return MATS[name]


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    # Explicitly remove orphan datablocks. Names never inherit another asset's suffix.
    for collection in (bpy.data.meshes, bpy.data.armatures):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)
    PARTS.clear()


def finish(obj, name, material, bone=None):
    # Blender's parallel n-gon tessellation can select different diagonals. Bake a
    # deterministic convex-face fan before weights exist; all authored faces here
    # are convex bevels, sphere quads or cylinder caps.
    source = obj.data
    vertices = [tuple(v.co) for v in source.vertices]
    triangles, smoothing = [], []
    for face in source.polygons:
        indices = list(face.vertices)
        start = indices.index(min(indices))
        indices = indices[start:] + indices[:start]
        for i in range(1, len(indices) - 1):
            triangles.append((indices[0], indices[i], indices[i + 1]))
            smoothing.append(face.use_smooth)
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], triangles)
    mesh.update()
    for face, smooth in zip(mesh.polygons, smoothing):
        face.use_smooth = smooth
    obj.data = mesh
    if source.users == 0:
        bpy.data.meshes.remove(source)
    obj.name = name
    obj.data.name = name + "Mesh"
    obj.data.materials.append(material)
    if bone:
        PARTS.append((obj, bone))
    return obj


def block(name, p, size, material, bevel=.04, bone=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Hand softened edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, material, bone)


def oval(name, p, size, material, bone=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1, location=p)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for face in obj.data.polygons:
        face.use_smooth = True
    return finish(obj, name, material, bone)


def cylinder(name, p, radius, depth, material, bone=None, tilt=None, top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=radius,
                                  radius2=radius if top is None else top,
                                  depth=depth, location=p)
    obj = bpy.context.object
    if tilt:
        obj.rotation_euler = tilt
    bevel = obj.modifiers.new("Rounded rim", "BEVEL")
    bevel.width = min(.025, depth / 6)
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return finish(obj, name, material, bone)


def beam(name, a, b, radius, material, bone=None):
    from mathutils import Vector
    a, b = Vector(a), Vector(b)
    obj = cylinder(name, (a + b) / 2, radius, (a - b).length, material, bone)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return obj


def pivot(name, p, objects):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = p
    bpy.context.view_layer.update()
    for child in objects:
        child.parent = obj
        child.matrix_parent_inverse = obj.matrix_world.inverted()
    return obj


def consolidate():
    groups = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH":
            key = (obj.parent.name if obj.parent else "", obj.data.materials[0].name)
            groups.setdefault(key, []).append(obj)
    for (parent, material), objects in sorted(groups.items()):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        objects[0].name = "Sculpt_" + parent + "_" + material
        objects[0].data.name = objects[0].name + "Mesh"


def canonicalize(path):
    raw = bytearray(path.read_bytes())
    count = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + count])
    base = 28 + count
    widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    for accessor in doc.get("accessors", []):
        if accessor["componentType"] != 5126 or "bufferView" not in accessor:
            continue
        view = doc["bufferViews"][accessor["bufferView"]]
        width = widths[accessor["type"]]
        start = base + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        for row in range(accessor["count"]):
            for col in range(width):
                pos = start + row * view.get("byteStride", width * 4) + col * 4
                v = round(struct.unpack_from("<f", raw, pos)[0], 5)
                struct.pack_into("<f", raw, pos, v if v else 0)
    def layout(index, width):
        accessor = doc["accessors"][index]
        view = doc["bufferViews"][accessor["bufferView"]]
        return accessor, base + view.get("byteOffset", 0) + accessor.get("byteOffset", 0), view.get("byteStride", width)

    # Stable area normals eliminate last-bit parallel accumulation drift while
    # preserving the exporter's split vertices at every hard sculpted edge.
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            if "NORMAL" not in primitive["attributes"]:
                continue
            pa, ps, stride = layout(primitive["attributes"]["POSITION"], 12)
            positions = [struct.unpack_from("<3f", raw, ps + i * stride) for i in range(pa["count"])]
            ia = doc["accessors"][primitive["indices"]]
            fmt, size = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}[ia["componentType"]]
            _, ins, instride = layout(primitive["indices"], size)
            indices = [struct.unpack_from("<" + fmt, raw, ins + i * instride)[0] for i in range(ia["count"])]
            triangles = []
            for i in range(0, len(indices), 3):
                triangle = indices[i:i + 3]
                start = triangle.index(min(triangle))
                triangles.append(triangle[start:] + triangle[:start])
            triangles.sort()
            indices = [index for triangle in triangles for index in triangle]
            for i, index in enumerate(indices):
                struct.pack_into("<" + fmt, raw, ins + i * instride, index)
            normals = [[0.0, 0.0, 0.0] for _ in positions]
            for i in range(0, len(indices), 3):
                a, b, c = [positions[indices[i + j]] for j in range(3)]
                u = [b[j] - a[j] for j in range(3)]
                v = [c[j] - a[j] for j in range(3)]
                cross = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
                for j in range(3):
                    for axis in range(3):
                        normals[indices[i + j]][axis] += cross[axis]
            _, ns, nstride = layout(primitive["attributes"]["NORMAL"], 12)
            for i, normal in enumerate(normals):
                length = math.sqrt(sum(x * x for x in normal))
                values = [round(x / length, 5) for x in normal] if length > 1e-15 else [0, 1, 0]
                struct.pack_into("<3f", raw, ns + i * nstride, *(x if x else 0 for x in values))
    path.write_bytes(raw)
    return doc


def export(name):
    consolidate()
    bpy.context.view_layer.update()
    from mathutils import Vector
    points = [obj.matrix_world @ Vector(corner) for obj in bpy.context.scene.objects
              if obj.type == "MESH" for corner in obj.bound_box]
    bounds = {"min": [min(p[i] for p in points) for i in range(3)],
              "max": [max(p[i] for p in points) for i in range(3)]}
    bpy.ops.object.select_all(action="SELECT")
    path = OUT / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_yup=True,
                              export_animations=False, export_skins=True,
                              export_extras=True, export_texcoords=False)
    doc = canonicalize(path)
    RECORDS.append({"name": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "bytes": path.stat().st_size, "bounds_blender": bounds,
                    "skins": len(doc.get("skins", [])),
                    "joints": len(doc["skins"][0]["joints"]) if doc.get("skins") else 0,
                    "meshes": len(doc.get("meshes", []))})


WOOD = mat("Honey oak", "916444")
DARK = mat("Leather and sockets", "343840")
GOLD = mat("Hammered brass", "e4b75e", .25)
STEEL = mat("Forged iron", "9caeaf", .25)
SKIN = mat("Warm skin", "e5b383")
STONE = mat("Limestone", "b7b39a")
BLUE = mat("Hearth teal", "318984")
RED = mat("Ash red", "b75048")
WHITE = mat("Ivory", "eee0b8")
GLASS = mat("Lantern glass", "f3d485")


def humanoid(role):
    clear()
    boss = role in ("ram", "matriarch", "regent")
    ally = role in ("commander", "citizen", "defender")
    garment = mat("Cloth " + role, {
        "commander": "318984", "citizen": "b39565", "defender": "4c828c",
        "raider": "b75048", "runner": "d29042", "armor": "737d91",
        "swarm": "a47182", "mender": "829b57", "shade": "776494",
        "ram": "8b6552", "matriarch": "965d86", "regent": "526e80"}[role])
    armor = role in ("armor", "ram", "regent", "defender")
    h = 1.12 if boss else 1
    width = 1.2 if role in ("armor", "ram") else (.83 if role in ("runner", "shade") else 1)
    block("Quilted jerkin", (0, 0, .88), (.53 * width, .34, .43), garment, .10, "Torso")
    cylinder("Skirt hem", (0, 0, .64), .29 * width, .20, garment, "Torso", top=.23 * width)
    block("Leather belt", (0, 0, .70), (.57 * width, .37, .07), DARK, .02, "Torso")
    block("Belt seal", (0, .202, .70), (.10, .05, .10), GOLD, .02, "Torso")
    if armor:
        block("Breastplate", (0, .172, .91), (.46 * width, .13, .34), STEEL, .075, "Torso")
        for x in (-.13, .13):
            oval("Rivet" + str(x), (x, .246, .94), (.025, .022, .025), GOLD, "Torso")
    else:
        for x in (-.15, .15):
            block("Cross strap" + str(x), (x, .183, .90), (.045, .04, .33), WOOD, .012, "Torso")
    oval("Neck", (0, 0, 1.12), (.11, .10, .12), SKIN, "Head")
    oval("Sculpted face", (0, .02, 1.29), (.20, .18, .22), SKIN, "Head")
    oval("Nose", (0, .19, 1.27), (.047, .065, .055), SKIN, "Head")
    for side in (-1, 1):
        oval("Ear" + str(side), (side * .20, .0, 1.28), (.045, .06, .075), SKIN, "Head")
        block("Eye" + str(side), (side * .077, .181, 1.32), (.045, .025, .032), DARK, .008, "Head")
        block("Brow" + str(side), (side * .077, .178, 1.36), (.072, .035, .026), DARK, .008, "Head")
    if role in ("commander", "regent"):
        cylinder("Crown circlet", (0, .0, 1.45), .215, .10, GOLD, "Head")
        for i in range(5):
            a = i * math.tau / 5
            block("Crown point" + str(i), (.19 * math.cos(a), .19 * math.sin(a), 1.56), (.065, .07, .20), GOLD, .025, "Head")
        block("Cloak", (0, -.22, .85), (.55, .10, .57), garment, .065, "Cape")
        block("Cloak brooch", (.20, .17, 1.08), (.09, .06, .09), GOLD, .025, "Torso")
    elif role in ("mender", "shade", "matriarch"):
        oval("Hood", (0, -.03, 1.40), (.24, .23, .19), garment, "Head")
        block("Hood face opening", (0, .17, 1.39), (.28, .05, .07), WHITE, .02, "Head")
        block("Mantle", (0, -.19, .94), (.58, .10, .40), garment, .06, "Cape")
    elif role == "citizen":
        cylinder("Felt cap", (0, -.015, 1.46), .23, .16, garment, "Head", top=.14)
        block("Apron", (0, .193, .72), (.34, .045, .35), WHITE, .03, "Torso")
    else:
        oval("Helmet dome", (0, -.015, 1.43), (.235 * width, .22, .15), STEEL if armor else garment, "Head")
        block("Helmet brim", (0, .015, 1.405), (.50 * width, .43, .065), GOLD if ally else DARK, .025, "Head")
        if role == "runner":
            oval("Feather", (.06, -.09, 1.66), (.05, .10, .20), RED, "Head")
    for side, suffix in ((-1, "L"), (1, "R")):
        x = side * .145
        block("Trouser" + suffix, (x, 0, .50), (.21, .24, .28), garment, .06, "Thigh" + suffix)
        oval("Knee" + suffix, (x, .07, .355), (.105, .12, .10), STEEL if armor else WOOD, "Shin" + suffix)
        block("Greave" + suffix, (x, 0, .245), (.17, .20, .23), STEEL if armor else WOOD, .05, "Shin" + suffix)
        block("Boot" + suffix, (x, .08, .095), (.23, .37, .19), DARK, .05, "Foot" + suffix)
        block("Boot sole" + suffix, (x, .09, .027), (.24, .38, .055), WOOD, .018, "Foot" + suffix)
        oval("Shoulder" + suffix, (side * .32 * width, 0, 1.035), (.15, .17, .15), STEEL if armor else garment, "UpperArm" + suffix)
        block("Sleeve" + suffix, (side * .34 * width, .02, .92), (.21, .23, .25), garment, .075, "UpperArm" + suffix)
        block("Forearm" + suffix, (side * .34 * width, .14, .785), (.18, .31, .16), WOOD if armor else garment, .06, "Forearm" + suffix)
        oval("Glove" + suffix, (side * .34 * width, .295, .78), (.095, .10, .09), DARK, "Hand" + suffix)
    tip = (.34 * width, .83, .82)
    if role == "defender":
        block("Crossbow stock", (.34 * width, .48, .81), (.12, .66, .13), WOOD, .03, "Weapon")
        for s in (-1, 1):
            bow = block("Bow arm" + str(s), (.34 * width + s * .20, .69, .82), (.43, .07, .07), STEEL, .02, "Weapon")
            bow.rotation_euler.z = s * .17
            beam("Bowstring" + str(s), (.34 * width + s * .40, .65, .82), (.34 * width, .38, .82), .009, WHITE, "Weapon")
        beam("Loaded bolt", (.34 * width, .38, .90), tip, .022, GOLD, "Weapon")
    elif role in ("mender", "matriarch", "commander"):
        beam("Lantern staff", (.34 * width, .30, .32), (.34 * width, .36, 1.34), .035, WOOD, "Weapon")
        cylinder("Lantern frame", (.34 * width, .36, 1.38), .12, .30, GOLD, "Weapon")
        oval("Lantern pane", (.34 * width, .39, 1.40), (.09, .095, .11), GLASS, "Weapon")
        tip = (.34 * width, .36, 1.57)
    elif role == "citizen":
        beam("Mallet handle", (.34 * width, .30, .70), (.34 * width, .65, .95), .034, WOOD, "Weapon")
        block("Mallet head", (.34 * width, .66, .96), (.30, .16, .17), WOOD, .045, "Weapon")
        tip = (.34 * width, .75, .96)
    else:
        beam("Sword grip", (.34 * width, .30, .78), (.34 * width, .44, .91), .045, DARK, "Weapon")
        block("Sword guard", (.34 * width, .45, .93), (.30, .07, .07), GOLD, .02, "Weapon")
        blade = block("Sword blade", (.34 * width, .67, 1.12), (.105 if role != "ram" else .21, .08, .64), STEEL, .035, "Weapon")
        blade.rotation_euler.x = -.85
        tip = (.34 * width, .91, 1.34)
        if role in ("armor", "ram", "raider"):
            cylinder("Shield rim", (-.34 * width, .37, .80), .31, .10, GOLD if ally else STEEL, "HandL", (math.pi / 2, 0, 0))
            cylinder("Painted shield", (-.34 * width, .432, .80), .26, .045, garment, "HandL", (math.pi / 2, 0, 0))
            oval("Shield boss", (-.34 * width, .466, .80), (.08, .05, .08), GOLD, "HandL")
    if role == "ram":
        for s in (-1, 1):
            beam("Ram horn" + str(s), (s * .18, 0, 1.47), (s * .37, .05, 1.70), .10, WHITE, "Head")
            beam("Ram horn tip" + str(s), (s * .37, .05, 1.70), (s * .33, .19, 1.78), .06, WHITE, "Head")
    if role == "matriarch":
        for s in (-1, 1):
            oval("Brood pauldron" + str(s), (s * .36, -.02, 1.12), (.21, .24, .18), garment, "UpperArm" + ("L" if s < 0 else "R"))
            oval("Brood charm" + str(s), (s * .27, .15, .61), (.10, .10, .14), GLASS, "Torso")
    if role == "regent":
        block("Regent standard", (0, -.31, 1.43), (.08, .07, .90), WOOD, .018, "Cape")
        block("Regent pennant", (.23, -.31, 1.73), (.48, .06, .32), RED, .04, "Cape")
    positions = {"Root": (0, 0, 0), "Torso": (0, 0, .68), "Head": (0, 0, 1.12), "Cape": (0, -.18, 1.07)}
    parents = {"Torso": "Root", "Head": "Torso", "Cape": "Torso"}
    for side, suffix in ((-1, "L"), (1, "R")):
        for name, p, parent in (
            ("Thigh", (side * .145, 0, .64), "Root"),
            ("Shin", (side * .145, 0, .36), "Thigh" + suffix),
            ("Foot", (side * .145, 0, .12), "Shin" + suffix),
            ("UpperArm", (side * .32 * width, 0, 1.07), "Torso"),
            ("Forearm", (side * .34 * width, .02, .81), "UpperArm" + suffix),
            ("Hand", (side * .34 * width, .29, .78), "Forearm" + suffix)):
            positions[name + suffix] = p
            parents[name + suffix] = parent
    positions["Weapon"] = (.34 * width, .30, .80)
    parents["Weapon"] = "HandR"
    positions["WeaponTip"] = tip
    parents["WeaponTip"] = "Weapon"
    arm = bpy.data.armatures.new("HearthguardArticulatedSkin")
    rig = bpy.data.objects.new("HearthRig", arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, p in positions.items():
        bone = arm.edit_bones.new(name)
        bone.head = p
        bone.tail = (p[0], p[1], p[2] + .10)
        if name in parents:
            bone.parent = arm.edit_bones[parents[name]]
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj, joint in PARTS:
        group = obj.vertex_groups.new(name=joint)
        group.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
        obj.modifiers.new("Rigid weighted sculpture", "ARMATURE").object = rig
        obj.parent = rig
    rig["forward"] = "+Y Blender / -Z Godot"
    rig["authorship"] = "Original Hearthguard deterministic geometry and rigid skin"
    export("actor_" + role)


def hut(kind):
    clear()
    fen = kind == "stilt_house"
    snow = kind == "ridge_house"
    plaster = mat("Warm plaster", "e1cf9f") if not fen else mat("Fen plaster", "a8beb0")
    roof = mat("Roof " + kind, "638d92" if fen else ("617c8b" if snow else "b67846"))
    lift = .35 if fen else 0
    block("Stone footing", (0, 0, .15 + lift), (1.60, 1.30, .30), STONE, .10)
    block("Plastered walls", (0, 0, .82 + lift), (1.40, 1.12, 1.12), plaster, .10)
    for x in (-.68, .68):
        block("Corner timber" + str(x), (x, .54, .83 + lift), (.12, .12, 1.12), WOOD, .02)
    block("Beam", (0, .58, 1.22 + lift), (1.50, .13, .13), WOOD, .025)
    for s in (-1, 1):
        r = block("Pitched roof" + str(s), (s * .42, 0, 1.54 + lift), (1.04, 1.55, .15), roof, .035)
        r.rotation_euler.y = s * .57
        for j in range(4):
            seam = block("Roof batten" + str(s) + str(j), (s * .42, -.59 + j * .39, 1.63 + lift), (1.04, .025, .04), GOLD if not snow else WHITE, .01)
            seam.rotation_euler.y = s * .57
    beam("Roof ridge", (0, -.79, 1.83 + lift), (0, .79, 1.83 + lift), .075, WOOD)
    block("Door surround", (0, .59, .62 + lift), (.50, .09, .87), WOOD, .06)
    block("Door inset", (0, .65, .61 + lift), (.35, .055, .70), DARK, .04)
    oval("Door pull", (.11, .69, .60 + lift), (.026, .025, .035), GOLD)
    for x in (-.48, .48):
        block("Window frame" + str(x), (x, .59, .96 + lift), (.27, .08, .31), WOOD, .025)
        block("Lit window" + str(x), (x, .64, .96 + lift), (.18, .035, .21), GLASS, .018)
        block("Window mullion" + str(x), (x, .668, .96 + lift), (.025, .02, .23), WOOD, .005)
    block("Chimney", (-.43, -.24, 1.82 + lift), (.25, .28, .62), STONE, .045)
    if snow:
        for s in (-1, 1):
            cap = block("Snow blanket" + str(s), (s * .42, 0, 1.65), (1.05, 1.57, .10), WHITE, .04)
            cap.rotation_euler.y = s * .57
    if fen:
        for x in (-.63, .63):
            for y in (-.45, .45):
                cylinder("Stilt" + str(x) + str(y), (x, y, .25), .08, .6, WOOD)
    export(kind)


def watchtower(family):
    clear()
    cylinder("Octagonal footing", (0, 0, .12), .64, .24, STONE)
    cylinder("Tapered tower", (0, 0, .61), .45, .92, STONE, top=.36)
    for s in (-1, 1):
        block("Timber brace" + str(s), (s * .38, 0, .64), (.12, .38, .95), WOOD, .025)
    block("Deck", (0, 0, 1.12), (1.04, .98, .16), WOOD, .055)
    for x in (-.44, .44):
        for y in (-.40, .40):
            block("Deck post" + str(x) + str(y), (x, y, 1.25), (.13, .13, .28), GOLD, .025)
    items = []
    if family == "bolt":
        items.append(block("Crossbow tiller", (0, .07, 1.46), (.18, .96, .18), WOOD, .03))
        for s in (-1, 1):
            obj = block("Crossbow limb" + str(s), (s * .31, .34, 1.48), (.66, .10, .10), STEEL, .025)
            obj.rotation_euler.z = s * .18
            items += [obj, beam("Crossbow cord" + str(s), (s * .63, .27, 1.48), (0, -.18, 1.48), .012, WHITE)]
        items.append(beam("Visible loaded bolt", (0, -.19, 1.56), (0, .70, 1.56), .025, GOLD))
        tip = (0, .70, 1.56)
    elif family == "mortar":
        cylinder("Mortar bed", (0, 0, 1.36), .40, .30, DARK)
        obj = cylinder("Mortar barrel", (0, .13, 1.61), .25, .65, GOLD, tilt=(math.pi / 3, 0, 0))
        items.append(obj)
        items.append(cylinder("Mortar mouth", (0, .43, 1.77), .18, .03, DARK, tilt=(math.pi / 3, 0, 0)))
        tip = (0, .45, 1.79)
    else:
        items.append(cylinder("Beacon column", (0, 0, 1.49), .16, .70, STEEL))
        items.append(oval("Beacon heart", (0, 0, 1.94), (.22, .22, .32), mat("Ice crystal", "82d9d0")))
        for s in (-1, 1):
            items.append(beam("Beacon prong" + str(s), (s * .30, 0, 1.32), (s * .28, 0, 1.98), .045, GOLD))
        tip = (0, 0, 2.21)
    turret = pivot("Turret", (0, 0, 1.36), items)
    socket = bpy.data.objects.new("AuthoredWeaponTip", None)
    bpy.context.collection.objects.link(socket)
    socket.location = tip
    bpy.context.view_layer.update()
    socket.parent = turret
    socket.matrix_parent_inverse = turret.matrix_world.inverted()
    export("tower_" + family)


def props():
    clear()
    block("Wall foot", (0, 0, .11), (.42, 1.12, .22), STONE, .065)
    for row in range(2):
        block("Ashlar" + str(row), (0, 0, .29 + row * .24), (.35, 1.04, .22), STONE, .045)
    for y in (-.37, .37):
        block("Merlon" + str(y), (0, y, .77), (.38, .27, .29), STONE, .045)
    export("wall")
    clear()
    cylinder("Oak trunk", (0, 0, .6), .13, 1.2, WOOD)
    for i, p in enumerate([(-.30, 0, 1.27), (.31, -.03, 1.42), (0, .12, 1.75)]):
        oval("Leaf crown" + str(i), p, (.55, .52, .62), mat("Copper leaves", "738c52"))
    export("oak")
    clear()
    cylinder("Pine trunk", (0, 0, .60), .12, 1.2, WOOD)
    for i in range(3):
        cylinder("Pine tier" + str(i), (0, 0, .9 + i * .44), .63 - i * .13, .85, mat("Pine", "467a72"), top=.06)
        cylinder("Snow tier" + str(i), (0, 0, 1.09 + i * .44), .41 - i * .095, .52, WHITE, top=.02)
    export("pine")
    clear()
    block("Rock foot", (0, 0, .25), (.90, .75, .50), mat("Slate", "728d92"), .17)
    obj = block("Rock upper", (.10, -.03, .53), (.67, .60, .43), STONE, .15)
    obj.rotation_euler.z = .25
    export("boulder")
    clear()
    cylinder("Lamp base", (0, 0, .12), .20, .24, STONE)
    cylinder("Lamp pole", (0, 0, .86), .05, 1.5, WOOD)
    block("Lamp cap", (0, 0, 1.71), (.35, .35, .13), GOLD, .035)
    block("Lamp pane", (0, 0, 1.48), (.23, .23, .33), GLASS, .035)
    for x in (-.13, .13):
        for y in (-.13, .13):
            block("Lamp strut" + str(x) + str(y), (x, y, 1.49), (.035, .035, .38), DARK, .008)
    export("lantern")
    clear()
    cylinder("Well ring", (0, 0, .34), .52, .68, STONE)
    cylinder("Well water", (0, 0, .695), .39, .03, mat("Water", "478c9b"))
    for x in (-.49, .49):
        beam("Well support" + str(x), (x, 0, .5), (x, 0, 1.48), .055, WOOD)
    beam("Well crossbar", (-.60, 0, 1.48), (.60, 0, 1.48), .07, WOOD)
    cylinder("Well bucket", (.12, 0, 1.11), .13, .24, GOLD)
    export("well")
    clear()
    block("Market tabletop", (0, 0, .65), (1.40, .70, .12), WOOD, .035)
    for x in (-.54, .54):
        for y in (-.25, .25):
            block("Market leg" + str(x) + str(y), (x, y, .32), (.10, .10, .64), WOOD, .02)
    for i in range(5):
        oval("Market produce" + str(i), (-.42 + i * .21, .02, .79), (.11, .12, .12), mat("Apples", "c7834c"))
    export("market")
    clear()
    cylinder("Minted coin", (0, 0, .0), .22, .075, GOLD, tilt=(math.pi / 2, 0, 0))
    block("Coin stamp", (0, .045, 0), (.12, .025, .20), WHITE, .025)
    export("coin")
    clear()
    cylinder("Banner plinth", (0, 0, .12), .22, .24, STONE)
    cylinder("Banner pole", (0, 0, 1.15), .04, 2.2, WOOD)
    block("Banner cloth", (.27, 0, 1.75), (.57, .07, .67), BLUE, .045)
    block("Banner heraldry", (.27, .043, 1.76), (.20, .025, .30), GOLD, .025)
    oval("Banner finial", (0, 0, 2.30), (.07, .07, .11), GOLD)
    export("banner")
    clear()
    for i in range(5):
        x, y = (i % 3 - 1) * .15, (i // 3) * .17
        beam("Reed" + str(i), (x, y, 0), (x + .06, y, .70 + i * .06), .023, mat("Reeds", "96a36a"))
        cylinder("Reed head" + str(i), (x + .06, y, .76 + i * .06), .045, .20, WOOD)
    export("reeds")
    clear()
    block("Forge anvil base", (0, 0, .25), (.70, .65, .50), WOOD, .09)
    block("Forge anvil waist", (0, 0, .57), (.33, .40, .25), DARK, .06)
    block("Forge anvil face", (0, 0, .75), (.80, .45, .16), STEEL, .045)
    export("anvil")
    clear()
    for i in range(3):
        block("Glass monolith" + str(i), ((i - 1) * .34, 0, .65 + i * .19), (.24, .31, 1.25 + i * .38), mat("Glass stone", "91bfc0"), .055)
    export("monolith")


for role in ("commander", "citizen", "defender", "raider", "runner", "armor", "swarm", "mender", "shade", "ram", "matriarch", "regent"):
    humanoid(role)
for kind in ("cottage", "stilt_house", "ridge_house"):
    hut(kind)
for family in ("bolt", "mortar", "beacon"):
    watchtower(family)
props()
(OUT.parent / "manifest.json").write_text(json.dumps({
    "generator": "Blender 4.5.14, original CPU-only Hearthguard sculpture",
    "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    "license": "Original project artwork; no external assets or services",
    "coordinates": "bounds_blender are x/right y/forward z/up; Godot maps (x,z,-y)",
    "models": RECORDS}, indent=2) + "\n")
print("HEARTHGUARD_KIT_COMPLETE", len(RECORDS))
