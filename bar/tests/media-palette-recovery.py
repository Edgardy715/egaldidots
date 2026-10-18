#!/usr/bin/env python3
from collections import Counter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time

bar = Path(__file__).resolve().parents[1]
counts = Counter()
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass
    def do_GET(self):
        counts[self.path] += 1
        if self.path == '/slow.svg' or (self.path == '/timeout.svg' and counts[self.path] == 1):
            time.sleep(3)
        if self.path == '/missing.svg' or (self.path == '/flaky.svg' and counts[self.path] == 1):
            self.send_error(503)
            return
        self.send_response(200)
        self.end_headers()
        color = 'green' if self.path == '/flaky.svg' else 'blue'
        try:
            self.wfile.write((bar / f'tests/fixtures/artwork-{color}.svg').read_bytes())
        except (BrokenPipeError, ConnectionResetError):
            pass

with tempfile.TemporaryDirectory(prefix='isla-palette-recovery-') as folder:
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', ISLA_CONFIG=folder+'/shell.json',
                   XDG_CACHE_HOME=folder, ISLA_PALETTE_TEST_BASE=f'http://127.0.0.1:{server.server_port}')
        result = subprocess.run(['quickshell', '-p', str(bar / 'media-palette-recovery-regression.qml')],
                                env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output, end='')
        assert result.returncode == 0 and 'PASS: palette cancels' in output and 'FAIL:' not in output
        assert counts['/slow.svg'] == 1 and counts['/blue.svg'] == 1
        assert counts['/timeout.svg'] == 2
        assert counts['/flaky.svg'] == 2 and counts['/missing.svg'] == 3, counts
        print('PASS: real HTTP cancellation, retry and request bounds')
    finally:
        server.shutdown()
        server.server_close()
