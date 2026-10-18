"""Build editable rigid-part character clips from the reviewed static source.

Run: blender --background --python tools/animate_player_technician.py
Runtime owns the yaw on UpperBody_Pivot / LowerBody_Pivot and WeaponSocket.
"""
import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets/models')
CLIPS = [('Idle', 1, 49), ('Walk', 61, 85), ('Aim', 97, 145),
         ('Dash', 157, 165), ('Death', 177, 193), ('Reload', 205, 229)]
FPS = 24


def parent_keep(obj, parent):
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_world = world
    bpy.context.view_layer.update()


def build():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(ASSETS, 'source/player_technician.blend'))
    scene = bpy.context.scene
    collection = bpy.data.collections['PLAYER | modular technician']
    root = bpy.data.objects['Player_Technician']

    def pivot(name, position, parent):
        obj = bpy.data.objects.new(name, None)
        collection.objects.link(obj)
        obj.location = position
        obj.empty_display_type = 'PLAIN_AXES'
        obj.empty_display_size = .06
        parent_keep(obj, parent)
        return obj

    motion = pivot('Body_Motion', (0, 0, .72), root)
    upper = pivot('UpperBody_Pivot', (0, 0, .77), motion)
    lower = pivot('LowerBody_Pivot', (0, 0, .72), motion)
    for obj in list(root.children):
        if obj == motion:
            continue
        parent_keep(obj, lower if obj.name.startswith(('Leg_', 'Hips')) else upper)
    torso = bpy.data.objects['Torso_Pivot']
    # Belt and hip pouches turn with the trousers, keeping the waist seam closed.
    for obj in list(upper.children):
        if obj != torso:
            parent_keep(obj, lower)
    arms = [bpy.data.objects['Arm_' + side + '_Pivot'] for side in ('L', 'R')]
    legs = [bpy.data.objects['Leg_' + side + '_Pivot'] for side in ('L', 'R')]
    knees = []
    for side, leg in zip(('L', 'R'), legs):
        knee = pivot('Knee_' + side + '_Pivot', (-.13 if side == 'L' else .13, 0, .445), leg)
        for name in ('Shin ', 'Boot ', 'Sole ', 'Knee pad '):
            parent_keep(bpy.data.objects[name + side], knee)
        knees.append(knee)

    # Pose the existing sleeves as connected rigid segments, retaining the palette
    # and authored bevels. Hands meet the two grip positions of the compact weapon.
    wrists = {'L': Vector((.02, -.245, 1.045)), 'R': Vector((.155, -.20, .99))}
    elbows = {'L': Vector((-.27, -.145, .995)), 'R': Vector((.30, -.10, .985))}

    def oriented_mesh(obj, center, orientation, dimensions):
        extent = [max(v.co[i] for v in obj.data.vertices)-min(v.co[i] for v in obj.data.vertices) for i in range(3)]
        obj.matrix_world = Matrix.Translation(center) @ orientation.to_4x4() @ Matrix.Diagonal(tuple(dimensions[i]/extent[i] for i in range(3))+(1,))

    def segment(obj, a, b, width, depth, overlap):
        axis_z = (b-a).normalized()
        axis_x = (Vector((1, 0, 0))-axis_z*axis_z.x).normalized()
        axis_y = axis_z.cross(axis_x).normalized()
        orientation = Matrix((axis_x, axis_y, axis_z)).transposed()
        oriented_mesh(obj, (a+b)/2, orientation, (width, depth, (b-a).length*overlap))
        return orientation

    for side, arm in zip(('L', 'R'), arms):
        shoulder = arm.matrix_world.translation.copy()
        elbow, wrist = elbows[side], wrists[side]
        segment(bpy.data.objects['Upper sleeve ' + side], shoulder, elbow, .16, .22, 1.045)
        frame = segment(bpy.data.objects['Forearm sleeve ' + side], elbow, wrist, .135, .18, 1.08)
        # Reflective patch sits on the upper surface of the forearm; no floating cuff.
        patch = bpy.data.objects['Sleeve reflector ' + side]
        center = (elbow+wrist)/2 + frame @ Vector((0, .0905, (wrist-elbow).length*.28))
        oriented_mesh(patch, center, frame, (.112, .008, .028))
        glove = bpy.data.objects['Glove ' + side]
        glove.matrix_world = Matrix.Translation(wrist + Vector((0, -.026, 0))) @ Matrix.Rotation(-math.pi/2, 4, 'X')
        thumb = bpy.data.objects['Thumb ' + side]
        thumb.matrix_world = Matrix.Translation(wrist + Vector((-.055 if side == 'R' else .052, -.035, .018)))

    socket = pivot('WeaponSocket', (.09, -.15, 1.075), torso)
    weapon = pivot('Weapon_Pivot', (.09, -.15, 1.075), socket)
    geometry = pivot('ImportedWeapon_Mesh', (.09, -.15, 1.075), weapon)
    muzzle = pivot('Muzzle', (.09, -.59, 1.075), weapon)
    mat = bpy.data.materials.get('Equipment | graphite')
    orange = bpy.data.materials.get('Vest | editable')
    black = bpy.data.materials.get('Boots | editable')

    def block(name, position, dims, material):
        bpy.ops.mesh.primitive_cube_add(size=1, location=position)
        obj = bpy.context.object
        obj.name = name
        obj.dimensions = dims
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.data.materials.append(material)
        bevel = obj.modifiers.new('Single segment bevel', 'BEVEL')
        bevel.width = .006
        bevel.segments = 1
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        for col in list(obj.users_collection):
            col.objects.unlink(obj)
        collection.objects.link(obj)
        parent_keep(obj, geometry)
        return obj

    block('Weapon | receiver', (.09, -.30, 1.075), (.10, .28, .115), mat)
    block('Weapon | barrel', (.09, -.505, 1.075), (.065, .17, .065), black)
    block('Weapon | grip', (.12, -.205, .99), (.065, .07, .115), black)
    block('Weapon | magazine', (.09, -.31, .985), (.065, .085, .12), black)
    block('Weapon | stock', (.09, -.115, 1.065), (.085, .115, .085), black)
    block('Weapon | safety stripe', (.145, -.30, 1.09), (.007, .08, .022), orange)
    block('Weapon | rear sight', (.09, -.24, 1.143), (.035, .03, .028), black)
    block('Weapon | front sight', (.09, -.53, 1.12), (.025, .025, .035), orange)
    for side, knee in zip(('L', 'R'), knees):
        joint = block('Knee joint ' + side, (-.13 if side == 'L' else .13, 0, .445),
                      (.145, .19, .10), bpy.data.materials['Suit | editable'])
        parent_keep(joint, knee)
    bpy.context.view_layer.update()
    controls = [motion, torso, bpy.data.objects['Head_Pivot'], bpy.data.objects['Ponytail_Pivot']] + legs + knees + arms
    rest = {o: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in controls}
    head = bpy.data.objects['Head_Pivot']
    pony = bpy.data.objects['Ponytail_Pivot']
    meshes = [o for o in collection.objects if o.type == 'MESH']

    def pose(t, clip):
        for obj in controls:
            obj.location, obj.rotation_euler, obj.scale = rest[obj]
        phase = t * math.tau
        breathe = math.sin(phase)
        torso.rotation_euler.x = -.025
        head.rotation_euler.x = .025
        if clip in ('Idle', 'Aim'):
            torso.location.z += .0035 * breathe
            torso.rotation_euler.y = .006 * breathe
            pony.rotation_euler.x = .018 * math.sin(phase - .4)
        elif clip == 'Walk':
            stride = math.sin(phase)
            torso.rotation_euler.x = .035
            torso.rotation_euler.y = .018 * stride
            head.rotation_euler.y = -.014 * stride
            motion.location.z += .014 * (1 - math.cos(phase * 2))
            pony.rotation_euler.x = .09 * math.sin(phase * 2 - .5)
            pony.rotation_euler.y = .055 * stride
            for i, (leg, knee) in enumerate(zip(legs, knees)):
                p = phase + math.pi * i
                leg.rotation_euler.x = .42 * math.sin(p)
                knee.rotation_euler.x = -.34 * max(0, -math.sin(p))
                leg.location.z += .07 * max(0, -math.cos(p))
        elif clip == 'Dash':
            envelope = math.sin(math.pi * t)
            torso.rotation_euler.x = .18 + envelope * .15
            head.rotation_euler.x = -.15 - envelope * .1
            motion.location.z -= .10 * envelope
            legs[0].rotation_euler.x = -.48 * envelope
            legs[1].rotation_euler.x = .36 * envelope
            knees[0].rotation_euler.x = -.35 * envelope
            pony.rotation_euler.x = -.20 * envelope
        elif clip == 'Death':
            collapse = min(1, max(0, (t - .06) / .84))
            collapse = collapse * collapse * (3 - 2 * collapse)
            motion.rotation_euler.x = -math.pi / 2 * collapse
            motion.location.y += .20 * collapse
            motion.location.z -= .43 * collapse
            torso.rotation_euler.z = .06 * math.sin(t * math.pi)
            head.rotation_euler.x = -.16 * math.sin(t * math.pi)
            # The backpack supports the torso; let the legs settle down to the
            # floor instead of leaving both boots rigidly suspended in the air.
            legs[0].rotation_euler.x = .44 * collapse
            legs[1].rotation_euler.x = .36 * collapse
            knees[0].rotation_euler.x = -.10 * collapse
            knees[1].rotation_euler.x = -.06 * collapse
            # Fold the ponytail alongside the neck; its rigid blocks must not
            # prop the whole character above the floor after the fall.
            pony.rotation_euler.x = -1.0 * collapse
        elif clip == 'Reload':
            envelope = math.sin(math.pi * t) ** 2
            arms[0].rotation_euler.x += .25 * envelope
            arms[0].rotation_euler.z += .08 * envelope
            head.rotation_euler.x = .12 * envelope
            torso.rotation_euler.z = -.025 * envelope
        bpy.context.view_layer.update()
        bottom = min((o.matrix_world @ Vector(c)).z for o in meshes for c in o.bound_box)
        # Preserve planted contact through the stride and keep the final body on ground.
        motion.location.z += .002 - bottom
        bpy.context.view_layer.update()

    scene.render.fps = FPS
    for marker in list(scene.timeline_markers):
        scene.timeline_markers.remove(marker)
    for clip, start, end in CLIPS:
        scene.timeline_markers.new(clip, frame=start)
        for obj in controls:
            obj.animation_data_clear()
        for frame in range(start, end + 1):
            pose((frame-start)/(end-start), clip)
            for obj in controls:
                obj.keyframe_insert(data_path='location', frame=frame)
                obj.keyframe_insert(data_path='rotation_euler', frame=frame)
        for obj in controls:
            action = obj.animation_data.action
            action.name = clip + '__' + obj.name
            action.use_fake_user = True
            action['clip'] = clip
            action['loop'] = clip in ('Idle', 'Walk', 'Aim')
            obj.animation_data.action = None
    for obj in controls:
        obj.animation_data_clear()
        obj.animation_data_create()
        track = obj.animation_data.nla_tracks.new()
        track.name = 'Technician clips'
        for clip, start, end in CLIPS:
            strip = track.strips.new(clip, start, bpy.data.actions[clip + '__' + obj.name])
            strip.extrapolation = 'HOLD_FORWARD'
            strip.blend_type = 'REPLACE'
        obj.location, obj.rotation_euler, obj.scale = rest[obj]
    root['Animation instructions'] = '24fps. Markers/NLA: Idle, Walk, Aim, Dash, Death, Reload. UpperBody_Pivot/LowerBody_Pivot runtime yaw. WeaponSocket recoil. Rigid mesh animation; editable parts and materials.'
    root['Animation clips'] = json.dumps(CLIPS)
    root['Height_m'] = 1.74
    socket['Coordinates'] = 'Local origin is receiver stock. Forward Blender -Y / Godot +Z. Muzzle local (0,0,.44) in Godot. All units before runtime .9 scale.'
    scene.frame_start, scene.frame_end = 1, 229
    scene.use_preview_range = True
    scene.frame_preview_start, scene.frame_preview_end = 61, 84
    scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version = 0
    out = os.path.join(ASSETS, 'source/player_technician_animated.blend')
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print('ANIMATED_PLAYER', out)
    print('SOCKET_LOCAL_GLTF', list(socket.location))
    print('MUZZLE_LOCAL_BLENDER', list(muzzle.location))
    # Representative frames from every clip, front-three-quarter and isometric.
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.eevee.taa_render_samples = 24
    camera = scene.camera
    for clip, start, end in CLIPS:
        scene.frame_set((start + end)//2 if clip != 'Death' else end)
        camera.location = (3.5, -7.5, 2.7)
        target = Vector((0, 0, .87)) if clip != 'Death' else Vector((0, .3, .50))
        camera.rotation_euler = (target-camera.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = os.path.join(ASSETS, 'player_animation_' + clip + '.png')
        bpy.ops.render.render(write_still=True)
    for label, frame, position in [('walk_front_67', 67, (0, -8, 1.7)),
                                    ('walk_side_67', 67, (8, 0, 1.8)),
                                    ('walk_side_79', 79, (8, 0, 1.8)),
                                    ('death_side', 193, (8, 0, 1.3))]:
        scene.frame_set(frame)
        camera.location = position
        target = Vector((0, 0, .87)) if frame != 193 else Vector((0, .25, .4))
        camera.rotation_euler = (target-camera.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = os.path.join(ASSETS, 'player_animation_' + label + '.png')
        bpy.ops.render.render(write_still=True)


def render_walk_preview():
    """Render a real loop without modifying the reviewed animation source."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(ASSETS, 'source/player_technician_animated.blend'))
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = 384
    scene.render.resolution_percentage = 100
    scene.eevee.taa_render_samples = 16
    camera = scene.camera
    camera.location = (3.5, -7.5, 2.7)
    camera.rotation_euler = (Vector((0, 0, .87))-camera.location).to_track_quat('-Z', 'Y').to_euler()
    # Blender 5 interprets braces in sandbox TEMP paths as filename templates.
    directory = os.path.join(ROOT, '.godot/player_animation_preview')
    os.makedirs(directory, exist_ok=True)
    for i, frame in enumerate(range(61, 85, 2)):
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(directory, 'walk_%02d.png' % i)
        bpy.ops.render.render(write_still=True)
    print('WALK_PREVIEW_FRAMES', directory)


if __name__ == '__main__':
    if '--preview-only' in sys.argv:
        render_walk_preview()
    else:
        build()
