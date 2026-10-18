"""Original Hook and Hunger sculpture kit; Blender 4.5.14, CPU export only.

No downloaded geometry, images or libraries. +Y forward / +Z up becomes Godot
-Z forward / +Y up. Named rigid skin groups articulate modeled limb segments.
Run blender --background --factory-startup --threads 2 --python this_file.
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
PARTS, RECORDS, MATS = [], [], {}
bpy.context.scene.render.engine = "BLENDER_WORKBENCH"


def material(name, color, metal=0):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        rgb = tuple(int(color[i:i + 2], 16) / 255 for i in (0, 2, 4))
        m.diffuse_color = (*rgb, 1)
        m.use_nodes = True
        shader = m.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*rgb, 1)
        shader.inputs["Roughness"].default_value = .72
        shader.inputs["Metallic"].default_value = metal
        MATS[name] = m
    return MATS[name]


INK = material("Deep ocean rubber", "243e4a")
BRASS = material("Diver brass", "d8ad68", .25)
TEAL = material("Enamel jade", "62b9ae", .12)
GLASS = material("Visor sea glass", "97ddcf", .22)
SUIT = material("Diver saffron", "e7ab62")
WOOD = material("Salvaged teak", "886653")
SAND = material("Warm limestone", "c7bc9b")
ROCK = material("Ocean basalt", "647e82")
LEAF = material("Palm frond", "548c73")
IVORY = material("Pearl edge", "e5deba")
CORAL = material("Sun coral", "cc8c7d")


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)
    PARTS.clear()


def finish(obj, name, mat, bone=None):
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
    obj.data.name = name + "Mesh"
    obj.data.materials.append(mat)
    if bone:
        PARTS.append((obj, bone))
    return obj


def block(name, at, size, mat, bone=None, bevel=.05):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new("Rounded sculpted rim", "BEVEL")
    mod.width = min(bevel, min(size) * .4)
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, mat, bone)


def oval(name, at, size, mat, bone=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1, location=at)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for f in obj.data.polygons:
        f.use_smooth = True
    return finish(obj, name, mat, bone)


def cone(name, at, radius, height, mat, bone=None, top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=radius,
                                  radius2=radius if top is None else top,
                                  depth=height, location=at)
    return finish(bpy.context.object, name, mat, bone)


def beam(name, a, b, radius, mat, bone=None):
    a, b = Vector(a), Vector(b)
    obj = cone(name, (a + b) / 2, radius, (b - a).length, mat, bone)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return obj


def torus(name, at, radius, tube, mat, bone=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=6,
                                   location=at, major_radius=radius, minor_radius=tube)
    return finish(bpy.context.object, name, mat, bone)


def rig():
    bpy.ops.object.armature_add()
    arm = bpy.context.object
    arm.name = "SalvageRig"
    arm.data.name = "SalvageRigData"
    bpy.ops.object.mode_set(mode="EDIT")
    arm.data.edit_bones.remove(arm.data.edit_bones[0])
    specs = [("Root", (0, 0, 0), None), ("Torso", (0, 0, .7), "Root"),
             ("Head", (0, 0, 1.22), "Torso")]
    for side, suffix in ((-1, "L"), (1, "R")):
        specs += [("Thigh" + suffix, (side * .23, 0, .65), "Root"),
                  ("Shin" + suffix, (side * .23, 0, .37), "Thigh" + suffix),
                  ("Foot" + suffix, (side * .23, .03, .12), "Shin" + suffix),
                  ("Arm" + suffix, (side * .39, 0, 1.08), "Torso"),
                  ("Forearm" + suffix, (side * .49, .08, .87), "Arm" + suffix),
                  ("Hand" + suffix, (side * .49, .32, .84), "Forearm" + suffix)]
    specs += [("ChainSocket", (.49, .43, .84), "HandR"),
              ("Crest", (0, -.15, 1.65), "Head"),
              ("Tail", (0, -.32, .65), "Root")]
    for name, point, parent in specs:
        bone = arm.data.edit_bones.new(name)
        bone.head = point
        bone.tail = Vector(point) + Vector((0, 0, .12))
        if parent:
            bone.parent = arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj, bone in PARTS:
        group = obj.vertex_groups.new(name=bone)
        group.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
        mod = obj.modifiers.new("Articulated salvage skin", "ARMATURE")
        mod.object = arm
        obj.parent = arm
    # A small authored reference clip proves channels survive import. Runtime
    # samples current rule clocks with procedural bone poses, never callbacks.
    chest = arm.pose.bones["Torso"]
    chest.rotation_mode = "XYZ"
    for frame, angle in ((1, -.035), (16, .035), (31, -.035)):
        chest.rotation_euler.x = angle
        chest.keyframe_insert(data_path="rotation_euler", frame=frame)
    arm.animation_data.action.name = "AuthoredBreath"
    bpy.context.scene.frame_set(1)
    return arm


def actor(role):
    clear()
    diver = role == "diver"
    boss = role in ("bellkeeper", "warden", "kiln", "twin_sun", "twin_moon", "crown")
    colors = {"skitter": "70aaa2", "lancer": "7c9eb9", "spitter": "c9a275",
              "shield": "8499a2", "charger": "c78384", "tender": "a590b6",
              "warden": "839b9b", "kiln": "b78360", "twin_sun": "c8ae70",
              "twin_moon": "839bc2", "crown": "a48fb5", "bellkeeper": "91a696"}
    shell = SUIT if diver else material("Carapace " + role, colors[role])
    width = 1.22 if role in ("shield", "kiln", "warden", "bellkeeper") else 1
    oval("Pressure suit" if diver else "Carapace", (0, 0, .91), (.36 * width, .27, .37), shell, "Torso")
    block("Belt", (0, 0, .65), (.65 * width, .46, .10), INK, "Root")
    block("Belt buckle", (0, .25, .65), (.16, .07, .13), BRASS, "Root")
    if diver:
        oval("Brass diving helmet", (0, 0, 1.48), (.37, .32, .34), BRASS, "Head")
        block("Visor gasket", (0, .29, 1.48), (.53, .13, .27), INK, "Head", .09)
        block("Curved visor", (0, .366, 1.49), (.43, .07, .18), GLASS, "Head", .07)
        block("Visor highlight", (-.13, .405, 1.52), (.09, .015, .09), IVORY, "Head")
        for x in (-.18, .18):
            cone("Air cylinder" + str(x), (x, -.31, .94), .13, .56, TEAL, "Torso")
            block("Tank strap" + str(x), (x, -.32, .94), (.29, .28, .06), INK, "Torso")
        beam("Breathing hose", (.29, .10, 1.30), (.36, -.25, .99), .05, INK, "Torso")
    else:
        oval("Sea creature head", (0, .10, 1.35), (.30 * width, .30, .25), shell, "Head")
        for side in (-1, 1):
            oval("Eye socket" + str(side), (side * .19, .35, 1.40), (.10, .085, .10), INK, "Head")
            oval("Amber eye" + str(side), (side * .19, .422, 1.41), (.05, .025, .05), IVORY, "Head")
        for i in range(3 if not boss else 6):
            a = i * math.tau / (3 if not boss else 6)
            cone("Crystal crown" + str(i), (math.cos(a) * .24, math.sin(a) * .20, 1.67 + .09 * (i % 2)), .10, .40, IVORY, "Crest", top=0)
        oval("Back shell", (0, -.24, .99), (.40 * width, .20, .36), shell, "Torso")
        for i in range(3):
            cone("Dorsal crystal" + str(i), ((i - 1) * .18, -.39, 1.23), .10, .31, GLASS, "Torso", top=0)
    for side, suffix in ((-1, "L"), (1, "R")):
        block("Upper leg" + suffix, (side * .23, 0, .53), (.24, .27, .30), shell, "Thigh" + suffix)
        oval("Knee" + suffix, (side * .23, .05, .36), (.14, .15, .13), BRASS if diver else IVORY, "Shin" + suffix)
        block("Lower leg" + suffix, (side * .23, 0, .24), (.21, .24, .24), INK, "Shin" + suffix)
        block("Diving boot" + suffix if diver else "Cloven foot" + suffix,
              (side * .23, .12, .10), (.30, .52 if diver else .38, .19), BRASS if diver else shell, "Foot" + suffix)
        oval("Shoulder" + suffix, (side * .39, 0, 1.07), (.18, .19, .18), shell, "Arm" + suffix)
        beam("Upper arm" + suffix, (side * .39, 0, 1.05), (side * .49, .08, .87), .13, shell, "Arm" + suffix)
        beam("Forearm" + suffix, (side * .49, .08, .87), (side * .49, .31, .84), .13, INK if diver else shell, "Forearm" + suffix)
        oval("Glove or claw" + suffix, (side * .49, .34, .84), (.14, .14, .13), BRASS if diver else IVORY, "Hand" + suffix)
    if role in ("skitter", "bellkeeper", "warden"):
        for side, suffix in ((-1, "L"), (1, "R")):
            for i in range(2):
                beam("Swimmer limb" + suffix + str(i), (side * .30, -.10 - .18 * i, .70), (side * .69, -.19 - .24 * i, .28), .075, shell, "Thigh" + suffix)
    if role in ("shield", "kiln"):
        block("Forward shell shield", (0, .48, .99), (.86, .24, .85), ROCK, "HandL", .12)
        block("Armor seam", (0, .617, .99), (.12, .05, .70), BRASS, "HandL")
    if role in ("lancer", "warden"):
        beam("Crystal lance shaft", (.49, .32, .84), (.49, .95, 1.0), .055, ROCK, "HandR")
        cone("Lance pearl", (.49, .96, 1.12), .15, .40, IVORY, "HandR", top=0)
    if role in ("spitter", "twin_sun", "tender"):
        oval("Pressure throat", (0, .40, 1.23), (.20, .22, .18), INK, "Head")
        torus("Nozzle lip", (0, .52, 1.23), .17, .045, BRASS, "Head").rotation_euler.x = math.pi / 2
    if role in ("charger", "twin_moon"):
        horn = cone("Ram crest", (0, .39, 1.56), .19, .75, IVORY, "Head", top=0)
        horn.rotation_euler.x = -.85
    if role in ("tender", "twin_sun", "twin_moon", "crown"):
        torus("Lantern halo", (0, 0, 1.88), .39 if role != "crown" else .58, .055, BRASS, "Crest")
        for x in (-.37, .37):
            oval("Hanging lantern" + str(x), (x, 0, 1.71), (.11, .12, .18), GLASS, "Crest")
    if role == "kiln":
        cone("Kiln chimney", (0, -.25, 1.54), .23, .52, ROCK, "Torso")
        torus("Hot chimney rim", (0, -.25, 1.82), .24, .045, CORAL, "Torso")
    if role == "crown":
        for i in range(7):
            a = i * math.tau / 7
            beam("Crown ray" + str(i), (.36 * math.cos(a), .36 * math.sin(a), 1.74),
                 (.73 * math.cos(a), .73 * math.sin(a), 2.03), .065, IVORY, "Crest")
    if role == "bellkeeper":
        cone("Bell shell", (0, -.03, 1.50), .48, .32, BRASS, "Crest", top=.24)
    rig()
    export("actor_" + role)


def weapon(tier):
    clear()
    mat = [BRASS, TEAL, CORAL, material("Storm enamel", "a99ac4", .15)][tier]
    torus("Chain eye", (0, -.25, 0), .11, .035, INK)
    beam("Weapon spine", (0, -.25, 0), (0, .40, 0), .08, ROCK)
    if tier == 2:
        oval("Furnace flail core", (0, .12, 0), (.36, .38, .32), mat)
        for i in range(8):
            a = i * math.tau / 8
            oval("Hammer stud" + str(i), (.34 * math.cos(a), .12 + .34 * math.sin(a), 0), (.12, .12, .15), BRASS)
    else:
        for side in (-1, 1):
            block("Anchor arm" + str(side), (side * .25, .16, 0), (.53, .17, .16), mat)
            tip = block("Sharpened barb" + str(side), (side * .44, .31, 0), (.18, .47, .17), mat)
            tip.rotation_euler.z = -side * .43
        if tier == 3:
            oval("Storm pearl", (0, .16, .11), (.16, .20, .12), GLASS)
    for name, point in (("ChainEye", (0, -.25, 0)),
                        ("ContactTip", (0, .58, 0) if tier == 2 else (.538, .523, 0))):
        marker = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(marker)
        marker.location = point
    export("weapon_" + str(tier))


def prop(kind):
    clear()
    if kind.startswith("terrain_"):
        colors = ["b8b695", "a58f78", "97a9a4", "a6b4b7"]
        mat = material(kind, colors[int(kind[-1])])
        block("Beveled island shelf", (0, 0, -.51), (19.2, 27.2, 1.0), ROCK, bevel=.32)
        block("Continuous island top", (0, 0, -.065), (18.8, 26.8, .13), mat, bevel=.05)
    elif kind == "palm":
        for i in range(5):
            cone("Curving trunk" + str(i), (.08 * i, 0, .30 + .48 * i), .16 - i * .012, .53, WOOD)
        for i in range(7):
            a = i * math.tau / 7
            leaf = oval("Palm leaf" + str(i), (.4 + .67 * math.cos(a), .67 * math.sin(a), 2.55), (.88, .22, .11), LEAF)
            leaf.rotation_euler.z = a
            leaf.rotation_euler.y = .24
        oval("Coconut", (.40, 0, 2.47), (.18, .18, .20), WOOD)
    elif kind == "rock":
        oval("Rounded reef boulder", (0, 0, .37), (.74, .65, .43), ROCK)
        for i in range(3):
            cone("Reef quartz" + str(i), ((i - 1) * .22, 0, .83 + .12 * (i % 2)), .14, .64, GLASS, top=.015)
    elif kind == "coral":
        for i in range(5):
            a = i * math.tau / 5
            beam("Coral stalk" + str(i), (0, 0, .0), (.36 * math.cos(a), .36 * math.sin(a), .45 + .09 * i), .09, CORAL)
            oval("Coral tip" + str(i), (.36 * math.cos(a), .36 * math.sin(a), .45 + .09 * i), (.15, .15, .13), CORAL)
    elif kind == "fence":
        for x in (-.9, .9):
            cone("Mooring bollard" + str(x), (x, 0, .40), .10, .80, WOOD)
            cone("Bollard brass cap" + str(x), (x, 0, .84), .13, .08, BRASS)
        for h in (.32, .63):
            beam("Rounded rail" + str(h), (-.9, 0, h), (.9, 0, h), .045, TEAL)
    elif kind == "door":
        for x in (-.9, 0, .9):
            block("Gate rib" + str(x), (x, 0, .72), (.13, .22, 1.40), BRASS)
        block("Gate brace", (0, 0, 1.20), (2.9, .20, .14), TEAL)
    elif kind == "forge":
        cone("Forge plinth", (0, 0, .20), .85, .40, ROCK)
        torus("Forge brass rim", (0, 0, .42), .72, .065, BRASS)
        block("Anvil body", (0, 0, .57), (.63, .42, .20), INK)
        block("Anvil lip", (0, .03, .71), (.97, .38, .12), TEAL)
        for x in (-.52, .52):
            cone("Salvage socket" + str(x), (x, -.31, .50), .12, .16, BRASS)
    elif kind == "salvage":
        block("Salvage chest", (0, 0, .18), (.42, .37, .32), WOOD)
        for x in (-.14, .14):
            block("Chest strap" + str(x), (x, 0, .19), (.05, .39, .35), BRASS)
        oval("Salvage pearl", (0, 0, .39), (.15, .14, .12), TEAL)
    elif kind == "boat":
        oval("Rounded tender hull", (0, 0, .31), (.80, 1.65, .35), WOOD)
        block("Deck inset", (0, 0, .57), (1.08, 2.40, .10), SAND)
        for y in (-.8, .2):
            block("Bench" + str(y), (0, y, .73), (1.20, .22, .18), TEAL)
        beam("Mast", (0, .27, .60), (0, .27, 2.55), .055, BRASS)
        block("Furled sail", (.22, .27, 1.96), (.42, .12, 1.0), IVORY)
    elif kind == "beacon":
        for i in range(3):
            cone("Beacon tier" + str(i), (0, 0, .20 + i * .36), 1 - .16 * i, .35, SAND)
        for x in (-.47, .47):
            beam("Lantern frame" + str(x), (x, 0, 1.05), (x, 0, 2.20), .09, BRASS)
        oval("Beacon lens", (0, 0, 1.65), (.40, .40, .47), GLASS)
        cone("Lantern roof", (0, 0, 2.21), .72, .27, TEAL, top=.05)
    elif kind == "kiln_arch":
        for x in (-1.15, 1.15):
            block("Volcanic pillar" + str(x), (x, 0, 1), (.76, 1.10, 2), ROCK, bevel=.16)
            torus("Kiln pipe" + str(x), (x, .59, .92), .28, .065, CORAL).rotation_euler.x = math.pi / 2
        block("Kiln lintel", (0, 0, 2.10), (3.3, 1.15, .48), WOOD, bevel=.12)
        cone("Kiln chimney", (.7, 0, 2.63), .34, .62, ROCK)
    elif kind == "wreck":
        oval("Wreck half hull", (0, 0, .50), (1.25, 2.1, .50), WOOD)
        for i in range(5):
            beam("Exposed rib" + str(i), (-1.1, -1.6 + .7 * i, .30), (.9, -1.6 + .7 * i, 1.0), .09, BRASS)
        beam("Snapped mast", (0, 0, .6), (.5, -.5, 2.7), .12, WOOD)
    elif kind == "crystal_spire":
        for i in range(5):
            a = i * math.tau / 5
            cone("Glass choir" + str(i), (.55 * math.cos(a), .55 * math.sin(a), 1.2 + .22 * (i % 3)), .32, 2.4 + .44 * (i % 3), GLASS, top=.03)
        torus("Choir base", (0, 0, .16), 1.0, .13, SAND)
    elif kind == "buoy":
        oval("Buoy float", (0, 0, .22), (.45, .45, .30), CORAL)
        beam("Buoy rod", (0, 0, .35), (0, 0, 1.2), .045, BRASS)
        cone("Buoy light", (0, 0, 1.20), .15, .20, IVORY)
    elif kind == "chain_link":
        torus("Forged chain link", (0, 0, 0), .085, .026, INK)
    export(kind)


def canonicalize(path):
    # Blender's parallel exporter may reorder independent triangles. Keep vertex
    # and skin data intact; sort cyclic triangle indices without changing winding.
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
            # Stable area normals avoid last-bit/parallel accumulation changes.
            # glTF has already split hard sculpted edges into separate vertices.
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
    # Consolidate by material and skin; retain per-joint weights on joining.
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
        objects[0].name = name + "_" + mat.replace(" ", "_")
        objects[0].data.name = objects[0].name + "Mesh"
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(c) for obj in bpy.context.scene.objects if obj.type == "MESH" for c in obj.bound_box]
    bpy.ops.object.select_all(action="SELECT")
    path = OUT / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_yup=True,
                              export_animations=bool(PARTS), export_skins=True,
                              export_extras=True, export_texcoords=False)
    canonicalize(path)
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    RECORDS.append({"name": name, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
                    "meshes": len(doc.get("meshes", [])), "skins": len(doc.get("skins", [])),
                    "animations": len(doc.get("animations", [])),
                    "joints": len(doc["skins"][0]["joints"]) if doc.get("skins") else 0,
                    "bounds_blender": {"min": [round(min(p[i] for p in points), 5) for i in range(3)],
                                       "max": [round(max(p[i] for p in points), 5) for i in range(3)]}})


for role in ("diver", "skitter", "lancer", "spitter", "shield", "charger", "tender",
             "bellkeeper", "warden", "kiln", "twin_sun", "twin_moon", "crown"):
    actor(role)
for tier in range(4):
    weapon(tier)
for name in (["terrain_" + str(i) for i in range(4)] + ["palm", "rock", "coral", "fence", "door", "forge",
             "salvage", "boat", "beacon", "kiln_arch", "wreck", "crystal_spire", "buoy", "chain_link"]):
    prop(name)
(ROOT / "manifest.json").write_text(json.dumps({"generator": "source/build_assets.py",
    "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    "generator_lf_sha256": hashlib.sha256(Path(__file__).read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
    "blender": bpy.app.version_string, "rendered": False, "original": True,
    "coordinates": "Blender +Y forward +Z up; glTF -Z forward +Y up", "assets": RECORDS}, indent=2) + "\n")
print("HOOK_KIT_COMPLETE", len(RECORDS))
