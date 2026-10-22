#!/usr/bin/env python3
"""Audio child ownership under EOF, TERM, KILL, blocked query and server EOF."""
import argparse
import json
import os
from pathlib import Path
import runpy
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
helpers = runpy.run_path(str(ROOT / "bar/tests/cava-hybrid-performance.py"))
tree, stop = (helpers[key] for key in ("tree", "stop"))
fixture = runpy.run_path(str(ROOT / "bar/tests/audio-backend.py"))["fixture"]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--bridge", type=Path, default=ROOT / "bar/services/audio_bridge.py")
args = parser.parse_args()
FAKE = '''#!/usr/bin/env python3
import json,os,signal,sys,time
from pathlib import Path
kind=Path(sys.argv[0]).name
blocking=kind=='parec' or sys.argv[1:]==['subscribe'] or os.environ['AUDIO_MODE']=='query-KILL'
if blocking:
    with open(os.environ['AUDIO_PIDS'],'a') as f:f.write(str(os.getpid())+'\\n')
    if kind=='parec':
        while True:os.write(1,bytes(3840));time.sleep(.01)
    elif os.environ['AUDIO_MODE']=='server-EOF':time.sleep(.8)
    else:
        while True:signal.pause()
else:
    data=json.loads(Path(os.environ['AUDIO_DATA']).read_text())
    print(json.dumps(data['info'] if sys.argv[-1]=='info' else
                     {k.replace('-','_'):v for k,v in data.items() if k!='info'}))
'''


def wait_for(predicate):
    deadline = time.monotonic() + 4
    while not predicate():
        assert time.monotonic() < deadline, "audio child failed to start/stop"
        time.sleep(.01)


for mode in ("stdin-EOF", "TERM", "KILL", "query-KILL", "server-EOF"):
    with tempfile.TemporaryDirectory(prefix="isla-audio-lifetime-") as tmp:
        temp = Path(tmp)
        (temp / "fixture.json").write_text(json.dumps(fixture()))
        for binary in ("pactl", "parec"):
            (temp / binary).write_text(FAKE)
            (temp / binary).chmod(0o755)
        pids = temp / "pids"
        env = {**os.environ, "PATH": str(temp) + os.pathsep + os.environ["PATH"],
               "AUDIO_PIDS": str(pids), "AUDIO_DATA": str(temp / "fixture.json"), "AUDIO_MODE": mode}
        process = subprocess.Popen([sys.executable, str(args.bridge.resolve())], env=env,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        children = []
        try:
            if mode != "query-KILL":
                process.stdin.write(b'{"action":"meters","args":{"sources":["sink.a.monitor"]}}\n')
                process.stdin.flush()
            wait_for(lambda: pids.exists() and len(pids.read_text().splitlines()) >=
                     (1 if mode == "query-KILL" else 2))
            children = [int(pid) for pid in pids.read_text().splitlines()]
            if mode == "stdin-EOF":
                process.stdin.close()
            elif mode in ("KILL", "query-KILL"):
                process.kill()
            elif mode == "TERM":
                process.terminate()
            process.wait(timeout=4)
            assert process.returncode == (-signal.SIGKILL if "KILL" in mode else 0), process.stderr.read()
            wait_for(lambda: not any(tree(pid) for pid in children))
            print("PASS:", mode, "leaves no live child")
        finally:
            stop(process)
            for pid in children:
                if tree(pid):
                    os.kill(pid, signal.SIGKILL)
            for pipe in (process.stdin, process.stdout, process.stderr):
                if pipe and not pipe.closed:
                    pipe.close()
