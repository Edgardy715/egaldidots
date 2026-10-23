"""Resumen determinista de las mediciones; CPU equivale a un núcleo Linux."""
import json
from pathlib import Path
import statistics

root = Path(__file__).resolve().parent

def load(name):
    return json.loads((root / name).read_text())


def thread_cpu(path):
    values = []
    for block in path.read_text().split('top - ')[2:]:
        totals = {'main': 0.0, 'render': 0.0}
        for line in block.splitlines():
            fields = line.split()
            if len(fields) >= 12 and fields[0].isdigit():
                if fields[11] == 'qs':
                    totals['main'] += float(fields[8])
                elif fields[11].startswith('QSGRend'):
                    totals['render'] += float(fields[8])
        values.append(totals)
    return values


for index, row in enumerate(load('music-comparison.json')):
    for scenario, label in [('compact', 'compact'), ('expanded', 'media')]:
        sample = row[scenario]
        threads = thread_cpu(root / f'{index}-{row["variant"]}-{label}-top.txt')
        print('music', index, row['variant'], scenario,
              round(sample['cpu_percent'], 3), sample['memory_after'],
              {key: round(statistics.mean(t[key] for t in threads), 3) for key in ['main', 'render']})
if (root / 'memory-batches.json').exists():
    for row in load('memory-batches.json'):
        print('memory', row['label'], round(row['Pss_kib'] / 1024, 3), round(row['Rss_kib'] / 1024, 3))
if (root / 'rust-ab-comparison.json').exists():
    for row in load('rust-ab-comparison.json'):
        after = row['samples'][-1]['processes']
        frames = json.loads(row['state'])['frames'] - json.loads(row['state_before'])['frames']
        print('rust', row['variant'], round(row['cpu_qs'], 3), round(row['cpu_total'], 3),
              round(sum(p['Pss_kib'] for p in after.values()) / 1024, 3),
              round(frames / row['seconds'], 3), 'updates/s')
if (root / 'idle-comparison.json').exists():
    for row in load('idle-comparison.json'):
        print('idle', row['variant'], round(row['measurement']['cpu_percent'], 3), row['measurement']['memory_after'])
