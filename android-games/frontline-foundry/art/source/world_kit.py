"""Original regional outpost, equipment and boss models; invoked by build_assets.
No random inputs, third-party art, rendering or network operations.
"""
import math


def build(api):
    clear, block, oval, cylinder, material, export, pivot = [api[key] for key in
        ["clear", "block", "oval", "cylinder", "material", "export", "pivot"]]
    bpy = api["bpy"]
    olive = material("WorldOlive", (.30, .42, .23))
    roof = material("WorldRoof", (.43, .55, .30))
    steel = material("WorldMetal", (.19, .27, .28), .65, .12)
    stone = material("WorldStone", (.45, .49, .44))
    wood = material("WorldWood", (.43, .31, .19))
    ivory = material("WorldIvory", (.68, .70, .57))
    brass = material("WorldBrass", (.76, .59, .24), .6, .10)
    rust = material("WorldRust", (.40, .25, .16))
    glass = material("WorldGlass", (.32, .59, .63), .45)
    rubber = material("Rubber", (.065, .085, .09))
    uniform = material("Uniform", (.94, .64, .065))
    dark = material("Gunmetal", (.16, .22, .23), .45, .2)

    def beam(name, a, b, width, mat):
        from mathutils import Vector
        midpoint = (Vector(a) + Vector(b)) / 2
        length = (Vector(b) - Vector(a)).length
        obj = block(name, midpoint, (width, width, length), mat, min(width / 3, .045))
        obj.rotation_euler = (Vector(b) - Vector(a)).to_track_quat("Z", "Y").to_euler()
        return obj

    def wheels(width=.65, ys=(-.56, .56), radius=.30):
        for side in [-1, 1]:
            for y in ys:
                cylinder("Wheel", (side * width, y, radius), radius, .19, rubber, rotation=(0, math.pi / 2, 0))
                cylinder("Hub", (side * (width + .105), y, radius), radius * .48, .025, dark, rotation=(0, math.pi / 2, 0))

    clear()
    block("Foundation", (0, 0, .08), (2.65, 1.15, .16), stone, .07)
    block("HQWalls", (0, 0, .51), (2.35, .88, .86), olive, .12)
    block("HQRoof", (0, 0, 1.0), (2.60, 1.12, .22), roof, .11)
    for x in [-1.02, 1.02]:
        block("CornerColumn", (x, .46, .53), (.13, .12, .83), ivory, .035)
    block("DoorRecess", (0, .45, .43), (.48, .055, .70), steel, .045)
    block("DoorLeaf", (0, .49, .41), (.35, .04, .61), roof, .035)
    cylinder("DoorHandle", (.11, .522, .40), .025, .09, brass, rotation=(math.pi / 2, 0, 0))
    for x in [-.72, .72]:
        block("WindowRecess", (x, .455, .63), (.46, .05, .33), steel, .035)
        block("GlassPane", (x, .501, .63), (.34, .024, .22), glass, .015)
        block("WindowBrow", (x, .48, .83), (.52, .19, .075), roof, .025)
    for i in range(3):
        block("EntryStep", (0, .61 + i * .12, .10 - i * .025), (.73 + i * .10, .21, .15 - i * .025), stone, .035)
    cylinder("RoofVent", (-.68, -.19, 1.20), .16, .20, steel)
    cylinder("VentCap", (-.68, -.19, 1.32), .22, .07, ivory)
    cylinder("RadioAerial", (.83, -.18, 1.44), .027, .82, steel)
    for z in [1.35, 1.52, 1.69]:
        block("AerialCrossbar", (.83, -.18, z), (.35, .04, .035), steel, .012)
    block("RoofBadge", (0, .03, 1.13), (.40, .42, .055), brass, .055)
    block("BadgeAnvil", (0, .025, 1.165), (.25, .12, .03), steel, .015)
    export("headquarters", merge=True)

    clear()
    block("PadFoundation", (0, 0, .035), (1.44, 1.14, .07), stone, .10)
    block("PadInset", (0, 0, .077), (1.22, .92, .018), ivory, .09)
    for x in [-.60, .60]:
        for y in [-.43, .43]:
            block("BrassCorner", (x, y, .095), (.14, .13, .025), brass, .025)
    export("station_pad", merge=True)

    for role in ["rifle", "breaker", "ranger", "rover", "ward", "relay", "recovery"]:
        clear()
        block("CounterTop", (0, 0, .57), (1.10, .44, .12), wood, .045)
        for x in [-.43, .43]:
            block("CounterLeg", (x, 0, .28), (.13, .34, .56), steel, .025)
        block("CounterTrim", (0, .225, .57), (1.06, .025, .07), brass, .012)
        if role == "rifle":
            for x in [-.32, 0, .32]:
                block("RackStock", (x, -.09, .74), (.12, .12, .20), olive, .03)
                block("RackBarrel", (x, -.09, .98), (.055, .07, .37), steel, .015)
        elif role == "breaker":
            for x in [-.30, .04]:
                cylinder("LauncherRack", (x, -.06, .91), .10, .58, steel)
                cylinder("LauncherLip", (x, -.06, 1.20), .13, .05, brass)
            block("ShellCase", (.33, .03, .77), (.23, .25, .27), olive, .04)
        elif role == "ranger":
            block("LongRifle", (0, -.05, .84), (.91, .07, .08), steel, .02)
            cylinder("ScopeStand", (.16, -.05, .94), .055, .20, rubber, rotation=(0, math.pi / 2, 0))
            for x in [-.39, .39]:
                cylinder("RackSupport", (x, -.05, .70), .035, .30, brass)
        elif role == "rover":
            block("ToolChest", (0, -.04, .79), (.64, .29, .32), olive, .055)
            for z in [.70, .79, .88]:
                block("DrawerPull", (0, .12, z), (.43, .035, .022), brass, .008)
            cylinder("SpareWheel", (.41, -.11, .86), .22, .13, rubber, rotation=(0, math.pi / 2, 0))
        elif role == "ward":
            block("ArmorPress", (0, -.05, .89), (.54, .26, .57), olive, .07)
            block("ShieldPlate", (0, .12, 1.0), (.37, .09, .40), ivory, .07)
            block("ShieldEmblem", (0, .175, 1.0), (.20, .025, .07), brass, .01)
        elif role == "relay":
            cylinder("Mast", (0, -.04, 1.16), .043, 1.12, steel)
            for z in [.90, 1.15, 1.40]:
                block("RelayElement", (0, -.04, z), (.65, .055, .035), brass, .012)
            block("Radio", (.26, .04, .77), (.30, .24, .28), olive, .045)
        else:
            block("RepairCabinet", (0, -.04, .85), (.72, .33, .47), ivory, .065)
            block("RepairStripeV", (0, .137, .87), (.07, .02, .27), olive, .01)
            block("RepairStripeH", (0, .14, .87), (.27, .02, .07), olive, .01)
        for i in range(3):
            block("SupplyToken" + str(i), (-.30 + i * .30, .06, .70), (.17, .15, .15), brass, .025)
        export("station_" + role, merge=True)

    clear()
    cylinder("CoinDisc", (0, 0, .05), .21, .10, brass)
    cylinder("CoinRim", (0, 0, .106), .19, .022, ivory)
    block("CoinMark", (0, 0, .123), (.20, .06, .016), brass, .012)
    export("scrap_coin", merge=True)

    for kind in ["watchtower", "rail_wagon", "signal_dish", "quarry_crane", "bridge_arch", "crystal_spire", "relay_mast", "repair_gantry", "floodgate", "orchard_tree", "supply_truck", "foundry_stack"]:
        clear()
        if kind == "watchtower":
            for x in [-.50, .50]:
                for y in [-.38, .38]:
                    block("TowerLeg", (x, y, 1.0), (.12, .12, 2.0), wood, .03)
            block("TowerFloor", (0, 0, 1.82), (1.30, 1.05, .16), wood, .06)
            block("TowerRoof", (0, 0, 2.65), (1.50, 1.18, .17), roof, .08)
            for x in [-.56, .56]:
                block("TowerCabin", (x, 0, 2.16), (.12, 1.01, .62), olive, .04)
            block("TowerRear", (0, -.43, 2.16), (1.15, .14, .62), olive, .04)
            for z in [.25, .50, .75, 1.0, 1.25, 1.5]:
                block("LadderRung", (0, -.46, z), (.56, .08, .065), wood, .015)
        elif kind in ["rail_wagon", "supply_truck"]:
            block("CargoDeck", (0, 0, .56), (1.65, 2.80, .22), steel, .07)
            block("CargoBox", (0, -.25, 1.16), (1.48, 2.08, 1.05), olive if kind == "supply_truck" else rust, .12)
            for y in [-1, -.5, 0, .5]:
                block("CargoRib", (0, y, 1.17), (1.53, .075, 1.11), steel, .02)
            wheels(.86, (-1.0, .94), .32)
            if kind == "supply_truck":
                block("TruckCab", (0, 1.0, .98), (1.38, .83, .89), roof, .15)
                block("Windscreen", (0, 1.435, 1.13), (1.03, .025, .33), glass, .045)
        elif kind in ["signal_dish", "relay_mast"]:
            block("RadioBase", (0, 0, .42), (.95, .75, .84), olive, .10)
            cylinder("Mast", (0, 0, 1.6), .065, 2.6, steel)
            if kind == "signal_dish":
                oval("Dish", (0, .05, 2.65), (.65, .12, .65), ivory)
                cylinder("DishReceiver", (0, .30, 2.65), .06, .50, brass, rotation=(math.pi / 2, 0, 0))
            else:
                for z in [1.8, 2.2, 2.6]:
                    block("SignalArm", (0, 0, z), (.95, .07, .055), brass, .018)
                oval("MastLamp", (0, 0, 2.98), (.12, .12, .13), glass)
        elif kind in ["quarry_crane", "repair_gantry"]:
            for x in [-.80, .80]:
                block("GantryFoot", (x, 0, .16), (.62, .72, .32), stone, .08)
                block("GantryColumn", (x, 0, 1.28), (.24, .28, 2.35), steel, .05)
            block("GantryCrossbeam", (0, 0, 2.50), (2.20, .38, .27), brass if kind == "quarry_crane" else roof, .065)
            cylinder("HoistCable", (.3, 0, 1.96), .028, .85, steel)
            block("HoistHook", (.30, 0, 1.55), (.19, .15, .19), brass, .05)
            if kind == "repair_gantry":
                cylinder("RepairVat", (0, -.22, .65), .42, 1.25, ivory)
                for z in [.30, .94]:
                    cylinder("VatBand", (0, -.22, z), .44, .08, olive)
        elif kind in ["bridge_arch", "floodgate"]:
            for x in [-.85, .85]:
                block("Pier", (x, 0, .75), (.55, .95, 1.50), stone, .14)
            block("BridgeLintel", (0, 0, 1.50), (2.45, 1.05, .30), ivory, .10)
            if kind == "floodgate":
                for x in [-.55, -.27, 0, .27, .55]:
                    block("GateSlat", (x, .15, .75), (.17, .16, 1.35), steel, .035)
                cylinder("GateWheel", (0, .27, 1.52), .22, .06, brass, rotation=(math.pi / 2, 0, 0))
            else:
                block("BrokenDeck", (0, -.55, 1.58), (1.10, .48, .18), stone, .07)
        elif kind == "crystal_spire":
            for x, y, size in [(-.37, 0, .68), (.15, .14, 1.08), (.47, -.20, .47)]:
                bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=size * .32, radius2=0, depth=size, location=(x, y, size * .5))
                obj = bpy.context.object
                obj.name = "Crystal"
                obj.data.materials.append(glass)
            block("CrystalBed", (0, 0, .09), (1.5, 1.12, .18), stone, .18)
        elif kind == "orchard_tree":
            cylinder("Trunk", (0, 0, .68), .15, 1.35, wood)
            for i in range(5):
                angle = i * math.tau / 5
                beam("Branch", (0, 0, .78), (math.cos(angle) * .53, math.sin(angle) * .50, 1.66), .10, wood)
                oval("Foliage", (math.cos(angle) * .45, math.sin(angle) * .43, 1.70), (.52, .45, .49), roof)
            for x, y in [(-.4, .21), (.32, -.32), (.1, .34)]:
                oval("Fruit", (x, y, 1.46), (.065, .065, .07), brass)
        else:
            block("FactoryBase", (0, 0, .50), (2.05, 1.58, 1.0), steel, .12)
            block("FactoryRoof", (0, 0, 1.04), (2.25, 1.78, .16), rust, .08)
            for x in [-.60, .60]:
                cylinder("FoundryStack", (x, -.20, 1.95), .29, 2.0, rust)
                cylinder("StackRim", (x, -.20, 2.98), .35, .13, steel)
            for x in [-.57, 0, .57]:
                block("FactoryWindow", (x, .808, .65), (.29, .025, .25), brass, .025)
        export(kind, merge=True)

    for kind in ["drill", "carrier", "storm"]:
        clear()
        width = .73 if kind == "drill" else .81
        block("ArmoredHull", (0, 0, .55), (width * 2, 1.92, .62), uniform, .17)
        block("HullDeck", (0, -.16, .93), (width * 1.8, 1.45, .18), dark, .08)
        wheels(width + .08, (-.68, 0, .68), .31)
        for side in [-1, 1]:
            block("TrackGuard", (side * (width + .06), 0, .70), (.27, 2.08, .18), uniform, .055)
        turret = block("TurretArmor", (0, -.20, 1.10), (.78, .69, .35), uniform, .13)
        cannon = cylinder("Cannon", (0, .48, 1.18), .10, .70, dark, rotation=(math.pi / 2, 0, 0))
        gun_pivot = pivot("TurretPivot", (0, -.20, 1.10), [turret, cannon])
        if kind == "drill":
            rotor_parts = [cylinder("DrillShaft", (0, 1.12, .49), .085, .92, dark, rotation=(math.pi / 2, 0, 0))]
            vertices, faces = [], []
            for i in range(49):
                t = i / 48
                angle = t * math.tau * 2.5
                radius = .34 * (1 - t) + .055
                for offset in [-.045, .045]:
                    vertices.append((math.sin(angle) * radius, .72 + t * .88 + offset, .49 + math.cos(angle) * radius))
                if i:
                    j = i * 2
                    faces.append((j - 2, j - 1, j + 1, j))
            mesh = bpy.data.meshes.new("OriginalHelicalDrill")
            mesh.from_pydata(vertices, [], faces)
            mesh.materials.append(brass)
            obj = bpy.data.objects.new("HelicalFlight", mesh)
            bpy.context.collection.objects.link(obj)
            rotor_parts.append(obj)
            pivot("DrillRotor", (0, .72, .49), rotor_parts)
        elif kind == "carrier":
            for x in [-.43, 0, .43]:
                cylinder("RepairReservoir", (x, -.33, 1.27), .17, .55, ivory)
                cylinder("ReservoirCap", (x, -.33, 1.57), .20, .07, dark)
            boom_parts = [block("Boom", (0, .15, 1.79), (.19, 1.50, .18), brass, .045), cylinder("RepairNozzle", (0, .86, 1.65), .10, .40, ivory)]
            pivot("RepairBoom", (0, -.47, 1.65), boom_parts)
            block("RepairMarkV", (0, 1.0, .61), (.10, .03, .40), ivory, .02)
            block("RepairMarkH", (0, 1.0, .61), (.40, .03, .10), ivory, .02)
        else:
            pod_parts = []
            for x in [-.48, .48]:
                for y in [-.10, .35]:
                    pod_parts.append(cylinder("RocketTube", (x, y, 1.45), .14, .62, dark, rotation=(math.pi / 2, 0, 0)))
                pod_parts.append(block("RocketPodArmor", (x, -.05, 1.20), (.47, .90, .16), uniform, .065))
            for part in pod_parts:
                part.parent = gun_pivot
                part.matrix_parent_inverse = gun_pivot.matrix_world.inverted()
            dish = oval("ChargeDishFace", (0, -.58, 1.67), (.38, .15, .17), brass)
            pivot("ChargeDish", (0, -.58, 1.67), [dish])
        for x in [-.51, .51]:
            block("Headlamp", (x, .976, .61), (.21, .035, .16), brass, .04)
        export("vehicle_" + kind, merge=True)
