# Part-based authoring for Mimo; outputs flattened 20x18 char grids.
W,H=20,20
PAL={'o':'#1c2a2d','b':'#86d6c4','s':'#55a898','h':'#d2f5ec','l':'#a6d65e','d':'#5f9a3c','c':'#f0948f','a':'#ffd36b','k':'#a9b6ba'}
BODY=["..oooooooo..",".ohhbbbbbbo.","ohbbbbbbbbbo","obbbbbbbbbbo","obbbbbbbbbbo","obbbbbbbbbbo","osbbbbbbbbso",".ossssssssso."[:12]]
BODY=["..oooooooo..",".ohhbbbbbbo.","ohbbbbbbbbbo","obbbbbbbbbbo","obbbbbbbbbbo","obbbbbbbbbbo","osbbbbbbbbso",".osssssssso."]
def squash(n=1): return BODY[:2]+BODY[3:]  if n==1 else BODY
def stretch(): return BODY[:3]+[BODY[3]]+BODY[3:]
SPROUT=[".ooo....ooo.","olllo..oddlo","olddlooldllo",".olldoodllo.","..oooddooo..","....oddo...."]
PERK=["ooo......ooo","ollo....oldo","olldo..odllo",".olldoodllo.","..oooddooo..","....oddo...."]
DROOP=["....oddo....","..oooddooo..",".olldoodllo.","olddlo.oldlo","olllo..oddlo",".ooo....ooo."]
def shift(rows,dx):  # shear top rows for lean
    out=[]
    for i,r in enumerate(rows):
        k=dx if i<3 else (dx if i<4 and abs(dx)>1 else 0)
        out.append(('.'*k+r)[:len(r)] if k>0 else (r[-k:]+'.'*(-k)) if k<0 else r)
    return out
def canvas(): return [['.']*W for _ in range(H)]
def put(c,part,x,y):
    for j,r in enumerate(part):
        for i,ch in enumerate(r):
            X,Y=x+i,y+j
            if ch!='.' and 0<=X<W and 0<=Y<H: c[Y][X]=ch
def px(c,pts,ch):
    for x,y in pts:
        if 0<=x<W and 0<=y<H: c[y][x]=ch
BX=4
def pet(body=None,by=9,sprout=SPROUT,sx=0,eyes='open',ex=0,ey=0,feet='rest',cheeks=True,arms=None,mouth=None,extra=None,dy=0):
    body=body or BODY
    c=canvas(); bh=len(body); top=by+dy+(8-bh)
    # feet
    fy=17+dy
    F={'rest':[(BX+2,fy),(BX+3,fy),(BX+8,fy),(BX+9,fy)],
       'w1':[(BX+1,fy),(BX+2,fy),(BX+8,fy-1),(BX+9,fy-1)],
       'w2':[(BX+2,fy),(BX+3,fy),(BX+8,fy),(BX+9,fy)],
       'w3':[(BX+2,fy-1),(BX+3,fy-1),(BX+9,fy),(BX+10,fy)],
       'dangle':[(BX+2,fy),(BX+2,fy+1),(BX+9,fy),(BX+9,fy+1)],
       'tuck':[],'air':[(BX+3,fy),(BX+8,fy)]}[feet]
    px(c,F,'s')
    put(c,shift(sprout,sx),BX,top-6)
    put(c,body,BX,top)
    ry=top+3 if bh>=8 else top+2
    L,R=BX+3+ex,BX+8+ex
    if eyes=='open': px(c,[(L,ry+ey),(L,ry+1+ey),(R,ry+ey),(R,ry+1+ey)],'o')
    elif eyes=='blink': px(c,[(L,ry+1),(R,ry+1)],'o')
    elif eyes=='closed': px(c,[(L-1,ry+1),(L,ry+1),(R,ry+1),(R+1,ry+1)],'o')   # sleepy lines
    elif eyes=='happy': px(c,[(L-1,ry+1),(L,ry),(L+1,ry+1),(R-1,ry+1),(R,ry),(R+1,ry+1)],'o')
    elif eyes=='wide': px(c,[(L,ry-1),(L,ry),(L,ry+1),(R,ry-1),(R,ry),(R,ry+1)],'o')
    elif eyes=='focus': px(c,[(L,ry+1+ey),(L+1,ry+1+ey),(R,ry+1+ey),(R+1,ry+1+ey)],'o')
    if cheeks: px(c,[(BX+1,ry+2),(BX+10,ry+2)],'c')
    if mouth=='o': px(c,[(BX+5,ry+2),(BX+6,ry+2),(BX+5,ry+3),(BX+6,ry+3)],'o')
    elif mouth=='smile': px(c,[(BX+5,ry+3),(BX+6,ry+3)],'o'); px(c,[(BX+4,ry+2),(BX+7,ry+2)],'o')
    elif mouth=='small': px(c,[(BX+5,ry+2),(BX+6,ry+2)],'o')
    if arms:
        for a in arms:
            if a=='L_up': px(c,[(BX-1,top+2),(BX-1,top+1),(BX-2,top)],'b')
            if a=='R_up': px(c,[(BX+12,top+2),(BX+12,top+1),(BX+13,top)],'b')
            if a=='L_side': px(c,[(BX-1,top+4),(BX-2,top+4)],'b')
            if a=='R_side': px(c,[(BX+12,top+4),(BX+13,top+4)],'b')
            if a=='L_fwd': px(c,[(BX+1,top+6),(BX+2,top+6)],'b')
            if a=='R_fwd': px(c,[(BX+9,top+6),(BX+10,top+6)],'b')
            if a=='L_fwd2': px(c,[(BX+1,top+5),(BX+2,top+5)],'b')
            if a=='R_fwd2': px(c,[(BX+9,top+5),(BX+10,top+5)],'b')
    if extra: extra(c,top)
    return [''.join(r) for r in c]
