#!/usr/bin/env python3
"""Muestrea PSS/RSS cada 30 s sin confundir un PID reutilizado con el original."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import time
import tempfile

spec = importlib.util.spec_from_file_location('process_sample', Path(__file__).with_name('sample-process.py'))
proc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proc)


def watch(pid, seconds, interval, output):
    process = Path('/proc') / str(pid)
    identity = proc.counters((process / 'stat').read_text())['start_ticks']
    start = time.monotonic()
    with output.open('w') as log:
        while True:
            if proc.counters((process / 'stat').read_text())['start_ticks'] != identity:
                raise RuntimeError('PID reutilizado')
            record = dict(pid=pid, elapsed_s=time.monotonic() - start, **proc.memory(process))
            log.write(json.dumps(record) + '\n')
            log.flush()
            remaining = seconds - (time.monotonic() - start)
            if remaining <= 0:
                break
            time.sleep(min(interval, remaining))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int)
    parser.add_argument('--seconds', type=proc.positive, default=600)
    parser.add_argument('--interval', type=proc.positive, default=30)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'samples.jsonl'
            watch(os.getpid(), 0.05, 0.02, output)
            rows = [json.loads(line) for line in output.read_text().splitlines()]
            assert len(rows) >= 3 and all(row['Pss_kib'] > 0 for row in rows)
            assert rows[-1]['elapsed_s'] >= 0.05
        print('PASS: PSS real, cadencia, salida JSONL y final acotado')
    else:
        if args.pid is None or args.pid <= 0 or args.output is None:
            parser.error('se requieren --pid positivo y --output')
        watch(args.pid, args.seconds, args.interval, args.output)
