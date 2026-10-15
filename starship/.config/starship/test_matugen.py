"""Run with: python3 ~/.config/starship/test_matugen.py"""
import tomllib
from matugen import contrast, generate, readable, rgb

for bg, fg, accent in [('#0a0404', '#c1c0c0', '#910e0e'), ('#fafafa', '#303030', '#eeeeff'), ('#777777', '#888888', '#777777')]:
    adjusted = readable(accent, bg, fg)
    assert contrast(rgb(adjusted), rgb(bg)) >= 4.5
assert readable('#ffffff', '#000000', '#ffffff') == '#ffffff'

def fixture(accent):
    return {'version': 1, 'generator': 'matugen', 'terminal': {'background': '#000000', 'foreground': '#ffffff'}, 'colors': {
        'background': '#000000', 'on_background': '#ffffff', 'on_surface': '#ffffff',
        'on_surface_variant': '#aaaaaa', 'error': accent, 'secondary': accent,
        'tertiary': accent, 'primary': accent}}
base = "palette = 'matugen'\n[character]\nsuccess_symbol = '[❯](accent)'\n[palettes.matugen]\naccent = '#ffffff'\n"
a, b = (generate(base, fixture(color)) for color in ('#dd5555', '#5555dd'))
assert tomllib.loads(a)['palettes']['matugen'] != tomllib.loads(b)['palettes']['matugen']
assert tomllib.loads(a)['character'] == tomllib.loads(base)['character']
assert generate(a, fixture('#dd5555')) == a
for value in tomllib.loads(a)['palettes']['matugen'].values():
    assert contrast(rgb(value), rgb('#000000')) >= 4.5
try:
    rgb('#oops')
    raise AssertionError('Invalid color accepted')
except ValueError:
    pass
print('PASS: dark/light/low-contrast palettes, wallpaper change, idempotence, validation')
