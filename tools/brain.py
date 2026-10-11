#!/usr/bin/env python3
"""Build navigable Obsidian source cards; search current source, never summaries."""
import argparse
from collections import defaultdict
from datetime import datetime
from pathlib import Path
import re
import subprocess
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
VAULT = Path.home() / 'Documents/Segundo Cerebro/Isla'
EXCLUDES = ['!.git/**', '!**/__pycache__/**', '!**/node_modules/**', '!**/.venv/**', '!**/.obsidian/**']
DECL = re.compile(r'^\s*(?:(?:readonly|required|default)\s+)?(?:property\s+\w+\s+\w+|signal\s+\w+|(?:async\s+)?function\s+\w+|(?:async\s+)?def\s+\w+|class\s+\w+|(?:export\s+)?(?:const|let|var)\s+\w+|import\s+|pragma\s+|#{1,4}\s+|\w+\s*\(\)\s*\{)')


def inventory():
    args = ['rg', '--files', '--hidden', '--no-require-git']
    for glob in EXCLUDES:
        args += ['-g', glob]
    safe = set(subprocess.check_output(args, cwd=ROOT, text=True).splitlines())
    all_files = set(subprocess.check_output(args + ['--no-ignore'], cwd=ROOT, text=True).splitlines())
    for name in ('PROJECT_MEMORY.md', 'TASK_STATE.md', 'AGENTS.md'):
        if (ROOT / name).is_file():
            safe.add(name)
            all_files.add(name)
    # Ignored files remain discoverable by path, without indexing private content.
    texts = {}
    for name in sorted(safe):
        path = ROOT / name
        if not path.is_file() or path.is_symlink():
            continue
        try:
            text = path.read_text(encoding='utf-8')
            if '\0' not in text:
                texts[name] = text
        except (UnicodeError, OSError):
            pass
    return sorted(all_files), texts


def link(name):
    return f'[[Archivos/{name}|{name}]]'


def source(name, line=1):
    return f'[{name}:{line}](file://{quote(str(ROOT / name))})'


def refresh():
    files, texts = inventory()
    groups = defaultdict(list)
    target = VAULT / 'Archivos'
    target.mkdir(parents=True, exist_ok=True)
    # Remove only stale generated cards bearing our ownership marker.
    desired = {target / (name + '.md') for name in files}
    for path in target.rglob('*.md'):
        if path not in desired and path.read_text().startswith('<!-- isla-brain-generated -->'):
            path.unlink()
    for name in files:
        folder = str(Path(name).parent)
        folder = 'Raiz' if folder == '.' else folder
        groups[folder].append(name)
        path = target / (name + '.md')
        path.parent.mkdir(parents=True, exist_ok=True)
        text = texts.get(name)
        rows = text.splitlines() if text is not None else []
        ignored = name not in texts
        out = ['<!-- isla-brain-generated -->', f'# {name}', '',
               f'Fuente real: {source(name)}', '',
               f'Tamaño: {(ROOT / name).stat().st_size} bytes. Líneas: {len(rows) if text is not None else "no indexadas"}.',
               'Contenido no indexado (ignorado, binario, enlace o no UTF-8).' if ignored else 'Ficha extraída de la fuente; no es una explicación semántica ni una certificación de comportamiento.',
               '', f'Carpeta: [[Carpetas/{folder}|{folder}]]', '', '## Declaraciones y encabezados']
        declarations = [(i, row.strip()) for i, row in enumerate(rows, 1) if DECL.match(row)]
        out += [f'- L{i}: `{row.replace(chr(96), chr(39))}` — {source(name, i)}' for i, row in declarations]
        if not declarations:
            out += ['Sin declaraciones reconocidas; consultar fuente o búsqueda de contenido.']
        # Exact filename tokens only; this is navigation evidence, not a resolved import graph.
        stem = Path(name).stem
        if text is not None and Path(name).suffix in ('.qml', '.js', '.py', '.cjs'):
            pattern = re.compile(r'(?<![\w])' + re.escape(stem) + r'(?![\w])')
            refs = [other for other, body in texts.items() if other != name and pattern.search(body)]
            out += ['', '## Referencias candidatas al nombre', 'Coincidencias textuales; pueden ser menciones o pruebas, no llamadas reales.']
            out += ['- ' + link(other) for other in refs]
        path.write_text('\n'.join(out) + '\n')
    for folder, names in groups.items():
        path = VAULT / 'Carpetas' / (folder + '.md')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f'# {folder}\n\n{len(names)} archivos.\n\n' + '\n'.join('- ' + link(n) for n in names) + '\n')
    (VAULT / 'Catalogo completo.md').write_text('# Catálogo completo\n\n' +
        f'Generado: {datetime.now().isoformat(timespec="seconds")}. {len(files)} archivos; {len(texts)} fuentes textuales indexadas.\n\n' +
        'Incluye archivos ignorados por ruta, sin su contenido. Excluye .git, cachés Python, node_modules, .venv y .obsidian.\n\n' +
        '\n'.join(f'## {folder}\n\n' + '\n'.join('- ' + link(n) for n in names) + '\n' for folder, names in sorted(groups.items())))
    assert len(list(target.rglob('*.md'))) == len(files), 'Card coverage mismatch'
    assert all((target / (name + '.md')).is_file() for name in files)
    print(f'PASS: {len(files)} fichas, {len(groups)} carpetas, {len(texts)} fuentes textuales; cobertura completa del inventario definido.')


def search(query, limit):
    _, texts = inventory()
    hits = [(name, i, row) for name, text in texts.items()
            for i, row in enumerate(text.splitlines(), 1) if query.casefold() in row.casefold()]
    report = Path.home() / '.cache/isla-brain/search.txt'
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text('\n'.join(f'{ROOT / name}:{i}:{row}' for name, i, row in hits) + '\n')
    print(f'{len(hits)} coincidencias literales; se muestran hasta {limit}. Completo: {report}')
    for name, i, row in hits[:limit]:
        print(f'{ROOT / name}:{i}:{row}')
    if not hits:
        print('Sin coincidencias literales en fuentes textuales indexables; no prueba ausencia conceptual. Consultar catálogo, reformular o recall.py.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--search', help='Literal case-insensitive search in live project files')
    parser.add_argument('--limit', type=int, default=40)
    args = parser.parse_args()
    if args.limit < 1 or (args.search is not None and not args.search.strip()):
        parser.error('Use nonempty search and positive limit')
    if args.search is None:
        refresh()
    else:
        search(args.search, args.limit)


if __name__ == '__main__':
    main()
