"""Extract reusable cottage/tree assets from the existing editable source."""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'public/assets'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/blender/courtyard.blend'))
world=bpy.data.collections['Courtyard']

def export(name,predicate):
 bpy.ops.object.select_all(action='DESELECT')
 originals=[o for o in world.objects if o.type=='MESH' and predicate(o)]
 copies=[]
 for source in originals:
  o=source.copy();o.data=source.data.copy();bpy.context.scene.collection.objects.link(o);copies.append(o);o.select_set(True);bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
  o.select_set(False)
 groups={}
 for o in copies:groups.setdefault(o.data.materials[0].name,[]).append(o)
 joined=[]
 for objects in groups.values():
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();joined.append(bpy.context.object)
 bpy.ops.object.select_all(action='DESELECT')
 for o in joined:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True)
 for o in joined:bpy.data.objects.remove(o,do_unlink=True)
 return len(groups)

def lodge(o):
 p=o.matrix_world.translation
 return -8.5<p.x<-4.3 and 1.1<p.y<4.5 and p.z>.12 and not o.name.startswith(('Meadow','Path','Moss','Solid','Courtyard'))
def tree(o):
 p=o.matrix_world.translation
 return -8.5<p.x<-5.5 and -7.5<p.y<-4.5 and o.name.startswith(('Tree trunk','Branch','Leaf crown'))
report={'lodgeMeshes':export('forest-lodge',lodge),'treeMeshes':export('forest-tree',tree)}
print('EXPLORATION_ASSETS_COMPLETE',report)
