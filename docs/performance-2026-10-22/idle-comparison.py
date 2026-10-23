import importlib.util,json,os,shutil,subprocess,time
from pathlib import Path
repo=Path('/home/zdito/.config/quickshell');out=repo/'docs/performance-2026-10-22';work=Path('/tmp/isla-idle-perf');work.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('sampler',repo/'bar/tests/sample-process.py');sampler=importlib.util.module_from_spec(spec);spec.loader.exec_module(sampler)
config=work/'config.json';shutil.copyfile(Path.home()/'.config/isla/shell.json',config)
for variant in ['glow','without-glow']:
 bar=work/variant/'bar';shutil.copytree(repo/'bar',bar,dirs_exist_ok=True)
 p=bar/'shell.qml';p.write_text(p.read_text().replace('settings.watchFiles: true','settings.watchFiles: false'))
 if variant=='without-glow':
  p=bar/'components/InnerGlow.qml';s=p.read_text();s=s.replace('running: root.visible && root.opacity > 0.005 && root.width > 0 && root.height > 0 && !Flags.reduceMotion','running: false');p.write_text(s)
status=subprocess.run(['playerctl','--player=spotify','status'],capture_output=True,text=True).stdout.strip()
subprocess.run(['playerctl','--player=spotify','pause'],capture_output=True)
subprocess.run(['qs','kill','-c','bar'],capture_output=True);time.sleep(1)
results=[]
try:
 for variant in ['glow','without-glow','without-glow','glow']:
  i=len(results);bar=work/variant/'bar';env=dict(os.environ,ISLA_CONFIG=str(config),XDG_STATE_HOME=str(work/f'state-{i}'),QSG_RENDER_TIMING='1')
  path=out/f'idle-{i}-{variant}.log'
  with path.open('w') as log:
   p=subprocess.Popen(['qs','-p',str(bar),'--no-duplicate','--log-times'],env=env,stdout=log,stderr=log,start_new_session=True)
   try:
    time.sleep(5)
    assert p.poll() is None
    offset=path.stat().st_size
    result=sampler.sample(p.pid,12,3)
    with path.open('r') as f:f.seek(offset);timing=f.read()
    (out/f'idle-{i}-{variant}-sample.log').write_text(timing)
    with (out/f'idle-{i}-{variant}-top.txt').open('w') as f:subprocess.run(['top','-H','-b','-n','4','-d','3','-p',str(p.pid)],stdout=f)
    results.append(dict(variant=variant,measurement=result));(out/'idle-comparison.json').write_text(json.dumps(results,indent=2)+'\n')
    print(variant,result['cpu_percent'],flush=True)
   finally:p.terminate();p.wait(timeout=10)
   time.sleep(1)
finally:
 if status=='Playing':subprocess.run(['playerctl','--player=spotify','play'],capture_output=True)
 subprocess.Popen(['qs','-c','bar','--no-duplicate'],cwd=Path.home(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
