#!/usr/bin/env python3
"""Synthetic protocol/cadence plus original lifecycle suite, without audio access."""
import importlib.util
import json
import math
import os
from pathlib import Path
import selectors
import subprocess
import tempfile
import time
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('lifecycle', ROOT/'bar/tests/cava-rust-lifecycle.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.BINARY = HERE/'smooth.sh'

with tempfile.TemporaryDirectory(prefix='isla-smooth-protocol-') as directory:
    work = Path(directory)
    for name in ['pactl', 'cava', 'parec']:
        path = work/name
        path.write_text(module.FAKE)
        path.chmod(0o755)
    (work/'state').write_text(json.dumps(module.STATE))
    env = dict(os.environ, PATH=str(work)+':'+os.environ['PATH'], ISLA_CAVA_LIFECYCLE=str(work))
    proc = subprocess.Popen([str(module.BINARY), '--parent',str(os.getpid()),'--identity','isla-lifecycle-fixture'], env=env, stdout=subprocess.PIPE)
    frames = []
    started = time.monotonic()
    buffer = b''
    try:
        selector = selectors.DefaultSelector()
        selector.register(proc.stdout, selectors.EVENT_READ)
        while time.monotonic()-started < 1.6:
            if not selector.select(timeout=.1):
                continue
            buffer += os.read(proc.stdout.fileno(),65536)
            while b'\n' in buffer:
                line, buffer = buffer.split(b'\n',1)
                values = list(map(float,line.split()))
                assert len(values) == 24 and all(math.isfinite(v) and 0 <= v <= 1 for v in values), line
                if any(values):
                    frames.append((time.monotonic(),values))
        assert len(frames) >= 70, len(frames)
        hz = (len(frames)-1)/(frames[-1][0]-frames[0][0])
        assert 55 < hz < 65, hz
        assert frames[-1][1][0] > frames[0][1][0]
        print(json.dumps({'frames':len(frames),'observed_hz':hz,'duration_s':time.monotonic()-started,'protocol':'24 normalized doubles','audio':'synthetic'},indent=2),flush=True)
    finally:
        proc.terminate()
        proc.wait(timeout=2)
        proc.stdout.close()
        selector.close()
    module.wait_for(lambda: all(not module.alive(json.loads(line)['pid']) for line in (work/'children').read_text().splitlines()),'fake child survived')

# The inherited backpressure test assumes <=150-byte integer frames. Smoothed
# doubles need <=600 bytes; keep all lifecycle assertions and change that bound.
source = (ROOT/'bar/tests/cava-rust-lifecycle.py').read_text().replace('capacity - 150','capacity - 600')
namespace = {'__name__':'lifecycle_smooth','__file__':str(ROOT/'bar/tests/cava-rust-lifecycle.py')}
exec(compile(source,str(ROOT/'bar/tests/cava-rust-lifecycle.py'),'exec'),namespace)
namespace['BINARY'] = HERE/'smooth.sh'
result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(namespace['Lifecycle']))
if not result.wasSuccessful():
    raise SystemExit(1)
