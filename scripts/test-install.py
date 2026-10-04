"""Recovery regression: real GNU Stow; package/desktop commands are simulated.

Runs in temporary homes. No package installs, user shell changes or real locks.
Requires Python, ripgrep and GNU Stow (or STOW_BIN pointing at the real executable).
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
STOW = os.environ.get('STOW_BIN') or shutil.which('stow')
if not STOW:
    raise SystemExit('GNU Stow is required for this test')
if not shutil.which('rg'):
    raise SystemExit('ripgrep (rg) is required for this test')

FAKE = r'''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
name=Path(sys.argv[0]).name
args=sys.argv[1:]
root=Path(os.environ['FAKE_ROOT']); home=Path(os.environ['HOME'])
with (root/'commands.jsonl').open('a') as log: log.write(json.dumps([name,*args])+'\n')
if name==os.environ.get('FAIL_COMMAND'): sys.exit(17)
if name=='sudo':
    if args==['-v']: sys.exit(0)
    os.execvp(args[0],args)
if name=='pacman':
    if args and args[0]=='-Si' and args[1] in ('python-pywal16','wpgtk','ttf-google-sans-flex'): sys.exit(1)
elif name=='git' and args[0]=='clone':
    dest=Path(args[-1]); dest.mkdir(parents=True)
    if 'wpgtk-templates' in args[-2]:
        for rel in ('gtk-2.0/gtkrc','gtk-3.0/gtk.css','gtk-3.20/gtk.css'):
            f=dest/'FlatColor'/rel;f.parent.mkdir(parents=True,exist_ok=True)
            f.write_text('theme\n');Path(str(f)+'.base').write_text('template\n')
elif name=='makepkg':
    f=root/'bin/yay'; f.symlink_to(root/'fake')
elif name=='fc-match': print('Google Sans Flex')
elif name=='quickshell' and 'authDebug' in args: print('registered=true active=false')
elif name=='curl': Path(args[args.index('-o')+1]).write_text('# simulated fisher download\n')
elif name=='fish' and any('fisher install' in arg for arg in args):
    functions=home/'.config/fish/functions';functions.mkdir(parents=True,exist_ok=True)
    (home/'.config/fish/fish_plugins').write_text('jorgebucaran/fisher\npatrickf1/fzf.fish\n# rewritten by fisher\n')
    (functions/'fisher.fish').write_text('fisher')
    (functions/'fzf_configure_bindings.fish').write_text('fzf')
elif name=='cmake' and '-B' in args:
    module=Path(args[args.index('-B')+1])/'Wpscan';module.mkdir()
    (module/'qmldir').write_text('module Wpscan\nplugin wpscanpluginplugin\n')
elif name=='wal':
    cache=home/'.cache/wal';cache.mkdir(parents=True,exist_ok=True)
    palette={'background':'#1e1e2e','foreground':'#cdd6f4',**{f'color{i}':'#89b4fa' for i in range(16)}}
    (cache/'colors.sh').write_text('\n'.join(f"{k}='{v}'" for k,v in palette.items()))
    (cache/'colors.json').write_text(json.dumps({'special':{'background':'#1e1e2e','foreground':'#cdd6f4'},'colors':{f'color{i}':'#89b4fa' for i in range(16)}}))
    (cache/'wal').write_text(args[args.index('-i')+1])
elif name=='wpg' and '-l' in args: print('')
elif name=='fish' and any('type -q fisher' in arg for arg in args):
    sys.exit(0 if (home/'.config/fish/functions/fzf_configure_bindings.fish').exists() else 1)
'''


class Recovery(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='egaldidots-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'checkout with spaces'
        shutil.copytree(REPO, self.repo, ignore=shutil.ignore_patterns('.git', '__pycache__'))
        self.home = self.root / 'home'; self.home.mkdir()
        walls = self.repo / 'wallpapers/Wallpapers'; walls.mkdir(parents=True, exist_ok=True)
        (walls / 'test wall.png').write_bytes(b'fake wallpaper for simulated image commands')
        # Fixture-only OS and PAM selectors. Production installer has no bypass.
        os_release = self.root / 'os-release'; os_release.write_text('ID=arch\nNAME=Arch\n')
        pam = self.root / 'hyprlock-pam'; pam.write_text('fixture')
        installer = self.repo / 'install.sh'
        installer.write_text(installer.read_text().replace('/etc/os-release', str(os_release)).replace('/etc/pam.d/hyprlock', str(pam)))
        self.bin = self.root / 'bin'; self.bin.mkdir()
        fake = self.root / 'fake'; fake.write_text(FAKE); fake.chmod(0o755)
        commands = ('Hyprland hyprctl hypridle hyprlock quickshell qs fish starship kitty nvim micro fastfetch bat eza zoxide fzf fd rg lazygit jq playerctl wl-copy wl-paste cliphist wl-clip-persist brightnessctl hyprshot notify-send pavucontrol thunar magick awww wal wpg cmake curl nmcli wpctl pactl cava gsettings fc-cache fc-match gh ruff shfmt node npm sudo pacman yay systemctl chsh git makepkg').split()
        # rg is real: the wallpaper name matching is part of the tested flow.
        commands.remove('rg')
        for name in commands: (self.bin / name).symlink_to(fake)
        (self.bin / 'stow').symlink_to(STOW)
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin)+':'+os.environ['PATH'], FAKE_ROOT=str(self.root))
        for var in ('XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
            self.env.pop(var, None)

    def run_install(self, *args, success=True):
        result = subprocess.run(['bash', str(self.repo/'install.sh'), *args], env=self.env, capture_output=True, text=True)
        if success: self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        else: self.assertNotEqual(result.returncode, 0, result.stdout+result.stderr)
        return result

    def commands(self):
        return [json.loads(line) for line in (self.root/'commands.jsonl').read_text().splitlines()]

    def test_fresh_restore_and_repeat(self):
        original = self.repo/'rofi/.config/rofi/themes/wallpaper-picker.rasi'
        original_text = original.read_text()
        manifest = self.repo/'fish/.config/fish/fish_plugins'
        manifest_text = manifest.read_text()
        self.run_install()
        self.assertTrue((self.home/'.config/quickshell/bar').is_symlink())
        self.assertTrue((self.home/'.local/bin/isla').is_symlink())
        self.assertTrue((self.home/'.cache/wal/current-wallpaper').is_symlink())
        self.assertEqual(original.read_text(), original_text, 'generated theme changed source checkout')
        self.assertEqual(manifest.read_text(), manifest_text, 'Fisher changed source manifest')
        self.assertIn('monitor=,preferred,auto,1', (self.home/'.config/hypr/modules/monitors.conf').read_text())
        hardware = self.home/'.config/hypr/local.hardware.conf'
        hardware.write_text('# personal override\n')
        self.run_install('--stow-only', '--keep-shell')
        self.assertEqual(hardware.read_text(), '# personal override\n')
        self.run_install('--check')
        calls = self.commands()
        self.assertTrue(any(c[:2] == ['pacman', '-Syu'] for c in calls))
        self.assertFalse(any(c[:2] == ['pacman', '-Sy'] for c in calls))
        self.assertTrue(any(c[:2] == ['yay', '-S'] for c in calls))

    def test_existing_config_backup(self):
        config = self.home/'.config/fish'; config.mkdir(parents=True)
        (config/'config.fish').write_text('previous config')
        (config/'unrelated.fish').write_text('keep me')
        self.run_install('--stow-only', '--keep-shell')
        backup = list(self.home.glob('.egaldidots-backup-*/.config/fish/config.fish'))
        self.assertEqual(len(backup), 1)
        self.assertEqual(backup[0].read_text(), 'previous config')
        self.assertEqual((config/'unrelated.fish').read_text(), 'keep me')

    def test_foreign_directory_symlink_is_not_followed(self):
        foreign = self.root/'foreign'; foreign.mkdir(); (foreign/'keep').write_text('unchanged')
        (self.home/'.config').symlink_to(foreign)
        result = self.run_install('--stow-only', success=False)
        self.assertIn('Foreign directory symlink', result.stderr)
        self.assertEqual(list(foreign.iterdir()), [foreign/'keep'])

    def test_failed_dependencies_cannot_report_success(self):
        for cmd in ('pacman', 'yay'):
            self.env['FAIL_COMMAND'] = cmd
            result = self.run_install('--deps-only', success=False)
            self.assertNotIn('Completed successfully', result.stdout)
            self.assertFalse((self.home/'.config').exists())

    def test_helper_bootstrap(self):
        (self.bin/'yay').unlink()
        self.run_install('--deps-only')
        self.assertIn(['makepkg','-si','--needed','--noconfirm'], self.commands())

    def test_plugin_failure_cannot_report_success(self):
        self.env['FAIL_COMMAND'] = 'quickshell'
        result = self.run_install('--stow-only', success=False)
        self.assertNotIn('Completed successfully', result.stdout)

    def test_original_hardware_profile(self):
        self.run_install('--stow-only','--hardware-profile','original')
        self.assertIn('monitor=eDP-1, disable', (self.home/'.config/hypr/local.hardware.conf').read_text())

    def test_palette_failure_cannot_report_success(self):
        self.env['FAIL_COMMAND'] = 'wal'
        result = self.run_install('--stow-only', success=False)
        self.assertNotIn('Completed successfully', result.stdout)

    def test_missing_wallpaper_fails(self):
        self.run_install('--stow-only','--wallpaper', str(self.root/'missing.png'), success=False)

    def test_legacy_folded_stow_links_do_not_change_checkout(self):
        (self.home/'.config').symlink_to(self.repo/'hypr/.config')
        original = {str(p.relative_to(self.repo)):p.read_bytes() for p in self.repo.rglob('*') if p.is_file()}
        self.run_install('--stow-only', '--keep-shell')
        after = {str(p.relative_to(self.repo)):p.read_bytes() for p in self.repo.rglob('*') if p.is_file()}
        self.assertEqual(original, after, 'unfolding/backup wrote into source checkout')
        self.assertFalse((self.home/'.config').is_symlink())
        self.assertTrue(list(self.home.glob('.egaldidots-backup-*/directory-links/*/original-path.txt')))

    def test_custom_data_and_state_directories(self):
        self.env['XDG_DATA_HOME'] = str(self.home/'data')
        self.env['XDG_STATE_HOME'] = str(self.home/'state')
        self.run_install('--stow-only', '--keep-shell')
        self.assertTrue((self.home/'data/isla/qml/Wpscan/qmldir').is_file())
        self.assertTrue((self.home/'data/quickshell-lockscreen/lock.sh').is_file())

    def test_conflicting_modes(self):
        self.run_install('--deps-only', '--stow-only', success=False)


if __name__ == '__main__':
    unittest.main(verbosity=2)
