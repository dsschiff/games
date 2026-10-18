"""Gear's original brass foundry and articulated raiders. Never renders.

blender --background --factory-startup --python art/source/build_assets.py
Blender 4.5.14 LTS. Mesh utilities/float canonicalization follow the accepted
Frontline technique; every silhouette, rig and prop below is authored for Gear.
Animation is runtime joint posing; bones never drive simulation or root motion.
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from mesh_tools import *

BRASS = material("Brass", (.42, .29, .13), .67, .22)
EDGE = material("PolishedRim", (.63, .49, .25), .58, .25)
IRON = material("Iron", (.12, .20, .22), .72, .25)
TEAL = material("Enamel", (.10, .27, .29), .72, .12)
IVORY = material("Ivory", (.52, .50, .39), .75, .1)
GLASS = material("MintLens", (.20, .50, .39), .48, .10)
RED = material("Carapace", (.67, .23, .17), .7, .12)
DARK = material("Chitin", (.24, .14, .17), .8)


def rod(name, a, b, radius, mat, bone=None):
    a, b = mathutils.Vector(a), mathutils.Vector(b)
    obj = cylinder(name, (a+b)/2, radius, (b-a).length, mat, bone)
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return obj


def group_surfaces(objects):
    materials = list(dict.fromkeys(obj.data.materials[0] for obj in objects))
    groups = [(mat, [obj for obj in objects if obj.data.materials[0] == mat]) for mat in materials]
    for mat, group in groups:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        if len(group) > 1:
            bpy.ops.object.join()
        group[0].name = "Surface_" + mat.name


def rigged(name, positions, parents):
    arm = bpy.data.armatures.new("ClockworkJoints")
    rig = bpy.data.objects.new("GearRig", arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for joint, point in positions.items():
        bone = arm.edit_bones.new(joint)
        bone.head = point
        bone.tail = (point[0], point[1], point[2]+.10)
        if joint in parents:
            bone.parent = arm.edit_bones[parents[joint]]
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj, joint in PARTS:
        group = obj.vertex_groups.new(name=joint)
        group.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
        mod = obj.modifiers.new("Rigid articulated brass", "ARMATURE")
        mod.object = rig
        obj.parent = rig
    group_surfaces([obj for obj, _ in PARTS])
    rig["authorship"] = "Original Gear Bastion procedural sculpture and rigid weights"
    rig["animation"] = "Independent runtime articulated gait, strike, recoil, hit, death and victory"
    rig["forward"] = "+Y Blender / -Z Godot"
    export(name)


def automaton(role):
    clear()
    # Inset piston waist, rounded riveted cuirass, clock-face visor and true hands.
    cylinder("Waist bearing", (0, 0, .64), .16, .17, IRON, "Root")
    oval("Breastplate", (0, 0, .91), (.28, .18, .30), BRASS, "Torso")
    block("Chest enamel", (0, .16, .93), (.32, .06, .30), TEAL, .055, "Torso")
    cylinder("Chest clock", (0, .205, .94), .085, .035, EDGE, "Torso", (math.pi/2, 0, 0))
    rod("Clock hand", (0, .229, .94), (.035, .229, 1), .009, IRON, "Torso")
    cylinder("Neck bearing", (0, 0, 1.19), .085, .12, IRON, "Head")
    oval("Helmet", (0, 0, 1.35), (.235, .21, .23), BRASS, "Head")
    block("Visor recess", (0, .185, 1.36), (.34, .055, .12), IRON, .03, "Head")
    for side in [-1, 1]:
        cylinder("Goggle lens", (side*.085, .223, 1.37), .045, .045, GLASS, "Head", (math.pi/2, 0, 0))
        cylinder("Ear cog", (side*.23, 0, 1.35), .075, .05, EDGE, "Head", (0, math.pi/2, 0))
    if role == "guard":
        block("Crest", (0, -.02, 1.57), (.065, .23, .11), TEAL, .02, "Head")
    elif role == "ranger":
        cylinder("Rangefinder", (.14, .27, 1.40), .066, .14, EDGE, "Head", (math.pi/2, 0, 0))
    else:
        cylinder("Pressure tank", (0, -.21, 1.00), .17, .44, IVORY, "Torso")
        cylinder("Tank cap", (0, -.21, 1.24), .12, .08, EDGE, "Torso")
    positions = {"Root": (0, 0, 0), "Torso": (0, 0, .66), "Head": (0, 0, 1.19)}
    parents = {"Torso": "Root", "Head": "Torso"}
    for side, suffix in [(-1, "L"), (1, "R")]:
        x = side*.15
        for joint, point, parent in [
            ("Thigh", (x, 0, .63), "Root"), ("Shin", (x, 0, .35), "Thigh"+suffix),
            ("Foot", (x, 0, .12), "Shin"+suffix),
            ("UpperArm", (side*.30, 0, 1.06), "Torso"),
            ("Forearm", (side*.36, .03, .84), "UpperArm"+suffix),
            ("Hand", (side*.34, .22, .80), "Forearm"+suffix)]:
            positions[joint+suffix] = point
            parents[joint+suffix] = parent
        oval("Hip joint", (x, 0, .61), (.10, .11, .10), IRON, "Thigh"+suffix)
        block("Thigh case", (x, 0, .48), (.18, .21, .27), BRASS, .055, "Thigh"+suffix)
        oval("Knee ball", (x, 0, .35), (.105, .105, .105), IRON, "Shin"+suffix)
        rod("Shin piston", (x, .04, .34), (x, .04, .15), .065, EDGE, "Shin"+suffix)
        block("Boot", (x, .07, .075), (.22, .34, .15), IRON, .045, "Foot"+suffix)
        oval("Shoulder bearing", (side*.30, 0, 1.05), (.12, .13, .13), IVORY, "UpperArm"+suffix)
        rod("Arm case", (side*.33, 0, 1.02), (side*.36, .03, .85), .075, BRASS, "UpperArm"+suffix)
        oval("Elbow", (side*.36, .03, .84), (.073, .073, .073), IRON, "Forearm"+suffix)
        rod("Forearm piston", (side*.36, .06, .82), (side*.34, .21, .80), .065, EDGE, "Forearm"+suffix)
        block("Mitten", (side*.34, .23, .79), (.13, .16, .13), IRON, .04, "Hand"+suffix)
    positions["Weapon"] = (.34, .24, .80)
    parents["Weapon"] = "HandR"
    if role == "guard":
        # Mechanical shield and a broad striking hammer, not a recolored gunner.
        block("Shield rim", (-.35, .32, .82), (.44, .12, .62), EDGE, .09, "ForearmL")
        block("Shield enamel", (-.35, .392, .83), (.32, .035, .45), TEAL, .065, "ForearmL")
        cylinder("Shield boss", (-.35, .43, .83), .09, .07, BRASS, "ForearmL", (math.pi/2, 0, 0))
        rod("Hammer haft", (.34, .25, .75), (.34, .30, 1.25), .036, IRON, "Weapon")
        block("Hammer head", (.34, .30, 1.28), (.38, .20, .20), BRASS, .04, "Weapon")
    elif role == "ranger":
        block("Clock rifle", (.34, .42, .85), (.12, .48, .13), IVORY, .035, "Weapon")
        rod("Long barrel", (.34, .60, .86), (.34, 1.02, .86), .033, IRON, "Weapon")
        cylinder("Muzzle rim", (.34, 1.02, .86), .047, .07, EDGE, "Weapon", (math.pi/2, 0, 0))
        block("Bow limb", (.34, .63, .86), (.48, .055, .065), BRASS, .022, "Weapon")
        rod("Sight", (.34, .38, .96), (.34, .54, .96), .03, IRON, "Weapon")
    else:
        # Shoulder-held pressure mortar; muzzle belongs to the Weapon bone.
        rod("Mortar tube", (.34, .17, .81), (.34, .72, 1.10), .105, IRON, "Weapon")
        rod("Mortar rim", (.34, .65, 1.06), (.34, .75, 1.12), .137, EDGE, "Weapon")
        block("Cradle", (.34, .22, .79), (.24, .27, .17), BRASS, .035, "Weapon")
    rigged(role, positions, parents)


def insect(role):
    clear()
    sizes = {"beetle": (.35, .45, .30), "shell": (.43, .46, .39),
             "skitter": (.22, .37, .23), "spitter": (.32, .46, .29),
             "swarm": (.24, .30, .20), "carapace": (.49, .55, .42),
             "captain": (.55, .65, .48), "siege": (.58, .72, .46), "matriarch": (.66, .90, .55)}
    sx, sy, sz = sizes[role]
    shell = material("Carapace_"+role, {"shell": (.60, .52, .31), "skitter": (.34, .25, .36),
        "spitter": (.42, .53, .22), "swarm": (.75, .34, .23), "carapace": (.37, .33, .39),
        "captain": (.72, .24, .14), "siege": (.42, .29, .20), "matriarch": (.43, .18, .35)}.get(role, (.67, .23, .17)), .65, .12)
    high = role in ["captain", "siege", "matriarch"]
    height = .46 if high else .31
    positions = {"Root": (0, 0, 0), "Torso": (0, 0, height),
                 "Head": (0, sy*.64, height), "Weapon": (0, sy*.95, height)}
    parents = {"Torso": "Root", "Head": "Torso", "Weapon": "Head"}
    oval("Abdomen", (0, -sy*.20, height+sz*.28), (sx, sy, sz), shell, "Torso")
    rod("Split shell seam", (0, -sy*.94, height+sz*.30), (0, sy*.37, height+sz), .018, DARK, "Torso")
    oval("Head carapace", (0, sy*.70, height), (sx*.63, sy*.43, sz*.67), DARK, "Head")
    for side in [-1, 1]:
        oval("Compound eye", (side*sx*.47, sy*.93, height+sz*.19), (.055, .075, .048), GLASS if role=="spitter" else EDGE, "Head")
        for i in range(3):
            suffix = ("L" if side<0 else "R")+str(i)
            hip = (side*sx*.70, sy*(.5-i*.53), height)
            knee = (side*(sx+.22), hip[1]+(.12 if i==0 else -.12), .22)
            foot = (side*(sx+.37), hip[1]+(.27 if i==0 else -.25), .045)
            positions["Leg"+suffix] = hip
            positions["Tip"+suffix] = knee
            parents["Leg"+suffix] = "Torso"
            parents["Tip"+suffix] = "Leg"+suffix
            oval("Hip hinge", hip, (.065, .065, .065), DARK, "Leg"+suffix)
            rod("Femur", hip, knee, .047 if high else .033, shell, "Leg"+suffix)
            rod("Tarsus", knee, foot, .038 if high else .024, DARK, "Tip"+suffix)
            oval("Foot pad", foot, (.067, .09, .037), DARK, "Tip"+suffix)
        jaw = side*sx*.36
        rod("Mandible root", (jaw, sy*.9, height-.02), (jaw*1.2, sy*1.22, height-.09), .045, EDGE, "Weapon")
        rod("Mandible hook", (jaw*1.2, sy*1.22, height-.09), (jaw*.40, sy*1.39, height-.06), .033, EDGE, "Weapon")
    if role in ["shell", "carapace", "captain"]:
        for i in range(3):
            oval("Armored ridge", (0, -sy*.66+i*sy*.39, height+sz*.78), (sx*.94, .09, .09), IRON if role=="carapace" else EDGE, "Torso")
    if role in ["carapace", "captain", "matriarch"]:
        for x in [-sx*.5, 0, sx*.5]:
            rod("Crown horn", (x, sy*.65, height+sz*.3), (x*.8, sy*.87, height+sz*.95), .05, EDGE, "Head")
    if role == "spitter":
        for x in [-sx*.52, sx*.52]:
            oval("Acid bladder", (x, -sy*.30, height+sz*.85), (.14, .23, .17), GLASS, "Torso")
        rod("Spitter nozzle", (0, sy*.94, height), (0, sy*1.4, height+.03), .07, IRON, "Weapon")
    if role == "swarm":
        for side in [-1, 1]:
            joint="Wing"+("L" if side<0 else "R")
            positions[joint]=(side*.10, 0, height+sz*.6);parents[joint]="Torso"
            oval("Wing", (side*.28, -.05, height+sz*.8), (.24, .29, .025), IVORY, joint)
    if role == "siege":
        block("Siege saddle", (0, -.10, height+sz*.9), (.65, .65, .20), IRON, .06, "Torso")
        rod("Siege cannon", (0, .05, height+sz+ .08), (0, sy*1.45, height+sz+.08), .12, BRASS, "Weapon")
        cylinder("Siege muzzle", (0, sy*1.45, height+sz+.08), .16, .10, IRON, "Weapon", (math.pi/2, 0, 0))
    if role == "matriarch":
        for i in range(3):
            oval("Brood lantern", ((i-1)*.38, -.44, height+sz*.82), (.19, .27, .22), GLASS, "Torso")
        for side in [-1, 1]:
            joint="Wing"+("L" if side<0 else "R")
            positions[joint]=(side*.24, -.1, height+sz*.7);parents[joint]="Torso"
            oval("Royal wing", (side*.70, -.35, height+sz*.75), (.53, .77, .055), shell, joint)
    rigged(role, positions, parents)


def cog(name, radius=.8, core=False):
    clear()
    cylinder("Gear web", (0, 0, .10), radius*.87, .20, BRASS)
    cylinder("Inset rim", (0, 0, .215), radius*.67, .045, IRON)
    cylinder("Face ring", (0, 0, .25), radius*.48, .06, EDGE)
    for i in range(16):
        angle=i*math.tau/16
        tooth=block("Machined tooth", (math.cos(angle)*radius*.90, math.sin(angle)*radius*.90, .11), (.21, .19, .23), EDGE, .025)
        tooth.rotation_euler.z=angle
    for i in range(6):
        a=i*math.tau/6
        cylinder("Rivet", (math.cos(a)*radius*.59, math.sin(a)*radius*.59, .255), .035, .05, BRASS)
    cylinder("Axle", (0, 0, .33), .12 if not core else .22, .16, GLASS if core else IVORY)
    group_surfaces([o for o in bpy.context.scene.objects if o.type=="MESH"])
    export(name)


def props():
    for role in ["guard", "ranger", "mortar"]:
        clear()
        cylinder("Generator plinth", (0, 0, .12), .50, .24, IRON)
        block("Generator enamel", (0, -.12, .43), (.64, .48, .54), TEAL, .10)
        for side in [-1, 1]:
            cylinder("Piston sleeve", (side*.30, .12, .39), .08, .50, BRASS)
            cylinder("PistonRod"+("L" if side<0 else "R"), (side*.30, .12, .70), .035, .26, EDGE)
        cylinder("Assembly ring", (0, .20, .32), .27, .18, EDGE, rotation=(math.pi/2, 0, 0))
        cylinder("Exit aperture", (0, .31, .32), .20, .03, IRON, rotation=(math.pi/2, 0, 0))
        if role=="guard":
            block("Shield sign", (0, -.15, .84), (.38, .09, .42), IVORY, .07)
        elif role=="ranger":
            rod("Rifle sign", (-.24, -.15, .83), (.24, -.15, .83), .065, IVORY)
            block("Scope sign", (0, -.15, .94), (.15, .10, .08), EDGE, .02)
        else:
            rod("Mortar sign", (0, -.15, .75), (0, .06, 1.08), .12, IVORY)
        for obj in bpy.context.scene.objects:
            if obj.type=="MESH":
                PARTS.append((obj,"PistonL" if obj.name=="PistonRodL" else "PistonR" if obj.name=="PistonRodR" else "Root"))
        rigged("generator_"+role,{"Root":(0,0,0),"PistonL":(-.30,.12,.70),"PistonR":(.30,.12,.70)}, {"PistonL":"Root","PistonR":"Root"})
    clear()
    stone=material("FoundryStone", (.54, .51, .40), .88)
    for side in [-1, 1]:
        block("Gate pier", (side*.63, 0, .58), (.38, .48, 1.16), stone, .08)
        block("Brass foot", (side*.63, 0, .12), (.49, .60, .24), BRASS, .045)
    # Individual radial keystones form an open semicircular arch.
    for i in range(11):
        a=i*math.pi/10
        block("Arch keystone", (math.cos(a)*.63, 0, 1.08+math.sin(a)*.63), (.25, .49, .27), EDGE if i==5 else stone, .035).rotation_euler.y=a-math.pi/2
    block("Gate crest", (0, .28, 1.73), (.24, .10, .26), TEAL, .04)
    group_surfaces([o for o in bpy.context.scene.objects if o.type=="MESH"])
    export("arch")
    clear()
    block("Wall body", (0, 0, .34), (1, .44, .68), stone, .065)
    block("Wall cornice", (0, 0, .72), (1.08, .55, .14), BRASS, .04)
    for x in [-.33, .33]:
        block("Wall tooth", (x, 0, .89), (.28, .45, .24), stone, .035)
    group_surfaces([o for o in bpy.context.scene.objects if o.type=="MESH"])
    export("wall")
    for act in range(1,4):
        clear()
        color=[(.46,.47,.34),(.39,.32,.29),(.35,.38,.43)][act-1]
        rock=material("RegionStone"+str(act), color, .94)
        for i in range(3):
            block("Rounded strata", ((i-1)*.48, (i%2)*.24, .35+i*.18), (.9,.85,.70+i*.15), rock, .17).rotation_euler.z=i*.37
        if act==1:
            rod("Dock pipe", (-.7,0,.9), (.7,0,.9), .11, BRASS)
            for x in [-.5,.5]:
                cylinder("Pipe collar", (x,0,.9), .15,.10, EDGE, rotation=(0,math.pi/2,0))
        elif act==2:
            cylinder("Furnace stack", (0,0,1.10), .28,1.0, IRON)
            cylinder("Hot rim", (0,0,1.64), .34,.12, material("Kiln",(.76,.38,.16)), rotation=None)
        else:
            block("Citadel pillar", (0,0,1.3), (.48,.48,1.6), rock,.09)
            oval("Mint beacon", (0,0,2.1), (.17,.17,.25), GLASS)
        group_surfaces([o for o in bpy.context.scene.objects if o.type=="MESH"])
        export("region_"+str(act))


def deck_and_environment():
    clear()
    deck=material("DeckEnamel",(.22,.30,.30),.86,.12)
    recess=material("SocketRecess",(.12,.20,.21),.86,.08)
    block("Beveled foundry bed",(0,0,-.38),(10.40,12.0,.52),IRON,.14)
    floor=block("Inset assembly floor",(0,0,-.045),(10.12,11.72,.09),deck,.08)
    cutters=[]
    def cut_box(location, dimensions):
        bpy.ops.mesh.primitive_cube_add(size=1,location=location)
        obj=bpy.context.object;obj.scale=dimensions
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        cutters.append(obj)
    for x in [-5.12,5.12]:
        block("Brass rim side",(x,0,.005),(.15,11.84,.03),BRASS,.015)
    for y in [-5.92,5.92]:
        block("Brass rim end",(0,y,.005),(10.26,.15,.03),BRASS,.015)
    for y in range(4):
        for x in range(5):
            px=(x-2)*2;py=(1.5-y)*math.sqrt(8)
            cylinder("Inset socket well",(px,py,-.108),.30,.015,recess)
            bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.305,depth=.5,location=(px,py,-.05))
            cutters.append(bpy.context.object)
            bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,location=(px,py,-.025),major_radius=.34,minor_radius=.035)
            finish(bpy.context.object,"Socket collar",BRASS)
            for dx in [-.67,.67]:
                cylinder("Recessed fastener",(px+dx,py,-.005),.035,.015,EDGE)
            if x<4:
                cut_box((px+1,py,0),(1.24,.06,.08))
                block("Conduit inset",(px+1,py,-.040),(1.24,.05,.01),recess,.005)
            if y<3:
                cut_box((px,py-math.sqrt(2),0),(.06,2.04,.08))
                block("Conduit inset",(px,py-math.sqrt(2),-.040),(.05,2.04,.01),recess,.005)
    bpy.ops.object.select_all(action="DESELECT")
    for cutter in cutters:
        cutter.select_set(True)
    bpy.context.view_layer.objects.active=cutters[0]
    bpy.ops.object.join()
    cutter=cutters[0]
    bpy.context.view_layer.objects.active=floor
    boolean=floor.modifiers.new("Machined sockets and conduits","BOOLEAN")
    boolean.operation="DIFFERENCE";boolean.solver="EXACT";boolean.object=cutter
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
    group_surfaces([o for o in bpy.context.scene.objects if o.type=="MESH"])
    export("foundry_deck")
    for name, outline, color in [
        ("paver",[(-.40,-.54),(.28,-.54),(.41,-.32),(.35,.46),(-.25,.55),(-.42,.31)],(.36,.35,.30)),
        ("paver_broken",[(-.42,-.32),(-.18,-.40),(.40,-.35),(.40,.20),(.18,.20),(.18,.39),(-.36,.35)],(.32,.33,.285)),
        ("paver_long",[(-.50,-.25),(-.36,-.37),(.42,-.33),(.50,-.12),(.41,.35),(-.44,.32)],(.38,.37,.31))]:
        clear()
        paving=material("PavingStone_"+name,color,.96)
        edge=material("PavingEdge",(.30,.31,.27),.95)
        n=len(outline)
        vertices=[(x,y,z) for z in [-.09,0] for x,y in outline]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        mesh=bpy.data.meshes.new("Irregular beveled flagstone");mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new("Hand shaped paving",mesh);bpy.context.collection.objects.link(obj)
        obj.data.materials.append(paving);obj.data.materials.append(edge)
        for poly in obj.data.polygons: poly.material_index=0 if poly.index==1 else 1
        bpy.context.view_layer.objects.active=obj;obj.select_set(True)
        bevel=obj.modifiers.new("Soft chipped edge","BEVEL");bevel.width=.025;bevel.segments=2
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        export(name)
    clear()
    earth=material("WornCourtyard",(.30,.30,.25),.98)
    vertices=[(-2.1,-1.3,-.012),(-.8,-1.7,-.012),(1.4,-1.35,-.012),(2.0,-.2,-.012),(1.4,1.2,-.012),(-.6,1.5,-.012),(-2.0,.7,-.012)]
    mesh=bpy.data.meshes.new("Authored irregular courtyard patch")
    mesh.from_pydata(vertices,[],[tuple(range(len(vertices)))])
    mesh.update();obj=bpy.data.objects.new("Flush worn stone/earth",mesh);bpy.context.collection.objects.link(obj)
    finish(obj,"Courtyard wear",earth)
    export("courtyard_patch")
    clear()
    stone=material("WorkshopStone",(.42,.43,.39),.90)
    block("Workshop plinth",(0,0,.10),(1.04,.86,.20),stone,.08)
    block("Boiler house",(0,0,.52),(.82,.68,.84),TEAL,.11)
    block("Workshop roof",(0,0,.98),(1.03,.91,.16),IRON,.07)
    cylinder("Copper pressure vessel",(0,-.02,1.25),.25,.55,BRASS)
    cylinder("Vessel collar",(0,-.02,1.54),.28,.09,EDGE)
    cylinder("Chimney",(.31,-.20,1.44),.09,.94,IRON)
    cylinder("Chimney lip",(.31,-.20,1.94),.12,.10,BRASS)
    cylinder("Dial rim",(0,.38,.67),.17,.07,EDGE,rotation=(math.pi/2,0,0))
    cylinder("Dial face",(0,.425,.67),.13,.02,IVORY,rotation=(math.pi/2,0,0))
    rod("Dial needle",(0,.442,.67),(.065,.442,.74),.012,IRON)
    for side in [-1,1]:
        rod("Copper riser",(side*.39,.22,.18),(side*.39,.22,.85),.045,BRASS)
        rod("Elbow pipe",(side*.39,.22,.85),(side*.19,.22,.85),.045,BRASS)
    group_surfaces([o for o in bpy.context.scene.objects if o.type=="MESH"])
    export("workshop")


def manifest():
    rows=[]
    for path in sorted(OUT.glob("*.glb")):
        raw=path.read_bytes(); length=struct.unpack_from("<I",raw,12)[0]; doc=json.loads(raw[20:20+length])
        tip = None
        role = path.stem
        if role in ["guard","ranger","mortar"]:
            tip = {"guard":[.34,1.28,-.40], "ranger":[.34,.86,-1.055], "mortar":[.34,1.12,-.75]}[role]
        elif role in ["beetle","shell","skitter","spitter","swarm","carapace","captain","siege","matriarch"]:
            sy = {"beetle":.45,"shell":.46,"skitter":.37,"spitter":.46,"swarm":.30,"carapace":.55,"captain":.65,"siege":.72,"matriarch":.90}[role]
            height = .46 if role in ["captain","siege","matriarch"] else .31
            tip = [0,height-.06,-sy*1.39]
            if role=="spitter": tip=[0,height+.03,-sy*1.4]
            if role=="siege": tip=[0,1.00,-sy*1.45-.05]
        rows.append({"file":"models/"+path.name,"sha256":hashlib.sha256(raw).hexdigest(),"bytes":len(raw),"contact_socket_godot":tip,
            "triangles":sum(doc["accessors"][p["indices"]]["count"]//3 for mesh in doc.get("meshes",[]) for p in mesh["primitives"]),
            "mesh_nodes":len(doc.get("meshes",[])),"materials":[m["name"] for m in doc.get("materials",[])],
            "skin_joints":[len(s["joints"]) for s in doc.get("skins",[])],
            "joints":[doc["nodes"][j]["name"] for s in doc.get("skins",[]) for j in s["joints"]]})
    source=Path(__file__)
    result={"schema_version":1,"authorship":"Original Gear Bastion authored brass machinery, automata and insect sculpture; no external art",
        "blender":"4.5.14 LTS 62c1db4208e8","portable_archive_sha256":"b9533d2397ac1984db4466fb23a7a4649391cca93f6e84209f9bcc60d071c8b9",
        "generator_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),
        "mesh_helpers_sha256":hashlib.sha256(source.with_name("mesh_tools.py").read_bytes()).hexdigest(),
        "units":"meters; Blender +Y forward / Godot -Z forward; glTF Y-up",
        "animation":{"owner":"scripts/presentation/actor.gd","method":"rigid-weight skeletal posing, no root motion or rule callbacks",
            "states":["idle","independently phased stance/swing","aim","strike","fire/recoil","hit","death","victory"]},
        "status":"CPU export only; visible quality and frame timing await real rendered review","assets":rows}
    (OUT.parent/"manifest.json").write_bytes((json.dumps(result,indent=2)+"\n").encode("utf-8"))


import mathutils
for role in ["guard","ranger","mortar"]:
    automaton(role)
for role in ["beetle","shell","skitter","spitter","swarm","carapace","captain","siege","matriarch"]:
    insect(role)
cog("drive")
cog("core", core=True)
props()
deck_and_environment()
manifest()
print("GEAR_ASSET_EXPORT_COMPLETE", OUT)
