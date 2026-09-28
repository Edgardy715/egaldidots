"""Exercise the production launcher using fake lock processes; never locks."""
import os
from pathlib import Path
import subprocess
import tempfile

launcher = Path(__file__).resolve().parents[1] / 'lockscreen/lock.sh'
installer = launcher.with_name('install.sh')
with tempfile.TemporaryDirectory(prefix='isla-launcher-') as directory:
    root = Path(directory)
    data = root / 'data'
    state = root / 'state'
    target = data / 'quickshell-lockscreen/lock.sh'
    target.parent.mkdir(parents=True)
    target.write_text('#!/bin/sh\necho previous\n')
    target.chmod(0o755)
    install_env = dict(os.environ, XDG_DATA_HOME=str(data), XDG_STATE_HOME=str(state))
    subprocess.run(['bash', str(installer)], env=install_env, capture_output=True, text=True, check=True)
    assert target.stat().st_mode & 0o111
    assert str(launcher) in target.read_text()
    backups = list((state / 'isla').glob('lockscreen-backup.*/lock.sh'))
    assert len(backups) == 1 and 'echo previous' in backups[0].read_text()
    for name, content in {
        'quickshell': '#!/bin/sh\ntest -z "${QS_LOCK_PREVIEW:-}" || exit 88\nprintf "quickshell:%s:%s\\n" "$1" "$2"\nexit "${FAKE_EXIT:-0}"\n',
        'hyprlock': '#!/bin/sh\necho fallback\n',
    }.items():
        script = root / name
        script.write_text(content)
        script.chmod(0o755)
    env = dict(os.environ, PATH=f'{root}:' + os.environ['PATH'],
               XDG_RUNTIME_DIR=str(root), QS_LOCK_PREVIEW='1')
    success = subprocess.run([str(launcher)], env=env, capture_output=True, text=True, check=True)
    assert 'quickshell:--path:' in success.stdout and 'fallback' not in success.stdout
    env['FAKE_EXIT'] = '3'
    failed = subprocess.run([str(launcher)], env=env, capture_output=True, text=True, check=True)
    assert 'fallback' in failed.stdout
print('PASS: lock installer backup/XDG and launcher preview guard, repository entry, failure fallback')
