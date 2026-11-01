"""Deterministic Istanbul environment from the bundled OpenStreetMap extract.
Python 3.11+; pip install -r requirements.txt (pinned versions)
Run from anywhere: python build_map.py [--source DIR] [--out DIR] [--detail-cell METRES]
Inputs are only read from --source (default: maps/istanbul_halic/source);
every output goes to --out (default: build/maps/istanbul_halic, ignored by Git).
--detail-cell groups facade detail, tree crowns, and shrubs into smaller cells
inside each 150 m chunk (by object centre; no geometry changes); off by default.
Coordinates inside this generator: east, north, up, in metres.
Export: glTF/Godot +X east, +Y up, -Z north. Origin 28.975 E, 41.023 N.
"""
from pathlib import Path
import argparse, json, math, struct, random, re, collections, xml.etree.ElementTree as ET
import numpy as np
import mapbox_earcut
from shapely.geometry import Polygon, LineString, Point, box, MultiPolygon
from shapely.geometry.polygon import orient
from shapely.ops import unary_union, polygonize, triangulate
from shapely import segmentize
from terrain import Elevation

REPO = Path(__file__).resolve().parents[3]
cli = argparse.ArgumentParser(description='Generate the Istanbul Halic map GLB and its JSON records.')
cli.add_argument('--source', type=Path, default=REPO/'maps/istanbul_halic/source', help='input folder, only read (default: %(default)s)')
cli.add_argument('--out', type=Path, default=REPO/'build/maps/istanbul_halic', help='output folder, created if missing (default: %(default)s)')
cli.add_argument('--detail-cell', type=float, metavar='METRES', help='mesh Detail_*, Trees_*, and Shrubs_* per cell of this size inside each 150 m chunk, '
                 'named <Category>_<cx>_<cy>_<i>_<j>; each building, tree, or shrub goes whole into the cell of its centre (default: off, one mesh per chunk)')
opts = cli.parse_args()
SOURCE = opts.source.resolve(); OUT = opts.out.resolve(); CELL = opts.detail_cell
if OUT == SOURCE or SOURCE in OUT.parents: cli.error('--out must not be inside --source')
if CELL is not None and not 0 < CELL < 150: cli.error('--detail-cell must be more than 0 and less than 150 metres')
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(41023)
SX = 111320 * math.cos(math.radians(41.023)); SY = 111320
BBOX = [28.952,41.013,28.984,41.037]
BOUNDS = ((BBOX[0]-28.975)*SX,(BBOX[1]-41.023)*SY,(BBOX[2]-28.975)*SX,(BBOX[3]-41.023)*SY)
AREA = box(*BOUNDS)
def ll(lon,lat): return ((lon-28.975)*SX,(lat-41.023)*SY)
def tags(n): return {t.get('k'):t.get('v') for t in n.findall('tag')}
doc=ET.parse(SOURCE/'istanbul_extended_v4.osm').getroot()
nodes={n.get('id'):ll(float(n.get('lon')),float(n.get('lat'))) for n in doc.findall('node')}
ways={w.get('id'):w for w in doc.findall('way')}
def coords(w): return [nodes[n.get('ref')] for n in w.findall('nd') if n.get('ref') in nodes]
coasts=[LineString(coords(w)).intersection(AREA) for w in ways.values() if tags(w).get('natural')=='coastline']
parts=list(polygonize(unary_union([AREA.boundary]+coasts)))
land=[p for p in parts if p.contains(Point(ll(28.97417,41.0256))) or p.contains(Point(ll(28.971,41.017)))]
LAND=unary_union(land); COAST=unary_union(coasts)
DEM=Elevation(SOURCE/'elevation')
# Use an 8 metre game mesh over the coarser source DEM. Waterfront elevations
# are corrected to a 1.5 m quay to avoid DEM/coastline mismatches.
GRID_STEP=8
GX=np.arange(BOUNDS[0],BOUNDS[2]+GRID_STEP,GRID_STEP)
GY=np.arange(BOUNDS[1],BOUNDS[3]+GRID_STEP,GRID_STEP)
HG=np.zeros((len(GY),len(GX)),dtype=np.float32)
print('Sampling real DEM relief',flush=True)
for iy,y in enumerate(GY):
 for ix,x in enumerate(GX):
    raw=DEM.sample(x/SX+28.975,y/SY+41.023)
    d=COAST.distance(Point(x,y));weight=min(1,max(0,(d-10)/45));weight=weight*weight*(3-2*weight)
    HG[iy,ix]=1.5+(max(1.5,raw)-1.5)*weight
def height(x,y):
    u=max(0,min(len(GX)-1.001,(x-GX[0])/GRID_STEP));v=max(0,min(len(GY)-1.001,(y-GY[0])/GRID_STEP))
    ix,iy=int(u),int(v);u-=ix;v-=iy
    return float((1-v)*((1-u)*HG[iy,ix]+u*HG[iy,ix+1])+v*((1-u)*HG[iy+1,ix]+u*HG[iy+1,ix+1]))
def polygons(g):
    if g.is_empty:return []
    if g.geom_type=='Polygon':return [g]
    return [p for p in getattr(g,'geoms',[]) if p.geom_type=='Polygon']
def triangles(p):
    p=orient(p,1); rings=[list(p.exterior.coords)[:-1]]+[list(r.coords)[:-1] for r in p.interiors]
    v=np.array([xy for r in rings for xy in r],dtype=np.float64)
    if len(v)<3:return []
    ix=mapbox_earcut.triangulate_float64(v,np.cumsum([len(r) for r in rings],dtype=np.uint32))
    return [[v[k] for k in ix[i:i+3]] for i in range(0,len(ix),3)]
def rgb(s):return tuple(int(s[i:i+2],16) for i in (0,2,4))+(255,)
PALETTE=list(map(rgb,['D6C7A9','DDCDB6','C4B7A4','C5B6A0','D7BD9E','C7C4B7','BBA991','D6D0C1','C1ABA0','BFBFAA','C8B298','ADB7AD','C4AB91','C1A393']))
ROOFS=list(map(rgb,['A66049','B07457','965442','B57D61','835E50','777D7D']))
STONE=rgb('C8BEA3'); LIGHT=rgb('E0D6BA'); DARK=rgb('3A5057'); METAL=rgb('526970'); GOLD=rgb('C7A555')

class Mesh:
    def __init__(self):self.v=[];self.n=[];self.c=[];self.f=[]
    def face(self,pts,color):
        if len(pts)<3:return
        a,b,c=np.array(pts[:3],dtype=float);n=np.cross(b-a,c-a);l=np.linalg.norm(n)
        if l<1e-8:return
        n/=l;start=len(self.v)
        self.v.extend(pts);self.n.extend([n]*len(pts));self.c.extend([color]*len(pts))
        for k in range(1,len(pts)-1):self.f.extend([start,start+k,start+k+1])
M={}
def mesh(name):
    if name not in M:M[name]=Mesh()
    return M[name]
# --detail-cell: these categories (never their -col meshes) get one mesh per cell inside the chunk.
CELLED={'Detail','Trees','Shrubs'}
def cell(offset):return min(max(math.floor(offset/CELL),0),math.ceil(150/CELL)-1)
def chunk(cat,x,y,solid=False):
    cx=math.floor((x-BOUNDS[0])/150);cy=math.floor((y-BOUNDS[1])/150);name=f'{cat}_{cx:02}_{cy:02}'
    if CELL and cat in CELLED and not solid:name+=f'_{cell(x-BOUNDS[0]-cx*150)}_{cell(y-BOUNDS[1]-cy*150)}'
    return mesh(name+('-col' if solid else ''))
def surf(m,p,color,z):
    for tri in triangles(p):m.face([(x,y,z(x,y) if callable(z) else z) for x,y in tri],color)
def extrude(m,p,z0,z1,color,cap=True):
    p=orient(p,1)
    for ring in [p.exterior,*p.interiors]:
        v=list(ring.coords)
        for a,b in zip(v,v[1:]):m.face([(*a,z0),(*b,z0),(*b,z1),(*a,z1)],color)
    if cap:surf(m,p,color,z1)
def cube(m,c,s,col,angle=0):
    x,y,z=c; a,b,h=(v/2 for v in s);cs=math.cos(angle);sn=math.sin(angle)
    p=Polygon([(x+dx*cs-dy*sn,y+dx*sn+dy*cs) for dx,dy in [(-a,-b),(a,-b),(a,b),(-a,b)]])
    extrude(m,p,z-h,z+h,col)
def cylinder(m,c,r,h,col,n=16,r2=None):
    x,y,z=c;r2=r if r2 is None else r2
    bot=[(x+r*math.cos(a*math.tau/n),y+r*math.sin(a*math.tau/n),z) for a in range(n)]
    top=[(x+r2*math.cos(a*math.tau/n),y+r2*math.sin(a*math.tau/n),z+h) for a in range(n)]
    for i in range(n):j=(i+1)%n;m.face([bot[i],bot[j],top[j],top[i]],col)
    if r2>0:m.face(top,col)
def dome(m,c,r,col,levels=7,n=24):
    x,y,z=c
    for j in range(levels):
        t0=j*math.pi/(2*levels);t1=(j+1)*math.pi/(2*levels)
        for k in range(n):
            a=k*math.tau/n;b=(k+1)*math.tau/n
            p=[(x+r*math.cos(t)*math.cos(u),y+r*math.cos(t)*math.sin(u),z+r*math.sin(t)) for t,u in [(t0,a),(t0,b),(t1,b),(t1,a)]]
            m.face(p,col)
def bar(m,a,b,r,col):
    a=np.array(a);b=np.array(b);d=b-a;d/=np.linalg.norm(d)
    up=np.array([0.,0.,1.]);u=np.cross(d,up)
    if np.linalg.norm(u)<.01:u=np.array([1.,0.,0.])
    u=u/np.linalg.norm(u)*r;v=np.cross(d,u)
    rings=[[p+u*math.cos(i*math.tau/6)+v*math.sin(i*math.tau/6) for i in range(6)] for p in [a,b]]
    for i in range(6):j=(i+1)%6;m.face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]],col)

print('Building terrain',flush=True)
for x in GX[:-1]:
 for y in GY[:-1]:
    for p in polygons(box(x,y,min(x+GRID_STEP,BOUNDS[2]),min(y+GRID_STEP,BOUNDS[3])).intersection(LAND)):
        co=rgb(RNG.choice(['B4B09A','B7B29D','B8B39F']))
        surf(chunk('Ground',x,y,True),p,co,height)
# Coast revetments and cut edges, the visible perimeter belongs to the model.
for p in land:
 for a,b in zip(list(p.exterior.coords),list(p.exterior.coords)[1:]):
    m=chunk('Ground',*a,True)
    m.face([(*a,-14),(*b,-14),(*b,height(*b)),(*a,height(*a))],rgb('9E9C8A'))
surf(mesh('Water'),AREA,rgb('337E89'),0)

def is_mosque(t):
    return t.get('building')=='mosque' or (t.get('amenity')=='place_of_worship' and t.get('religion')=='muslim')
buildings=[];used=set();landmarks=[]
for rel in doc.findall('relation'):
 t=tags(rel);t['_osm_type']='relation'
 if 'building' not in t and not is_mosque(t):continue
 outer=[];inner=[]
 for member in rel.findall('member'):
    if member.get('type')!='way' or member.get('ref') not in ways:continue
    w=ways[member.get('ref')];p=coords(w)
    if len(p)>3 and p[0]==p[-1]:
        (inner if member.get('role')=='inner' else outer).append(p);used.add(w.get('id'))
 for outerring in outer:
    try:
        p=Polygon(outerring,[r for r in inner if Polygon(outerring).contains(Point(r[0]))]).buffer(0)
        for q in polygons(p.intersection(AREA)): buildings.append((q,t,rel.get('id')))
    except Exception:pass
for wid,w in ways.items():
 t=tags(w);t['_osm_type']='way'
 if wid in used or ('building' not in t and not is_mosque(t)):continue
 p=coords(w)
 if len(p)<4 or p[0]!=p[-1]:continue
 try:
    for q in polygons(Polygon(p).buffer(0).intersection(AREA)):
        if q.area>6:buildings.append((q,t,wid))
 except Exception:pass
BUILDING_AREA=unary_union([p for p,t,i in buildings])

# Quay surfaces remain clear; planted surfaces are generated after roads.
print('Adding quay surfaces',flush=True)
for p in polygons(COAST.buffer(7).intersection(LAND).difference(BUILDING_AREA)):
 for tri in triangulate(segmentize(p,6)):
    if p.covers(tri.representative_point()):
        cx,cy=tri.centroid.coords[0];surf(chunk('Quays',cx,cy),tri,rgb('C5C1AD'),lambda x,y:height(x,y)+.14)

print('Building streets',flush=True)
widths={'trunk':14,'trunk_link':7,'primary_link':7,'secondary_link':6.5,'tertiary_link':5.5,'cycleway':2,'primary':9,'secondary':8,'tertiary':6.5,'residential':4.7,'living_street':4,'service':3.7,'pedestrian':5,'footway':2,'path':1.8,'steps':2.2,'unclassified':4.5}
roads=[];road_count=0
for wid,w in ways.items():
 t=tags(w);kind=t.get('highway')
 if kind not in widths or t.get('tunnel')=='yes' or t.get('bridge')=='yes':continue
 p=coords(w)
 if len(p)<2:continue
 line=LineString(p).intersection(AREA)
 if line.is_empty:continue
 width=widths[kind]
 if t.get('oneway')=='yes' and kind in ['primary','secondary']:width=7
 try:
    lanes=int(t.get('lanes','0'));width=max(width,min(21,lanes*3.1))
 except ValueError:pass
 t['_way_id']=wid
 roads.append((line,width,t));road_count+=1
 for poly in polygons(line.buffer(width/2+1.1,join_style=2).intersection(LAND).difference(BUILDING_AREA)):
    for tr in triangulate(segmentize(poly,8)):
        if not poly.covers(tr.representative_point()):continue
        cx,cy=tr.centroid.coords[0];surf(chunk('Pavement',cx,cy),tr,rgb('CFC8B2'),lambda x,y:height(x,y)+.16)
 for poly in polygons(line.buffer(width/2,join_style=2).intersection(LAND).difference(BUILDING_AREA)):
    for tr in triangulate(segmentize(poly,8)):
        if not poly.covers(tr.representative_point()):continue
        cx,cy=tr.centroid.coords[0]
        surf(chunk('Road',cx,cy),tr,rgb('737B79') if kind in ['pedestrian','footway','steps','path'] else rgb('535F61'),lambda x,y:height(x,y)+.20)
print('Building facades',len(buildings),flush=True)
records=[];estimated=0
height_overrides=json.loads((SOURCE/'building_height_overrides.json').read_text())
for p,t,wid in buildings:
 x,y=p.centroid.coords[0];p=orient(p.simplify(.16,preserve_topology=True),1)
 name=t.get('name','')
 if name=='Galata Kulesi' or is_mosque(t):landmarks.append((p,t,wid));continue
 v=list(p.exterior.coords)[:-1]
 zlow=min(height(*a) for a in v)-.4;zg=max(height(*a) for a in v)
 try:
    hs=t.get('height','');h=float(re.search(r'[\d.]+',hs).group()) if hs else float(t['building:levels'])*3.25
    sourced=True
 except Exception:h=RNG.choice([10.5,13,16,19,22,25]);sourced=False;estimated+=1
 if not sourced and wid in height_overrides:h=height_overrides[wid]
 if p.area<40:h=min(h,13)
 h=max(4,min(h,42));zt=zg+h
 m=chunk('Buildings',x,y,True);d=chunk('Detail',x,y)
 color=RNG.choice(PALETTE);extrude(m,p,zlow,zt,color)
 roof=RNG.choice(ROOFS)
 convex=p.convex_hull.area/p.area<1.02 and len(v)<=8 and not p.interiors and p.area<600
 if convex and RNG.random()<.62:
    center=p.centroid;top=[(center.x+(a[0]-center.x)*.35,center.y+(a[1]-center.y)*.35,zt+2.3) for a in v]
    for j,a in enumerate(v):k=(j+1)%len(v);d.face([(*a,zt),(*v[k],zt),top[k],top[j]],roof)
    d.face(top,roof)
 else:
    surf(d,p,rgb('98978B') if RNG.random()<.5 else roof,zt+.04)
    if p.area>150:
        q=p.representative_point();cube(d,(q.x,q.y,zt+.65),(3,3,1.2),rgb('B8B9AF'))
 for j,a in enumerate(v):
    b=v[(j+1)%len(v)];dx=b[0]-a[0];dy=b[1]-a[1];length=math.hypot(dx,dy)
    if length<2.8:continue
    nx,ny=dy/length,-dx/length;ux,uy=dx/length,dy/length
    ncol=max(1,int(length/3.3));nfloor=max(1,int((zt-zg-1)/3.3))
    # Thin cornice and regularly spaced low-cost window quads.
    d.face([(a[0]+nx*.12,a[1]+ny*.12,zt-.45),(b[0]+nx*.12,b[1]+ny*.12,zt-.45),(b[0]+nx*.12,b[1]+ny*.12,zt-.13),(a[0]+nx*.12,a[1]+ny*.12,zt-.13)],LIGHT)
    for floor in range(nfloor):
     wz=zg+1.3+floor*3.3
     for col in range(ncol):
        tpos=(col+.5)/ncol;wx=a[0]+tpos*dx+nx*.025;wy=a[1]+tpos*dy+ny*.025;ww=min(1.2,length/ncol*.43)
        glass=DARK if RNG.random()<.88 else rgb('80918E')
        # Contrasting surround, recessed glass, a thin sill and central mullion.
        fw=ww/2+.12
        d.face([(wx-ux*fw,wy-uy*fw,wz-.12),(wx+ux*fw,wy+uy*fw,wz-.12),(wx+ux*fw,wy+uy*fw,wz+1.78),(wx-ux*fw,wy-uy*fw,wz+1.78)],LIGHT)
        wx+=nx*.025;wy+=ny*.025
        d.face([(wx-ux*ww/2,wy-uy*ww/2,wz),(wx+ux*ww/2,wy+uy*ww/2,wz),(wx+ux*ww/2,wy+uy*ww/2,wz+1.65),(wx-ux*ww/2,wy-uy*ww/2,wz+1.65)],glass)
        if col%2==0:
            d.face([(wx-ux*.035+nx*.015,wy-uy*.035+ny*.015,wz),(wx+ux*.035+nx*.015,wy+uy*.035+ny*.015,wz),(wx+ux*.035+nx*.015,wy+uy*.035+ny*.015,wz+1.65),(wx-ux*.035+nx*.015,wy-uy*.035+ny*.015,wz+1.65)],LIGHT)
            d.face([(wx-ux*fw,wy-uy*fw,wz-.1),(wx+ux*fw,wy+uy*fw,wz-.1),(wx+ux*fw+nx*.2,wy+uy*fw+ny*.2,wz-.1),(wx-ux*fw+nx*.2,wy-uy*fw+ny*.2,wz-.1)],LIGHT)
        if j==0 and floor in [1,2] and col%3==0 and int(wid)%7==0:
            # Balcony slab and simple iron railing; all geometry is static.
            center=np.array([wx,wy])+np.array([nx,ny])*.55
            cube(d,(*center,wz-.12),(ww+1,1.2,.18),LIGHT,math.atan2(uy,ux))
            for offset in [-.5,.5]:
                p0=center+np.array([ux,uy])*offset*(ww+1)+np.array([nx,ny])*.5
                bar(d,(*p0,wz),(*p0,wz+.85),.04,METAL)
            p0=center-np.array([ux,uy])*(ww+1)*.5+np.array([nx,ny])*.5;p1=center+np.array([ux,uy])*(ww+1)*.5+np.array([nx,ny])*.5
            bar(d,(*p0,wz+.85),(*p1,wz+.85),.055,METAL)
            for off in np.arange(-ww*.5,ww*.5+.1,.35):
                pp=center+np.array([ux,uy])*off+np.array([nx,ny])*.5
                bar(d,(*pp,wz),(*pp,wz+.85),.025,METAL)
    for zz in np.arange(zg+3.1,zt-1,6.6):
        d.face([(a[0]+nx*.045,a[1]+ny*.045,zz),(b[0]+nx*.045,b[1]+ny*.045,zz),(b[0]+nx*.045,b[1]+ny*.045,zz+.13),(a[0]+nx*.045,a[1]+ny*.045,zz+.13)],LIGHT)
    if j==0:
        mid=((a[0]+b[0])/2,(a[1]+b[1])/2);doorbase=height(*mid)+.22;dw=min(1.1,length*.16)
        d.face([(mid[0]-ux*dw/2+nx*.06,mid[1]-uy*dw/2+ny*.06,doorbase),(mid[0]+ux*dw/2+nx*.06,mid[1]+uy*dw/2+ny*.06,doorbase),(mid[0]+ux*dw/2+nx*.06,mid[1]+uy*dw/2+ny*.06,doorbase+2.25),(mid[0]-ux*dw/2+nx*.06,mid[1]-uy*dw/2+ny*.06,doorbase+2.25)],rgb('695A4E'))
    if length>7 and j==0 and RNG.random()<.24:
        mid=((a[0]+b[0])/2,(a[1]+b[1])/2);length=min(length-1,8)
        for k in range(8):
            u0=-length/2+k*length/8;u1=u0+length/8
            d.face([(mid[0]+ux*u0,mid[1]+uy*u0,zg+3),(mid[0]+ux*u1,mid[1]+uy*u1,zg+3),(mid[0]+ux*u1+nx*1.2,mid[1]+uy*u1+ny*1.2,zg+2.5),(mid[0]+ux*u0+nx*1.2,mid[1]+uy*u0+ny*1.2,zg+2.5)],rgb('9A5342') if k%2 else LIGHT)
 if p.area>70 and int(wid)%3==0:
    q=p.representative_point();cube(d,(q.x,q.y,zt+2.1),(1,1,2.4),rgb('AE8068'));cube(d,(q.x,q.y,zt+3.35),(1.3,1.3,.2),LIGHT)
 records.append({'osm_id':wid,'name':name,'east':round(x,2),'north':round(y,2),'height_m':round(h,2),'height_source':'osm' if sourced else 'estimated'})

from architecture import Architecture
ARCH=Architecture(globals())
print('Building landmarks',flush=True)
for p,t,wid in landmarks:
 x,y=p.centroid.coords[0];z=height(x,y);name=t.get('name','Mosque');m=mesh('Landmark_'+wid+'-col');d=mesh('LandmarkDetail_'+wid)
 if name=='Galata Kulesi':
    cylinder(m,(x,y,z-.5),8.3,40,STONE,32,r2=7.7)
    for zz,rad,h in [(3,8.45,.7),(18,8.05,.5),(34,8.0,.7),(39,9.3,1.25),(46,8.7,.8)]:cylinder(d,(x,y,z+zz),rad,h,LIGHT,32)
    cylinder(m,(x,y,z+40),7.8,7,LIGHT,32)
    cylinder(m,(x,y,z+47),9.2,16.3,METAL,32,r2=0)
    cylinder(d,(x,y,z+63),.15,3,GOLD,8)
    for row in [8,15,23,31,42]:
     for k in range(12):
        a=k*math.tau/12;rad=8.36 if row<35 else 7.86;cx=x+rad*math.cos(a);cy=y+rad*math.sin(a);u=(-math.sin(a)*.58,math.cos(a)*.58)
        d.face([(cx-u[0],cy-u[1],z+row),(cx+u[0],cy+u[1],z+row),(cx+u[0],cy+u[1],z+row+2.6),(cx-u[0],cy-u[1],z+row+2.6)],DARK)
    for k in range(48):
        a=k*math.tau/48;b=(k+1)*math.tau/48
        bar(d,(x+9*math.cos(a),y+9*math.sin(a),z+40.5),(x+9*math.cos(a),y+9*math.sin(a),z+42),.06,METAL)
        bar(d,(x+9*math.cos(a),y+9*math.sin(a),z+42),(x+9*math.cos(b),y+9*math.sin(b),z+42),.07,METAL)
 else:
    records.append(ARCH.mosque(p,t,wid))
    continue
 records.append({'osm_id':wid,'name':name,'east':round(x,2),'north':round(y,2),'height_source':'authored_stylization'})

(OUT/'mosques.json').write_text(json.dumps(ARCH.inventory,ensure_ascii=False,indent=2))

# Galata Bridge: aligned with its OSM endpoints. The centre rises gently to 6 m.
a=np.array(ll(28.97194,41.01821));b=np.array(ll(28.97443,41.02191));axis=b-a;length=np.linalg.norm(axis);u=axis/length;v=np.array([-u[1],u[0]])
def bridge_xy(s,t):return a+u*s+v*t
AZ=height(*a)+.24;BZ=height(*b)+.24
def bridge_z(s):
    t=max(0,min(1,s/length));return AZ*(1-t)+BZ*t+4.4*math.sin(math.pi*t)
m=mesh('Galata_Bridge-col');d=mesh('Galata_Bridge_Detail')
for s in np.arange(0,length,8):
 end=min(length,s+8)
 for t0,t1,col in [(-21,-15,LIGHT),(-15,-3,rgb('535F61')),(-3,3,rgb('808984')),(3,15,rgb('535F61')),(15,21,LIGHT)]:
    m.face([(*bridge_xy(s,t0),bridge_z(s)),(*bridge_xy(end,t0),bridge_z(end)),(*bridge_xy(end,t1),bridge_z(end)),(*bridge_xy(s,t1),bridge_z(s))],col)
 for side in [-21,21]:
    p0=bridge_xy(s,side);p1=bridge_xy(end,side)
    bar(d,(*p0,bridge_z(s)+1.4),(*p1,bridge_z(end)+1.4),.16,METAL)
    bar(d,(*p0,bridge_z(s)),(*p0,bridge_z(s)+1.4),.12,METAL)
 for track in [-1.8,-.9,.9,1.8]:
    p0=bridge_xy(s,track);p1=bridge_xy(end,track)
    bar(d,(*p0,bridge_z(s)+.05),(*p1,bridge_z(end)+.05),.08,rgb('BAC2BA'))
 if int(s)%24==0:
    for t in [-9,9]:
        p0=bridge_xy(s,t);p1=bridge_xy(min(s+4,length),t);poly=LineString([p0,p1]).buffer(.12)
        surf(d,poly,LIGHT,lambda x,y:bridge_z(np.dot(np.array([x,y])-a,u))+.06)
for s in np.arange(35,length-20,55):
 c=bridge_xy(s,0)
 for side in [-13,13]:
    p0=bridge_xy(s,side);cube(m,(*p0,1),(7,7,5),rgb('9C9D8D'))
for s in np.arange(10,length,35):
 for side in [-19,19]:
    p0=bridge_xy(s,side);zz=bridge_z(s);cylinder(d,(*p0,zz),.13,7,METAL,6)
    cube(d,(*p0,zz+7),(1,.55,.3),LIGHT)

# The expanded shoreline also contains the Ataturk road bridge and the Halic
# metro bridge. Include their infrastructure, with no road or rail vehicles.
for wid in ['619249707']:
 if wid not in ways:continue
 bp=Polygon(coords(ways[wid])).buffer(0).intersection(AREA)
 m2=mesh(('Ataturk_Bridge' if wid=='619249707' else 'Halic_Metro_Bridge')+'-col')
 d2=mesh('BridgeDetail_'+wid)
 deck=6.5 if wid=='619249707' else 18.0
 for poly in polygons(bp):
    extrude(m2,poly,deck-1.5,deck,rgb('989F9A'))
    surf(d2,poly.buffer(-1),rgb('5D686A'),deck+.04)
    line=LineString(poly.exterior.coords)
    for start in np.arange(0,line.length-1,5):
        a2=line.interpolate(start);b2=line.interpolate(min(line.length,start+5))
        bar(d2,(a2.x,a2.y,deck+1.2),(b2.x,b2.y,deck+1.2),.08,METAL)
        bar(d2,(a2.x,a2.y,deck),(a2.x,a2.y,deck+1.2),.065,METAL)
    rect=list(poly.minimum_rotated_rectangle.exterior.coords)[:4];edges=[np.array(rect[(i+1)%4])-np.array(rect[i]) for i in range(4)]
    ax=max(edges,key=np.linalg.norm);span=np.linalg.norm(ax);ax/=span;cen=np.array(poly.centroid.coords[0])
    for off in np.arange(-span*.38,span*.39,65):
        pp=cen+ax*off
        if poly.contains(Point(pp)) and not LAND.contains(Point(pp)):cube(m2,(*pp,deck/2),(5,5,deck),rgb('A5A998'))
    if wid=='949665670':
        # Two tapered pylons and a fan of stays, aligned to the footprint.
        for off in [-span*.14,span*.14]:
            pp=cen+ax*off
            cylinder(m2,(*pp,deck),2.0,42,METAL,12,r2=.45)
            for delta in [-70,-53,-36,-19,19,36,53,70]:
                anchor=pp+ax*delta
                if poly.distance(Point(anchor))<9:bar(d2,(*pp,deck+34),(*anchor,deck+.7),.09,rgb('BBC0B8'))

from bridge import build as build_bridge
bridge_metadata=build_bridge(globals())
print('Adding waterfront objects',flush=True)
from vegetation import build as build_vegetation
vegetation_stats=build_vegetation(globals())
tree_count=vegetation_stats['trees']
from street_details import build as build_street_details
street_metadata=build_street_details(globals())

def ferry(lon,lat,angle=0,scale=1):
 x,y=ll(lon,lat);m=mesh(f'Ferry_{lon}_{lat}');cs=math.cos(angle);sn=math.sin(angle)
 def pos(a,b,z):return (x+(a*cs-b*sn)*scale,y+(a*sn+b*cs)*scale,z*scale)
 # Pointed bow and a two-deck white passenger ferry.
 outline=[(-20,-5),(15,-5),(23,0),(15,5),(-20,5)]
 p=Polygon([pos(a,b,0)[:2] for a,b in outline]);extrude(m,p,.25,2.8*scale,rgb('E0DDC5'))
 for z,sx,sy,col in [(3,34,8,LIGHT),(4.9,31,7.5,LIGHT),(6.8,26,7,LIGHT)]:cube(m,pos(-1,0,z),(sx*scale,sy*scale,1.3*scale),col,angle)
 for row in [3.8,5.6]:
  for k in range(-7,7):
   for side in [-1,1]:cube(m,pos(k*2,side*3.8,row),(1.25*scale,.1*scale,.75*scale),DARK,angle)
 cylinder(m,pos(-7,0,7.4),1.1*scale,3*scale,rgb('C0984F'),10)
 cylinder(m,pos(9,0,7.3),.12*scale,5*scale,METAL,6)
for args in [(28.9784,41.0201,.2,1),(28.972,41.0204,-.6,.8),(28.9794,41.0181,2.5,1.1)]:ferry(*args)

# Motor vehicles and tram cars intentionally excluded at user request.

print('Exporting glTF',flush=True)
def export_glb(path):
    blob=bytearray();access=[];views=[];meshes=[];gnodes=[]
    def array(data,component,kind,target):
        while len(blob)%4:blob.append(0)
        offset=len(blob);raw=data.tobytes();blob.extend(raw)
        views.append({'buffer':0,'byteOffset':offset,'byteLength':len(raw),'target':target})
        a={'bufferView':len(views)-1,'componentType':component,'count':len(data),'type':kind}
        if kind=='VEC3' and component==5126:a.update(min=data.min(axis=0).tolist(),max=data.max(axis=0).tolist())
        if component==5121:a['normalized']=True
        access.append(a);return len(access)-1
    stats={'triangles':0,'vertices':0,'mesh_nodes':0}
    for name,m in M.items():
        if not m.f:continue
        v=np.array(m.v,dtype=np.float32);n=np.array(m.n,dtype=np.float32)
        v=v[:,[0,2,1]];v[:,2]*=-1;n=n[:,[0,2,1]];n[:,2]*=-1
        colors=np.array(m.c,dtype=np.float32)/255
        colors[:,:3]=np.where(colors[:,:3]<=.04045,colors[:,:3]/12.92,((colors[:,:3]+.055)/1.055)**2.4)
        colors=np.rint(colors*255).astype(np.uint8)
        pa=array(v,5126,'VEC3',34962);na=array(n,5126,'VEC3',34962);ca=array(colors,5121,'VEC4',34962)
        ia=array(np.array(m.f,dtype=np.uint32),5125,'SCALAR',34963)
        meshes.append({'name':name,'primitives':[{'attributes':{'POSITION':pa,'NORMAL':na,'COLOR_0':ca},'indices':ia,'material':1 if name=='Water' else 2 if name.startswith('LampGlow') else 3 if name.startswith('SignalGlow_red') else 4 if name.startswith('SignalGlow_green') else 5 if name.startswith('BridgeGlass') else 0}]})
        gnodes.append({'name':name,'mesh':len(meshes)-1})
        stats['triangles']+=len(m.f)//3;stats['vertices']+=len(m.v);stats['mesh_nodes']+=1
    j={'asset':{'version':'2.0','generator':'Istanbul Halic expanded bridge and streets v4'},'scene':0,'scenes':[{'nodes':list(range(len(gnodes)))}],'nodes':gnodes,'meshes':meshes,
       'materials':[{'name':'Istanbul_VertexPalette','doubleSided':False,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.88}}, {'name':'Halic_Water','doubleSided':False,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':.12,'roughnessFactor':.26}}, {'name':'Warm_Lamp_Lenses','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.4},'emissiveFactor':[1,.83,.48]}, {'name':'Signal_Red','doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.35},'emissiveFactor':[1,.025,.012]}, {'name':'Signal_Green','doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.35},'emissiveFactor':[.015,.8,.15]}, {'name':'Bridge_Canopy_Glass','doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':.15,'roughnessFactor':.27}}],
       'accessors':access,'bufferViews':views,'buffers':[{'byteLength':len(blob)}],
       'extras':{'attribution':'© OpenStreetMap contributors — ODbL 1.0','origin_lon_lat':[28.975,41.023],'units':'meters','elevation':'Terrain Tiles DEM, smoothed; waterfront corrected to 1.5 m'}}
    js=json.dumps(j,separators=(',',':')).encode();js+=b' '*((-len(js))%4);blob+=b'\x00'*((-len(blob))%4)
    with open(path,'wb') as f:
        f.write(struct.pack('<4sII',b'glTF',2,12+8+len(js)+8+len(blob)));f.write(struct.pack('<I4s',len(js),b'JSON'));f.write(js);f.write(struct.pack('<I4s',len(blob),b'BIN\x00'));f.write(blob)
    return stats
stats=export_glb(OUT/'istanbul_halic.glb')
stats.update(street_details=street_metadata['counts'],bridge_main_span_m=180,vegetation=vegetation_stats,buildings=len(records),estimated_building_heights=estimated,road_ways=road_count,trees=tree_count,dimensions_m=[round(BOUNDS[2]-BOUNDS[0]),round(BOUNDS[3]-BOUNDS[1])],land_area_km2=round(LAND.area/1e6,3),origin=[28.975,41.023],bbox=BBOX,mosques=sum(is_mosque(t) for p,t,wid in landmarks),cars=0,trams=0,elevation_min_m=float(HG.min()),elevation_max_m=float(HG.max()),elevation_source="Mapzen/Tilezen Terrain Tiles")
if CELL:stats['detail_cell_m']=CELL
(OUT/'buildings.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
(OUT/'statistics.json').write_text(json.dumps(stats,indent=2))
(OUT/'spawn.json').write_text(json.dumps({'bridge':[*bridge_xy(length*.78,17),bridge_z(length*.78)],'galata':[*ll(28.97417,41.02563),height(*ll(28.97417,41.02563))]},indent=2))
print(json.dumps(stats,indent=2),flush=True)

(OUT/'map_metadata.json').write_text(json.dumps({'stats':stats,'walk_spawn':[float(bridge_xy(length*.78,17)[0]),float(bridge_z(length*.78)+2),float(-bridge_xy(length*.78,17)[1])],'mosques':ARCH.inventory,'bounds':[BOUNDS[0],BOUNDS[1],BOUNDS[2],BOUNDS[3]],'metro_bridge':bridge_metadata,'street_lights':street_metadata['lights']},ensure_ascii=False,indent=2))
