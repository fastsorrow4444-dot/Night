"""blender -b --python tools/art/build_realistic_worker.py
Anatomy, eyes and weights: MakeHuman hm08, CC0. See source/README.md.
Clothes, skin paint and details: Shift 13. Blender is only an authoring tool.
"""
import bpy
import math
import json
from pathlib import Path
from collections import defaultdict
from mathutils import Vector, Matrix, Quaternion
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
SRC=Path(__file__).parent/'source'/'makehuman'
DEST=ROOT/'assets'/'character'
TEX=DEST/'textures'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def read_obj(path):
    vertices,uv,groups=[],[],defaultdict(list);group='body'
    for line in path.read_text().splitlines():
        p=line.split()
        if not p:continue
        if p[0]=='v':vertices.append(Vector(tuple(map(float,p[1:4]))))
        elif p[0]=='vt':uv.append(tuple(map(float,p[1:3])))
        elif p[0]=='g':group=p[1]
        elif p[0]=='f':groups[group].append([(int(x.split('/')[0])-1,int(x.split('/')[1])-1 if '/' in x and x.split('/')[1] else 0) for x in p[1:]])
    return vertices,uv,groups

base,uv,groups=read_obj(SRC/'base.obj');coords=[v.copy() for v in base]
for filename,amount in [('caucasian-male-young.target',.82),('caucasian-male-old.target',.18)]:
    for line in (SRC/filename).read_text().splitlines():
        if not line or line.startswith('#'):continue
        p=line.split();coords[int(p[0])]+=Vector(tuple(map(float,p[1:4])))*amount
floor=min(coords[i].y for f in groups['body'] for i,_ in f)
SCALE=1.78/(max(coords[i].y for f in groups['body'] for i,_ in f)-floor)
def xyz(v):return Vector((-v.x,v.z,v.y-floor))*SCALE
points=[xyz(v) for v in coords]
rigdata=json.loads((SRC/'default.mhskel').read_text())
weights=json.loads((SRC/'default_weights.mhw').read_text())['weights']
def joint(name,which):
    ids=rigdata['joints'][rigdata['bones'][name][which]]
    return sum((points[i] for i in ids),Vector())/len(ids)

def mat(name,color,texture=None,roughness=.85,metal=0,normal=None):
    m=bpy.data.materials.new(name);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=roughness;bs.inputs['Metallic'].default_value=metal
    if texture:
        im=m.node_tree.nodes.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(TEX/texture),check_existing=True)
        m.node_tree.links.new(im.outputs['Color'],bs.inputs['Base Color'])
    if normal:
        im=m.node_tree.nodes.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(TEX/normal),check_existing=True);im.image.colorspace_settings.name='Non-Color'
        n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.16
        m.node_tree.links.new(im.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],bs.inputs['Normal'])
    return m
M={
 'work':mat('Navy cotton canvas',(1,1,1),'work_canvas.png',normal='work_canvas_normal.png'),
 'casual':mat('Burgundy fleece',(1,1,1),'hoodie.png',normal='hoodie_normal.png'),
 'cargo':mat('Graphite twill',(1,1,1),'work_trousers.png',normal='work_trousers_normal.png'),
 'denim':mat('Indigo denim',(1,1,1),'denim.png',normal='denim_normal.png'),
 'leather':mat('Boot leather',(1,1,1),'leather.png',roughness=.72),
 'rubber':mat('Rubber',(.025,.028,.027)),
 'trim':mat('Reflective fabric',(.48,.49,.45),roughness=.58),
 'thread':mat('Seam thread',(.11,.15,.16)),
 'zip':mat('Gunmetal zipper',(.20,.22,.21),roughness=.4,metal=.65),
 'hair':mat('Short dark hair',(.035,.025,.02),roughness=.93),
 'eyes':mat('Brown eyes',(1,1,1),'brown_eye.png',roughness=.24),
}
eye_material=M['eyes'];eye_bs=eye_material.node_tree.nodes.get('Principled BSDF')
eye_image=next(n for n in eye_material.node_tree.nodes if n.type=='TEX_IMAGE')
eye_material.node_tree.links.new(eye_image.outputs['Alpha'],eye_bs.inputs['Alpha'])
eye_material.surface_render_method='DITHERED'
arm=bpy.data.armatures.new('WorkerSkeleton');rig=bpy.data.objects.new('WorkerRig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bone_defs={}
def bone(name,head,tail,parent=None):
    b=arm.edit_bones.new(name);b.head=head;b.tail=tail
    if parent:b.parent=arm.edit_bones[parent]
    b.align_roll(Vector((0,1,0)));bone_defs[name]=(head.copy(),tail.copy(),parent)
bone('Hips',joint('spine05','head'),joint('spine04','head'))
bone('Spine',joint('spine04','head'),joint('spine02','head'),'Hips')
bone('Chest',joint('spine02','head'),joint('neck01','head'),'Spine')
bone('Neck',joint('neck01','head'),joint('head','head'),'Chest')
bone('Head',joint('head','head'),joint('head','tail'),'Neck')
for side in ['L','R']:
    bone('Clavicle'+side,joint('clavicle.'+side,'head'),joint('upperarm01.'+side,'head'),'Chest')
    bone('UpperArm'+side,joint('upperarm01.'+side,'head'),joint('lowerarm01.'+side,'head'),'Clavicle'+side)
    bone('Forearm'+side,joint('lowerarm01.'+side,'head'),joint('wrist.'+side,'head'),'UpperArm'+side)
    bone('Hand'+side,joint('wrist.'+side,'head'),joint('wrist.'+side,'tail'),'Forearm'+side)
    for finger in range(1,6):
        for segment in range(1,4):
            src=f'finger{finger}-{segment}.{side}';name=f'Finger{finger}_{segment}{side}'
            bone(name,joint(src,'head'),joint(src,'tail'),'Hand'+side if segment==1 else f'Finger{finger}_{segment-1}{side}')
    bone('Thigh'+side,joint('upperleg01.'+side,'head'),joint('lowerleg01.'+side,'head'),'Hips')
    bone('Shin'+side,joint('lowerleg01.'+side,'head'),joint('foot.'+side,'head'),'Thigh'+side)
    bone('Foot'+side,joint('foot.'+side,'head'),joint('toe1-1.'+side,'tail'),'Shin'+side)
bpy.ops.object.mode_set(mode='OBJECT')
def remap(name):
    s=name[-1] if name.endswith(('.L','.R')) else ''
    if name.startswith('finger'):
        a,b=name.split('.')[0][6:].split('-');return f'Finger{a}_{b}{s}'
    if name.startswith(('upperarm','lowerarm','wrist','metacarpal')):return ('UpperArm' if name.startswith('upperarm') else 'Forearm' if name.startswith('lowerarm') else 'Hand')+s
    if name.startswith(('clavicle','shoulder')):return 'Clavicle'+s
    if name.startswith('upperleg'):return 'Thigh'+s
    if name.startswith('lowerleg'):return 'Shin'+s
    if name.startswith(('foot','toe')):return 'Foot'+s
    if name in ['root','spine05'] or name.startswith('pelvis'):return 'Hips'
    if name in ['spine04','spine03']:return 'Spine'
    if name in ['spine02','spine01'] or name.startswith('breast'):return 'Chest'
    if name.startswith('neck'):return 'Neck'
    return 'Head'
vw=defaultdict(lambda:defaultdict(float))
for old,entries in weights.items():
    for index,value in entries:vw[index][remap(old)]+=value
kd=KDTree(len(points))
for i,p in enumerate(points):kd.insert(p,i)
kd.balance()
ref_trees={}
def bind(obj,indices=None,fixed=None,reference=None):
    if reference is not None and reference.name not in ref_trees:
        tree=KDTree(len(reference.data.vertices))
        for i,v in enumerate(reference.data.vertices):tree.insert(v.co,i)
        tree.balance();ref_trees[reference.name]=tree
    for name in bone_defs:obj.vertex_groups.new(name=name)
    for i,v in enumerate(obj.data.vertices):
        if fixed:entry={fixed:1}
        elif reference is not None:
            near=reference.data.vertices[ref_trees[reference.name].find(v.co)[1]]
            entry={reference.vertex_groups[g.group].name:g.weight for g in near.groups}
        else:entry=vw[indices[i] if indices is not None else kd.find(v.co)[1]] or {'Hips':1}
        entry=sorted(entry.items(),key=lambda x:-x[1])[:4];total=sum(w for _,w in entry)
        for name,w in entry:obj.vertex_groups[name].add([i],w/total,'REPLACE')
    mod=obj.modifiers.new('Skeletal deformation','ARMATURE');mod.object=rig;obj.parent=rig
def mesh_from_faces(name,faces,material,inflate=0,folds=False,subdiv=1):
    ids=sorted({i for f in faces for i,_ in f});mapping={i:j for j,i in enumerate(ids)}
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([points[i] for i in ids],[],[[mapping[i] for i,_ in f] for f in faces]);mesh.update()
    layer=mesh.uv_layers.new(name='UVMap')
    for poly,f in zip(mesh.polygons,faces):
        poly.use_smooth=True
        for li,(_,uvi) in zip(poly.loop_indices,f):layer.data[li].uv=uv[uvi]
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(material)
    if inflate:
        for v in mesh.vertices:
            p=v.co.copy();noise=0
            if folds:
                elbow=max(math.exp(-((p.x-x)**2+(p.z-z)**2)/.004) for x,z in [(-.32,1.20),(.32,1.20)])
                knee=max(math.exp(-((p.x-x)**2+(p.z-.49)**2)/.008) for x in [-.13,.13])
                waist=math.exp(-((p.z-.98)/.09)**2)
                noise=.004*math.sin(p.z*150+p.x*45+p.y*30)*(elbow+knee+waist*.6)+.0015*math.sin(p.z*65+p.x*30)*math.sin(p.y*40)
            v.co+=v.normal*(inflate+noise)
        mesh.update()
    bind(obj,ids)
    if subdiv:
        mod=obj.modifiers.new('Tailored subdivision','SUBSURF');mod.levels=subdiv;bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_move_up(modifier=mod.name);bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj,ids
skin=mat('Worker skin',(1,1,1),roughness=.63)
bodyfaces=[]
for f in groups['body']:
    c=sum((points[i] for i,_ in f),Vector())/len(f)
    if c.z>1.48 or abs(c.x)>.38 and c.z>1.0:bodyfaces.append(f)
body,body_ids=mesh_from_faces('Skin',bodyfaces,skin,subdiv=0)
colors=body.data.color_attributes.new(name='SkinColour',type='FLOAT_COLOR',domain='CORNER')
def gauss(x,s):return math.exp(-(x/s)**2)
eye_y=joint('eye.L','head').z/SCALE+floor
for loop in body.data.loops:
    p=coords[body_ids[loop.vertex_index]];x,y,z=p.x,p.y,p.z;color=Vector((.52,.32,.225))
    if y>6.6:
        cheeks=gauss(abs(x)-.55,.30)*gauss(y-eye_y+.2,.36)*max(0,min(1,z));color+=Vector((.035,-.012,-.010))*cheeks
        brow=gauss(abs(x)-.36,.24)*gauss(y-eye_y-.27,.07)*max(0,min(1,(z-.85)*3))
        lips=gauss(x,.27)*gauss(y-eye_y+.80,.075)*max(0,min(1,(z-1.0)*4))
        beard=max(0,min(1,(eye_y-.43-y)*3))*gauss(x,.75)*max(0,min(1,(z-.60)*3))
        color=color.lerp(Vector((.12,.078,.05)),brow*.88).lerp(Vector((.38,.16,.135)),lips*.8).lerp(Vector((.27,.24,.21)),beard*.36)
    pore=math.sin(x*147+y*131+z*79)*math.sin(y*271-x*83)*.007;color+=Vector((pore,pore*.75,pore*.60))
    colors.data[loop.index].color=(*color,1)
node=skin.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name=colors.name
skin.node_tree.links.new(node.outputs['Color'],skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
img=bpy.data.images.new('Worker skin atlas',width=2048,height=2048,alpha=False)
texnode=skin.node_tree.nodes.new('ShaderNodeTexImage');texnode.image=img;skin.node_tree.nodes.active=texnode
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1
scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True;scene.render.bake.margin=8
bpy.ops.object.bake(type='DIFFUSE');img.filepath_raw=str(TEX/'worker_skin_atlas.png');img.file_format='PNG';img.save()
skin.node_tree.links.new(texnode.outputs['Color'],skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
body.shape_key_add(name='Basis');blink=body.shape_key_add(name='Blink');delta=defaultdict(lambda:Vector())
for filename in ['eye-left-closure.target','eye-right-closure.target']:
    for line in (SRC/filename).read_text().splitlines():
        if not line or line.startswith('#'):continue
        p=line.split();v=Vector(tuple(map(float,p[1:4])));delta[int(p[0])]+=Vector((-v.x,v.z,v.y))*SCALE
for i,original in enumerate(body_ids):blink.data[i].co+=delta[original]
mod=body.modifiers.new('Face subdivision','SUBSURF');mod.levels=1
# Keep the anatomical hands independently visible when a contact grip is used.
for side,sign in [('L',-1),('R',1)]:
    bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.mode_set(mode='OBJECT')
    for v in body.data.vertices:v.select=v.co.x*sign>.38
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
    for obj in bpy.context.selected_objects:
        if obj!=body:obj.name='HandSkin'+side
body.name='HeadSkin'

for outfit,fabric in [('Work','work'),('Casual','casual')]:
    top=[];bottom=[]
    for f in groups['helper-tights']:
        c=sum((points[i] for i,_ in f),Vector())/len(f)
        if c.z>.95:top.append(f)
        if .14<c.z<1.035:bottom.append(f)
    jacket,_=mesh_from_faces('Torso'+outfit,top,M[fabric],inflate=.016 if outfit=='Work' else .020,folds=True)
    trousers,_=mesh_from_faces('Pelvis'+outfit,bottom,M['cargo' if outfit=='Work' else 'denim'],inflate=.013,folds=True)
    for obj in [jacket,trousers]:
        for item in obj.data.uv_layers.active.data:item.uv*=18

def finish(obj,name,material,bone_name=None,reference=None):
    obj.name=name;obj.data.materials.append(material);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for poly in obj.data.polygons:poly.use_smooth=True
    bind(obj,fixed=bone_name,reference=reference);return obj
def box(name,pos,scale,material,bone_name=None,bevel=.004):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);obj=bpy.context.object;obj.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=obj.modifiers.new('Sewn corners','BEVEL');m.width=bevel;m.segments=3;bpy.ops.object.modifier_apply(modifier=m.name)
    return finish(obj,name,material,bone_name)
def seam(name,path,radius,material,bone_name=None,reference=None):
    bpy.ops.object.select_all(action='DESELECT')
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=1;curve.bevel_depth=radius;curve.bevel_resolution=2
    spline=curve.splines.new('POLY');spline.points.add(len(path)-1)
    for p,v in zip(spline.points,path):p.co=(*v,1)
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj);bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.convert(target='MESH');return finish(bpy.context.object,name,material,bone_name,reference)
work=bpy.data.objects['TorsoWork']
front_tree=BVHTree.FromPolygons([v.co for v in work.data.vertices],[list(p.vertices) for p in work.data.polygons])
def front(x,z,offset=.003):
    hit,_,_,_=front_tree.ray_cast(Vector((x,1,z)),Vector((0,-1,0)))
    return Vector((x,(hit.y if hit else .11)+offset,z))
seam('Jacket zipper',[front(0,1.01+i*.02,.006) for i in range(23)],.0025,M['zip'],reference=work)
for side in [-1,1]:
    x=side*.085;pocket=[front(x-.042,1.31,.006),front(x+.042,1.31,.006),front(x+.042,1.39,.006),front(x-.042,1.39,.006)]
    grid=[front(x-.042+col*.084/6,1.31+row*.08/6,.005) for row in range(7) for col in range(7)]
    mesh=bpy.data.meshes.new('Pocket');mesh.from_pydata(grid,[],[(r*7+c,r*7+c+1,(r+1)*7+c+1,(r+1)*7+c) for r in range(6) for c in range(6)]);mesh.update()
    layer=mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        poly.use_smooth=True
        for li in poly.loop_indices:
            p=mesh.vertices[mesh.loops[li].vertex_index].co;layer.data[li].uv=(p.x*18,p.z*18)
    obj=bpy.data.objects.new('Work pocket '+str(side),mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(M['work']);bind(obj,reference=work)
    seam('Pocket seam '+str(side),pocket+[pocket[0]],.00065,M['thread'],reference=work)
    # Flat sewn tape follows the chest instead of a round rope-shaped strip.
    strip=[]
    for i in range(17):
        x=side*(.012+i*.009)
        strip.extend([front(x,1.267,.006),front(x,1.282,.006)])
    mesh=bpy.data.meshes.new('Reflective tape');mesh.from_pydata(strip,[],[(i*2,i*2+2,i*2+3,i*2+1) for i in range(16)]);mesh.update()
    obj=bpy.data.objects.new('Reflective chest '+str(side),mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(M['trim']);bind(obj,reference=work)

# A folded, double-wall hood with visible edge stitching; independent of trousers.
hood_verts=[];hood_faces=[]
for row in range(6):
    t=row/5
    for i in range(33):
        angle=i*math.pi/32
        outer=Vector((.125*math.cos(angle),-.035-.125*math.sin(angle),1.53-.11*math.sin(angle)))
        inner=Vector((.065*math.cos(angle),-.025-.05*math.sin(angle),1.535-.04*math.sin(angle)))
        p=inner.lerp(outer,t);p.y-=math.sin(t*math.pi)*.015
        hood_verts.append(p)
for row in range(5):
    for i in range(32):
        a=row*33+i;hood_faces.append((a,a+1,a+34,a+33))
mesh=bpy.data.meshes.new('Folded hood');mesh.from_pydata(hood_verts,[],hood_faces);mesh.update()
obj=bpy.data.objects.new('HoodCasual',mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(M['casual']);bind(obj)
for p in mesh.polygons:p.use_smooth=True
for side in [-1,1]:
    seam('DrawstringCasual'+str(side),[front(side*.032,1.48,.007),front(side*.037,1.35,.010)],.0018,M['thread'])

# External cargo pockets follow the thigh surface and bend with its skin weights.
trousers=bpy.data.objects['PelvisWork']
trouser_tree=BVHTree.FromPolygons([v.co for v in trousers.data.vertices],[list(p.vertices) for p in trousers.data.polygons])
for side in [-1,1]:
    verts=[]
    for z in [.67,.81]:
        for y in [-.045,.060]:
            hit,_,_,_=trouser_tree.ray_cast(Vector((side, y,z)),Vector((-side,0,0)))
            verts.append(Vector(((hit.x if hit else side*.19)+side*.005,y,z)))
    mesh=bpy.data.meshes.new('Cargo pocket');mesh.from_pydata(verts,[],[(0,1,3,2)]);mesh.update()
    obj=bpy.data.objects.new('CargoWork'+str(side),mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(M['cargo']);bind(obj)
    seam('CargoWork seam'+str(side),[verts[i] for i in [0,1,3,2,0]],.0009,M['thread'])

hairfaces=[]
for f in groups['body']:
    c=sum((points[i] for i,_ in f),Vector())/len(f)
    if c.z>1.72 or c.z>1.65 and c.y<.012:hairfaces.append(f)
mesh_from_faces('Hair',hairfaces,M['hair'],inflate=.005,subdiv=1)
head_tree=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
for side in [-1,1]:
    path=[]
    for i in range(13):
        t=i/12;x=side*(.019+t*.035);z=1.695+math.sin(t*math.pi)*.003-t*.001
        hit,_,_,_=head_tree.ray_cast(Vector((x,1,z)),Vector((0,-1,0)))
        path.append(Vector((x,(hit.y if hit else .11)+.001,z)))
    seam('Eyebrow'+str(side),path,.00095,M['hair'],'Head')
eye_v,eye_uv,eye_groups=read_obj(SRC/'high-poly.obj');mapping=[];active=False
for line in (SRC/'high-poly.mhclo').read_text().splitlines():
    if line.startswith('verts '):active=True;continue
    if active:
        p=line.split()
        if len(p)<9:break
        try:mapping.append((list(map(int,p[:3])),list(map(float,p[3:6]))))
        except ValueError:break
for i,(ids,ws) in enumerate(mapping):
    # The OBJ is floor-aligned; the base mesh is centred. MHCLO coordinates
    # reconstruct the eyes in the same reference frame as the adult anatomy.
    eye_v[i]=sum((coords[j]*w for j,w in zip(ids,ws)),Vector())
    raw=(SRC/'high-poly.mhclo').read_text().split('verts 0\n',1)[1].splitlines()[i].split()
    eye_v[i]+=Vector(tuple(map(float,raw[6:9])))
faces=[f for fs in eye_groups.values() for f in fs];mesh=bpy.data.meshes.new('Eyes');mesh.from_pydata([xyz(v) for v in eye_v],[],[[i for i,_ in f] for f in faces]);mesh.update();layer=mesh.uv_layers.new(name='UVMap')
for poly,f in zip(mesh.polygons,faces):
    poly.use_smooth=True
    for li,(_,uv_idx) in zip(poly.loop_indices,f):layer.data[li].uv=eye_uv[uv_idx]
eyes=bpy.data.objects.new('Eyes',mesh);bpy.context.collection.objects.link(eyes);mesh.materials.append(M['eyes']);bind(eyes,fixed='Head')
# The stowed torch is clipped into a leather belt pouch, not suspended beside the hip.
box('TorchHolster',(.208,-.002,.985),(.043,.069,.135),M['leather'],'Hips',.006)
box('HolsterClip',(.210,-.043,1.045),(.028,.008,.065),M['zip'],'Hips',.003)
bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,location=(0,-.004,1.755));cap=bpy.context.object;cap.scale=(.096,.108,.039);finish(cap,'Cap',M['work'],'Head')
box('Cap brim',(0,.096,1.742),(.155,.12,.007),M['work'],'Head',.012)
for side,suffix in [(-1,'L'),(1,'R')]:
    x=joint('foot.'+suffix,'head').x
    for outfit,fabric in [('Work','leather'),('Casual','work')]:
        box('Boot'+outfit+suffix,(x,.057,.031),(.112,.266,.041),M['rubber'],'Foot'+suffix,.018)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=20,location=(x,.075,.078));shoe=bpy.context.object;shoe.scale=(.055,.132,.056);finish(shoe,'Shoe'+outfit+suffix,M[fabric],'Foot'+suffix)
        box('Ankle'+outfit+suffix,(x,-.014,.125),(.095,.108,.14),M[fabric],'Foot'+suffix,.028)
        for i in range(5):seam('Lace'+outfit+suffix+str(i),[Vector((x-.022,.12-i*.014,.099+i*.012)),Vector((x+.022,.113-i*.014,.102+i*.012))],.0015,M['thread'],'Foot'+suffix)
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH':continue
    if obj.name.startswith(('Jacket zipper','Work pocket','Pocket seam','Reflective chest')):obj['outfit']='top_work'
    elif 'Casual' in obj.name:obj['outfit']='shoes_casual' if obj.name.startswith(('Boot','Shoe','Ankle','Lace')) else 'top_casual' if obj.name.startswith(('Torso','Hood','Drawstring')) else 'bottom_casual'
    elif obj.name.startswith(('Boot','Shoe','Ankle','Lace')):obj['outfit']='shoes_work'
    elif obj.name=='TorsoWork':obj['outfit']='top_work'
    elif obj.name=='PelvisWork' or obj.name.startswith('CargoWork'):obj['outfit']='bottom_work'
    elif obj.name.startswith('Cap'):obj['outfit']='cap'
metadata={name:{'head':[h.x,h.z,-h.y],'tail':[t.x,t.z,-t.y],'parent':p} for name,(h,t,p) in bone_defs.items()}
(DEST/'worker_rig.json').write_text(json.dumps(metadata,separators=(',',':'))+'\n')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(DEST/'Worker.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True,export_apply=False,export_skins=True,export_morph=True)
print('Exported skinned worker:',len(bone_defs),'bones')

# Bake anatomical contact hands into the camera rig's two grip coordinate frames.
# The body keeps the full skeleton; the close-up hands require no second skeleton.
hand_exports=[]
for suffix in ['L','R']:
    source=bpy.data.objects['HandSkin'+suffix]
    wrist=bone_defs['Hand'+suffix][0]
    long=(sum((bone_defs[f'Finger{f}_1{suffix}'][0] for f in range(2,6)),Vector())/4-wrist).normalized()
    across=(bone_defs[f'Finger2_1{suffix}'][0]-bone_defs[f'Finger5_1{suffix}'][0]).normalized()
    across=(across-long*across.dot(long)).normalized();normal=across.cross(long).normalized()
    for f in range(2,6):
        for segment,angle in enumerate(([62,68,32] if suffix=='R' else [4,10,6]),1):
            name=f'Finger{f}_{segment}{suffix}';pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION'
            axis=arm.bones[name].matrix_local.to_3x3().inverted()@across
            pb.rotation_quaternion=Quaternion(axis,math.radians(angle))
    for mod in source.modifiers:
        if mod.type!='ARMATURE':mod.show_viewport=False
    bpy.context.view_layer.update()
    evaluated=source.evaluated_get(bpy.context.evaluated_depsgraph_get());posed=evaluated.to_mesh()
    thumb_groups={g.index for g in source.vertex_groups if g.name.startswith('Finger1_')}
    thumb_weights=[min(1,sum(g.weight for g in v.groups if g.group in thumb_groups)) for v in source.data.vertices]
    def local_hand(p):
        p=p-wrist;u=p.dot(across);v=p.dot(long);w=p.dot(normal)
        return Vector((u,w,-v)) if suffix=='L' else Vector((-w,-v,-u))
    thumb_base=local_hand(bone_defs['Finger1_1'+suffix][0])
    thumb_tip=local_hand(bone_defs['Finger1_3'+suffix][1])
    wrist_roll=Matrix.Rotation(math.radians(-130),3,'Z')
    thumb_target=Vector((-.034,-.100,-.060))+wrist_roll.inverted()@Vector((0,.039,.015))
    thumb_rotation=(thumb_tip-thumb_base).rotation_difference(thumb_target-thumb_base)
    thumb_scale=(thumb_target-thumb_base).length/(thumb_tip-thumb_base).length
    for thumb_part in [False]:
        faces=[]
        for p in source.data.polygons:
            center=sum((source.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
            if (center-wrist).dot(long)<-.016:continue
            faces.append(p)
        ids=sorted({i for p in faces for i in p.vertices});lookup={old:i for i,old in enumerate(ids)}
        name='RightThumb' if thumb_part else 'RightHand' if suffix=='R' else 'LeftHand'
        verts=[]
        for i in ids:
            q=local_hand(posed.vertices[i].co)
            if suffix=='R':
                warped=thumb_base+thumb_rotation@(q-thumb_base)*thumb_scale
                q=q.lerp(warped,thumb_weights[i])
            verts.append((q.x,-q.z,q.y))
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],[[lookup[i] for i in p.vertices] for p in faces]);mesh.update();layer=mesh.uv_layers.new(name='UVMap')
        for poly,original in zip(mesh.polygons,faces):
            poly.use_smooth=True
            for li,old_li in zip(poly.loop_indices,original.loop_indices):layer.data[li].uv=source.data.uv_layers.active.data[old_li].uv
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(skin);hand_exports.append(obj)
        if suffix=='R':
            obj.shape_key_add(name='Basis');press=obj.shape_key_add(name='SwitchPress')
            delta=wrist_roll.inverted()@Vector((0,-.009,0))
            for i,old in enumerate(ids):press.data[i].co+=Vector((delta.x,-delta.z,delta.y))*thumb_weights[old]
    evaluated.to_mesh_clear()
bpy.ops.object.select_all(action='DESELECT')
for obj in hand_exports:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/player/AnatomicalHands.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_skins=False,export_morph=True)
print('Exported anatomical first-person grips')
