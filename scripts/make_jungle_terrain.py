# Builds the Dino Jungle island in Blender and exports it for Godot.
#   Blender -b -P scripts/make_jungle_terrain.py -- <out_dir>
# Writes <out_dir>/jungle_terrain.glb (vertex-coloured mesh), jungle_heights.bin
# (header: int32 N, float32 size; then N*N float32 heights, row = z, col = x) and
# a .blend copy so the map can be opened and tweaked by hand.
import bpy, bmesh, math, struct, sys, os
from mathutils import noise, Vector

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(out, exist_ok=True)

SIZE = 600.0          # metres, square
N = 201               # vertices per side
HALF = SIZE / 2

VOLCANO = Vector((150.0, -140.0))
LAKE = Vector((-70.0, 60.0))
# River from the volcano's foot to the sea (polyline in x,z).
RIVER = [Vector(p) for p in [(95, -95), (40, -60), (0, -10), (-30, 30), (-70, 60), (-120, 110), (-170, 170), (-260, 250)]]


def fbm(x, y, oct=5):
    s, a, f = 0.0, 1.0, 1.0
    for _ in range(oct):
        s += a * noise.noise(Vector((x * f, y * f, 7.3)))
        a *= 0.5
        f *= 2.03
    return s


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def height(x, z):
    p = Vector((x, z))
    r = p.length / HALF
    # Island: land in the middle, sea floor near the edges, wobbly coastline.
    coast = 0.78 + 0.1 * fbm(x * 0.006, z * 0.006, 3)
    island = 1.0 - smooth(coast - 0.22, coast, r)
    h = -8.0 + island * (12.0 + 10.0 * fbm(x * 0.008, z * 0.008) + 4.0 * fbm(x * 0.03, z * 0.03, 3))
    # Rolling hills in the north-west.
    h += island * 22.0 * math.exp(-((x + 150) ** 2 + (z + 120) ** 2) / (2 * 70.0 ** 2))
    # Volcano: a big cone with a crater on top.
    dv = (p - VOLCANO).length
    cone = 85.0 * math.exp(-(dv / 70.0) ** 1.6)
    crater = 26.0 * math.exp(-(dv / 14.0) ** 2)
    h = max(h, h * 0.4 + cone - crater)
    # Lake: a soft bowl below sea level.
    dl = (p - LAKE).length
    h -= 14.0 * (1.0 - smooth(18.0, 48.0, dl))
    # River channel.
    dr = min(seg_dist(p, RIVER[i], RIVER[i + 1]) for i in range(len(RIVER) - 1))
    if dv > 55:
        h = min(h, h - 9.0 * (1.0 - smooth(3.0, 14.0, dr)) - 0.0)
        if dr < 5.0:
            h = min(h, -1.2)
    return h


def color(x, z, h, slope):
    p = Vector((x, z))
    dv = (p - VOLCANO).length
    v = 0.5 + 0.5 * fbm(x * 0.05, z * 0.05, 2)
    sand = (0.86, 0.78, 0.55)
    grass = (0.30 + 0.12 * v, 0.58 + 0.12 * v, 0.18)
    jungle = (0.12 + 0.05 * v, 0.40 + 0.08 * v, 0.12)
    dirt = (0.48, 0.34, 0.20)
    rock = (0.40, 0.36, 0.34)
    lava = (0.85, 0.25, 0.05)

    def mix(a, b, t):
        return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

    c = mix(jungle, grass, smooth(0.35, 0.75, fbm(x * 0.012, z * 0.012, 3) * 0.5 + 0.5))
    c = mix(c, sand, 1.0 - smooth(0.6, 2.4, h))
    if h < -0.5:
        c = mix(sand, (0.55, 0.50, 0.38), smooth(-0.5, -6.0, h))
    c = mix(c, dirt, smooth(0.45, 0.8, slope))
    c = mix(c, rock, smooth(35.0, 55.0, h) * smooth(30, 60, 200 - dv + 30))
    if dv < 16 and h > 40:
        c = mix(c, lava, 1.0 - smooth(6.0, 16.0, dv))
    return c


bpy.ops.wm.read_factory_settings(use_empty=True)
heights = [[height(-HALF + SIZE * i / (N - 1), -HALF + SIZE * j / (N - 1)) for i in range(N)] for j in range(N)]

mesh = bpy.data.meshes.new("JungleTerrain")
bm = bmesh.new()
step = SIZE / (N - 1)
verts = []
for j in range(N):
    for i in range(N):
        x = -HALF + step * i
        z = -HALF + step * j
        # Blender is Z-up: Godot (x, y, z) -> Blender (x, -z, y).
        verts.append(bm.verts.new((x, -z, heights[j][i])))
bm.verts.ensure_lookup_table()
col_layer = bm.loops.layers.color.new("Col")
for j in range(N - 1):
    for i in range(N - 1):
        a, b, c, d = j * N + i, j * N + i + 1, (j + 1) * N + i + 1, (j + 1) * N + i
        f = bm.faces.new((verts[a], verts[d], verts[c], verts[b]))
for v in bm.verts:
    pass
bm.normal_update()
for f in bm.faces:
    for loop in f.loops:
        v = loop.vert
        x, z, h = v.co.x, -v.co.y, v.co.z
        slope = 1.0 - max(0.0, v.normal.z)
        r, g, b = color(x, z, h, slope * 3.0)
        loop[col_layer] = (r, g, b, 1.0)
bm.to_mesh(mesh)
bm.free()
for poly in mesh.polygons:
    poly.use_smooth = True
mesh.color_attributes.active_color_name = "Col"
mesh.color_attributes.render_color_index = 0

obj = bpy.data.objects.new("JungleTerrain", mesh)
bpy.context.scene.collection.objects.link(obj)

mat = bpy.data.materials.new("Ground")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes.get("Principled BSDF")
attr = nt.nodes.new("ShaderNodeVertexColor")
attr.layer_name = "Col"
nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.95
mesh.materials.append(mat)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.path.dirname(__file__), "..", "assets-src", "maps", "jungle_terrain.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "jungle_terrain.glb"), export_format="GLB",
                          export_yup=True, export_vertex_color="NAME", export_vertex_color_name="Col", export_all_vertex_colors=False, export_apply=True)

with open(os.path.join(out, "jungle_heights.bin"), "wb") as fh:
    fh.write(struct.pack("<if", N, SIZE))
    for row in heights:
        fh.write(struct.pack("<%df" % N, *row))
print("TERRAIN OK", min(min(r) for r in heights), max(max(r) for r in heights))
