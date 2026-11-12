#!/usr/bin/env python3
"""Hyprland plugin manager for Isla settings (phase 5).

Subcommands (stdout is always one JSON document, progress goes to stderr):
  status            local state only, no network
  check             status + latest upstream version (git ls-remote)
  update <id>       build in a temp dir, verify ABI, back up, atomic replace

Safety rules:
  * The installed .so is never touched unless the new build exists and embeds
    the running Hyprland commit (the plugin ABI check).
  * The previous .so is copied to <name>.so.bak-YYYYMMDD before the swap.
  * Nothing is loaded or unloaded: live reloads froze Hyprland before (see
    docs/WORKSPACE_TRANSITIONS.md), so a new build applies on next Hyprland start.

Environment (tests): ISLA_PLUGIN_DIR, ISLA_HYPRCTL, ISLA_PLUGIN_REGISTRY (JSON file).
"""
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

DATA = Path(os.environ.get("ISLA_PLUGIN_DIR") or
            Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "isla")
HYPRCTL = os.environ.get("ISLA_HYPRCTL", "hyprctl")
TAG_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")

REGISTRY = {
    "hyprglass": {
        "name": "hyprglass", "label": "Hyprglass",
        "repo": "https://github.com/hyprnux/hyprglass", "channel": "tag",
        "dest": "hyprglass/hyprglass.so", "built": "hyprglass.so",
        "build": [["make", "-j{jobs}", "HYPRGLASS_VERSION={version}"]],
    },
    "scrolloverview": {
        "name": "scrolloverview", "label": "Scroll overview",
        "repo": "https://github.com/yayuuu/hyprland-scroll-overview", "channel": "head",
        "dest": "scrolloverview/scrolloverview.so", "built": "build/libscrolloverview.so",
        "build": [["cmake", "-S", ".", "-B", "build", "-DCMAKE_BUILD_TYPE=Release"],
                  ["cmake", "--build", "build", "-j{jobs}"]],
    },
}


def registry():
    path = os.environ.get("ISLA_PLUGIN_REGISTRY")
    return json.loads(Path(path).read_text()) if path else REGISTRY


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def run(cmd, timeout=10, cwd=None):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd)


def hyprland():
    try:
        out = run([HYPRCTL, "-j", "version"], 5)
        data = json.loads(out.stdout)
        return {"version": data.get("version", ""), "commit": data.get("commit", ""), "running": True}
    except Exception:
        return {"version": "", "commit": "", "running": False}


def target_commit(hypr):
    """Commit plugins must embed: the installed headers (they differ from the
    running one after a Hyprland package update, before the session restarts)."""
    header = Path(os.environ.get("ISLA_HYPR_HEADERS", "/usr/include/hyprland/src/version.h"))
    try:
        match = re.search(r'GIT_COMMIT_HASH\s+"([0-9a-f]{40})"', header.read_text())
        if match:
            return match.group(1)
    except OSError:
        pass
    return hypr["commit"]


def loaded_plugins():
    try:
        return {p["name"]: p for p in json.loads(run([HYPRCTL, "-j", "plugin", "list"], 5).stdout)}
    except Exception:
        return {}


def embeds_commit(so, commit):
    """The plugin ABI check compares the Hyprland commit baked into the .so."""
    if not commit or not so.is_file():
        return False
    needle = commit.encode()
    tail = b""
    with so.open("rb") as handle:
        while chunk := handle.read(1 << 20):
            if needle in tail + chunk:
                return True
            tail = chunk[-len(needle):]
    return False


def meta_path(spec):
    return (DATA / spec["dest"]).with_suffix(".meta.json")


def read_meta(spec):
    try:
        return json.loads(meta_path(spec).read_text())
    except Exception:
        return {}


def plugin_state(pid, spec, hypr, loaded):
    so = DATA / spec["dest"]
    live = loaded.get(spec["name"])
    meta = read_meta(spec)
    installed = so.is_file()
    compatible = embeds_commit(so, target_commit(hypr)) if installed and hypr["running"] else None
    version = meta.get("version") or (live or {}).get("version") or ""
    if not installed:
        state = "missing"
    elif compatible is False:
        state = "incompatible"
    elif live:
        state = "loaded"
    else:
        state = "paused"
    pending = bool(live and meta.get("version") and live.get("version")
                   and not meta["version"].startswith(live["version"]) and not live["version"].startswith(meta["version"]))
    stale = installed and compatible is False
    return {
        "id": pid, "name": spec["label"], "version": version,
        "loadedVersion": (live or {}).get("version", ""), "state": state,
        "compatible": compatible, "stale": stale, "restartRequired": pending,
        "hyprlandBuiltFor": meta.get("hyprland", ""),
        "message": message_for(state, stale, pending),
    }


def message_for(state, stale, pending):
    if state == "incompatible":
        return "Hyprland se actualizó: este plugin ya no coincide. Actualízalo y reinicia Hyprland."
    if state == "missing":
        return "No instalado."
    if pending:
        return "Actualizado. Se aplicará al reiniciar Hyprland."
    if state == "paused":
        return "Instalado, sin cargar en esta sesión."
    return ""


def status():
    hypr, loaded = hyprland(), loaded_plugins()
    plugins = [plugin_state(pid, spec, hypr, loaded) for pid, spec in registry().items()]
    return {"ok": True, "hyprland": hypr, "plugins": plugins,
            "staleCount": sum(1 for p in plugins if p["stale"])}


def latest_for(spec):
    out = run(["git", "ls-remote", "--tags", "--refs", spec["repo"]] if spec["channel"] == "tag"
              else ["git", "ls-remote", spec["repo"], "HEAD"], 25)
    if out.returncode != 0:
        raise RuntimeError((out.stderr or "git ls-remote failed").strip().splitlines()[-1])
    if spec["channel"] == "head":
        sha = out.stdout.split()[0]
        return {"version": sha[:12], "ref": sha}
    tags = []
    for line in out.stdout.splitlines():
        sha, ref = line.split()
        tag = ref.rsplit("/", 1)[-1]
        match = TAG_RE.match(tag)
        if match:
            tags.append((tuple(int(x) for x in match.groups()), tag, sha))
    if not tags:
        raise RuntimeError("no release tags")
    _, tag, sha = max(tags)
    return {"version": tag.lstrip("v"), "ref": tag}


def check():
    result = status()
    specs = registry()
    for plugin in result["plugins"]:
        try:
            latest = latest_for(specs[plugin["id"]])
            plugin["latest"] = latest["version"]
            plugin["updateAvailable"] = bool(plugin["version"]) and not (
                plugin["version"] == latest["version"] or latest["version"].startswith(plugin["version"]))
            plugin["updateAvailable"] = plugin["updateAvailable"] or plugin["state"] in ("incompatible", "missing")
        except Exception as exc:
            plugin["latest"] = ""
            plugin["updateAvailable"] = plugin["state"] in ("incompatible", "missing")
            plugin["checkError"] = str(exc)
    return result


def fail(pid, message):
    return {"ok": False, "id": pid, "error": message}


def update(pid):
    specs = registry()
    spec = specs.get(pid)
    if not spec:
        return fail(pid, "Plugin desconocido")
    hypr = hyprland()
    if not hypr["running"]:
        return fail(pid, "Hyprland no responde; no se puede verificar la compatibilidad.")
    try:
        latest = latest_for(spec)
    except Exception as exc:
        return fail(pid, "Sin conexión con el repositorio: %s" % exc)

    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "isla"
    cache.mkdir(parents=True, exist_ok=True)
    lock = (cache / "hypr-plugins.lock").open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return fail(pid, "Ya hay una actualización de plugins en curso.")
    for old in cache.glob("plugin-build-*"):
        shutil.rmtree(old, ignore_errors=True)
    work = Path(tempfile.mkdtemp(prefix="plugin-build-", dir=cache))
    try:
        src = work / "src"
        clone = ["git", "clone", "--quiet", "--depth", "1"]
        if spec["channel"] == "tag":
            clone += ["--branch", latest["ref"]]
        log("clone %s" % spec["repo"])
        out = run(clone + [spec["repo"], str(src)], 180)
        if out.returncode != 0:
            return fail(pid, "No se pudo descargar: " + (out.stderr.strip().splitlines() or ["git"])[-1])
        if spec["channel"] == "head":
            latest["version"] = run(["git", "rev-parse", "--short=12", "HEAD"], 10, src).stdout.strip()
        jobs = str(os.cpu_count() or 2)
        for step in spec["build"]:
            cmd = [a.format(jobs=jobs, version=latest["version"]) for a in step]
            log("build: " + " ".join(cmd))
            out = run(cmd, 1500, src)
            if out.returncode != 0:
                tail = (out.stderr or out.stdout).strip().splitlines()[-3:]
                return fail(pid, "La compilación falló; se conserva el plugin actual. " + " | ".join(tail))
        built = src / spec["built"]
        if not built.is_file():
            return fail(pid, "La compilación no produjo el plugin; se conserva el actual.")
        if not embeds_commit(built, target_commit(hypr)):
            return fail(pid, "La versión %s no es compatible con Hyprland %s; se conserva el plugin actual."
                        % (latest["version"], hypr["version"]))

        dest = DATA / spec["dest"]
        dest.parent.mkdir(parents=True, exist_ok=True)
        backup = ""
        staged = dest.with_name(".%s.new" % dest.name)
        try:
            if dest.is_file():
                backup = "%s.bak-%s" % (dest, time.strftime("%Y%m%d-%H%M%S"))
                shutil.copy2(dest, backup)
            shutil.copy2(built, staged)
            with staged.open("rb") as handle:
                os.fsync(handle.fileno())
            os.replace(staged, dest)
        finally:
            staged.unlink(missing_ok=True)
        meta = {"version": latest["version"], "hyprland": hypr["commit"],
                "built": time.strftime("%Y-%m-%dT%H:%M:%S")}
        try:
            tmp_meta = meta_path(spec).with_name(".meta.new")
            tmp_meta.write_text(json.dumps(meta))
            os.replace(tmp_meta, meta_path(spec))
        except OSError as exc:
            return {"ok": True, "id": pid, "version": latest["version"], "backup": backup,
                    "restartRequired": True, "warning": "Plugin instalado, pero no se pudo guardar su versión: %s" % exc}
        return {"ok": True, "id": pid, "version": latest["version"], "backup": backup,
                "restartRequired": True}
    except subprocess.TimeoutExpired:
        return fail(pid, "La operación tardó demasiado; se conserva el plugin actual.")
    except Exception as exc:
        return fail(pid, "Error inesperado: %s. Se conserva el plugin actual." % exc)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    if cmd == "status":
        out = status()
    elif cmd == "check":
        out = check()
    elif cmd == "update" and len(argv) > 2:
        out = update(argv[2])
    else:
        out = {"ok": False, "error": "uso: hypr-plugins.py status|check|update <id>"}
    print(json.dumps(out, ensure_ascii=False))
    return 0 if out.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
