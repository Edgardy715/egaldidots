import importlib.util,json,os,tempfile,time
from pathlib import Path
root=Path('/home/zdito/.config/quickshell')
spec=importlib.util.spec_from_file_location('bench',root/'bar/tests/pets-performance.py'); b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
original=b.tree
samples=[]
def traced(pid):
 tree=original(pid)
 threads={}
 for process in tree:
  for task in (Path('/proc')/str(process)/'task').iterdir():
   try: threads[task.name]={'ns':int((task/'schedstat').read_text().split()[0]),'name':(task/'comm').read_text().strip()}
   except (FileNotFoundError,ProcessLookupError):pass
 samples.append({'at':time.monotonic(),'ticks':sum(row['cpu_ticks'] for row in tree.values()),'threads':threads})
 return tree
b.tree=traced
out=root/'docs/eshell-pets-redesign-2026-10-23/perf/cpu-probe';out.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory() as temporary:
 config=Path(temporary)/'config.json';config.write_text('{}\n')
 runs=[]
 for scenario in ('hidden','hidden','disabled'):
  samples=[]
  result=b.measure('mimo',scenario,5,config,out/f'{scenario}-{len(runs)}.log')
  first,last=samples[1],samples[-2]
  changes=[{'name':row['name'],'cpu_ms':(row['ns']-first['threads'][tid]['ns'])/1e6} for tid,row in last['threads'].items() if tid in first['threads'] and row['ns']!=first['threads'][tid]['ns']]
  summary={'scenario':scenario,'tick_cpu':result['tree_cpu_percent'],'elapsed_s':last['at']-first['at'],'threads':changes}
  runs.append({'summary':summary,'samples':samples}); print(json.dumps(summary),flush=True)
(out/'results.json').write_text(json.dumps(runs,indent=2)+'\n')
