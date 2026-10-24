#!/usr/bin/env python3
"""DP-1 QA for «más vida»: doze→sleep, wake, love and pill gaze on the native pets-qa scene.
Contact sheets stay here; raw frames in /tmp."""
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
    with tempfile.TemporaryDirectory(prefix='isla-pets-vidaqa-') as temporary, (OUT / 'scene.log').open('w') as log:
        tmp = Path(temporary)
        config = tmp / 'config.json'
        config.write_text(json.dumps({'pets': {'enabled': True, 'sleepEnabled': True, 'codingReaction': False, 'mischief': 'never'}}) + '\n')
        env = {**os.environ, 'ISLA_CONFIG': str(config), 'QT_QPA_PLATFORM': 'wayland'}
        process = subprocess.Popen(['qs', '-p', str(FIXTURE)], env=env, stdout=log, stderr=log)
        verdicts = {}

        def ipc(method, *args):
            result = subprocess.run(['qs', '-p', str(FIXTURE), 'ipc', 'call', 'petqa', method, *map(str, args)],
                                    env=env, capture_output=True, text=True, timeout=4)
            assert result.returncode == 0, result.stderr
            return json.loads(result.stdout)

        def wait(predicate, timeout=8):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                assert process.poll() is None, 'native QA scene exited'
                try:
                    current = ipc('status')
                    if predicate(current):
                        return current
                except (AssertionError, json.JSONDecodeError):
                    pass
                time.sleep(.05)
            raise AssertionError(ipc('status'))

        def capture(name, seconds, region, action=lambda: None):
            frames, anims = [], []
            start = time.monotonic()
            action()
            while time.monotonic() - start < seconds:
                path = tmp / 'frame.png'
                subprocess.run(['grim', '-g', region, str(path)], check=True, timeout=3)
                frames.append(Image.open(path).convert('RGB'))
                anims.append(ipc('status')['anim'])
            sheet(name, frames, anims)
            return anims

        def sheet(name, frames, anims):
            step = max(1, len(frames) // 12)
            picked = list(zip(frames, anims))[::step][:12]
            w, h = picked[0][0].size
            out = Image.new('RGB', (w * 2, (h * 2 + 14) * len(picked)), (20, 20, 24))
            draw = ImageDraw.Draw(out)
            for i, (frame, anim) in enumerate(picked):
                y = i * (h * 2 + 14)
                out.paste(frame.resize((w * 2, h * 2), Image.NEAREST), (0, y + 14))
                draw.text((4, y), anim, fill=(230, 230, 230))
            out.save(OUT / f'{name}.png')

        try:
            s = wait(lambda s: s['loaded'] and s['perch'] == 'bar' and s['shown'] and s['opacity'] > .99, 12)
            fx, fy = s['feet']
            region = f'{int(fx) - 70},{int(fy) - 50} 140x60'
            time.sleep(1)

            anims = capture('doze-sleep', 3.2, region, lambda: ipc('sleepAfter', 200))
            verdicts['doze precedes sleep'] = 'doze' in anims and anims[-1] == 'sleep' and anims.index('doze') < anims.index('sleep')
            time.sleep(.5)
            anims = capture('wake', 1.6, region, lambda: ipc('event', 'click'))
            verdicts['wake plays from sleep'] = 'wake' in anims
            ipc('sleepAfter', 120000)
            time.sleep(2.6)
            anims = capture('love', 1.4, region, lambda: ipc('pet'))
            verdicts['pet shows love'] = 'love' in anims

            # Gaze: real pointer over the pill on each side of the pet, then away.
            pill_y = int(fy) - 18
            def move(x, y):
                # Hyprland Lua config: dispatch takes an hl.dsp expression.
                subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.cursor.move({{x={x},y={y}}})'], check=True, capture_output=True)
            looks = {}
            move(int(fx), 700)
            wait(lambda s: s['anim'] == 'idle', 6)
            # The bar perch sits at the pill's right end: aim just past the pet's
            # teal body (found in a capture), not at a fixed offset off the pill.
            probe = tmp / 'probe.png'
            subprocess.run(['grim', '-g', region, str(probe)], check=True)
            img = Image.open(probe).convert('RGB')
            teal = [x for x in range(img.width) for y in range(img.height)
                    if (lambda p: p[1] > 150 and p[2] > 140 and p[0] < 150)(img.getpixel((x, y)))]
            right_x = int(fx) - 70 + max(teal) + 5
            verdicts['_right_x'] = right_x
            for side, x in (('left', int(fx) - 160), ('right', right_x)):
                # Hyprland warps inside one surface deliver no wl_pointer motion
                # (pill.pointerX stayed put), so each side enters the pill afresh.
                move(x, 700)
                time.sleep(.15)
                move(x, pill_y)
                time.sleep(.6)
                looks[side] = ipc('status')['anim']
                looks[side + '_gaze'] = ipc('gaze')
                subprocess.run(['grim', '-g', region, str(OUT / f'gaze-{side}.png')], check=True)
            move(int(fx), 700)
            time.sleep(1.8)
            looks['away'] = ipc('status')['anim']
            verdicts['gaze follows pointer'] = looks['left'] == 'look_left' and looks['right'] == 'look_right' and looks['away'] not in ('look_left', 'look_right')
            verdicts['_looks'] = looks
        finally:
            try:
                ipc('quit')
            except Exception:
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        (OUT / 'verdicts.json').write_text(json.dumps(verdicts, indent=1) + '\n')
        print(json.dumps(verdicts))


if __name__ == '__main__':
    run()
