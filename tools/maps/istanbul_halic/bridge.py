"""Photo-referenced Haliç Metro Bridge: static low-poly interpretation.
Dimensions use ISTCON's project description; alignment uses OSM M2 tracks.
"""
import math,json
import numpy as np
from shapely.geometry import Point,LineString,Polygon


def build(g):
    ll=g['ll'];mesh=g['mesh'];rgb=g['rgb'];cube=g['cube'];bar=g['bar'];cylinder=g['cylinder'];height=g['height']
    a=np.array(ll(28.963439,41.019337));b=np.array(ll(28.969881,41.026019))
    u=(b-a)/np.linalg.norm(b-a);v=np.array([-u[1],u[0]]);length=float(np.linalg.norm(b-a));angle=math.atan2(u[1],u[0])
    centre=np.array(ll(28.9667445,41.022778));mid=float(np.dot(centre-a,u));pylons=[mid-90,mid+90]
    deck=17.5;start_z=max(deck,height(*a)+.6);end_z=max(deck,height(*b)+.6)
    def xy(s,t=0):return a+u*s+v*t
    def zz(s):
        if s<180:return deck+(start_z-deck)*(1-s/180)**2
        if s>length-210:return deck+(end_z-deck)*((s-(length-210))/210)**2
        return deck
    def at(s,t=0,z=0):return (*xy(s,t),zz(s)+z)
    def block(m,s,t,z,sx,sy,h,col):cube(m,at(s,t,z),(sx,sy,h),col,angle)
    def quad(m,s0,s1,t0,t1,z,col):
        t0,t1=sorted([t0,t1]);m.face([at(s0,t0,z),at(s1,t0,z),at(s1,t1,z),at(s0,t1,z)],col)
    body=mesh('Halic_Metro_Bridge-col');d=mesh('Halic_Metro_Bridge_Detail');glass=mesh('BridgeGlass_Canopies')
    steel=rgb('8C999A');pale=rgb('CBD1CA');dark=rgb('48575C');gold=rgb('B9AC77');paving=rgb('BCB9A5');rail=rgb('A9AFAB')
    # Continuous railway deck. Station side platforms widen the middle span.
    for s in np.arange(0,length,5):
        e=min(length,s+5);width=9.7 if abs((s+e)/2-mid)<90 else 6.3
        quad(body,s,e,-width,width,0,dark)
        quad(body,s,e,-width,width,-1.6,steel)
        for side in [-1,1]:
            body.face([at(s,side*width,-1.6),at(e,side*width,-1.6),at(e,side*width,0),at(s,side*width,0)],steel)
        # Lower public promenade; rises gently into the approach ends.
        lower=-3.7*min(1,s/90,(length-s)/90)
        for side in [-1,1]:
            t=side*(8+3*min(1,max(0,(90-abs(s-mid))/15)))
            te=side*(8+3*min(1,max(0,(90-abs(e-mid))/15)))
            body.face([at(s,t-1.4,lower),at(e,te-1.4,lower),at(e,te+1.4,lower),at(s,t+1.4,lower)],paving)
            for edge in [t-1.4,t+1.4]:
                bar(d,at(s,edge,lower+1.15),at(e,edge+te-t,lower+1.15),.075,pale)
                bar(d,at(s,edge,lower),at(s,edge,lower+1.15),.045,gold)
                bar(d,at(s,edge,lower+.45),at(e,edge+te-t,lower+.45),.04,pale)
            if int(s)%15==0:bar(d,at(s,side*4,-1.4),at(s,t,lower-.25),.18,steel)
    # Track sleepers, running rails and modest cable trays, with no trains.
    for s in np.arange(1,length-1,1.4):
        for t in [-2.0,2.0]:block(d,s,t,.08,.24,2.3,.16,rgb('A6A69B'))
    for s in np.arange(0,length,8):
        e=min(length,s+8)
        for t in [-2.7175,-1.2825,1.2825,2.7175]:bar(d,at(s,t,.23),at(e,t,.23),.075,rail)
        for t in [-5.5,5.5]:bar(d,at(s,t,.42),at(e,t,.42),.06,gold)
    # Two 65 m tapered pylons, 180 m apart, with a lower cable attachment zone.
    for s in pylons:
        x,y=xy(s)
        block(body,s,0,-deck+1.1,12,12,2.2,rgb('909790'))
        for side in [-1,1]:bar(body,(*xy(s,side*4.5),1.8),at(s,side*2,-1.5),1.25,rgb('B1B7AE'))
        ring=[(0,1.45),(3,1.95),(24,1.4),(39,.52),(46,.12)]
        for (z0,r0),(z1,r1) in zip(ring,ring[1:]):cylinder(body,(x,y,deck+z0),r0,z1-z0,pale,20,r2=r1)
        cylinder(d,(x,y,63.5),.09,1.5,steel,8)
        # Nine stays in each direction: central-plane cable system.
        for sign in [-1,1]:
            for k,off in enumerate(np.linspace(17,87,9)):
                anchor=s+sign*off
                bar(d,(x,y,43.5+k*.48),at(anchor,0,.65),.13,pale)
                block(d,anchor,0,.4,1.1,.7,.55,steel)
    # Approach piers and the pivot of the 120 m opening section, shown closed.
    for s in list(np.arange(28,pylons[0]-112,43))+list(np.arange(pylons[1]+110,length-12,43)):
        p=xy(s);base=height(*p) if g['LAND'].contains(Point(p)) else .6
        top=zz(s)-1.6
        if top-base<1:continue
        cylinder(body,(*p,base),1.4,top-base,rgb('AFB4A9'),10,r2=1.05)
        block(body,s,0,-2.0,4.2,13,1.2,rgb('ADB3AA'))
    pivot=pylons[0]-144;p=xy(pivot)
    cylinder(body,(*p,.8),4,deck-2.4,rgb('939D99'),16,r2=3)
    for s in [pivot-60,pivot+60]:block(d,s,0,.025,.18,12.6,.05,rgb('303F43'))
    # Side platforms and shallow, segmented glass canopies between the pylons.
    for side in [-1,1]:
        for s in np.arange(mid-78,mid+78,5):
            e=min(mid+78,s+5)
            quad(body,s,e,side*3.5,side*9.4,.48,paving)
            for t in [side*3.65,side*3.85]:bar(d,at(s,t,.51),at(e,t,.51),.065,rgb('D9BD56'))
            profile=[(4.2,4.0),(5.1,5.15),(6.5,5.6),(8.1,4.8),(9.4,2.35)]
            for (t0,z0),(t1,z1) in zip(profile,profile[1:]):
                glass.face([at(s,side*t0,z0),at(e,side*t0,z0),at(e,side*t1,z1),at(s,side*t1,z1)],rgb('9CABAA'))
                bar(d,at(s,side*t0,z0),at(s,side*t1,z1),.09,gold)
            bar(d,at(s,side*8.6,.48),at(s,side*9.4,2.35),.14,gold)
            bar(d,at(s,side*4.4,.48),at(s,side*4.2,4),.11,gold)
            if int(s)%3==0:block(d,s,side*7.7,1.05,2,.65,.16,rgb('657C77'))
        # Access stairways from the public lower promenade to each platform.
        for s0 in [mid-88,mid+76]:
            for k in range(24):
                z=-3.7+(k+1)*(4.18/24)
                block(body,s0+k*.42,side*10,z-.10,.44,2.5,.20,paving)
            for off in [-1.15,1.15]:bar(d,at(s0,side*10+off,-2.55),at(s0+10.1,side*10+off,1.63),.065,gold)
        # Station end elevator enclosure, understated rather than oversized.
        for s in [mid-84,mid+84]:
            block(d,s,side*6.4,2.15,3,2.5,3.3,steel)
            block(glass,s,side*6.4,2.45,2.8,2.3,2.4,rgb('789A9D'))
    # Walkway lamps along the approaches and across the river.
    lamps=[]
    for s in np.arange(10,length-8,24):
        for side in [-1,1]:
            t=side*(11 if abs(s-mid)<90 else 8)
            low=-3.7*min(1,s/90,(length-s)/90)
            p=xy(s,t);base=zz(s)+low
            cylinder(d,(*p,base),.055,3.5,steel,6)
            cube(d,(*p,base+3.5),(.45,.45,.15),gold,angle)
            cube(mesh('LampGlow_Bridge'),(*p,base+3.40),(.32,.32,.06),rgb('FFF0BD'),angle)
            lamps.append([float(p[0]),float(base+3.3),float(-p[1])])
    data={'name':'Haliç Metro Köprüsü','reference':'https://www.istconinsaat.com.tr/tr/projelerimiz/istanbul-metrosu-halic-metro-gecis-koprusu-yapim-isi','overall_model_length_m':round(length,2),'main_span_m':180,'pylon_top_m_above_water':65,'cable_count':36,'station_canopy_length_m':156,'model_deck_level_m':deck,'pylon_positions':[list(map(float,xy(s))) for s in pylons],'station_centre':list(map(float,xy(mid))),'walkway_test_position':[float(xy(mid,11)[0]),deck-3.7+2,float(-xy(mid,11)[1])],'lamps':lamps,'notes':'Static photo-referenced interpretation; swing span closed; no rolling stock.'}
    (g['ROOT']/'source/bridge_metadata.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
    return data
