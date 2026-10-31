"""Low-poly planting on mapped green areas and deliberately authored small beds.

The layout is an interpretation for the game, not a survey of individual trees.
Keep mapped roads, paths, doors, paved mosque courts and building footprints clear.
"""
import math, random, json, collections
import numpy as np
from shapely.geometry import Polygon, Point, LineString
from shapely.ops import unary_union, triangulate, polygonize
from shapely import segmentize
from shapely.prepared import prep


def build(g):
    rng = random.Random(4102303)
    land, area = g['LAND'], g['AREA']
    polygons, tags, coords = g['polygons'], g['tags'], g['coords']
    height, chunk, rgb = g['height'], g['chunk'], g['rgb']
    cylinder, surf, bar = g['cylinder'], g['surf'], g['bar']
    buildings = g['BUILDING_AREA']
    roads = unary_union([line.buffer(width/2, join_style=2) for line, width, t in g['roads']])
    # Architecture fills these holes with raised stone courts; preserve them.
    courts = unary_union([Polygon(r) for p, t, wid in g['landmarks'] for r in p.interiors])
    doors = [Point(g['nodes'][n.get('id')]).buffer(5) for n in g['doc'].findall('node')
             if tags(n).get('entrance') not in [None, 'no'] or tags(n).get('barrier') in ['gate', 'lift_gate']]
    transit = []
    for w in g['ways'].values():
        t = tags(w); pts = coords(w)
        if len(pts) < 2: continue
        if t.get('railway') in ['rail', 'tram', 'light_rail'] and t.get('tunnel') != 'yes':
            transit.append(LineString(pts).buffer(3.5))
        if t.get('man_made') in ['pier', 'bridge']:
            transit.append((Polygon(pts) if len(pts)>3 and pts[0]==pts[-1] else LineString(pts)).buffer(4))
    hard = unary_union([courts, *doors, *transit])
    # Extra trunk clearance leaves a usable path even beside a wide crown.
    plantable = land.buffer(-3).difference(unary_union([buildings.buffer(4), roads.buffer(2), hard]))
    groundable = land.buffer(-.5).difference(unary_union([buildings.buffer(1), roads.buffer(.65), hard]))
    can_plant = prep(plantable)
    features = []

    def category(t):
        if t.get('landuse') in ['forest'] or t.get('natural') == 'wood': return 'woodland'
        if t.get('landuse') == 'cemetery' or t.get('amenity') == 'grave_yard': return 'cemetery'
        if t.get('landuse') in ['grass', 'meadow'] or t.get('natural') in ['grassland', 'scrub']: return 'lawn'
        if t.get('leisure') in ['park', 'garden']: return 'park'
        if t.get('landuse') == 'religious': return 'garden_edge'
        return None

    def add_feature(p, t, osm_id):
        kind = category(t)
        if not kind: return
        p = p.buffer(0).intersection(land)
        # Mosque squares and religious sites retain an open paved centre.
        if kind == 'garden_edge' or 'meydan' in t.get('name', '').lower():
            p = p.difference(p.buffer(-5)); kind = 'garden_edge'
        for q in polygons(p.intersection(groundable)):
            if q.area > 8: features.append((q, kind, osm_id))

    for wid, w in g['ways'].items():
        t = tags(w)
        if not category(t): continue
        pts = coords(w)
        if len(pts)>3 and pts[0]==pts[-1]: add_feature(Polygon(pts), t, 'way/'+wid)
    for rel in g['doc'].findall('relation'):
        t = tags(rel)
        if not category(t): continue
        outer, inner = [], []
        for member in rel.findall('member'):
            w = g['ways'].get(member.get('ref'))
            if member.get('type')!='way' or w is None: continue
            pts = coords(w)
            if len(pts)>1: (inner if member.get('role')=='inner' else outer).append(LineString(pts))
        shells = unary_union(list(polygonize(unary_union(outer))))
        holes = unary_union(list(polygonize(unary_union(inner))))
        for p in polygons(shells.difference(holes)): add_feature(p, t, 'relation/'+rel.get('id'))

    records, shrubs, beds = [], [], []
    occupied = collections.defaultdict(list)
    def spaced(x, y, radius):
        gx, gy = math.floor(x/8), math.floor(y/8)
        for ix in range(gx-2, gx+3):
            for iy in range(gy-2, gy+3):
                for px, py, pr in occupied[(ix, iy)]:
                    if math.hypot(px-x, py-y) < radius+pr+.6: return False
        return True

    def crown(m, x, y, z, rx, ry, rz, color):
        # Four faceted rings give a leafy silhouette without alpha textures.
        rings = [(-.9,.34), (-.42,.85), (.2,1), (.72,.63), (1,.08)]
        phase = rng.random()*math.tau
        for (h0,r0),(h1,r1) in zip(rings,rings[1:]):
            for k in range(9):
                a = phase+k*math.tau/9; b = phase+(k+1)*math.tau/9
                pts=[(x+rx*r*math.cos(u),y+ry*r*math.sin(u),z+rz*h) for h,r,u in [(h0,r0,a),(h0,r0,b),(h1,r1,b),(h1,r1,a)]]
                m.face(pts, color)

    def tree(x, y, source, preferred=None):
        pt = Point(x,y)
        if not can_plant.contains(pt): return False
        variant = preferred or rng.choices(['broadleaf','cypress','small'],[.70,.14,.16])[0]
        radius = rng.uniform(2.6,3.7) if variant=='broadleaf' else rng.uniform(1.0,1.6) if variant=='cypress' else rng.uniform(1.8,2.5)
        if not spaced(x,y,radius): return False
        # Crowns also stay clear of walls, even when using larger trees.
        if buildings.distance(pt)<radius+.7: return False
        z=height(x,y); m=chunk('Trees',x,y); trunk=chunk('TreeTrunks',x,y,True)
        h=rng.uniform(7.5,11.5) if variant=='broadleaf' else rng.uniform(9,14) if variant=='cypress' else rng.uniform(5,7)
        cylinder(trunk,(x,y,z),.18 if variant=='small' else .27,h*.56,rgb('705840'),8,r2=.11)
        if variant=='cypress':
            for k in range(3): cylinder(m,(x,y,z+h*(.22+k*.2)),radius*(1-k*.19),h*.40,rgb(['385E3E','416B43','4B7447'][k]),9,r2=.07)
        else:
            base=rgb(rng.choice(['487446','557F48','648C4F','709653','4D7A48']))
            crown(m,x,y,z+h*.67,radius,radius*.9,h*.32,base)
            for a in [rng.random()*math.tau, rng.random()*math.tau]:
                dx=math.cos(a)*radius*.55;dy=math.sin(a)*radius*.55
                bar(m,(x,y,z+h*.34),(x+dx,y+dy,z+h*.65),.10,rgb('705840'))
                crown(m,x+dx,y+dy,z+h*.58,radius*.61,radius*.64,h*.24,rgb(rng.choice(['5F884B','709450','557E43'])))
        occupied[(math.floor(x/8),math.floor(y/8))].append((x,y,radius))
        records.append({'east':round(x,3),'north':round(y,3),'ground_m':round(z,3),'type':variant,'source':source,'height_m':round(h,2),'crown_radius_m':round(radius,2)})
        return True

    # Retain mapped trees when the game geometry has enough clearance.
    for n in g['doc'].findall('node'):
        if tags(n).get('natural')=='tree': tree(*g['nodes'][n.get('id')], 'OSM tree')
    for p, kind, osm_id in sorted(features, key=lambda a:a[0].area, reverse=True):
        candidate=p.intersection(plantable)
        if candidate.is_empty: continue
        minx,miny,maxx,maxy=candidate.bounds
        target=max(1,int(candidate.area/55))
        accepted=0
        for _ in range(min(24000,target*16)):
            if accepted>=target: break
            x,y=rng.uniform(minx,maxx),rng.uniform(miny,maxy)
            if not candidate.contains(Point(x,y)): continue
            preferred='cypress' if kind=='cemetery' and rng.random()<.65 else None
            accepted+=tree(x,y,'mapped '+kind,preferred)

    # Add discrete beds behind the clear quay strip, not a continuous green wall.
    for coast in g['coasts']:
        for line in getattr(coast,'geoms',[coast]):
            if line.geom_type!='LineString': continue
            for d in np.arange(15,line.length-5,18):
                p=line.interpolate(d);q=line.interpolate(min(d+1,line.length));dx=q.x-p.x;dy=q.y-p.y;ln=math.hypot(dx,dy)
                if ln<.001: continue
                for side in [-1,1]:
                    x=p.x-dy/ln*side*15; y=p.y+dx/ln*side*15
                    if tree(x,y,'authored waterfront','broadleaf'):
                        bed=Point(x,y).buffer(4.2,quad_segs=8).intersection(groundable)
                        beds.extend(polygons(bed)); break

    # Only broad streets with a genuinely empty verge receive street trees.
    for line,width,t in g['roads']:
        if width<8 or line.geom_type!='LineString': continue
        for d in np.arange(12,line.length-6,25):
            p=line.interpolate(d);q=line.interpolate(min(d+1,line.length));dx=q.x-p.x;dy=q.y-p.y;ln=math.hypot(dx,dy)
            if ln<.001: continue
            for side in [-1,1]:
                off=width/2+5
                x=p.x-dy/ln*side*off; y=p.y+dx/ln*side*off
                if tree(x,y,'authored street verge','small'):
                    beds.extend(polygons(Point(x,y).buffer(1.7,quad_segs=8).intersection(groundable)))

    green=unary_union([p for p,k,i in features]+beds)
    # Clip to the actual terrain triangles, preserving their planes exactly.
    # Triangulating only a lawn's boundary can bury its interior under a hill.
    green_prepared=prep(green)
    ground_meshes=[m for name,m in g['M'].items() if name.startswith('Ground')]
    for m in ground_meshes:
        for i in range(0,len(m.f),3):
            pts=np.asarray([m.v[k] for k in m.f[i:i+3]],dtype=float)
            normal=np.cross(pts[1]-pts[0],pts[2]-pts[0])
            if abs(normal[2])<1e-8: continue
            tri=Polygon(pts[:,:2])
            if not green_prepared.intersects(tri): continue
            origin=pts[0].copy()
            def on_terrain(px,py):
                return origin[2]-(normal[0]*(px-origin[0])+normal[1]*(py-origin[1]))/normal[2]+.10
            for q in polygons(tri.intersection(green)):
                x,y=q.centroid.coords[0]
                surf(chunk('Gardens',x,y),q,rgb('709453'),on_terrain)
    for p in polygons(green):
        # Sparse rounded shrub groups around lawn edges; paths stay clear.
        edge=LineString(p.exterior.coords)
        for d in np.arange(4,edge.length,10):
            if rng.random()>.50: continue
            pt=edge.interpolate(d);x,y=pt.x,pt.y
            if not can_plant.contains(pt) or not spaced(x,y,1): continue
            for dx,dy in [(-.6,0),(.4,.35),(0,-.4)]:
                xx,yy=x+dx,y+dy
                if not can_plant.contains(Point(xx,yy)): continue
                zz=height(xx,yy)
                crown(chunk('Shrubs',xx,yy),xx,yy,zz+.65,.9,.85,.65,rgb(rng.choice(['4C7841','638A48','779449'])))
                shrubs.append([round(xx,3),round(yy,3)])
    # Explicit audit against the imported street/footprint geometry.
    points=[Point(r['east'],r['north']) for r in records]
    summary={'trees':len(records),'shrubs':len(shrubs),'green_area_m2':round(green.area),
             'tree_types':dict(collections.Counter(r['type'] for r in records)),
             'tree_sources':dict(collections.Counter(r['source'] for r in records)),
             'minimum_building_clearance_m':round(min(buildings.distance(p) for p in points),3),
             'minimum_road_path_clearance_m':round(min(roads.distance(p) for p in points),3),
             'all_tree_centres_on_land':all(land.contains(p) for p in points),
             'trees_in_paved_mosque_courts':sum(courts.contains(p) for p in points)}
    assert summary['minimum_building_clearance_m']>=3.99
    assert summary['minimum_road_path_clearance_m']>=1.99
    assert summary['all_tree_centres_on_land'] and summary['trees_in_paved_mosque_courts']==0
    (g['ROOT']/'source/vegetation.json').write_text(json.dumps({'summary':summary,'trees':records,'shrub_centres':shrubs},ensure_ascii=False,indent=2))
    print('VEGETATION',json.dumps(summary),flush=True)
    return summary
