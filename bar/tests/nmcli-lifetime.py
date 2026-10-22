#!/usr/bin/env python3
"""Check the real Nmcli monitor with a silent, blocking fake; never use desktop PIDs."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
FAKE = '''#!/usr/bin/env python3
import os, signal, sys
from pathlib import Path
state = Path(os.environ['NMCLI_TEST_STATE'])
if sys.argv[1:] == ['monitor']:
    signal.signal(signal.SIGUSR1, lambda *_: print('network changed', flush=True))
    with (state / 'monitors').open('a') as stream:
        stream.write(str(os.getpid()) + '\\n')
    while True:
        signal.pause()
elif sys.argv[1:2] == ['-g']:
    with (state / 'reads').open('a') as stream:
        stream.write('read\\n')
elif sys.argv[1:] == ['radio', 'wifi']:
    print('enabled')
'''
QML = '''import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"
ShellRoot {
    property bool enabled: Nmcli.wifiEnabled
    IpcHandler {
        target: "fixture"
        function quit(): void { Qt.quit() }
        function reload(): void { Quickshell.reload(false) }
    }
}
'''


def alive(pid):
    try:
        return Path(f'/proc/{pid}/stat').read_text().split(') ')[1][0] != 'Z'
    except FileNotFoundError:
        return False


def wait_for(predicate, message, timeout=5):
    deadline = time.monotonic() + timeout
    while not predicate():
        assert time.monotonic() < deadline, message
        time.sleep(.02)


def lines(path):
    return path.read_text().splitlines() if path.exists() else []


failures = []
for mode in ('quit', 'SIGTERM', 'reload'):
    with tempfile.TemporaryDirectory(prefix='isla-nmcli-lifetime-') as directory:
        work = Path(directory)
        (work / 'Singletons').mkdir()
        (work / 'Singletons/Nmcli.qml').write_text((ROOT / 'Singletons/Nmcli.qml').read_text())
        (work / 'Singletons/qmldir').write_text('singleton Nmcli Nmcli.qml\n')
        (work / 'services').symlink_to(ROOT / 'services', target_is_directory=True)
        (work / 'shell.qml').write_text(QML)
        (work / 'nmcli').write_text(FAKE)
        (work / 'nmcli').chmod(0o755)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory,
                   NMCLI_TEST_STATE=directory, PATH=directory + os.pathsep + os.environ['PATH'])
        with (work / 'output.log').open('w+') as log:
            process = subprocess.Popen(['quickshell', '-p', directory], env=env,
                                       stdout=log, stderr=subprocess.STDOUT)
            def call(method):
                result = subprocess.run(['quickshell', '-p', directory, 'ipc', 'call', 'fixture', method],
                                        env=env, capture_output=True, text=True, timeout=5)
                assert result.returncode == 0, result.stdout + result.stderr
            try:
                wait_for(lambda: len(lines(work / 'monitors')) == 1, 'monitor not started')
                first = int(lines(work / 'monitors')[0])
                assert Path(f'/proc/{first}/stat').read_text().split(') ')[1].split()[1] == str(process.pid), 'monitor must exec directly under Quickshell'
                wait_for(lambda: len(lines(work / 'reads')) >= 1, 'initial read missing')
                # Event refresh and restart must survive lifecycle hardening.
                before = len(lines(work / 'reads'))
                os.kill(first, signal.SIGUSR1)
                wait_for(lambda: len(lines(work / 'reads')) > before, 'monitor event lost')
                os.kill(first, signal.SIGTERM)
                wait_for(lambda: len(lines(work / 'monitors')) == 2, 'monitor did not restart')
                if mode == 'reload':
                    call('reload')
                    wait_for(lambda: len(lines(work / 'monitors')) >= 3, 'reload monitor missing')
                    time.sleep(.3)
                    current = [int(pid) for pid in lines(work / 'monitors') if alive(int(pid))]
                    assert len(current) == 1, f'reload left monitors {current}'
                    process.terminate()
                elif mode == 'quit':
                    call('quit')
                else:
                    process.terminate()
                process.wait(timeout=5)
                time.sleep(.15)
                survivors = [int(pid) for pid in lines(work / 'monitors') if alive(int(pid))]
                assert not survivors, f'{mode} left orphan monitors {survivors}'
                print(f'PASS: {mode}; event refresh, crash restart, no surviving monitor')
            except Exception as error:
                failures.append(f'{mode}: {error}')
                log.flush()
                log.seek(0)
                print(log.read())
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
                for pid in map(int, lines(work / 'monitors')):
                    if alive(pid):
                        os.kill(pid, signal.SIGKILL)
assert not failures, '\n'.join(failures)

# A parent that died before prctl was armed must not allow exec of the monitor.
with tempfile.TemporaryDirectory(prefix='isla-nmcli-parent-race-') as directory:
    work = Path(directory)
    (work / 'nmcli').write_text(FAKE)
    (work / 'nmcli').chmod(0o755)
    result = subprocess.run([sys.executable, str(ROOT / 'services/nmcli_monitor.py'), '0'],
                            env=dict(os.environ, NMCLI_TEST_STATE=directory,
                                     PATH=directory + os.pathsep + os.environ['PATH']), timeout=5)
    assert result.returncode == 1 and not (work / 'monitors').exists(), 'dead parent permitted exec'
    print('PASS: parent identity mismatch aborts before exec')
