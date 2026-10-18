"""Export complete evaluated local transforms; includes constant pivot offsets.

This deliberately avoids NLA glTF exporter dropping constant translations (the
original zombie squash). References are mesh origins AND extremities per clip.
"""
import bpy
import json
import os
import struct
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, 'assets/models/player_technician.glb')
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, 'assets/models/source/player_technician_animated.blend'))
scene = bpy.context.scene
collection = bpy.data.collections['PLAYER | modular technician']
controls = [o for o in collection.objects if o.animation_data]
clips = json.loads(bpy.data.objects['Player_Technician']['Animation clips'])
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))


def transform(obj):
    loc, rot, scale = (C @ obj.matrix_local @ C.inverted()).decompose()
    return list(loc), [rot.x, rot.y, rot.z, rot.w], list(scale)


scene.frame_set(1)
base = {o.name: transform(o) for o in controls}
samples, reference = {}, {}
for name, start, end in clips:
    samples[name] = {o.name: [[], [], []] for o in controls}
    reference[name] = []
    # Quarter-cycle checkpoints catch rotation errors that endpoints cannot.
    check_frames = {start, start+(end-start)//4, (start+end)//2, end-(end-start)//4, end}
    for frame in range(start, end + 1):
        scene.frame_set(frame)
        for obj in controls:
            for values, value in zip(samples[name][obj.name], transform(obj)):
                values.append(value)
        if frame in check_frames:
            meshes = [o for o in collection.objects if o.type == 'MESH']
            positions = {o.name: list(C.to_3x3() @ o.matrix_world.translation) for o in meshes}
            positions['Muzzle'] = list(C.to_3x3() @ bpy.data.objects['Muzzle'].matrix_world.translation)
            reference[name].append({'time': (frame-start)/24, 'positions': positions,
                                    'bounds': {o.name: [list(C.to_3x3() @ (o.matrix_world @ Vector(c))) for c in o.bound_box] for o in meshes}})
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=PATH, export_format='GLB', use_selection=True,
                          export_animations=False, export_yup=True)
raw = open(PATH, 'rb').read()
size = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+size])
offset = 20+size
binary = bytearray(raw[offset+8:offset+8+struct.unpack_from('<I', raw, offset)[0]])
nodes = {o['name']: i for i, o in enumerate(doc['nodes'])}
for name, (loc, rot, scale) in base.items():
    node = doc['nodes'][nodes[name]]
    node.pop('matrix', None)
    node.update(translation=loc, rotation=rot, scale=scale)


def accessor(values, kind):
    while len(binary) % 4:
        binary.append(0)
    start = len(binary)
    flat = [v for row in values for v in row] if kind != 'SCALAR' else values
    binary.extend(struct.pack('<'+'f'*len(flat), *flat))
    view = len(doc.setdefault('bufferViews', []))
    doc['bufferViews'].append({'buffer': 0, 'byteOffset': start, 'byteLength': len(binary)-start})
    a = {'bufferView': view, 'componentType': 5126, 'count': len(values), 'type': kind}
    if kind == 'SCALAR':
        a.update(min=[min(values)], max=[max(values)])
    index = len(doc['accessors'])
    doc['accessors'].append(a)
    return index


doc['animations'] = []
for name, start, end in clips:
    times = accessor([(f-start)/24 for f in range(start, end+1)], 'SCALAR')
    animation = {'name': name, 'samplers': [], 'channels': [], 'extras': {'loop': name in ('Idle', 'Walk', 'Aim')}}
    for obj in controls:
        for path, kind, values in zip(('translation', 'rotation', 'scale'), ('VEC3', 'VEC4', 'VEC3'), samples[name][obj.name]):
            if path == 'rotation':
                for i in range(1, len(values)):
                    if sum(a*b for a, b in zip(values[i-1], values[i])) < 0:
                        values[i] = [-v for v in values[i]]
            output = accessor(values, kind)
            index = len(animation['samplers'])
            animation['samplers'].append({'input': times, 'output': output, 'interpolation': 'LINEAR'})
            animation['channels'].append({'sampler': index, 'target': {'node': nodes[obj.name], 'path': path}})
    doc['animations'].append(animation)
doc['buffers'][0]['byteLength'] = len(binary)
j = json.dumps(doc, separators=(',', ':')).encode()
j += b' ' * ((-len(j)) % 4)
binary += b'\0' * ((-len(binary)) % 4)
with open(PATH, 'wb') as out:
    out.write(struct.pack('<III', 0x46546c67, 2, 12+8+len(j)+8+len(binary)))
    out.write(struct.pack('<II', len(j), 0x4e4f534a))
    out.write(j)
    out.write(struct.pack('<II', len(binary), 0x004e4942))
    out.write(binary)
with open(os.path.join(ROOT, 'tests/fixtures/player_blender_reference.json'), 'w') as out:
    json.dump(reference, out)
print('PLAYER_EXPORTED', PATH, 'clips', [clip[0] for clip in clips], 'channels', len(controls)*3)
