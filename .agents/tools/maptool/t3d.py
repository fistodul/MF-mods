"""Minimal T3D (UE1 / Mobile Forces) reader and writer.

Reading: actors as raw text blocks plus parsed helpers. Export a map with `mfed.py export`, then
`python t3d.py <dir>/MyLevel.t3d` prints a survey (actor counts, brushes with CSG op and bounds,
static mesh bounds, zones and spawns).
Writing: brush and actor blocks for a T3D that a macro IMPORTADDs into a loaded map (maps.md 10C).
"""
import re, math, sys
from collections import Counter

NUM = r'[-+]?\d+(?:\.\d+)?'

class Actor:
    def __init__(self, cls, name, lines):
        self.cls, self.name, self.lines = cls, name, lines   # lines: full block incl. Begin/End Actor

    def prop(self, key):
        """Top-level property value (outside nested Begin/End blocks)."""
        depth = 0
        for l in self.lines[1:-1]:
            s = l.strip()
            if s.startswith('Begin '): depth += 1; continue
            if s.startswith('End '): depth -= 1; continue
            if depth == 0 and s.startswith(key + '='):
                return s[len(key) + 1:]
        return None

    def vec(self, key, default=(0.0, 0.0, 0.0)):
        v = self.prop(key)
        if v is None: return default
        d = dict(re.findall(r'([XYZ])=(' + NUM + ')', v))
        return tuple(float(d.get(a, 0)) for a in 'XYZ')

    def rot(self):
        v = self.prop('Rotation')
        if v is None: return (0, 0, 0)
        d = dict(re.findall(r'(Pitch|Yaw|Roll)=(' + NUM + ')', v))
        return tuple(int(float(d.get(a, 0))) for a in ('Pitch', 'Yaw', 'Roll'))

    def scale(self, key):
        v = self.prop(key)
        if v is None or 'Scale=' not in v: return (1.0, 1.0, 1.0)
        m = re.search(r'Scale=\(([^)]*)\)', v)
        d = dict(re.findall(r'([XYZ])=(' + NUM + ')', m.group(1)))
        return tuple(float(d.get(a, 1)) for a in 'XYZ')

    def brush_verts(self):
        return [tuple(float(x) for x in re.findall(NUM, l.split('Vertex', 1)[1]))
                for l in self.lines if l.strip().startswith('Vertex ') and ',' in l]

    def mesh_bbox_local(self):
        for l in self.lines:
            if 'BoundingBox.Min.X' in l:
                d = {a + b: float(c) for a, b, c in re.findall(r'BoundingBox\.(Min|Max)\.([XYZ])=(' + NUM + ')', l)}
                return (d['MinX'], d['MinY'], d['MinZ']), (d['MaxX'], d['MaxY'], d['MaxZ'])
        return None

def rotate(v, rot):
    """UE1 rotator (Pitch, Yaw, Roll) applied to a local vector (FCoords order: roll, pitch, yaw)."""
    p, y, r = (a * 2 * math.pi / 65536 for a in rot)
    x0, y0, z0 = v
    # roll about X
    y1 = y0 * math.cos(r) - z0 * math.sin(r); z1 = y0 * math.sin(r) + z0 * math.cos(r); x1 = x0
    # pitch about Y
    x2 = x1 * math.cos(p) - z1 * math.sin(p); z2 = x1 * math.sin(p) + z1 * math.cos(p); y2 = y1
    # yaw about Z
    x3 = x2 * math.cos(y) - y2 * math.sin(y); y3 = x2 * math.sin(y) + y2 * math.cos(y)
    return (x3, y3, z2)

def world_brush_verts(a):
    loc, pre = a.vec('Location'), a.vec('PrePivot')
    ms, ps, rot = a.scale('MainScale'), a.scale('PostScale'), a.rot()
    out = []
    for v in a.brush_verts():
        w = tuple((v[i] - pre[i]) * ms[i] for i in range(3))
        w = rotate(w, rot)
        out.append(tuple(w[i] * ps[i] + loc[i] for i in range(3)))
    return out

def bbox(points):
    if not points: return None
    return tuple(min(p[i] for p in points) for i in range(3)), tuple(max(p[i] for p in points) for i in range(3))

MESHES = {}

def index_meshes(actors):
    for a in actors:
        bb = a.mesh_bbox_local()
        if bb:
            for l in a.lines:
                m = re.match(r'\s*Begin StaticMesh Name=(\w+)', l)
                if m: MESHES[m.group(1)] = bb; break

def mesh_name(a):
    v = a.prop('StaticMesh')
    return v.split('.')[-1].rstrip("'") if v else None

def mesh_world_bbox(a):
    bb = a.mesh_bbox_local() or MESHES.get(mesh_name(a))
    if bb is None: return None
    loc, ds, rot = a.vec('Location'), float(a.prop('DrawScale') or 1), a.rot()
    ds3 = a.vec('DrawScale3D', (1.0, 1.0, 1.0))
    corners = [(x, y, z) for x in (bb[0][0], bb[1][0]) for y in (bb[0][1], bb[1][1]) for z in (bb[0][2], bb[1][2])]
    pts = []
    for c in corners:
        w = rotate(tuple(c[i] * ds * ds3[i] for i in range(3)), rot)
        pts.append(tuple(w[i] + loc[i] for i in range(3)))
    return bbox(pts)

def mesh_world_triangles(a):
    """World-space triangles of a StaticMeshActor whose block embeds its mesh (the mesh's first user)."""
    loc, ds, rot = a.vec('Location'), float(a.prop('DrawScale') or 1), a.rot()
    ds3 = a.vec('DrawScale3D', (1.0, 1.0, 1.0))
    tris, cur = [], []
    for l in a.lines:
        s = l.split()
        if len(s) == 10 and s[0] == 'Vertex':   # Vertex <i> x y z nx ny nz u v
            w = rotate(tuple(float(s[2 + i]) * ds * ds3[i] for i in range(3)), rot)
            cur.append(tuple(w[i] + loc[i] for i in range(3)))
            if len(cur) == 3:
                tris.append(cur)
                cur = []
    return tris

def ground_z(tris, x, y):
    """Highest triangle surface at XY (e.g. terrain height under an actor), or None."""
    best = None
    for a, b, c in tris:
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-9:
            continue
        l1 = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / d
        l2 = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / d
        if min(l1, l2, 1 - l1 - l2) >= -1e-6:
            z = l1 * a[2] + l2 * b[2] + (1 - l1 - l2) * c[2]
            best = z if best is None else max(best, z)
    return best

def read(path):
    text = open(path, encoding='latin-1').read().replace('\r\n', '\n')
    lines = text.split('\n')
    actors, cur, depth = [], None, 0
    for l in lines:
        s = l.strip()
        m = re.match(r'Begin Actor Class=(\w+) Name=(\w+)', s)
        if m and cur is None:
            cur = [l]; depth = 0; info = m.groups(); continue
        if cur is not None:
            cur.append(l)
            if s.startswith('Begin '): depth += 1
            elif s == 'End Actor' and depth == 0:
                actors.append(Actor(info[0], info[1], cur)); cur = None
            elif s.startswith('End '): depth -= 1
    return actors

def fmt(bb):
    return 'min(%.0f, %.0f, %.0f) max(%.0f, %.0f, %.0f)' % (bb[0] + bb[1]) if bb else '-'

# --- writing ---------------------------------------------------------------------------------
PKG = 'MyLevel'                       # the editor loads the edited map into package MyLevel

def vec3(v):
    return ','.join('%+013.6f' % x for x in v)

def polygon(head, normal, u, v, verts):
    """head: extra Begin Polygon attributes, e.g. ' Texture=pueblo_ground_5 Flags=128' (bare
    texture names only). Vertices wind counter-clockwise seen from the side the normal faces."""
    out = ['          Begin Polygon' + head,
           '             Origin   ' + vec3(verts[0]),
           '             Normal   ' + vec3(normal),
           '             TextureU ' + vec3(u),
           '             TextureV ' + vec3(v)]
    out += ['             Vertex   ' + vec3(p) for p in verts]
    out.append('          End Polygon')
    return out

def poly_head(tex, flags=None):
    return (' Texture=%s' % tex if tex else '') + (' Flags=%d' % flags if flags is not None else '')

# Cube faces: normal, TextureU, TextureV, corner signs
CUBE_FACES = [
    ((-1, 0, 0), (0, 1, 0), (0, 0, -1), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)]),
    ((0, 1, 0), (1, 0, 0), (0, 0, -1), [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)]),
    ((1, 0, 0), (0, -1, 0), (0, 0, -1), [(1, 1, -1), (1, 1, 1), (1, -1, 1), (1, -1, -1)]),
    ((0, -1, 0), (-1, 0, 0), (0, 0, -1), [(1, -1, -1), (1, -1, 1), (-1, -1, 1), (-1, -1, -1)]),
    ((0, 0, 1), (1, 0, 0), (0, 1, 0), [(-1, 1, 1), (-1, -1, 1), (1, -1, 1), (1, 1, 1)]),
    ((0, 0, -1), (1, 0, 0), (0, -1, 0), [(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)]),
]

def cube_polys(half, tex_for_face, flags=None):
    """Box around the brush location; tex_for_face(normal) -> texture name or None."""
    return [polygon(poly_head(tex_for_face(n), flags), n, u, v,
                    [tuple(c[i] * half[i] for i in range(3)) for c in corners])
            for n, u, v, corners in CUBE_FACES]

def hexa_polys(corner, tex, flags=None):
    """Any convex six-sided block (e.g. a rotated box): corner(sx, sy, sz) gives the vertex,
    relative to the brush location, for each sign combination of a cube's corners."""
    polys = []
    centre = [sum(corner(*c)[i] for _, _, _, cs in CUBE_FACES for c in cs) / 24 for i in range(3)]
    for _, _, _, signs in CUBE_FACES:
        quad = [corner(*c) for c in signs]
        e1, e2 = [[quad[i][a] - quad[0][a] for a in range(3)] for i in (1, 2)]
        n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
        length = math.sqrt(sum(c * c for c in n))
        n = tuple(c / length for c in n)
        if sum(n[i] * (quad[0][i] - centre[i]) for i in range(3)) < 0:   # face outwards
            quad, n = quad[::-1], tuple(-c for c in n)
        u = (-n[1], n[0], 0) if abs(n[2]) < 0.9 else (1, 0, 0)
        v = (0, 0, -1) if abs(n[2]) < 0.9 else (0, 1, 0)
        polys.append(polygon(poly_head(tex, flags), n, u, v, quad))
    return polys

def prism_polys(sides, r_top, r_bottom, z_bottom, z_top, tex, flags=None):
    """Regular prism or frustum around the brush location's Z axis (z relative to it)."""
    ring = lambda r, z: [(r * math.cos(2 * math.pi * k / sides), r * math.sin(2 * math.pi * k / sides), z)
                         for k in range(sides)]
    top, bottom = ring(r_top, z_top), ring(r_bottom, z_bottom)
    head = poly_head(tex, flags)
    polys = [polygon(head, (0, 0, 1), (1, 0, 0), (0, 1, 0), top),
             polygon(head, (0, 0, -1), (1, 0, 0), (0, -1, 0), bottom[::-1])]
    for k in range(sides):
        j = (k + 1) % sides
        quad = [top[k], bottom[k], bottom[j], top[j]]
        e1, e2 = [[quad[i][a] - quad[0][a] for a in range(3)] for i in (1, 2)]
        n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
        length = math.sqrt(sum(c * c for c in n))
        n = tuple(c / length for c in n)
        if n[0] * quad[0][0] + n[1] * quad[0][1] < 0:     # face outwards
            quad, n = quad[::-1], tuple(-c for c in n)
        polys.append(polygon(head, n, (-n[1], n[0], 0), (0, 0, -1), quad))
    return polys

def box(lo, hi):
    """Centre and half extents of an axis-aligned box."""
    return tuple((lo[i] + hi[i]) / 2 for i in range(3)), tuple((hi[i] - lo[i]) / 2 for i in range(3))

def brush_actor(name, model, csg, loc, polys, polyflags=None):
    lines = ['Begin Actor Class=Brush Name=%s' % name,
             '    CsgOper=%s' % csg,
             '    MainScale=(SheerAxis=SHEER_ZX)',
             '    PostScale=(SheerAxis=SHEER_ZX)']
    if polyflags is not None:
        lines.append('    PolyFlags=%d' % polyflags)
    lines.append('    Location=(X=%f,Y=%f,Z=%f)' % tuple(loc))
    lines += ['    Begin Brush Name=%s' % model, '       Begin PolyList']
    for p in polys:
        lines += p
    return lines + ['       End PolyList', '    End Brush', "    Brush=Model'%s.%s'" % (PKG, model),
                    '    Name=%s' % name, 'End Actor']

def builder_brush(loc, polys):
    """The first brush of an imported T3D replaces the editor's builder brush (never CSG'd)."""
    return brush_actor('Brush0', 'Brush', 'CSG_Active', loc, polys)

def simple_actor(cls, name, props):
    return ['Begin Actor Class=%s Name=%s' % (cls, name)] + ['    ' + p for p in props] + \
           ['    Name=%s' % name, 'End Actor']

# Properties an exported actor carries that must not be imported elsewhere
DROP = re.compile(r'\s*(Level|Region|FootRegion|HeadRegion|Base|Touching\(\d+\)|ZoneMask\(\d+\)|upstreamPaths\(\d+\)|'
                  r'Paths\(\d+\)|PrunedPaths\(\d+\)|visitedWeight|nextNavigationPoint|nextOrdered|prevOrdered|'
                  r'startPath|previousPath|cost|bestPathWeight|TimeSeconds)=')
_renamed = {}

def import_actor(a, offset, newname, prefix='Imp'):
    """Copy of an actor exported from another map, moved by offset and renamed. Its embedded brush
    model or static mesh is renamed prefix + actor + model and referenced from MyLevel."""
    out, depth, has_loc = [], 0, False
    for l in a.lines:
        s = l.strip()
        if s.startswith('Begin Actor'):
            out.append('Begin Actor Class=%s Name=%s' % (a.cls, newname))
            continue
        if s == 'End Actor' and depth == 0:
            if not has_loc:
                out.insert(1, '    Location=(X=%f,Y=%f,Z=%f)' % tuple(offset))
            out.append(l)
            continue
        if s.startswith('Begin '):
            depth += 1
            m = re.match(r'(\s*Begin (?:Brush|StaticMesh) Name=)(\w+)(.*)', l)
            if m:
                _renamed[m.group(2)] = prefix + a.name + m.group(2)
                l = m.group(1) + _renamed[m.group(2)] + m.group(3)
        elif s.startswith('End '):
            depth -= 1
        elif depth == 0:
            if DROP.match(l):
                continue
            key, value = s.split('=', 1) if '=' in s else (s, '')
            if key in ('Location', 'OldLocation', 'ColLocation', 'RealLocation'):
                has_loc |= key == 'Location'
                d = dict(re.findall(r'([XYZ])=(' + NUM + ')', value))
                l = '    %s=(X=%f,Y=%f,Z=%f)' % ((key,) + tuple(float(d.get(c, 0)) + offset[i] for i, c in enumerate('XYZ')))
            elif key == 'Name':
                l = '    Name=%s' % newname
            elif key in ('Brush', 'StaticMesh'):
                cls, obj = re.match(r"(\w+)'[\w-]+\.(\w+)'", value).groups()
                l = "    %s=%s'%s.%s'" % (key, cls, PKG, _renamed[obj])
        out.append(l)
    return out

def write_t3d(path, blocks):
    text = ['Begin Map'] + [l for b in blocks for l in b] + ['End Map', '']
    open(path, 'w', encoding='latin-1', newline='\r\n').write('\n'.join(text))

# --- survey ----------------------------------------------------------------------------------
def zone_number(a):
    m = re.search(r'ZoneNumber=(\d+)', a.prop('Region') or '')
    return int(m.group(1)) if m else None

def survey(path):
    acts = read(path)
    index_meshes(acts)
    print(len(acts), 'actors:', dict(Counter(a.cls for a in acts).most_common()))
    for a in acts:
        if a.cls == 'Brush':
            print('  Brush', a.name, a.prop('CsgOper') or '(builder)', a.prop('PolyFlags') or '',
                  fmt(bbox(world_brush_verts(a))))
        elif a.cls == 'StaticMeshActor':
            print('  Mesh', a.name, mesh_name(a), fmt(mesh_world_bbox(a)))
        elif a.cls.endswith('ZoneInfo') or a.cls.endswith('WaterZone') or a.cls == 'PlayerStart':
            print('  %s %s %s zone %s' % (a.cls, a.name, a.vec('Location'), zone_number(a)))

if __name__ == '__main__':
    survey(sys.argv[1])
