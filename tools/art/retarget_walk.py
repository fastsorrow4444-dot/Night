"""Read CC0 MakeHuman walk1.bvh into compact direction samples. Authoring only."""
import json
import math
import re
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
data=(Path(__file__).parent/'source/makehuman/walk1.bvh').read_text()
hierarchy,motion=data.split('MOTION');tokens=re.findall(r'[{}]|[^\s{}]+',hierarchy);cursor=1;nodes=[];channel=0
def parse(parent=None):
    global cursor,channel
    name=tokens[cursor];cursor+=2
    node={'name':name,'parent':parent,'offset':np.zeros(3),'channels':[]};index=len(nodes);nodes.append(node)
    while tokens[cursor]!='}':
        key=tokens[cursor];cursor+=1
        if key=='OFFSET':node['offset']=np.array(list(map(float,tokens[cursor:cursor+3])));cursor+=3
        elif key=='CHANNELS':
            count=int(tokens[cursor]);cursor+=1
            node['channels']=[(x,channel+i) for i,x in enumerate(tokens[cursor:cursor+count])];channel+=count;cursor+=count
        elif key=='JOINT':parse(index)
        elif key=='End':
            cursor+=1;depth=0
            while True:
                x=tokens[cursor];cursor+=1;depth+=int(x=='{')-int(x=='}')
                if depth==0:break
    cursor+=1
parse()
rows=motion.strip().splitlines();dt=float(rows[1].split(':')[1]);samples=[]
def rotate(axis,angle):
    a=math.radians(angle);c=math.cos(a);s=math.sin(a)
    if axis=='X':return np.array([[1,0,0],[0,c,-s],[0,s,c]])
    if axis=='Y':return np.array([[c,0,s],[0,1,0],[-s,0,c]])
    return np.array([[c,-s,0],[s,c,0],[0,0,1]])
for line in rows[2:]:
    values=list(map(float,line.split()));transforms=[];positions={}
    for node in nodes:
        r=np.eye(3);t=node['offset'].copy()
        for c,i in node['channels']:
            if c.endswith('position'):t['XYZ'.index(c[0])]+=values[i]
            else:r=r@rotate(c[0],values[i])
        m=np.eye(4);m[:3,:3]=r;m[:3,3]=t
        if node['parent'] is not None:m=transforms[node['parent']]@m
        transforms.append(m);positions[node['name']]=m[:3,3]
    samples.append(positions)
# Source is Z up, +Y forward, positive X on the character's left.
def godot(v):return [-float(v[0]),float(v[2]),-float(v[1])]
mapping={'Spine':('Spine1','Spine3'),'Chest':('Spine3','Neck')}
for side in ['L','R']:
    for dest,src,end in [('UpperArm','UpArm','LoArm'),('Forearm','LoArm','Hand'),('Thigh','UpLeg','LoLeg'),('Shin','LoLeg','Foot'),('Foot','Foot','Toe')]:mapping[dest+side]=(src+'_'+side,end+'_'+side)
frames=[]
for sample in samples:
    frame={}
    for dest,(a,b) in mapping.items():
        v=sample[b]-sample[a];v/=np.linalg.norm(v);frame[dest]=[round(x,6) for x in godot(v)]
    frames.append(frame)
(ROOT/'assets/character/walk_cycle.json').write_text(json.dumps({'frame_time':dt,'frames':frames},separators=(',',':'))+'\n')
print('Retargeted walk:',len(frames),'frames; left upper arm',frames[0]['UpperArmL'])
