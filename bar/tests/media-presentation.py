#!/usr/bin/env python3
"""Exercise real delayed image loads without MPRIS, network services or user config."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import subprocess
import tempfile
import threading
import time

bar = Path(__file__).resolve().parents[1]
image = (bar / 'tests/fixtures/artwork-blue.svg').read_bytes()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        time.sleep(0.4)
        self.send_response(200)
        self.send_header('Content-Type', 'image/svg+xml')
        self.send_header('Content-Length', str(len(image)))
        self.end_headers()
        try:
            self.wfile.write(image)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Qt cancels requests when a newer track arrives.

    def log_message(self, *_args):
        pass


with tempfile.TemporaryDirectory(prefix='isla-artwork-') as folder:
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        env = dict(os.environ, ISLA_CONFIG=str(Path(folder) / 'shell.json'),
                   QT_QPA_PLATFORM=os.environ.get('QT_QPA_PLATFORM', 'offscreen'),
                   ISLA_SLOW_ARTWORK=f'http://127.0.0.1:{server.server_port}/blue.svg')
        result = subprocess.run(['quickshell', '-p', str(bar / 'media-presentation-regression.qml')],
                                env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        print(output, end='')
        assert result.returncode == 0 and 'PASS: retained art' in output and 'FAIL:' not in output
        print('PASS: delayed HTTP image retention and stale-response cancellation')
    finally:
        server.shutdown()
        server.server_close()
