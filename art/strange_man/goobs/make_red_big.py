"""Red intro Goob, bigger + crisper (Sean 2026-11-20: it was smaller and softer than the blue one).
From raw_red_angle_3.png (Sean's angle pick): scale x1.24, snap to the raw_red_sky.png colours,
solid 1 px dark outline, then a clean face (eyes gazing up, smile, blush), banded rim and
top-left light. Run from anywhere: python art/strange_man/goobs/make_red_big.py -> raw_red_big.png"""
from PIL import Image
G='C:/Users/Sean/four-in-a-rogue/art/strange_man/goobs/'
SP=G  # output folder
src=Image.open(G+'raw_red_angle_3.png').convert('RGBA')
pal=sorted(set(p[:3] for p in Image.open(G+'raw_red_sky.png').convert('RGBA').getdata() if p[3]))
pal=[c for c in pal if c!=(255,255,255)]
FACE=(232,59,59)
box=src.crop(src.getbbox())
sx=1.24
W,H=round(box.width*sx),round(box.height*sx)
big=box.resize((W,H),Image.LANCZOS)
out=Image.new('RGBA',(48,48),(0,0,0,0))
def near(c): return min(pal,key=lambda p:sum((a-b)**2 for a,b in zip(p,c)))
ox,oy=(48-W)//2, 46-H
for y in range(H):
  for x in range(W):
    r,g,b,a=big.getpixel((x,y))
    if a>=128: out.putpixel((ox+x,oy+y),near((r,g,b))+(255,))
# solid 1px dark outline round the silhouette
D=(46,34,47,255)
a=out.copy()
for y in range(48):
  for x in range(48):
    if a.getpixel((x,y))[3]:
      if any(not(0<=x+dx<48 and 0<=y+dy<48) or a.getpixel((x+dx,y+dy))[3]==0 for dx,dy in((1,0),(-1,0),(0,1),(0,-1))):
        out.putpixel((x,y),D)

im=out.convert('RGBA')
FACE=(232,59,59,255); W=(255,255,255,255); D=(46,34,47,255); L=(179,56,49,255)
M=(110,39,39,255); B=(245,125,74,255)
cx,cy,rx,ry=24,25,15,8
for y in range(48):
  for x in range(48):
    if ((x-cx)/rx)**2+((y-cy)/ry)**2<=1: im.putpixel((x,y),FACE)
def eye(x,y,left):
  rows=[[W,D,D,L] if left else [L,D,D,W],[W]*4,[W]*4]
  for j,r in enumerate(rows):
    for i,c in enumerate(r): im.putpixel((x+i,y+j),c)
eye(18,21,True); eye(28,25,False)
for p in ((21,28),(22,29),(23,29),(24,30),(25,30),(26,29)): im.putpixel(p,M)
for p in ((16,25),(17,25),(32,29),(33,29)): im.putpixel(p,B)
im.save(SP+'raw_red_big.png')
# rim clean-up: per column, interior pixels below the face ellipse -> highlight / mid / dark band
im=Image.open(SP+'raw_red_big.png').convert('RGBA')
HI=(234,79,54,255); MID=(174,35,52,255); DK=(110,39,39,255)
def inside(x,y): return im.getpixel((x,y))[3] and im.getpixel((x,y))[:3]!=(46,34,47)
fx,fy,frx,fry=24,25,16.5,9.5
for x in range(48):
  ys=[y for y in range(48) if inside(x,y)]
  if not ys: continue
  top=[y for y in ys if ((x-fx)/frx)**2+((y-fy)/fry)**2>1 and y<fy]
  bot=[y for y in ys if ((x-fx)/frx)**2+((y-fy)/fry)**2>1 and y>=fy]
  for y in top: im.putpixel((x,y),FACE)
  for i,y in enumerate(bot):
    im.putpixel((x,y),HI if i==0 else (DK if i==len(bot)-1 else MID))
  for y in ys:
    if ((x-fx)/frx)**2+((y-fy)/fry)**2<=1 and im.getpixel((x,y))[:3] not in ((255,255,255),(46,34,47),(179,56,49),(110,39,39),(245,125,74)):
      im.putpixel((x,y),FACE)
im.save(SP+'raw_red_big.png')
# light from the top left (as on the man and the blue Goob): highlight arc top-left, shade arc bottom-right of the face
im=Image.open(SP+'raw_red_big.png').convert('RGBA')
H1=(245,125,74,255); H2=(252,167,144,255); SH=(179,56,49,255)
import math
for y in range(48):
  for x in range(48):
    if im.getpixel((x,y))!=FACE: continue
    d=((x-fx)/frx)**2+((y-fy)/fry)**2
    ang=math.degrees(math.atan2(y-fy,x-fx))
    if d>0.62 and -170<ang<-100: im.putpixel((x,y),H2 if d>0.8 and -150<ang<-120 else H1)
    elif d>0.7 and -10<ang<60: im.putpixel((x,y),SH)
im.save(SP+'raw_red_big.png')
