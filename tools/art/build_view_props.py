"""Original close-up hands and bevelled cartons. Run in Blender; runtime uses GLB."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets' / 'player'
DEST.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def xyz(p):
    # Write geometry in Godot coordinates, export via Blender's Z-up conversion.
    return (p[0], -p[2], p[1])

def mat(name, color, texture=None, roughness=.7):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bsdf=m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(*color,1)
    bsdf.inputs['Roughness'].default_value=roughness
    if texture:
        node=m.node_tree.nodes.new('ShaderNodeTexImage')
        node.image=bpy.data.images.load(str(texture))
        m.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
    return m

skin=mat('Natural skin',(.64,.43,.31),ROOT/'assets/character/textures/skin.png',.62)
nails=mat('Natural fingernails',(.64,.48,.40),roughness=.47)

def empty(name):
    node=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(node)
    return node

def sphere(name, pos, scale, material, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=xyz(pos))
    obj=bpy.context.object;obj.name=name
    obj.scale=(scale[0],scale[2],scale[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(material)
    for poly in obj.data.polygons:poly.use_smooth=True
    if parent:obj.parent=parent
    return obj

def bone(a,b,r1,r2,material):
    av,bv=Vector(xyz(a)),Vector(xyz(b))
    delta=bv-av
    bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=r1,radius2=r2,depth=delta.length,location=(av+bv)/2)
    obj=bpy.context.object
    obj.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    obj.data.materials.append(material)
    return obj

def sculpt(name, objects, parent):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object;obj.name=name
    # Unite palm, knuckles and phalanges into continuous skin rather than separate tubes.
    remesh=obj.modifiers.new('Continuous skin','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.0022
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=obj.modifiers.new('Skin smoothing','SMOOTH');smooth.factor=.35;smooth.iterations=3
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    for poly in obj.data.polygons:poly.use_smooth=True
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(island_margin=.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.parent=parent
    return obj

left=empty('LeftHand')
pieces=[sphere('Palm',(0,-.004,-.047),(.036,.014,.049),skin),
        sphere('Wrist',(0,0,-.009),(.025,.014,.023),skin)]
for i in range(4):
    x=-.026+i*.017
    length=[.045,.057,.053,.039][i]
    points=[(x,-.003,-.078),(x,.000,-.078-length*.48),(x,.002,-.078-length)]
    pieces.extend([bone(points[0],points[1],.0085,.0075,skin),bone(points[1],points[2],.0075,.006,skin)])
    pieces.append(sphere('Knuckle',points[0],(.009,.010,.012),skin))
    sphere('Nail',(x,.007,points[2][2]+.007),(.0055,.0015,.008),nails,left)
thumb_points=[(-.027,0,-.035),(-.053,.007,-.057),(-.078,.018,-.074)]
pieces.extend([bone(thumb_points[0],thumb_points[1],.013,.011,skin),bone(thumb_points[1],thumb_points[2],.011,.008,skin)])
pieces.append(sphere('Thumb base',(-.028,-.002,-.032),(.016,.014,.026),skin))
sculpt('Continuous left hand',pieces,left)
sphere('Thumb nail',(-.075,.024,-.071),(.007,.0015,.008),nails,left)

right=empty('RightHand')
pieces=[sphere('Palm',(0,-.044,-.024),(.018,.043,.039),skin),
        sphere('Wrist',(0,-.008,-.005),(.024,.021,.023),skin)]
for i in range(4):
    z=-.065+i*.019
    points=[(-.002,-.062,z),(-.010,-.092,z),(-.031,-.107,z),(-.053,-.098,z)]
    pieces.extend([bone(points[j],points[j+1],[.009,.008,.007][j],[.008,.007,.006][j],skin) for j in range(3)])
    pieces.append(sphere('Knuckle',points[0],(.011,.012,.010),skin))
    sphere('Nail',(-.051,-.099,z),(.002,.007,.006),nails,right)
sculpt('Continuous right grip',pieces,right)
thumb=empty('RightThumb')
thumb_parts=[sphere('Thumb base',(-.015,-.019,-.026),(.015,.014,.021),skin),
    bone((-.014,-.020,-.026),(-.024,-.021,-.043),.012,.010,skin),
    bone((-.024,-.021,-.043),(-.034,-.023,-.057),.010,.008,skin)]
sculpt('Switch thumb',thumb_parts,thumb)
sphere('Thumb nail',(-.031,-.016,-.054),(.007,.0015,.008),nails,thumb)

# Selected export keeps the hands asset independent of props.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(DEST/'ViewHands.glb'),export_format='GLB',export_yup=True,export_animations=False)

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
cardboard=mat('Corrugated cardboard',(.54,.40,.25),roughness=.92)
product=mat('Coated product carton',(.19,.34,.31),roughness=.85)
tape=mat('Paper packing tape',(.66,.56,.39),roughness=.8)
ink=mat('Printed label',(.12,.15,.14),roughness=.92)

def cube(name,pos,size,material,parent,bevel=.002):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(pos))
    obj=bpy.context.object;obj.name=name
    obj.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=obj.modifiers.new('Worn folded edges','BEVEL');mod.width=bevel;mod.segments=3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(material);obj.parent=parent
    # Faces stay flat; curved edge normals are averaged.
    mod=obj.modifiers.new('Weighted carton normals','WEIGHTED_NORMAL')
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

for name,material in [('RawBox',cardboard),('ProductBox',product)]:
    root=empty(name)
    cube('Carton',(0,0,0),(.32,.26,.30),material,root,.004)
    cube('Top tape',(0,.131,0),(.043,.002,.30),tape,root,.0005)
    for z in [-.151,.151]:
        cube('Tape folded over edge',(0,.092,z),(.043,.072,.001),tape,root,.0005)
        cube('Box seam',(0,0,z),(.001,.26,.001),ink,root,.0002)
    # Printed handling marks and a barcode on the side nearest the operator.
    cube('Label',(0,-.008,.152),(.19,.095,.001),tape,root,.001)
    for i in range(22):
        cube('Barcode',(-.073+i*.0068,-.010,.153),(.0014 if i%3 else .003,.044,.0005),ink,root,.0001)
    for x in [-.12,.12]:
        cube('Handling arrow',(x,.035,.152),(.007,.042,.001),ink,root,.0001)
        cube('Arrow head',(x,.055,.152),(.021,.007,.001),ink,root,.0001)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(DEST/'Cartons.glb'),export_format='GLB',export_yup=True,export_animations=False)
print('Exported original view hands and cartons to',DEST)
