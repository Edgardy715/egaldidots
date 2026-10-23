import importlib.util,json,os,shutil,subprocess,time
from pathlib import Path
repo=Path('/home/zdito/.config/quickshell');out=repo/'docs/performance-2026-10-22';work=Path('/tmp/isla-final-sample');work.mkdir(exist_ok=True)
bar=work/'bar';shutil.copytree(repo/'bar',bar,dirs_exist_ok=True)
p=bar/'shell.qml';p.write_text(p.read_text().replace('settings.watchFiles: true','settings.watchFiles: false'))
config=work/'config.json';shutil.copyfile(Path.home()/'.config/isla/shell.json',config)
spec=importlib.util.spec_from_file_location('sampler',repo/'bar/tests/sample-process.py');sampler=importlib.util.module_from_spec(spec);spec.loader.exec_module(sampler)
subprocess.run(['qs','kill','-c','bar'],capture_output=True);time.sleep(1)
with (out/'final-session.log').open('w') as log:
 env=dict(os.environ,ISLA_CONFIG=str(config),XDG_STATE_HOME=str(work/'state'))
 p=subprocess.Popen(['qs','-p',str(bar),'--no-duplicate'],env=env,stdout=log,stderr=log,start_new_session=True)
 try:
  time.sleep(6);assert p.poll() is None
  compact=sampler.sample(p.pid,12,3)
  subprocess.run(['qs','-p',str(bar),'ipc','call','island','media',''],capture_output=True,check=True);time.sleep(3)
  media=sampler.sample(p.pid,12,3)
  subprocess.run(['grim','-g','1028,8 720x440',str(out/'final-media.png')],check=True)
  (out/'final-music.json').write_text(json.dumps(dict(compact=compact,media=media),indent=2)+'\n')
  print('final',compact['cpu_percent'],media['cpu_percent'],flush=True)
 finally:
  p.terminate();p.wait(timeout=10)
  subprocess.Popen(['qs','-c','bar','--no-duplicate'],cwd=Path.home(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
