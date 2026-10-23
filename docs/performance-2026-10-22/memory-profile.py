import gzip,importlib.util,json,os,shutil,subprocess,time
from pathlib import Path
repo=Path('/home/zdito/.config/quickshell');out=repo/'docs/performance-2026-10-22';work=Path('/tmp/isla-memory-profile-complete');work.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('sampler',repo/'bar/tests/sample-process.py');sampler=importlib.util.module_from_spec(spec);spec.loader.exec_module(sampler)
config=work/'config.json';shutil.copyfile(Path.home()/'.config/isla/shell.json',config)
bar=work/'bar';shutil.copytree(repo/'bar',bar,dirs_exist_ok=True)
p=bar/'shell.qml';s=p.read_text().replace('settings.watchFiles: true','settings.watchFiles: false').replace('    id: root','    id: root\n    property var perfOverlays: []',1)
s=s.replace('        target: "island"','''        target: "island"
        function collect(): bool { gc(); return true; }
        function finish(): bool { Qt.callLater(Qt.quit); return true; }
        function nodes(item): int {
            var total = 1
            for (const child of item.children || []) total += nodes(child)
            return total
        }
        function mark(label: string): string {
            var count = 0
            for (const overlay of root.perfOverlays) count += nodes(overlay.contentItem)
            console.log("MEM_MARK", label)
            return JSON.stringify({label:label, nodes:count, subscribers:AmbientClock.subscribers, surface:navigation.openSurface})
        }''',1)
start = s.index('        function nodes(item): int {')
end = s.index('        function mark(', start)
helper = s[start:end].replace('function nodes(', 'function perfNodes(').replace('+= nodes(child)', '+= root.perfNodes(child)')
s = s[:start] + s[end:]
s = s.replace('    property var perfOverlays: []', '    property var perfOverlays: []\n' + helper)
s = s.replace('count += nodes(overlay.contentItem)', 'count += root.perfNodes(overlay.contentItem)')
s=s.replace('            id: monitor\n','            id: monitor\n            Component.onCompleted: root.perfOverlays.push(monitorOverlay)\n',1);p.write_text(s)
subprocess.run(['qs','kill','-c','bar'],capture_output=True);time.sleep(1)
records=[]
with (out/'memory-profile-complete-session.log').open('w') as log,(out/'memory-profiler-complete.log').open('w') as plog:
 env=dict(os.environ,ISLA_CONFIG=str(config),XDG_STATE_HOME=str(work/'state'), QML_DISABLE_DISK_CACHE='1')
 p=subprocess.Popen(['qs','-p',str(bar),'--no-duplicate','--debug','3800','--waitfordebug'],env=env,stdout=log,stderr=log,start_new_session=True)
 profiler=None
 try:
  time.sleep(0.5)
  profiler=subprocess.Popen(['qmlprofiler','--attach','127.0.0.1','--port','3800','--include','memory,pixmapcache,creating,debugmessages','--output',str(work/'memory.qtd')],stdout=plog,stderr=plog)
  time.sleep(6)
  def ipc(*args):
   r=subprocess.run(['qs','-p',str(bar),'ipc','call','island',*args],capture_output=True,text=True,timeout=10)
   assert r.returncode==0,r.stderr
   return r.stdout.strip()
  def snap(label):
   result=json.loads(ipc('mark',label));result.update(sampler.memory(Path('/proc')/str(p.pid)))
   records.append(result);(out/'memory-profile-complete-batches.json').write_text(json.dumps(records,indent=2)+'\n');print(result,flush=True)
  ipc('hide');time.sleep(2);snap('initial')
  for batch in range(1):
   for scenario in ['media','launcher']:
    for i in range(20):
     ipc(scenario,'');time.sleep(0.8);ipc('hide');time.sleep(1)
    time.sleep(2);snap(f'{batch}-{scenario}-after');ipc('collect');time.sleep(1);snap(f'{batch}-{scenario}-gc')
  time.sleep(10);snap('settled')
 finally:
  if p.poll() is None:
   subprocess.run(['qs','-p',str(bar),'ipc','call','island','finish'],capture_output=True,timeout=5)
   try:p.wait(timeout=10)
   except subprocess.TimeoutExpired:p.terminate();p.wait(timeout=10)
  if profiler:
   try:profiler.wait(timeout=20)
   except subprocess.TimeoutExpired:profiler.terminate();profiler.wait(timeout=5)
  if (work/'memory.qtd').exists():
   with (work/'memory.qtd').open('rb') as source,gzip.open(out/'memory-profile-complete.qtd.gz','wb') as target:shutil.copyfileobj(source,target)
  subprocess.Popen(['qs','-c','bar','--no-duplicate'],cwd=Path.home(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
