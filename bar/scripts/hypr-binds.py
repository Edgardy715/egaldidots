#!/usr/bin/env python3
"""Hyprland keybind editor backend for Isla settings and the shortcut explorer.

Source of truth for the catalog is ~/.config/hypr/modules/binds.lua, which
writes $XDG_RUNTIME_DIR/isla-binds-catalog.json on every (re)load. Overrides
and user-created binds live in ~/.config/hypr/binds.user.json:

  {"version": 1, "binds": {"<id>": {"key": "...", "enabled": false}},
   "custom": [{"id": "custom.<n>", "label": "...", "key": "...", "cmd": "...", "enabled": true}]}

  list                          catalog + custom + external (read-only) + conflicts
  set <id> "<keys>"             remap (refused if another bind already uses it)
  disable <id> | enable <id>    unbind / rebind without losing the chosen keys
  reset <id> | reset-all        back to defaults (reset-all keeps custom binds)
  add "<label>" "<keys>" "<cmd>"            new user bind (runs a command)
  edit <id> "<label>" "<keys>" "<cmd>"      change a user bind
  remove <id>                   delete a user bind
  undo                          restore the state before the last change
Every write: validate, flock, back up, atomic replace, live rebind, verify.
stdout is one JSON document.

Environment (tests): ISLA_BINDS_USER, ISLA_BINDS_CATALOG, ISLA_HYPRCTL, ISLA_NO_RELOAD.
"""
import fcntl
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
USER = Path(os.environ.get("ISLA_BINDS_USER") or HOME / ".config/hypr/binds.user.json")
CATALOG = Path(os.environ.get("ISLA_BINDS_CATALOG") or
               Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "isla-binds-catalog.json")
HYPRCTL = os.environ.get("ISLA_HYPRCTL", "hyprctl")
MASK = {"SHIFT": 1, "CAPS": 2, "CTRL": 4, "ALT": 8, "MOD2": 16, "MOD3": 32, "SUPER": 64, "MOD5": 128}
ORDER = ["SUPER", "CTRL", "ALT", "SHIFT"]
KEY_RE = re.compile(r"^(?:[A-Za-z0-9_]+|code:\d+|mouse:\d+|mouse_up|mouse_down|mouse_left|mouse_right)$")
MODIFIER_KEYS = {"super", "shift", "ctrl", "control", "alt", "meta", "hyper"}
FLAG_NAMES = ["locked", "repeat", "release", "longPress", "mouse", "non_consuming", "submap_universal"]
CUSTOM_GROUP = "Personalizados"
MAX_BACKUPS = 8


class BindError(Exception):
    pass


def parse_keys(text):
    parts = [p.strip() for p in str(text).split("+")]
    parts = [p for p in parts if p]
    if not parts:
        raise BindError("Tecla vacía")
    key = parts[-1]
    mods = set()
    for part in parts[:-1]:
        name = {"CONTROL": "CTRL", "WIN": "SUPER", "META": "SUPER", "MOD4": "SUPER"}.get(part.upper(), part.upper())
        if name not in ORDER:
            raise BindError("Modificador desconocido: %s" % part)
        mods.add(name)
    if key.lower() in MODIFIER_KEYS or not KEY_RE.match(key):
        raise BindError("Tecla no válida: %s" % key)
    # A bare code:NN could be any printable key on another layout: needs a modifier.
    bare_ok = re.match(r"^(F\d{1,2}|Print|XF86\w+)$", key) or key.startswith("mouse")
    if not mods and not bare_ok:
        raise BindError("Añade un modificador (Super, Ctrl, Alt o Shift)")
    return mods, key


def canonical(text):
    mods, key = parse_keys(text)
    if len(key) == 1:
        key = key.upper()
    return " + ".join([m for m in ORDER if m in mods] + [key])


def signature(text):
    mods, key = parse_keys(text)
    return (sum(MASK[m] for m in mods), key.lower())


def mods_from_mask(mask):
    return [m for m in ORDER if mask & MASK[m]]


def live_binds():
    try:
        out = subprocess.run([HYPRCTL, "-j", "binds"], capture_output=True, text=True, timeout=5)
        data = json.loads(out.stdout)
        return data if isinstance(data, list) else []
    except Exception:
        return []


def read_json(path, default):
    try:
        return json.loads(Path(path).read_text())
    except Exception:
        return default


def read_user():
    data = read_json(USER, {})
    if not isinstance(data, dict):
        data = {}
    binds = data.get("binds") if isinstance(data.get("binds"), dict) else {}
    custom = data.get("custom") if isinstance(data.get("custom"), list) else []
    custom = [c for c in custom if isinstance(c, dict) and str(c.get("id", "")).startswith("custom.")]
    return {"binds": binds, "custom": custom}


def load():
    catalog = read_json(CATALOG, {}).get("binds")
    if not catalog:
        raise BindError("Hyprland no ha publicado el catálogo de atajos. Recarga la configuración.")
    return catalog, read_user()


def merged(catalog, user):
    """Built-in catalog rows plus user binds; custom rows the compositor has not
    published yet are kept (pending) so the UI and conflict checks see them."""
    rows = [dict(e) for e in catalog if not str(e.get("id", "")).startswith("custom.")]
    live_custom = {e["id"]: e for e in catalog if str(e.get("id", "")).startswith("custom.")}
    for c in user["custom"]:
        published = live_custom.get(c["id"])
        rows.append({
            "id": c["id"], "label": c.get("label") or "Atajo", "group": CUSTOM_GROUP,
            "default": c.get("key", ""), "cmd": c.get("cmd", ""),
            "key": published["key"] if published else c.get("key", ""),
            "enabled": published["enabled"] if published else c.get("enabled", True) is not False,
            "custom": True, "pending": not published,
        })
    return rows


def external_rows(live):
    rows = []
    for b in live:
        if str(b.get("description", "")).startswith("isla:"):
            continue
        key = str(b.get("key", "")) or ("code:%s" % b.get("keycode") if b.get("keycode") else "")
        if not key:
            continue
        submap = b.get("submap", "")
        rows.append({
            "id": "external.%d" % len(rows), "label": b.get("description") or "Atajo de la configuración",
            "group": "Submapa %s" % submap if submap else "Configuración", "default": "",
            "key": " + ".join(mods_from_mask(int(b.get("modmask", 0))) + [key]), "enabled": True,
            "external": True, "submap": submap, "dispatcher": dispatcher_name(b),
            "flags": [f for f in FLAG_NAMES if str(b.get(f, "false")).lower() == "true"],
        })
    return rows


def dispatcher_name(b):
    text = str(b.get("dispatcher", ""))
    m = re.match(r"HL\.Dispatcher\((\w+)\)", text)
    if m:
        return m.group(1)
    return "lua" if text.startswith("function") else text


def build():
    catalog, user = load()
    live = live_binds()
    rows = merged(catalog, user)
    external = external_rows(live)
    live_by_id = {str(b.get("description", ""))[5:]: b for b in live
                  if str(b.get("description", "")).startswith("isla:")}
    by_sig = {}
    for r in rows:
        if r["enabled"]:
            try:
                by_sig.setdefault(signature(r["key"]), []).append(r["label"])
            except BindError:
                pass
    ext_sig = {}
    for b in live:
        if b.get("submap", "") == "" and not str(b.get("description", "")).startswith("isla:"):
            ext_sig.setdefault((int(b.get("modmask", 0)), str(b.get("key", "")).lower()), []).append(
                b.get("description") or "Atajo de la configuración")
    for r in rows:
        r["overridden"] = r["id"] in user["binds"]
        r.setdefault("custom", False)
        lb = live_by_id.get(r["id"])
        r["flags"] = [f for f in FLAG_NAMES if lb and str(lb.get(f, "false")).lower() == "true"]
        r["dispatcher"] = dispatcher_name(lb) if lb else ("exec_cmd" if r.get("cmd") else "")
        r["conflicts"] = []
        if r["enabled"]:
            try:
                sig = signature(r["key"])
                r["conflicts"] = [l for l in by_sig.get(sig, []) if l != r["label"]] + ext_sig.get(sig, [])
            except BindError:
                pass
    for r in external:
        r["conflicts"] = []
    return {"ok": True, "binds": rows, "external": external,
            "conflictCount": sum(1 for r in rows if r["conflicts"]),
            "canUndo": bool(backups())}


def backups():
    return sorted(USER.parent.glob(USER.name + ".bak-*"))


def write_user(data):
    USER.parent.mkdir(parents=True, exist_ok=True)
    stamp = "%s-%09d" % (time.strftime("%Y%m%d-%H%M%S"), time.time_ns() % 1000000000)
    before = USER.read_bytes() if USER.is_file() else b'{"version": 1, "binds": {}}'
    backup = Path("%s.bak-%s" % (USER, stamp))
    backup.write_bytes(before)
    for old in backups()[:-MAX_BACKUPS]:
        old.unlink(missing_ok=True)
    payload = {"version": 1, "binds": data["binds"]}
    if data["custom"]:
        payload["custom"] = data["custom"]
    atomic_write(json.dumps(payload, indent=2, ensure_ascii=False))
    return backup


def atomic_write(data):
    tmp = USER.with_name(".%s.new" % USER.name)
    with tmp.open("wb") as handle:
        handle.write(data.encode() if isinstance(data, str) else data)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, USER)


def apply_live(expected):
    """Apply without `hyprctl reload` (it would revert Isla's live Hyprland settings)
    and confirm the catalog now reflects what was asked."""
    if os.environ.get("ISLA_NO_RELOAD"):
        return
    before = CATALOG.stat().st_mtime_ns if CATALOG.exists() else 0
    subprocess.run([HYPRCTL, "eval", "isla_rebind()"], capture_output=True, timeout=10)
    for _ in range(40):
        if CATALOG.exists() and CATALOG.stat().st_mtime_ns != before:
            break
        time.sleep(0.1)
    else:
        raise BindError("Hyprland no confirmó el cambio; revisa la configuración.")
    got = {e["id"]: e for e in load()[0]}
    for pid, want in expected.items():
        e = got.get(pid)
        if want is None:
            if e:
                raise BindError("Hyprland no eliminó el atajo.")
            continue
        if e is None:
            if pid.startswith("custom."):
                raise BindError("Hyprland no registró el atajo nuevo.")
            continue
        if want.get("enabled") is False and e["enabled"]:
            raise BindError("Hyprland no desactivó el atajo.")
        if want.get("enabled") is not False and want.get("key") and (
                not e["enabled"] or canonical(e["key"]) != canonical(want["key"])):
            raise BindError("Hyprland rechazó la combinación %s." % want["key"])


def clashes(rows, own_id, keys):
    sig = signature(keys)
    out = [r["label"] for r in rows if r["id"] != own_id and r["enabled"] and _sig(r["key"]) == sig]
    out += [b.get("description") or "Atajo de la configuración" for b in live_binds()
            if b.get("submap", "") == "" and not str(b.get("description", "")).startswith("isla:")
            and (int(b.get("modmask", 0)), str(b.get("key", "")).lower()) == sig]
    return out


def _sig(text):
    try:
        return signature(text)
    except BindError:
        return None


def ensure_free(rows, own_id, keys):
    clash = clashes(rows, own_id, keys)
    if clash:
        raise BindError("%s ya usa %s" % (clash[0], canonical(keys)))


def clean_label(text):
    label = " ".join(str(text or "").split())
    if not label:
        raise BindError("Escribe un nombre para el atajo")
    if len(label) > 60:
        raise BindError("El nombre es demasiado largo")
    return label


def clean_cmd(text):
    cmd = str(text or "").strip()
    if not cmd:
        raise BindError("Escribe el comando que ejecutará el atajo")
    if any(ord(ch) < 32 or ord(ch) == 127 for ch in cmd):
        raise BindError("El comando debe ocupar una sola línea")
    return cmd


def mutate(action, args):
    catalog, user = load()
    rows = merged(catalog, user)
    ids = {r["id"]: r for r in rows}
    new = json.loads(json.dumps(user))
    expected = {}
    custom_idx = {c["id"]: i for i, c in enumerate(new["custom"])}

    def need_entry():
        if not args or args[0] not in ids:
            raise BindError("Atajo desconocido")
        return ids[args[0]]

    if action == "reset-all":
        new["binds"] = {}
        after = [dict(r, key=r["default"], enabled=True) if not r.get("custom") else r for r in merged(catalog, new)]
        for c in new["custom"]:
            if c.get("enabled", True) and clashes(after, c["id"], c["key"]):
                raise BindError("«%s» chocaría con un atajo restaurado; cámbialo o desactívalo antes" % c["label"])
        expected = {e["id"]: {"key": e["default"]} for e in catalog if not str(e["id"]).startswith("custom.")}
    elif action == "add":
        if len(args) < 3:
            raise BindError("uso: add <nombre> <teclas> <comando>")
        label, keys, cmd = clean_label(args[0]), canonical(args[1]), clean_cmd(args[2])
        ensure_free(rows, None, keys)
        n = 1
        while "custom.%d" % n in ids:
            n += 1
        cid = "custom.%d" % n
        new["custom"].append({"id": cid, "label": label, "key": keys, "cmd": cmd, "enabled": True})
        expected[cid] = {"key": keys}
    else:
        entry = need_entry()
        eid = entry["id"]
        if action in ("edit", "remove") and eid not in custom_idx:
            raise BindError("Solo se pueden editar o borrar los atajos creados por ti")
        if action == "remove":
            new["custom"].pop(custom_idx[eid])
            expected[eid] = None
        elif action == "edit":
            if len(args) < 4:
                raise BindError("uso: edit <id> <nombre> <teclas> <comando>")
            label, keys, cmd = clean_label(args[1]), canonical(args[2]), clean_cmd(args[3])
            ensure_free(rows, eid, keys)
            c = new["custom"][custom_idx[eid]]
            c.update(label=label, key=keys, cmd=cmd)
            expected[eid] = {"key": keys} if c.get("enabled", True) is not False else {"enabled": False}
        elif action == "set":
            if len(args) < 2:
                raise BindError("Falta la tecla")
            keys = canonical(args[1])
            ensure_free(rows, eid, keys)
            if eid in custom_idx:
                new["custom"][custom_idx[eid]].update(key=keys, enabled=True)
            elif keys == canonical(entry["default"]):
                new["binds"].pop(eid, None)
            else:
                new["binds"][eid] = {"key": keys}
            expected[eid] = {"key": keys}
        elif action == "disable":
            if eid in custom_idx:
                new["custom"][custom_idx[eid]]["enabled"] = False
            else:
                o = dict(new["binds"].get(eid, {}))
                o["enabled"] = False
                new["binds"][eid] = o
            expected[eid] = {"enabled": False}
        elif action == "enable":
            if eid in custom_idx:
                c = new["custom"][custom_idx[eid]]
                keys = c.get("key", "")
                c["enabled"] = True
            else:
                o = dict(new["binds"].get(eid, {}))
                o.pop("enabled", None)
                keys = o.get("key") or entry["default"]
                if o:
                    new["binds"][eid] = o
                else:
                    new["binds"].pop(eid, None)
            ensure_free(rows, eid, keys)
            expected[eid] = {"key": keys}
        elif action == "reset":
            if eid in custom_idx:
                raise BindError("Los atajos creados por ti no tienen valor por defecto")
            new["binds"].pop(eid, None)
            if not entry["enabled"] or eid in user["binds"]:
                ensure_free(rows, eid, entry["default"])
            expected[eid] = {"key": entry["default"]}
        else:
            raise BindError("Acción desconocida")
    if new != user:
        commit(write_user(new), expected)
    return build()


def commit(backup, expected):
    """Apply live; if Hyprland rejects it, put the previous bytes back and re-apply."""
    try:
        apply_live(expected)
    except BindError:
        restore(backup)
        raise


def restore(backup):
    # The backup holds the exact previous file; moving it back also drops it from the undo stack.
    os.replace(backup, USER)
    try:
        apply_live({})
    except BindError:
        pass


def undo():
    stack = backups()
    if not stack:
        raise BindError("No hay cambios que deshacer")
    previous = read_json(stack[-1], None)
    if not isinstance(previous, dict) or not isinstance(previous.get("binds", {}), dict):
        stack[-1].unlink(missing_ok=True)
        raise BindError("La copia anterior estaba dañada; se ha descartado")
    current = USER.read_bytes() if USER.is_file() else b'{"version": 1, "binds": {}}'
    atomic_write(stack[-1].read_bytes())
    try:
        apply_live({})
    except BindError:
        atomic_write(current)
        apply_live({})
        raise
    stack[-1].unlink(missing_ok=True)
    return build()


def main(argv):
    cmd, args = (argv[1] if len(argv) > 1 else "list"), argv[2:]
    lock = None
    try:
        if cmd == "list":
            out = build()
        elif cmd in ("set", "disable", "enable", "reset", "reset-all", "add", "edit", "remove", "undo"):
            lock_path = USER.with_name(".binds.lock")
            lock_path.parent.mkdir(parents=True, exist_ok=True)
            lock = lock_path.open("w")
            fcntl.flock(lock, fcntl.LOCK_EX)
            out = undo() if cmd == "undo" else mutate(cmd, args)
        else:
            raise BindError("uso: hypr-binds.py list|set|disable|enable|reset|reset-all|add|edit|remove|undo")
    except BindError as exc:
        out = {"ok": False, "error": str(exc)}
    except Exception as exc:
        out = {"ok": False, "error": "Error inesperado: %s" % exc}
    print(json.dumps(out, ensure_ascii=False))
    return 0 if out.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
