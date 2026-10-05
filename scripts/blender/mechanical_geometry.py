"""Mesh construction primitives for the editable ODONATA asset.

Direct mesh creation avoids per-part operators. Hard surfaces keep planar cap
normals; turned profiles split normals at shoulder changes. Units are design
units, not manufacturing dimensions.
"""
import bpy
import math
from mathutils import Vector
TAU=math.tau

def mesh(name, vertices, faces, mat, parent, smooth=False):
    data=bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces); data.update()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o)
    o.parent=parent; data.materials.append(mat)
    if smooth:
        for p in data.polygons: p.use_smooth=True
    return o

def basis(axis):
    n=Vector(axis).normalized()
    ref=Vector((0,0,1)) if abs(n.z)<.95 else Vector((0,1,0))
    u=ref.cross(n).normalized(); v=n.cross(u).normalized()
    return n,u,v

def turned(name, p, profile, mat, parent, axis=(0,0,1), segments=32):
    n,u,v=basis(axis); p=Vector(p); vs=[]; fs=[]
    # Duplicate shoulder vertices, retaining true machined edges at each step.
    for (ra,za),(rb,zb) in zip(profile,profile[1:]):
        offset=len(vs)
        for r,z in [(ra,za),(rb,zb)]:
            for i in range(segments):
                t=TAU*i/segments; vs.append(p+n*z+(u*math.cos(t)+v*math.sin(t))*r)
        for i in range(segments):
            j=(i+1)%segments; fs.append((offset+i,offset+j,offset+segments+j,offset+segments+i))
    return mesh(name,vs,fs,mat,parent,True)

def rod(name,a,b,r,mat,parent,r2=None,vertices=16):
    a,b=Vector(a),Vector(b); d=b-a; length=d.length
    return turned(name,a,[(0,0),(r,0),(r if r2 is None else r2,length),(0,length)],mat,parent,d,vertices)

def ring(name,p,r,t,mat,parent,axis=(0,0,1),segments=40):
    n,u,v=basis(axis); p=Vector(p); vs=[]; fs=[]; minor=8
    for i in range(segments):
        a=TAU*i/segments; out=u*math.cos(a)+v*math.sin(a)
        for j in range(minor):
            b=TAU*j/minor; vs.append(p+out*(r+t*math.cos(b))+n*(t*math.sin(b)))
    for i in range(segments):
        for j in range(minor): fs.append((i*minor+j,((i+1)%segments)*minor+j,((i+1)%segments)*minor+(j+1)%minor,i*minor+(j+1)%minor))
    return mesh(name,vs,fs,mat,parent,True)

def ball(name,p,scale,mat,parent,detail=20,rings=12):
    p=Vector(p); vs=[]; fs=[]
    for j in range(rings+1):
        b=math.pi*j/rings
        for i in range(detail):
            a=TAU*i/detail; vs.append(p+Vector((scale[0]*math.sin(b)*math.cos(a),scale[1]*math.sin(b)*math.sin(a),scale[2]*math.cos(b))))
    for j in range(rings):
        for i in range(detail): fs.append((j*detail+i,j*detail+(i+1)%detail,(j+1)*detail+(i+1)%detail,(j+1)*detail+i))
    return mesh(name,vs,fs,mat,parent,True)

def wire(name,points,r,mat,parent,sides=6):
    points=[Vector(p) for p in points]; vs=[]; fs=[]
    for i,p in enumerate(points):
        tangent=points[min(i+1,len(points)-1)]-points[max(i-1,0)]
        n,u,v=basis(tangent)
        for j in range(sides):
            a=TAU*j/sides; vs.append(p+(u*math.cos(a)+v*math.sin(a))*r)
    for i in range(len(points)-1):
        for j in range(sides): fs.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    return mesh(name,vs,fs,mat,parent,True)

def plate(name,polygon,z,thickness,mat,parent,bevel=.004):
    # Four polygon rings create a real edge chamfer, rather than smooth shading
    # across an entire rectangular solid.
    cx=sum(p[0] for p in polygon)/len(polygon); cy=sum(p[1] for p in polygon)/len(polygon)
    maxr=max(math.hypot(p[0]-cx,p[1]-cy) for p in polygon)
    fac=1-min(.2,bevel/maxr); b=min(bevel,thickness*.35); vs=[]; fs=[]; N=len(polygon)
    for scale,h in [(fac,z),(1,z+b),(1,z+thickness-b),(fac,z+thickness)]:
        vs += [(cx+(x-cx)*scale,cy+(y-cy)*scale,h) for x,y in polygon]
    fs.append(tuple(reversed(range(N)))); fs.append(tuple(range(3*N,4*N)))
    for j in range(3):
        for i in range(N): fs.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
    return mesh(name,vs,fs,mat,parent)

def box(name,p,size,mat,parent,bevel=.006):
    x,y,z=p; a,b,c=(n/2 for n in size); cham=min(bevel,a*.3,b*.3)
    poly=[(x-a+cham,y-b),(x+a-cham,y-b),(x+a,y-b+cham),(x+a,y+b-cham),(x+a-cham,y+b),(x-a+cham,y+b),(x-a,y+b-cham),(x-a,y-b+cham)]
    return plate(name,poly,z-c,c*2,mat,parent,bevel)

def shell(name,rows,thickness,mat,parent):
    # Rows describe the curved outside surface. Inner surface is radially inset
    # toward the longitudinal axis; bridged boundaries give plates real thickness.
    vs=[Vector(p) for row in rows for p in row]; count=len(vs); R=len(rows); C=len(rows[0]); fs=[]
    for p in list(vs):
        radial=Vector((p.x,0,p.z)).normalized(); vs.append(p-radial*thickness)
    for j in range(R-1):
        for i in range(C-1):
            a=j*C+i; fs.append((a,a+1,a+C+1,a+C)); fs.append((count+a+C,count+a+C+1,count+a+1,count+a))
    border=list(range(C))+[j*C+C-1 for j in range(1,R)]+list(range((R-1)*C+C-2,(R-1)*C-1,-1))+[j*C for j in range(R-2,0,-1)]
    for a,b in zip(border,border[1:]+border[:1]): fs.append((a,b,count+b,count+a))
    return mesh(name,vs,fs,mat,parent,True)

def clip_polygon(poly,dx,dy,limit):
    out=[]
    if not poly:return out
    prev=poly[-1]; a=prev[0]*dx+prev[1]*dy-limit
    for point in poly:
        b=point[0]*dx+point[1]*dy-limit
        if (a<=0)!=(b<=0):
            f=a/(a-b); out.append((prev[0]+(point[0]-prev[0])*f,prev[1]+(point[1]-prev[1])*f))
        if b<=0:out.append(point)
        prev=point;a=b
    return out

def voronoi_edges(seeds,boundary):
    edges={}
    for i,(x,y) in enumerate(seeds):
        cell=boundary[:]
        nearest=sorted((p for j,p in enumerate(seeds) if j!=i),key=lambda p:(x-p[0])**2+(y-p[1])**2)[:20]
        for qx,qy in nearest:
            cell=clip_polygon(cell,qx-x,qy-y,(qx*qx+qy*qy-x*x-y*y)/2)
            if not cell:break
        for a,b in zip(cell,cell[1:]+cell[:1]):
            if math.dist(a,b)<.012:continue
            key=tuple(sorted((tuple(round(v,5) for v in a),tuple(round(v,5) for v in b))))
            edges[key]=(a,b)
    return list(edges.values())
