"""Original Dead Run coastal-evacuation kit; Blender 4.5.14, CPU export only.

No downloaded geometry, images or libraries. Blender +Y forward / +Z up becomes
Godot -Z forward / +Y up. Characters are rigid-skinned modeled segments on an
eighteen-joint armature; runtime poses articulate them from rule state.
Run: blender --background --factory-startup --threads 2 --python this_file
Pattern adapted from this portfolio's Hook and Hunger generator (same author).
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


GLOW = {"Eye glow", "Spitter sac", "Bell glow", "Eater core", "Lamp glow", "Gate light"}
# Final authored sRGB palette. Each part carries its color as a vertex color;
# every asset exports as one opaque "Palette" mesh plus an optional unshaded
# "Glow" mesh, so a crowd actor costs one or two draw calls.
M = {n: c for n, c in [
    ("Crew blue", "2f6fd6"), ("Crew navy", "1d3260"), ("Crew vest", "33465e"), ("Helmet", "2a5cb8"),
    ("Visor", "9fe8ff"), ("Skin", "e0a77e"), ("Gun metal", "2b2f36"), ("Boot", "22262c"),
    ("Strap", "6a5236"), ("Infected skin", "8fa77a"), ("Rot", "56664a"), ("Torn cloth", "7a6656"),
    ("Runner cloth", "c8553d"), ("Runner skin", "b48f80"), ("Plate steel", "8a949c"), ("Rust", "a2603a"),
    ("Spitter sac", "c8e04a"), ("Spore", "b06ad6"), ("Fungus cap", "8e4fb5"), ("Bulwark hide", "6b5568"),
    ("Concrete", "a8a49a"), ("Eye glow", "ffd84a"), ("Asphalt", "737b88"), ("Asphalt patch", "666d79"), ("Curb", "b9b4a6"),
    ("Road paint", "f2e3b0"), ("Steel", "7f8a92"), ("Hazard yellow", "f2c230"), ("Hazard red", "d8453a"),
    ("White paint", "f3f1ea"), ("Wood", "9b6b43"), ("Crate", "b98552"), ("Tyre", "26282c"),
    ("Glass", "9fd6e8"), ("Lamp glow", "ffe7a0"), ("Palm trunk", "8a6a48"), ("Leaf", "4f9c58"),
    ("Container blue", "3a78b5"), ("Container orange", "d9773a"), ("Container teal", "3aa39a"),
    ("Facade", "c9b9a0"), ("Facade dark", "7d7f86"), ("Roof", "6a5048"), ("Window", "39495a"),
    ("Awning red", "d8554a"), ("Awning cream", "f3ece0"), ("Seawall", "9a9f9a"), ("Ferry white", "f1f1ec"),
    ("Ferry red", "c8463e"), ("Ferry hull", "2b3a55"), ("Car red", "c24a3c"), ("Car teal", "3f8f95"),
    ("Car cream", "e2d6b0"), ("Tank white", "d8dcd6"), ("Pipe green", "4f8a6e"), ("Pump orange", "e08a2e"),
    ("Rope", "c9b38a"), ("Survivor", "6fa8e8"), ("Matron hide", "9a6a7a"), ("Cable", "2f3238"),
    ("Ram hide", "7a5f4a"), ("Bell shell", "7a5a8e"), ("Bell glow", "e0ff7a"), ("Eater hide", "3f6a6a"),
    ("Eater core", "ff8a3a"), ("Gate frame", "e8edf2"), ("Gate light", "ffffff"), ("Sandbag", "a89a72")]}


def material(name):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        shader = m.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Roughness"].default_value = .75
        attr = m.node_tree.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        m.node_tree.links.new(attr.outputs["Color"], shader.inputs["Base Color"])
        MATS[name] = m
    return MATS[name]


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)
    PARTS.clear()


def finish(obj, name, mat, bone=None):
    # Rebuild with deterministic triangle order before export.
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
    obj.data.name = name + "Mesh"
    rgb = tuple(int(M[mat][i:i + 2], 16) / 255 for i in (0, 2, 4))
    layer = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for item in layer.data:
        item.color = (*rgb, 1)  # glTF COLOR_0 then carries the sRGB values Godot expects
    obj.data.materials.append(material("Glow" if mat in GLOW else "Palette"))
    if bone:
        PARTS.append((obj, bone))
    return obj


def block(name, at, size, mat, bone=None, bevel=.05, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new("Rounded sculpted rim", "BEVEL")
    mod.width = min(bevel, min(size) * .4)
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if rot:
        obj.rotation_euler = rot
    return finish(obj, name, mat, bone)


def oval(name, at, size, mat, bone=None, rot=None, seg=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=at)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for f in obj.data.polygons:
        f.use_smooth = True
    if rot:
        obj.rotation_euler = rot
    return finish(obj, name, mat, bone)


def cyl(name, at, radius, height, mat, bone=None, top=None, verts=12, rot=None, smooth=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius,
                                  radius2=radius if top is None else top,
                                  depth=height, location=at)
    obj = bpy.context.object
    if smooth:
        for f in obj.data.polygons:
            f.use_smooth = len(f.vertices) == 4
    if rot:
        obj.rotation_euler = rot
    return finish(obj, name, mat, bone)


def beam(name, a, b, radius, mat, bone=None, top=None, verts=10):
    a, b = Vector(a), Vector(b)
    rot = (b - a).to_track_quat("Z", "Y").to_euler()
    return cyl(name, tuple((a + b) / 2), radius, (b - a).length, mat, bone, top, verts, rot)


def torus(name, at, radius, tube, mat, bone=None, rot=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=18, minor_segments=6,
                                   location=at, major_radius=radius, minor_radius=tube)
    obj = bpy.context.object
    for f in obj.data.polygons:
        f.use_smooth = True
    if rot:
        obj.rotation_euler = rot
    return finish(obj, name, mat, bone)


# ---------------------------------------------------------------- characters
# Joint layout shared by every humanoid. Proportions vary per role.
def rig(p):
    bpy.ops.object.armature_add()
    arm = bpy.context.object
    arm.name = "RunnerRig"
    arm.data.name = "RunnerRigData"
    bpy.ops.object.mode_set(mode="EDIT")
    arm.data.edit_bones.remove(arm.data.edit_bones[0])
    hw, sw = p["hip_w"], p["sh_w"]
    specs = [("Root", (0, 0, 0), None), ("Torso", (0, 0, p["hip_z"] + .08), "Root"),
             ("Head", (0, p["head_y"], p["neck_z"]), "Torso"), ("Crest", (0, p["head_y"], p["neck_z"] + .30), "Head"),
             ("Weapon", (p["weapon"][0], p["weapon"][1], p["weapon"][2]), "Torso"),
             ("Muzzle", tuple(p["muzzle"]), "Weapon"), ("Tail", (0, -.25, p["hip_z"]), "Root")]
    for side, s in ((-1, "L"), (1, "R")):
        specs += [("Thigh" + s, (side * hw, 0, p["hip_z"]), "Root"),
                  ("Shin" + s, (side * hw, .02, p["knee_z"]), "Thigh" + s),
                  ("Foot" + s, (side * hw, 0, p["ankle_z"]), "Shin" + s),
                  ("Arm" + s, (side * sw, 0, p["sh_z"]), "Torso"),
                  ("Forearm" + s, (side * p["elbow"][0], p["elbow"][1], p["elbow"][2]), "Arm" + s),
                  ("Hand" + s, (side * p["wrist"][0], p["wrist"][1], p["wrist"][2]), "Forearm" + s)]
    for name, point, parent in specs:
        bone = arm.data.edit_bones.new(name)
        bone.head = point
        bone.tail = Vector(point) + Vector((0, 0, .10))
        if parent:
            bone.parent = arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj, bone in PARTS:
        group = obj.vertex_groups.new(name=bone)
        group.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
        mod = obj.modifiers.new("Rigid squad skin", "ARMATURE")
        mod.object = arm
        obj.parent = arm
    # Small authored breathing clip proves imported channels; runtime poses
    # are procedural and sampled from rule-owned state only.
    chest = arm.pose.bones["Torso"]
    chest.rotation_mode = "XYZ"
    for frame, angle in ((1, -.03), (16, .03), (31, -.03)):
        chest.rotation_euler.x = angle
        chest.keyframe_insert(data_path="rotation_euler", frame=frame)
    arm.animation_data.action.name = "AuthoredBreath"
    bpy.context.scene.frame_set(1)
    return arm


def limbs(p, leg_mat, boot_mat, arm_mat, hand_mat, thick=1.0, knee_mat=None):
    for side, s in ((-1, "L"), (1, "R")):
        hx = side * p["hip_w"]
        top, knee, ankle = p["hip_z"], p["knee_z"], p["ankle_z"]
        block("Thigh" + s, (hx, 0, (top + knee) / 2 + .02), (.17 * thick, .19 * thick, top - knee + .06), leg_mat, "Thigh" + s, .05)
        oval("Knee" + s, (hx, .03, knee), (.095 * thick, .10 * thick, .09), knee_mat or leg_mat, "Shin" + s)
        block("Shin" + s, (hx, .01, (knee + ankle) / 2), (.15 * thick, .17 * thick, knee - ankle + .04), leg_mat, "Shin" + s, .05)
        block("Boot" + s, (hx, .05, ankle * .55), (.18 * thick, .30 * thick, ankle * 1.1 + .02), boot_mat, "Foot" + s, .05)
        sx, sz = side * p["sh_w"], p["sh_z"]
        ex, ey, ez = side * p["elbow"][0], p["elbow"][1], p["elbow"][2]
        wx, wy, wz = side * p["wrist"][0], p["wrist"][1], p["wrist"][2]
        oval("Shoulder" + s, (sx, 0, sz), (.105 * thick, .13 * thick, .11 * thick), arm_mat, "Arm" + s)
        beam("Upper arm" + s, (sx, 0, sz), (ex, ey, ez), .075 * thick, arm_mat, "Arm" + s)
        beam("Forearm" + s, (ex, ey, ez), (wx, wy, wz), .068 * thick, arm_mat, "Forearm" + s)
        oval("Hand" + s, (wx, wy + .03, wz), (.075 * thick, .085 * thick, .075 * thick), hand_mat, "Hand" + s)


# Shoulders are kept narrow: at runtime scale each soldier stays inside the
# rule's 0.24 m member half-width, so the gold footprint bounds every body.
CREW = {"hip_w": .10, "hip_z": .56, "knee_z": .32, "ankle_z": .11, "sh_w": .19, "sh_z": 1.04,
        "neck_z": 1.16, "head_y": .02, "elbow": (.21, .16, .86), "wrist": (.10, .34, .90),
        "weapon": (.07, .20, .93), "muzzle": (.07, .86, .97)}


def crew():
    clear()
    p = CREW
    block("Belt", (0, 0, .60), (.40, .28, .10), "Strap", "Root")
    oval("Torso", (0, 0, .84), (.22, .16, .26), "Crew blue", "Torso")
    block("Tactical vest", (0, .01, .86), (.38, .34, .36), "Crew vest", "Torso", .09)
    block("Vest pouch", (-.10, .17, .78), (.10, .06, .10), "Strap", "Torso")
    block("Vest pouch2", (.10, .17, .78), (.10, .06, .10), "Strap", "Torso")
    block("Shoulder strap", (0, .175, .95), (.36, .04, .05), "Crew navy", "Torso")
    block("Backpack", (0, -.22, .88), (.30, .14, .32), "Crew navy", "Torso", .06)
    block("Bedroll", (0, -.24, 1.07), (.30, .12, .10), "Rope", "Torso", .05)
    oval("Neck", (0, 0, 1.12), (.07, .07, .06), "Skin", "Head")
    oval("Face", (0, .03, 1.27), (.15, .145, .15), "Skin", "Head")
    oval("Helmet", (0, 0, 1.36), (.185, .195, .13), "Helmet", "Head")
    block("Helmet brim", (0, .06, 1.30), (.36, .34, .04), "Helmet", "Head", .02)
    block("Goggles", (0, .155, 1.31), (.24, .05, .065), "Visor", "Head", .025)
    block("Goggle strap", (0, .02, 1.315), (.32, .26, .04), "Gun metal", "Head", .015)
    block("Chin", (0, .11, 1.19), (.12, .06, .05), "Skin", "Head", .02)
    limbs(p, "Crew navy", "Boot", "Crew blue", "Gun metal", 1.0, "Boot")
    # Two-handed carbine on the Weapon bone; Muzzle bone sits at the barrel tip.
    block("Carbine stock", (.07, .02, .93), (.06, .18, .09), "Gun metal", "Weapon", .02)
    block("Carbine body", (.07, .30, .95), (.075, .36, .10), "Gun metal", "Weapon", .02)
    block("Carbine magazine", (.07, .30, .87), (.05, .07, .12), "Steel", "Weapon", .02)
    beam("Carbine barrel", (.07, .46, .97), (.07, .84, .97), .022, "Gun metal", "Weapon")
    block("Carbine sight", (.07, .26, 1.02), (.03, .10, .04), "Crew blue", "Weapon", .01)
    rig(p)
    export("actor_crew")


INFECTED = {
    "drifter": {"hip_w": .11, "hip_z": .54, "knee_z": .31, "ankle_z": .10, "sh_w": .23, "sh_z": 1.00,
                "neck_z": 1.08, "head_y": .10, "elbow": (.26, .22, .98), "wrist": (.22, .44, 1.00),
                "weapon": (0, .1, .9), "muzzle": (0, .4, .9)},
    "runner": {"hip_w": .10, "hip_z": .60, "knee_z": .34, "ankle_z": .10, "sh_w": .21, "sh_z": 1.04,
               "neck_z": 1.12, "head_y": .14, "elbow": (.25, .04, .82), "wrist": (.26, .12, .64),
               "weapon": (0, .1, .9), "muzzle": (0, .4, .9)},
    "plated": {"hip_w": .12, "hip_z": .55, "knee_z": .31, "ankle_z": .10, "sh_w": .27, "sh_z": 1.02,
               "neck_z": 1.10, "head_y": .08, "elbow": (.30, .18, .92), "wrist": (.25, .38, .96),
               "weapon": (0, .1, .9), "muzzle": (0, .4, .9)},
    "spitter": {"hip_w": .12, "hip_z": .52, "knee_z": .30, "ankle_z": .10, "sh_w": .24, "sh_z": .98,
                "neck_z": 1.06, "head_y": .12, "elbow": (.30, .06, .80), "wrist": (.30, .16, .62),
                "weapon": (0, .1, .9), "muzzle": (0, .4, .9)},
    "cluster": {"hip_w": .09, "hip_z": .34, "knee_z": .20, "ankle_z": .07, "sh_w": .18, "sh_z": .62,
                "neck_z": .68, "head_y": .10, "elbow": (.22, .14, .52), "wrist": (.20, .30, .44),
                "weapon": (0, .1, .6), "muzzle": (0, .4, .6)},
    "bulwark": {"hip_w": .16, "hip_z": .58, "knee_z": .33, "ankle_z": .11, "sh_w": .36, "sh_z": 1.14,
                "neck_z": 1.20, "head_y": .16, "elbow": (.40, .22, .92), "wrist": (.30, .44, .86),
                "weapon": (0, .52, .88), "muzzle": (0, .7, .9)},
}


def infected(role):
    clear()
    p = INFECTED[role]
    skin = {"runner": "Runner skin", "cluster": "Spore", "bulwark": "Bulwark hide"}.get(role, "Infected skin")
    cloth = {"runner": "Runner cloth", "plated": "Rust", "spitter": "Rot", "cluster": "Fungus cap", "bulwark": "Torn cloth"}.get(role, "Torn cloth")
    thick = {"runner": .85, "bulwark": 1.55, "plated": 1.15, "spitter": 1.1, "cluster": .8}.get(role, 1.0)
    hz, sz, nz = p["hip_z"], p["sh_z"], p["neck_z"]
    block("Hips", (0, 0, hz + .02), (.32 * thick, .24 * thick, .14), cloth, "Root")
    chest_h = (sz - hz) * .9
    oval("Torso", (0, .03, (hz + sz) / 2 + .04), (.20 * thick, .16 * thick, chest_h * .62), cloth, "Torso")
    oval("Hunch", (0, -.06, sz - .04), (.20 * thick, .15 * thick, .13 * thick), skin, "Torso")
    head_r = {"cluster": .17, "bulwark": .15, "runner": .13}.get(role, .145)
    hy = p["head_y"]
    oval("Head", (0, hy, nz + head_r * .9), (head_r, head_r * 1.05, head_r * 1.05), skin, "Head")
    oval("Jaw", (0, hy + .07, nz + head_r * .35), (head_r * .7, head_r * .6, head_r * .45), "Rot", "Head")
    for side in (-1, 1):
        oval("Eye" + str(side), (side * head_r * .42, hy + head_r * .88, nz + head_r * 1.05), (.035, .02, .03), "Eye glow", "Head")
    limbs(p, cloth if role != "cluster" else skin, "Rot", skin, skin, thick)
    if role == "drifter":
        block("Torn shirt flap", (.06, .14, hz + .16), (.18, .05, .14), "Torn cloth", "Torso", .02, (0, .3, .2))
        oval("Fungal growth", (-.12, -.10, sz + .02), (.09, .08, .07), "Spore", "Torso")
    if role == "runner":
        block("Hood", (0, hy - .06, nz + .20), (.28, .28, .16), "Runner cloth", "Head", .06)
        block("Torn sleeve", (.20, .02, .90), (.10, .12, .14), "Runner cloth", "ArmR", .03)
    if role == "plated":
        block("Road-sign breastplate", (0, .19, (hz + sz) / 2 + .06), (.44, .07, .40), "Plate steel", "Torso", .03)
        block("Sign stripe", (0, .225, (hz + sz) / 2 + .14), (.40, .02, .07), "Hazard red", "Torso", .01)
        block("Sign stripe2", (0, .225, (hz + sz) / 2 + .00), (.40, .02, .07), "White paint", "Torso", .01)
        for side, s in ((-1, "L"), (1, "R")):
            block("Pauldron" + s, (side * .29, 0, sz + .05), (.20, .24, .08), "Rust", "Arm" + s, .03)
        block("Bucket helm", (0, hy, nz + .23), (.26, .26, .18), "Plate steel", "Head", .04)
        block("Helm slit", (0, hy + .13, nz + .22), (.18, .02, .03), "Eye glow", "Head", .01)
    if role == "spitter":
        oval("Throat sac", (0, hy + .15, nz - .06), (.16, .14, .13), "Spitter sac", "Head")
        for i, (x, z) in enumerate(((-.12, .92), (.10, .84), (.02, 1.0))):
            oval("Back pustule" + str(i), (x, -.17, z), (.07, .06, .07), "Spitter sac", "Torso")
    if role == "cluster":
        cyl("Fungus cap", (0, hy, nz + .30), .26, .10, "Fungus cap", "Crest", top=.12)
        for i in range(5):
            a = i * math.tau / 5
            oval("Cap spot" + str(i), (math.cos(a) * .17, hy + math.sin(a) * .17, nz + .33), (.04, .04, .025), "Spitter sac", "Crest")
        for i in range(3):
            cyl("Spore stalk" + str(i), ((i - 1) * .09, -.13, sz + .04), .03, .16, "Spore", "Torso", top=.012)
    if role == "bulwark":
        # A scavenged concrete slab carried as a shield on the Weapon bone.
        block("Barrier slab", (0, .52, .90), (.86, .14, .80), "Concrete", "Weapon", .06)
        block("Slab stripe", (0, .60, 1.12), (.80, .02, .10), "Hazard yellow", "Weapon", .01)
        block("Slab stripe2", (0, .60, .74), (.80, .02, .10), "Hazard yellow", "Weapon", .01)
        for x in (-.30, .30):
            cyl("Rebar" + str(x), (x, .52, 1.36), .02, .16, "Rust", "Weapon")
        oval("Brute hump", (0, -.16, sz + .05), (.32, .22, .20), "Bulwark hide", "Torso")
        for i in range(3):
            cyl("Bone spike" + str(i), ((i - 1) * .16, -.22, sz + .20), .05, .22, "Concrete", "Torso", top=0)
    rig(p)
    export("actor_" + role)


BOSS = {
    "matron": {"hip_w": .14, "hip_z": .62, "knee_z": .36, "ankle_z": .11, "sh_w": .34, "sh_z": 1.26,
               "neck_z": 1.36, "head_y": .12, "elbow": (.52, .10, 1.00), "wrist": (.62, .30, .78),
               "weapon": (0, -.2, 1.5), "muzzle": (0, -.2, 2.2)},
    "ram": {"hip_w": .18, "hip_z": .60, "knee_z": .34, "ankle_z": .11, "sh_w": .42, "sh_z": 1.18,
            "neck_z": 1.24, "head_y": .22, "elbow": (.50, .26, .92), "wrist": (.42, .52, .84),
            "weapon": (0, .62, .90), "muzzle": (0, .8, .9)},
}


def boss_humanoid(kind):
    clear()
    p = BOSS[kind]
    hz, sz, nz = p["hip_z"], p["sh_z"], p["neck_z"]
    if kind == "matron":
        hide = "Matron hide"
        block("Hips", (0, 0, hz + .02), (.40, .30, .18), "Torn cloth", "Root")
        oval("Torso", (0, 0, (hz + sz) / 2 + .06), (.30, .24, .38), hide, "Torso")
        oval("Bloated belly", (0, .12, hz + .22), (.26, .20, .22), "Spore", "Torso")
        for i in range(4):
            torus("Cable coil" + str(i), (0, 0, hz + .30 + i * .13), .30 - .02 * abs(i - 1.5), .03, "Cable", "Torso")
        oval("Head", (0, .12, nz + .16), (.17, .18, .19), hide, "Head")
        for side in (-1, 1):
            oval("Eye" + str(side), (side * .07, .28, nz + .20), (.04, .02, .035), "Eye glow", "Head")
        cyl("Hair cable mass", (0, .02, nz + .34), .20, .26, "Cable", "Crest", top=.06)
        limbs(p, "Torn cloth", "Rot", hide, "Steel", 1.3)
        for side, s in ((-1, "L"), (1, "R")):
            wx, wy, wz = side * p["wrist"][0], p["wrist"][1], p["wrist"][2]
            torus("Crane hook" + s, (wx, wy + .10, wz - .14), .11, .03, "Hazard yellow", "Hand" + s, (0, math.pi / 2, 0))
            beam("Arm cable" + s, (side * p["sh_w"], 0, sz), (wx, wy, wz), .025, "Cable", "Arm" + s)
        # Suspension cables run up out of frame from the shoulders.
        for x in (-.26, 0, .26):
            beam("Suspension cable" + str(x), (x, -.05, sz), (x * 1.6, -.15, 4.8), .025, "Cable", "Weapon")
        block("Cable harness", (0, -.12, sz + .02), (.60, .16, .10), "Hazard yellow", "Torso", .03)
    else:
        hide = "Ram hide"
        block("Hips", (0, 0, hz + .02), (.48, .34, .18), "Torn cloth", "Root")
        oval("Torso", (0, .02, (hz + sz) / 2 + .06), (.38, .28, .36), hide, "Torso")
        oval("Brute hump", (0, -.20, sz + .04), (.40, .26, .22), hide, "Torso")
        oval("Head", (0, .24, nz + .10), (.17, .19, .16), hide, "Head")
        for side in (-1, 1):
            oval("Eye" + str(side), (side * .08, .40, nz + .14), (.04, .02, .03), "Eye glow", "Head")
            beam("Ram horn" + str(side), (side * .12, .22, nz + .20), (side * .40, .34, nz + .10), .07, "Concrete", "Head", top=.02)
        limbs(p, "Torn cloth", "Rot", hide, hide, 1.6)
        # Toll barrier shield: striped arm and booth plate carried forward.
        block("Toll plate", (0, .64, .92), (1.10, .16, .92), "Plate steel", "Weapon", .07)
        for i in range(5):
            block("Toll stripe" + str(i), ((i - 2) * .21, .73, .92), (.10, .02, .86), "Hazard red" if i % 2 else "White paint", "Weapon", .01)
        block("Toll lamp housing", (0, .66, 1.44), (.30, .14, .14), "Gun metal", "Weapon", .03)
        oval("Toll lamp", (0, .70, 1.44), (.10, .06, .08), "Eye glow", "Weapon")
    rig(p)
    export("boss_" + kind)


def boss_rigid(kind):
    clear()
    if kind == "bell":
        cyl("Bell body", (0, 0, 1.55), 1.05, 1.5, "Bell shell", top=.45, verts=18)
        oval("Bell crown", (0, 0, 2.38), (.52, .52, .36), "Bell shell", seg=18)
        torus("Bell lip", (0, 0, .82), 1.02, .10, "Rot")
        oval("Bell glow core", (0, 0, .95), (.70, .70, .26), "Bell glow", seg=18)
        for i in range(8):
            a = i * math.tau / 8
            oval("Spore vent" + str(i), (math.cos(a) * .84, math.sin(a) * .84, 1.55 + .18 * (i % 2)), (.16, .16, .13), "Spitter sac")
        for i in range(6):
            a = i * math.tau / 6 + .3
            beam("Hanging tendril" + str(i), (math.cos(a) * .7, math.sin(a) * .7, .85), (math.cos(a) * .95, math.sin(a) * .95, .10), .05, "Spore", top=.015)
        for x in (-.3, .3):
            beam("Bell chain" + str(x), (x, 0, 2.6), (x * 2, 0, 5.2), .035, "Cable")
    elif kind == "ferry":
        oval("Eater torso", (0, 0, 1.4), (1.25, .95, 1.35), "Eater hide", seg=16, rings=10)
        oval("Eater shoulders", (0, -.15, 2.35), (1.55, .80, .55), "Eater hide", seg=16)
        oval("Eater head", (0, .55, 2.75), (.62, .58, .50), "Eater hide", seg=14)
        oval("Eater jaw", (0, .85, 2.45), (.52, .40, .26), "Rot", seg=12)
        for i in range(6):
            cyl("Eater tooth" + str(i), (-.32 + i * .13, 1.10, 2.52), .045, .18, "Concrete", top=0, rot=(math.pi, 0, 0))
        for side in (-1, 1):
            oval("Eater eye" + str(side), (side * .30, 1.0, 2.92), (.10, .05, .08), "Eye glow")
        oval("Exposed core", (0, .82, 1.45), (.45, .22, .45), "Eater core", seg=14)
        torus("Core ribs", (0, .78, 1.45), .52, .07, "Concrete", rot=(math.pi / 2, 0, 0))
        for i in range(5):
            a = i * math.tau / 5
            cyl("Barnacle" + str(i), (math.cos(a) * 1.0, -.2 + math.sin(a) * .5, 2.0 + .2 * (i % 2)), .16, .22, "Concrete", top=.06)
        cyl("Hull fragment", (.8, -.5, 2.9), .3, 1.2, "Ferry red", top=.25, rot=(.4, .3, 0))
    elif kind == "ferry_arm":
        for i in range(4):
            r = .42 - i * .06
            oval("Arm segment" + str(i), (0, i * .45, .5 + i * .38), (r, r, r * 1.1), "Eater hide")
        beam("Arm claw a", (0, 1.5, 1.7), (.30, 2.0, 1.2), .10, "Concrete", top=.02)
        beam("Arm claw b", (0, 1.5, 1.7), (-.30, 2.0, 1.2), .10, "Concrete", top=.02)
        for i in range(3):
            oval("Arm sucker" + str(i), (0, .2 + i * .45, .2 + i * .40), (.16, .10, .10), "Eater core")
    elif kind == "blockade":
        block("Blockade base", (0, 0, .25), (3.0, .9, .40), "Wood", bevel=.06)
        block("Car wreck", (-.70, 0, .80), (1.4, .80, .70), "Car red", bevel=.18)
        block("Car cabin", (-.70, -.05, 1.25), (.95, .70, .35), "Window", bevel=.10)
        block("Crate a", (.75, .05, .75), (.65, .65, .60), "Crate", bevel=.05)
        block("Crate b", (.95, -.05, 1.32), (.45, .45, .45), "Crate", bevel=.04)
        for i in range(5):
            block("Barrier stripe" + str(i), (-1.2 + i * .6, .48, .55), (.28, .06, .55), "Hazard red" if i % 2 else "White paint", bevel=.02)
        block("Barrier plank", (0, .44, .55), (3.0, .05, .14), "Wood", bevel=.02)
        for x in (-1.45, 1.45):
            cyl("Spike" + str(x), (x, .3, 1.0), .05, 1.4, "Rust", top=.0, rot=(-.5, 0, 0))
        oval("Fungal mass", (.2, -.2, 1.25), (.40, .35, .30), "Spore")
    export("boss_" + kind)


# -------------------------------------------------------------------- props
def prop(kind):
    clear()
    if kind == "road_tile":
        # Ten metres of road: asphalt, curbs, sidewalks, joints and drains.
        block("Asphalt", (0, 0, -.15), (9.3, 10.0, .30), "Asphalt", bevel=.02)
        for x in (-4.85, 4.85):
            block("Curb" + str(x), (x, 0, -.05), (.32, 10.0, .32), "Curb", bevel=.05)
            block("Sidewalk" + str(x), (x * 1.33, 0, -.10), (2.9, 10.0, .30), "Concrete", bevel=.04)
            for y in (-3.4, 1.6):
                block("Sidewalk joint" + str(x) + str(y), (x * 1.33, y, .052), (2.8, .04, .01), "Facade dark", bevel=.004)
        block("Expansion joint", (0, 4.2, .005), (9.2, .10, .02), "Facade dark", bevel=.005)
        for x in (-3.6, 3.6):
            block("Drain" + str(x), (x, -2.0, .006), (.55, .32, .02), "Gun metal", bevel=.01)
        for i in range(3):
            oval("Asphalt patch" + str(i), ((-2.5, 1.2, 2.9)[i], (-3.2, .8, 3.0)[i], -.02), ((.8, 1.1, .6)[i], (.6, .9, .8)[i], .03), "Asphalt patch", seg=10, rings=4)
    elif kind in ("road_cross", "road_mark"):
        block("Asphalt", (0, 0, -.15), (9.3, 10.0, .30), "Asphalt", bevel=.02)
        for x in (-4.85, 4.85):
            block("Curb" + str(x), (x, 0, -.05), (.32, 10.0, .32), "Curb", bevel=.05)
            block("Sidewalk" + str(x), (x * 1.33, 0, -.10), (2.9, 10.0, .30), "Concrete", bevel=.04)
            block("Sidewalk joint" + str(x), (x * 1.33, 0, .052), (2.8, .04, .01), "Facade dark", bevel=.004)
        if kind == "road_cross":
            for i in range(9):
                block("Crosswalk" + str(i), (-3.6 + i * .9, 1.0, .004), (.48, 2.6, .012), "White paint", bevel=.004)
            block("Stop line", (0, 2.7, .004), (8.6, .22, .012), "White paint", bevel=.004)
        else:
            for x in (-2.65, 2.65):
                block("Arrow shaft" + str(x), (x, -1.0, .004), (.20, 1.8, .012), "White paint", bevel=.004)
                for side in (-1, 1):
                    block("Arrow head" + str(x) + str(side), (x + side * .22, .05, .004), (.18, .75, .012), "White paint", bevel=.004, rot=(0, 0, side * .7))
            cyl("Manhole", (-1.0, 3.0, .006), .42, .02, "Steel", verts=16)
            cyl("Manhole rim", (-1.0, 3.0, .002), .50, .012, "Curb", verts=16)
            oval("Oil stain", (1.4, -3.5, -.02), (.9, .6, .03), "Asphalt patch", seg=10, rings=4)
    elif kind == "streetlight":
        cyl("Light base", (0, 0, .15), .14, .30, "Steel")
        cyl("Light pole", (0, 0, 2.0), .06, 3.8, "Steel", top=.045)
        beam("Light arm", (0, 0, 3.85), (.95, 0, 4.05), .04, "Steel")
        block("Light head", (1.05, 0, 3.98), (.42, .20, .10), "Gun metal", bevel=.03)
        block("Light lens", (1.05, 0, 3.92), (.34, .15, .03), "Lamp glow", bevel=.01)
    elif kind == "palm":
        for i in range(6):
            cyl("Trunk" + str(i), (.10 * i, 0, .32 + .55 * i), .17 - i * .014, .60, "Palm trunk")
        for i in range(8):
            a = i * math.tau / 8
            leaf = oval("Frond" + str(i), (.55 + .85 * math.cos(a), .85 * math.sin(a), 3.25), (1.05, .24, .09), "Leaf", rot=(0, .30, a))
        oval("Coconuts", (.55, 0, 3.15), (.22, .22, .18), "Palm trunk")
    elif kind == "car":
        block("Car body", (0, 0, .45), (1.7, 3.9, .55), "Car teal", bevel=.20)
        block("Car cabin", (0, -.25, .92), (1.45, 2.0, .48), "Car teal", bevel=.18)
        block("Car windows", (0, -.25, .95), (1.50, 1.85, .34), "Window", bevel=.12)
        block("Bumper front", (0, 1.95, .38), (1.6, .12, .18), "Steel", bevel=.05)
        block("Bumper rear", (0, -1.95, .38), (1.6, .12, .18), "Steel", bevel=.05)
        for x in (-.86, .86):
            for y in (-1.25, 1.25):
                cyl("Tyre" + str(x) + str(y), (x, y, .32), .32, .24, "Tyre", rot=(0, math.pi / 2, 0), verts=14)
        for x in (-.55, .55):
            block("Headlight" + str(x), (x, 1.96, .52), (.30, .04, .12), "Lamp glow", bevel=.02)
    elif kind == "van":
        block("Van body", (0, 0, 1.0), (1.9, 4.6, 1.55), "Car cream", bevel=.22)
        block("Van windshield", (0, 2.1, 1.35), (1.7, .30, .55), "Window", bevel=.10)
        block("Van stripe", (0, 0, .95), (1.94, 4.4, .18), "Hazard red", bevel=.05)
        for x in (-.95, .95):
            for y in (-1.5, 1.5):
                cyl("Tyre" + str(x) + str(y), (x, y, .35), .35, .26, "Tyre", rot=(0, math.pi / 2, 0), verts=14)
    elif kind == "barrier":
        block("Jersey base", (0, 0, .18), (2.2, .62, .36), "Concrete", bevel=.06)
        block("Jersey top", (0, 0, .58), (2.2, .32, .50), "Concrete", bevel=.08)
        for i in range(4):
            block("Barrier stripe" + str(i), (-.75 + i * .5, .17, .62), (.24, .02, .22), "Hazard red" if i % 2 else "White paint", bevel=.01)
    elif kind == "sandbags":
        for i in range(5):
            oval("Sandbag" + str(i), (-.9 + i * .45, 0, .16), (.26, .20, .15), "Sandbag")
        for i in range(4):
            oval("Sandbag top" + str(i), (-.68 + i * .45, .02, .42), (.26, .20, .15), "Sandbag")
    elif kind == "container":
        block("Container shell", (0, 0, 1.3), (2.45, 6.0, 2.6), "Container blue", bevel=.06)
        for i in range(9):
            block("Container rib" + str(i), (1.25, -2.6 + i * .65, 1.3), (.06, .20, 2.4), "Container blue", bevel=.02)
            block("Container rib b" + str(i), (-1.25, -2.6 + i * .65, 1.3), (.06, .20, 2.4), "Container blue", bevel=.02)
        block("Container door", (0, 3.02, 1.3), (2.3, .06, 2.4), "Steel", bevel=.02)
    elif kind == "crates":
        block("Crate a", (0, 0, .32), (.64, .64, .64), "Crate", bevel=.05)
        block("Crate b", (.70, .10, .28), (.56, .56, .56), "Crate", bevel=.05)
        block("Crate c", (.30, .05, .86), (.50, .50, .46), "Crate", bevel=.05)
        cyl("Barrel", (-.65, .2, .45), .28, .90, "Hazard yellow")
        torus("Barrel ring", (-.65, .2, .70), .28, .025, "Gun metal")
    elif kind == "warehouse":
        block("Warehouse walls", (0, 0, 2.4), (6.0, 8.0, 4.8), "Facade", bevel=.10)
        block("Warehouse roof", (0, 0, 5.0), (6.4, 8.4, .45), "Roof", bevel=.12)
        for y in (-2.4, 0, 2.4):
            block("Roller door" + str(y), (3.02, y, 1.4), (.08, 1.8, 2.6), "Facade dark", bevel=.03)
        for y in (-3, -1, 1, 3):
            block("Clerestory" + str(y), (3.02, y, 3.9), (.06, 1.2, .55), "Window", bevel=.02)
        block("Warehouse sign", (3.05, 0, 4.45), (.06, 3.2, .40), "Hazard yellow", bevel=.02)
    elif kind == "apartment":
        block("Apartment walls", (0, 0, 4.0), (6.0, 7.0, 8.0), "Facade", bevel=.12)
        block("Apartment roof", (0, 0, 8.15), (6.3, 7.3, .30), "Roof", bevel=.08)
        for floor in range(4):
            for y in (-2.2, 0, 2.2):
                block("Window" + str(floor) + str(y), (3.02, y, 1.4 + floor * 1.9), (.06, 1.1, 1.0), "Window", bevel=.03)
                block("Sill" + str(floor) + str(y), (3.08, y, .85 + floor * 1.9), (.14, 1.3, .10), "Awning cream", bevel=.02)
        block("Ground awning", (3.4, 0, 1.9), (.9, 5.5, .12), "Awning red", bevel=.03)
    elif kind == "market_stall":
        for x in (-.9, .9):
            for y in (-.7, .7):
                cyl("Stall pole" + str(x) + str(y), (x, y, 1.1), .045, 2.2, "Wood")
        block("Stall counter", (0, .5, .5), (1.9, .55, .9), "Wood", bevel=.05)
        for i in range(5):
            block("Awning" + str(i), (-.8 + i * .4, 0, 2.25), (.40, 1.8, .10), "Awning red" if i % 2 == 0 else "Awning cream", bevel=.02, rot=(.18, 0, 0))
        for i in range(3):
            oval("Produce" + str(i), (-.5 + i * .5, .5, 1.0), (.20, .18, .12), ("Pump orange", "Leaf", "Hazard red")[i])
    elif kind == "viaduct_pier":
        block("Pier column", (0, 0, -3.0), (1.6, 1.6, 6.0), "Seawall", bevel=.15)
        block("Pier cap", (0, 0, -.25), (3.0, 2.0, .50), "Concrete", bevel=.10)
    elif kind == "guardrail":
        for y in (-2.4, 0, 2.4):
            cyl("Rail post" + str(y), (0, y, .45), .06, .90, "Steel")
        for z in (.55, .85):
            block("Rail band" + str(z), (0, 0, z), (.06, 5.0, .14), "Steel", bevel=.02)
    elif kind == "seawall":
        block("Seawall body", (0, 0, -.6), (1.4, 10.0, 1.8), "Seawall", bevel=.12)
        block("Seawall coping", (0, 0, .35), (1.6, 10.0, .22), "Concrete", bevel=.05)
        for y in (-3.5, 0, 3.5):
            cyl("Bollard" + str(y), (0, y, .65), .14, .45, "Gun metal")
            torus("Bollard ring" + str(y), (0, y, .80), .15, .03, "Hazard yellow")
    elif kind == "tank":
        cyl("Tank shell", (0, 0, 2.2), 3.0, 4.4, "Tank white", verts=24)
        cyl("Tank roof", (0, 0, 4.65), 3.1, .50, "Steel", top=1.0, verts=24)
        torus("Tank band", (0, 0, 1.5), 3.02, .06, "Pipe green")
        torus("Tank band2", (0, 0, 3.2), 3.02, .06, "Pipe green")
        for i in range(10):
            a = i * math.tau / 20
            beam("Tank ladder" + str(i), (3.05 * math.cos(a * .1), 3.05, .2 + i * .42), (3.05 * math.cos(a * .1) + .4, 3.05, .2 + i * .42), .02, "Steel")
    elif kind == "pipes":
        for i, z in enumerate((.35, .95)):
            cyl("Pipe" + str(i), (0, 0, z), .26, 9.6, "Pipe green", rot=(math.pi / 2, 0, 0), verts=14)
        for y in (-3.5, 0, 3.5):
            block("Pipe saddle" + str(y), (0, y, .45), (.8, .25, 1.0), "Concrete", bevel=.04)
            torus("Valve wheel" + str(y), (.32, y + .5, .95), .18, .03, "Hazard red", rot=(0, math.pi / 2, 0))
    elif kind == "ferry":
        block("Ferry hull", (0, 0, .9), (6.0, 18.0, 1.8), "Ferry hull", bevel=.6)
        block("Ferry stripe", (0, 0, 1.7), (6.05, 17.6, .25), "Ferry red", bevel=.1)
        block("Ferry deck", (0, -.5, 2.6), (5.2, 14.0, 1.6), "Ferry white", bevel=.3)
        block("Ferry upper deck", (0, -1.5, 3.9), (4.2, 9.0, 1.2), "Ferry white", bevel=.25)
        for y in range(-5, 6, 2):
            block("Ferry window" + str(y), (2.62, y * .9 - .5, 2.7), (.05, 1.1, .55), "Window", bevel=.03)
            block("Ferry window b" + str(y), (-2.62, y * .9 - .5, 2.7), (.05, 1.1, .55), "Window", bevel=.03)
        block("Ferry bridge", (0, 2.2, 4.9), (3.2, 2.2, .9), "Ferry white", bevel=.2)
        block("Bridge glass", (0, 3.3, 4.95), (3.0, .05, .4), "Window", bevel=.02)
        cyl("Funnel", (0, -3.5, 5.4), .75, 2.2, "Ferry red", top=.65)
        cyl("Funnel cap", (0, -3.5, 6.55), .70, .25, "Gun metal")
        for y in (-6, -3, 0, 3):
            torus("Life ring" + str(y), (2.66, y, 3.9), .22, .06, "Pump orange", rot=(0, math.pi / 2, 0))
    elif kind == "gate":
        # Gate frame; the signed glowing panel and numerals are runtime-owned.
        for x in (-1, 1):
            block("Gate post" + str(x), (x, 0, 1.05), (.16, .22, 2.1), "Gate frame", bevel=.05)
            block("Gate foot" + str(x), (x, 0, .08), (.40, .50, .16), "Gun metal", bevel=.04)
            oval("Gate cap" + str(x), (x, 0, 2.16), (.13, .13, .10), "Gate light")
        block("Gate header", (0, 0, 2.12), (2.16, .20, .20), "Gate frame", bevel=.05)
        block("Gate header light", (0, .11, 2.12), (1.8, .02, .07), "Gate light", bevel=.01)
    elif kind == "rig_truck":
        # Crane truck drives on the sidewalk; its boom carries the rescue cage
        # over the lane at x=+3.35 (the rule target), above infected heads.
        truck_base()
        block("Crane turret", (0, -.6, 1.30), (1.0, 1.0, .45), "Hazard yellow", bevel=.08)
        beam("Crane boom", (0, -.6, 1.55), (3.55, -.6, 3.15), .13, "Hazard yellow")
        beam("Crane strut", (.2, -.6, 1.4), (1.9, -.6, 2.45), .06, "Gun metal")
        beam("Crane hoist", (3.35, -.6, 3.1), (3.35, -.6, 1.95), .02, "Cable")
        block("Cage floor", (3.35, -.6, 1.05), (1.05, 1.0, .08), "Gun metal", bevel=.02)
        block("Cage roof", (3.35, -.6, 1.90), (1.05, 1.0, .06), "Gun metal", bevel=.02)
        for x in (-.48, .48):
            for y in (-.46, .46):
                cyl("Cage bar" + str(x) + str(y), (3.35 + x, -.6 + y, 1.48), .025, .84, "Hazard yellow")
        for i, x in enumerate((-.26, 0, .26)):
            y = -.6 - .1 * (i % 2)
            cyl("Rigger body" + str(i), (3.35 + x, y, 1.30), .10, .40, "Survivor", top=.085)
            oval("Rigger head" + str(i), (3.35 + x, y, 1.58), (.085, .085, .085), "Skin")
            oval("Rigger cap" + str(i), (3.35 + x, y, 1.64), (.09, .09, .045), "Hazard yellow")
            beam("Rigger arm" + str(i), (3.35 + x, y, 1.42), (3.35 + x + .05, y + .05, 1.78), .03, "Survivor")
    elif kind == "pump_truck":
        # Pump tender on the sidewalk; its gantry holds the intake pump over
        # the flooded lane at x=+3.35.
        truck_base()
        cyl("Pump drum", (0, -.5, 1.45), .55, 1.8, "Pump orange", rot=(math.pi / 2, 0, 0), verts=18)
        torus("Pump band", (0, -1.0, 1.45), .56, .05, "Gun metal", rot=(math.pi / 2, 0, 0))
        torus("Pump band2", (0, 0, 1.45), .56, .05, "Gun metal", rot=(math.pi / 2, 0, 0))
        beam("Gantry arm", (0, -.5, 2.0), (3.55, -.5, 2.55), .11, "Pipe green")
        beam("Gantry brace", (.2, -.5, 1.6), (2.0, -.5, 2.25), .06, "Gun metal")
        cyl("Intake pump", (3.35, -.5, 1.55), .42, .85, "Pump orange", verts=16)
        torus("Intake rim", (3.35, -.5, 1.13), .44, .05, "Gun metal")
        cyl("Intake motor", (3.35, -.5, 2.10), .26, .34, "Pipe green")
        oval("Pump beacon", (3.35, -.5, 2.36), (.12, .12, .10), "Hazard red")
        beam("Pump hose", (3.0, -.2, 1.5), (.5, .2, 1.3), .09, "Gun metal")
        block("Gauge panel", (-.66, -.3, 1.4), (.06, .7, .45), "Steel", bevel=.02)
    elif kind == "cart":
        block("Cart bed", (0, 0, .55), (2.0, 1.2, .18), "Wood", bevel=.04)
        for x in (-.95, .95):
            block("Cart side" + str(x), (x, 0, .80), (.08, 1.2, .40), "Wood", bevel=.02)
        block("Cart crate", (-.45, 0, .95), (.70, .70, .60), "Crate", bevel=.05)
        block("Cart crate b", (.40, .10, .90), (.60, .60, .50), "Crate", bevel=.05)
        cyl("Cart barrel", (.45, -.20, 1.35), .22, .55, "Hazard red")
        block("Hazard board", (0, .64, .70), (1.9, .05, .30), "Hazard yellow", bevel=.02)
        for i in range(4):
            block("Hazard chevron" + str(i), (-.70 + i * .47, .67, .70), (.16, .02, .30), "Gun metal", bevel=.01, rot=(0, .6, 0))
        beam("Cart handle", (-.4, -.6, .60), (-.4, -1.4, .90), .04, "Wood")
        beam("Cart handle2", (.4, -.6, .60), (.4, -1.4, .90), .04, "Wood")
    elif kind == "wheel":
        cyl("Tyre", (0, 0, 0), .40, .30, "Tyre", rot=(0, math.pi / 2, 0), verts=16)
        cyl("Hub", (.16, 0, 0), .20, .04, "Steel", rot=(0, math.pi / 2, 0), verts=10)
        block("Hub bolt", (.18, 0, .10), (.03, .06, .06), "Gun metal", bevel=.01)
    elif kind == "terminal":
        block("Terminal hall", (0, 0, 2.2), (8.0, 6.0, 4.4), "Ferry white", bevel=.2)
        block("Terminal roof", (0, 0, 4.6), (8.6, 6.6, .5), "Container teal", bevel=.15)
        for x in (-3, -1, 1, 3):
            block("Terminal glass" + str(x), (x, 3.02, 1.8), (1.6, .06, 2.4), "Window", bevel=.04)
        block("Terminal sign", (0, 3.1, 4.0), (4.0, .08, .6), "Ferry red", bevel=.04)
    elif kind == "lifebuoy":
        cyl("Buoy post", (0, 0, .8), .06, 1.6, "Steel")
        torus("Buoy ring", (0, .08, 1.25), .30, .08, "Pump orange", rot=(math.pi / 2, 0, 0))
        block("Buoy box", (0, 0, 1.75), (.40, .20, .30), "White paint", bevel=.04)
    elif kind == "cone":
        cyl("Cone", (0, 0, .35), .22, .70, "Pump orange", top=.03, verts=12)
        torus("Cone band", (0, 0, .42), .14, .03, "White paint")
        block("Cone foot", (0, 0, .03), (.5, .5, .06), "Pump orange", bevel=.02)
    elif kind == "shrub":
        for i in range(4):
            oval("Shrub" + str(i), ((-.3, .3, 0, .1)[i], (0, .1, .3, -.3)[i], .40 + .15 * (i % 2)), (.48, .44, .42), "Leaf")
    elif kind == "dock_crane":
        for x in (-2.2, 2.2):
            for y in (-1.6, 1.6):
                block("Crane leg" + str(x) + str(y), (x, y, 4.0), (.5, .5, 8.0), "Pump orange", bevel=.08)
        block("Crane deck", (0, 0, 8.3), (5.2, 4.0, .8), "Pump orange", bevel=.12)
        block("Crane boom", (-6.0, 0, 9.4), (16.0, 1.0, 1.0), "Pump orange", bevel=.12)
        block("Crane cab", (1.0, 0, 9.3), (1.6, 1.8, 1.4), "Ferry white", bevel=.12)
        beam("Crane cable", (-9.0, 0, 9.0), (-9.0, 0, 4.0), .04, "Cable")
    export(kind)


def truck_base():
    block("Truck bed", (0, 0, .90), (1.7, 3.6, .30), "Gun metal", bevel=.06)
    block("Truck cab", (0, 2.2, 1.25), (1.7, 1.2, 1.2), "Crew blue", bevel=.16)
    block("Cab glass", (0, 2.82, 1.45), (1.5, .05, .55), "Window", bevel=.03)
    block("Chassis", (0, .5, .62), (1.3, 4.6, .30), "Tyre", bevel=.05)
    block("Bed rail", (.86, 0, 1.15), (.06, 3.4, .22), "Hazard yellow", bevel=.02)
    block("Bed rail2", (-.86, 0, 1.15), (.06, 3.4, .22), "Hazard yellow", bevel=.02)
    oval("Cab beacon", (0, 2.2, 1.92), (.14, .14, .09), "Lamp glow")


# ------------------------------------------------------------------- export
def canonicalize(path):
    # Blender's exporter may reorder independent triangles. Keep vertex and
    # skin data intact; sort cyclic triangle indices without changing winding.
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
        objects[0].name = name + "_" + mat.replace(" ", "_")
        objects[0].data.name = objects[0].name + "Mesh"
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(c) for obj in bpy.context.scene.objects if obj.type == "MESH" for c in obj.bound_box]
    bpy.ops.object.select_all(action="SELECT")
    path = OUT / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_yup=True,
                              export_animations=bool(PARTS), export_skins=True,
                              export_extras=True, export_texcoords=False,
                              export_vertex_color="ACTIVE", export_active_vertex_color_when_no_material=True)
    canonicalize(path)
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    RECORDS.append({"name": name, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
                    "meshes": len(doc.get("meshes", [])), "skins": len(doc.get("skins", [])),
                    "animations": len(doc.get("animations", [])),
                    "joints": len(doc["skins"][0]["joints"]) if doc.get("skins") else 0,
                    "triangles": sum(doc["accessors"][p["indices"]]["count"] // 3 for m in doc["meshes"] for p in m["primitives"]),
                    "bounds_blender": {"min": [round(min(p[i] for p in points), 5) for i in range(3)],
                                       "max": [round(max(p[i] for p in points), 5) for i in range(3)]}})


crew()
for role in INFECTED:
    infected(role)
for kind in BOSS:
    boss_humanoid(kind)
for kind in ("bell", "ferry", "ferry_arm", "blockade"):
    boss_rigid(kind)
PROPS = ["road_tile", "road_cross", "road_mark", "streetlight", "palm", "car", "van", "barrier", "sandbags", "container", "crates",
         "warehouse", "apartment", "market_stall", "viaduct_pier", "guardrail", "seawall", "tank", "pipes",
         "ferry", "gate", "rig_truck", "pump_truck", "cart", "wheel", "terminal", "lifebuoy", "cone",
         "shrub", "dock_crane"]
for name in PROPS:
    prop(name)
(ROOT / "manifest.json").write_text(json.dumps({"generator": "source/build_assets.py",
    "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    "generator_lf_sha256": hashlib.sha256(Path(__file__).read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
    "blender": bpy.app.version_string, "rendered": False, "original": True,
    "coordinates": "Blender +Y forward +Z up; glTF -Z forward +Y up", "assets": RECORDS}, indent=2) + "\n")
print("DEAD_RUN_KIT_COMPLETE", len(RECORDS))
