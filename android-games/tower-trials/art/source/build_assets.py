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

GLOW = {"Lantern", "Window glow", "Eye glow", "Moon", "Beacon", "Sky glass", "Crystal glow", "Aurora"}
M = {n: c for n, c in [
    ("Stone", "c9bfa8"), ("Stone dark", "8f8a7c"), ("Mortar", "a39b88"), ("Plaster", "f1e4c6"),
    ("Slate", "4d6c7c"), ("Slate dark", "36505f"), ("Timber", "8a5f3c"), ("Iron", "2e3a44"),
    ("Teal", "3fc7a8"), ("Teal dark", "2a8f7c"), ("Gold", "ffd17d"), ("Brass", "d9a54a"),
    ("Cloak", "32baa2"), ("Skin", "f0c58c"), ("Ink", "102c42"), ("Boot", "3a2c24"),
    ("Spirit", "c9e4f0"), ("Spirit shade", "8fb3c9"), ("Rock", "4c6470"), ("Rock dark", "35495a"),
    ("Moss", "4f8a6e"), ("Cottage wall", "d8cdb4"), ("Cottage roof", "8a4a3c"),
    ("Lantern", "ffe08a"), ("Window glow", "ffd98a"), ("Eye glow", "aef6ff"), ("Moon", "f2ead2"),
    ("Beacon", "fff1b0"), ("Red band", "c8463e"), ("White band", "f3efe4"),
    ("Plaster shade", "e2cfa8"), ("Plank", "9c6a40"), ("Plank dark", "6e4a2f"), ("Sky glass", "9fd8ff"),
    ("Tunic", "2e9d8a"), ("Scarf", "e86a4a"), ("Leather", "6b4a33"),
    ("Wisp", "b8476a"), ("Wisp dark", "7d2a4c"), ("Armour", "56606e"), ("Armour dark", "343c48"),
    ("Cloth red", "a8323e"), ("Golem", "5b4f63"), ("Golem dark", "3b3346"), ("Crystal glow", "ff7ad9"),
    ("Sandstone", "d9b98a"), ("Sandstone dark", "b08e62"), ("Salt", "efe8dc"),
    ("Glass", "8fd6cf"), ("Glass dark", "4f9a99"), ("Violet stone", "5a4a78"), ("Aurora", "9cf0d0")]}


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
    # Open diorama chamber. Front plane y=0 faces the viewer; the interior
    # recedes to the back wall at y=.7. Floor top sits at z=-.28 so feet land
    # just above the 2D name plaque; stone bands above and below close the
    # gaps between stacked floors.
    block("Floor", (0, .35, -.39), (1.66, .7, .22), "Plank", .02)
    for i in range(7):
        block("Seam%d" % i, (-.72 + i * .24, .35, -.278), (.012, .68, .006), "Plank dark", .002)
    block("Back", (0, .7, .08), (1.66, .06, .78), "Plaster", .02)
    block("Wainscot", (0, .66, -.17), (1.62, .03, .2), "Plank dark", .01)
    block("Rail", (0, .645, -.06), (1.62, .03, .03), "Timber", .008)
    for side in (-1, 1):
        block("Side", (side * .8, .35, .08), (.06, .68, .78), "Plaster shade", .02)
        block("Window", (side * .48, .668, .2), (.26, .02, .26), "Sky glass", .01)
        oval("Arch", (side * .48, .668, .33), (.13, .01, .08), "Sky glass", 10, 4)
        block("Mullion", (side * .48, .655, .22), (.02, .02, .36), "Timber", .004)
        block("Transom", (side * .48, .655, .2), (.26, .02, .02), "Timber", .004)
        block("Ledge", (side * .48, .65, .06), (.32, .05, .03), "Stone dark", .008)
        cyl("Sconce", (side * .74, .3, .2), .025, .06, "Iron", verts=6, rot=(0, math.pi / 2, 0))
        oval("Flame", (side * .7, .3, .24), (.035, .035, .05), "Lantern", 8, 6)
        block("Pilaster", (side * .86, -.01, .0), (.12, .1, 1.0), "Stone", .02)
        block("Plinth", (side * .86, -.03, -.42), (.15, .1, .14), "Stone dark", .02)
    block("Beam", (0, .35, .44), (1.62, .68, .06), "Timber", .015)
    for i in range(4):
        block("Joist%d" % i, (-.6 + i * .4, .35, .405), (.05, .66, .04), "Plank dark", .006)
    block("Lintel", (0, -.02, .48), (1.86, .12, .08), "Stone dark", .02)
    block("Keystone", (0, -.05, .48), (.14, .06, .12), "Stone", .02)
    block("Upper band", (0, .02, .54), (1.84, .1, .06), "Mortar", .01)
    block("Lower band", (0, .03, -.54), (1.84, .12, .1), "Stone dark", .02)
    block("Closure", (0, .76, 0), (1.8, .06, 1.12), "Stone dark", .02)


def tower_column():
    # Shaft behind the chambers, unit tall from z=0, scaled at runtime.
    block("Shaft", (0, .95, .5), (1.86, .4, 1.0), "Stone dark", .04)
    for i in range(8):
        block("Band", (0, .74, .06 + i * .125), (1.88, .04, .015), "Mortar", .004)
    for side in (-1, 1):
        block("Buttress", (side * .98, .6, .5), (.14, .8, 1.0), "Rock", .03)


def tower_segment():
    # Flush masonry for tower stretches without a chamber: 1.84 wide, .5 tall
    # from z=0, front at y=0; staggered ashlar courses and one lit slit.
    block("Core", (0, .2, .25), (1.8, .4, .5), "Rock dark", .02)
    for row in range(3):
        z = .085 + row * .165
        shift = .15 if row % 2 else 0
        for col in range(6):
            x = -.75 + col * .3 + shift
            if abs(x) > .8:
                continue
            block("Ashlar%d_%d" % (row, col), (x, -.01, z), (.28, .04, .15), "Stone dark" if (row + col) % 3 else "Rock", .02)
    block("Slit frame", (0, -.03, .26), (.12, .03, .24), "Iron", .01)
    block("Slit", (0, -.04, .26), (.05, .02, .18), "Window glow", .005)


def keeper():
    # Lost lantern keeper awaiting rescue, about .5 tall, origin at the feet.
    cyl("Robe", (0, 0, .16), .14, .32, "Salt", top=.07, verts=12)
    block("Trim", (0, 0, .03), (.27, .27, .03), "Gold", .01)
    oval("Head", (0, 0, .38), (.09, .085, .09), "Skin", 10, 6)
    cyl("Cowl", (0, .02, .44), .1, .1, "Gold", top=.02, verts=10)
    for side in (-1, 1):
        oval("Eye", (side * .03, -.08, .39), (.012, .006, .012), "Ink", 6, 4)
    cyl("Arm", (.12, -.04, .26), .025, .14, "Salt", top=.02, verts=6, rot=(.6, .5, 0))
    oval("Lamp", (.16, -.12, .36), (.045, .045, .055), "Lantern", 8, 6)


def cage():
    # Iron chime cage around a keeper; lifted away once the room is claimed.
    for i in range(10):
        a = i * math.pi / 5
        cyl("Bar%d" % i, (math.sin(a) * .2, math.cos(a) * .2, .3), .012, .6, "Iron", verts=5)
    cyl("Base", (0, 0, .015), .23, .03, "Iron", verts=14)
    cyl("Lid", (0, 0, .62), .23, .08, "Iron", top=.05, verts=14)
    cyl("Ring", (0, 0, .7), .03, .06, "Brass", verts=8)


def tower_roof():
    prism("Roof", (0, .5, .04), 2.06, .56, 1.2, "Slate")
    block("Eave", (0, .5, .04), (2.1, 1.24, .07), "Slate dark", .02)
    for side in (-1, 1):
        prism("Dormer%d" % side, (side * .5, -.02, .04), .3, .22, .16, "Slate dark")
    cyl("Spire", (0, .5, .74), .03, .4, "Iron", verts=8)
    oval("Finial", (0, .5, .96), (.07, .07, .07), "Brass", 8, 6)
    prism("Flag", (.14, .5, .82), .22, .12, .02, "Red band")


def home_floor():
    # Unit-tall floor of the player's watch, 1.16 wide: timber frame, lit windows.
    block("Wall", (0, .3, .5), (1.12, .6, .96), "Cottage wall", .03)
    for side in (-1, 1):
        block("Post", (side * .55, -.02, .5), (.08, .06, .98), "Timber", .01)
        block("Window", (side * .3, -.015, .55), (.2, .03, .3), "Window glow", .01)
        block("Mullion", (side * .3, -.03, .55), (.02, .02, .3), "Timber", .004)
        block("Shutter", (side * .3, -.03, .72), (.26, .02, .04), "Timber", .005)
    block("Beam", (0, -.03, .96), (1.16, .06, .06), "Timber", .01)
    block("Ledge", (0, -.04, .03), (1.2, .1, .06), "Stone dark", .02)
    oval("Bell", (0, -.05, .55), (.06, .05, .07), "Gold", 8, 6)


def home_roof():
    prism("Roof", (0, .3, 0), 1.4, .5, .74, "Teal")
    block("Eave", (0, .3, 0), (1.42, .78, .05), "Teal dark", .02)
    cyl("Pole", (0, .3, .74), .025, .62, "Iron", verts=8)
    prism("Pennant", (.16, .3, .92), .3, .2, .02, "Gold")
    oval("Lantern", (0, -.02, .26), (.09, .09, .11), "Lantern", 10, 6)
    block("Lantern cap", (0, -.02, .38), (.12, .1, .03), "Brass", .006)


def courier_body():
    # Pivot at the hips; the courier faces -Y (toward the viewer).
    oval("Torso", (0, 0, .11), (.1, .08, .13), "Tunic", 12, 8)
    cyl("Skirt", (0, 0, .0), .1, .1, "Tunic", top=.07, verts=12)
    block("Belt", (0, 0, .03), (.21, .17, .03), "Leather", .01)
    block("Buckle", (0, -.085, .03), (.05, .01, .035), "Gold", .004)
    cyl("Cape", (0, .05, .09), .13, .3, "Teal dark", top=.06, verts=10)
    oval("Head", (0, -.01, .33), (.11, .1, .11), "Skin", 12, 8)
    cyl("Hood", (0, .02, .4), .12, .12, "Cloak", top=.02, verts=12)
    block("Visor", (0, -.1, .34), (.2, .03, .045), "Ink", .01)
    oval("Eye", (.045, -.115, .345), (.014, .006, .012), "Eye glow", 6, 4)
    cyl("Scarf", (0, 0, .23), .085, .05, "Scarf", top=.08, verts=12)
    block("Scarf tail", (.02, .08, .19), (.05, .1, .03), "Scarf", .01, rot=(.5, 0, .2))
    oval("Pauldron", (-.1, 0, .2), (.05, .05, .04), "Brass", 8, 6)


def courier_leg():
    # Pivot at the hip; foot at z=-.2.
    cyl("Thigh", (0, 0, -.07), .035, .14, "Leather", top=.03, verts=8)
    cyl("Shin", (0, 0, -.15), .03, .08, "Boot", verts=8)
    block("Boot", (0, -.025, -.19), (.07, .11, .045), "Boot", .015)


def courier_arm():
    # Pivot at the right shoulder; the hand at z=-.13 holds the lantern staff.
    cyl("Sleeve", (0, 0, -.06), .03, .12, "Tunic", top=.025, verts=8)
    oval("Hand", (0, -.01, -.13), (.03, .03, .03), "Skin", 8, 6)
    cyl("Staff", (0, -.03, -.06), .016, .5, "Timber", verts=6)
    block("Cap", (0, -.03, .2), (.07, .07, .02), "Brass", .005)
    oval("Lantern", (0, -.03, .25), (.05, .05, .06), "Lantern", 10, 6)
    cyl("Hook", (0, -.03, .31), .012, .04, "Iron", verts=6)


def spirit():
    # Lost chime wisp (single-digit enemies): about .44 tall, origin at the base.
    cyl("Shroud", (0, 0, .13), .16, .26, "Wisp", top=.1, verts=14)
    oval("Crown", (0, 0, .28), (.13, .12, .12), "Wisp", 12, 8)
    oval("Face", (0, -.08, .28), (.085, .04, .07), "Ink", 10, 6)
    for side in (-1, 1):
        oval("Eye", (side * .035, -.11, .29), (.018, .01, .02), "Eye glow", 6, 4)
        cyl("Arm", (side * .17, -.02, .14), .03, .12, "Wisp dark", top=.012, verts=6, rot=(0, side * .9, 0))
        cyl("Horn", (side * .07, 0, .4), .025, .08, "Wisp dark", top=.004, verts=6, rot=(0, side * .4, 0))
    block("Rim", (0, 0, .01), (.33, .33, .03), "Wisp dark", .015)
    oval("Clapper", (0, 0, -.01), (.05, .05, .05), "Gold", 8, 6)


def spirit_knight():
    # Armoured chime knight (two-digit enemies): about .52 tall.
    cyl("Body", (0, 0, .15), .17, .3, "Armour", top=.13, verts=12)
    block("Tabard", (0, -.12, .14), (.16, .04, .24), "Cloth red", .01)
    oval("Helm", (0, 0, .36), (.13, .12, .12), "Armour dark", 12, 8)
    block("Slit", (0, -.12, .36), (.15, .02, .03), "Eye glow", .005)
    cyl("Crest", (0, .02, .48), .03, .1, "Cloth red", top=.01, verts=6)
    for side in (-1, 1):
        oval("Pauldron", (side * .17, 0, .27), (.07, .07, .05), "Armour dark", 8, 6)
        cyl("Horn", (side * .12, 0, .46), .028, .12, "Gold", top=.004, verts=6, rot=(0, side * .7, 0))
    block("Shield", (-.19, -.06, .16), (.04, .16, .2), "Armour dark", .02)
    oval("Boss", (-.215, -.06, .16), (.02, .04, .04), "Gold", 6, 4)
    cyl("Blade", (.2, -.04, .24), .012, .32, "White band", top=.002, verts=4)
    block("Guard", (.2, -.04, .1), (.08, .03, .02), "Gold", .004)
    block("Base", (0, 0, .01), (.32, .3, .03), "Armour dark", .01)


def spirit_golem():
    # Great chime golem (three-digit enemies and more): about .62 tall and wide.
    oval("Body", (0, 0, .28), (.24, .18, .24), "Golem", 12, 8)
    oval("Head", (0, -.04, .5), (.11, .1, .09), "Golem dark", 10, 6)
    for side in (-1, 1):
        oval("Eye", (side * .04, -.13, .51), (.022, .01, .018), "Crystal glow", 6, 4)
        oval("Fist", (side * .29, -.03, .14), (.09, .09, .1), "Golem dark", 8, 6)
        cyl("Arm", (side * .27, 0, .3), .06, .22, "Golem dark", top=.05, verts=8, rot=(0, side * .3, 0))
        cyl("Leg", (side * .1, 0, .06), .07, .12, "Golem dark", verts=8)
        cyl("Shard", (side * .14, .04, .5), .05, .18, "Crystal glow", top=.0, verts=5, rot=(0, side * .5, 0))
    cyl("Core", (0, -.16, .3), .06, .03, "Crystal glow", verts=8, rot=(math.pi / 2, 0, 0))
    block("Plate", (0, -.15, .2), (.22, .04, .08), "Brass", .01)


def banner():
    # Courier claim pennant hung on a chamber back wall; origin at the rod.
    cyl("Rod", (0, 0, 0), .015, .5, "Brass", verts=6, rot=(0, math.pi / 2, 0))
    block("Cloth", (0, .01, -.16), (.36, .015, .3), "Teal", .006)
    block("Hem", (0, .005, -.32), (.36, .015, .04), "Gold", .004)
    oval("Emblem", (0, -.005, -.14), (.07, .01, .07), "Lantern", 10, 4)


def cliff():
    # Backdrop headland, about 6 wide and 2.6 tall.
    # Stacked, tapering, slightly turned strata read as weathered rock.
    for i, (x, w, h) in enumerate([(-2.4, 1.6, 1.4), (-1.1, 1.8, 2.1), (.4, 2.0, 2.5), (1.9, 1.6, 1.8), (3.0, 1.2, 1.0)]):
        layers = 4
        for k in range(layers):
            lw = w * (1.0 - .13 * k) + ((i * 7 + k * 3) % 5) * .04
            lh = h / layers
            twist = (((i * 5 + k * 11) % 7) - 3) * .035
            block("Rock%d_%d" % (i, k), (x + (((i + k) % 3) - 1) * .07, .4, lh * (k + .5)), (lw, .9 - k * .08, lh * 1.04),
                  "Rock" if (i + k) % 2 else "Rock dark", .1, rot=(0, twist, twist * .5))
        cyl("Cap%d" % i, (x, .4, h + .02), w * .3, .08, "Moss", top=w * .22, verts=9)
    for i in range(6):
        oval("Boulder%d" % i, (-2.8 + i * 1.15, -.15, .1), (.22 + (i % 3) * .06, .2, .14 + (i % 2) * .05), "Rock dark", 8, 5)


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


def archive():
    # Salt Archives: stepped sandstone stacks with lit reading windows and a dome.
    tiers = [(1.6, .9), (1.2, .8), (.8, .6)]
    z = 0.0
    for k, (w, h) in enumerate(tiers):
        block("Tier%d" % k, (0, .4, z + h / 2), (w, .8 - k * .1, h), "Sandstone" if k % 2 == 0 else "Sandstone dark", .04)
        block("Cornice%d" % k, (0, .4, z + h), (w + .08, .86 - k * .1, .05), "Salt", .02)
        for j in range(int(w / .3)):
            block("Lit%d_%d" % (k, j), (-w / 2 + .18 + j * .3, -.01 + k * .05, z + h * .5), (.1, .02, h * .4), "Window glow", .01)
        z += h
    oval("Dome", (0, .4, z), (.34, .34, .3), "Salt", 12, 8)
    cyl("Needle", (0, .4, z + .4), .02, .3, "Brass", verts=6)


def crystal():
    # Glass March: a cluster of leaning glass shards with lit tips.
    for i, (x, h, lean) in enumerate([(0, 1.6, 0), (-.35, 1.0, -.3), (.32, 1.2, .25), (-.15, .6, -.6), (.5, .55, .7)]):
        cyl("Shard%d" % i, (x, 0, h / 2), .16 - i * .015, h, "Glass" if i % 2 == 0 else "Glass dark", top=.02, verts=5, rot=(0, lean, 0), smooth=False)
        oval("Tip%d" % i, (x + math.sin(lean) * h * .5, 0, h * .5 + math.cos(lean) * h * .5), (.04, .04, .05), "Crystal glow", 6, 4)
    oval("Root", (0, 0, .02), (.6, .4, .08), "Rock dark", 8, 5)


def meridian():
    # Last Meridian: a great clock ring on a pedestal with gold hour marks.
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=.07, major_segments=40, minor_segments=8,
                                     location=(0, 0, 1.3), rotation=(math.pi / 2, 0, 0))
    finish(bpy.context.object, "Ring", "Violet stone")
    for i in range(12):
        a = i * math.pi / 6
        block("Mark%d" % i, (math.sin(a) * 1.0, -.07, 1.3 + math.cos(a) * 1.0), (.06, .04, .16), "Gold", .01, rot=(0, a, 0))
    block("Hand", (.25, -.09, 1.45), (.05, .03, .6), "Brass", .01, rot=(0, .9, 0))
    block("Pedestal", (0, 0, .15), (.9, .5, .3), "Violet stone", .04)
    block("Step", (0, 0, .03), (1.3, .7, .06), "Stone dark", .02)
    oval("Heart", (0, -.04, 1.3), (.1, .04, .1), "Aurora", 10, 6)


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


ASSETS = [("room", room), ("tower_column", tower_column), ("tower_segment", tower_segment), ("tower_roof", tower_roof),
          ("home_floor", home_floor), ("home_roof", home_roof),
          ("courier_body", courier_body), ("courier_leg", courier_leg), ("courier_arm", courier_arm),
          ("spirit", spirit), ("spirit_knight", spirit_knight), ("spirit_golem", spirit_golem),
          ("banner", banner), ("keeper", keeper), ("cage", cage), ("cliff", cliff), ("lighthouse", lighthouse), ("cottage", cottage),
          ("archive", archive), ("crystal", crystal), ("meridian", meridian), ("moon", moon)]
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
