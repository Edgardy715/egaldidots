#!/usr/bin/env python3
"""Check palette build bytes and the offscreen runtime preview."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

bar = Path(__file__).resolve().parents[1]
pack = bar / 'pets/packs/mimo'
tool = bar / 'pets/tools/petpack.py'
names = ['atlas.png', 'atlas-coral.png', 'atlas-lavanda.png', 'atlas-arena.png', 'atlas.json']
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('petpack', tool)
petpack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(petpack)
data = json.loads((pack / 'pet.json').read_text())
assert petpack.validate(data) == ([], [])
bad = json.loads(json.dumps(data))
bad['paletteVariants']['coral']['x'] = '#ffffff'
assert any('invalid color' in error for error in petpack.validate(bad)[0])
bad = json.loads(json.dumps(data))
bad['paletteVariants']['coral']['b'] = '#1c2a2d'
assert any('low contrast' in warning for warning in petpack.validate(bad)[1])

def build():
    result = subprocess.run(['python', str(tool), 'build', str(pack)], capture_output=True, text=True, check=True)
    assert 'warning:' not in result.stderr, result.stderr
    return {name: hashlib.sha256((pack / name).read_bytes()).hexdigest() for name in names}

assert build() == build(), 'atlas build is not reproducible'
with tempfile.TemporaryDirectory(prefix='isla-pets-palette-') as folder:
    runtime = Path(folder) / 'runtime'
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, ISLA_CONFIG=str(Path(folder) / 'shell.json'), XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen')
    try:
        result = subprocess.run(['quickshell', '-p', str(bar / 'pets-preview-regression.qml')],
                                env=env, capture_output=True, text=True, timeout=20)
    except subprocess.TimeoutExpired as error:
        raise AssertionError((error.stdout or b'').decode(errors='replace')[-3000:] +
                             (error.stderr or b'').decode(errors='replace')[-3000:]) from error
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'PASS: live atlas' in output, output[-6000:]
    assert 'Failed to compile' not in output and 'Failed to load shader' not in output, output[-6000:]
    saved = json.loads((Path(folder) / 'shell.json').read_text())
    assert saved['pets']['palette'] == 'coral' and saved['pets']['enabled'] is True
print('PASS: reproducible atlases and offscreen live palette/preview')
