"""Original Frontline kit. Blender 4.5 LTS, CPU-only export; never renders.

Run: blender --background --factory-startup --python build_assets.py
All geometry/materials/rigs are authored here; no external artwork or textures.
Godot owns animation timing in scripts/presentation/actor.gd. The rigid-weighted
armature deliberately preserves the toy-sculpted joints without rubber limbs.
"""
import math
import hashlib
import json
import struct
import sys
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


def export(name, merge=False):
    if merge:
        merge_static_surfaces()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB",
                              export_yup=True, export_animations=False,
                              export_skins=True, export_extras=True, export_texcoords=False)
    canonicalize(OUT / (name + ".glb"))


def merge_static_surfaces():
    groups = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or len(obj.data.materials) != 1 or obj.name.startswith(("Wheel", "Hub", "Cannon", "SupplyToken")):
            continue
        if any(mod.type == "ARMATURE" for mod in obj.modifiers):
            continue
        key = (obj.parent.name if obj.parent else "", obj.data.materials[0].name)
        groups.setdefault(key, []).append(obj)
    for key, objects in sorted(groups.items()):
        objects.sort(key=lambda obj: obj.name)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        objects[0].name = "Surface_" + key[1]


def pivot(name, point, children):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = point
    bpy.context.view_layer.update()
    for child in children:
        child.parent = obj
        child.matrix_parent_inverse = obj.matrix_world.inverted()
    return obj


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


def soldier(variant="rifle"):
    clear()
    uniform = material("Uniform", (0.94, 0.64, 0.065))
    vest = material("Vest", (0.64, 0.42, 0.045))
    skin = material("Skin", (0.83, 0.55, 0.30))
    dark = material("Rubber", (0.065, 0.085, 0.09))
    steel = material("Gunmetal", (0.16, 0.22, 0.23), 0.45, 0.2)
    trim = material("Trim", (0.96, 0.84, 0.39))
    glass = material("Visor", (0.085, 0.19, 0.21), 0.22, 0.12)
    heft = 1.14 if variant in ["breaker", "bulwark"] else 1.0
    block("Tunic", (0, 0, .84), (.49 * heft, .30, .45), uniform, .09, "Torso")
    block("ArmoredVest", (0, .14, .86), (.43 * heft, .13, .32), vest, .055, "Torso")
    block("Belt", (0, .015, .64), (.49, .34, .085), dark, .025, "Torso")
    block("Buckle", (0, .20, .64), (.095, .045, .08), trim, .015, "Torso")
    for side in [-1, 1]:
        block("ChestPocket", (side * .115, .22, .86), (.16, .085, .15), uniform, .025, "Torso")
        block("Webbing", (side * .19, .18, .99), (.045, .05, .20), dark, .01, "Torso")
    block("Backpack", (0, -.21, .86), (.28 if variant == "runner" else .36, .16 if variant == "runner" else .20, .27 if variant == "runner" else .35), vest, .065, "Torso")
    block("PackRoll", (0, -.24, 1.06), (.36, .17, .13), uniform, .055, "Torso")
    oval("Neck", (0, 0, 1.075), (.105, .10, .12), skin, "Head")
    oval("Face", (0, .015, 1.19), (.205, .18, .22), skin, "Head")
    oval("HelmetDome", (0, -.005, 1.32), (.225, .215, .125) if variant == "runner" else ((.275, .25, .20) if variant == "bulwark" else (.25, .23, .19)), uniform, "Head")
    block("HelmetRim", (0, .035, 1.285), (.51, .44, .055), uniform, .025, "Head")
    block("Goggles", (0, .183, 1.225), (.34, .075, .10), dark, .035, "Head")
    for side in [-1, 1]:
        block("Lens", (side * .083, .225, 1.23), (.125, .025, .06), glass, .015, "Head")
        oval("EarDefender", (side * .214, -.02, 1.20), (.055, .09, .10), vest, "Head")
    block("HelmetStripe", (0, .211, 1.34), (.11, .018, .09), trim, .01, "Head")
    for side, suffix in [(-1, "L"), (1, "R")]:
        block("Thigh" + suffix, (side * .135, 0, .49), (.215, .235, .28), uniform, .07, "Thigh" + suffix)
        block("Knee" + suffix, (side * .135, .11, .345), (.19, .075, .13), vest, .045, "Shin" + suffix)
        block("Shin" + suffix, (side * .135, -.005, .235), (.17, .19, .22), uniform, .05, "Shin" + suffix)
        block("Boot" + suffix, (side * .135, .075, .095), (.22, .35, .19), dark, .055, "Foot" + suffix)
        block("Sole" + suffix, (side * .135, .085, .027), (.23, .36, .055), steel, .02, "Foot" + suffix)
        oval("Shoulder" + suffix, (side * .293, 0, .98), (.13, .16, .16), uniform, "UpperArm" + suffix)
        if heft > 1:
            block("BallisticShoulder" + suffix, (side * .32, -.015, 1.01), (.24, .28, .19), vest, .065, "UpperArm" + suffix)
        block("UpperSleeve" + suffix, (side * .315, .015, .88), (.19, .23, .25), uniform, .075, "UpperArm" + suffix)
        if suffix == "L":
            forearm = block("SupportForearm", (-.05, .28, .755), (.17, .61, .15), uniform, .06, "ForearmL")
            forearm.rotation_euler.z = -.77
            oval("SupportGlove", (.20, .53, .75), (.09, .105, .085), dark, "HandL")
        else:
            block("TriggerForearm", (.30, .13, .755), (.17, .27, .15), uniform, .06, "ForearmR")
            oval("TriggerGlove", (.27, .26, .75), (.09, .105, .085), dark, "HandR")
    muzzle_tip = (.22, .955, .79)
    if variant in ["breaker", "mortar"]:
        cylinder("LauncherBody", (.22, .55, .80), .11 if variant == "breaker" else .13, .78, steel, "Weapon", (math.pi / 2, 0, 0))
        cylinder("LauncherMuzzle", (.22, .94, .80), .14, .08, dark, "Weapon", (math.pi / 2, 0, 0))
        block("LauncherGrip", (.22, .31, .68), (.12, .16, .22), dark, .03, "Weapon")
        block("LauncherSight", (.22, .46, .94), (.06, .17, .05), trim, .01, "Weapon")
        muzzle_tip = (.22, .995, .80)
    elif variant == "ranger":
        block("RangerReceiver", (.22, .38, .78), (.15, .43, .15), steel, .025, "Weapon")
        block("RangerStock", (.22, .08, .78), (.13, .28, .14), dark, .035, "Weapon")
        block("RangerMagazine", (.22, .34, .67), (.10, .14, .21), dark, .025, "Weapon")
        cylinder("LongRifleBarrel", (.22, .82, .79), .043, .59, steel, "Weapon", (math.pi / 2, 0, 0))
        cylinder("RangerMuzzle", (.22, 1.13, .79), .057, .06, dark, "Weapon", (math.pi / 2, 0, 0))
        block("ScopeMount", (.22, .48, .88), (.10, .20, .10), steel, .02, "Weapon")
        cylinder("RangerOptic", (.22, .48, .96), .065, .27, dark, "Weapon", (math.pi / 2, 0, 0))
        cylinder("OpticLens", (.22, .618, .96), .048, .012, glass, "Weapon", (math.pi / 2, 0, 0))
        muzzle_tip = (.22, 1.165, .79)
    elif variant == "jammer":
        block("EmitterHousing", (.22, .43, .80), (.22, .32, .20), steel, .055, "Weapon")
        cylinder("EmitterCoil", (.22, .69, .82), .11, .12, dark, "Weapon", (math.pi / 2, 0, 0))
        cylinder("EmitterFace", (.22, .755, .82), .077, .02, glass, "Weapon", (math.pi / 2, 0, 0))
        muzzle_tip = (.22, .78, .82)
    elif variant == "sapper":
        block("Detonator", (.22, .40, .78), (.25, .26, .20), vest, .04, "Weapon")
        block("DetonatorLever", (.22, .40, .91), (.07, .20, .045), steel, .015, "Weapon")
        muzzle_tip = (.22, .55, .79)
    else:
        block("RifleReceiver", (.22, .38, .78), (.14, .34 if variant == "runner" else .43, .14), steel, .025, "Weapon")
        block("RifleStock", (.22, .09, .78), (.12, .25, .13), dark, .035, "Weapon")
        block("RifleMagazine", (.22, .34, .68), (.10, .13, .20), dark, .025, "Weapon")
        cylinder("RifleBarrel", (.22, .65 if variant == "runner" else .72, .79), .041, .15 if variant == "runner" else .35, steel, "Weapon", (math.pi / 2, 0, 0))
        block("Sight", (.22, .43, .885), (.05, .12, .045), dark, .01, "Weapon")
        cylinder("Muzzle", (.22, .75 if variant == "runner" else .91, .79), .052, .05 if variant == "runner" else .075, dark, "Weapon", (math.pi / 2, 0, 0))
        if variant == "runner":
            muzzle_tip = (.22, .79, .79)
    positions = {"Root": (0, 0, 0), "Torso": (0, 0, .64), "Head": (0, 0, 1.07)}
    parents = {"Torso": "Root", "Head": "Torso"}
    for side, suffix in [(-1, "L"), (1, "R")]:
        for name, point, parent in [
            ("Thigh", (side * .135, 0, .63), "Root"),
            ("Shin", (side * .135, 0, .35), "Thigh" + suffix),
            ("Foot", (side * .135, 0, .12), "Shin" + suffix),
            ("UpperArm", (side * .29, 0, 1.01), "Torso"),
            ("Forearm", (side * .315, .02, .79), "UpperArm" + suffix),
            ("Hand", (side * .29, .23, .75), "Forearm" + suffix),
        ]:
            positions[name + suffix] = point
            parents[name + suffix] = parent
    positions["Weapon"] = (.22, .26, .78)
    positions["HandL"] = (.20, .53, .75)
    parents["Weapon"] = "HandR"
    positions["PrimaryMuzzle"] = muzzle_tip
    parents["PrimaryMuzzle"] = "Weapon"
    arm = bpy.data.armatures.new("FoundryRigidRig")
    rig = bpy.data.objects.new("FoundryRig", arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, point in positions.items():
        bone = arm.edit_bones.new(name)
        bone.head = point
        bone.tail = (point[0], point[1], point[2] + .12)
        if name in parents:
            bone.parent = arm.edit_bones[parents[name]]
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj, bone in PARTS:
        group = obj.vertex_groups.new(name=bone)
        group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        modifier = obj.modifiers.new("Rigid toy rig", "ARMATURE")
        modifier.object = rig
        obj.parent = rig
    # Seven shared surfaces, not sixty-one draws per soldier. Joining preserves
    # rigid vertex groups and the common armature modifier.
    groups = [[obj for obj, _ in PARTS if obj.data.materials[0] == mat]
              for mat in [uniform, vest, skin, dark, steel, trim, glass]]
    for mat, objects in zip([uniform, vest, skin, dark, steel, trim, glass], groups):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        objects[0].name = "SoldierSurface_" + mat.name
    rig["provenance"] = "Original deterministic Frontline soldier, no external assets"
    rig["forward"] = "+Y Blender / -Z glTF"
    export("soldier" if variant == "rifle" else "soldier_" + variant)


def props():
    clear()
    sand = material("Sandbag", (.43, .51, .25))
    # Flattened filled sack silhouette with a seam rather than a sharp box.
    block("Sandbag", (0, 0, .20), (.87, .45, .40), sand, .145)
    block("StitchedSeam", (0, -.222, .20), (.65, .012, .018), material("Seam", (.35, .40, .19)), .005)
    export("sandbag")
    clear()
    rock = material("Rock", (.37, .45, .49))
    snow = material("Snow", (.78, .86, .87))
    block("CliffStone", (0, 0, -.48), (1.8, 1.6, 1.75), rock, .24)
    block("SnowCap", (0, 0, .43), (1.87, 1.68, .27), snow, .16)
    export("cliff")
    clear()
    olive = material("Olive", (.25, .39, .23))
    light = material("Roof", (.39, .53, .29))
    metal = material("Metal", (.16, .24, .24))
    block("HQWalls", (0, 0, .49), (2.30, .92, .98), olive, .12)
    block("HQRoof", (0, 0, 1.03), (2.58, 1.12, .22), light, .10)
    block("Door", (0, .469, .38), (.40, .045, .71), metal, .04)
    for x in [-.73, .73]:
        block("WindowFrame", (x, .48, .61), (.43, .045, .35), metal, .025)
        block("Window", (x, .51, .61), (.33, .025, .25), material("Window", (.45, .70, .72), .3), .015)
    cylinder("Antenna", (.80, -.25, 1.42), .035, .82, metal)
    oval("SignalTip", (.80, -.25, 1.84), (.07, .07, .07), material("Signal", (.94, .66, .13)))
    block("Steps", (0, .63, .09), (.65, .38, .18), metal, .045)
    export("headquarters")
    clear()
    block("BenchTop", (0, 0, .62), (1.12, .55, .13), material("Wood", (.49, .35, .20)), .04)
    for x in [-.43, .43]:
        block("BenchFoot", (x, 0, .30), (.12, .44, .60), metal, .025)
    for x in [-.31, 0, .31]:
        block("RifleRack", (x, -.17, .86), (.09, .10, .50), metal, .02)
        block("Stock", (x, -.17, .67), (.13, .13, .17), olive, .035)
    block("SupplyBox", (0, .10, .76), (.30, .28, .17), light, .035)
    export("equipment")
    clear()
    block("Crate", (0, 0, .28), (.62, .56, .56), olive, .055)
    for x in [-.22, .22]:
        block("CrateBand", (x, 0, .29), (.045, .575, .56), metal, .015)
    block("Latch", (0, .29, .28), (.12, .04, .12), light, .015)
    export("crate")


def rover():
    clear()
    olive = material("Uniform", (.24, .43, .26))
    rubber = material("Rubber", (.07, .10, .11))
    steel = material("Gunmetal", (.17, .25, .25), .45, .2)
    block("Hull", (0, 0, .43), (.92, 1.18, .48), olive, .14)
    block("Bonnet", (0, .40, .58), (.85, .40, .25), olive, .08)
    turret = block("Turret", (0, -.14, .78), (.56, .54, .30), olive, .10)
    cannon = cylinder("Cannon", (0, .55, .86), .075, .85, steel, rotation=(math.pi / 2, 0, 0))
    pivot = bpy.data.objects.new("TurretPivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.location = (0, -.14, .78)
    bpy.context.view_layer.update()
    for child in [turret, cannon]:
        child.parent = pivot
        child.matrix_parent_inverse = pivot.matrix_world.inverted()
    for x in [-.48, .48]:
        for y in [-.42, .42]:
            cylinder("Wheel", (x, y, .24), .25, .18, rubber, rotation=(0, math.pi / 2, 0))
            cylinder("Hub", (x * 1.20, y, .24), .12, .025, steel, rotation=(0, math.pi / 2, 0))
    for x in [-.29, .29]:
        block("Headlamp", (x, .61, .49), (.16, .04, .13), material("Trim", (.96, .80, .34)), .035)
    export("rover")
    clear()
    cylinder("SentryPlinth", (0, 0, .17), .38, .34, steel)
    block("SentryHousing", (0, 0, .51), (.45, .42, .38), olive, .09)
    cylinder("SentryBarrel", (0, .36, .61), .06, .60, steel, rotation=(math.pi / 2, 0, 0))
    block("SentrySight", (0, .06, .76), (.10, .17, .08), material("Trim", (.96, .80, .34)), .02)
    export("sentry")


def role_kits():
    olive = material("Uniform", (.24, .43, .26))
    red = material("EnemyKit", (.48, .13, .10))
    dark = material("Rubber", (.07, .10, .11))
    steel = material("Gunmetal", (.17, .25, .25), .45, .2)
    brass = material("KitBrass", (.66, .52, .23), .6, .1)
    for role in ["bulwark", "mortar", "jammer", "sapper", "breaker", "ranger", "storm", "carrier"]:
        clear()
        if role == "bulwark":
            block("ShieldBody", (-.33, .34, .69), (.48, .15, .81), red, .09)
            block("ShieldRim", (-.33, .43, .68), (.42, .035, .71), steel, .07)
            block("ShieldViewport", (-.33, .46, .89), (.23, .025, .09), dark, .025)
            block("ShieldBadge", (-.33, .46, .59), (.17, .025, .18), red, .04)
        elif role == "mortar":
            x = 0
            y = -.29
            cylinder("LauncherTube", (x, y, .98), .11, .65, steel, rotation=(.35, 0, 0))
            cylinder("LauncherRim", (x, y - .10, 1.29), .135, .08, brass)
            block("LauncherPack", (x, y - .02, .74), (.33, .25, .32), red if role == "mortar" else olive, .06)
        elif role == "breaker":
            block("AmmoPack", (0, -.29, .91), (.40, .24, .43), olive, .06)
            for x in [-.12, .12]:
                cylinder("SpareRocket", (x, -.30, 1.03), .065, .50, brass)
        elif role == "jammer":
            block("RadioPack", (0, -.29, .91), (.38, .22, .40), red, .07)
            cylinder("Aerial", (.14, -.31, 1.43), .018, .76, steel)
            oval("AerialTip", (.14, -.31, 1.82), (.045, .045, .045), brass)
            for z in [.80, .91, 1.02]:
                block("RadioVent", (0, -.408, z), (.25, .02, .025), dark, .008)
        elif role == "sapper":
            block("ChargeHarness", (0, .25, .83), (.40, .18, .23), dark, .04)
            for x in [-.13, 0, .13]:
                cylinder("Charge", (x, .37, .84), .052, .22, brass)
        elif role == "ranger":
            block("SpotterPack", (0, -.29, .92), (.32, .20, .31), olive, .055)
            for x in [-.09, .09]:
                cylinder("SpareOptic", (x, -.30, 1.15), .054, .16, dark)
        elif role == "storm":
            for x in [-.36, .36]:
                block("MissileCradle", (x, -.1, 1.12), (.30, .74, .32), red, .06)
                for dx in [-.065, .065]:
                    cylinder("MissileTube", (x + dx, .14, 1.15), .055, .73, steel, rotation=(math.pi / 2, 0, 0))
        elif role == "carrier":
            block("RepairTank", (0, -.25, 1.10), (.75, .65, .36), material("Ivory", (.83, .80, .61)), .10)
            for x in [-.22, .22]:
                cylinder("RepairCanister", (x, -.29, 1.30), .10, .38, brass, rotation=(math.pi / 2, 0, 0))
        export("kit_" + role)


def manifest():
    assets = []
    for path in sorted(OUT.glob("*.glb")):
        raw = path.read_bytes()
        length = struct.unpack_from("<I", raw, 12)[0]
        doc = json.loads(raw[20:20 + length])
        triangles = sum(doc["accessors"][p["indices"]]["count"] // 3
                        for mesh in doc.get("meshes", []) for p in mesh["primitives"])
        assets.append({"file": "models/" + path.name, "sha256": hashlib.sha256(raw).hexdigest(),
                       "bytes": len(raw), "triangles": triangles, "mesh_nodes": len(doc.get("meshes", [])),
                       "materials": [m["name"] for m in doc.get("materials", [])],
                       "skin_joints": [len(s["joints"]) for s in doc.get("skins", [])]})
    record = {"schema_version": 1, "authorship": "Original deterministic Frontline geometry; no imported third-party art, textures or paid assets",
              "blender": "4.5.14 LTS 62c1db4208e8",
              "portable_archive_sha256": "b9533d2397ac1984db4466fb23a7a4649391cca93f6e84209f9bcc60d071c8b9",
              "generator": "source/build_assets.py", "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "generator_sources_sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(Path(__file__).parent.glob("*.py"))},
              "units": "meters; +Y Blender forward exports -Z Godot; right-handed glTF Y-up",
              "animation": {"source": "scripts/presentation/actor.gd", "method": "Runtime rigid-weight skeleton poses, not baked glTF tracks", "states": ["idle", "run with analytic two-link stance/swing", "equip", "upper-body aim", "fire/recoil", "hit", "fallen", "victory"], "root_motion": False},
              "acceptance": "Structural export only; visible quality and frame-time measurement require actual rendered review",
              "assets": assets}
    (OUT.parent / "manifest.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")


soldier()
for variant in ["runner", "breaker", "ranger", "bulwark", "mortar", "jammer", "sapper"]:
    soldier(variant)
props()
rover()
role_kits()
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).parent))
from world_kit import build
build(globals())
from scenery_kit import build as build_scenery
build_scenery(globals())
manifest()
print("FRONTLINE_ASSET_EXPORT_COMPLETE", OUT)
