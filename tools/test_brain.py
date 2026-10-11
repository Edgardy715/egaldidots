"""Isolated assertions for catalog coverage, privacy and live search."""
import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile

spec = importlib.util.spec_from_file_location('brain', Path(__file__).with_name('brain.py'))
brain = importlib.util.module_from_spec(spec)
spec.loader.exec_module(brain)
with tempfile.TemporaryDirectory() as tmp:
    brain.ROOT = Path(tmp) / 'project'
    brain.VAULT = Path(tmp) / 'vault'
    brain.ROOT.mkdir()
    (brain.ROOT / '.gitignore').write_text('private.env\n')
    (brain.ROOT / 'private.env').write_text('UNIQUE_PRIVATE_VALUE=hidden\n')
    (brain.ROOT / 'Widget.qml').write_text('import QtQuick\nItem {\n property string title: "first"\n}\n')
    (brain.ROOT / 'Caller.qml').write_text('Widget {}\n')
    (brain.ROOT / 'image.png').write_bytes(b'\x00\xff\x00')
    with contextlib.redirect_stdout(io.StringIO()):
        brain.refresh()
    cards = brain.VAULT / 'Archivos'
    assert (cards / 'private.env.md').is_file()
    assert 'UNIQUE_PRIVATE_VALUE' not in (cards / 'private.env.md').read_text()
    assert 'property string title' in (cards / 'Widget.qml.md').read_text()
    assert 'Caller.qml' in (cards / 'Widget.qml.md').read_text()
    assert 'no indexadas' in (cards / 'image.png.md').read_text()
    (brain.ROOT / 'Widget.qml').write_text('Item { property string title: "UPDATED_LIVE" }\n')
    _, texts = brain.inventory()
    assert 'UPDATED_LIVE' in texts['Widget.qml']
    assert 'private.env' not in texts
    (brain.ROOT / 'Caller.qml').unlink()
    (brain.VAULT / 'Nota personal.md').write_text('keep')
    with contextlib.redirect_stdout(io.StringIO()):
        brain.refresh()
    assert not (cards / 'Caller.qml.md').exists()
    assert (brain.VAULT / 'Nota personal.md').read_text() == 'keep'
    assert (brain.VAULT / 'Carpetas/Raiz.md').exists()
print('PASS: complete catalog, private content excluded, binary handling, live content, stale cards, personal notes preserved')
