from PIL import Image,ImageDraw,ImageFont
from anims import *
from sheet import img
D='/home/zdito/.config/quickshell/docs/'; OUT=D+'eshell-pets-redesign-2026-10-23/design/'
F=ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf',13)
def place(base,fr,x,baseline,S=2):
    # x = pet centre, baseline = perch line (row 18 of the canvas)
    base.alpha_composite(img(fr,scale=S),(int(x-W*S/2),int(baseline-18*S)))
def tag(im,xy,t):
    d=ImageDraw.Draw(im); x,y=xy; w=d.textlength(t,font=F)
    d.rounded_rectangle([x-6,y-4,x+w+6,y+16],6,fill=(250,210,90,235)); d.text((x,y),t,fill=(30,24,20),font=F)
# 1 launcher: search field top edge
L=Image.open(D+'shell-audit-2026-10-18/launcher.png').convert('RGBA').crop((0,0,936,420))
pad=Image.new('RGBA',(936,470),L.getpixel((400,300))); pad.alpha_composite(L,(0,50)); L=pad
place(L,A['sit'][0],830,50+3,S=3)
tag(L,(560,14),'percha: borde superior del buscador')
L.save(OUT+'mock-launcher.png')
# 2 pill niche (split bar): widen pill right end by 34px
T=Image.open(D+'eshell-pets-2026-10-22/phase2/qa-compositor/compositor-compact.png').convert('RGBA').crop((620,0,1300,90))
cap=T.crop((1101-620,0,1125-620,70)); col=T.crop((1100-620,0,1101-620,70))
T2=T.copy()
for x in range(1101-620,1101-620+36): T2.alpha_composite(col,(x,0))
T2.alpha_composite(cap,(1101-620+36,0))
place(T2,A['idle'][0],1101-620+14,56)
big=T2.resize((T2.width*2,T2.height*2),Image.NEAREST)
tag(big,(20,150),'percha: nicho al final de la pill (sólo con mascota en casa)')
big.save(OUT+'mock-pill.png')
# 3 media: walks/dances on timeline
M=Image.open(D+'performance-2026-10-22/final-media.png').convert('RGBA')
place(M,A['dance'][1],590,307)
tag(M,(470,250),'percha: línea de tiempo')
M.save(OUT+'mock-media.png')
# 4 Edots header search box
E=Image.open(D+'settings-latency-2026-10-22/qa-final/theme-dark.png').convert('RGBA')
place(E,A['sit'][0],860,35)
tag(E,(600,6),'percha: buscador de Edots')
E.save(OUT+'mock-edots.png')
print('ok')
