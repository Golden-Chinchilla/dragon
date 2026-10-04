"""Rebuild editable Blender assets, bake portable materials and export GLB."""
from pathlib import Path
import bpy, math, random, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'public/assets'; OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'assets/blender'; SOURCE.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(28)
worldcol=bpy.data.collections.new('Courtyard'); bpy.context.scene.collection.children.link(worldcol)
herocol=bpy.data.collections.new('Traveler'); bpy.context.scene.collection.children.link(herocol)
activecol=worldcol
materials={}
def textured(name,a,b,kind='noise',scale=5):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');p.inputs['Roughness'].default_value=.88
 coord=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(2,14,2) if kind=='wood' else (scale,scale,scale);l.new(coord.outputs['UV'],mapping.inputs[0])
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=4;noise.inputs['Detail'].default_value=3;noise.inputs['Roughness'].default_value=.72;l.new(mapping.outputs[0],noise.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[0].color=(*a,1);ramp.color_ramp.elements[1].position=.82;ramp.color_ramp.elements[1].color=(*b,1);l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
 materials[name]=m;return m
wood=textured('Weathered oak',(.105,.13,.115),(.31,.28,.19),'wood')
plaster=textured('Sage limewash',(.28,.36,.31),(.50,.54,.41),scale=8)
stone=textured('Hand cut sandstone',(.23,.28,.26),(.48,.50,.41),scale=5)
roofmat=textured('Blue slate tiles',(.065,.17,.19),(.18,.31,.29),scale=5)
grass=textured('Mossy soil',(.12,.23,.18),(.27,.36,.22),scale=7)
leaves=textured('Soft foliage',(.075,.19,.14),(.25,.37,.21),scale=6)
cloth=textured('Traveler linen',(.32,.36,.27),(.58,.54,.35),scale=5)
def plain(name,color,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.85
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
light=plain('Amber window glass',(1,.61,.19),1.1);metal=plain('Blackened iron',(.055,.085,.085));water=plain('Deep water',(.075,.19,.19));skin=plain('Warm skin',(.64,.45,.27));rust=plain('Rust scarf',(.42,.15,.075));base=plain('Earth cut edge',(.09,.16,.14))
def move(o,name,m):
 o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 activecol.objects.link(o)
 if m:o.data.materials.append(m)
 return o
def cube(name,loc,size,m,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:mod=o.modifiers.new('Soft worked edges','BEVEL');mod.width=bevel;mod.segments=2;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return move(o,name,m)
def sphere(name,loc,size,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,location=loc);o=bpy.context.object;o.scale=size;move(o,name,m)
 for p in o.data.polygons:p.use_smooth=True
 return o
def cylinder(name,loc,r,depth,m,vertices=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc);return move(bpy.context.object,name,m)
def beam(name,a,b,r,m):
 a,b=Vector(a),Vector(b);o=cylinder(name,(a+b)/2,r,(b-a).length,m,8);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def mesh(name,verts,faces,m):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update();o=bpy.data.objects.new(name,data);activecol.objects.link(o);data.materials.append(m)
 # portable UVs for generated material atlas
 uv=data.uv_layers.new(name='UVMap')
 for p in data.polygons:
  for li in p.loop_indices:
   v=data.vertices[data.loops[li].vertex_index].co;uv.data[li].uv=(v.x*.23+v.y*.13,v.z*.24+v.y*.18)
 return o
# Bake each authored procedural base color into a reusable atlas. No lighting baked in.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=4
for name,m in materials.items():
 bpy.ops.mesh.primitive_plane_add(size=2,location=(0,0,0));bake=move(bpy.context.object,'Material baking swatch',m)
 img=bpy.data.images.new(name+' albedo',width=512,height=512)
 tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;m.node_tree.nodes.active=tex
 bpy.ops.object.select_all(action='DESELECT');bake.select_set(True);bpy.context.view_layer.objects.active=bake
 scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
 bpy.ops.object.bake(type='DIFFUSE',margin=8)
 p=m.node_tree.nodes.get('Principled BSDF');m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 img.pack();bpy.data.objects.remove(bake,do_unlink=True)
# Cottage garden, a small authored scene instead of a grid of identical primitive houses.
cube('Solid earth island',(0,0,-.55),(19,17,1),base,.28)
cube('Moss top',(0,0,-.035),(18.85,16.85,.16),grass,.2)
# Uneven slate garden path, with mortar gaps and subtle color/height variations.
for row in range(15):
 for col in range(4):
  x=(col-1.5)*.62+.06*math.sin(row);y=-7.2+row*.72
  cube('Path stone',(x,y,.075+random.uniform(-.01,.01)),(.57+random.uniform(-.035,.035),.66,.11),stone,.045)
for row in range(4):
 for col in range(20):
  x=-6.3+col*.63;y=-2.6+row*.62
  if abs(x)<1.3:continue
  cube('Courtyard paving',(x,y,.075),(.58,.57,.1),stone,.04)
def cottage(x,y,w,d,h,label):
 # main structure and individually modeled stone foundation
 cube(label+' limewash walls',(x,y,h/2+.26),(w,d,h),plaster,.055)
 for side in [-1,1]:
  for i in range(int(w/.5)):
   cube('Foundation blocks',(x-w/2+.26+i*.5,y+side*d/2,.2),(.47,.31,.38),stone,.035)
 for dx in [-w/2,w/2]:
  cube('Oak corner post',(x+dx,y-d/2-.06,h/2+.3),(.16,.17,h+.1),wood,.02)
 cube('Front timber sill',(x,y-d/2-.07,.49),(w+.15,.15,.16),wood,.02)
 cube('Front timber lintel',(x,y-d/2-.07,h+.24),(w+.2,.18,.19),wood,.02)
 # pitched roof: real gable and rows of softly beveled, individually editable slate tiles
 rise=w*.45;eave=h+.34
 mesh('Front plaster gable',[(x-w/2,y-d/2,eave),(x+w/2,y-d/2,eave),(x,y-d/2,eave+rise)],[(0,1,2)],plaster)
 mesh('Rear plaster gable',[(x-w/2,y+d/2,eave),(x+w/2,y+d/2,eave),(x,y+d/2,eave+rise)],[(2,1,0)],plaster)
 theta=math.atan2(rise,w/2);slope=math.hypot(w/2,rise)+.42
 for side in [-1,1]:
  o=cube('Slate roof backing',(x+side*w/4,y,eave+rise/2),(slope,.12,d+.65),roofmat)
  o.rotation_euler=(math.pi/2,side*theta,0)
  # tile long axis lies down slope; cover the two sides all the way to overhanging eaves
  for row in range(9):
   t=(row+.45)/9
   for col in range(max(8,int((d+.7)/.4))):
    yy=y-(d+.65)/2+(col+.5)*(d+.65)/max(8,int((d+.7)/.4))
    xx=x+side*(w/2+.32)*t;zz=eave+rise-(rise+.23)*t+.075
    tile=cube('Individual slate',(xx,yy,zz),((slope/9)*1.18,(d+.7)/max(8,int((d+.7)/.4))*.96,.065),roofmat,.018)
    tile.rotation_euler.y=side*theta
 beam('Oak ridge',(x,y-d/2-.45,eave+rise+.12),(x,y+d/2+.45,eave+rise+.12),.09,wood)
 for sy in [-1,1]:
  beam('Gable trim',(x-w/2-.32,y+sy*(d/2+.35),eave-.15),(x,y+sy*(d/2+.35),eave+rise+.12),.095,wood)
  beam('Gable trim',(x,y+sy*(d/2+.35),eave+rise+.12),(x+w/2+.32,y+sy*(d/2+.35),eave-.15),.095,wood)
 # door boards, stone doorstep and warm transom
 fy=y-d/2-.11
 cube('Door recess',(x,fy,.99),(1.04,.13,1.58),metal,.04)
 for i in range(6):cube('Door oak plank',(x-.43+i*.173,fy-.075,.91),(.16,.09,1.37),wood,.025)
 cube('Door transom',(x,fy-.09,1.63),(.73,.08,.24),light,.02)
 sphere('Iron door handle',(x+.29,fy-.15,.94),(.055,.05,.055),metal)
 for i in range(3):cube('Stone doorstep',(x,fy-.22-i*.23,.15-i*.036),(1.22+i*.12,.45,.17),stone,.035)
 def window(cx,cy,cz,side=False):
  objs=[];objs.append(cube('Window frame',(cx,cy,cz),(.84,.15,1.06),wood,.025));objs.append(cube('Amber glass',(cx,cy-.09,cz),(.67,.08,.88),light,.018))
  objs.append(cube('Window mullion',(cx,cy-.14,cz),(.045,.06,.9),wood));objs.append(cube('Window crossbar',(cx,cy-.14,cz),(.68,.06,.045),wood))
  for s in [-1,1]:
   for i in range(5):objs.append(cube('Shutter board',(cx+s*.55,cy-.04,cz-.4+i*.19),(.23,.12,.17),wood,.015))
  objs.append(cube('Window sill',(cx,cy-.21,cz-.59),(1.26,.35,.12),wood,.025))
  if side:
   pivot=Vector((cx,cy,cz))
   from mathutils import Matrix
   rot=Matrix.Rotation(math.pi/2,4,'Z')
   for o in objs:o.location=pivot+rot.to_3x3()@(o.location-pivot);o.rotation_euler.z=math.pi/2
 for dx in [-w*.31,w*.31]:window(x+dx,fy,h*.59+.35)
 window(x+w/2+.11,y,h*.57+.3,True)
 window(x,fy,eave+rise*.44)
 # brick chimney and moss at the wall foot
 for row in range(7):
  for j in range(2):cube('Chimney brick',(x+w*.29+(.17 if j else -.17),y+.8,eave+rise*.56+row*.16),(.32,.56,.15),stone,.022)
 cube('Chimney cap',(x+w*.29,y+.8,eave+rise*.56+1.09),(.86,.8,.16),stone,.035)
 return {'name':label,'x':x,'z':-y,'w':w+.8,'d':d+.8}
colliders=[cottage(0,2.8,5.1,4.2,2.65,'守灯人的家'),cottage(-6.3,2.8,2.5,2.5,1.8,'药草小屋')]
# Well with individually laid stones, wooden canopy and bucket.
wx,wy=4.5,-2.4
for row in range(3):
 for i in range(12):
  a=math.tau*(i+.5*(row%2))/12;o=cube('Well ring stone',(wx+math.cos(a)*.65,wy+math.sin(a)*.65,.18+row*.2),(.36,.25,.18),stone,.035);o.rotation_euler.z=a+math.pi/2
cylinder('Still well water',(wx,wy,.19),.51,.02,water,24)
for dx in [-.85,.85]:cube('Well canopy post',(wx+dx,wy,1.15),(.13,.15,2.1),wood,.02)
mesh('Well slate canopy',[(wx-1.1,wy-.75,2.1),(wx,wy-.75,2.7),(wx+1.1,wy-.75,2.1),(wx-1.1,wy+.75,2.1),(wx,wy+.75,2.7),(wx+1.1,wy+.75,2.1)],[(0,1,4,3),(1,2,5,4)],roofmat)
beam('Well crossbeam',(wx-.9,wy,1.6),(wx+.9,wy,1.6),.07,wood);beam('Bucket rope',(wx,wy,1.6),(wx,wy,.75),.013,wood);cylinder('Wooden bucket',(wx,wy,.65),.2,.28,wood)
colliders.append({'name':'水井','x':wx,'z':-wy,'w':2.3,'d':1.8})
# A little lived-in clutter: stacked firewood, barrels, flower boxes, crates.
for i in range(9):beam('Stacked logs',(2.8,3.3+i%3*.24,.19+i//3*.21),(3.6,3.3+i%3*.24,.19+i//3*.21),.11,wood)
for x,y in [(3.3,.3),(-4.2,2.5)]:
 cylinder('Oak barrel',(x,y,.4),.32,.75,wood,12)
 for z in [.17,.62]:
  bpy.ops.mesh.primitive_torus_add(major_radius=.323,minor_radius=.018,major_segments=16,minor_segments=6,location=(x,y,z));move(bpy.context.object,'Barrel iron band',metal)
for x in [-1.7,1.7]:
 cube('Flower box',(x,.49,.68),(1.05,.35,.28),wood,.025)
 for i in range(7):sphere('Herb leaves',(x+random.uniform(-.47,.47),.46,.92+random.uniform(0,.1)),(.12,.13,.18),leaves)
# Organic trees, thin branching twigs, bush clusters, small meadow stones.
def tree(x,y,h):
 beam('Tree trunk',(x,y,0),(x+.12,y,h*.7),.12,wood)
 for j in range(7):
  a=j*2.4;dx=math.cos(a)*h*.18;dy=math.sin(a)*h*.18;z=h*.48+j*.055
  beam('Branch',(x,y,z-.15),(x+dx,y+dy,z+.3),.045,wood)
  sphere('Leaf crown',(x+dx,y+dy,z+.48),(h*.26,h*.23,h*.26),leaves)
 colliders.append({'name':'树干','x':x,'z':-y,'w':.65,'d':.65})
for x,y,h in [(-7,-6,3.7),(-8,6,4.4),(7.3,5,4.2),(7.8,-5.8,3.6),(-3,6.7,3.6),(4,6.8,3.9)]:tree(x,y,h)
for i in range(85):
 x=random.uniform(-8.9,8.9);y=random.uniform(-7.8,7.8)
 if abs(x)<1.4 or (-3.1<y<-.5) or any(abs(x-c['x'])<c['w']/2 and abs(y+c['z'])<c['d']/2 for c in colliders):continue
 if i%3==0:sphere('Meadow rock',(x,y,.08),(.16,.13,.09),stone)
 else:
  for j in range(3):beam('Meadow blades',(x+j*.045,y,0),(x-.04+j*.04,y+.03,.16+random.uniform(0,.15)),.013,leaves)
for side in [-1,1]:
 for i in range(9):
  x=side*3.9+i*.43*side;cube('Fence picket',(x,-4.8,.44),(.09,.11,.85),wood,.015)
 for z in [.27,.63]:cube('Fence rail',(side*5.6,-4.8,z),(3.55,.09,.075),wood,.015)
 colliders.append({'name':'木栅栏','x':side*5.6,'z':4.8,'w':3.7,'d':.5})
# Glowing lamps exported with physically portable emissive material; runtime adds spill lights.
lamps=[]
for x,y in [(-1.7,-3.8),(2,-.5),(4.5,-4.5),(-4.8,-.4)]:
 cube('Lamp post',(x,y,.95),(.1,.1,1.9),wood,.02);cube('Lantern glass',(x,y,1.94),(.26,.26,.35),light,.015)
 for dx in [-.14,.14]:
  for dy in [-.14,.14]:cube('Lantern iron frame',(x+dx,y+dy,1.94),(.03,.03,.4),metal)
 cube('Lantern cap',(x,y,2.17),(.36,.36,.1),metal,.015);lamps.append([x,1.94,-y])
# Separate traveler GLB with editable limb pivots. This is articulated geometry, not a skin rig.
activecol=herocol
def empty(name,loc,parent=None):
 o=bpy.data.objects.new(name,None);activecol.objects.link(o);o.location=loc
 if parent:o.parent=parent
 return o
hero=empty('Traveler',(0,0,0))
def parent_local(o,parent):o.parent=parent;return o
parent_local(sphere('Linen coat',(0,0,.76),(.24,.18,.34),cloth),hero)
parent_local(sphere('Head',(0,0,1.25),(.17,.16,.2),skin),hero)
parent_local(sphere('Soft cap',(0,0,1.42),(.205,.185,.09),wood),hero)
parent_local(cube('Scarf',(0,-.03,1.03),(.46,.32,.075),rust,.035),hero)
parent_local(cube('Satchel',(0,.2,.72),(.31,.13,.35),wood,.05),hero)
for label,x in [('Left',-.13),('Right',.13)]:
 p=empty(label+'Leg',(x,0,.49),hero);parent_local(cube(label+' trousers',(0,0,-.19),(.15,.16,.38),wood,.035),p);parent_local(cube(label+' boot',(0,-.04,-.4),(.18,.25,.14),metal,.03),p)
for label,x in [('Left',-.28),('Right',.28)]:
 p=empty(label+'Arm',(x,0,.99),hero);parent_local(cube(label+' sleeve',(0,0,-.18),(.12,.15,.36),cloth,.025),p);parent_local(sphere(label+' hand',(0,0,-.38),(.065,.065,.08),skin),p)
parent_local(cube('Held lantern',(.29,-.03,.46),(.14,.14,.2),light,.015),hero)
# Save original modeling scene before export batching, retaining separate editable details.
scene.render.engine='BLENDER_EEVEE'
bpy.ops.object.camera_add(location=(18,-23,22));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=27;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-4,-6,14));bpy.context.object.data.energy=1800;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=10
scene.world=bpy.data.worlds.new('Twilight world');scene.world.color=(.15,.20,.23)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'courtyard.blend'))
# Export traveler before batching, preserving parent pivots.
bpy.ops.object.select_all(action='DESELECT')
for o in herocol.objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'traveler.glb'),export_format='GLB',use_selection=True,export_extras=True)
# Apply authored bevels, merge static geometry by material for efficient browser draw calls.
bpy.ops.object.select_all(action='DESELECT')
for o in list(worldcol.objects):
 if o.type=='MESH':
  o.select_set(True);bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
  o.select_set(False)
groups={}
for o in worldcol.objects:
 if o.type=='MESH':groups.setdefault(o.data.materials[0].name,[]).append(o)
for name,objects in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name='Courtyard · '+name
bpy.ops.object.select_all(action='DESELECT')
for o in worldcol.objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'courtyard.glb'),export_format='GLB',use_selection=True,export_extras=True)
meta={'bounds':{'x':9.2,'z':8.2},'colliders':colliders,'lamps':lamps,'spawn':[0,0,6.5],'destination':[0,0,1.2],'source':'assets/blender/courtyard.blend','materials':'512px Cycles base-color bakes; no baked illumination','staticMeshes':len(groups),'traveler':'Articulated object pivots; no skeletal skin binding'}
(OUT/'courtyard.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
print('ASSET_PIPELINE_COMPLETE',len(groups))
