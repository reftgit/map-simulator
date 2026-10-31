"""Photo-informed landmark profiles and reusable facade geometry.
The principal landmarks use named profiles; neighbourhood mosques are
typological interpretations where individual photographic evidence is absent.
No photos are projected onto the model or redistributed as textures.
"""
import math,random,json
import numpy as np
from shapely.geometry import Polygon,LineString,Point
from shapely.geometry.polygon import orient

PROFILES={
 '1564032':dict(style='imperial',r=13.75,top=53,minarets=4,ref='https://visit.istanbul/suleymaniye-mosque'),
 '7574356':dict(style='imperial',r=8.1,top=36,minarets=2,ref='https://www.fatih.bel.tr/tr/main/pages/fatihte-bulunan-selatin-camiler/272'),
 '175518494':dict(style='raised_dome',r=7.8,top=25,minarets=1,ref='https://visit.istanbul/rustem-pasha-mosque'),
 '165574748':dict(style='half_domes',r=6.35,top=24,minarets=1,ref='https://www.routard.com/photos/istanbul/1375574-mosquee_kilic_ali_pasa.htm'),
 '175518809':dict(style='gothic_hall',minarets=1,ref='https://visit.istanbul/arap-mosque'),
 '498861887':dict(style='raised_dome',r=8.3,top=28,minarets=1,ref='https://commons.wikimedia.org/wiki/Category:Sokollu_Mehmet_Pasha_Mosque_(Azapkap%C4%B1)'),
 '109980654':dict(style='dome',r=6.7,top=16,minarets=1,ref='https://commons.wikimedia.org/wiki/Category:Ahi_%C3%87elebi_Mosque'),
 '330902933':dict(style='dome',r=6.0,top=20,minarets=1,ref='https://commons.wikimedia.org/wiki/Category:Hidayet_Mosque'),
 '333134101':dict(style='small_dome',r=4.2,top=11,minarets=0,ref='https://dijitalistanbul.org/bereketzade-camii'),
 '331897879':dict(style='hipped',minarets=1,ref='https://commons.wikimedia.org/wiki/Category:Bereketzade_Ali_Efendi_Mosque'),
 '110314231':dict(style='byzantine',r=7.2,top=22,minarets=1,ref='https://visit.istanbul/kalenderhane-mosque'),
 '111002436':dict(style='byzantine',r=4.7,top=18,minarets=1,ref='https://commons.wikimedia.org/wiki/Category:Vefa_Kilise_Mosque'),
 '225989341':dict(style='underground',minarets=1,ref='https://commons.wikimedia.org/wiki/Category:Yeralt%C4%B1_Mosque'),
 '333114634':dict(style='dome',r=4.7,top=17,minarets=1,ref='https://commons.wikimedia.org/wiki/Category:Hobyar_Mosque'),
}

class Architecture:
 def __init__(self,g):
    self.g=g
    for k in ['rgb','mesh','cube','cylinder','dome','bar','surf','extrude','height','ll','polygons']:
        setattr(self,k,g[k])
    self.stone=self.rgb('C7BEA8');self.trim=self.rgb('E0D7C2');self.roof=self.rgb('738184');self.dark=self.rgb('263F46');self.gold=self.rgb('BAA061');self.brick=self.rgb('A07961')
    self.inventory=[]

 def window(self,m,c,u,w,h,col=None,ornate=False):
    """An arch in the vertical wall plane; u follows a CCW footprint edge."""
    x,y,z=c;ux,uy=u;nx,ny=uy,-ux
    def polygon(width,height,offset):
        rr=width*.5;spring=height-rr
        points=[(-rr,0),(rr,0),(rr,spring)]
        points += [(rr*math.cos(a),spring+rr*math.sin(a)) for a in np.linspace(0,math.pi,9)[1:]]
        points +=[(-rr,0)]
        return [(x+ux*xx+nx*offset,y+uy*xx+ny*offset,z+zz) for xx,zz in points[:-1]]
    m.face(polygon(w+.34,h+.22,.025),col or self.trim)
    m.face(polygon(w,h,.045),self.dark)
    # Light mullions divide the openings without extra transparent materials.
    mid=h*.48
    m.face([(x-ux*w*.43+nx*.06,y-uy*w*.43+ny*.06,z+mid),(x+ux*w*.43+nx*.06,y+uy*w*.43+ny*.06,z+mid),(x+ux*w*.43+nx*.06,y+uy*w*.43+ny*.06,z+mid+.09),(x-ux*w*.43+nx*.06,y-uy*w*.43+ny*.06,z+mid+.09)],self.trim)
    m.face([(x-ux*.045+nx*.07,y-uy*.045+ny*.07,z),(x+ux*.045+nx*.07,y+uy*.045+ny*.07,z),(x+ux*.045+nx*.07,y+uy*.045+ny*.07,z+h-.15),(x-ux*.045+nx*.07,y-uy*.045+ny*.07,z+h-.15)],self.trim)
    if ornate:
        rr=w*.5;zz=z+h-rr
        for k in range(9):
            a=k*math.pi/9;b=(k+1)*math.pi/9
            points=[]
            for rad,ang in [(rr,a),(rr+.22,a),(rr+.22,b),(rr,b)]:
                xx=rad*math.cos(ang);hh=rad*math.sin(ang);points.append((x+ux*xx+nx*.08,y+uy*xx+ny*.08,zz+hh))
            m.face(points,self.trim if k%2 else self.brick)

 def finial(self,m,x,y,z,s=1):
    self.cylinder(m,(x,y,z),.12*s,1.6*s,self.gold,8)
    self.cylinder(m,(x,y,z+1.25*s),.3*s,.3*s,self.gold,8,r2=.12*s)
    # A small crescent, lying in the X/Z plane.
    for a,b in zip(np.linspace(.35,math.tau-.35,12),np.linspace(.35,math.tau-.35,12)[1:]):
        self.bar(m,(x+.38*s*math.cos(a),y,z+1.95*s+.38*s*math.sin(a)),(x+.38*s*math.cos(b),y,z+1.95*s+.38*s*math.sin(b)),.045*s,self.gold)

 def capped_dome(self,m,c,r,seams=True):
    x,y,z=c;self.dome(m,c,r,self.roof,10,32)
    self.cylinder(m,(x,y,z-.15),r+.13,.23,self.trim,32)
    if seams and r>4:
     for a in np.linspace(0,math.tau,17)[:-1]:
      for t0,t1 in zip(np.linspace(0,math.pi/2,8),np.linspace(0,math.pi/2,8)[1:]):
        self.bar(m,(x+(r+.03)*math.cos(t0)*math.cos(a),y+(r+.03)*math.cos(t0)*math.sin(a),z+(r+.03)*math.sin(t0)),(x+(r+.03)*math.cos(t1)*math.cos(a),y+(r+.03)*math.cos(t1)*math.sin(a),z+(r+.03)*math.sin(t1)),.055,self.rgb('53676D'))
    self.finial(m,x,y,z+r,.7 if r<5 else 1)

 def minaret(self,m,d,x,y,z,h=30,balconies=1,rad=1.0):
    gz=min(z,self.height(x,y)-.2)
    self.cylinder(m,(x,y,gz),rad*1.65,max(.2,z-gz),self.stone,8)
    self.cylinder(m,(x,y,z),rad*1.6,h*.13,self.stone,8)
    self.cylinder(m,(x,y,z+h*.13),rad*1.6,h*.05,self.stone,12,r2=rad)
    self.cylinder(m,(x,y,z+h*.18),rad,h*.65,self.stone,20,r2=rad*.76)
    levels={1:[.66],2:[.48,.71],3:[.39,.57,.75]}[balconies]
    for f in levels:
        zz=z+h*f;rr=rad*1.85
        self.cylinder(d,(x,y,zz-.8),rad,.8,self.trim,20,r2=rr)
        self.cylinder(d,(x,y,zz),rr,.23,self.trim,24)
        self.cylinder(d,(x,y,zz+1.0),rr,.13,self.trim,24)
        for a in np.linspace(0,math.tau,25)[:-1]:
            self.cylinder(d,(x+rr*.9*math.cos(a),y+rr*.9*math.sin(a),zz+.18),.075,.9,self.trim,4)
    self.cylinder(m,(x,y,z+h*.83),rad*.8,h*.05,self.trim,20,r2=rad*.85)
    self.cylinder(d,(x,y,z+h*.88),rad*.94,h*.12,self.roof,20,r2=0)
    self.finial(d,x,y,z+h,.65)
    for zz in np.arange(z+3,z+h*.85,2.1):self.cylinder(d,(x,y,zz),rad*1.015,.055,self.rgb('A69E8E'),20)

 def facade(self,d,p,z,h,brick=False):
    p=orient(p,1)
    for a,b in zip(list(p.exterior.coords),list(p.exterior.coords)[1:]):
        dx,dy=b[0]-a[0],b[1]-a[1];ln=math.hypot(dx,dy)
        if ln<3:continue
        u=(dx/ln,dy/ln);nx,ny=u[1],-u[0]
        for zz in np.arange(2.5,h-1,4.6):
         for k in range(max(1,int(ln/4.7))):
            t=(k+.5)/max(1,int(ln/4.7));self.window(d,(a[0]+t*dx,a[1]+t*dy,z+zz),u,1.25,2.3,ornate=brick)
        if brick:
         for zz in np.arange(1,h,.85):
            d.face([(a[0]+nx*.02,a[1]+ny*.02,z+zz),(b[0]+nx*.02,b[1]+ny*.02,z+zz),(b[0]+nx*.02,b[1]+ny*.02,z+zz+.18),(a[0]+nx*.02,a[1]+ny*.02,z+zz+.18)],self.brick)
        for zz in [h-.45,h]:
            self.bar(d,(a[0]+nx*.08,a[1]+ny*.08,z+zz),(b[0]+nx*.08,b[1]+ny*.08,z+zz),.11,self.trim)

 def fountain(self,d,x,y,z,r=2.5):
    self.cylinder(d,(x,y,z),r,.4,self.trim,8)
    self.cylinder(d,(x,y,z+.4),r*.6,1.0,self.stone,12)
    for a in np.linspace(0,math.tau,9)[:-1]:self.cylinder(d,(x+r*.9*math.cos(a),y+r*.9*math.sin(a),z+.3),.15,3.2,self.trim,8)
    self.capped_dome(d,(x,y,z+3.5),r*1.1,False)

 def mosque(self,p,t,wid):
    cfg=PROFILES.get(wid,{});name=t.get('name','İsimsiz mescit');style=cfg.get('style','hipped' if p.area<700 else 'dome')
    x,y=p.representative_point().coords[0];z=max(self.height(*a) for a in p.exterior.coords)+.15
    m=self.mesh('Mosque_'+wid+'-col');d=self.mesh('MosqueDetail_'+wid)
    low=min(self.height(*a) for a in p.exterior.coords)-.3
    self.extrude(m,p,low,z+.1,self.rgb('ACA795'))
    rect=list(p.minimum_rotated_rectangle.exterior.coords)[:4];edges=[np.array(rect[(i+1)%4])-np.array(rect[i]) for i in range(4)]
    edge=max(edges,key=np.linalg.norm);axis=edge/np.linalg.norm(edge);side=np.array([-axis[1],axis[0]]);angle=math.atan2(axis[1],axis[0])
    widths=[np.linalg.norm(e) for e in edges];r=cfg.get('r',min(8,min(widths)*.37));h=cfg.get('top',16)-r
    if style=='imperial':
        large=wid=='1564032';x,y=self.ll(*( (28.96405,41.01606) if large else (28.97222,41.01683)))
        r=cfg['r'];h=cfg['top']-r;angle=math.radians(40);axis=np.array([math.cos(angle),math.sin(angle)]);side=np.array([-axis[1],axis[0]])
        w,dep=(61,58) if large else (48,46)
        hall=Polygon([tuple(np.array([x,y])+axis*dx+side*dy) for dx,dy in [(-w/2,-dep/2),(w/2,-dep/2),(w/2,dep/2),(-w/2,dep/2)]]).intersection(p)
        bodyh=18 if large else 12
        upperh=34 if large else 23
        self.extrude(m,p,z-1,z+1,self.stone)
        for part in self.polygons(hall):self.extrude(m,part,z+1,z+bodyh,self.stone);self.facade(d,part,z,bodyh)
        # Stepped central crossing and lower side galleries, rather than a
        # full-height rectangular hall beneath the dome.
        self.cube(m,(x,y,z+(bodyh+upperh)/2),(r*2+6,r*2+6,upperh-bodyh),self.stone,angle)
        self.cylinder(m,(x,y,z+upperh),r+1,h-upperh,self.stone,32)
        for k in range(32 if large else 24):
            a=k*math.tau/(32 if large else 24);u=(-math.sin(a),math.cos(a))
            self.window(d,(x+(r+1.025)*math.cos(a),y+(r+1.025)*math.sin(a),z+h-4),u,1,2.65)
        self.capped_dome(d,(x,y,z+h),r)
        for sign in [-1,1]:
            q=np.array([x,y])+side*sign*r*1.15
            self.capped_dome(d,(*q,z+(25 if large else 20)),r*.79)
        if not large:
            for sign in [-1,1]:
                q=np.array([x,y])+axis*sign*r*1.2
                self.capped_dome(d,(*q,z+20),r*.82)
        for dx in [-1,1]:
         for dy in [-1,1]:
            q=np.array([x,y])+axis*dx*r*1.5+side*dy*r*1.2
            self.capped_dome(d,(*q,z+bodyh),r*.36)
        for ring in p.interiors:
            court=Polygon(ring);cx,cy=court.centroid.coords[0]
            self.surf(m,court,self.rgb('C8C4B6'),z+1.05)
            self.fountain(d,cx,cy,z+1.05,3 if large else 2.3)
            coords=list(ring.coords)
            for a,b in zip(coords,coords[1:]):
                le=math.dist(a,b);n=max(1,round(le/5.4));u=np.array(b)-a;u=u/le
                for j in range(n):
                    q=np.array(a)+(np.array(b)-a)*(j+.5)/n
                    self.cube(d,(*q,z+6.85),(le/n+.15,4.7,.3),self.trim,math.atan2(u[1],u[0]))
                    self.capped_dome(d,(*q,z+7),min(2.6,le/n*.51),False)
                    col=np.array(a)+(np.array(b)-a)*j/n
                    self.cylinder(d,(*col,z+1),.28,4.7,self.trim,10)
                    self.cylinder(d,(*col,z+5.65),.46,.3,self.trim,10)
            corners=list(court.minimum_rotated_rectangle.exterior.coords)[:4]
            corners=sorted(corners,key=lambda a:math.dist(a,(x,y)))
            for k,q in enumerate(corners if large else corners[:2]):
                vec=np.array(q)-np.array([cx,cy]);q=np.array(q)+vec/np.linalg.norm(vec)*3.8
                mh=(76 if k<2 else 56) if large else 55
                self.minaret(m,d,*q,z,mh,3 if k<2 else 2,1.3 if large else 1.05)
    elif style=='gothic_hall':
        h=13.5;self.extrude(m,p,z-1,z+h,self.stone);self.facade(d,p,z,h,True)
        v=list(orient(p,1).exterior.coords)[:-1];cx,cy=p.centroid.coords[0]
        for a,b in zip(v,v[1:]+v[:1]):d.face([(*a,z+h),(*b,z+h),(cx,cy,z+h+3)],self.rgb('8D5948'))
        q=max(rect,key=lambda a:a[1]);tx,ty=np.array(q)*.88+np.array([cx,cy])*.12
        self.cube(m,(tx,ty,z+17),(5.7,5.7,34),self.brick,angle)
        for zz in [5,15,26,33.7]:self.cube(d,(tx,ty,z+zz),(6.0,6.0,.25),self.trim,angle)
        self.cube(d,(tx,ty,z+35),(6.7,6.7,2.4),self.rgb('AA8660'),angle)
        self.cylinder(d,(tx,ty,z+36.3),3.8,8,self.roof,4,r2=0);self.finial(d,tx,ty,z+44.3)
    elif style=='underground':
        h=8;self.extrude(m,p,z-.5,z+h,self.stone);self.facade(d,p,z,h)
        q=rect[0];self.minaret(m,d,*q,z,23,1,.7)
    elif style=='hipped':
        h=min(11,max(6,math.sqrt(p.area)*.35));self.extrude(m,p,z-1,z+h,self.stone);self.facade(d,p,z,h,False)
        v=list(orient(p,1).exterior.coords)[:-1];cx,cy=p.centroid.coords[0]
        if p.convex_hull.area/p.area<1.08:
            top=[(cx+(a[0]-cx)*.25,cy+(a[1]-cy)*.25,z+h+2.8) for a in v]
            for i,a in enumerate(v):j=(i+1)%len(v);d.face([(*a,z+h),(*v[j],z+h),top[j],top[i]],self.rgb('9F6952'))
            d.face(top,self.rgb('9F6952'))
        else:self.surf(d,p,self.rgb('9F6952'),z+h+.06)
        if cfg.get('minarets',0 if 'Mescid' in name or 'Medresesi' in name else 1):
            q=max(rect,key=lambda a:a[1]);q=np.array(q)*.88+np.array([x,y])*.12
            self.minaret(m,d,*q,z,max(20,h+14),1,.7)
    else:
        r=min(r,min(widths)*.48);h=cfg.get('top',16)-r
        color=self.brick if style=='byzantine' else self.stone
        self.extrude(m,p,z-1,z+h-2.5,color)
        self.facade(d,p,z,h-2.5,style=='byzantine')
        self.cylinder(m,(x,y,z+h-2.5),r+.6,2.5,self.stone,24)
        for k in range(16):
            a=k*math.tau/16;self.window(d,(x+(r+.62)*math.cos(a),y+(r+.62)*math.sin(a),z+h-2.2),(-math.sin(a),math.cos(a)),.65,1.6)
        self.capped_dome(d,(x,y,z+h),r)
        if style in ['raised_dome','half_domes']:
            for sign in [-1,1]:
                q=np.array([x,y])+side*sign*r*1.05;self.capped_dome(d,(*q,z+h-4),r*.68)
            for dx in [-1,1]:
             for dy in [-1,1]:
                q=np.array([x,y])+axis*dx*r*1.2+side*dy*r*1.05;self.capped_dome(d,(*q,z+h-5),r*.32)
        if cfg.get('minarets',1):
            q=max(rect,key=lambda a:a[1]);q=np.array(q)*.87+np.array([x,y])*.13
            self.minaret(m,d,*q,z,43 if style=='raised_dome' else max(23,h+r+9),1,.95)
    # A visible doorway on one long frontage, plus a restrained stone threshold.
    poly=orient(p,1);coords=list(poly.exterior.coords);a,b=max(zip(coords,coords[1:]),key=lambda ab:math.dist(*ab))
    vec=np.array(b)-a;ln=np.linalg.norm(vec);u=vec/ln;mid=(np.array(a)+b)/2
    self.window(d,(*mid,z+.25),u,min(2.2,ln*.2),3.4,ornate=True)
    self.inventory.append({'osm_id':wid,'name':name,'style':style,'reference':cfg.get('ref','https://www.openstreetmap.org/'+t.get('_osm_type','way')+'/'+wid),'detail_basis':'named_profile' if cfg else 'OSM footprint + typological interpretation','east':round(x,2),'north':round(y,2),'ground_m':round(z,2)})
    return {'osm_id':wid,'name':name,'east':round(x,2),'north':round(y,2),'height_source':'photo_informed_profile' if cfg else 'typological_estimate'}
