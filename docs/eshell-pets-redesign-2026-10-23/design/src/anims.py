from mimo import *
SQ=squash(); ST=stretch()
def z(c,top,step):
    Z=["hhh","..h",".h.","h..","hhh"]
    if step==0: px(c,[(BX+12,top-1)],'h'); put(c,Z,BX+13,top-5)
    else: px(c,[(BX+11,top-3)],'h'); put(c,Z,BX+12,top-8)
def heart(c,top,dy=0): put(c,[".c.c.","ccccc",".ccc.","..c.."],BX+12,top-7+dy)
def note(c,top,side):
    put(c,["..a","..a","aaa","aa."],BX-3 if side<0 else BX+13,top-5)
def bang(c,top): px(c,[(BX+12,top-6),(BX+12,top-5),(BX+12,top-3)],'a')
def laptop(c,top,glow):
    put(c,[".oooooooo.","okkkkkkkko","okkkkkkkko","okkkklkkko","okkkkkkkko","oooooooooo"],BX+1,top+3)
    put(c,["oooooooooooo"],BX,17)
    if glow: px(c,[(BX+2,top+2),(BX+3,top+2),(BX+4,top+2),(BX+7,top+2),(BX+8,top+2),(BX+9,top+2)],'a')
    else: px(c,[(BX+3,top+2),(BX+4,top+2),(BX+8,top+2),(BX+9,top+2)],'a')
def leafbit(c,top,k): px(c,[(BX+13+k,top-3+k),(BX+14+k,top-3+k)],'l')
def compressed(c,top):
    for y in range(top+2,top+5):
        px(c,[(BX-1,y),(BX+12,y)],'o')
        px(c,[(BX,y),(BX+11,y)],'b')
def love_heart(c,top,size=0):
    forms=[['.c.c.','ccccc','.ccc.','..c..'],['..c..','.ccc.','..c..'],['..c..']]
    put(c,forms[min(size,len(forms)-1)],BX+12,top-4-[0,3,5][min(size,2)])
TW=[SPROUT,
    ["..........","....oo....","...oldo...","..olddlo..",".ooolloo..","....oddo...."][0:0] or [".....oo.....","....oldo....","...olddlo...","..oollddoo..","..oooddooo..","....oddo...."],
    [".ooo....ooo.","oddlo..ollo.","odlldoolddlo",".odlloolldo.","..oooddooo..","....oddo...."],
    [".....oo.....","....oldo....","...olddlo...","..oollddoo..","..oooddooo..","....oddo...."]]
A={
 'idle':[pet(),pet(body=SQ)],
 'idle_breath':[pet(body=BODY),pet(body=SQ,sprout=PERK)],
 'blink':[pet(eyes='blink')],
 'look_left':[pet(ex=-1,sx=-1)],
 'look_right':[pet(ex=1,sx=1)],
 'look_up':[pet(ey=-1,sprout=PERK)],
 'walk':[pet(feet='w1',sx=1),pet(feet='w2',dy=-1),pet(feet='w3',sx=-1),pet(feet='w2',dy=-1)],
 'hop':[pet(body=SQ,sprout=DROOP,extra=compressed),
        pet(body=ST,feet='tuck',sprout=DROOP,sx=-1,dy=-1),
        pet(body=SQ,sprout=DROOP,eyes='blink',extra=compressed)],
 'doze':[pet(body=BODY,eyes='blink'),
         pet(body=SQ,sprout=DROOP,eyes='closed'),
         pet(body=SQ,sprout=DROOP,eyes='closed')],
 'wake':[pet(body=SQ,sprout=DROOP,eyes='closed'),
         pet(body=ST,arms=['L_up','R_up'],sprout=PERK,eyes='closed'),
         pet(body=ST,arms=['L_up','R_up'],sprout=PERK,eyes='blink'),
         pet(body=BODY,sprout=PERK,eyes='open')],
 'love':[pet(eyes='happy',mouth='smile',sprout=PERK,extra=lambda c,t:love_heart(c,t,0)),
         pet(eyes='happy',mouth='smile',sprout=PERK,extra=lambda c,t:love_heart(c,t,1)),
         pet(eyes='happy',mouth='smile',sprout=PERK,extra=lambda c,t:love_heart(c,t,2)),
         pet(eyes='happy',mouth='smile',sprout=PERK)],
 'stretch':[pet(body=ST,arms=['L_up','R_up'],sprout=PERK,eyes='closed'),
            pet(body=ST,arms=['L_up','R_up'],sprout=PERK,eyes='closed',dy=-1),
            pet(body=BODY,arms=['L_side','R_side'],sprout=PERK,eyes='blink'),
            pet(body=BODY,sprout=PERK,eyes='open')],
 'sit':[pet(body=SQ,by=10,feet='dangle'),pet(body=SQ,by=10,feet='dangle',eyes='blink')],
 'sleep':[pet(body=SQ,by=10,feet='dangle',sprout=DROOP,eyes='closed',extra=lambda c,t:z(c,t,0)),
          pet(body=BODY,by=10,feet='dangle',sprout=DROOP,eyes='closed',dy=-0,extra=lambda c,t:z(c,t,1))],
 'yawn':[pet(body=ST,eyes='closed',mouth='o',arms=['L_up','R_up'],sprout=PERK),pet(body=ST,eyes='closed',mouth='small',arms=['L_up','R_up'],sprout=PERK)],
 'code':[pet(body=BODY,eyes='focus',ey=-3,cheeks=False,extra=lambda c,t:laptop(c,t,True)),pet(body=BODY,eyes='focus',ey=-3,ex=1,cheeks=False,extra=lambda c,t:laptop(c,t,False))],
 'dance':[pet(arms=['L_up','R_side'],sx=-1,ex=-1,mouth='smile',extra=lambda c,t:note(c,t,-1)),pet(dy=-1,arms=['L_up','R_up'],eyes='happy',mouth='smile',sprout=PERK),
          pet(arms=['R_up','L_side'],sx=1,ex=1,mouth='smile',extra=lambda c,t:note(c,t,1)),pet(body=SQ,eyes='happy',mouth='smile')],
 'react':[pet(body=SQ),pet(dy=-3,eyes='wide',sprout=PERK,feet='air',arms=['L_side','R_side'],extra=bang),pet(body=SQ,eyes='blink')],
 'happy':[pet(eyes='happy',mouth='smile',sprout=PERK,sx=-1),pet(eyes='happy',mouth='smile',sprout=PERK,sx=1)],
 'wave':[pet(arms=['R_up'],mouth='smile',ex=1),pet(arms=['R_side'],mouth='smile',ex=1)],
 'twirl':[pet(sprout=TW[0]),pet(sprout=TW[1],dy=-1),pet(sprout=TW[2],dy=-2,eyes='happy'),pet(sprout=TW[3],dy=-1)],
 'sneeze':[pet(body=ST,eyes='closed',sprout=PERK),pet(body=SQ,eyes='closed',mouth='o',sprout=TW[1],extra=lambda c,t:leafbit(c,t,0)),pet(body=SQ,eyes='blink',sprout=TW[1],extra=lambda c,t:leafbit(c,t,2)),pet()],
}
for k,v in A.items():
    for f in v: assert len(f)==H and all(len(r)==W for r in f),k
