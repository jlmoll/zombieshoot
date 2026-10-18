import bpy, os
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=os.path.abspath('assets/models/source/zombie_blocky_animated.blend'))
scene=bpy.context.scene
root=bpy.data.objects['Zombie_Blocky']
controls=[root,bpy.data.objects['Body_Pivot'],bpy.data.objects['Head_Pivot']]+[bpy.data.objects[k+'_'+s+'_Pivot'] for k in ('Arm','Leg') for s in ('L','R')]
assert len([a for a in bpy.data.actions if 'clip' in a]) == 28
for obj in controls:
    assert len(obj.animation_data.nla_tracks[0].strips)==4
for start,end in ((1,49),(61,109)):
    scene.frame_set(start)
    first=[o.matrix_world.copy() for o in controls]
    scene.frame_set(end)
    assert all(max(abs(m[r][c]-o.matrix_world[r][c]) for r in range(4) for c in range(4)) < .0001 for m,o in zip(first,controls)), 'Loop seam'
for frame in range(1,206):
    scene.frame_set(frame)
    bottom=min((o.matrix_world@Vector(v)).z for o in bpy.data.collections['ZOMBIE | modular blocky'].objects if o.type=='MESH' for v in o.bound_box)
    assert bottom > -.001, (frame,bottom)
print('PASS: 28 actions, 7 controls, 4 NLA clips each, seamless idle/walk, no floor penetration across 205 frames')
