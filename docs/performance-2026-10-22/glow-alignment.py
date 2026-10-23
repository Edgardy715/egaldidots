import importlib.util,json,os,shutil,subprocess,time
from pathlib import Path
repo=Path('/home/zdito/.config/quickshell');out=repo/'docs/performance-2026-10-22';work=Path('/tmp/isla-glow-alignment');work.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('sampler',repo/'bar/tests/sample-process.py');sampler=importlib.util.module_from_spec(spec);spec.loader.exec_module(sampler)
config=work/'config.json';shutil.copyfile(Path.home()/'.config/isla/shell.json',config)
for variant in ['independent','shared']:
 bar=work/variant/'bar';shutil.copytree(repo/'bar',bar,dirs_exist_ok=True)
 p=bar/'shell.qml';p.write_text(p.read_text().replace('settings.watchFiles: true','settings.watchFiles: false'))
 if variant=='independent':shutil.copyfile('/tmp/isla-perf-20261022-before/bar/components/InnerGlow.qml',bar/'components/InnerGlow.qml')
status=subprocess.run(['playerctl','--player=spotify','status'],capture_output=True,text=True).stdout.strip()
subprocess.run(['playerctl','--player=spotify','pause'],capture_output=True)
subprocess.run(['qs','kill','-c','bar'],capture_output=True);time.sleep(1)
results=[]
try:
 for variant,timing in [('independent',False),('shared',False),('shared',False),('independent',False),('independent',True),('shared',True)]:
  i=len(results);bar=work/variant/'bar';env=dict(os.environ,ISLA_CONFIG=str(config),XDG_STATE_HOME=str(work/f'state-{i}'))
  if timing:env['QSG_RENDER_TIMING']='1'
  path=out/f'glow-{i}-{variant}.log'
  with path.open('w') as log:
   p=subprocess.Popen(['qs','-p',str(bar),'--no-duplicate','--log-times'],env=env,stdout=log,stderr=log,start_new_session=True)
   try:
    time.sleep(6);assert p.poll() is None
    offset=path.stat().st_size
    result=sampler.sample(p.pid,12,3)
    with path.open('r') as f:f.seek(offset);renderlog=f.read()
    (out/f'glow-{i}-{variant}-sample.log').write_text(renderlog)
    results.append(dict(variant=variant,timing=timing,measurement=result,rendered_frames=renderlog.count('frame rendered in')))
    (out/'glow-alignment.json').write_text(json.dumps(results,indent=2)+'\n');print(variant,timing,result['cpu_percent'],results[-1]['rendered_frames'],flush=True)
   finally:p.terminate();p.wait(timeout=10)
   time.sleep(1)
finally:
 if status=='Playing':subprocess.run(['playerctl','--player=spotify','play'],capture_output=True)
 subprocess.Popen(['qs','-c','bar','--no-duplicate'],cwd=Path.home(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
