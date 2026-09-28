"""Run with: python3 ~/.config/starship/test_pywal.py"""
import tomllib
from pywal import contrast, generate, readable, rgb

for bg, fg, accent in [('#0a0404', '#c1c0c0', '#910e0e'), ('#fafafa', '#303030', '#eeeeff'), ('#777777', '#888888', '#777777')]:
    adjusted = readable(accent, bg, fg)
    assert contrast(rgb(adjusted), rgb(bg)) >= 4.5
assert readable('#ffffff', '#000000', '#ffffff') == '#ffffff'

def fixture(accent):
    return {'special': {'background': '#000000', 'foreground': '#ffffff'},
            'colors': {f'color{i}': accent for i in range(7, 15)}}
base = "palette = 'pywal'\n[character]\nsuccess_symbol = '[❯](wal12)'\n[palettes.pywal]\nwal12 = '#ffffff'\n"
a, b = (generate(base, fixture(color)) for color in ('#dd5555', '#5555dd'))
assert tomllib.loads(a)['palettes']['pywal'] != tomllib.loads(b)['palettes']['pywal']
assert tomllib.loads(a)['character'] == tomllib.loads(base)['character']
assert generate(a, fixture('#dd5555')) == a
try:
    rgb('#oops')
    raise AssertionError('Invalid color accepted')
except ValueError:
    pass
print('PASS: dark/light/low-contrast palettes, wallpaper change, idempotence, validation')
