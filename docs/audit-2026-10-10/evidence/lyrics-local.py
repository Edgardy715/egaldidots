import http.server,threading,json,urllib.parse,time,subprocess,os,pathlib
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_GET(self):
  title=urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get('track_name',[''])[0]
  if title=='slow': time.sleep(1.1)
  status=404 if title=='empty' else 200
  body=b'bad-json' if title=='broken' else json.dumps({'instrumental':title=='instrumental','syncedLyrics':'[00:00.00]Primera línea de prueba\n[00:10.00]Segunda\n[00:20.00]Tercera' if title in ['synced','slow'] else None,'plainLyrics':'Una línea\nOtra línea' if title=='plain' else None}).encode()
  self.send_response(status);self.send_header('Content-Type','application/json');self.end_headers()
  try:self.wfile.write(body)
  except BrokenPipeError:pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
env=os.environ.copy();env.update(ISLA_CONFIG='/tmp/isla-audit-lyrics-local.json',QT_QPA_PLATFORM='offscreen',ISLA_LYRICS_TEST_ENDPOINT=f'http://127.0.0.1:{server.server_port}/api/get')
try:
 r=subprocess.run(['python',os.path.expanduser('~/.codex/token-economy/output.py'),'run','--','timeout','12s','qs','-p','bar/lyrics-controller-regression.qml'],env=env,capture_output=True,text=True)
 pathlib.Path('docs/audit-2026-10-10/evidence/lyrics-local.txt').write_text(r.stdout+r.stderr)
 print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS:' in r.stdout and 'FAIL:' not in r.stdout
finally:server.shutdown();server.server_close()
