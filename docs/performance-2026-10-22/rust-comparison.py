import importlib.util,json,os,shutil,subprocess,time
from pathlib import Path
repo=Path('/home/zdito/.config/quickshell');out=repo/'docs/performance-2026-10-22';work=Path('/tmp/isla-ab-rust');work.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('sampler',repo/'bar/tests/sample-process.py');sampler=importlib.util.module_from_spec(spec);spec.loader.exec_module(sampler)
config=work/'config.json';shutil.copyfile(Path.home()/'.config/isla/shell.json',config)
for variant in ['A','B']:
 bar=work/variant/'bar';shutil.copytree(repo/'bar',bar,dirs_exist_ok=True)
 p=bar/'shell.qml';s=p.read_text().replace('settings.watchFiles: true','settings.watchFiles: false');s=s.replace('    id: root', '    id: root\n    property int perfFrames: 0\n    Connections { target: Cava; function onValuesChanged() { root.perfFrames++ } }', 1);s=s.replace('        target: "island"','        target: "island"\n        function perf(): string { return JSON.stringify({hasFrame:Cava.hasFrame, signal:Cava.values.some(v => v>0), subscribers:AmbientClock.subscribers, playing:Players.playing, frames:root.perfFrames}); }',1);p.write_text(s)
 if variant=='B':
  p=bar/'Singletons/Cava.qml';s=p.read_text();start=s.index('    function parseFrame(line)');end=s.index('    AmbientSubscription {',start)
  s=s[:start]+'''    function parseFrame(line) {
        const frame = line.trim().split(/\\s+/).map(Number)
        if (frame.length !== bars || frame.some(v => !isFinite(v) || v < 0 || v > 1)) return
        values = frame
        hasFrame = true
    }

'''+s[end:];s=s.replace('running: root.wanted && root.hasFrame && root.envelopeActive && !Flags.reduceMotion','running: false')
  p.write_text(s)
  (bar/'services/cava-stream.sh').write_text('#!/bin/sh\nparent=$1\nshift\nexec /tmp/isla-cava-b/target/release/isla-cava-stream --smooth --parent "$parent" "$@"\n')
def descendants(pid):
 found=[pid]
 for parent in found:
  found.extend(int(x) for x in subprocess.run(['pgrep','-P',str(parent)],capture_output=True,text=True).stdout.split())
 return found

def snapshot(pid):
 rows={}
 for ident in descendants(pid):
  p=Path('/proc')/str(ident)
  try:rows[ident]=dict(**sampler.counters((p/'stat').read_text()),**sampler.memory(p),comm=(p/'comm').read_text().strip())
  except FileNotFoundError:pass
 return rows
results=[]
subprocess.run(['qs','kill','-c','bar'],capture_output=True);time.sleep(1)
try:
 for variant in ['A','B','B','A']:
  i=len(results);bar=work/variant/'bar';env=dict(os.environ,ISLA_CONFIG=str(config),XDG_STATE_HOME=str(work/f'state-{i}'))
  with (out/f'rust-{i}-{variant}.log').open('w') as log:
   p=subprocess.Popen(['qs','-p',str(bar),'--no-duplicate'],env=env,stdout=log,stderr=log,start_new_session=True)
   try:
    time.sleep(5)
    subprocess.run(['qs','-p',str(bar),'ipc','call','island','media',''],capture_output=True,check=True);time.sleep(3)
    state_before=subprocess.run(['qs','-p',str(bar),'ipc','call','island','perf'],capture_output=True,text=True).stdout.strip()
    start=time.monotonic();before=snapshot(p.pid);samples=[]
    for n in range(4):
     time.sleep(3);samples.append(dict(elapsed_s=time.monotonic()-start,processes=snapshot(p.pid)))
    after=samples[-1]['processes'];dt=time.monotonic()-start
    cpu={}
    for pid,row in after.items():
     if pid in before and row['start_ticks']==before[pid]['start_ticks']:
      cpu[pid]=100*(row['cpu_ticks']-before[pid]['cpu_ticks'])/os.sysconf('SC_CLK_TCK')/dt
    state=subprocess.run(['qs','-p',str(bar),'ipc','call','island','perf'],capture_output=True,text=True).stdout.strip()
    record=dict(variant=variant,pid=p.pid,seconds=dt,before=before,samples=samples,cpu_by_pid=cpu,cpu_total=sum(cpu.values()),cpu_qs=cpu[p.pid],state=state,state_before=state_before)
    results.append(record);(out/'rust-ab-comparison.json').write_text(json.dumps(results,indent=2)+'\n');print(variant,record['cpu_qs'],record['cpu_total'],state,flush=True)
   finally:p.terminate();p.wait(timeout=10)
   time.sleep(1)
finally:subprocess.Popen(['qs','-c','bar','--no-duplicate'],cwd=Path.home(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
