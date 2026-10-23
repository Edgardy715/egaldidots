import dbus, importlib.util, json, os, shutil, subprocess, time
from pathlib import Path
repo=Path('/home/zdito/.config/quickshell');out=repo/'docs/performance-2026-10-22';work=Path('/tmp/isla-memory-perf');work.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('sampler',repo/'bar/tests/sample-process.py');sampler=importlib.util.module_from_spec(spec);spec.loader.exec_module(sampler)
config=work/'config.json';shutil.copyfile(Path.home()/'.config/isla/shell.json',config)
bar=work/'bar';shutil.copytree(repo/'bar',bar,dirs_exist_ok=True)
p=bar/'shell.qml';p.write_text(p.read_text().replace('settings.watchFiles: true','settings.watchFiles: false').replace('        target: "island"','        target: "island"\n        function collect(): bool { gc(); return true; }',1))
subprocess.run(['qs','kill','-c','bar'],capture_output=True);time.sleep(1)
env=dict(os.environ,ISLA_CONFIG=str(config),XDG_STATE_HOME=str(work/'state'))
records=[]
with (out/'memory-session.log').open('w') as log:
 process=subprocess.Popen(['qs','-p',str(bar),'--no-duplicate'],env=env,stdout=log,stderr=log,start_new_session=True)
 watcher=None
 try:
  time.sleep(5)
  watcher=subprocess.Popen(['python',str(repo/'bar/tests/pss-watch.py'),'--pid',str(process.pid),'--seconds','900','--output',str(out/'memory-30s.jsonl')])
  def ipc(*args):
   r=subprocess.run(['qs','-p',str(bar),'ipc','call','island',*args],capture_output=True,text=True,timeout=10)
   assert r.returncode==0,r.stderr
  def snap(label):
   record=dict(label=label,time=time.monotonic(),**sampler.memory(Path('/proc')/str(process.pid)))
   records.append(record);(out/'memory-batches.json').write_text(json.dumps(records,indent=2)+'\n');print(record,flush=True)
  ipc('hide');time.sleep(2);snap('initial')
  for batch in range(2):
   for scenario in ['media','wallpaper','launcher','settings','tracks','notifications']:
    snap(f'{batch}-{scenario}-before')
    for i in range(20):
     if scenario in ['media','wallpaper','launcher','settings']:
      ipc(scenario,*([] if scenario=='settings' else ['']));time.sleep(1)
      ipc('hide');time.sleep(1)
     elif scenario=='tracks':
      result=subprocess.run(['playerctl','--player=spotify','next'],capture_output=True)
      if result.returncode: raise RuntimeError('No se puede cambiar pista')
      time.sleep(1.5)
     else:
      bus=dbus.SessionBus();service=dbus.Interface(bus.get_object('org.freedesktop.Notifications','/org/freedesktop/Notifications'),'org.freedesktop.Notifications')
      ident=service.Notify('Isla performance test',0,'','Prueba de rendimiento',f'Notificación {i+1}',[],{'transient':dbus.Boolean(True)},500)
      time.sleep(1);service.CloseNotification(ident)
    ipc('hide');time.sleep(3);snap(f'{batch}-{scenario}-after')
    ipc('collect');time.sleep(1);snap(f'{batch}-{scenario}-gc')
  time.sleep(30);snap('settled-30s');ipc('collect');time.sleep(1);snap('settled-gc')
 finally:
  if watcher:watcher.terminate();watcher.wait()
  process.terminate();process.wait(timeout=10)
  subprocess.Popen(['qs','-c','bar','--no-duplicate'],cwd=Path.home(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
