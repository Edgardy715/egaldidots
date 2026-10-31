"""Isolated service contract: no network, notification server or real installer."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="isla-updates-service-") as directory:
    root = Path(directory)
    shutil.copytree(source, root / "bar")
    (root / "shell.json").write_text('{"updates":{"enabled":false,"notifications":true}}')
    (root / "bar/Singletons/Notifs.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property int calls: 0
    property var actions: []
    function postLocal(summary, body, items) { calls++; actions=items }
}
''')
    (root / "bar/scripts/system-updates.py").write_text('''import json, os, sys, time
from pathlib import Path
state=Path(os.environ['ISLA_TEST_COUNTER'] + '-install')
def emit(**value):
    print(json.dumps(dict(source='system', **value)), flush=True)
if sys.argv[1] == 'status':
    print(json.dumps({"active": ""})); sys.exit(0)
if sys.argv[1] == 'cancel':
    (state.parent / (state.name + '-cancel')).touch(); print('{"cancelled": true}'); sys.exit(0)
if sys.argv[1] == 'install':
    runs=int(state.read_text())+1 if state.exists() else 1
    state.write_text(str(runs))
    emit(event='phase', phase='auth', done=0, total=2, cancellable=False)
    if runs == 1:
        emit(event='phase', phase='download', done=1, total=2, cancellable=True)
        marker=state.parent / (state.name + '-cancel')
        for _ in range(100):
            if marker.exists(): break
            time.sleep(.05)
        emit(event='result', result='cancelled', code='cancelled', snapshot='', reboot=False, changed=0)
        sys.exit(1)
    emit(event='phase', phase='install', done=1, total=2, cancellable=False)
    emit(event='result', result='error', code='partial', snapshot='42', reboot=False, changed=1)
    sys.exit(1)
if sys.argv[1] == 'check':
    counter=Path(os.environ['ISLA_TEST_COUNTER'])
    count=int(counter.read_text())+1 if counter.exists() else 1
    counter.write_text(str(count))
    if count == 2:
        print('invalid JSON'); sys.exit(0)
    if count == 3:
        print('Simulated bridge failure', file=sys.stderr); sys.exit(1)
print(json.dumps({"system":{"count":2,"packages":["a 1 -> 2","b 1 -> 2"]},
"aur":{"count":0,"error":"network"},"flatpak":{"count":0,"supported":False},
"shell":{"count":1,"dirty":True,"blocked":"dirty"},"checkedAt":"2026-10-29T12:00:00Z"}))
''')
    env = dict(os.environ, ISLA_CONFIG=str(root / "shell.json"),
               XDG_STATE_HOME=str(root / "state"), QT_QPA_PLATFORM="offscreen")
    for replay in ("0", "1"):
        counter=root / ("checks-"+replay)
        env["ISLA_TEST_COUNTER"]=str(counter)
        result = subprocess.run(["qs", "-p", str(root / "bar/updates-service-regression.qml")],
                                env=dict(env, ISLA_TEST_REPLAY=replay), capture_output=True, text=True, timeout=15)
        log = result.stdout + result.stderr
        print(log)
        assert result.returncode == 0 and "PASS: Updates service" in log and "FAIL" not in log
    assert (root / "state/isla/updates-notice.json").exists()
