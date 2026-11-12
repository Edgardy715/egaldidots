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
    state = root / 'locked'
    for name, content in {
        # Fake compositor lock state, shared through a file.
        'hyprctl': '#!/bin/sh\n'
                   'case "$*" in\n'
                   '  *monitors*) echo "[]" ;;\n'
                   '  *locked*) test -z "${FAKE_OLD_HYPR:-}" || { echo "unknown request"; exit 0; }\n'
                   '    test -z "${FAKE_NO_LOCKED:-}" || exit 1; printf \'{"locked": %s}\\n\' "$(cat "$FAKE_STATE")" ;;\n'
                   'esac\n',
        'quickshell': '#!/bin/sh\n'
                      'test -z "${QS_LOCK_PREVIEW:-}" || exit 88\n'
                      'test "${QS_DISABLE_CRASH_HANDLER:-}" = 1 || exit 89\n'
                      'test ! -e /proc/self/fd/9 || exit 90\n'
                      'printf "quickshell:%s:%s\\n" "$1" "$2"\n'
                      'case "${FAKE_MODE:-ok}" in\n'
                      '  ok) echo true > "$FAKE_STATE"; sleep 0.3; echo false > "$FAKE_STATE" ;;\n'
                      '  crash) echo true > "$FAKE_STATE"; sleep 0.2 ;;\n'
                      '  hang) exec sleep 30 ;;\n'
                      'esac\n'
                      'exit "${FAKE_EXIT:-0}"\n',
        'hyprlock': '#!/bin/sh\necho fallback\n',
    }.items():
        script = root / name
        script.write_text(content)
        script.chmod(0o755)
    base = dict(os.environ, PATH=f'{root}:' + os.environ['PATH'], XDG_RUNTIME_DIR=str(root),
                QS_LOCK_PREVIEW='1', FAKE_STATE=str(state), ISLA_LOCK_CONFIRM_SECONDS='1')

    def run(locked='false', **extra):
        state.write_text(locked + '\n')
        return subprocess.run([str(launcher)], env=dict(base, **extra), capture_output=True,
                              text=True, timeout=20).stdout

    out = run()
    assert 'quickshell:--path:' in out and 'fallback' not in out, out
    assert 'fallback' in run(FAKE_MODE='quiet'), 'exit 0 without ever locking must fall back'
    assert 'fallback' in run(FAKE_MODE='hang'), 'never locking within the deadline must fall back'
    assert 'fallback' in run(FAKE_MODE='crash', FAKE_EXIT='3'), 'crash while locked must fall back'
    assert 'fallback' in run(FAKE_MODE='crash'), 'exit 0 while still locked must fall back'
    out = run(locked='true')
    assert 'quickshell' not in out and 'fallback' not in out, 'already locked: nothing to do'
    out = run(FAKE_MODE='quiet', FAKE_NO_LOCKED='1')
    assert 'quickshell:' in out and 'fallback' not in out, 'without lock state, exit 0 is trusted'
    assert 'fallback' in run(FAKE_MODE='quiet', FAKE_NO_LOCKED='1', FAKE_EXIT='3')
    out = run(FAKE_OLD_HYPR='1')
    assert 'quickshell:' in out and 'fallback' not in out, 'unsupported locked request must not be trusted: ' + out
    assert 'fallback' in run(FAKE_MODE='hang', ISLA_LOCK_CONFIRM_SECONDS='1s'), 'malformed deadline still falls back'

    # isla-lock: the entry point for hypridle, SUPER+L and Session.
    entry = Path(__file__).resolve().parents[2] / 'fish/.local/bin/isla-lock'
    def enter(wrapper):
        env = dict(base, XDG_DATA_HOME=str(root / 'entry'))
        w = root / 'entry/quickshell-lockscreen/lock.sh'
        w.parent.mkdir(parents=True, exist_ok=True)
        if w.exists():
            w.unlink()
        if wrapper is not None:
            w.write_text(wrapper); w.chmod(0o755)
        return subprocess.run([str(entry)], env=env, capture_output=True, text=True, timeout=10).stdout
    assert 'fallback' in enter(None), 'missing launcher must fall back'
    assert 'fallback' in enter('#!/bin/sh\nexec /nonexistent/lock.sh\n'), 'dangling launcher must fall back'
    assert enter('#!/bin/sh\necho isla\n').strip() == 'isla'
print('PASS: lock installer backup/XDG, preview guard, verified lock with hyprlock fallback, isla-lock entry')
