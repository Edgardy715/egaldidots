"""Real IPC reload across atomic palette generations; isolated, no wallpaper change."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'bar/matugen-reload-regression.qml'
PIPELINE = ROOT / 'matugen/.config/matugen/generate.py'
with tempfile.TemporaryDirectory(prefix='isla-palette-ipc-') as directory:
    base = Path(directory)
    # Real Matugen output, used without any native templates/reload hooks.
    native = json.loads(subprocess.check_output(['matugen','--dry-run','--json','hex','color','hex','#4285f4'], text=True))
    cache = base/'matugen'; cache.mkdir()
    configs = base/'config'; shell = configs/'quickshell/bar'; shell.mkdir(parents=True)
    (shell/'shell.qml').symlink_to(FIXTURE)
    for entry in (ROOT/'bar').iterdir():
        if entry.is_dir(): (shell/entry.name).symlink_to(entry, target_is_directory=True)
    seed = dict(version=1,generator='matugen',mode='dark',wallpaper='/fixture-a.png',
                colors={key:value['dark']['color'] for key,value in native['colors'].items()})
    for index, primary in [(1,'#adc6ff'),(2,'#ffb3af'),(3,'#9bd49c')]:
        generation = cache/str(index); generation.mkdir()
        data={**seed,'wallpaper':f'/fixture-{index}.png','colors':{**seed['colors'],'primary':primary}}
        (generation/'palette.json').write_text(json.dumps(data))
    (cache/'current').symlink_to('1'); (cache/'palette.json').symlink_to('current/palette.json')
    config=base/'settings.json';config.write_text(json.dumps({'paths':{'paletteFile':str(cache/'palette.json')}}))
    env=dict(os.environ, ISLA_CONFIG=str(config), QT_QPA_PLATFORM='offscreen')
    log=base/'shell.log'
    with log.open('w') as handle:
        process=subprocess.Popen(['quickshell','-p',str(shell)],env=env,stdout=handle,stderr=subprocess.STDOUT)
        try:
            def status():
                result=subprocess.run(['quickshell','-p',str(shell),'ipc','call','island','paletteStatus'],env=env,capture_output=True,text=True)
                try:return json.loads(result.stdout)
                except ValueError:return {}
            def expect(primary):
                until=time.monotonic()+3
                while time.monotonic()<until:
                    value=status()
                    if value.get('loaded') and value.get('primary')==primary:return
                    time.sleep(.04)
                raise AssertionError(f'Expected {primary}, got {value}; {log.read_text()}')
            expect('#adc6ff')
            import importlib.util
            spec=importlib.util.spec_from_file_location('pipeline',PIPELINE)
            pipeline=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipeline)
            real_optional = pipeline.optional
            def isolated_reload(command, label, allowed_codes=()):
                if label == 'Isla': real_optional(command, label, allowed_codes)
            pipeline.optional = isolated_reload
            pipeline.running = lambda name: False
            for index,primary in [(2,'#ffb3af'),(3,'#9bd49c')]:
                temporary=cache/'next';temporary.symlink_to(str(index));temporary.replace(cache/'current')
                invalid=subprocess.run(['quickshell','-p',str(shell),'ipc','call','island','reloadColors',''],
                                       env=env,capture_output=True,text=True)
                assert 'Too many arguments' in invalid.stdout + invalid.stderr
                # Exact production command builder, not a separately hand-written IPC call.
                pipeline.reload_clients(configs)
                expect(primary)
            print('PASS: real IPC applies two atomic palette swaps without reloading the shell')
        finally:
            process.terminate();process.wait(timeout=3)
