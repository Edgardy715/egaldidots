"""Derive Starship's palette from pywal, lifting dark accents for legibility."""
import json
import re
import tempfile
from pathlib import Path


def rgb(value):
    if not isinstance(value, str) or not re.fullmatch(r'#[0-9a-fA-F]{6}', value):
        raise ValueError('Invalid pywal color')
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def luminance(color):
    channels = [v / 255 for v in color]
    linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in channels]
    return sum(v * w for v, w in zip(linear, (.2126, .7152, .0722)))


def contrast(a, b):
    a, b = sorted((luminance(a), luminance(b)))
    return (b + .05) / (a + .05)


def readable(value, background, foreground):
    color, bg, fg = rgb(value), rgb(background), rgb(foreground)
    # Preserve the wallpaper hue; mix toward its foreground only as needed.
    if contrast(fg, bg) < 4.5:
        fg = max(((0, 0, 0), (255, 255, 255)), key=lambda c: contrast(c, bg))
    for step in range(101):
        mixed = tuple(round(c + (f - c) * step / 100) for c, f in zip(color, fg))
        if contrast(mixed, bg) >= 4.5:
            return '#' + ''.join(f'{v:02x}' for v in mixed)


def generate(config, data):
    bg, fg = data['special']['background'], data['special']['foreground']
    colors = {f'wal{i}': readable(data['colors'][f'color{i}'], bg, fg) for i in range(7, 15)}
    colors['wal_fg'] = readable(fg, bg, fg)
    # Replace only our final palette table; keep module options in the base file.
    config = config.split('[palettes.pywal]', 1)[0]
    return config + '[palettes.pywal]\n' + ''.join(f"{k} = '{v}'\n" for k, v in colors.items())


def main():
    home = Path.home()
    palette = home / '.cache/wal/colors.json'
    if not palette.exists():
        return 1
    try:
        result = generate((home / '.config/starship.toml').read_text(), json.loads(palette.read_text()))
        dest = home / '.cache/starship/pywal.toml'
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists() and dest.read_text() == result:
            return 0
        with tempfile.NamedTemporaryFile(mode='w', dir=dest.parent, delete=False) as f:
            f.write(result)
            temp = Path(f.name)
        temp.replace(dest)
        return 0
    except (OSError, ValueError, KeyError):
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
