import bpy
import math
import os
from mathutils import Vector


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(PROJECT_ROOT, "assets", "models")
SOURCE_DIR = os.path.join(ASSET_DIR, "source")
os.makedirs(SOURCE_DIR, exist_ok=True)
OUT = os.path.join(SOURCE_DIR, "zombie_enemy.blend")
PREVIEW = os.path.join(ASSET_DIR, "zombie_enemy_preview.png")
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
root_collection = bpy.data.collections.new("ZOMBIE | reusable base")
scene.collection.children.link(root_collection)
presentation = bpy.data.collections.new("STUDIO | preview only")
scene.collection.children.link(presentation)

skin = material("Skin | sickly moss", (0.30, 0.43, 0.30))
skin_dark = material("Skin | bruised shadow", (0.16, 0.25, 0.19))
jacket = material("Cloth | faded charcoal teal", (0.075, 0.14, 0.14))
jacket_light = material("Cloth | torn olive lining", (0.29, 0.30, 0.17))
trousers = material("Cloth | dark trousers", (0.065, 0.09, 0.095))
leather = material("Leather | worn brown", (0.20, 0.12, 0.075))
bone = material("Bone | old ivory", (0.68, 0.60, 0.40))
eye = material("Eyes | amber glow", (1.0, 0.48, 0.08), 0.35, emission=(1.0, 0.22, 0.015))

root = bpy.data.objects.new("Zombie_Base | scale and pose root", None)
root.empty_display_type = "CIRCLE"
root.empty_display_size = 0.32
root.location = (0, 0, 0)
root_collection.objects.link(root)
root["purpose"] = "Reusable low-poly enemy base. Recolor named materials; reshape or scale separate parts."
root["variant_notes"] = "Change root scale for size. Swap Skin/Cloth materials for palette variants. Edit limbs, shoulders, head and attachments for silhouette variants."

parts = []

# Core silhouette: hunched shoulders, narrow waist, oversized head.
parts.append(bevel_cube("Torso | jacket shell", (0, 0, 1.00), (0.72, 0.39, 0.76), jacket, 0.11, 2, (math.radians(-5), 0, 0)))
parts.append(bevel_cube("Pelvis | jacket hem", (0, 0.015, 0.61), (0.57, 0.36, 0.26), jacket, 0.07, 1))
parts.append(ico("Head | angular skull", (0.01, -0.015, 1.72), (0.31, 0.285, 0.34), skin, 2))
parts.append(ico("Jaw | slack", (0.02, -0.18, 1.55), (0.235, 0.16, 0.13), skin_dark, 1))
parts.append(bevel_cube("Mouth | dark opening", (0.025, -0.326, 1.59), (0.20, 0.026, 0.045), skin_dark, 0.012, 1))
parts.append(bevel_cube("Shirt | exposed neckline", (0, -0.212, 1.34), (0.31, 0.045, 0.16), jacket_light, 0.035, 1))

# Face details facing -Y.
for side in (-1, 1):
    parts.append(ico(f"Eye socket {side:+}", (side * 0.125, -0.258, 1.79), (0.083, 0.045, 0.065), skin_dark, 1))
    parts.append(ico(f"Amber eye {side:+}", (side * 0.125, -0.297, 1.79), (0.033, 0.024, 0.03), eye, 2))
parts.append(bevel_cube("Brow | broken left", (-0.13, -0.278, 1.86), (0.18, 0.045, 0.045), skin_dark, 0.02, 1, (0, 0, math.radians(-8))))
parts.append(bevel_cube("Brow | broken right", (0.13, -0.278, 1.86), (0.16, 0.045, 0.04), skin_dark, 0.018, 1, (0, 0, math.radians(8))))
for x in (-0.045, 0.065):
    parts.append(bevel_cube("Tooth | chipped", (x, -0.346, 1.575), (0.035, 0.022, 0.035), bone, 0.008, 1))

# Asymmetric torn jacket and collar.
parts.append(bevel_cube("Collar | left flap", (-0.16, -0.23, 1.31), (0.16, 0.055, 0.22), jacket_light, 0.025, 1, (0, 0, math.radians(-18))))
parts.append(bevel_cube("Collar | right flap", (0.14, -0.23, 1.32), (0.16, 0.055, 0.20), jacket_light, 0.025, 1, (0, 0, math.radians(16))))
parts.append(bevel_cube("Patch | chest", (0.20, -0.206, 1.05), (0.16, 0.025, 0.14), leather, 0.02, 1, (0, 0, math.radians(-8))))
parts.append(bevel_cube("Belt | front", (0, -0.19, 0.72), (0.59, 0.04, 0.075), leather, 0.018, 1))
parts.append(bevel_cube("Buckle | brass", (-0.015, -0.221, 0.72), (0.10, 0.026, 0.075), bone, 0.012, 1))

# Limbs are individual pieces, easy to pose or replace. Front is -Y.
for side, label in ((-1, "L"), (1, "R")):
    hip = (side * 0.19, 0.015, 0.58)
    knee = (side * 0.22, -0.005, 0.30)
    ankle = (side * 0.23, -0.035, 0.105)
    parts.append(cylinder_between(f"Leg {label} | upper", hip, knee, 0.115, trousers, 7, 0.095))
    parts.append(ico(f"Knee {label} | torn", knee, (0.105, 0.11, 0.09), skin_dark, 1))
    parts.append(cylinder_between(f"Leg {label} | lower", knee, ankle, 0.082, trousers, 7, 0.072))
    parts.append(bevel_cube(f"Boot {label}", (side * 0.23, -0.095, 0.075), (0.20, 0.32, 0.14), leather, 0.045, 1))

    shoulder = (side * 0.39, 0.0, 1.26)
    elbow = (side * (0.49 if side < 0 else 0.52), -0.13, 1.00 if side < 0 else 1.04)
    wrist = (side * (0.43 if side < 0 else 0.67), -0.29, 0.77 if side < 0 else 0.83)
    parts.append(ico(f"Shoulder {label} | torn sleeve", shoulder, (0.18, 0.19, 0.20), jacket, 1))
    parts.append(cylinder_between(f"Arm {label} | upper", shoulder, elbow, 0.105, skin, 7, 0.085))
    parts.append(cylinder_between(f"Arm {label} | forearm", elbow, wrist, 0.083, skin, 7, 0.07))
    parts.append(ico(f"Hand {label} | claw palm", wrist, (0.10, 0.085, 0.11), skin_dark, 1))
    # Three long, splayed fingers create a readable reaching silhouette.
    for finger in range(3):
        spread = (finger - 1) * 0.075
        start = (wrist[0] + spread * 0.45, wrist[1] - 0.02, wrist[2] - 0.045)
        end = (wrist[0] + spread, wrist[1] - 0.06, wrist[2] - 0.17 - (0.025 if finger == 1 else 0))
        parts.append(cylinder_between(f"Hand {label} | finger {finger + 1}", start, end, 0.025, skin, 6, 0.012))

# Exposed ribs and small scars on the damaged side.
for index in range(3):
    z = 1.08 - index * 0.105
    parts.append(bevel_cube(f"Rib | left {index + 1}", (-0.255, -0.208, z), (0.13, 0.035, 0.035), bone, 0.014, 1, (0, 0, math.radians(-15))))
parts.append(ico("Shoulder wound", (-0.36, -0.145, 1.23), (0.07, 0.035, 0.10), skin_dark, 1))

arm_pivots = {}
leg_pivots = {}
for side, label in ((-1, "L"), (1, "R")):
    arm_pivot = bpy.data.objects.new(f"Arm_{label}_Pivot", None)
    arm_pivot.empty_display_type = "SPHERE"
    arm_pivot.empty_display_size = 0.09
    arm_pivot.location = (side * 0.39, 0, 1.26)
    root_collection.objects.link(arm_pivot)
    parent_to(arm_pivot, root)
    arm_pivots[label] = arm_pivot
    leg_pivot = bpy.data.objects.new(f"Leg_{label}_Pivot", None)
    leg_pivot.empty_display_type = "SPHERE"
    leg_pivot.empty_display_size = 0.075
    leg_pivot.location = (side * 0.19, 0.015, 0.58)
    root_collection.objects.link(leg_pivot)
    parent_to(leg_pivot, root)
    leg_pivots[label] = leg_pivot

for part in parts:
    parent = root
    for label in ("L", "R"):
        if part.name.startswith((f"Arm {label} |", f"Shoulder {label} |", f"Hand {label} |")):
            parent = arm_pivots[label]
        elif part.name.startswith((f"Leg {label} |", f"Knee {label} |", f"Boot {label}")):
            parent = leg_pivots[label]
    for collection in list(part.users_collection):
        collection.objects.unlink(part)
    root_collection.objects.link(part)
    parent_to(part, parent)

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
cam.location = (3.35, -5.8, 2.85)
aim(cam, (0, -0.02, 0.98))
cam_data.type = "ORTHO"
cam_data.ortho_scale = 3.25
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

bpy.ops.wm.save_as_mainfile(filepath=OUT)
scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
for obj in root_collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
print(f"Saved Blender asset: {OUT}")
print(f"Saved preview: {PREVIEW}")
print(f"Exported Godot-ready GLB: {GLB}")
