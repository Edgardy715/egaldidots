import os,json
from PIL import Image,ImageDraw,ImageFont
from anims import *
from sheet import img,rgba
OUT='/home/zdito/.config/quickshell/docs/eshell-pets-redesign-2026-10-23/design'
os.makedirs(OUT,exist_ok=True)
F=ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf',14) if os.path.exists('/usr/share/fonts/TTF/DejaVuSans.ttf') else ImageFont.load_default()
LABEL={'idle':'reposo · respira','idle_breath':'respiración alterna','blink':'parpadeo','look_left':'mira izq.','look_right':'mira der.','look_up':'mira arriba (hover)',
 'walk':'camina','hop':'salto: agacha / aire / cae','sit':'sentado en borde','sleep':'duerme','yawn':'bosteza','code':'programa','dance':'baila','react':'clic: salto',
 'happy':'caricia: contento','love':'caricia: corazón y alegría','doze':'se queda dormido','wake':'despierta y se estira','stretch':'se estira',
 'wave':'saluda','twirl':'travesura: hélice','sneeze':'travesura: estornudo'}
def sheet(name,bg,line,S=6):
    rows=list(A.items()); cols=4; pad=16; cw=W*S+pad; rh=H*S+pad+6
    sh=Image.new('RGBA',(190+cols*cw,len(rows)*rh+pad),bg); d=ImageDraw.Draw(sh)
    fg=(235,228,228) if bg[0]<128 else (40,34,38)
    for i,(k,v) in enumerate(rows):
        y=pad+i*rh; d.text((12,y+H*S//2-16),k,fill=fg,font=F); d.text((12,y+H*S//2+4),LABEL[k],fill=fg[:3]+(150,),font=F)
        for j,fr in enumerate(v):
            x=190+j*cw; d.line([(x,y+18*S),(x+W*S,y+18*S)],fill=line,width=2)
            sh.alpha_composite(img(fr,scale=S),(x,y))
    sh.save(f'{OUT}/{name}')
sheet('poses-dark.png',(26,22,24,255),(110,100,104))
sheet('poses-light.png',(242,238,240,255),(170,160,166))
# GIFs
T={'idle':[(0,900),(1,900),(0,700),('blink',110),(0,900),(1,900)],'idle_breath':[(0,500),(1,500)],
   'walk':[(i,150) for i in range(4)]*3,'hop':[(0,80),(1,100),(2,90)],'doze':[(0,600),(1,600),(2,700)],
   'wake':[(0,120),(1,260),(2,220),(3,180)],'love':[(0,180),(1,180),(2,180),(3,160)],'stretch':[(0,220),(1,220),(2,260),(3,180)],'sit':[(0,1400),(1,120),(0,900)],
   'sleep':[(0,1300),(1,1300)],'yawn':[(0,800),(1,500)],'code':[(0,380),(1,260),(0,420),(1,300)],'dance':[(i,230) for i in range(4)]*2,
   'react':[(0,90),(1,300),(2,240),('idle0',600)],'happy':[(0,260),(1,260)]*2,'wave':[(0,260),(1,260)]*2,'twirl':[(i,110) for i in range(4)]*2+[('idle0',500)],
   'sneeze':[(0,450),(1,160),(2,520),(3,500)]}
def gif(k,S=6,bg=(26,22,24)):
    frames=[];durs=[];xs=0
    for idx,(f,ms) in enumerate(T[k]):
        fr=A['blink'][0] if f=='blink' else A['idle'][0] if f=='idle0' else A[k][f]
        can=Image.new('RGBA',(W*S+ (60 if k=='walk' else 0),H*S),bg+(255,))
        dx=(idx*5) if k=='walk' else 0
        d=ImageDraw.Draw(can); d.line([(0,18*S),(can.width,18*S)],fill=(110,100,104),width=2)
        can.alpha_composite(img(fr,scale=S),(dx,0)); frames.append(can.convert('RGB')); durs.append(ms)
    frames[0].save(f'{OUT}/anim-{k}.gif',save_all=True,append_images=frames[1:],duration=durs,loop=0,disposal=2)
for k in T: gif(k)
# palettes
mat=json.load(open(os.path.expanduser('~/.cache/matugen/palette.json')))['colors']
def mix(a,b,t): A_=rgba(a);B_=rgba(b); return '#%02x%02x%02x'%tuple(round(A_[i]*(1-t)+B_[i]*t) for i in range(3))
PALS={'Marea (fija, por defecto)':PAL,
 'Coral (fija)':{**PAL,'b':'#f4a37f','s':'#d07656','h':'#ffd9c4','l':'#7cc9a8','d':'#3f8f73','c':'#e8606a'},
 'Noche (fija)':{**PAL,'o':'#0f1022','b':'#8d93d8','s':'#6067b3','h':'#c8ccff','l':'#e2c86a','d':'#b0902f','c':'#e89ac0','a':'#ffe08a'},
 'Matugen (wallpaper actual)':{**PAL,'o':mat['on_primary_fixed'],'b':mat['primary'],'s':mix(mat['primary'],mat['primary_container'],.55),'h':mat['primary_fixed'],
    'l':mat['tertiary'],'d':mix(mat['tertiary'],mat['tertiary_container'],.6),'c':mat['error'],'a':mat['tertiary_fixed'] if 'tertiary_fixed' in mat else '#ffd8e6','k':mat['outline']}}
S=6; P=Image.new('RGBA',(len(PALS)*(W*S+90)+20,H*S+70),(26,22,24,255)); d=ImageDraw.Draw(P)
for i,(n,p) in enumerate(PALS.items()):
    x=20+i*(W*S+90); P.alpha_composite(img(A['idle'][0],p,S),(x,10)); d.text((x,H*S+20),n,fill=(235,228,228),font=F)
P.save(f'{OUT}/palettes.png')
# accessories (layers anchored to the stem/head point)
def acc_flower(c,top): put(c,[".c.","cac",".c."],BX+4,top-7)
def acc_scarf(c,top): put(c,["cccccccccc"],BX+1,top+6); put(c,["c","c"],BX+8,top+7)
def acc_cap(c,top): put(c,["..oooo..",".oaaaao.","oooooooo"][:3],BX+2,top-2)
def acc_glasses(c,top): put(c,["oooooooooo",".ohh..ohh.",".ooo..ooo."],BX+1,top+2)
ACC={'sin accesorio':None,'flor':acc_flower,'bufanda':acc_scarf,'gafas':acc_glasses}
P=Image.new('RGBA',(len(ACC)*(W*S+90)+20,H*S+70),(26,22,24,255)); d=ImageDraw.Draw(P)
for i,(n,fn) in enumerate(ACC.items()):
    x=20+i*(W*S+90); P.alpha_composite(img(pet(extra=fn),scale=S),(x,10)); d.text((x,H*S+20),n,fill=(235,228,228),font=F)
P.save(f'{OUT}/accessories.png')
json.dump({k:v for k,v in A.items()},open('frames.json','w'))
print('ok')
