"""Validate binary layout, indexed geometry, PBR materials and rigid pivot names."""
import json
import math
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'public/assets/dragonfly.glb'
b=p.read_bytes()
magic,version,length=struct.unpack_from('<4sII',b)
assert magic==b'glTF' and version==2 and length==len(b)
chunks=[]; pos=12
while pos<len(b):
    size,kind=struct.unpack_from('<II',b,pos); pos+=8
    assert pos+size<=len(b) and size%4==0
    chunks.append((kind,b[pos:pos+size])); pos+=size
assert chunks[0][0]==0x4e4f534a and chunks[1][0]==0x004e4942
j=json.loads(chunks[0][1]); binary=chunks[1][1]
assert len(binary)>=j['buffers'][0]['byteLength']
for view in j['bufferViews']:
    assert view.get('byteOffset',0)+view['byteLength']<=len(binary)
for accessor in j['accessors']:
    assert accessor['count']>0
    for key in ['min','max']:
        assert all(math.isfinite(v) for v in accessor.get(key,[]))
names={n.get('name'):n for n in j['nodes']}
required=['Dragonfly','Thorax','Head','Gear_A','Gear_B','Gear_C']
required += ['Wing_'+s+'_'+r for s in ['L','R'] for r in ['Fore','Hind']]
required += ['DriveRod_'+s+'_'+r for s in ['L','R'] for r in ['Fore','Hind']]
required += ['Abdomen_%02d'%i for i in range(10)]
required += ['Leg_'+s+'_'+str(i) for s in ['L','R'] for i in range(3)]
assert all(n in names for n in required),set(required)-set(names)
assert all('mesh' not in names[n] for n in required), 'Rigid pivots must remain independent of merged meshes'
assert len(j['materials'])==9
assert any(m.get('alphaMode')=='BLEND' for m in j['materials']), 'Transparent wing membrane missing'
def values(index):
    a=j['accessors'][index];v=j['bufferViews'][a['bufferView']]
    formats={5121:'B',5123:'H',5125:'I',5126:'f'}
    widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
    fmt='<'+formats[a['componentType']]*widths[a['type']]
    size=struct.calcsize(fmt);stride=v.get('byteStride',size)
    start=v.get('byteOffset',0)+a.get('byteOffset',0)
    assert start+(a['count']-1)*stride+size<=v.get('byteOffset',0)+v['byteLength']
    for i in range(a['count']):yield struct.unpack_from(fmt,binary,start+i*stride)

triangles=0
for mesh in j['meshes']:
    for prim in mesh['primitives']:
        assert 'POSITION' in prim['attributes'] and 'NORMAL' in prim['attributes']
        assert prim.get('mode',4)==4
        positions=prim['attributes']['POSITION'];normals=prim['attributes']['NORMAL']
        count=j['accessors'][positions]['count']
        assert count==j['accessors'][normals]['count']
        assert all(all(math.isfinite(v) for v in xyz) for xyz in values(positions))
        assert all(all(math.isfinite(v) for v in xyz) for xyz in values(normals))
        assert all(index[0]<count for index in values(prim['indices']))
        assert j['accessors'][prim['indices']]['count']%3==0
        triangles+=j['accessors'][prim['indices']]['count']//3
assert 30000<triangles<500000
assert len(b)<20_000_000
assert (ROOT/'assets/blender/dragonfly.blend').is_file()
metadata=json.loads((ROOT/'public/assets/dragonfly.json').read_text())
assert metadata['triangles']==triangles and metadata['bytes']==len(b)
report={'revision':metadata['revision'],'sourceParts':metadata['sourceParts'],'features':metadata['features'],'status':'passed','glbBytes':len(b),'meshes':len(j['meshes']),'triangles':triangles,'materials':len(j['materials']),'verifiedPivots':len(required),'textures':len(j.get('textures',[])),'notes':'Geometry and PBR constants, no baked textures. Rigid assemblies, no bone skinning or physical drivetrain simulation.'}
(ROOT/'docs/asset-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
