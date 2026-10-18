"""Blender --background --python tools/animate_blocky_zombie.py"""
import bpy, math, os
from mathutils import Vector
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets', 'models')
bpy.ops.wm.open_mainfile(filepath=os.path.join(ASSETS, 'source', 'zombie_blocky.blend'))
scene = bpy.context.scene
root = bpy.data.objects['Zombie_Blocky']
collection = bpy.data.collections['ZOMBIE | modular blocky']
body = bpy.data.objects.new('Body_Pivot', None)
collection.objects.link(body)
body.location = (0, 0, 0.78)
bpy.context.view_layer.update()
world = body.matrix_world.copy()
body.parent = root
body.matrix_world = world
for obj in list(root.children):
    if obj == body or obj.name.startswith('Leg_'): continue
    world = obj.matrix_world.copy()
    obj.parent = body
    obj.matrix_world = world
head = bpy.data.objects['Head_Pivot']
legs = [bpy.data.objects['Leg_'+side+'_Pivot'] for side in ('L','R')]
arms = [bpy.data.objects['Arm_'+side+'_Pivot'] for side in ('L','R')]
controls = [root, body, head] + legs + arms
rest = {obj: (obj.location.copy(), obj.rotation_euler.copy(), obj.scale.copy()) for obj in controls}
scene.render.fps = 24
clips = [('Idle',1,49), ('Walk',61,109), ('Attack',121,151), ('Death',163,205)]
for marker in list(scene.timeline_markers): scene.timeline_markers.remove(marker)

def pose(t, clip):
    for obj in controls:
        obj.location, obj.rotation_euler, obj.scale = rest[obj]
    # Reaching stance; local X points outwards on either side.
    for i, arm in enumerate(arms):
        side = -1 if i == 0 else 1
        arm.rotation_euler.z = -side * 0.96
        arm.rotation_euler.y = side * 0.12
    head.rotation_euler.y = -0.065
    if clip == 'Idle':
        wave = math.sin(t * math.tau)
        body.rotation_euler.x = 0.045 + wave * 0.018
        body.rotation_euler.y = wave * 0.025
        head.rotation_euler.z = wave * 0.035
        for i, arm in enumerate(arms): arm.rotation_euler.y += wave * 0.04 * (-1 if i else 1)
    elif clip == 'Walk':
        phase = t * math.tau * 2
        stride = math.sin(phase)
        body.rotation_euler.x = 0.09
        body.rotation_euler.y = stride * 0.035
        body.rotation_euler.z = stride * 0.04
        root.location.z += 0.016 * (1-math.cos(phase*2))
        head.rotation_euler.z = -stride * 0.045
        for i, leg in enumerate(legs):
            p = phase + i * math.pi
            leg.rotation_euler.x = math.cos(p) * 0.29
            leg.location.z += max(0, math.sin(p)) * 0.10
        for i, arm in enumerate(arms): arm.rotation_euler.z += stride * 0.07 * (-1 if i else 1)
    elif clip == 'Attack':
        # Anticipation, fast two-handed lunge, then deliberate recovery.
        def curve(points):
            for (a,x),(b,y) in zip(points,points[1:]):
                if t <= b:
                    f = max(0,min(1,(t-a)/(b-a)))
                    f = f*f*(3-2*f)
                    return x+(y-x)*f
            return points[-1][1]
        reach = curve([(0,0),(.30,-.24),(.47,.48),(.60,.40),(1,0)])
        body.rotation_euler.x = 0.04 + reach
        body.location.y -= max(0,reach)*0.15
        head.rotation_euler.x = -reach*.4
        for i,arm in enumerate(arms):
            side = -1 if i == 0 else 1
            arm.rotation_euler.y += side * reach * .9
            arm.rotation_euler.z -= side * reach * .22
    else:
        # A backward fall with a brief recoil and a final ground settle.
        f = max(0,min(1,(t-.12)/.68))
        f = f*f*(3-2*f)
        root.rotation_euler.x = -math.pi/2 * f
        root.location.y += .25 * f
        body.rotation_euler.z = math.sin(t*math.pi)*.08
        head.rotation_euler.x = -.12*math.sin(t*math.pi)
        for i,arm in enumerate(arms):
            side = -1 if i == 0 else 1
            arm.rotation_euler.z *= 1-f*.55
            arm.rotation_euler.y += side*f*.22
    # Lift the entire character only as needed to keep geometry above the floor.
    bpy.context.view_layer.update()
    bottom = min((obj.matrix_world @ Vector(corner)).z for obj in collection.objects if obj.type == 'MESH' for corner in obj.bound_box)
    if bottom < .002: root.location.z += .002-bottom

for clip,start,end in clips:
    scene.timeline_markers.new(clip, frame=start)
    for obj in controls:
        obj.animation_data_clear()
        obj.animation_data_create()
    for frame in range(start,end+1):
        t = (frame-start)/(end-start)
        pose(t,clip)
        for obj in controls:
            obj.keyframe_insert(data_path='location',frame=frame,group='Translation')
            obj.keyframe_insert(data_path='rotation_euler',frame=frame,group='Rotation')
    for obj in controls:
        action = obj.animation_data.action
        action.name = clip+'__'+obj.name
        action.use_fake_user = True
        # Keep earlier clips as muted-independent NLA tracks on the same controls.
        # animation_data_clear above removes tracks, so restore all clips after baking.
        action['clip'] = clip
        action['control'] = obj.name
        action['loop'] = clip in ('Idle','Walk')
        obj.animation_data.action = None

for obj in controls:
    obj.animation_data_clear()
    obj.animation_data_create()
    track = obj.animation_data.nla_tracks.new()
    track.name = 'Zombie Clips'
    for clip,start,end in clips:
        action = bpy.data.actions[clip+'__'+obj.name]
        strip = track.strips.new(clip,start,action)
        strip.extrapolation = 'HOLD_FORWARD'
        strip.blend_type = 'REPLACE'
    obj.location, obj.rotation_euler, obj.scale = rest[obj]
root['Animation instructions'] = '24 fps. Timeline markers: Idle 1-49 (loop), Walk 61-109 (two in-place cycles), Attack 121-151, Death 163-205. Separate named Actions per control; assembled in NLA. Pose via Body/Head/Arm/Leg pivots.'
scene.frame_start = 1
scene.frame_end = 205
scene.frame_set(73)
# Open the file with walking selected as the playback range.
scene.use_preview_range = True
scene.frame_preview_start = 61
scene.frame_preview_end = 108
bpy.context.preferences.filepaths.save_version = 0
out = os.path.join(ASSETS,'source','zombie_blocky_animated.blend')
bpy.ops.wm.save_as_mainfile(filepath=out)
# Render a compact contact sheet source and animation frames for review.
scene.render.resolution_x = 448
scene.render.resolution_y = 448
scene.render.resolution_percentage = 100
scene.eevee.taa_render_samples = 16
frames_dir = os.path.join(ASSETS,'animation_preview')
os.makedirs(frames_dir,exist_ok=True)
for clip,start,end in clips:
    for frame in range(start,end,3):
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(frames_dir,f'{clip}_{frame:03d}.png')
        bpy.ops.render.render(write_still=True)
print('ANIMATED BLEND:',out)
print('Validated clips:',[(name,end-start+1) for name,start,end in clips])

