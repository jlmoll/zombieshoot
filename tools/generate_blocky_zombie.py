import bpy
import math
import os
from mathutils import Vector


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(PROJECT_ROOT, "assets", "models")
SOURCE_DIR = os.path.join(ASSET_DIR, "source")
os.makedirs(SOURCE_DIR, exist_ok=True)
OUT = os.path.join(SOURCE_DIR, "zombie_blocky.blend")
PREVIEW = os.path.join(ASSET_DIR, "zombie_blocky_preview.png")
GLB = os.path.join(ASSET_DIR, "zombie_enemy.glb")


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
root_collection = bpy.data.collections.new("ZOMBIE | modular blocky")
scene.collection.children.link(root_collection)
presentation = bpy.data.collections.new("STUDIO | preview only")
scene.collection.children.link(presentation)

# Edit this palette and proportions to generate other members of the horde.
PALETTE = {
    "skin": (0.43, 0.59, 0.43), "shadow": (0.18, 0.27, 0.18),
    "shirt": (0.035, 0.20, 0.25), "pants": (0.055, 0.075, 0.12),
    "hair": (0.20, 0.075, 0.028), "shoes": (0.16, 0.21, 0.045),
}
HEAD_SCALE = 1.0
BODY_WIDTH = 1.0
ARM_REACH = 1.0
skin = material("Skin | sage", PALETTE["skin"])
shadow = material("Skin | socket shadow", PALETTE["shadow"])
shirt = material("Cloth | petrol shirt", PALETTE["shirt"])
pants = material("Cloth | midnight trousers", PALETTE["pants"])
hair = material("Hair | chestnut", PALETTE["hair"])
shoes = material("Shoes | moss", PALETTE["shoes"])
mouth = material("Mouth | dark cavity", (0.012, 0.019, 0.012))
teeth = material("Teeth | ivory", (0.72, 0.72, 0.48))
eye = material("Eyes | golden amber", (1.0, 0.65, 0.025), emission=(1.0, 0.45, 0.01))
root = bpy.data.objects.new("Zombie_Blocky", None)
root_collection.objects.link(root)
root["Instructions"] = "Separate head, hair, shirt, limbs, eyes and shoes. Recolor named materials; pose named pivots. Front = -Y; feet = Z0."
root["Style"] = "Flat shaded blocks with single-segment chamfers; no textures required."


def pivot(name, loc, parent=root):
    obj = bpy.data.objects.new(name, None)
    root_collection.objects.link(obj)
    obj.location = loc
    obj.empty_display_type = 'PLAIN_AXES'
    obj.empty_display_size = 0.15
    bpy.context.view_layer.update()
    parent_to(obj, parent)
    return obj


def block(name, loc, dims, mat, parent=root, bevel=0.018, rotation=None):
    obj = bevel_cube(name, loc, dims, mat, bevel, 1, rotation)
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    root_collection.objects.link(obj)
    bpy.context.view_layer.update()
    parent_to(obj, parent)
    return obj

head = pivot("Head_Pivot", (0, 0, 1.68))
block("Head | broad square skull", (0,-0.035,1.72), (0.65,0.49,0.68), skin, head, 0.045)
block("Jaw | square lower lip", (0,-0.071,1.425), (0.57,0.47,0.13), skin, head, 0.025)
for side in (-1, 1):
    block("Ear %s" % side,(side*0.343,-0.015,1.60),(0.09,0.15,0.16),skin,head)
    # Eight-sided discs, kept broad and simple like the reference.
    for name, y, radius, mat in (("Socket",-0.291,0.124,shadow),("Eye",-0.315,0.094,eye)):
        obj = cylinder_between(name+str(side),(side*0.18,y-0.014,1.75),(side*0.18,y+0.014,1.75),radius,mat,8)
        for col in list(obj.users_collection): col.objects.unlink(obj)
        root_collection.objects.link(obj)
        bpy.context.view_layer.update()
        parent_to(obj,head)
block("Nose | stub",(0,-0.308,1.61),(0.075,0.068,0.075),shadow,head,0.012)
block("Mouth | open rectangle",(0.015,-0.286,1.493),(0.30,0.035,0.11),mouth,head,0.007, (0,0,0.05))
block("Tooth | single chipped",(-0.063,-0.312,1.525),(0.067,0.025,0.034),teeth,head,0.003)
block("Hair | cap",(0,0,2.065),(0.69,0.54,0.16),hair,head,0.025)
block("Hair | crooked fringe",(0.10,-0.255,2.025),(0.47,0.075,0.145),hair,head,0.012,(0,0,-0.07))
block("Hair | left temple",(-0.293,-0.005,1.88),(0.09,0.47,0.30),hair,head,0.015)
block("Hair | back",(0,0.213,1.91),(0.64,0.085,0.28),hair,head,0.018)
block("Neck",(0,0,1.33),(0.22,0.24,0.17),shadow)
block("Shirt | square torso",(0,0,1.05),(0.57*BODY_WIDTH,0.35,0.55),shirt,bevel=0.022)
block("Collar | exposed neck",(0,-0.188,1.28),(0.18,0.025,0.10),shadow,bevel=0.004)
block("Waist",(0,0.005,0.76),(0.49,0.32,0.13),pants)
for side,label in ((-1,'L'),(1,'R')):
    leg=pivot('Leg_'+label+'_Pivot',(side*0.16,0,0.73))
    block('Leg '+label,(side*0.185,0,0.44),(0.205,0.25,0.57),pants,leg,0.014,(0,side*-0.08,0))
    block('Shoe '+label,(side*0.21,-0.08,0.095),(0.27,0.40,0.19),shoes,leg,0.022)
    if side == -1:
        block('Knee | exposed patch',(side*0.19,-0.131,0.43),(0.15,0.025,0.13),skin,leg,0.007,(0,0,0.12))
        block('Knee | torn cuff',(side*0.20,-0.15,0.49),(0.09,0.027,0.045),pants,leg,0.002,(0,0,-0.22))
    arm=pivot('Arm_'+label+'_Pivot',(side*0.31,0,1.24))
    block('Sleeve '+label,(side*0.35,0,1.245),(0.19,0.37,0.23),shirt,arm,0.018)
    block('Arm '+label,(side*0.56*ARM_REACH,-0.015,1.245),(0.35,0.17,0.16),skin,arm,0.015,(0,side*0.055,0))
    block('Palm '+label,(side*0.82*ARM_REACH,-0.07,1.20),(0.24,0.24,0.20),skin,arm,0.022)
    for finger in (-1,1):
        block('Finger '+label+str(finger),(side*0.82*ARM_REACH+finger*0.078,-0.13,1.08),(0.075,0.15,0.16),skin,arm,0.009)
    block('Thumb '+label,(side*0.685*ARM_REACH,-0.16,1.17),(0.09,0.16,0.12),skin,arm,0.01)
head.scale = (HEAD_SCALE,)*3
bpy.context.view_layer.update()
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
cam.location = (2.7, -7.5, 2.8)
aim(cam, (0, -0.02, 0.98))
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.95
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

# Save a clean, editable model with its preview studio, without changing game assets.
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=OUT)
bpy.ops.render.render(write_still=True)
print("BLOCKY MODEL SAVED:", OUT)
print("PREVIEW:", PREVIEW)
print("TRIANGLES:", sum(len(o.data.polygons) for o in root_collection.objects if o.type == 'MESH'))
