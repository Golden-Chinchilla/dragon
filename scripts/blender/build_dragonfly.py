"""ODONATA / revision 02 — watch-movement mechanical dragonfly.

Fully editable independent solids. Geometry expresses seams, cut plates, gear
teeth, bearing races, optical cells and wing venation. Blender X lateral, -Y
forward, Z up; export uses glTF Y-up. No baked maps or physics simulation.
"""
import bpy
import math
import json
import random
import sys
from pathlib import Path
from collections import defaultdict
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from mechanical_geometry import mesh,turned,rod,ring,ball,wire,plate,box,shell,basis,voronoi_edges
TAU=math.tau
random.seed(24)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for m in list(bpy.data.materials):bpy.data.materials.remove(m)
def material(name,color,metallic,roughness,alpha=1,glow=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,alpha);m.use_nodes=True
    bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if bs is None:
        bs=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled');out=m.node_tree.nodes.new('ShaderNodeOutputMaterial');m.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    for k,v in [('Base Color',(*color,alpha)),('Metallic',metallic),('Roughness',roughness),('Alpha',alpha)]:bs.inputs[k].default_value=v
    if alpha<1:m.surface_render_method='DITHERED'
    if glow:bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=glow
    return m
TI=material('01 | Bead blasted titanium',(.13,.17,.19),.86,.36)
SILVER=material('02 | Ground steel edges',(.32,.37,.40),.94,.27)
DARK=material('03 | Graphite ceramic',(.017,.023,.027),.48,.38)
GOLD=material('04 | Pale nickel brass',(.36,.255,.13),.88,.31)
COPPER=material('05 | Enamelled copper',(.28,.10,.045),.83,.32)
GLASS=material('06 | Obsidian optical cells',(.009,.028,.032),.48,.23)
MEMBRANE=material('07 | Iridescent wing film',(.27,.32,.28),.30,.32,.16)
LIGHT=material('08 | Recessed amber indicators',(.90,.24,.035),.2,.31,glow=.7)
TEAL=material('09 | Blue tempered steel',(.07,.15,.19),.88,.32)
assemblies={};features=defaultdict(int)
def group(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;assemblies[name]=o;return o
root=group('Dragonfly');body=group('Thorax',parent=root);head=group('Head',(0,-1.08,.08),root)
def screw(p,parent,size=.018,axis=(0,0,1)):
    n,u,v=basis(axis);p=Vector(p)
    turned('Countersunk screw',p,[(size*.45,-.008),(size,.0),(size,.009),(size*.85,.013),(size*.43,.013)],SILVER,parent,n,12)
    rod('Hex socket',p+n*.011,p+n*.013,size*.43,DARK,parent,vertices=6)
    features['fasteners']+=1

def bearing(p,r,parent,axis=(0,0,1),rollers=12):
    n,u,v=basis(axis);p=Vector(p)
    turned('Bearing seat',p,[(r*.60,-.034),(r*1.14,-.034),(r*1.14,-.02),(r*1.02,-.012),(r*1.02,.018),(r*.88,.018)],TI,parent,n)
    ring('Outer race',p+n*.018,r,.009,SILVER,parent,n,40)
    ring('Inner race',p+n*.021,r*.64,.008,GOLD,parent,n,32)
    for i in range(rollers):
        t=TAU*i/rollers;q=p+n*.02+(u*math.cos(t)+v*math.sin(t))*r*.81
        ball('Bearing roller',q,(r*.095,)*3,SILVER,parent,10,6)
    rod('Axle cap',p,p+n*.044,r*.46,DARK,parent,vertices=24)
    screw(p+n*.047,parent,r*.22,n);features['bearings']+=1

def cog(name,p,r,teeth,parent,depth=.035):
    g=group(name,p,parent);vs=[];fs=[]
    # Narrow dedendum, tapered tooth flank and flat addendum. Deliberately a
    # visual gear profile, not a manufacturing-grade involute specification.
    outline=[]
    for i in range(teeth):
        for phase,rad in [(0,.91),(.15,.91),(.28,1.025),(.56,1.025),(.73,.91)]:
            t=TAU*(i+phase)/teeth;outline.append((r*rad*math.cos(t),r*rad*math.sin(t)))
    N=len(outline)
    for z in [-depth/2,depth/2]:
        vs.extend((x,y,z) for x,y in outline)
        vs.extend((x*.76,y*.76,z) for x,y in outline)
    for i in range(N):
        j=(i+1)%N
        fs.extend([(i,j,2*N+j,2*N+i),(N+j,N+i,3*N+i,3*N+j),(2*N+i,2*N+j,3*N+j,3*N+i),(j,i,N+i,N+j)])
    mesh('Cut tooth crown',vs,fs,GOLD,g)
    for z in [-depth*.52,depth*.52]:ring('Tooth root bevel',(0,0,z),r*.79,.004,SILVER,g,segments=64)
    for i in range(5):
        a=TAU*i/5
        poly=[]
        for radius,angle in [(r*.19,a-.26),(r*.80,a-.085),(r*.80,a+.085),(r*.19,a+.26)]:poly.append((radius*math.cos(angle),radius*math.sin(angle)))
        plate('Tapered web spoke',poly,-depth*.30,depth*.6,GOLD,g,.002)
    turned('Stepped gear hub',(0,0,0),[(r*.13,-.04),(r*.30,-.04),(r*.30,.035),(r*.24,.042),(r*.12,.042)],SILVER,g,segments=32)
    screw((0,0,.045),g,r*.12)
    features['gearTeeth']+=teeth
    return g

def coil(p,r,length,parent,axis=(0,0,1),turns=14):
    n,u,v=basis(axis);p=Vector(p)
    rod('Winding armature',p,p+n*length,r*.83,DARK,parent,vertices=24)
    points=[]
    for i in range(turns*14+1):
        t=TAU*i/14;points.append(p+n*(length*i/(turns*14))+(u*math.cos(t)+v*math.sin(t))*r)
    wire('Continuous copper winding',points,.008,COPPER,parent)
    for z in [0,length]:turned('Winding end cap',p+n*z,[(0,-.008),(r*1.1,-.008),(r*1.1,.008),(0,.008)],TI,parent,n,24)

def cable(points,parent,r=.009):
    # Three slender helices around the routed cable centreline.
    points=[Vector(p) for p in points];dense=[]
    for a,b in zip(points,points[1:]):
        for i in range(12):dense.append(a.lerp(b,i/12))
    dense.append(points[-1])
    for strand in range(3):
        out=[]
        for i,p in enumerate(dense):
            n,u,v=basis(dense[min(i+1,len(dense)-1)]-dense[max(0,i-1)])
            a=i*.9+strand*TAU/3;out.append(p+(u*math.cos(a)+v*math.sin(a))*r*.65)
        wire('Braided control cable',out,r*.43,COPPER if strand==0 else DARK,parent,sides=5)

def lettering(text,p,size,parent,rotation=(0,0,0),mat=GOLD):
    data=bpy.data.curves.new('Laser legend','FONT');data.body=text;data.size=size;data.extrude=.0005;data.space_character=1.15
    o=bpy.data.objects.new('Laser legend '+text,data);bpy.context.collection.objects.link(o);o.parent=parent;o.location=p;o.rotation_euler=rotation;data.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')

# Compact barrel motor and skeletal chassis: dark foundation, not a solid ball.
rod('Central motor barrel',(0,-.60,-.11),(0,.61,-.11),.225,DARK,body,vertices=48)
for y in [-.62,-.58,-.53,.48,.53,.58]:
    turned('Motor cooling shoulder',(0,y,-.11),[(.17,-.01),(.26,-.01),(.26,.008),(.17,.008)],SILVER,body,(0,1,0),40)
for side in [-1,1]:
    for y in [-.42,.05,.45]:coil((side*.31,y,-.12),.087,.23,body,turns=13)
    # Dorsal and ventral machined rails, slimmer than the earlier pipe cage.
    wire('Dorsal frame rail',[(side*.24,-.83,.24),(side*.47,-.52,.31),(side*.49,.34,.30),(side*.25,.80,.21)],.020,SILVER,body)
    wire('Ventral frame rail',[(side*.25,-.73,-.20),(side*.41,.34,-.30),(side*.22,.77,-.13)],.019,TI,body)
    for j in range(3):
        ya=-.69+j*.45;yb=ya+.39;rows=[]
        for k in range(7):
            y=ya+(yb-ya)*k/6;w=.39+.12*math.sin((y+.85)/1.7*math.pi)
            row=[]
            for h in range(9):
                angle=-.32+.93*h/8;row.append((side*w*math.cos(angle),y,.04+w*.72*math.sin(angle)))
            rows.append(row)
        shell('Scalloped flank armor',rows,.014,TI,body)
        for y in [ya+.06,yb-.055]:screw((side*.44,y,.235),body,.015)
        # Long inset vents and raised lips, visible through the cheek opening.
        for k in range(5):
            y=ya+.075+k*.05
            box('Dark louver recess',(side*.485,y,.1),(.015,.025,.13),DARK,body,.003)
            rod('Louver edge',(side*.49,y,.08),(side*.475,y,.20),.004,SILVER,body)
    cable([(side*.23,-.75,.15),(side*.51,-.48,.19),(side*.55,.30,.13),(side*.21,.86,.12)],body)
    for y in [-.58,-.05,.53]:
        plate('Shoulder clevis',[(side*.34,y-.10),(side*.67,y-.10),(side*.69,y+.08),(side*.35,y+.1)],.055,.04,TI,body)
        screw((side*.60,y,.102),body,.021)
# Skeletonised dorsal movement deck.
for side in [-1,1]:
    plate('Movement side plate',[(side*.07,-.61),(side*.29,-.65),(side*.45,-.39),(side*.45,.37),(side*.23,.59),(side*.07,.55)],.295,.022,DARK,body)
    for y in [-.48,-.24,0,.24,.45]:screw((side*.38,y,.322),body,.017)
    for j in range(15):
        box('Machined calibration notch',(side*.423,-.34+j*.045,.324),(.018,.0035,.002),SILVER,body,.001)
gearA=cog('Gear_A',(-.21,-.12,.365),.215,36,body)
gearB=cog('Gear_B',(.20,-.12,.365),.195,32,body)
gearC=cog('Gear_C',(0,.225,.365),.184,30,body)
# Small secondary reduction wheels seated at a lower level.
for side in [-1,1]:
    cog('Reduction_'+str(side),(side*.275,.41,.30),.101,20,body,.026)
    bearing((side*.275,.41,.352),.044,body,rollers=8)
# Stepped bridge plates cross the hubs; access windows leave the teeth exposed.
for x,y in [(-.21,-.12),(.20,-.12),(0,.225)]:
    plate('Skeleton balance bridge',[(x-.042,y-.17),(x+.041,y-.17),(x+.07,y+.07),(x+.04,y+.15),(x-.04,y+.15),(x-.07,y+.07)],.438,.018,TI,body,.004)
    bearing((x,y,.460),.044,body,rollers=9)
    for yy in [y-.137,y+.117]:screw((x,yy,.46),body,.013)
plate('Anterior shield',[(-.32,-.78),(-.24,-.91),(.24,-.91),(.32,-.78),(.25,-.61),(-.25,-.61)],.22,.03,TI,body)
lettering('OD / 02',(-.145,-.81,.255),.045,body)
for x in [-.25,.25]:screw((x,-.76,.263),body,.019)
plate('Rear service hatch',[(-.20,.53),(.2,.53),(.28,.72),(.12,.84),(-.12,.84),(-.28,.72)],.21,.035,TI,body)
for y in [.61,.65,.69,.73]:box('Rear heat exchanger',(0,y,.254),(.28,.016,.018),DARK,body,.003)
for x in [-.23,.23]:screw((x,.70,.258),body,.017)

# Head: close-packed optical array over a compact dark shell and detailed bezel.
turned('Neck universal collar',(0,.12,0),[(.11,-.15),(.17,-.15),(.17,-.10),(.14,-.10),(.14,.1),(.10,.1)],GOLD,head,(0,1,0),40)
for y in [-.12,-.07,-.02]:ring('Neck bellows',(0,y,0),.13,.012,DARK,head,(0,1,0))
plate('Cranial crown',[(-.18,-.07),(.18,-.07),(.22,-.37),(.10,-.65),(-.10,-.65),(-.22,-.37)],.12,.06,TI,head,.01)
plate('Crown inlay',[(-.055,-.10),(.055,-.10),(.073,-.46),(0,-.57),(-.073,-.46)],.183,.008,DARK,head,.003)
for y in [-.16,-.28,-.4]:screw((0,y,.20),head,.014)
for side in [-1,1]:
    center=Vector((side*.30,-.36,.12));r=.255
    ball('Eye body',center,(r,r,r),DARK,head,32,18)
    direction=Vector((side*.27,-.69,.67)).normalized();n,u,v=basis(direction)
    turned('Optical bezel',center,[(r*.91,-.025),(r*1.035,-.025),(r*1.035,.012),(r*.975,.022)],TI,head,n,64)
    ring('Bezel polished lip',center+n*.019,r*.985,.006,GOLD,head,n,64)
    # Hex tiling projected onto the visible sphere; narrow bezels and real facets.
    pitch=.109
    for row in range(-10,11):
        for col in range(-10,11):
            xx=(col+.5*(row%2))*pitch;yy=row*pitch*.8660254
            if xx*xx+yy*yy>.953**2:continue
            zz=math.sqrt(1-xx*xx-yy*yy);normal=(u*xx+v*yy+n*zz).normalized();p=center+normal*(r+.003)
            nn,uu,vv=basis(normal);rad=r*pitch*.55
            bezel=[];faces=[]
            for scale,height in [(1,0),(.82,.002)]:
                for j in range(6):
                    a=TAU*j/6;bezel.append(p+(uu*math.cos(a)+vv*math.sin(a))*rad*scale+nn*height)
            for j in range(6):faces.append((j,(j+1)%6,(j+1)%6+6,j+6))
            mesh('Optical cell bezel',bezel,faces,GOLD if (row+col)%5==0 else TI,head)
            glassverts=bezel[6:]+[p+nn*.0045]
            mesh('Faceted optical lens',glassverts,[(j,(j+1)%6,6) for j in range(6)],TEAL if (row*11+col)%13==0 else GLASS,head)
            features['opticalCells']+=1
    for j in range(12):
        t=TAU*j/12;p=center+n*.023+(u*math.cos(t)+v*math.sin(t))*r*1.02
        screw(p,head,.011,n)
    wire('Jointed antenna',[(side*.12,-.53,.16),(side*.20,-.76,.21),(side*.26,-.96,.24)],.009,SILVER,head)
    for k in range(5):
        a=Vector((side*.20,-.76,.21)).lerp(Vector((side*.26,-.96,.24)),k/5)
        ball('Antenna ferrule',a,(.013,)*3,GOLD,head,10,6)
    wire('Mandible blade',[(side*.11,-.48,-.08),(side*.21,-.64,-.13),(side*.13,-.76,-.15)],.020,TI,head)
    screw((side*.16,-.48,-.05),head,.016)
# Compact iris sensor mounted vertically at the brow.
n=Vector((0,-1,.18)).normalized();p=Vector((0,-.615,.09))
turned('Front iris bezel',p,[(.031,0),(.07,0),(.075,.02),(.07,.045),(.039,.049)],GOLD,head,n,40)
rod('Iris aperture',p+n*.046,p+n*.048,.037,DARK,head,vertices=32)
ring('Iris optical rim',p+n*.05,.026,.003,SILVER,head,n,32)
rod('Iris lens',p+n*.05,p+n*.052,.023,GLASS,head,vertices=32)

# Detailed wing roots and organic cellular venation.
for side,label in [(-1,'L'),(1,'R')]:
    for row,yy in [('Fore',-.46),('Hind',.43)]:
        mount=group('Mount_'+label+'_'+row,(side*.54,yy,.18),body)
        rod('Wing trunnion',(-.10,0,0),(.10,0,0),.081,DARK,mount,vertices=32)
        for x in [-.108,.108]:bearing((x,0,0),.103,mount,(1 if x>0 else -1,0,0),12)
        for a in [-1,1]:
            box('Clevis cheek',(0,a*.127,-.005),(.22,.028,.145),TI,mount,.008)
            screw((0,a*.146,.04),mount,.018,(0,a,0))
        g=group('Wing_'+label+'_'+row,(side*.64,yy,.24),root)
        length=3.90 if row=='Fore' else 3.50;sweep=-.22 if row=='Fore' else .30;width=.92 if row=='Fore' else 1.14
        def halfwidth(t):return width*math.sin(math.pi*min(.99999,max(.00001,t)))**.72*(.80+.20*t)
        def pos(t,v,z=0):return (side*length*t,sweep*length*t+halfwidth(t)*v,z+.042*math.sin(math.pi*t))
        def wp(p,z=.008):
            t=p[0]/length;return (side*p[0],p[1]+sweep*p[0],z+.042*math.sin(math.pi*t))
        boundary=[(length*i/48,halfwidth(i/48)*-.48) for i in range(49)]+[(length*i/48,halfwidth(i/48)*.52) for i in range(48,-1,-1)]
        vs=[wp(p,0) for p in boundary];vs.append(wp((length*.48,0),0));N=len(boundary)
        mesh('Clear cellular wing film',vs,[(i,(i+1)%N,N) for i in range(N)],MEMBRANE,g)
        for v in [-.48,.52]:wire('Tapered wing perimeter',[pos(i/64,v,.009) for i in range(65)],.010,SILVER,g)
        wire('Paired leading spar',[pos(i/64,-.43,.013) for i in range(65)],.007,GOLD,g)
        seeds=[]
        rng=random.Random(31 if row=='Fore' else 49)
        for i in range(2,37):
            t=i/39;w=halfwidth(t)
            rows=max(2,int(w/.12))
            for j in range(rows):
                x=length*(t+rng.uniform(-.009,.009));y=w*(-.40+.84*(j+.5)/rows+rng.uniform(-.035,.035));seeds.append((x,y))
        for a,b in voronoi_edges(seeds,boundary):
            wire('Cellular cross vein',[wp(a),wp(b)],.0030,TI,g,sides=5);features['wingCellEdges']+=1
        for v in [-.23,.05,.30]:
            wire('Branching longitudinal vein',[pos(i/64,v+.035*math.sin(i/64*math.pi*2),.014) for i in range(2,64)],.0046,GOLD if v<0 else SILVER,g)
        # Skeleton fork with twin skins and a line of small ferrules.
        poly=[(0,-.035),(side*.14,-.095),(side*.67,sweep*.67-.08),(side*.77,sweep*.77+.02),(side*.18,.07)]
        plate('Root fork upper skin',poly,.027,.014,TI,g,.004)
        for v in [-.30,.28]:wire('Root tension member',[(0,0,0),pos(.07,v,.02),pos(.20,v,.018)],.014,SILVER,g)
        for t in [.038,.071,.108,.145]:screw(pos(t,-.04,.049),g,.013)
        # A counterweight follows the leading edge instead of a large yellow bar.
        for t in [.77,.80,.83]:
            p=pos(t,-.36,.014);box('Pterostigma weight',p,(.11,.055,.012),GOLD,g,.003)
        lettering('OD-'+('F' if row=='Fore' else 'H'),pos(.15,-.17,.049),.034,g)
# Slender pushrods; runtime connects these named pivot groups to wing root motion.
for side,label in [(-1,'L'),(1,'R')]:
    for row,yy in [('Fore',-.46),('Hind',.43)]:
        a=Vector((side*.24,yy,.46));b=Vector((side*.80,yy,.21));d=b-a
        g=group('DriveRod_'+label+'_'+row,a,root)
        rod('Hardened pushrod',(0,0,0),(0,0,1),.012,SILVER,g)
        rod('Pushrod sleeve',(0,0,.15),(0,0,.54),.022,TI,g)
        for z in [.14,.20,.48,.54]:ring('Sleeve retaining clip',(0,0,z),.023,.003,GOLD,g,segments=20)
        g.rotation_mode='QUATERNION';g.rotation_quaternion=d.to_track_quat('Z','Y');g.scale.z=d.length
        for p in [a,b]:bearing(p,.035,body,rollers=8)

# Overlapping abdominal shells around a fine segmented spine.
parent=root
for i in range(10):
    r=.30*(1-i*.079);L=.38
    g=group('Abdomen_%02d'%i,(0,.89,-.015) if i==0 else (0,.365,-.018),parent)
    rod('Abdominal mandrel',(0,0,0),(0,L,0),r*.60,DARK,g,vertices=24)
    # Narrow flange, cooling discs and separate tapered left/right armor leaves.
    for y in [.016,.039,.060]:turned('Vertebral cooling flange',(0,y,0),[(r*.56,-.003),(r*.91,-.003),(r*.91,.003),(r*.56,.003)],GOLD if y==.039 else SILVER,g,(0,1,0),32)
    for lo,hi in [(.04,1.39),(1.75,math.pi-.04)]:
        rows=[]
        for j in range(9):
            t=j/8;y=.075+t*.285;rad=r*(1-.17*t+.055*math.sin(math.pi*t))
            # Angled seam at front and rear gives a machined, overlapping leaf.
            rows.append([(rad*math.cos(a),y+.013*math.sin(a)*math.sin(math.pi*t),rad*.83*math.sin(a)) for a in [lo+(hi-lo)*k/10 for k in range(11)]])
        shell('Tapered abdominal armor leaf',rows,.012,TI,g)
    for side in [-1,1]:
        for y in [.116,.295]:screw((side*r*.70,y,r*.62),g,.012 if i<5 else .009)
        wire('Exposed abdominal tendon',[(side*r*.80,0,-r*.31),(side*r*.76,L,-r*.31)],.009,GOLD,g)
        # A real inset and two rails, rather than a black rectangle on a cylinder.
        box('Service slot',(side*r*.32,.215,r*.795),(r*.15,.14,.004),DARK,g,.003)
        for y in [.15,.19,.23,.27]:box('Service slot fin',(side*r*.32,y,r*.805),(r*.15,.008,.005),SILVER,g,.001)
    for k in range(7):
        y=.09+k*.035
        box('Exposed spine rib',(0,y,r*.63),(r*.24,.011,r*.27),GOLD if k in [0,6] else DARK,g,.002)
    box('Spine light recess',(0,.215,r*.79),(r*.17,.08,.012),DARK,g,.002)
    if i in [0,3,6]:box('Spine index light',(0,.215,r*.8),(r*.06,.039,.003),LIGHT,g,.001)
    if i<4:lettering('%02d'%(i+1),(r*.46,.23,r*.80),.028,g)
    parent=g
for side in [-1,1]:
    wire('Terminal sensory fork',[(side*.04,.28,0),(side*.09,.47,.01),(side*.075,.64,.04)],.012,SILVER,parent)
    ring('Terminal hinge',(side*.06,.35,0),.025,.004,GOLD,parent,(1,0,0),20)
# Legs: twin fork members, joint races, hydraulic boots and segmented grippers.
for side,label in [(-1,'L'),(1,'R')]:
    for i,yy in enumerate([-.61,-.04,.56]):
        g=group('Leg_'+label+'_'+str(i),(side*.38,yy,-.19),root)
        a=Vector((0,0,0));b=Vector((side*.53,(i-1)*.25,-.32));c=Vector((side*.77,(i-1)*.47,-.93));d=Vector((side*.94,(i-1)*.60,-1.16))
        for p,r in [(a,.08),(b,.065),(c,.045)]:
            rod('Articulation axle',p+Vector((0,-.07,0)),p+Vector((0,.07,0)),r*.5,DARK,g)
            for sign in [-1,1]:bearing(p+Vector((0,sign*.064,0)),r,g,(0,sign,0),8)
        for sign in [-1,1]:
            o=Vector((0,sign*.052,0));wire('Twin femur link',[a+o,a.lerp(b,.27)+o+Vector((0,0,.014)),b+o],.017,TI,g)
            wire('Twin tibial link',[b+o,c+o],.010,SILVER,g)
        rod('Piston polished rod',b,c,.015,SILVER,g)
        rod('Piston barrel',b,b.lerp(c,.47),.036,DARK,g)
        n=(c-b).normalized()
        for j in range(12):ring('Piston bellows',b.lerp(c,.05+j*.026),.037,.0035,TI,g,n,20)
        for t in [.05,.44]:ring('Hydraulic gland',b.lerp(c,t),.04,.006,GOLD,g,n,24)
        cable([a+Vector((0,.08,0)),b+Vector((0,.085,.02)),c+Vector((0,.06,0))],g,.006)
        rod('Tarsal strut',c,d,.018,TI,g,r2=.011)
        for j in range(4):ring('Ankle rib',c.lerp(d,j/4),.024-j*.003,.003,SILVER,g,d-c,16)
        for sign in [-1,1]:
            claw=[d,d+Vector((side*.065,sign*.045,-.07)),d+Vector((side*.14,sign*.04,-.09)),d+Vector((side*.16,sign*.024,-.025))]
            for j in range(3):rod('Gripper phalange',claw[j],claw[j+1],.012-j*.002,TI if j<2 else SILVER,g,r2=.008-j*.002)
            for p in claw[1:3]:screw(p,g,.009,(0,1,0))

# Save independent parts, then build a compact export from material/pivot groups.
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
scene['design']='ODONATA / revision 02 — layered watch movement';scene['asset_notes']='Geometric details, nine constant PBR materials. No texture baking, skinning, physical drivetrain constraints or pre-baked animations.'
mesh_count=sum(o.type=='MESH' for o in scene.objects)
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/dragonfly.blend'))
buckets=defaultdict(list)
for o in list(scene.objects):
    if o.type=='MESH':buckets[(o.parent.name,o.data.materials[0].name)].append(o)
for (par,mat),obs in buckets.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();bpy.context.object.name=par+'__'+mat.split(' | ')[0]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'public/assets/dragonfly.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
triangles=sum(len(p.vertices)-2 for o in scene.objects if o.type=='MESH' for p in o.data.polygons)
report={'revision':2,'sourceParts':mesh_count,'exportMeshes':sum(o.type=='MESH' for o in scene.objects),'triangles':triangles,'materials':len(bpy.data.materials),'assemblies':list(assemblies),'features':dict(features),'bytes':(ROOT/'public/assets/dragonfly.glb').stat().st_size,'bakedTextures':False,'rig':'Named rigid-object pivots; no skinning or physical constraints in GLB.'}
(ROOT/'public/assets/dragonfly.json').write_text(json.dumps(report,indent=2)+'\n')
print('DRAGONFLY_EXPORT_COMPLETE',json.dumps(report))
