#!/usr/bin/env python3
"""DP-1 native pet QA. Keeps contact sheets and timed state samples, raw frames only in /tmp."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
FIXTURE = ROOT / 'bar/pets-qa.qml'


def run():
    with tempfile.TemporaryDirectory(prefix='isla-pets-qa-') as temporary, (OUT / 'scene.log').open('w') as log:
        tmp = Path(temporary)
        config = tmp / 'config.json'
        config.write_text('{}\n')
        env = {**os.environ, 'ISLA_CONFIG': str(config), 'QT_QPA_PLATFORM': 'wayland'}
        process = subprocess.Popen(['qs', '-p', str(FIXTURE)], env=env, stdout=log, stderr=log)
        owned = []
        evidence = {}

        def ipc(target, method, *args):
            result = subprocess.run(['qs', '-p', str(FIXTURE), 'ipc', 'call', target, method, *map(str, args)],
                                    env=env, capture_output=True, text=True, timeout=4)
            assert result.returncode == 0, result.stderr
            return json.loads(result.stdout)

        def status():
            return ipc('petqa', 'status')

        def wait(predicate, timeout=8):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                assert process.poll() is None, 'native QA scene exited'
                try:
                    current = status()
                    if predicate(current):
                        return current
                except (AssertionError, json.JSONDecodeError):
                    pass
                time.sleep(.05)
            raise AssertionError(status())

        def update(patch):
            assert ipc('settings', 'update', json.dumps(patch))['ok']

        def capture(name, seconds, action=lambda: None, spacing=.015, timed=()):
            frames, samples = [], []
            pending = list(timed)
            start = time.monotonic()
            action()
            while time.monotonic() - start < seconds:
                while pending and time.monotonic() - start >= pending[0][0]:
                    pending.pop(0)[1]()
                path = tmp / 'frame.png'
                before = time.monotonic()
                subprocess.run(['grim', '-g', '0,80 1920x500', str(path)], check=True, timeout=3)
                samples.append({'capture_start_s': before - start, 'capture_end_s': time.monotonic() - start, **status()})
                frames.append(Image.open(path).convert('RGB').copy())
                time.sleep(spacing)
            assert frames and frames[0].size == (1920, 500)
            # Same crop across a sequence, plus every sampled frame at 2x around the sprite.
            xs = [s['feet'][0] for s in samples]
            ys = [s['feet'][1] - 80 for s in samples]
            left, right = max(0, int(min(xs)) - 100), min(1920, int(max(xs)) + 100)
            top, bottom = max(0, int(min(ys)) - 85), min(500, int(max(ys)) + 35)
            crops = [frame.crop((left, top, right, bottom)) for frame in frames]
            details = []
            for frame, sample in zip(frames, samples):
                # IPC follows grim: find Mimo's actual body in the image for fast flights.
                delta = ImageChops.difference(frame, Image.new('RGB', frame.size, '#86d6c4'))
                red, green, blue = delta.split()
                mask = ImageChops.lighter(ImageChops.lighter(red, green), blue).point(lambda value: 255 if value == 0 else 0)
                box = mask.getbbox()
                cx, cy = sample['feet'][0], sample['feet'][1] - 95
                if box and box[2] - box[0] < 80 and box[3] - box[1] < 80:
                    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
                details.append(frame.crop((int(cx) - 60, int(cy) - 50, int(cx) + 60, int(cy) + 50))
                               .resize((240, 200), Image.Resampling.NEAREST))
            for suffix, pictures in (('', crops), ('-detail', details)):
                width, height = pictures[0].size
                cols = min(6, len(pictures))
                sheet = Image.new('RGB', (cols * width, ((len(pictures) + cols - 1) // cols) * (height + 22)), '#19191c')
                draw = ImageDraw.Draw(sheet)
                for index, (picture, sample) in enumerate(zip(pictures, samples)):
                    x, y = index % cols * width, index // cols * (height + 22)
                    sheet.paste(picture, (x, y))
                    draw.text((x + 3, y + height + 3), f"{sample['capture_end_s']:.3f}s {sample['phase'] or sample['anim']}", fill='white')
                sheet.save(OUT / (name + suffix + '.png'))
            evidence[name] = samples
            (OUT / 'samples.json').write_text(json.dumps(evidence, indent=2) + '\n')
            print('CAPTURE', name, len(samples), 'samples', flush=True)
            return samples

        try:
            wait(lambda s: s['loaded'])
            update({'pets': {'enabled': True, 'sleepEnabled': False, 'codingReaction': False, 'mischief': 'never'},
                    'appearance': {'barLayout': 'split', 'workspaceStyle': 'numbers'}})
            wait(lambda s: s['perch'] == 'bar' and not s['phase'])
            for repeat in (1, 2):
                capture(f'bar-launcher-{repeat}', 2, lambda: ipc('petqa', 'surface', 'launcher'))
                assert wait(lambda s: s['perch'] == 'launcher' and not s['phase'])
                capture(f'launcher-bar-{repeat}', 2.8, lambda: ipc('petqa', 'surface', ''))
                wait(lambda s: s['perch'] == 'bar' and not s['phase'])
            for layout in ('split', 'compact'):
                update({'appearance': {'barLayout': layout, 'workspaceStyle': 'pet'}})
                wait(lambda s: s['compact'] == (layout == 'compact') and not s['layoutChanging'] and s['perch'] == 'rail' and not s['phase'])
                for destination in (2, 5):
                    for repeat in (1, 2):
                        ipc('petqa', 'workspace', 1)
                        wait(lambda s: not s['phase'])
                        capture(f'{layout}-rail-1-{destination}-{repeat}', .8, lambda: ipc('petqa', 'workspace', destination))
                        wait(lambda s: not s['phase'])
                capture(f'{layout}-hover', .35, lambda: ipc('petqa', 'hover', 1))
                assert status()['anim'] == 'look_left'
                ipc('petqa', 'hover', 0)
                for repeat in (1, 2):
                    ipc('petqa', 'workspace', 1)
                    wait(lambda s: not s['phase'])
                    capture(f'{layout}-rapid-1-5-2-{repeat}', 1.1,
                            lambda: ipc('petqa', 'workspace', 5), timed=((.2, lambda: ipc('petqa', 'workspace', 2)),))
                    wait(lambda s: not s['phase'] and s['activeId'] == 2)
                capture(f'{layout}-rail-launcher', 2, lambda: ipc('petqa', 'surface', 'launcher'))
                wait(lambda s: s['perch'] == 'launcher' and not s['phase'])
                capture(f'{layout}-launcher-rail', 2.8, lambda: ipc('petqa', 'surface', ''))
                wait(lambda s: s['perch'] == 'rail' and not s['phase'])
            update({'appearance': {'barLayout': 'split', 'workspaceStyle': 'numbers'}, 'pets': {'codingReaction': True}})
            wait(lambda s: s['perch'] == 'bar' and not s['phase'])
            terminal = subprocess.Popen(['kitty', '--class', 'kitty', '--title', 'Isla coding QA', 'sh', '-c', 'sleep 30'], stdout=log, stderr=log)
            owned.append(terminal)
            wait(lambda s: s['coding'] and s['anim'] == 'code')
            capture('coding', 1)
            terminal.terminate(); terminal.wait(timeout=5)
            update({'pets': {'codingReaction': False}})
            wait(lambda s: s['anim'] == 'idle')
            fake = subprocess.Popen(['python3', str(ROOT / 'docs/drop-gather-2026-10-22/tools/fake-mpris.py')], stdout=log, stderr=log)
            owned.append(fake)
            wait(lambda s: ipc('petqa', 'selectPlayer', 'islasim'))
            wait(lambda s: s['music'] and s['anim'] == 'dance')
            music_samples = capture('music-eight-seconds', 8.6, spacing=.45)
            assert any(s['anim'] == 'dance' for s in music_samples) and status()['anim'] == 'idle'
            ipc('petqa', 'surface', 'media')
            wait(lambda s: s['perch'] == 'media' and not s['phase'])
            capture('media-launcher', 3, lambda: ipc('petqa', 'surface', 'launcher'))
            wait(lambda s: s['perch'] == 'launcher' and not s['phase'])
            ipc('petqa', 'surface', '')
            fake.terminate(); fake.wait(timeout=5)
            wait(lambda s: s['perch'] == 'bar' and not s['phase'])
            update({'pets': {'mischief': 'frequent', 'musicReaction': False}})
            time.sleep(3.1)
            wait(lambda s: s['anim'] == 'idle')
            capture('mischief-frequent', 1.8, lambda: ipc('petqa', 'advanceClock', 200))
            assert any(s['anim'] in ('twirl', 'sneeze', 'wave') for s in evidence['mischief-frequent'])
            update({'appearance': {'reduceMotion': True}, 'pets': {'mischief': 'never'}})
            capture('reduced-bar-launcher', 1, lambda: ipc('petqa', 'surface', 'launcher'))
            assert all(not s['flying'] for s in evidence['reduced-bar-launcher'])
            capture('reduced-launcher-bar', 1, lambda: ipc('petqa', 'surface', ''))
            update({'appearance': {'workspaceStyle': 'pet'}})
            wait(lambda s: s['perch'] == 'rail')
            capture('reduced-rail', .4, lambda: ipc('petqa', 'workspace', 5))
            assert all(not s['flying'] for s in evidence['reduced-rail'])
            for name in ('bar-launcher-1', 'bar-launcher-2', 'launcher-bar-1', 'launcher-bar-2', 'media-launcher'):
                assert any(sample['flying'] for sample in evidence[name]), name + ': no flight observed'
            for name, samples in evidence.items():
                assert all(sample['opaqueTop'] >= -.1 for sample in samples if sample['phase'] == 'flight'), name + ': top clipping'
            print('PASS: native DP-1 scenarios, repeated flights/hops, coding focus, real MPRIS, mischief and reduced', flush=True)
        finally:
            for child in owned:
                if child.poll() is None:
                    child.terminate(); child.wait(timeout=5)
            process.terminate(); process.wait(timeout=5)


if __name__ == '__main__':
    run()
