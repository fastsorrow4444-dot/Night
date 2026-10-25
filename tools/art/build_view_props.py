"""Bevelled cartons. Blender authoring only; anatomical hands use build_realistic_worker.py."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'assets'/'player'
DEST.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
def xyz(p):return (p[0],-p[2],p[1])
def empty(name):
    obj=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(obj);return obj
def mat(name,color,roughness=.7):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=roughness
    return m
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
print('Exported cartons to',DEST)
