"""Measure the recovered pre-A pet core in the current benchmark/environment."""
import importlib.util
import json
from pathlib import Path
import shutil
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('bench', ROOT / 'bar/tests/pets-performance.py')
bench = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bench)
assert not bench.offscreen_processes(), bench.offscreen_processes()
runs = []
with tempfile.TemporaryDirectory(prefix='isla-phase1-matched-') as temporary:
    folder = Path(temporary)
    shutil.copytree(ROOT / 'bar', folder / 'bar')
    with tarfile.open(OUT / 'source.tar.gz') as archive:
        archive.extractall(folder, filter='data')
    fixture = folder / 'bar/pets-performance.qml'
    text = fixture.read_text()
    binding = '; coding: root.scenario === "coding"'
    assert text.count(binding) == 1
    fixture.write_text(text.replace(binding, ''))
    actor = folder / 'bar/pets/PetActor.qml'
    source = actor.read_text()
    assert 'Math.random()' in source and 'property var random:' not in source
    actor.write_text(source.replace('Math.random()', 'random()').replace('    id: actor', '    id: actor\n    property var random: () => Math.random()', 1))
    bench.ROOT = folder
    config = folder / 'config.json'
    config.write_text('{}\n')
    for index, scenarios in enumerate((('disabled', 'idle'), ('idle', 'disabled')), 1):
        for scenario in scenarios:
            result = bench.measure('mimo', scenario, 5, config, OUT / f'round{index}-{scenario}.log')
            runs.append({'round': index, **result})
            print(json.dumps({key: result[key] for key in ('scenario', 'tree_cpu_percent', 'tree_pss_kib_median', 'framesPerSecond')}), flush=True)
result = {'method': 'same current harness, pre-A core and37-frame pack, original9-field Settings; unused coding binding removed; original Math.random calls exposed through one injected random property for the same idle RNG control; same5s windows and warmup',
          'sources': json.loads((OUT / 'source-sha256.json').read_text()), 'runs': runs, 'summary': bench.summarize(runs)}
(OUT / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
assert result['summary']['idle']['framesPerSecond'] <= 1.5
print('PASS: matched pre-A baseline', flush=True)
