"""Original Frontline perimeter scenery; invoked by build_assets after world_kit.

Soft beveled boulders, snow-shouldered rocks, faceted pines, striped barriers and
sawhorse barricades frame the playfield outside the rule rectangle. Deterministic
analytic displacement only: no random inputs, textures, rendering or network.
Rock/Snow material names let each district recolor the same kit at runtime.
"""
import math


def build(api):
    clear, block, cylinder, material, export = [api[key] for key in
        ["clear", "block", "cylinder", "material", "export"]]
    bpy = api["bpy"]
    import bmesh

    rock = material("Rock", (.37, .45, .49))
    snow = material("Snow", (.78, .86, .87))
    pine = material("PineNeedle", (.24, .36, .36))
    bark = material("Bark", (.30, .23, .17))
    concrete = material("Concrete", (.62, .63, .60))
    stripe = material("Stripe", (.62, .12, .09))
    paint = material("StripeWhite", (.86, .86, .82))
    rust = material("WorldRust", (.40, .25, .16))
    steel = material("WorldMetal", (.19, .27, .28), .65, .12)

    def hashed(x, y, z, seed):
        # Smooth, deterministic lumps; sums of incommensurate sines, never RNG.
        return (math.sin(x * 2.3 + y * 1.1 + seed * 1.7) * .55
                + math.sin(y * 3.1 - z * 1.9 + seed * 2.9) * .30
                + math.sin(z * 4.7 + x * 2.2 + seed * .6) * .15)

    def boulder(name, scale, seed, snow_line, location=(0, 0, 0), yaw=0.0):
        mesh = bpy.data.meshes.new(name + "Mesh")
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in bm.verts:
            x, y, z = v.co
            lump = 1 + .16 * hashed(x, y, z, seed)
            # Chunky planar facets: pull points toward a few broad cut planes.
            v.co.x = x * lump * scale[0]
            v.co.y = y * lump * scale[1]
            v.co.z = max(z * lump, -.25) * scale[2]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(rock)
        if snow_line is not None:
            obj.data.materials.append(snow)
            top = max(v.co.z for v in mesh.vertices)
            for poly in mesh.polygons:
                if poly.normal.z > .52 and poly.center.z > top * snow_line:
                    poly.material_index = 1
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new("Soft facet", "BEVEL")
        modifier.width = .05 * min(scale)
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(22)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        for poly in obj.data.polygons:
            poly.use_smooth = True
        modifier = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        modifier.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.location = (location[0], location[1], location[2] + .25 * scale[2])
        obj.rotation_euler = (0, 0, yaw)
        obj.select_set(False)
        return obj

    for name, scale, seed, snow_line in [
            ("boulder_large", (2.2, 1.7, 1.5), 1, None),
            ("boulder_small", (1.1, .95, .8), 4, None),
            ("snow_rock", (2.0, 1.6, 1.7), 7, .35),
            ("snow_rock_tall", (1.4, 1.2, 2.3), 11, .45)]:
        clear()
        boulder("Stone", scale, seed, snow_line)
        export(name, merge=True)

    # Cluster: one large and two leaning partners make a natural outcrop.
    clear()
    boulder("Outcrop", (2.3, 1.8, 1.9), 13, .4)
    boulder("Outcrop", (1.2, 1.0, 1.0), 17, .3, (1.9, -.9, 0), .7)
    boulder("Outcrop", (.9, .8, .7), 19, None, (-1.7, 1.1, 0), 1.9)
    export("rock_outcrop", merge=True)

    def cone(name, location, radius, depth, mat, vertices=7, yaw=0.0):
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius * .08, depth=depth, location=location)
        obj = bpy.context.object
        obj.rotation_euler = (0, 0, yaw)
        modifier = obj.modifiers.new("Soft rim", "BEVEL")
        modifier.width = .035
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.name = name
        obj.data.materials.append(mat)
        return obj

    for name, height, snowy in [("pine", 1.0, True), ("pine_tall", 1.35, True), ("pine_bare", 1.0, False)]:
        clear()
        cylinder("Trunk", (0, 0, .35 * height), .16, .7 * height, bark)
        for tier in range(3):
            radius = (1.05 - tier * .27) * height
            z = (.75 + tier * .62) * height
            cone("Needles", (0, 0, z), radius, 1.05 * height, pine, 8, tier * .4)
            if snowy:
                # A shallow pale shoulder on each tier reads as settled snow.
                cone("SnowShoulder", (0, 0, z + .32 * height), radius * .55, .42 * height, snow, 8, tier * .4)
        export(name, merge=True)

    clear()
    block("BarrierBase", (0, 0, .16), (2.2, .62, .32), concrete, .08)
    block("BarrierBody", (0, 0, .50), (2.1, .36, .52), concrete, .10)
    for x in [-.72, -.24, .24, .72]:
        block("BarrierStripe", (x, .185, .53), (.20, .03, .40), stripe, .02)
        block("BarrierStripe", (x, -.185, .53), (.20, .03, .40), stripe, .02)
    export("barrier", merge=True)

    clear()
    for x in [-.62, .62]:
        for tilt in [-.32, .32]:
            leg = block("SawLeg", (x, tilt * .5, .38), (.07, .07, .80), paint, .02)
            leg.rotation_euler = (tilt, 0, 0)
    block("SawPlank", (0, 0, .70), (1.55, .07, .19), paint, .025)
    for x in [-.54, -.18, .18, .54]:
        block("SawStripe", (x, -.045, .70), (.16, .02, .195), stripe, .01)
    export("sawhorse", merge=True)

    clear()
    cylinder("FuelDrum", (0, 0, .42), .30, .84, rust)
    for z in [.20, .64]:
        cylinder("DrumHoop", (0, 0, z), .315, .05, steel)
    cylinder("DrumLid", (0, 0, .85), .27, .02, steel)
    export("fuel_drum", merge=True)
