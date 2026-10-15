"""Derive readable Starship colors from Isla's Matugen palette."""
import json
import os
import re
import tempfile
from pathlib import Path


def rgb(value):
    if not isinstance(value, str) or not re.fullmatch(r'#[0-9a-fA-F]{6}', value):
        raise ValueError('Invalid Matugen color')
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
    if data.get('version') != 1 or data.get('generator') != 'matugen':
        raise ValueError('Unsupported Matugen palette')
    roles = data['colors']
    bg, fg = data['terminal']['background'], data['terminal']['foreground']
    names = {
        'text': 'on_surface', 'muted': 'on_surface_variant',
        'error': 'error', 'success': 'secondary', 'warning': 'tertiary',
        'accent': 'primary', 'secondary': 'secondary', 'tertiary': 'tertiary',
    }
    colors = {name: readable(roles[role], bg, fg) for name, role in names.items()}
    config = config.split('[palettes.matugen]', 1)[0]
    return config + '[palettes.matugen]\n' + ''.join(f"{k} = '{v}'\n" for k, v in colors.items())


def main():
    home = Path.home()
    cache = Path(os.environ.get('XDG_CACHE_HOME') or home / '.cache')
    config = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config')
    palette = cache / 'matugen/palette.json'
    if not palette.exists():
        return 1
    try:
        result = generate((config / 'starship.toml').read_text(), json.loads(palette.read_text()))
        dest = cache / 'starship/matugen.toml'
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
