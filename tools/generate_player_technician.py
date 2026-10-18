import bpy
import math
import os
from mathutils import Matrix, Vector


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(PROJECT_ROOT, "assets", "models")
SOURCE_DIR = os.path.join(ASSET_DIR, "source")
os.makedirs(SOURCE_DIR, exist_ok=True)
OUT = os.path.join(SOURCE_DIR, "player_technician.blend")
PREVIEW = os.path.join(ASSET_DIR, "player_technician_preview.png")


def repair_arm_connections():
    """Keep rigid modular sleeves, cuffs and gloves connected in the same frame.

    An explicit front axis avoids the roll ambiguity of tracking a nearly
    downward Z axis, which previously put the reflectors inside the arms.
    This also works on an existing static source without rebuilding the face.
    """
    for side, label in ((-1, 'L'), (1, 'R')):
        shoulder = Vector((side * .25, 0, 1.18))
        elbow = Vector((side * .34, -.005, .99))
        wrist = Vector((side * .385, -.035, .82))

        def orient(obj, center, rotation, dimensions):
            obj.rotation_mode = 'QUATERNION'
            parent_rotation = obj.parent.matrix_world.to_quaternion()
            obj.rotation_quaternion = parent_rotation.inverted() @ rotation
            obj.location = obj.parent.matrix_world.inverted() @ center
            obj.dimensions = dimensions
            bpy.context.view_layer.update()

        def frame(a, b):
            axis_z = (b - a).normalized()
            axis_x = Vector((0, 1, 0)).cross(axis_z).normalized()
            axis_y = axis_z.cross(axis_x).normalized()
            return Matrix((axis_x, axis_y, axis_z)).transposed().to_quaternion()

        upper_q = frame(shoulder, elbow)
        orient(bpy.data.objects['Upper sleeve ' + label], (shoulder + elbow) / 2,
               upper_q, (.16, .22, (elbow - shoulder).length * 1.035))
        q = frame(elbow, wrist)
        length = (wrist - elbow).length * 1.08
        center = (elbow + wrist) / 2
        orient(bpy.data.objects['Forearm sleeve ' + label], center,
               q, (.135, .18, length))
        # A thin inlay touches the front of the sleeve, rather than enclosing
        # the arm as a thick, world-aligned bracelet.
        orient(bpy.data.objects['Sleeve reflector ' + label],
               center + q @ Vector((0, -.091, length * .28)), q, (.112, .008, .028))
        glove_center = wrist + q @ Vector((0, 0, .045))
        orient(bpy.data.objects['Glove ' + label], glove_center, q, (.14, .18, .15))
        orient(bpy.data.objects['Thumb ' + label],
               glove_center + q @ Vector((side * .06, -.035, .015)),
               q, (.065, .085, .085))


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.collections, bpy.data.materials, bpy.data.meshes, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name, color, roughness=0.82, metallic=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.5
    return mat


def set_material(obj, mat):
    obj.data.materials.append(mat)
    return obj


def bevel_cube(name, loc, dims, mat, bevel=0.08, segments=1, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    set_material(obj, mat)
    if bevel:
        mod = obj.modifiers.new("Soft worn edges", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.affect = "EDGES"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        norm = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=norm.name)
    return obj


def ico(name, loc, scale, mat, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return set_material(obj, mat)


def cylinder_between(name, a, b, radius, mat, vertices=8, radius2=None):
    a, b = Vector(a), Vector(b)
    direction = b - a
    mid = (a + b) / 2
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=direction.length, location=mid)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius2, depth=direction.length, location=mid)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return set_material(obj, mat)


def parent_to(obj, parent):
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


clear_scene()
scene = bpy.context.scene
root_collection = bpy.data.collections.new("PLAYER | modular technician")
scene.collection.children.link(root_collection)
presentation = bpy.data.collections.new("STUDIO | preview only")
scene.collection.children.link(presentation)
PALETTE = {
    "skin": (0.57,0.32,0.19), "hair": (0.055,0.025,0.018),
    "suit": (0.025,0.16,0.20), "vest": (0.70,0.205,0.035),
    "boots": (0.045,0.06,0.067), "reflective": (0.77,0.78,0.62),
}
materials = {key:material(key.title()+" | editable",rgb) for key,rgb in PALETTE.items()}
skin,hair,suit,vest,boots,ivory = [materials[k] for k in ('skin','hair','suit','vest','boots','reflective')]
dark = material("Face | dark brown",(0.025,0.013,0.009))
white = material("Eyes | warm white",(0.70,0.70,0.57))
metal = material("Equipment | graphite",(0.10,0.13,0.14))
light = material("Battery | cyan indicator",(0.09,0.55,0.58),emission=(0.04,0.45,0.48))
root = bpy.data.objects.new('Player_Technician',None)
root_collection.objects.link(root)
root['Instructions'] = 'Static editable model. Front -Y, up Z, feet on ground. Separate hair, ponytail, vest, headset, battery, limbs. Palette in generator. No animation or game changes.'
root['Height_m'] = 1.72

def pivot(name,loc,parent=root):
    obj=bpy.data.objects.new(name,None)
    root_collection.objects.link(obj)
    obj.location=loc
    bpy.context.view_layer.update()
    parent_to(obj,parent)
    obj.empty_display_type='PLAIN_AXES'
    obj.empty_display_size=.08
    return obj

def block(name,loc,dims,mat,parent=root,bevel=.012,rotation=None):
    obj=bevel_cube(name,loc,dims,mat,bevel,1,rotation)
    for c in list(obj.users_collection): c.objects.unlink(obj)
    root_collection.objects.link(obj)
    bpy.context.view_layer.update()
    parent_to(obj,parent)
    return obj

def beam(name,a,b,width,depth,mat,parent):
    a,b=Vector(a),Vector(b)
    obj=block(name,(a+b)/2,(width,depth,(b-a).length),mat,parent)
    obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=(b-a).to_track_quat('Z','Y')
    return obj

body=pivot('Torso_Pivot',(0,0,.77))
block('Suit | fitted work torso',(0,0,1.005),(.43,.29,.45),suit,body,.022)
block('Hips | work trousers',(0,.005,.76),(.43,.29,.18),suit)
block('Belt | utility',(0,-.003,.81),(.45,.31,.065),boots)
block('Buckle',(0,-.166,.81),(.075,.025,.055),metal,bevel=.004)
# Split vest and broad reflective strips stay legible from above.
for side,label in ((-1,'L'),(1,'R')):
    block('Vest '+label+' | front panel',(side*.128,-.163,1.035),(.19,.065,.37),vest,body,.014)
    block('Vest '+label+' | shoulder',(side*.14,-.01,1.225),(.15,.32,.065),vest,body,.012)
    block('Reflector '+label+' | front',(side*.13,-.201,1.14),(.165,.012,.042),ivory,body,.002)
block('Vest | back',(0,.16,1.025),(.43,.055,.37),vest,body,.015)
block('Reflector | back',(0,.192,1.15),(.39,.012,.045),ivory,body,.002)
block('Suit | neckline',(0,-.15,1.23),(.13,.05,.06),boots,body,.008)
block('Neck',(0,0,1.285),(.155,.17,.13),skin,body)
head=pivot('Head_Pivot',(0,0,1.34),body)
block('Head | square face',(0,-.015,1.485),(.45,.37,.43),skin,head,.035)
block('Ear L',(-.233,-.005,1.45),(.055,.08,.09),skin,head,.01)
block('Ear R',(.233,-.005,1.45),(.055,.08,.09),skin,head,.01)
for side in (-1,1):
    block('Eye white '+str(side),(side*.105,-.204,1.50),(.09,.018,.055),white,head,.005)
    block('Pupil '+str(side),(side*.098,-.216,1.50),(.040,.012,.049),dark,head,.003)
    block('Brow '+str(side),(side*.108,-.214,1.558),(.105,.018,.023),hair,head,.003,(0,0,side*.07))
block('Nose',(0,-.221,1.445),(.055,.055,.065),skin,head,.008)
block('Mouth | determined',(0,-.208,1.382),(.095,.012,.014),dark,head,.003)
block('Hair | crown',(0,.015,1.685),(.48,.40,.11),hair,head,.025)
block('Hair | back',(0,.165,1.535),(.45,.09,.30),hair,head,.018)
block('Hair | swept fringe',(-.07,-.192,1.64),(.31,.065,.10),hair,head,.012,(0,0,-.12))
block('Hair | temple L',(-.208,-.075,1.565),(.065,.25,.20),hair,head,.012)
block('Hair | temple R',(.212,-.005,1.60),(.06,.22,.15),hair,head,.012)
ponytail=pivot('Ponytail_Pivot',(.14,.22,1.61),head)
block('Ponytail | tie',(.175,.245,1.595),(.13,.12,.11),vest,ponytail,.014)
block('Ponytail | upper block',(.25,.295,1.535),(.21,.18,.23),hair,ponytail,.022,(0,-.38,-.18))
block('Ponytail | lower block',(.30,.31,1.40),(.17,.15,.17),hair,ponytail,.018,(0,-.18,-.12))
# Hearing protection rests at the collar, leaving the facial silhouette open.
headset=pivot('Headset | removable',(0,0,1.24),body)
block('Headset | rear band',(0,.12,1.25),(.35,.055,.055),metal,headset,.01)
for side in (-1,1):
    block('Headset | ear cup '+str(side),(side*.196,-.035,1.245),(.09,.13,.115),boots,headset,.016)
    block('Headset | orange insert '+str(side),(side*.244,-.035,1.245),(.012,.08,.065),vest,headset,.004)
battery=pivot('Battery | removable',(0,.24,1.02),body)
block('Battery | compact pack',(0,.257,1.035),(.27,.15,.29),metal,battery,.018)
block('Battery | casing stripe',(0,.338,1.07),(.19,.014,.055),ivory,battery,.003)
block('Battery | status light',(.065,.338,.98),(.035,.014,.035),light,battery,.003)
for side,label in ((-1,'L'),(1,'R')):
    leg=pivot('Leg_'+label+'_Pivot',(side*.123,0,.72))
    block('Thigh '+label,(side*.13,0,.585),(.185,.245,.28),suit,leg,.014)
    block('Knee pad '+label,(side*.13,-.129,.445),(.155,.035,.115),metal,leg,.009)
    block('Shin '+label,(side*.14,0,.325),(.17,.22,.27),suit,leg,.012)
    block('Boot '+label,(side*.145,-.052,.12),(.225,.34,.24),boots,leg,.019)
    block('Sole '+label,(side*.145,-.052,.028),(.23,.35,.055),metal,leg,.006)
    arm=pivot('Arm_'+label+'_Pivot',(side*.25,0,1.18),body)
    shoulder=(side*.25,0,1.18)
    elbow=(side*.34,-.005,.99)
    wrist=(side*.385,-.035,.82)
    beam('Upper sleeve '+label,shoulder,elbow,.16,.22,suit,arm)
    beam('Forearm sleeve '+label,elbow,wrist,.135,.18,suit,arm)
    block('Sleeve reflector '+label,(side*.365,-.035,.875),(.145,.19,.04),ivory,arm,.003)
    block('Glove '+label,(side*.395,-.045,.755),(.15,.19,.145),boots,arm,.016)
    block('Thumb '+label,(side*.335,-.105,.76),(.065,.09,.09),boots,arm,.01)
repair_arm_connections()
block('Belt | tool pouch',(-.255,.025,.79),(.115,.19,.17),boots,body,.012)
block('Pouch | latch',(-.316,-.045,.80),(.015,.055,.035),ivory,body,.002)
# Ground and studio staging are kept in a separate collection from the reusable asset.
ground_mat = material("Studio | warm slate", (0.055, 0.075, 0.08), roughness=0.92)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.018))
ground = bpy.context.object
ground.name = "Preview ground"
set_material(ground, ground_mat)
for collection in list(ground.users_collection):
    collection.objects.unlink(ground)
presentation.objects.link(ground)

world = scene.world or bpy.data.worlds.new("Zombie studio world")
scene.world = world
world.color = (0.075, 0.085, 0.09)
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.075, 0.085, 0.09, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45

cam_data = bpy.data.cameras.new("Preview camera")
cam = bpy.data.objects.new("Preview camera", cam_data)
presentation.objects.link(cam)
cam.location = (3.5, -7.5, 2.7)
aim(cam, (0, 0, 0.87))
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.35
scene.camera = cam

def area_light(name, location, energy, size, color):
    data = bpy.data.lights.new(name, type="AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    presentation.objects.link(obj)
    obj.location = location
    aim(obj, (0, 0, 1.0))

area_light("Key | soft warm", (2.8, -3.8, 5.1), 520, 4.0, (1.0, 0.79, 0.58))
area_light("Fill | cool", (-3.0, -1.8, 2.5), 300, 3.5, (0.48, 0.70, 0.78))
area_light("Rim | sickly green", (0.3, 2.5, 3.8), 650, 2.5, (0.56, 0.82, 0.44))

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1000
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.view_settings.view_transform = "AgX"
scene.render.filepath = PREVIEW
scene.camera.data.lens = 50

# Make the asset root active when the .blend opens, and show the model in material color.
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active = root
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.shading.type = "MATERIAL"
            area.spaces.active.region_3d.view_distance = 4.2

bpy.context.preferences.filepaths.save_version = 0
# Frame the character when opening the source in Blender.
from mathutils import Quaternion
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.shading.type = 'SOLID'
            area.spaces.active.shading.color_type = 'MATERIAL'
            area.spaces.active.region_3d.view_location = Vector((0,0,.87))
            area.spaces.active.region_3d.view_distance = 3.2
            area.spaces.active.region_3d.view_rotation = cam.rotation_euler.to_quaternion()
bpy.ops.wm.save_as_mainfile(filepath=OUT)
bpy.ops.render.render(write_still=True)
for name,loc in [('front',(0,-8,1.95)),('side',(8,0,1.95)),('back',(3.5,7,2.7)),('isometric',(4,-6,5.7))]:
    cam.location=loc
    aim(cam,(0,0,.87))
    scene.render.filepath=os.path.join(ASSET_DIR,'player_technician_'+name+'.png')
    bpy.ops.render.render(write_still=True)
assert not bpy.data.actions, 'Static model must contain no animations'
meshes=[o for o in root_collection.objects if o.type=='MESH']
print('STATIC PLAYER SAVED:',OUT)
print('MESHES:',len(meshes),'TRIANGLES:',sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons))
