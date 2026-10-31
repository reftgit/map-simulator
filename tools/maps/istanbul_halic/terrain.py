"""Terrain Tiles / Terrarium elevation sampler, using only bundled source tiles.
Pixels encode metres: R*256 + G + B/256 - 32768.
Two gentle 5-tap smoothing passes suppress small urban DEM artefacts.
This is regional DEM relief, not survey-grade street or building elevation.
"""
from pathlib import Path
import math, json
import numpy as np
from PIL import Image

class Elevation:
    def __init__(self, directory):
        directory=Path(directory)
        self.meta=json.loads((directory/'metadata.json').read_text())
        self.z=self.meta['zoom']; coords=self.meta['tiles']
        self.x0=min(x for x,y in coords); self.y0=min(y for x,y in coords)
        self.data=np.zeros(((max(y for x,y in coords)-self.y0+1)*256,(max(x for x,y in coords)-self.x0+1)*256),dtype=np.float32)
        for x,y in coords:
            a=np.array(Image.open(directory/f'{self.z}_{x}_{y}.png'),dtype=np.float32)
            h=a[:,:,0]*256+a[:,:,1]+a[:,:,2]/256-32768
            self.data[(y-self.y0)*256:(y-self.y0+1)*256,(x-self.x0)*256:(x-self.x0+1)*256]=h
        for _ in range(2):
            for axis in [0,1]:
                pad=[(0,0),(0,0)];pad[axis]=(2,2);a=np.pad(self.data,pad,mode='edge');out=np.zeros_like(self.data)
                for k,w in enumerate([1,4,6,4,1]):
                    sl=[slice(None),slice(None)];sl[axis]=slice(k,k+self.data.shape[axis]);out+=a[tuple(sl)]*(w/16)
                self.data=out
    def sample(self,lon,lat):
        n=2**self.z
        px=((lon+180)/360*n-self.x0)*256-.5
        py=((1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*n-self.y0)*256-.5
        px=max(0,min(self.data.shape[1]-1.001,px));py=max(0,min(self.data.shape[0]-1.001,py))
        x,y=int(px),int(py);u,v=px-x,py-y
        return float((1-v)*((1-u)*self.data[y,x]+u*self.data[y,x+1])+v*((1-u)*self.data[y+1,x]+u*self.data[y+1,x+1]))
