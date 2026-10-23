import importlib.util, json, os, shutil, subprocess, time
from pathlib import Path
repo=Path('/home/zdito/.config/quickshell')
out=repo/'docs/performance-2026-10-22'
work=Path('/tmp/isla-session-perf');work.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('sampler',repo/'bar/tests/sample-process.py');sampler=importlib.util.module_from_spec(spec);spec.loader.exec_module(sampler)
config=work/'config.json';shutil.copyfile(Path.home()/'.config/isla/shell.json',config)
for variant in ['before','after']:
 dest=work/variant/'bar'
 shutil.copytree(repo/'bar',dest,dirs_exist_ok=True)
 if variant=='before':
  for p in Path('/tmp/isla-perf-20261022-before/bar').rglob('*'):
   if p.is_file():shutil.copyfile(p,dest/p.relative_to('/tmp/isla-perf-20261022-before/bar'))
 shell=dest/'shell.qml';s=shell.read_text().replace('settings.watchFiles: true','settings.watchFiles: false')
 s=s.replace('        target: "island"','        target: "island"\n        function collect(): bool { gc(); return true; }',1)
 shell.write_text(s)
subprocess.run(['qs','kill','-c','bar'],capture_output=True)
time.sleep(1)
results=[]
try:
 for variant in ['before','after','after','before']:
  dest=work/variant/'bar';idx=len(results)
  env=dict(os.environ, ISLA_CONFIG=str(config), XDG_STATE_HOME=str(work/f'state-{idx}'))
  with (out/f'{idx}-{variant}-session.log').open('w') as log:
   process=subprocess.Popen(['qs','-p',str(dest),'--no-duplicate'],env=env,stdout=log,stderr=log,start_new_session=True)
   try:
    time.sleep(5)
    def ipc(*args):
     return subprocess.run(['qs','-p',str(dest),'ipc','call','island',*args],capture_output=True,text=True,timeout=10)
    assert process.poll() is None,(out/f'{idx}-{variant}-session.log').read_text()
    ipc('hide');time.sleep(2)
    compact=sampler.sample(process.pid,12,3)
    with (out/f'{idx}-{variant}-compact-top.txt').open('w') as f:subprocess.run(['top','-H','-b','-n','4','-d','3','-p',str(process.pid)],stdout=f)
    ipc('media','');time.sleep(3)
    expanded=sampler.sample(process.pid,12,3)
    with (out/f'{idx}-{variant}-media-top.txt').open('w') as f:subprocess.run(['top','-H','-b','-n','4','-d','3','-p',str(process.pid)],stdout=f)
    record=dict(variant=variant,pid=process.pid,compact=compact,expanded=expanded)
    results.append(record);(out/'music-comparison.json').write_text(json.dumps(results,indent=2)+'\n')
    print(variant,'compact',compact['cpu_percent'],'media',expanded['cpu_percent'],flush=True)
   finally:
    process.terminate();process.wait(timeout=10)
   time.sleep(1)
finally:
 subprocess.Popen(['qs','-c','bar','--no-duplicate'],cwd=Path.home(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
