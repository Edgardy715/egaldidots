import random,subprocess,sys,time
seed=int(sys.argv[1]); dur=float(sys.argv[2]); random.seed(seed)
S=["launcher","overview","calendar","mixer","clipboard","notifs","wallpaper","connectivity","workspaces","focus","peek"]
def q(*a): subprocess.run(["qs","-c","bar","ipc","call",*a],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
log=[];t0=time.time()
while time.time()-t0<dur:
    r=random.random()
    if r<.6: c=("island",random.choice(S),"DP-1")
    elif r<.75: c=("island","hide")
    elif r<.85: c=("island","page","DP-1",random.choice(["settings","files","xx","","media","audio"]))
    elif r<.92: c=("notifctl",random.choice(["toggleDnd","count","clear"]))
    else:
        subprocess.run(["notify-send",f"t{random.randint(0,99)}","x"*random.randint(0,300)]); c=("notify",)
    log.append(c)
    if c[0]!="notify": q(*c)
    if subprocess.run(["pgrep","-x","qs"],stdout=subprocess.DEVNULL).returncode!=0:
        print("CRASH tras",len(log),"pasos; ultimos:",log[-6:]); open(f"crash_seed{seed}.txt","w").write(repr(log)); sys.exit(1)
print("vivo",len(log),"pasos")
