"""Check exported assets without needing a browser or third-party Python packages."""
from pathlib import Path
import json, struct
root=Path(__file__).resolve().parents[1]
reports={}
for name in ['courtyard','traveler','forest-lodge','forest-tree']:
 path=root/'public/assets'/f'{name}.glb';data=path.read_bytes()
 magic,version,length=struct.unpack_from('<III',data)
 assert magic==0x46546C67 and version==2 and length==len(data),f'Invalid GLB: {name}'
 size,kind=struct.unpack_from('<II',data,12);assert kind==0x4E4F534A
 doc=json.loads(data[20:20+size])
 assert doc.get('meshes'),f'No geometry: {name}'
 assert all('POSITION' in p['attributes'] for m in doc['meshes'] for p in m['primitives'])
 names={n.get('name') for n in doc['nodes']}
 if name=='traveler':assert {'LeftLeg','RightLeg','LeftArm','RightArm'}.issubset(names),'Missing limb pivots'
 if name in ['courtyard','forest-lodge','forest-tree']:
  assert len(doc['meshes'])<=16,'Static geometry was not batched'
  assert len(doc.get('textures',[]))>=(6 if name=='courtyard' else 2),'Missing baked materials'
  assert all('bufferView' in i for i in doc.get('images',[])),'Textures must be embedded'
 reports[name]={'bytes':len(data),'meshes':len(doc['meshes']),'textures':len(doc.get('textures',[])),'vertices':sum(doc['accessors'][p['attributes']['POSITION']]['count'] for m in doc['meshes'] for p in m['primitives'])}
meta=json.loads((root/'public/assets/courtyard.json').read_text())
assert meta['colliders'] and len(meta['lamps'])==4
(root/'docs/asset-verification.json').write_text(json.dumps(reports,indent=2)+'\n')
print(json.dumps(reports,indent=2))
