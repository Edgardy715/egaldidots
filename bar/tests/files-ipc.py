#!/usr/bin/env python3
"""IPC contract of the file explorer against an isolated quickshell instance (never HOME/user config)."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

bar = Path(__file__).resolve().parents[1]
host = bar / 'files-test-host.qml'


def rss(pid):
    for line in Path(f'/proc/{pid}/status').read_text().splitlines():
        if line.startswith('VmRSS:'):
            return int(line.split()[1])
    return 0


def main():
    with tempfile.TemporaryDirectory(prefix='isla-files-ipc-') as directory:
        folder = Path(directory)
        tree = folder / 'tree'
        (tree / 'with space #1').mkdir(parents=True)
        (tree / 'with space #1' / 'a b#c.txt').write_text('x')
        (folder / 'cfg').mkdir()
        env = dict(os.environ, ISLA_CONFIG=str(folder / 'cfg' / 'shell.json'), HOME=str(folder),
                   XDG_CONFIG_HOME=str(folder / 'cfg'), XDG_CACHE_HOME=str(folder / 'cache'),
                   QT_QPA_PLATFORM=os.environ.get('QT_QPA_PLATFORM', 'offscreen'))
        failures = []
        with (folder / 'host.log').open('w+') as log:
            process = subprocess.Popen(['quickshell', '-p', str(host)], env=env, stdout=log, stderr=log)

            def call(method, *args):
                result = subprocess.run(['quickshell', '-p', str(host), 'ipc', 'call', 'files', method, *args],
                                        env=env, capture_output=True, text=True, timeout=5)
                if result.returncode:
                    raise RuntimeError(result.stderr)
                return result.stdout.strip()

            def status():
                return json.loads(call('status'))

            def wait(predicate, label):
                deadline = time.monotonic() + 8
                last = None
                while time.monotonic() < deadline:
                    try:
                        last = status()
                        if predicate(last):
                            return last
                    except (RuntimeError, ValueError, subprocess.TimeoutExpired):
                        pass
                    time.sleep(0.05)
                raise AssertionError(f'timeout: {label} (last={last})')

            def check(value, label):
                if not value:
                    failures.append(label)
                    print('FAIL:', label)

            try:
                wait(lambda s: s['open'] is False, 'host ready')
                check(call('open', 'relative/path') == 'false', 'relative path rejected')
                check(call('open', '') == 'false', 'empty path rejected')
                check(call('open', str(tree / 'missing' / 'deeper')) == 'false', 'missing path under a missing folder rejected')
                # A missing child of an existing folder cannot be decided without reading: answers true
                # (async test -e) but opens nothing.
                check(call('open', str(tree / 'missing')) == 'true', 'missing child of a folder is decided async')
                time.sleep(0.5)
                check(not status()['open'], 'missing child opens no window')
                check(call('open', str(tree / 'missing' / 'deeper')) == 'false', 'missing nested path rejected')
                check(not status()['open'], 'rejections open nothing')

                check(call('open', str(tree)) == 'true', 'valid folder accepted')
                wait(lambda s: s['open'] and s['path'] == str(tree), 'window shows folder')
                check(call('open', str(tree / 'with space #1')) == 'true', 'second open accepted')
                wait(lambda s: s['open'] and s['path'] == str(tree / 'with space #1'), 'same window navigates')
                check(call('open', str(tree / 'with space #1' / 'a b#c.txt')) == 'true', 'file accepted')
                wait(lambda s: s['open'] and s['path'] == str(tree / 'with space #1'), 'file shows its folder')
                check(call('close') == 'true', 'close with a window returns true')
                wait(lambda s: not s['open'], 'closed')
                check(call('close') == 'false', 'close without window returns false')

                # A path created after a failed probe must be seen (no stale component cache).
                late = tree / 'late'
                check(call('open', str(late)) == 'true', 'not yet created: pending')
                time.sleep(0.4)
                check(not status()['open'], 'not yet created: no window')
                late.mkdir()
                check(call('open', str(late)) == 'true', 'created later is accepted')
                wait(lambda s: s['open'] and s['path'] == str(late), 'late folder shown')
                call('close')
                wait(lambda s: not s['open'], 'closed again')

                # FIFO and huge sparse file must never be read nor hang the shell.
                fifo = tree / 'pipe'
                os.mkfifo(fifo)
                started = time.monotonic()
                check(call('open', str(fifo)) == 'true', 'fifo accepted without reading')
                wait(lambda s: s['open'] and s['path'] == str(tree), 'fifo shows its folder')
                check(time.monotonic() - started < 3, 'fifo did not hang the shell')
                call('close')
                wait(lambda s: not s['open'], 'closed after fifo')
                big = tree / 'big.bin'
                with big.open('wb') as handle:
                    handle.truncate(2 * 1024 ** 3)
                rss_before = rss(process.pid)
                check(call('open', str(big)) == 'true', 'big file accepted')
                wait(lambda s: s['open'] and s['path'] == str(tree), 'big file shows its folder')
                growth = rss(process.pid) - rss_before
                check(growth < 300 * 1024, f'big file not read into memory (rss grew {growth} kB)')
                call('close')
                wait(lambda s: not s['open'], 'closed after big file')

                # Races: open(file) then close/toggle at once must leave no window behind.
                check(call('open', str(tree / 'with space #1' / 'a b#c.txt')) == 'true', 'file accepted for race')
                call('close')
                time.sleep(0.5)
                check(not status()['open'], 'open+close leaves it closed')
                check(call('open', str(tree / 'with space #1' / 'a b#c.txt')) == 'true', 'file accepted for toggle race')
                call('toggle')
                time.sleep(0.5)
                check(not status()['open'], 'open+toggle leaves it closed')
                call('toggle')
                call('toggle')
                time.sleep(0.5)
                check(not status()['open'], 'toggle x2 fast leaves zero windows')

                check(call('toggle') == 'true', 'toggle opens')
                wait(lambda s: s['open'], 'toggle open')
                check(call('toggle') == 'true', 'toggle closes')
                wait(lambda s: not s['open'], 'toggle closed: zero windows')
            except Exception as error:
                failures.append(repr(error))
                print('FAIL:', repr(error))
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
            if failures:
                log.seek(0)
                print(log.read()[-3000:])
                return 1
    print('PASS: files ipc (relative/missing rejected, folder/file open, same window, close, toggle x2 leaves none)')
    return 0


raise SystemExit(main())
