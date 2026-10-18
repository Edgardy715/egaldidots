#!/usr/bin/env python3
"""Small, bounded artwork palette cache; no work during audio frames."""
import colorsys
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import urllib.parse
import urllib.request


active_child = None


def stop(_signum, _frame):
    if active_child is not None:
        active_child.kill()
    raise SystemExit(143)


def extract(source):
    global active_child
    parsed = urllib.parse.urlsplit(source)
    if parsed.scheme not in ('http', 'https', 'file', ''):
        raise ValueError('Unsupported artwork URL')
    cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'isla/artwork-palettes'
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / (hashlib.sha256(source.encode()).hexdigest() + '.json')
    if target.exists():
        try:
            cached = json.loads(target.read_text())
            if isinstance(cached, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", cached):
                return cached
        except (ValueError, OSError):
            pass
    if parsed.scheme in ('http', 'https'):
        with urllib.request.urlopen(urllib.request.Request(source, headers={'User-Agent': 'Isla/1.0'}), timeout=8) as response:
            data = response.read(8 * 1024 * 1024 + 1)
    else:
        path = Path(urllib.parse.unquote(parsed.path) if parsed.scheme else source)
        with path.open('rb') as stream:
            data = stream.read(8 * 1024 * 1024 + 1)
    if len(data) > 8 * 1024 * 1024:
        raise ValueError('Artwork too large')
    with subprocess.Popen(['magick', '-limit', 'memory', '64MiB', '-limit', 'map', '64MiB',
                           '-', '-thumbnail', '48x48', '-background', '#808080', '-alpha', 'remove',
                           '-colors', '8', '-depth', '8', '-format', '%c', 'histogram:info:-'],
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
        active_child = process
        try:
            output, _ = process.communicate(data, timeout=6)
            if process.returncode:
                raise ValueError('Artwork decode failed')
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            raise
        finally:
            active_child = None
    candidates = []
    for count, hex_rgb in re.findall(r'(\d+):[^\n]*?#([0-9A-Fa-f]{6})\b', output.decode()):
        rgb = tuple(int(hex_rgb[i:i + 2], 16) / 255 for i in (0, 2, 4))
        hue, light, saturation = colorsys.rgb_to_hls(*rgb)
        score = int(count) ** 0.5 * (0.15 + saturation) * (1 - abs(light - 0.5))
        candidates.append((score, '#' + hex_rgb))
    if not candidates:
        raise ValueError('No artwork colors')
    color = max(candidates)[1]
    temporary = target.with_suffix(f'.{os.getpid()}.tmp')
    try:
        temporary.write_text(json.dumps(color))
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    for stale in sorted(cache.glob('*.json'), key=lambda p: p.stat().st_mtime, reverse=True)[64:]:
        stale.unlink(missing_ok=True)
    return color


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, stop)
    try:
        print(json.dumps({"source": sys.argv[1], "color": extract(sys.argv[1])}))
    except Exception:
        print(json.dumps({"source": sys.argv[1] if len(sys.argv) > 1 else "", "color": None}))
