import json,subprocess,random
c=json.load(open('/tmp/claude-1000/qa/cat.json'))['sections']
def call(patch):
    r=subprocess.run(["qs","-c","bar","ipc","call","settings","update",json.dumps(patch)],capture_output=True,text=True,timeout=20)
    return r.stdout.strip()
def alive(): return subprocess.run(["pgrep","-x","qs"],capture_output=True).returncode==0
junk=["abc","",None,True,[],{},-1,1e308,-1e308,"‮\x07'\"${x}%s\\","A"*5000,0,float("nan")]
bad=[];crash=None
for s,keys in c.items():
    for k,m in keys.items():
        if k in("wallpaperApplyScript",): continue
        for v in junk:
            try: s_json=json.dumps({s:{k:v}})
            except Exception: continue
            out=call({s:{k:v}})
            try: d=json.loads(out)
            except Exception: bad.append((s,k,repr(v)[:30],"respuesta no JSON: "+out[:60])); continue
            if not alive(): crash=(s,k,repr(v)[:40]); break
            if d.get("ok"):
                eff=d.get("effective",{}).get(s,{}).get(k)
                mn,mx=m.get("minimum"),m.get("maximum")
                opts=m.get("options")
                t=m.get("type")
                ok_type=(t=="number" and isinstance(eff,(int,float)) and not isinstance(eff,bool)) or (t=="string" and isinstance(eff,str)) or (t=="boolean" and isinstance(eff,bool)) or t not in("number","string","boolean")
                oor=(isinstance(eff,(int,float)) and ((mn is not None and eff<mn) or (mx is not None and eff>mx)))
                badopt=(opts and t=="string" and eff not in opts)
                if not ok_type or oor or badopt: bad.append((s,k,repr(v)[:30],"aceptado/efectivo=%r"%(str(eff)[:30])))
        if crash: break
    if crash: break
print("CRASH en",crash) if crash else print("sin crash")
print(len(bad),"entradas inválidas aceptadas o respuestas rotas")
for b in bad[:40]: print(b)
