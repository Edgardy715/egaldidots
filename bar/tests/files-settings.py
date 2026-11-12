#!/usr/bin/env python3
"""Files settings section: defaults, validation and save round-trip (isolated ISLA_CONFIG)."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

bar = Path(__file__).resolve().parents[1]
host = bar / 'settings-test-host.qml'
DEFAULTS = {'view': 'grid', 'showHidden': False, 'iconSize': 96, 'sortField': 'name',
            'sortReversed': False, 'dirsFirst': True}
with tempfile.TemporaryDirectory(prefix='isla-files-settings-') as directory:
    folder = Path(directory)
    config = folder / 'cfg' / 'shell.json'
    env = dict(os.environ, ISLA_CONFIG=str(config), QT_QPA_PLATFORM=os.environ.get('QT_QPA_PLATFORM', 'offscreen'))
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

        try:
            wait(lambda x: x['loaded'])
            assert call('get')['effective']['files'] == DEFAULTS
            schema = call('schema')['sections']['files']
            assert schema['iconSize']['minimum'] == 48 and schema['iconSize']['maximum'] == 160
            assert schema['view']['options'] == ['grid', 'list']
            assert schema['sortField']['options'] == ['name', 'modified', 'size', 'type']
            assert any(s['id'] == 'files' for s in call('catalog')['sectionOrder'])
            assert call('validate', '{"files":{"iconSize":5}}')['ok'] is False
            assert call('validate', '{"files":{"iconSize":161}}')['ok'] is False
            assert call('validate', '{"files":{"view":"x"}}')['ok'] is False
            assert call('validate', '{"files":{"sortField":"x"}}')['ok'] is False
            assert call('validate', '{"files":{"showHidden":"yes"}}')['ok'] is False
            assert call('update', '{"files":{"iconSize":5}}')['ok'] is False
            assert call('get')['effective']['files']['iconSize'] == 96
            assert call('update', '{"files":{"view":"list","showHidden":true,"iconSize":128,'
                                  '"sortField":"size","sortReversed":true,"dirsFirst":false}}')['ok']
            assert call('save')
            wait(lambda x: not x['saving'] and not x['dirty'] and not x['error'])
            assert json.loads(config.read_text())['files'] == {
                'view': 'list', 'showHidden': True, 'iconSize': 128,
                'sortField': 'size', 'sortReversed': True, 'dirsFirst': False}
            assert call('get')['effective']['files']['view'] == 'list'
            print('PASS: files settings defaults, validation and round-trip')
        finally:
            process.terminate()
            process.wait(timeout=5)
