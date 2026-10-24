#!/usr/bin/env python3
"""DP-1 QA (sole monitor at 0,0, so -g crops DP-1) for the phase-2 review fixes. Contact sheets and timed samples stay here, raw frames in /tmp."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
FIXTURE = ROOT / 'bar/pets-qa.qml'


def run():
    with tempfile.TemporaryDirectory(prefix='isla-pets-fixqa-') as temporary, (OUT / 'scene.log').open('w') as log:
        tmp = Path(temporary)
        config = tmp / 'config.json'
        config.write_text('{}\n')
        env = {**os.environ, 'ISLA_CONFIG': str(config), 'QT_QPA_PLATFORM': 'wayland'}
        process = subprocess.Popen(['qs', '-p', str(FIXTURE)], env=env, stdout=log, stderr=log)
        evidence, verdicts = {}, {}

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

        def capture(name, seconds, action=lambda: None, timed=()):
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
            xs = [s['feet'][0] for s in samples if s['shown']] or [960]
            ys = [s['feet'][1] - 80 for s in samples if s['shown']] or [60]
            left, right = max(0, int(min(xs)) - 110), min(1920, int(max(xs)) + 110)
            top, bottom = max(0, int(min(ys)) - 90), min(500, int(max(ys)) + 40)
            crops = [f.crop((left, top, right, bottom)).resize(((right - left) * 2, (bottom - top) * 2), Image.Resampling.NEAREST)
                     for f in frames]
            width, height = crops[0].size
            cols = max(1, min(6, 1800 // width, len(crops)))
            sheet = Image.new('RGB', (cols * width, ((len(crops) + cols - 1) // cols) * (height + 22)), '#19191c')
            draw = ImageDraw.Draw(sheet)
            for index, (picture, sample) in enumerate(zip(crops, samples)):
                x, y = index % cols * width, index // cols * (height + 22)
                sheet.paste(picture, (x, y))
                draw.text((x + 3, y + height + 3),
                          f"{sample['capture_end_s']:.3f}s {sample['phase'] or sample['anim']} a={sample['opacity']:.2f}", fill='white')
            sheet.save(OUT / (name + '.png'))
            evidence[name] = samples
            (OUT / 'samples.json').write_text(json.dumps(evidence, indent=2) + '\n')
            print('CAPTURE', name, len(samples), 'samples', flush=True)
            return samples

        def verdict(name, ok, detail):
            verdicts[name] = {'ok': bool(ok), 'detail': detail}
            (OUT / 'verdicts.json').write_text(json.dumps(verdicts, indent=2) + '\n')
            print(('PASS ' if ok else 'FAIL ') + name + ': ' + detail, flush=True)

        try:
            wait(lambda s: s['loaded'])
            update({'pets': {'enabled': True, 'sleepEnabled': False, 'codingReaction': False, 'mischief': 'never'},
                    'appearance': {'barLayout': 'split', 'workspaceStyle': 'pet'}})
            # F1: retarget while the landing crouch plays; the pet leaves from where it stands.
            for layout in ('split', 'compact'):
                update({'appearance': {'barLayout': layout, 'workspaceStyle': 'pet'}})
                wait(lambda s: s['compact'] == (layout == 'compact') and not s['layoutChanging'] and s['perch'] == 'rail' and not s['phase'])
                for repeat in (1, 2):
                    ipc('petqa', 'workspace', 1)
                    wait(lambda s: not s['phase'])
                    ipc('petqa', 'workspaceOnLand', 5)
                    samples = capture(f'{layout}-land-retarget-{repeat}', 1.6, lambda: ipc('petqa', 'workspace', 3))
                    wait(lambda s: not s['phase'] and s['activeId'] == 5)
                    phases = [s['phase'] for s in samples]
                    jumps = [abs(b['feet'][0] - a['feet'][0]) / max(.001, b['capture_end_s'] - a['capture_end_s'])
                             for a, b in zip(samples, samples[1:]) if a['shown'] and b['shown']]
                    # grim samples every ~100 ms and land lasts 90 ms, so the fixture reports the trigger itself.
                    fired = not status()['landArmed']
                    verdict(f'{layout}-land-retarget-{repeat}', fired and samples[-1]['activeId'] == 5,
                            f"fired on land {fired}, phases {sorted(set(phases))}, max feet speed {max(jumps or [0]):.0f} px/s")
            # F2: entry into the bar niche while it reveals never dips.
            update({'appearance': {'barLayout': 'split', 'workspaceStyle': 'numbers'}})
            wait(lambda s: s['perch'] == 'bar' and not s['phase'])
            update({'pets': {'enabled': False}})
            wait(lambda s: not s['shown'])
            time.sleep(.6)
            samples = capture('bar-niche-entry', 1.4, lambda: update({'pets': {'enabled': True}}))
            seen = [s['opacity'] for s in samples if s['shown']]
            dips = [b - a for a, b in zip(seen, seen[1:]) if b < a - .02]
            verdict('bar-niche-entry', seen and not dips and seen[-1] > .99, f"opacity {['%.2f' % o for o in seen]}")
            # F3: reopening the launcher mid-close flies back without a fade.
            for repeat in (1, 2):
                wait(lambda s: s['perch'] == 'bar' and not s['phase'])
                ipc('petqa', 'surface', 'launcher')
                wait(lambda s: s['perch'] == 'launcher' and not s['phase'])
                samples = capture(f'launcher-reopen-{repeat}', 2.4, lambda: ipc('petqa', 'surface', ''),
                                  timed=((.15, lambda: ipc('petqa', 'surface', 'launcher')),))
                wait(lambda s: s['perch'] == 'launcher' and not s['phase'])
                phases = [s['phase'] for s in samples]
                verdict(f'launcher-reopen-{repeat}', 'fade' not in phases and 'entry' not in phases,
                        f"phases {phases}, min opacity {min(s['opacity'] for s in samples):.2f}")
                ipc('petqa', 'surface', '')
            # F6: a surface with no perch dims the pet at once and hides it within the grace.
            wait(lambda s: s['perch'] == 'bar' and not s['phase'])
            for repeat in (1, 2):
                samples = capture(f'no-perch-surface-{repeat}', 1.0, lambda: ipc('petqa', 'surface', 'calendar'))
                late = [s for s in samples if s['capture_end_s'] >= .2 and s['shown'] and s['opacity'] > .45]
                hidden = next((s['capture_end_s'] for s in samples if not s['shown']), None)
                rises = [1 for a, b in zip(samples, samples[1:]) if a['shown'] and b['opacity'] > a['opacity'] + .02]
                verdict(f'no-perch-surface-{repeat}', not late and hidden is not None and hidden <= .7 and not rises,
                        f"hidden at {hidden}, perch {samples[-1]['perch']!r}, "
                        f"opacity {['%.2f' % s['opacity'] for s in samples]}")
                ipc('petqa', 'surface', '')
                wait(lambda s: s['perch'] == 'bar' and not s['phase'])
            ok = all(v['ok'] for v in verdicts.values())
            print(('PASS' if ok else 'FAIL') + ': phase-2 fix scenarios on DP-1', flush=True)
        finally:
            try:
                ipc('petqa', 'quit')
            except Exception:
                pass
            time.sleep(.3)
            if process.poll() is None:
                process.terminate(); process.wait(timeout=5)


if __name__ == '__main__':
    run()
