"""Run with Blender: blender -b --python tools/art/build_worker.py.
Creates an original modular character; the exported GLB needs no Blender at runtime.
Coordinates: Blender +Y is the face direction, exported Godot -Z.
"""
import bpy
import math
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets' / 'character'
TEX = DEST / 'textures'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, texture=None, roughness=.8, metal=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metal
    if texture:
        node = mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = bpy.data.images.load(str(TEX / f'{texture}.png'))
        mat.node_tree.links.new(node.outputs['Color'], bsdf.inputs['Base Color'])
        normal_file = TEX / f'{texture}_normal.png'
        if normal_file.exists():
            normal_tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
            normal_tex.image = bpy.data.images.load(str(normal_file))
            normal_tex.image.colorspace_settings.name = 'Non-Color'
            normal = mat.node_tree.nodes.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value = .28
            mat.node_tree.links.new(normal_tex.outputs['Color'], normal.inputs['Color'])
            mat.node_tree.links.new(normal.outputs['Normal'], bsdf.inputs['Normal'])
    return mat

M = {
    'canvas': material('Worn navy canvas', (.15, .23, .26), 'work_canvas'),
    'cargo': material('Graphite work trousers', (.2, .25, .25), 'work_trousers'),
    'hoodie': material('Burgundy cotton', (.4, .16, .18), 'hoodie'),
    'jeans': material('Indigo denim twill', (.2, .3, .4), 'denim'),
    'skin': material('Skin with subtle pores', (.65, .45, .32), 'skin', .64),
    'leather': material('Worn boot leather', (.15, .12, .09), 'leather'),
    'rubber': material('Rubber soles', (.032, .038, .036), roughness=.95),
    'reflective': material('Silver reflective tape', (.59, .64, .61), roughness=.3, metal=.25),
    'amber': material('Amber safety trim', (.68, .36, .08), roughness=.72),
    'zip': material('Brushed brass', (.36, .31, .2), roughness=.45, metal=.8),
    'hair': material('Dark brown hair', (.062, .045, .033), roughness=.95),
    'stubble': material('Jaw stubble', (.25, .18, .13), roughness=.9),
    'eye': material('Eyes', (.78, .76, .67), roughness=.32),
    'iris': material('Brown iris', (.11, .075, .042), roughness=.3),
    'pupil': material('Pupil', (.008, .011, .009), roughness=.22),
    'lip': material('Lips', (.37, .20, .16), roughness=.75),
    'patch': material('Woven operator badge', (.7, .7, .6), 'operator_patch'),
}
root = bpy.data.objects.new('Worker', None)
bpy.context.collection.objects.link(root)
parts = {}

def part(name, pivot):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = pivot
    obj.parent = root
    parts[name] = obj
    bpy.context.view_layer.update()
    return obj

def finish(obj, name, mat, parent):
    obj.name = name
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    bpy.context.view_layer.update()
    matrix = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = matrix
    return obj

def ellipsoid(name, position, scale, mat, parent, segments=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=12, location=position)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent)

def box(name, position, scale, mat, parent, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Soft sewn edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, mat, parent)

def tube(name, start, end, radius, mat, parent, other_radius=None):
    a, b = Vector(start), Vector(end)
    direction = b-a
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=radius, radius2=other_radius or radius, depth=direction.length, location=(a+b)/2)
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
    return finish(obj, name, mat, parent)

def rings(name, ring_list, mat, parent, segments=24):
    vertices, faces = [], []
    # Each row is center_x, center_y, height, width_radius, depth_radius.
    for cx, cy, z, rx, ry in ring_list:
        for j in range(segments):
            angle = j * math.tau / segments
            vertices.append((cx+rx*math.cos(angle), cy+ry*math.sin(angle), z))
    for r in range(len(ring_list)-1):
        for j in range(segments):
            k=(j+1)%segments
            faces.append((r*segments+j,r*segments+k,(r+1)*segments+k,(r+1)*segments+j))
    faces.extend([tuple(reversed(range(segments))),tuple((len(ring_list)-1)*segments+j for j in range(segments))])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name='Fabric UV')
    for poly in mesh.polygons:
        for index in poly.loop_indices:
            vertex = mesh.loops[index].vertex_index
            uv.data[index].uv = ((vertex % segments)/segments*2, (vertex//segments)/max(1,len(ring_list)-1)*2)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent)

# A human head, neck and small facial details, all moving as one part.
head = part('Head', (0, 0, 1.58))
tube('Neck', (0, 0, 1.48), (0, 0, 1.62), .060, M['skin'], head)
ellipsoid('Head skin', (0, 0, 1.687), (.098, .086, .139), M['skin'], head)
ellipsoid('Jaw', (0, .013, 1.615), (.076, .074, .062), M['skin'], head)
for side in [-1,1]:
    ellipsoid('Ear', (side*.100, -.004, 1.685), (.019, .022, .037), M['skin'], head)
    ellipsoid('Eye socket', (side*.039, .076, 1.711), (.028, .010, .017), M['skin'], head)
    ellipsoid('Sclera', (side*.039, .083, 1.709), (.020, .006, .009), M['eye'], head)
    ellipsoid('Iris', (side*.039, .089, 1.709), (.0075, .002, .0075), M['iris'], head)
    ellipsoid('Pupil', (side*.039, .091, 1.709), (.0037, .001, .0047), M['pupil'], head)
    ellipsoid('Eyebrow', (side*.039, .080, 1.730), (.025, .004, .005), M['hair'], head)
ellipsoid('Nose bridge', (0, .082, 1.682), (.014, .021, .035), M['skin'], head)
ellipsoid('Nose tip', (0, .101, 1.663), (.020, .016, .013), M['skin'], head)
for side in [-1,1]:
    ellipsoid('Nostril', (side*.012, .104, 1.655), (.004, .003, .003), M['stubble'], head)
ellipsoid('Lower lip', (0, .080, 1.632), (.026, .004, .005), M['lip'], head)
ellipsoid('Mouth line', (0, .082, 1.637), (.027, .002, .0018), M['stubble'], head)
ellipsoid('Chin stubble', (0, .065, 1.607), (.042, .009, .018), M['stubble'], head)
ellipsoid('Hair cap', (0, -.018, 1.777), (.097, .080, .056), M['hair'], head)
for side in [-1,1]:
    ellipsoid('Hair side', (side*.088, -.02, 1.73), (.012, .052, .045), M['hair'], head)
hat = part('Cap', (0,0,1.58))
ellipsoid('Work cap', (0, -.006, 1.804), (.105,.087,.036), M['canvas'], hat)
ellipsoid('Cap brim', (0,.084,1.785), (.089,.064,.007), M['canvas'], hat)

for outfit, fabric in [('Work','canvas'),('Casual','hoodie')]:
    torso=part('Torso'+outfit,(0,0,1.0))
    rings('Jacket' if outfit=='Work' else 'Sweatshirt',[(0,0,1.00,.162,.105),(0,0,1.08,.174,.111),(0,0,1.28,.205,.115),(0,0,1.43,.225,.118),(0,0,1.49,.177,.092),(0,0,1.53,.070,.062)],M[fabric],torso)
    if outfit=='Work':
        for z in [1.12,1.41]:
            box('Safety tape amber',(0,.114,z),(.388,.009,.033),M['amber'],torso,.002)
            box('Safety tape reflective',(0,.12,z),(.388,.005,.014),M['reflective'],torso,.001)
        box('Zipper',(0,.121,1.29),(.012,.012,.37),M['zip'],torso,.002)
        box('Zip pull',(.006,.133,1.44),(.015,.009,.026),M['zip'],torso,.003)
        for side in [-1,1]:
            box('Chest pocket',(side*.112,.122,1.34),(.105,.012,.105),M['canvas'],torso,.008)
            box('Pocket seam',(side*.112,.130,1.387),(.095,.003,.006),M['zip'],torso,.001)
        # Patch is a real textured UV plane, facing forward.
        mesh=bpy.data.meshes.new('Badge plane')
        mesh.from_pydata([(-.177,.14,1.308),(-.047,.14,1.308),(-.047,.14,1.373),(-.177,.14,1.373)],[],[(0,1,2,3)])
        uv=mesh.uv_layers.new(name='Badge UV')
        for i, coord in enumerate([(0,0),(1,0),(1,1),(0,1)]): uv.data[i].uv=coord
        obj=bpy.data.objects.new('Operator badge',mesh);bpy.context.collection.objects.link(obj)
        finish(obj,'Operator badge',M['patch'],torso)
    else:
        box('Kangaroo pocket',(0,.116,1.13),(.26,.026,.15),M['hoodie'],torso,.02)
        for side in [-1,1]:
            tube('Hood drawstring',(side*.042,.087,1.50),(side*.053,.135,1.31),.003,M['rubber'],torso)
        ellipsoid('Hood folded back',(0,-.086,1.47),(.108,.056,.075),M['hoodie'],torso)

for side, suffix in [(-1,'L'),(1,'R')]:
    x=side*.265
    for outfit,fabric in [('Work','canvas'),('Casual','hoodie')]:
        upper=part('UpperArm'+outfit+suffix,(x,0,1.46))
        rings('Sleeve upper',[(x,0,1.465,.080,.084),(x,0,1.39,.076,.075),(x,0,1.23,.057,.060),(x,0,1.17,.055,.057)],M[fabric],upper)
        forearm=part('Forearm'+outfit+suffix,(x,0,1.17))
        rings('Sleeve forearm',[(x,0,1.17,.055,.057),(x,0,1.07,.053,.056),(x,0,.95,.043,.045),(x,0,.918,.039,.041)],M[fabric],forearm)
        if outfit=='Work':
            rings('Cuff reflective',[(x,0,.98,.044,.047),(x,0,1.00,.045,.048)],M['reflective'],forearm)
    hand=part('Hand'+suffix,(x,0,.915))
    ellipsoid('Palm',(x,.005,.868),(.041,.024,.061),M['skin'],hand)
    for i in range(4):
        fx=x-.028+i*.018
        length=[.053,.066,.062,.048][i]
        tube('Finger proximal',(fx,.010,.841),(fx,.025,.841-length*.55),.009,M['skin'],hand,.008)
        tube('Finger curled',(fx,.025,.841-length*.55),(fx,.043,.841-length*.68),.008,M['skin'],hand,.006)
        ellipsoid('Knuckle',(fx,.025,.839),(.010,.009,.010),M['skin'],hand,12)
    thumb=part('Thumb'+suffix,(x-side*.032,.004,.888))
    tube('Thumb',(x-side*.031,.005,.887),(x-side*.051,.031,.850),.013,M['skin'],thumb,.010)
    ellipsoid('Thumbnail',(x-side*.049,.039,.850),(.008,.003,.010),M['skin'],thumb,12)
    for outfit,fabric in [('Work','cargo'),('Casual','jeans')]:
        hip=parts.get('Pelvis'+outfit) or part('Pelvis'+outfit,(0,0,.92))
        if len(hip.children)==0:
            rings('Waist',[(0,0,.85,.17,.098),(0,0,.94,.175,.10),(0,0,1.01,.164,.10)],M[fabric],hip)
            rings('Belt',[(0,0,.965,.177,.106),(0,0,.998,.174,.105)],M['leather'],hip)
            box('Belt buckle',(0,.113,.982),(.048,.015,.032),M['zip'],hip,.005)
        lx=side*.101
        thigh=part('Thigh'+outfit+suffix,(lx,0,.90))
        rings('Trouser thigh',[(lx,0,.93,.087,.097),(lx,0,.81,.089,.098),(lx,0,.60,.071,.078),(lx,0,.49,.062,.065)],M[fabric],thigh)
        if outfit=='Work':
            box('Cargo side pocket',(lx+side*.075,0,.70),(.028,.112,.16),M[fabric],thigh,.012)
        shin=part('Shin'+outfit+suffix,(lx,0,.49))
        rings('Trouser shin',[(lx,0,.49,.062,.064),(lx,0,.37,.062,.063),(lx,0,.17,.050,.050),(lx,0,.105,.050,.048)],M[fabric],shin)
        if outfit=='Work':
            for z in [.22,.255]:
                rings('Leg reflective tape',[(lx,0,z,.054,.055),(lx,0,z+.014,.054,.055)],M['reflective'],shin)
    for outfit in ['Work','Casual']:
        lx=side*.101
        boot=part('Boot'+outfit+suffix,(lx,0,.12))
        fabric=M['leather'] if outfit=='Work' else M['canvas']
        box('Sole',(lx,.052,.036),(.13,.29,.055),M['rubber'],boot,.022)
        ellipsoid('Toe',(lx,.102,.093),(.067,.112,.059),fabric,boot)
        ellipsoid('Upper boot',(lx,-.006,.132),(.060,.073,.104),fabric,boot)
        for i in range(4):
            z=.095+i*.025
            tube('Boot lace',(lx-.032,.068,z),(lx+.032,.068,z+.01),.0025,M['zip'],boot)

# Export all components with embedded original textures, without animation dependencies.
bpy.ops.object.select_all(action='SELECT')
DEST.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(DEST/'Worker.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
print('Exported original worker:',DEST/'Worker.glb')
