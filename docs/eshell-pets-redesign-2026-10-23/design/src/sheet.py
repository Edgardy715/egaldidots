import sys
from PIL import Image,ImageDraw,ImageFont
from anims import *
def rgba(h): return tuple(int(h[i:i+2],16) for i in (1,3,5))+(255,)
def img(fr,pal=PAL,scale=1):
    im=Image.new('RGBA',(W,H),(0,0,0,0))
    for y,r in enumerate(fr):
        for x,ch in enumerate(r):
            if ch!='.': im.putpixel((x,y),rgba(pal[ch]))
    return im.resize((W*scale,H*scale),Image.NEAREST) if scale>1 else im
if __name__=='__main__':
    S=6; pad=14; f=ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf',13) if __import__('os').path.exists('/usr/share/fonts/TTF/DejaVuSans.ttf') else ImageFont.load_default()
    rows=list(A.items()); cols=max(len(v) for _,v in rows)
    cw=W*S+pad; rh=H*S+pad+18
    sh=Image.new('RGBA',(130+cols*cw,len(rows)*rh+pad),(28,22,22,255)); d=ImageDraw.Draw(sh)
    for i,(k,v) in enumerate(rows):
        y=pad+i*rh; d.text((10,y+H*S//2-6),k,fill=(230,220,220),font=f)
        for j,fr in enumerate(v):
            x=130+j*cw; d.line([(x,y+18*S),(x+W*S,y+18*S)],fill=(90,80,80))
            sh.alpha_composite(img(fr,scale=S),(x,y))
    sh.save(sys.argv[1] if len(sys.argv)>1 else 'sheet.png')
