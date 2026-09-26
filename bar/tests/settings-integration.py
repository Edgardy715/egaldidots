#!/usr/bin/env python3
"""Exercise the real QML service with an isolated config, never user settings."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

bar = Path(__file__).resolve().parents[1]
host = bar / 'settings-test-host.qml'
with tempfile.TemporaryDirectory(prefix='isla-settings-') as directory:
    folder = Path(directory)
    config = folder / 'new-directory' / 'shell.json'
    env = dict(os.environ, ISLA_CONFIG=str(config), QT_QPA_PLATFORM='offscreen')
    with (folder / 'host.log').open('w+') as log:
        process = subprocess.Popen(['quickshell', '-p', str(host)], env=env, stdout=log, stderr=log)
        def call(method, *args):
            result = subprocess.run(['quickshell', '-p', str(host), 'ipc', 'call', 'settings', method, *args],
                                    env=env, capture_output=True, text=True, timeout=3)
            if result.returncode:
                raise RuntimeError(result.stderr)
            return json.loads(result.stdout)

        def wait(predicate):
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                try:
                    result = call('get')
                    if predicate(result):
                        return result
                except (RuntimeError, ValueError):
                    pass
                time.sleep(0.05)
            raise AssertionError('Timed out waiting for settings')

        def replace(text):
            temporary = config.with_suffix('.new')
            temporary.write_text(text)
            temporary.replace(config)

        try:
            wait(lambda x: x['loaded'])
            assert call('schema')['sections']['appearance']['fontScale']['minimum'] == 0.75
            assert call('validate', '{"appearance":{"fontScale":0}}')['ok'] is False
            assert call('update', '{"appearance":{"fontScale":1.2},"custom":{"keep":7}}')['ok']
            assert call('get')['dirty']
            assert call('save')
            wait(lambda x: not x['saving'] and not x['dirty'] and not x['error'])
            assert json.loads(config.read_text())['custom']['keep'] == 7
            replace('{"appearance":{"fontScale":1.4},"custom":{"keep":9}}')
            wait(lambda x: x['effective']['appearance']['fontScale'] == 1.4)
            replace('{ broken')
            invalid = wait(lambda x: bool(x['error']))
            assert invalid['effective']['appearance']['fontScale'] == 1.4
            assert call('save') is False  # do not overwrite an invalid external edit
            replace('')
            empty = wait(lambda x: bool(x['error']))
            assert empty['effective']['appearance']['fontScale'] == 1.4
            replace('{"appearance":{"fontScale":1.3},"custom":{"keep":10}}')
            wait(lambda x: not x['error'] and x['effective']['appearance']['fontScale'] == 1.3)
            assert call('update', '{"appearance":{"fontScale":1.1}}')['ok']
            assert call('discard')
            assert call('get')['effective']['appearance']['fontScale'] == 1.3
            assert call('update', '{"appearance":{"clockSeconds":true}}')['ok']
            assert call('save')
            wait(lambda x: not x['saving'] and not x['dirty'] and not x['error'])
            saved = json.loads(config.read_text())
            assert saved['custom']['keep'] == 10 and saved['appearance']['clockSeconds']
            config.unlink()
            wait(lambda x: x['effective']['appearance']['fontScale'] == 1)
            assert call('update', '{"appearance":{"time12h":false}}')['ok']
            assert call('save')
            wait(lambda x: not x['saving'] and not x['dirty'] and not x['error'])
            assert json.loads(config.read_text())['appearance']['time12h'] is False
            print('PASS: settings IPC, missing directory, atomic save, file watch, invalid retention, discard, unknown keys, deletion')
        except Exception:
            log.flush()
            log.seek(0)
            print(log.read())
            raise
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
