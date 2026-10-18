#!/usr/bin/env python3
"""Real local/HTTP extraction with isolated cache, no personal artwork."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import threading

bar = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('artwork_palette', bar / 'services/artwork_palette.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write((bar / 'tests/fixtures/artwork-blue.svg').read_bytes())
    def log_message(self, *_args):
        pass

with tempfile.TemporaryDirectory(prefix='isla-palette-') as folder:
    os.environ['XDG_CACHE_HOME'] = folder
    coral = module.extract((bar / 'tests/fixtures/artwork-coral.svg').as_uri())
    assert coral.startswith('#') and len(coral) == 7
    assert module.extract((bar / 'tests/fixtures/artwork-coral.svg').as_uri()) == coral
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        blue = module.extract(f'http://127.0.0.1:{server.server_port}/cover.svg')
        assert blue != coral and int(blue[5:7], 16) > int(blue[1:3], 16)
        assert len(list(Path(folder).rglob('*.json'))) == 2
    finally:
        server.shutdown()
        server.server_close()
    try:
        module.extract('unsupported://cover')
        raise AssertionError('Unsupported scheme accepted')
    except ValueError:
        pass
print('PASS: local/HTTP quantization, cache reuse/isolation and unsupported URL')
