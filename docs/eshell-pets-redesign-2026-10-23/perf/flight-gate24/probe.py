import importlib.util,json,tempfile
from pathlib import Path
root=Path('/home/zdito/.config/quickshell')
spec=importlib.util.spec_from_file_location('bench',root/'bar/tests/pets-performance.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
out=root/'docs/eshell-pets-redesign-2026-10-23/perf/flight-gate24';out.mkdir(exist_ok=True)
runs=[]
with tempfile.TemporaryDirectory() as tmp:
 config=Path(tmp)/'config.json';config.write_text('{}\n')
 for i in range(2):
  r=b.measure('mimo','flying',5,config,out/f'round{i+1}.log');runs.append(r)
  print(json.dumps({k:r[k] for k in ('scenario','tree_cpu_percent','framesPerSecond')}),flush=True)
(out/'results.json').write_text(json.dumps({'runs':runs,'summary':b.summarize(runs)},indent=2)+'\n')
assert b.summarize(runs)['flying']['tree_cpu_percent'] < 2
