# Decimate a heavy CC0 model for mobile and shrink its textures.
#   Blender -b --factory-startup -P scripts/slim_model.py -- <in.glb> <out.glb> <target_tris> [tex_size]
import bpy, sys, os
a = sys.argv[sys.argv.index("--") + 1:]
src, out, target = a[0], a[1], int(a[2])
tex = int(a[3]) if len(a) > 3 else 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
total = sum(len(o.data.polygons) for o in meshes)
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
ratio = min(1.0, target / max(tris, 1))
for o in meshes:
    if ratio < 1.0:
        m = o.modifiers.new("dec", 'DECIMATE')
        m.ratio = ratio
        m.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
for img in bpy.data.images:
    if img.size[0] > tex or img.size[1] > tex:
        img.scale(min(tex, img.size[0]), min(tex, img.size[1]))
        img.pack()
after = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=85)
print("SLIM", os.path.basename(src), tris, "->", after, "images", [(i.name, i.size[:]) for i in bpy.data.images])
