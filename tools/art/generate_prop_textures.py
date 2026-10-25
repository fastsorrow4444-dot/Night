"""Original paper textures for close-up cartons; runtime has no Python dependency."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

folder=Path(__file__).resolve().parents[2]/'assets/player/textures'
folder.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(21)
n=512
y,x=np.mgrid[:n,:n]
soft=np.asarray(Image.fromarray(rng.integers(95,160,(n,n),dtype=np.uint8)).filter(ImageFilter.GaussianBlur(7)),dtype=float)-128
fibers=rng.normal(0,.8,(n,n))+np.sin(x*.8+y*.05)*.6+soft*.12
for name,color in [('cardboard',(148,121,84)),('coated',(174,179,173))]:
 rgb=np.clip(np.array(color)+fibers[...,None],0,255).astype(np.uint8)
 Image.fromarray(rgb).save(folder/(name+'.png'))
print('Created paper material textures.')
