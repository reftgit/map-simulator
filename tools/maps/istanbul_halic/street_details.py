"""Game-scale street furniture and markings over the OSM street layout.
Mapped signals/crossings are used where available; lamps/arrows are authored.
Signal indications are static scenery, not a traffic simulation.
"""
import json,math,collections
import numpy as np
from shapely.geometry import Point,LineString,Polygon
from shapely.ops import unary_union
from shapely.strtree import STRtree


def build(g):
    tags=g['tags'];height=g['height'];rgb=g['rgb'];chunk=g['chunk'];cube=g['cube'];cylinder=g['cylinder'];bar=g['bar'];surf=g['surf'];polygons=g['polygons']
    roads=[(line,w,t) for line,w,t in g['roads'] if line.geom_type=='LineString' and t.get('highway') not in ['pedestrian','footway','steps','path','cycleway']]
    lines=[r[0] for r in roads];lookup=STRtree(lines)
    land=g['LAND'];building=g['BUILDING_AREA']
    drive=unary_union([l.buffer(w/2,join_style=2) for l,w,t in roads]).intersection(land).difference(building)
    # Actual road triangle planes keep paint above sloping road geometry.
    triangles=[];planes=[]
    for name,m in g['M'].items():
        if not name.startswith('Road_'):continue
        for k in range(0,len(m.f),3):
            p=np.asarray([m.v[i] for i in m.f[k:k+3]])
            n=np.cross(p[1]-p[0],p[2]-p[0])
            if abs(n[2])<1e-9:continue
            triangles.append(Polygon(p[:,:2]));planes.append((p[0],n))
    surface=STRtree(triangles)
    def zroad(x,y):
        p=Point(x,y);ix=surface.query(p,predicate='intersects')
        if len(ix)==0:ix=[surface.nearest(p)]
        return max(float(a[2]-(n[0]*(x-a[0])+n[1]*(y-a[1]))/n[2]) for a,n in [planes[i] for i in ix])+.025
    def basis(line,d):
        p=np.array(line.interpolate(max(0,min(line.length,d))).coords[0])
        a=np.array(line.interpolate(max(0,d-.8)).coords[0]);b=np.array(line.interpolate(min(line.length,d+.8)).coords[0]);u=b-a
        if np.linalg.norm(u)<1e-6:return p,np.array([1.,0.]),np.array([0.,1.])
        u/=np.linalg.norm(u);return p,u,np.array([-u[1],u[0]])
    def nearest(pt):
        i=int(lookup.nearest(pt));line,w,t=roads[i];d=line.project(pt);p,u,v=basis(line,d)
        return line,w,t,d,p,u,v
    counts=collections.Counter();lights=[];signals=[];crossings=[];lamp_pts=[];signal_pts=[];cross_pts=[]
    polecol=rgb('59686B');ivory=rgb('F2EFE0');warm=rgb('FFF0BC')
    doors=[Point(g['nodes'][n.get('id')]) for n in g['doc'].findall('node') if tags(n).get('entrance') not in [None,'no']]
    door_lookup=STRtree(doors) if doors else None
    tree_data=json.loads((g['ROOT']/'source/vegetation.json').read_text())['trees']
    tree_points=[Point(t['east'],t['north']) for t in tree_data];trees=STRtree(tree_points)
    def available(x,y):
        p=Point(x,y)
        if not g['AREA'].buffer(-2).contains(p) or not land.contains(p) or building.distance(p)<.75:return False
        if door_lookup is not None and door_lookup.geometries[door_lookup.nearest(p)].distance(p)<2.2:return False
        if len(tree_points) and tree_points[int(trees.nearest(p))].distance(p)<1.0:return False
        return True
    def lamp(x,y,u,h,source):
        if not available(x,y) or any((x-a)**2+(y-b)**2<81 for a,b in lamp_pts):return False
        z=height(x,y)+.18;m=chunk('StreetLamps',x,y);ang=math.atan2(u[1],u[0]);reach=1.5 if h>6 else .75
        cylinder(m,(x,y,z),.15 if h>6 else .11,h,polecol,8,r2=.075)
        cylinder(m,(x,y,z),.23,.36,rgb('7D8580'),8)
        p=np.array([x,y]);tip=p+u*reach
        bar(m,(x,y,z+h-.4),(*tip,z+h+.05),.07,polecol)
        cube(m,(*tip,z+h+.08),(1.05 if h>6 else .6,.34,.17),polecol,ang)
        cube(chunk('LampGlow',x,y),(*tip,z+h-.02),(.78 if h>6 else .42,.25,.04),warm,ang)
        lamp_pts.append((x,y));lights.append({'x':round(float(tip[0]),3),'y':round(z+h-.08,3),'z':round(float(-tip[1]),3),'source':source});counts['street_lamps']+=1
        return True
    def signal(x,y,u,active='red'):
        if not available(x,y) or any((x-a)**2+(y-b)**2<16 for a,b in signal_pts):return False
        z=height(x,y)+.18;m=chunk('TrafficSignals',x,y);v=np.array([-u[1],u[0]]);ang=math.atan2(v[1],v[0])
        cylinder(m,(x,y,z),.075,3.75,polecol,7)
        cube(m,(x,y,z+.16),(.32,.32,.32),rgb('858B81'),ang)
        c=np.array([x,y])-u*.13
        cube(m,(*c,z+3.65),(.40,.26,1.12),rgb('263339'),ang)
        for k,color in enumerate(['red','amber','green']):
            zz=z+4.0-k*.35;c2=c-u*.145
            co=rgb({'red':'D93829','amber':'D9A843','green':'43B572'}[color]) if color==active else rgb({'red':'612C27','amber':'655735','green':'29483B'}[color])
            target=chunk('SignalGlow_'+color,x,y) if color==active else m
            rim=[]
            for a in np.linspace(0,math.tau,13)[:-1]:rim.append((c2[0]+v[0]*.115*math.cos(a),c2[1]+v[1]*.115*math.cos(a),zz+.115*math.sin(a)))
            target.face(rim[::-1],co)
            # Small hood above each aspect.
            cube(m,(*(c-u*.20),zz+.15),(.38,.33,.05),rgb('263339'),ang)
        signal_pts.append((x,y));signals.append({'east':round(float(x),3),'north':round(float(y),3),'indication':active});counts['traffic_signal_heads']+=1
        return True
    def paint(poly,kind='markings'):
        for p in polygons(poly.intersection(drive)):
            if p.area<.006:continue
            x,y=p.centroid.coords[0];surf(chunk('RoadPaint',x,y),p,ivory,zroad);counts[kind]+=1
    def rect(p,u,v,length,width):return Polygon([p+u*a+v*b for a,b in [(-length/2,-width/2),(length/2,-width/2),(length/2,width/2),(-length/2,width/2)]])
    # Read mapped pedestrian crossings and signal points before painting lanes.
    exclusions=[]
    for n in g['doc'].findall('node'):
        t=tags(n);kind=t.get('highway');xy=g['nodes'][n.get('id')];pt=Point(xy)
        if kind not in ['crossing','traffic_signals'] or not g['AREA'].contains(pt) or not land.contains(pt):continue
        line,w,rt,d,p,u,v=nearest(pt)
        if pt.distance(line)>w/2+2:continue
        if kind=='crossing' or t.get('crossing') in ['traffic_signals','marked','uncontrolled']:
            if not any(np.linalg.norm(p-q)<10 for q in cross_pts):
                for off in np.arange(-1.8,1.81,.85):paint(rect(p+u*off,u,v,.45,max(2,w-.8)),'zebra_stripes')
                cross_pts.append(p);crossings.append({'east':float(p[0]),'north':float(p[1]),'source':'OSM '+n.get('id')});counts['crosswalks']+=1
                exclusions.append(rect(p,u,v,6,w+1))
        if kind=='traffic_signals' or t.get('crossing')=='traffic_signals':
            for sign in [-1,1]:
                q=p+u*sign*3.5+v*sign*(w/2+.6)
                signal(*q,u*sign,'red' if sign==1 else 'green')
                # Stop line before the controlled crossing, in its approach lane.
                paint(rect(p-u*sign*3.2-v*sign*w*.25,u,v,.35,w*.42),'stop_lines')
            exclusions.append(Point(p).buffer(6))
    # Keep lane lines and arrows out of junction centres.
    neighbours=collections.defaultdict(set)
    for line,w,t in roads:
        way=g['ways'].get(t.get('_way_id'))
        if way is None:continue
        ids=[n.get('ref') for n in way.findall('nd')]
        for a,b in zip(ids,ids[1:]):neighbours[a].add(b);neighbours[b].add(a)
    for ident,adj in neighbours.items():
        if len(adj)>=3 and ident in g['nodes']:exclusions.append(Point(g['nodes'][ident]).buffer(4.8))
    no_lane=unary_union(exclusions)
    for line,w,t in roads:
        kind=t.get('highway');oneway=t.get('oneway') in ['yes','1','-1']
        if kind not in ['primary','secondary','tertiary','primary_link','secondary_link','trunk','trunk_link'] and w<6:continue
        if line.length<16:continue
        # White edge lines and centre/lane separators, clipped around crossings.
        for off in [-w/2+.32,w/2-.32]:
            for d in np.arange(5,line.length-5,3):
                p,u,v=basis(line,d);q,u2,v2=basis(line,min(d+3,line.length-5))
                paint(LineString([p+v*off,q+v2*off]).buffer(.055,cap_style=2).difference(no_lane),'edge_line_segments')
        try:lanes=max(1,min(6,int(t.get('lanes','2'))))
        except ValueError:lanes=2
        separators=[-w/2+w*k/lanes for k in range(1,lanes)]
        if not separators and not oneway:separators=[0]
        for off in separators:
            for d in np.arange(7,line.length-6,9):
                p,u,v=basis(line,d);q,u2,v2=basis(line,min(d+3,line.length-5))
                paint(LineString([p+v*off,q+v2*off]).buffer(.07,cap_style=2).difference(no_lane),'lane_dashes')
        if line.length>45:
            for d in np.arange(24,line.length-15,65):
                p,u,v=basis(line,d)
                for sign in ([1] if oneway else [1,-1]):
                    q=p-v*w*.25*sign;du=u*sign
                    if no_lane.distance(Point(q))<5:continue
                    arrow=unary_union([rect(q-du*.5,du,v,2.1,.20),Polygon([q+du*1.2,q-du*.1+v*.65,q-du*.1-v*.65])])
                    paint(arrow,'direction_arrows')
    # Authored illumination extends across both old and new streets.
    for line,w,t in g['roads']:
        if line.geom_type!='LineString' or t.get('lit')=='no' or line.length<14:continue
        kind=t.get('highway');major=kind in ['primary','secondary','trunk','primary_link','secondary_link'];walking=kind in ['footway','path','pedestrian','steps']
        spacing=30 if major else 40 if walking else 42
        for k,d in enumerate(np.arange(7,line.length-4,spacing)):
            p,u,v=basis(line,d)
            for sign in ([-1,1] if major else [1 if k%2 else -1]):
                q=p+v*sign*(w/2+.7)
                lamp(*q,-v*sign,8 if major else 4.4 if walking else 6,'authored spacing')
    for n in g['doc'].findall('node'):
        if tags(n).get('highway')=='street_lamp':
            x,y=g['nodes'][n.get('id')];_,w,_,_,p,u,v=nearest(Point(x,y));toward=p-np.array([x,y]);norm=np.linalg.norm(toward)
            lamp(x,y,toward/norm if norm>.1 else u,6,'OSM lamp')
    counts['lamp_mesh_triangles_estimate']=counts['street_lamps']*60
    data={'counts':dict(counts),'lights':lights,'signals':signals,'crossings':crossings,'notes':'Mapped OSM signal/crossing positions; inferred pole offsets, static indications; authored lamp spacing and lane paint; not a surveyed traffic plan.'}
    (g['ROOT']/'source/street_details.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
    print('STREET DETAILS',dict(counts),flush=True)
    return data
