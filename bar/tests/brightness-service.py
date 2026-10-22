#!/usr/bin/env python3
"""Test Brightness against fake sysfs commands; never run sh or polkit."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FAKE = r'''#!/usr/bin/env python3
import fcntl, json, os, re, sys, time
from pathlib import Path
state = Path(os.environ['BRIGHTNESS_TEST_STATE'])
args = sys.argv[1:]
if args[:1] == ['mode']:
    (state / 'mode').write_text(args[1])
    sys.exit(0)
if Path(sys.argv[0]).name == 'cat':
    value = (state / 'actual').read_text()
    if (state / 'slow-read').exists():
        time.sleep(.35)
    print(value)
    sys.exit(0)
command = args[1]
if command.startswith('for d in '):
    print('fake 100')
    sys.exit(0)
match = re.search(r'echo (\d+) > /sys/class/backlight/fake/brightness', command)
assert match, command
value = int(match[1])
fallback = 'pkexec' in command
mode = (state / 'mode').read_text()
with (state / 'lock').open('a') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    stats = json.loads((state / 'stats').read_text())
    stats['active'] += 1
    stats['max_active'] = max(stats['max_active'], stats['active'])
    stats['starts'].append(['fallback' if fallback else 'direct', value, mode])
    (state / 'stats').write_text(json.dumps(stats))
time.sleep(.16 if fallback else .06)
success = mode == 'direct' or fallback and mode == 'fallback'
if success:
    (state / 'actual').write_text(str(value))
with (state / 'lock').open('a') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    stats = json.loads((state / 'stats').read_text())
    stats['active'] -= 1
    if success:
        stats['writes'].append(value)
    (state / 'stats').write_text(json.dumps(stats))
sys.exit(0 if success else 1)
'''
QML = r'''
import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"
ShellRoot {
    id: test
    property int phase: 0
    property var events: []
    property int failures: 0
    property bool queuedDuringFallback: false
    Connections {
        target: Brightness
        function onBrightnessChanged(value) { test.events.push(value) }
        function onWriteFailed() { test.failures++ }
    }
    function check(condition, message) {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1) }
        return condition
    }
    Process {
        id: mode
        onExited: code => {
            if (test.phase === 3) {
                test.phase = 4
                Brightness.setPercent(65)
                Brightness.setPercent(75)
                Brightness.setPercent(85)
            } else if (test.phase === 5) {
                test.phase = 6
                Brightness.setPercent(55)
            }
        }
    }
    Process {
        id: slowRead
        command: ["python3", "-c", "import os,pathlib; (pathlib.Path(os.environ['BRIGHTNESS_TEST_STATE'])/'slow-read').touch()"]
        onExited: {
            test.phase = 8
            Brightness.refresh()
            beginWrite.start()
        }
    }
    Timer {
        id: beginWrite
        interval: 45
        onTriggered: {
            Brightness.setPercent(35)
            staleReadCheck.start()
        }
    }
    Timer {
        id: staleReadCheck
        interval: 500
        onTriggered: {
            test.check(Brightness.rawBrightness === 35, "stale read cannot overwrite completed write")
            console.log("PASS: brightness burst targets, accumulated steps, fallback serialization/denial and stale reads")
            Qt.quit()
        }
    }
    Timer {
        interval: 10; repeat: true; running: true
        onTriggered: {
            if (test.phase === 6 && Brightness._testFallbackRunning && !test.queuedDuringFallback) {
                test.queuedDuringFallback = true
                Brightness.setPercent(95)
            }
            if (!Brightness.available || Brightness._testReadRunning || Brightness._testWriteRunning || Brightness._writing) return
            if (phase === 0) {
                if (!test.check(Brightness.rawBrightness === 50, "fake initial brightness")) return
                phase = 1
                events = []
                Brightness.setPercent(60)
                Brightness.setPercent(70)
                Brightness.setPercent(80)
            } else if (phase === 1) {
                if (!test.check(Brightness.rawBrightness === 80 && JSON.stringify(events) === "[60,80]", "slider writes and confirmed events match")) return
                phase = 2
                events = []
                Brightness.decrease(); Brightness.decrease(); Brightness.decrease()
            } else if (phase === 2) {
                if (!test.check(Brightness.rawBrightness === 50 && JSON.stringify(events) === "[70,50]", "rapid keys accumulate")) return
                phase = 3
                mode.exec(["sh", "mode", "fallback"])
            } else if (phase === 4) {
                if (!test.check(Brightness.rawBrightness === 85 && Brightness.lastWriteOk, "fallback uses latest burst target")) return
                phase = 5
                mode.exec(["sh", "mode", "deny"])
            } else if (phase === 6) {
                if (!test.check(queuedDuringFallback && failures === 1 && !Brightness.lastWriteOk && Brightness.rawBrightness === 85,
                                "denied fallback ends queued burst without another authorization")) return
                phase = 7
                mode.exec(["sh", "mode", "direct"])
                // The helper mode switch finishes before this separate process starts the read.
                delayedRead.start()
            }
        }
    }
    Timer { id: delayedRead; interval: 60; onTriggered: slowRead.running = true }
    Timer { interval: 6000; running: true; onTriggered: { console.error("FAIL: timeout"); Qt.exit(1) } }
}
'''

with tempfile.TemporaryDirectory(prefix='isla-brightness-') as directory:
    work = Path(directory)
    (work / 'Singletons').mkdir()
    source = (ROOT / 'Singletons/Brightness.qml').read_text()
    source = source.replace('property bool available: false', '''readonly property bool _testReadRunning: readProc.running
    readonly property bool _testFallbackRunning: fallbackProc.running
    readonly property bool _testWriteRunning: writeProc.running
    property bool available: false''')
    (work / 'Singletons/Brightness.qml').write_text(source)
    (work / 'Singletons/qmldir').write_text('singleton Brightness Brightness.qml\n')
    (work / 'test.qml').write_text(QML)
    for command in ('sh', 'cat'):
        (work / command).write_text(FAKE)
        (work / command).chmod(0o755)
    (work / 'mode').write_text('direct')
    (work / 'actual').write_text('50')
    (work / 'stats').write_text(json.dumps(dict(active=0, max_active=0, starts=[], writes=[])))
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', BRIGHTNESS_TEST_STATE=str(work),
               PATH=str(work) + os.pathsep + os.environ['PATH'])
    result = subprocess.run([shutil.which('quickshell'), '-p', str(work / 'test.qml')],
                            env=env, text=True, capture_output=True, timeout=10)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'PASS:' in output and 'FAIL:' not in output, output
    assert 'TypeError' not in output and 'ReferenceError' not in output, output
    stats = json.loads((work / 'stats').read_text())
    assert stats['max_active'] == 1 and stats['active'] == 0, stats
    assert stats['writes'] == [60, 80, 70, 50, 85, 35], stats
    assert stats['starts'] == [['direct', 60, 'direct'], ['direct', 80, 'direct'],
                               ['direct', 70, 'direct'], ['direct', 50, 'direct'],
                               ['direct', 65, 'fallback'], ['fallback', 85, 'fallback'],
                               ['direct', 55, 'deny'], ['fallback', 55, 'deny'],
                               ['direct', 35, 'direct']], stats
    print('PASS: Brightness; slider coalescing, accumulated steps, immutable confirmed values, latest fallback, single authorization on denial and stale read protection')
