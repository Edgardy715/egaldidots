#!/usr/bin/env python3
"""Deterministic LRCLIB responses for the real QML lyrics controller."""
import collections
import http.server
import json
import os
import subprocess
import tempfile
import threading
import time
from urllib.parse import parse_qs, urlsplit

COUNTS = collections.Counter()
LYRICS = '[00:01.00]Primera línea de prueba\n[00:04.50]Segunda línea'


def record(title='fallback', artist='QA', duration=30, album='Album', synced=LYRICS, plain=''):
    return dict(trackName=title, artistName=artist, duration=duration,
                albumName=album, syncedLyrics=synced, plainLyrics=plain, instrumental=False)


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        parsed = urlsplit(self.path)
        params = parse_qs(parsed.query)
        title = params.get('track_name', [''])[0]
        kind = parsed.path.rsplit('/', 1)[-1]
        COUNTS[kind, title] += 1
        status, payload = 200, {}
        if kind == 'get':
            if title in ('fallback', 'missing'):
                status, payload = 404, {'message': 'Not found'}
            elif title == 'outage':
                status, payload = 503, {'message': 'Temporary outage'}
            elif title == 'blank':
                payload = record(title='blank', synced='', plain='')
            elif title == 'hang' and 'album_name' in params:
                time.sleep(0.9)
                payload = record(title='hang', synced='', plain='Respuesta obsoleta')
            elif title == 'hangout':
                time.sleep(0.9)
                payload = record(title='hangout')
            elif title == 'flaky' and COUNTS[kind, title] == 1:
                status, payload = 503, {'message': 'Temporary outage'}
            elif title == 'slow':
                time.sleep(1.0)
                payload = record(title='slow')
            elif title == 'plain':
                payload = record(title='plain', synced='', plain='Texto nuevo')
            else:
                payload = record(title=title)
        elif kind == 'search':
            if title == 'hangout':
                time.sleep(0.9)
                payload = [record(title='hangout')]
            elif title == 'outage':
                status, payload = 503, {'message': 'Temporary outage'}
            else:
                payload = [] if title == 'missing' else [
                    record(title=title + ' live'),
                    record(title=title, artist='Wrong artist'),
                    record(title=title, duration=50),
                    record(title=title, duration=31),
                ]
        else:
            status, payload = 404, {}
        body = json.dumps(payload).encode()
        try:
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass


server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    with tempfile.TemporaryDirectory(prefix='isla-lyrics-') as temporary:
        for case in ('fallback', 'blank', 'retry', 'outage', 'hang', 'hangout', 'stale', 'close', 'empty'):
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen',
                       ISLA_CONFIG=os.path.join(temporary, 'settings.json'),
                       ISLA_LYRICS_TEST_CASE=case,
                       ISLA_LYRICS_TEST_ENDPOINT=f'http://127.0.0.1:{server.server_port}/api/get')
            result = subprocess.run(['quickshell', '-p', 'bar/lyrics-controller-regression.qml'],
                                    env=env, capture_output=True, text=True, timeout=13)
            output = result.stdout + result.stderr
            if result.returncode or f'PASS: lyrics {case}' not in output:
                raise AssertionError(f'{case}: exit {result.returncode}\n{output[-2500:]}')
        assert COUNTS['get', 'flaky'] == 2, COUNTS
        assert COUNTS['get', 'outage'] == 3 and COUNTS['search', 'outage'] == 2, COUNTS
        assert COUNTS['get', 'hang'] == 2 and COUNTS['search', 'hang'] == 0, COUNTS
        assert COUNTS['get', 'hangout'] == 3 and COUNTS['search', 'hangout'] == 2, COUNTS
        assert COUNTS['search', 'fallback'] >= 1, COUNTS
        assert COUNTS['search', 'blank'] == 1, COUNTS
        assert COUNTS['get', 'missing'] == 4 and COUNTS['search', 'missing'] == 2, COUNTS
        assert COUNTS['get', 'fallback'] == 4, COUNTS  # two GET forms per acquisition
        print('PASS: exact 404/blank fallback, search ranking, transient/outage/timeout recovery, stale change/close, cached reopen, empty reopen')
finally:
    server.shutdown()
    server.server_close()
