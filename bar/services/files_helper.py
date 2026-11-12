#!/usr/bin/env python3
"""File operations for Azog's file explorer.

CLI: python3 files_helper.py <op>
Reads one JSON request line from stdin and writes NDJSON events to stdout:
  {"event":"progress","done":int,"total":int,"current":str}
  {"event":"item_error","path":str,"error":str}
  {"event":"done","ok":bool,"cancelled":bool,"undo":{...}|null,"result":...}
Ops: conflicts, copy, move, moveback, trash, restore, rename, mkdir, thumb.
Nothing here ever deletes user data definitively: trashing renames into the
FreeDesktop trash, and a cross-device move deletes the source only after the
copy finished without errors.
"""
import errno
import hashlib
import json
import os
import shutil
import signal
import stat
import subprocess
import sys
import threading
import time
import urllib.parse
from pathlib import Path

CHUNK = 1024 * 1024
PROGRESS_INTERVAL = 0.05  # max 20 progress events per second
CANCEL = threading.Event()
POLICIES = ("skip", "keepboth", "overwrite")


class Rejected(Exception):
    pass


class Cancelled(Exception):
    pass


# --------------------------------------------------------------------------
# validation and naming

def require_abs(path, what="path"):
    if not isinstance(path, str) or not path or "\0" in path or not os.path.isabs(path):
        raise Rejected(f"{what} must be an absolute path")
    if len(path) > 1:
        path = path.rstrip("/") or "/"
    if os.path.basename(path) in (".", ".."):
        raise Rejected(f"{what} may not end in '.' or '..'")
    return path


def require_name(name):
    if (not isinstance(name, str) or not name or name in (".", "..")
            or "/" in name or "\0" in name):
        raise Rejected("invalid name")
    return name


def split_name(name):
    stem, ext = os.path.splitext(name)
    if not stem:  # dotfile such as ".bashrc"
        return name, ""
    return stem, ext


def candidate_names(name):
    yield name
    stem, ext = split_name(name)
    n = 2
    while True:
        yield f"{stem} ({n}){ext}"
        n += 1


def unique_name(dest_dir, name):
    dest_dir = Path(dest_dir)
    for candidate in candidate_names(name):
        if not os.path.lexists(dest_dir / candidate):
            return candidate


def plan_conflicts(sources, dest):
    out = []
    for source in sources:
        source = require_abs(source)
        if os.path.realpath(os.path.dirname(source)) == os.path.realpath(dest):
            continue  # pasting into the source folder: the helper keeps both
        name = os.path.basename(source)
        if name and os.path.lexists(os.path.join(dest, name)) and name not in out:
            out.append(name)
    return out


def same_device(path, other):
    return os.lstat(path).st_dev == os.stat(other).st_dev


def inside(child, parent):
    child, parent = os.path.realpath(child), os.path.realpath(parent)
    return child == parent or child.startswith(parent.rstrip("/") + "/")


# --------------------------------------------------------------------------
# progress / context

class Ctx:
    def __init__(self, emit, total=0):
        self.emit = emit
        self.total = total
        self.done = 0
        self.errors = 0
        self.last = 0.0
        self.current = ""

    def check(self):
        if CANCEL.is_set():
            raise Cancelled()

    def error(self, path, message):
        self.errors += 1
        self.emit({"event": "item_error", "path": path, "error": str(message)})

    def progress(self, force=False):
        now = time.monotonic()
        if not force and now - self.last < PROGRESS_INTERVAL:
            return
        self.last = now
        done = min(self.done, self.total)
        self.emit({"event": "progress", "done": done, "total": self.total, "current": self.current})

    def advance(self, amount):
        self.done += amount
        self.progress()

    def settle(self, value, current=None):
        if current is not None:
            self.current = current
        self.done = max(self.done, value)
        self.progress()


def done_event(ctx, cancelled=False, undo=None, result=None, ok=None):
    if ok is None:
        ok = not cancelled and ctx.errors == 0
    return {"event": "done", "ok": bool(ok), "cancelled": cancelled, "undo": undo, "result": result}


def rejected(emit, message, path=""):
    emit({"event": "item_error", "path": path, "error": str(message)})
    return {"event": "done", "ok": False, "cancelled": False, "undo": None, "result": None}


def cost_of(path):
    """Progress cost of a tree: bytes of regular files, 1 for every other node."""
    try:
        st = os.lstat(path)
    except OSError:
        return 1
    if stat.S_ISREG(st.st_mode):
        return max(st.st_size, 1)
    if not stat.S_ISDIR(st.st_mode):
        return 1
    total = 1
    stack = [path]
    while stack:
        current = stack.pop()
        try:
            with os.scandir(current) as it:
                for entry in it:
                    try:
                        est = entry.stat(follow_symlinks=False)
                    except OSError:
                        total += 1
                        continue
                    if stat.S_ISDIR(est.st_mode):
                        total += 1
                        stack.append(entry.path)
                    elif stat.S_ISREG(est.st_mode):
                        total += max(est.st_size, 1)
                    else:
                        total += 1
        except OSError:
            continue
    return total


# --------------------------------------------------------------------------
# copy engine

def tmp_sibling(target):
    return os.path.join(os.path.dirname(target), f".{os.path.basename(target)}.azog-{os.getpid()}.tmp")


def copy_file(src, dst, ctx, overwrite):
    """Copy a regular file in 1 MiB chunks. A partial result is removed on failure."""
    ctx.current = src
    target = tmp_sibling(dst) if overwrite else dst
    created = False
    try:
        with open(src, "rb") as fin:
            with open(target, "wb" if overwrite else "xb") as fout:
                created = True
                while True:
                    ctx.check()
                    chunk = fin.read(CHUNK)
                    if not chunk:
                        break
                    fout.write(chunk)
                    ctx.advance(len(chunk))
        shutil.copystat(src, target, follow_symlinks=False)
        if overwrite:
            os.replace(target, dst)
            created = False
        ctx.advance(1 if os.path.getsize(dst) == 0 else 0)
    except BaseException:
        if created and os.path.lexists(target):
            try:
                os.unlink(target)
            except OSError:
                pass
        raise


def copy_node(src, dst, ctx, overwrite, copied=None):
    """Copy one node without following symlinks. Errors are reported, never raised
    (except cancellation); returns True when the whole subtree was copied."""
    ctx.check()
    try:
        st = os.lstat(src)
        if stat.S_ISLNK(st.st_mode):
            link = os.readlink(src)
            if overwrite and os.path.lexists(dst):
                tmp = tmp_sibling(dst)
                os.symlink(link, tmp)
                try:
                    os.replace(tmp, dst)
                except OSError:
                    os.unlink(tmp)
                    raise
            else:
                os.symlink(link, dst)
            ctx.advance(1)
            if copied is not None:
                copied.append((src, False))
            return True
        if stat.S_ISREG(st.st_mode):
            copy_file(src, dst, ctx, overwrite)
            if copied is not None:
                copied.append((src, False))
            return True
        if stat.S_ISDIR(st.st_mode):
            ok = True
            if os.path.isdir(dst) and not os.path.islink(dst):
                if not overwrite:
                    raise FileExistsError(errno.EEXIST, "File exists", dst)
            else:
                os.mkdir(dst)
            ctx.advance(1)
            try:
                with os.scandir(src) as it:
                    children = sorted(entry.name for entry in it)
            except OSError as exc:
                ctx.error(src, exc)
                return False
            for name in children:
                if not copy_node(os.path.join(src, name), os.path.join(dst, name), ctx, overwrite, copied):
                    ok = False
            try:
                shutil.copystat(src, dst, follow_symlinks=False)
            except OSError:
                pass
            if copied is not None:
                copied.append((src, True))
            return ok
        ctx.error(src, "unsupported file type")
        ctx.advance(1)
        return False
    except Cancelled:
        raise
    except OSError as exc:
        ctx.error(src, exc)
        return False


def remove_copied(copied, ctx):
    """Delete only the source nodes that were really copied (post-order). Directories
    are removed only when empty, so anything that appeared in the source during the
    copy survives and is reported. Returns True when nothing was left behind."""
    clean = True
    for path, is_dir in copied:
        try:
            if is_dir:
                os.rmdir(path)
            else:
                os.unlink(path)
        except OSError as exc:
            clean = False
            ctx.error(path, f"copied but source not removed: {exc}")
    return clean


def resolve_target(src, dest, policy, moving):
    """Return (target, overwrite) or None when the item is skipped."""
    name = os.path.basename(src)
    target = os.path.join(dest, name)
    if not os.path.lexists(target):
        return target, False
    same_place = os.path.realpath(os.path.dirname(src)) == os.path.realpath(dest)
    if same_place:
        if moving:
            return None
        return os.path.join(dest, unique_name(dest, name)), False
    if policy == "keepboth":
        return os.path.join(dest, unique_name(dest, name)), False
    if policy == "overwrite":
        return target, True
    return None


def transfer(req, emit, moving):
    try:
        sources = req.get("sources")
        if not isinstance(sources, list) or not sources:
            raise Rejected("sources must be a non-empty list")
        sources = [require_abs(s, "source") for s in sources]
        dest = require_abs(req.get("dest"), "dest")
    except Rejected as exc:
        return rejected(emit, exc)
    policy = req.get("conflict")
    if policy not in POLICIES:
        policy = "skip"
    if not os.path.isdir(dest):
        return rejected(emit, "destination is not a directory", dest)
    for src in sources:
        if not os.path.basename(src):
            return rejected(emit, "cannot transfer the root directory", src)
        if not os.path.lexists(src):
            return rejected(emit, "source does not exist", src)
        if os.path.isdir(src) and not os.path.islink(src) and inside(dest, src):
            return rejected(emit, "cannot place a folder inside itself", src)
    costs = []
    for src in sources:
        if moving and same_device(src, dest):
            costs.append(1)
        else:
            costs.append(cost_of(src))
    ctx = Ctx(emit, sum(costs))
    ctx.progress(force=True)
    pairs = []
    merged = False  # a merge into an existing folder cannot be undone safely
    cumulative = 0
    try:
        for src, cost in zip(sources, costs):
            ctx.check()
            cumulative += cost
            ctx.current = src
            choice = resolve_target(src, dest, policy, moving)
            if choice is None:
                ctx.settle(cumulative, src)
                continue
            target, overwrite = choice
            if moving:
                if overwrite and os.path.isdir(target) and not os.path.islink(target):
                    merged = True
                if move_one(src, target, overwrite, ctx):
                    pairs.append({"from": target, "to": src})
            else:
                copy_node(src, target, ctx, overwrite)
            ctx.settle(cumulative, src)
    except Cancelled:
        undo = {"op": "moveback", "pairs": pairs} if pairs and not merged else None
        return done_event(ctx, cancelled=True, undo=undo)
    ctx.done = ctx.total
    ctx.progress(force=True)
    undo = {"op": "moveback", "pairs": pairs} if moving and pairs and not merged else None
    return done_event(ctx, undo=undo)


def move_one(src, target, overwrite, ctx):
    """Rename when possible, otherwise copy then delete the copied source nodes."""
    merge = (overwrite and os.path.isdir(target) and not os.path.islink(target)
             and os.path.isdir(src) and not os.path.islink(src))
    if not merge:
        try:
            os.rename(src, target)
            return True
        except OSError as exc:
            if exc.errno != errno.EXDEV:
                ctx.error(src, exc)
                return False
    before = ctx.errors
    existed = os.path.lexists(target)
    copied = []
    try:
        ok = copy_node(src, target, ctx, overwrite, copied) and ctx.errors == before
    except Cancelled:
        if not existed:
            shutil.rmtree(target, ignore_errors=True)
        raise
    if not ok:
        return False
    return remove_copied(copied, ctx)


def run_copy(req, emit):
    return transfer(req, emit, moving=False)


def run_move(req, emit):
    return transfer(req, emit, moving=True)


def run_moveback(req, emit):
    try:
        pairs = req.get("pairs")
        if not isinstance(pairs, list):
            raise Rejected("pairs must be a list")
        pairs = [(require_abs(p.get("from"), "from"), require_abs(p.get("to"), "to")) for p in pairs]
    except (Rejected, AttributeError) as exc:
        return rejected(emit, exc)
    ctx = Ctx(emit, len(pairs))
    ctx.progress(force=True)
    try:
        for index, (origin, target) in enumerate(pairs, 1):
            ctx.check()
            ctx.current = origin
            if not os.path.lexists(origin):
                ctx.error(origin, "item no longer exists")
            elif os.path.lexists(target):
                ctx.error(target, "destination already exists")
            else:
                try:
                    os.makedirs(os.path.dirname(target), exist_ok=True)
                except OSError as exc:
                    ctx.error(target, exc)
                else:
                    move_one(origin, target, False, ctx)
            ctx.settle(index)
    except Cancelled:
        return done_event(ctx, cancelled=True)
    return done_event(ctx)


# --------------------------------------------------------------------------
# trash (FreeDesktop.org Trash specification, home trash)

def trash_root():
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local/share")
    return Path(base) / "Trash"


def trash_dirs():
    root = trash_root()
    files, info = root / "files", root / "info"
    for d in (root, files, info):
        d.mkdir(mode=0o700, parents=True, exist_ok=True)
    return files, info


def trashinfo_text(original):
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S")
    return "[Trash Info]\nPath=" + urllib.parse.quote(original, safe="/", errors="surrogateescape") \
        + "\nDeletionDate=" + stamp + "\n"


def trash_one(path, files, info):
    """Move path into the trash. Returns the trashed path. The source is only ever
    renamed, so a failure anywhere leaves it exactly where it was."""
    name = os.path.basename(path)
    for candidate in candidate_names(name):
        info_path = info / (candidate + ".trashinfo")
        target = files / candidate
        if os.path.lexists(target):
            continue
        try:
            fd = os.open(info_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            continue
        try:
            with os.fdopen(fd, "w", encoding="utf-8", errors="surrogateescape") as fp:
                fp.write(trashinfo_text(path))
            os.rename(path, target)
        except BaseException:
            try:
                os.unlink(info_path)
            except OSError:
                pass
            raise
        return str(target)
    raise OSError("no free trash name")


def run_trash(req, emit):
    try:
        paths = req.get("paths")
        if not isinstance(paths, list) or not paths:
            raise Rejected("paths must be a non-empty list")
        paths = [require_abs(p) for p in paths]
    except Rejected as exc:
        return rejected(emit, exc)
    ctx = Ctx(emit, len(paths))
    ctx.progress(force=True)
    entries = []
    try:
        files, info = trash_dirs()
    except OSError as exc:
        return rejected(emit, f"trash unavailable: {exc}")
    try:
        for index, path in enumerate(paths, 1):
            ctx.check()
            ctx.current = path
            try:
                if not os.path.lexists(path):
                    raise FileNotFoundError(errno.ENOENT, "No such file or directory")
                if inside(path, trash_root()):
                    raise OSError("already in the trash")
                if same_device(path, files):
                    entries.append({"trashed": trash_one(path, files, info), "original": path})
                else:
                    result = subprocess.run(["gio", "trash", "--", path], capture_output=True, text=True)
                    if result.returncode != 0:
                        raise OSError((result.stderr or "gio trash failed").strip())
            except OSError as exc:
                ctx.error(path, exc)
            ctx.settle(index)
    except Cancelled:
        undo = {"op": "restore", "entries": entries} if entries else None
        return done_event(ctx, cancelled=True, undo=undo)
    undo = {"op": "restore", "entries": entries} if entries else None
    return done_event(ctx, undo=undo)


def run_restore(req, emit):
    try:
        entries = req.get("entries")
        if not isinstance(entries, list) or not entries:
            raise Rejected("entries must be a non-empty list")
        entries = [(require_abs(e.get("trashed"), "trashed"), require_abs(e.get("original"), "original"))
                   for e in entries]
    except (Rejected, AttributeError) as exc:
        return rejected(emit, exc)
    ctx = Ctx(emit, len(entries))
    ctx.progress(force=True)
    restored = []
    try:
        for index, (trashed, original) in enumerate(entries, 1):
            ctx.check()
            ctx.current = trashed
            try:
                if not os.path.lexists(trashed):
                    raise FileNotFoundError(errno.ENOENT, "item is no longer in the trash")
                parent = os.path.dirname(original)
                os.makedirs(parent, exist_ok=True)
                target = original
                if os.path.lexists(target):
                    target = os.path.join(parent, unique_name(parent, os.path.basename(original)))
                os.rename(trashed, target)
                restored.append(target)
                forget_trashinfo(trashed)
            except OSError as exc:
                ctx.error(trashed, exc)
            ctx.settle(index)
    except Cancelled:
        return done_event(ctx, cancelled=True, result=restored)
    return done_event(ctx, result=restored)


def forget_trashinfo(trashed):
    """Remove the .trashinfo of an entry we just restored (our own bookkeeping only)."""
    files_dir = os.path.dirname(trashed)
    if os.path.basename(files_dir) != "files":
        return
    info = os.path.join(os.path.dirname(files_dir), "info", os.path.basename(trashed) + ".trashinfo")
    try:
        os.unlink(info)
    except OSError:
        pass


# --------------------------------------------------------------------------
# rename / mkdir / conflicts / thumbnails

def run_rename(req, emit):
    try:
        path = require_abs(req.get("path"))
        name = require_name(req.get("name"))
    except Rejected as exc:
        return rejected(emit, exc)
    ctx = Ctx(emit, 1)
    target = os.path.join(os.path.dirname(path), name)
    old = os.path.basename(path)
    try:
        if not os.path.lexists(path):
            raise FileNotFoundError(errno.ENOENT, "No such file or directory")
        if name == old:
            return done_event(ctx, result=path)
        if os.path.lexists(target):
            raise FileExistsError(errno.EEXIST, "a file with that name already exists")
        os.rename(path, target)
    except OSError as exc:
        ctx.error(path, exc)
        return done_event(ctx)
    return done_event(ctx, undo={"op": "rename", "path": target, "name": old}, result=target)


def run_mkdir(req, emit):
    try:
        parent = require_abs(req.get("parent"), "parent")
        name = require_name(req.get("name"))
    except Rejected as exc:
        return rejected(emit, exc)
    ctx = Ctx(emit, 1)
    target = os.path.join(parent, name)
    try:
        os.mkdir(target)
    except OSError as exc:
        ctx.error(target, exc)
        return done_event(ctx)
    return done_event(ctx, result=target)


def run_conflicts(req, emit):
    try:
        sources = req.get("sources")
        if not isinstance(sources, list):
            raise Rejected("sources must be a list")
        dest = require_abs(req.get("dest"), "dest")
        names = plan_conflicts(sources, dest)
    except Rejected as exc:
        return rejected(emit, exc)
    return done_event(Ctx(emit), result=names)


def thumb_video(path, size):
    """FreeDesktop thumbnail via ffmpegthumbnailer; returns the png path or None."""
    try:
        path = require_abs(path)
        size = int(size)
        src_mtime = os.stat(path).st_mtime
    except (Rejected, OSError, TypeError, ValueError):
        return None
    uri = "file://" + urllib.parse.quote(path, safe="/!$&'()*+,;=:@~", errors="surrogateescape")
    digest = hashlib.md5(uri.encode("utf-8", "surrogateescape")).hexdigest()
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    folder = Path(base) / "thumbnails" / ("normal" if size <= 128 else "large")
    out = folder / (digest + ".png")
    try:
        if out.exists() and out.stat().st_mtime >= src_mtime:
            return str(out)
        folder.mkdir(mode=0o700, parents=True, exist_ok=True)
        tmp = folder / f".{digest}.{os.getpid()}.tmp.png"
        result = subprocess.run(["ffmpegthumbnailer", "-i", path, "-o", str(tmp), "-s", str(size)],
                                capture_output=True, timeout=30)
        if result.returncode == 0 and tmp.exists() and tmp.stat().st_size > 0:
            os.replace(tmp, out)
            return str(out)
        if tmp.exists():
            tmp.unlink()
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def run_thumb(req, emit):
    ctx = Ctx(emit, 1)
    return done_event(ctx, ok=True, result=thumb_video(req.get("path"), req.get("size", 128)))


OPS = {
    "conflicts": run_conflicts, "copy": run_copy, "move": run_move, "moveback": run_moveback,
    "trash": run_trash, "restore": run_restore, "rename": run_rename, "mkdir": run_mkdir,
    "thumb": run_thumb,
}


def emit_line(event):
    sys.stdout.write(json.dumps(event) + "\n")
    sys.stdout.flush()


def main(argv):
    def on_term(signum, frame):
        CANCEL.set()
    signal.signal(signal.SIGTERM, on_term)
    signal.signal(signal.SIGINT, on_term)
    op = argv[1] if len(argv) > 1 else ""
    handler = OPS.get(op)
    if handler is None:
        emit_line(rejected(lambda e: emit_line(e), f"unknown op: {op}"))
        return 2
    try:
        req = json.loads(sys.stdin.readline())
        if not isinstance(req, dict):
            raise ValueError("request must be an object")
    except ValueError as exc:
        emit_line(rejected(lambda e: emit_line(e), f"invalid request: {exc}"))
        return 2
    try:
        emit_line(handler(req, emit_line))
    except BrokenPipeError:
        return 1
    except Exception as exc:  # last resort: report instead of a traceback
        emit_line(rejected(lambda e: emit_line(e), f"{type(exc).__name__}: {exc}"))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
