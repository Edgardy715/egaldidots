#!/usr/bin/env python3
"""Back up conflicts and unfold links owned by this checkout before GNU Stow.

Foreign directory symlinks are rejected before any changes: following them would
modify another tree. Unrelated files in real directories are left in place.
"""
import os
from pathlib import Path
import shutil
import sys


def prepare(repo, home, backup, packages):
    repo, home, backup = map(lambda p: Path(p).absolute(), (repo, home, backup))
    sources = []
    for package in packages:
        for directory, dirs, files in os.walk(repo / package, followlinks=False):
            for name in list(dirs):
                if (Path(directory) / name).is_symlink():
                    dirs.remove(name)
                    files.append(name)
            for name in files:
                source = Path(directory) / name
                sources.append((source, source.relative_to(repo / package)))
    # Include generated destinations in the same ancestor safety check.
    data = Path(os.environ.get('XDG_DATA_HOME', home / '.local/share'))
    state = Path(os.environ.get('XDG_STATE_HOME', home / '.local/state'))
    generated = [Path('.config/quickshell/bar'), Path('.config/hypr/local.hardware.conf'),
                 Path('.cache/wal/colors.json'), (data / 'isla/qml/Wpscan').relative_to(home),
                 (data / 'quickshell-lockscreen/lock.sh').relative_to(home),
                 (data / 'themes/FlatColor/.check').relative_to(home),
                 (data / 'nvim/lazy/lazy.nvim/.check').relative_to(home),
                 (state / 'isla/.check').relative_to(home)]
    for _, rel in sources + [(None, p) for p in generated]:
        for parent in (home / rel).parents:
            if parent == home:
                break
            if parent.is_symlink() and not parent.resolve().is_relative_to(repo):
                raise RuntimeError(f'Foreign directory symlink: {parent}. Replace it with a real directory before installing.')

    ancestor_count = 0

    def save(path, ancestor=False):
        nonlocal ancestor_count
        if ancestor:
            # A backup symlink at backup/.config would redirect all subsequent
            # child backups into the source repo. Store ancestor links apart.
            ancestor_count += 1
            record = backup / 'directory-links' / str(ancestor_count)
            record.mkdir(parents=True)
            (record / 'original-path.txt').write_text(str(path) + '\n')
            dest = record / 'target'
        else:
            dest = backup / path.relative_to(home)
        if dest.exists() or dest.is_symlink():
            raise RuntimeError(f'Duplicate backup target: {dest}')
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), str(dest))
        print(f'Backup: {path} -> {dest}')

    def parents_for(path):
        parents = []
        parent = path.parent
        while parent != home:
            parents.append(parent)
            parent = parent.parent
        for parent in reversed(parents):
            if parent.is_symlink():
                # An earlier Stow run may have folded a complete directory.
                original = parent.resolve()
                children = list(original.iterdir()) if original.is_dir() else []
                save(parent, ancestor=True)
                parent.mkdir()
                for child in children:
                    (parent / child.name).symlink_to(os.path.relpath(child, parent))
            elif parent.exists() and not parent.is_dir():
                save(parent, ancestor=True)
                parent.mkdir()
            else:
                parent.mkdir(exist_ok=True)

    for source, rel in sorted(sources, key=lambda item: str(item[1])):
        target = home / rel
        parents_for(target)
        if target.is_symlink() and target.resolve() == source.resolve():
            # GNU Stow treats absolute links as foreign even if they point at
            # this checkout. Normalize them when migrating an older install.
            if os.path.isabs(os.readlink(target)):
                target.unlink()
                target.symlink_to(os.path.relpath(source, target.parent))
            continue
        if target.exists() or target.is_symlink():
            save(target)
    for rel in generated:
        parents_for(home / rel)


if __name__ == '__main__':
    try:
        prepare(*sys.argv[1:4], sys.argv[4:])
    except (OSError, RuntimeError) as error:
        sys.exit(str(error))
