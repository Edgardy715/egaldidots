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

        def replace(text):
            temporary = config.with_suffix('.new')
            temporary.write_text(text)
            temporary.replace(config)

        try:
            wait(lambda x: x['loaded'])
            schema = call('schema')
            assert schema['sections']['appearance']['barLayout']['options'] == ['split', 'compact']
            assert schema['sections']['appearance']['fontScale']['minimum'] == 0.75
            assert schema['sections']['appearance']['fontScale']['label'] == 'Tamaño de texto'
            catalog = call('catalog')
            assert catalog['availabilityIsLive'] is False
            assert catalog['sections']['appearance']['pillBlur']['availability'] == 'inactive'
            assert catalog['sections']['appearance']['clockSeconds']['availability'] == 'partial'
            assert catalog['requiredModules'][0]['id'] == 'pill'
            assert len(catalog['surfaces']) == 17
            assert any(surface['id'] == 'settings' for surface in catalog['surfaces'])
            assert catalog['optionalModules'][1]['dependencyMode'] == 'any'
            assert call('validate', '{"appearance":{"fontScale":0}}')['ok'] is False
            assert call('validate', '{"appearance":{"barLayout":"wide"}}')['ok'] is False
            for key, maximum in (('uiScale', 3), ('topGap', 4), ('appGap', 4)):
                assert call('validate', json.dumps({'appearance': {key: maximum}}))['ok']
                assert call('validate', json.dumps({'appearance': {key: 1e308}}))['ok'] is False
            assert call('get')['effective']['appearance']['barLayout'] == 'split'
            assert call('update', '{"appearance":{"barLayout":"compact"}}')['ok']
            assert call('get')['effective']['appearance']['barLayout'] == 'compact'
            assert call('update', '{"appearance":{"barLayout":"wide"}}')['ok'] is False
            assert call('get')['effective']['appearance']['barLayout'] == 'compact'
            assert call('discard')
            assert call('get')['effective']['appearance']['barLayout'] == 'split'
            assert call('update', '{"appearance":{"barLayout":"compact"}}')['ok']
            assert call('update', '{"appearance":{"fontScale":1.2},"custom":{"keep":7}}')['ok']
            assert call('get')['dirty']
            assert call('save')
            wait(lambda x: not x['saving'] and not x['dirty'] and not x['error'])
            assert json.loads(config.read_text())['custom']['keep'] == 7
            assert json.loads(config.read_text())['appearance']['barLayout'] == 'compact'
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
            visual = {'materialDepth': 0.6, 'mediaTransitions': False, 'menuSelectionAnchor': False}
            assert call('update', json.dumps({'appearance': visual}))['ok']
            assert call('save')
            wait(lambda x: not x['saving'] and not x['dirty'] and not x['error'])
            saved = json.loads(config.read_text())
            for key, value in visual.items():
                assert saved['appearance'][key] == value
            assert call('update', '{"appearance":{"materialDepth":0}}')['ok']
            assert call('discard')
            assert call('get')['effective']['appearance']['materialDepth'] == 0.6
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

with tempfile.TemporaryDirectory(prefix='isla-draft-conflict-') as directory:
    folder = Path(directory)
    config = folder / 'shell.json'
    config.write_text('{"profile":{"displayName":"Original"},"custom":{"keep":7}}')
    fixture = bar / 'config-draft-conflict-regression.qml'
    env = dict(os.environ, ISLA_CONFIG=str(config), QT_QPA_PLATFORM=os.environ.get('QT_QPA_PLATFORM', 'offscreen'))
    with (folder / 'host.log').open('w+') as log:
        process = subprocess.Popen(['quickshell', '-p', str(fixture)], env=env, stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                log.flush()
                log.seek(0)
                output = log.read()
                if 'DRAFT_READY' in output or process.poll() is not None:
                    break
                time.sleep(0.05)
            assert 'DRAFT_READY' in output, output
            replacement = folder / 'replacement'
            replacement.write_text('{"profile":{"displayName":"Cambio externo"},"custom":{"keep":9}}')
            replacement.replace(config)
            assert process.wait(timeout=10) == 0
            log.flush()
            log.seek(0)
            output = log.read()
            assert 'PASS: external draft conflict, explicit edit, save and discard' in output, output
            saved = json.loads(config.read_text())
            assert saved['profile']['displayName'] == 'Mi decision'
            assert saved['custom']['keep'] == 9
            print('PASS: real editor, external reload conflict, save, discard and unknown key')
        except Exception:
            log.flush()
            log.seek(0)
            print(log.read())
            raise
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=3)
