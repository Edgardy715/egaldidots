#!/usr/bin/env python3
"""Registro local finito de qs: /proc, GPU NVIDIA opcional y contexto de sesión."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time

spec = importlib.util.spec_from_file_location('process_sample', Path(__file__).with_name('sample-process.py'))
proc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proc)


def command(argv):
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=8)
        return result.stdout.strip() if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def gpu_row(text, pid):
    for line in (text or '').splitlines():
        fields = line.split()
        if len(fields) >= 12 and fields[1] == str(pid):
            return {'sm_percent': int(fields[3]) if fields[3].isdigit() else None,
                    'vram_mib': int(fields[9]) if fields[9].isdigit() else None}
    return None


def identity(process):
    return proc.counters((process / 'stat').read_text())


def record(pid, expected_start):
    process = Path('/proc') / str(pid)
    counters = identity(process)
    if counters['start_ticks'] != expected_start:
        raise RuntimeError('PID reutilizado')
    return dict(monotonic_s=time.monotonic(), **counters, **proc.memory(process))


def run(args):
    args.output.mkdir(parents=True, exist_ok=False)
    process = Path('/proc') / str(args.pid)
    expected = identity(process)['start_ticks']
    start = time.monotonic()
    status = dict(state='running', pid=args.pid, collector_pid=os.getpid(), start_ticks=expected,
                  started_utc=datetime.now(timezone.utc).isoformat(), requested_seconds=args.seconds,
                  interval_seconds=args.interval, samples=0)
    summary = args.output / 'status.json'

    def save_status():
        temporary = summary.with_suffix('.tmp')
        temporary.write_text(json.dumps(status, indent=2) + '\n')
        temporary.replace(summary)

    save_status()
    before_log = command(['qs', 'log', '--pid', str(args.pid), '-t', '1000'])
    (args.output / 'shell-start.txt').write_text(before_log or '')
    previous = None
    try:
        with (args.output / 'samples.jsonl').open('w') as log:
            while True:
                try:
                    current = record(args.pid, expected)
                except (FileNotFoundError, ProcessLookupError):
                    status['state'] = 'pid-exited'
                    break
                current['elapsed_s'] = current['monotonic_s'] - start
                current['utc'] = datetime.now(timezone.utc).isoformat()
                current['cpu_percent'] = None if previous is None else 100 * (current['cpu_ticks'] - previous['cpu_ticks']) / os.sysconf('SC_CLK_TCK') / (current['monotonic_s'] - previous['monotonic_s'])
                current['gpu'] = gpu_row(command(['nvidia-smi', 'pmon', '-c', '1', '-s', 'um']), args.pid)
                current['playback'] = command(['playerctl', 'status'])
                session = os.environ.get('XDG_SESSION_ID')
                current['idle_hint_advisory'] = command(['loginctl', 'show-session', session, '-p', 'IdleHint', '--value']) if session else None
                log.write(json.dumps(current) + '\n')
                log.flush()
                previous = current
                status.update(samples=status['samples'] + 1, elapsed_seconds=current['elapsed_s'])
                save_status()
                remaining = args.seconds - (time.monotonic() - start)
                if remaining <= 0:
                    status['state'] = 'completed'
                    break
                time.sleep(min(remaining, max(0, start + status['samples'] * args.interval - time.monotonic())))
    except Exception as error:
        status.update(state='error', error=str(error))
        raise
    finally:
        after_log = command(['qs', 'log', '--pid', str(args.pid), '-t', '1000'])
        (args.output / 'shell-end.txt').write_text(after_log or '')
        status['possible_reload'] = None if before_log is None or after_log is None else after_log.count('Reloading configuration') > before_log.count('Reloading configuration')
        status['elapsed_seconds'] = time.monotonic() - start
        status['ended_utc'] = datetime.now(timezone.utc).isoformat()
        save_status()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int)
    parser.add_argument('--seconds', type=proc.positive, default=7200)
    parser.add_argument('--interval', type=proc.positive, default=30)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        assert gpu_row('0 123 G - - - - - - 59 0 qs', 123) == {'sm_percent': None, 'vram_mib': 59}
        assert gpu_row('0 123 G 2 1 - - - - 60 0 qs', 123)['sm_percent'] == 2
        assert gpu_row('# header', 123) is None
        assert gpu_row('0 123 G - - - - - - 59 0 qs', 456) is None
        first = identity(Path('/proc') / str(os.getpid()))
        assert record(os.getpid(), first['start_ticks'])['Pss_kib'] > 0
        try:
            record(os.getpid(), first['start_ticks'] + 1)
            raise AssertionError('Aceptó otro starttime')
        except RuntimeError:
            pass
        print('PASS: GPU soportada/no disponible, filtro PID, PSS y rechazo PID reutilizado')
    else:
        if args.pid is None or args.pid <= 0 or args.output is None:
            parser.error('se requieren --pid positivo y --output nuevo')
        run(args)
