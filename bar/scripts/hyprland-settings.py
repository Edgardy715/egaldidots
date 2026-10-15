#!/usr/bin/env python3
"""Bounded Hyprland settings bridge for Isla. Never reads or writes Hyprland config."""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


LEAVES = ("windowsIn", "windowsOut", "workspaces")
PARENTS = {"windowsIn": "windows", "windowsOut": "windows", "workspaces": "global"}
LAYOUTS = ("scrolling", "dwindle", "master")
STYLES = {
    "windowsIn": ("slide", "popin", "popin 94%", "popin 97%", "gnomed"),
    "windowsOut": ("slide", "popin", "popin 94%", "popin 97%", "gnomed"),
    "workspaces": ("slide", "slidevert", "fade", "slidefade", "slidefadevert"),
}
WINDOW_STYLE = re.compile(r"^popin (?:100|[1-9]?[0-9])%$")
CURVE = re.compile(r"^(?:spring:)?[A-Za-z_][A-Za-z_0-9-]*$")
FILE = Path(os.environ.get("ISLA_HYPRLAND_CONFIG") or
            Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "isla/hyprland.json")


def run(*args):
    result = subprocess.run((os.environ.get("ISLA_HYPRCTL") or "hyprctl", *args),
                            capture_output=True, text=True, timeout=5, check=False)
    if result.returncode or not result.stdout.strip() or (args[0] == "eval" and result.stdout.strip() != "ok"):
        raise RuntimeError((result.stderr or result.stdout or "hyprctl failed").strip()[:300])
    return result.stdout.strip()


def query():
    layout = json.loads(run("-j", "getoption", "general:layout"))["str"]
    animations_enabled = json.loads(run("-j", "getoption", "animations:enabled"))["bool"] is True
    tree = json.loads(run("-j", "animations"))[0]
    if not isinstance(tree, list):
        raise ValueError("Invalid animations response")
    raw = {item["name"]: item for item in tree if isinstance(item, dict) and "name" in item}
    for leaf in LEAVES:
        if leaf not in raw:
            raise ValueError("Missing animation leaf: " + leaf)
    version = json.loads(run("-j", "version"))["version"]
    return {"layout": layout, "version": version, "animationsEnabled": animations_enabled, "raw": raw, "values": values(layout, raw)}


def effective(raw, leaf):
    item = raw[leaf]
    if item.get("overridden"):
        return item
    parent = PARENTS.get(leaf)
    return effective(raw, parent) if parent else item


def values(layout, raw):
    result = {"layout": layout}
    for leaf in LEAVES:
        item = effective(raw, leaf)
        display = effective(raw, PARENTS[leaf]) if not item["enabled"] else item
        speed = display["speed"]
        if type(speed) not in (int, float) or not math.isfinite(speed) or speed < 0.1:
            speed = 1
        result[leaf] = {"enabled": item["enabled"], "speed": speed, "style": display["style"]}
    return result


def curve_for(raw, leaf):
    for name in (leaf, PARENTS[leaf], "global"):
        curve = raw[name].get("bezier", "")
        if isinstance(curve, str) and CURVE.fullmatch(curve):
            return curve
    raise ValueError("Missing animation curve for " + leaf)


def validate(data):
    if not isinstance(data, dict) or set(data) != {"layout", *LEAVES} or data["layout"] not in LAYOUTS:
        raise ValueError("Invalid layout or settings fields")
    for leaf in LEAVES:
        item = data[leaf]
        if not isinstance(item, dict) or set(item) != {"enabled", "speed", "style"}:
            raise ValueError("Invalid fields for " + leaf)
        if type(item["enabled"]) is not bool or type(item["speed"]) not in (int, float) or not math.isfinite(item["speed"]) or not 0.1 <= item["speed"] <= 100:
            raise ValueError("Invalid animation value for " + leaf)
        if item["style"] not in ("", *STYLES[leaf]) and not (leaf != "workspaces" and
                                                      isinstance(item["style"], str) and WINDOW_STYLE.fullmatch(item["style"])):
            raise ValueError("Unsupported style for " + leaf)
    return data


def lua_string(value):
    return json.dumps(value, ensure_ascii=True)


def animation_code(leaf, item, curve):
    if not item["enabled"]:
        return "hl.animation({ leaf = " + lua_string(leaf) + ", enabled = false })"
    curve_field = "spring" if curve.startswith("spring:") else "bezier"
    return ("hl.animation({ leaf = " + lua_string(leaf) + ", enabled = true, speed = " +
            format(item["speed"], ".6g") + ", " + curve_field + " = " + lua_string(curve.removeprefix("spring:")) +
            ", style = " + lua_string(item["style"]) + " })")


def apply(target, baseline, current):
    target = validate(target)
    original = baseline["raw"]
    curves = {}
    retained_curves = {leaf: current["raw"][leaf]["bezier"] for leaf in LEAVES
                       if current["raw"][leaf]["enabled"] and isinstance(current["raw"][leaf]["bezier"], str)
                       and CURVE.fullmatch(current["raw"][leaf]["bezier"])}
    for leaf in LEAVES:
        if target[leaf]["enabled"] != current["values"][leaf]["enabled"] or (target[leaf]["enabled"] and target[leaf] != current["values"][leaf]):
            if not original[leaf]["overridden"]:
                raise ValueError("Cannot preview inherited " + leaf + " without changing its inheritance")
            live = current["raw"][leaf]
            curve = live["bezier"] if live["enabled"] else original[leaf]["bezier"]
            if not isinstance(curve, str) or not CURVE.fullmatch(curve):
                raise ValueError("Unsupported curve for " + leaf)
            curves[leaf] = curve
    attempted = []
    commands = []
    if target["layout"] != current["layout"]:
        commands.append(("layout", "hl.config({ general = { layout = " + lua_string(target["layout"]) + " } })"))
    for leaf in LEAVES:
        if target[leaf]["enabled"] == current["values"][leaf]["enabled"] and (not target[leaf]["enabled"] or target[leaf] == current["values"][leaf]):
            continue
        commands.append((leaf, animation_code(leaf, target[leaf], curves[leaf])))
    try:
        for name, code in commands:
            attempted.append(name)
            run("eval", code)
        runtime = query()
        runtime["retainedCurves"] = retained_curves
        return runtime
    except (RuntimeError, ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        failures = []
        for name in reversed(attempted):
            try:
                if name == "layout":
                    run("eval", "hl.config({ general = { layout = " + lua_string(current["layout"]) + " } })")
                else:
                    run("eval", animation_code(name, current["values"][name], current["raw"][name]["bezier"]))
            except (RuntimeError, OSError, subprocess.SubprocessError) as rollback_error:
                failures.append(str(rollback_error))
        raise RuntimeError(str(error) + ("; rollback failed: " + "; ".join(failures) if failures else ""))


def read_file():
    try:
        raw = FILE.read_bytes()
    except FileNotFoundError:
        return None, None, None
    data = json.loads(raw)
    if not isinstance(data, dict) or data.get("version") != 1:
        raise ValueError("Unsupported Hyprland settings file")
    curves = data.get("curves")
    if not isinstance(curves, dict) or set(curves) != set(LEAVES) or any(
            not isinstance(curves[leaf], str) or not CURVE.fullmatch(curves[leaf]) for leaf in LEAVES):
        raise ValueError("Invalid saved animation curves")
    return validate(data.get("values")), hashlib.sha256(raw).hexdigest(), curves


def read_with_error():
    try:
        saved, digest, curves = read_file()
        return saved, digest, curves, ""
    except (ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        raw = FILE.read_bytes()
        return None, hashlib.sha256(raw).hexdigest(), None, "Invalid saved Hyprland settings: " + str(error)


def body_for(target, curves):
    if not isinstance(curves, dict) or set(curves) != set(LEAVES) or any(
            not isinstance(curves[leaf], str) or not CURVE.fullmatch(curves[leaf]) for leaf in LEAVES):
        raise ValueError("Invalid animation curves")
    return (json.dumps({"version": 1, "values": validate(target), "curves": curves}, indent=2, ensure_ascii=False) + "\n").encode()


def write_atomic(body):
    FILE.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix=".hyprland-", dir=FILE.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(body)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, FILE)
    finally:
        if os.path.exists(name):
            os.unlink(name)
    return hashlib.sha256(body).hexdigest()


def save(target, expected, curves):
    _, digest, _ = read_file()
    if digest != expected:
        raise ValueError("Settings changed on disk; refresh before saving")
    return write_atomic(body_for(target, curves))


def reset_saved(target, expected, curves):
    raw = FILE.read_bytes()
    if hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError("Settings changed on disk; refresh before recovery")
    try:
        read_file()
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        pass
    else:
        raise ValueError("Saved settings are valid; recovery is unnecessary")
    body = body_for(target, curves)
    descriptor, backup = tempfile.mkstemp(prefix=FILE.name + ".invalid-", dir=FILE.parent)
    with os.fdopen(descriptor, "wb") as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())
    if hashlib.sha256(FILE.read_bytes()).hexdigest() != expected:
        os.unlink(backup)
        raise ValueError("Settings changed on disk; refresh before recovery")
    return {"digest": write_atomic(body), "backup": backup}


def main():
    action = sys.argv[1]
    if action == "initialize":
        current = query()
        persisted, digest, curves, persistence_error = read_with_error()
        baseline = json.loads(json.dumps(current))
        for leaf in LEAVES:
            if not baseline["raw"][leaf]["enabled"]:
                baseline["raw"][leaf]["bezier"] = curves[leaf] if curves else curve_for(current["raw"], leaf)
        if persisted is not None:
            current = apply(persisted, baseline, current)
        return {"runtime": current, "baseline": baseline, "saved": persisted or current["values"],
                "digest": digest, "persistenceError": persistence_error}
    if action == "refresh":
        current = query()
        persisted, digest, curves, persistence_error = read_with_error()
        baseline = json.loads(json.dumps(current))
        for leaf in LEAVES:
            if not baseline["raw"][leaf]["enabled"]:
                baseline["raw"][leaf]["bezier"] = curves[leaf] if curves else curve_for(current["raw"], leaf)
        return {"runtime": current, "baseline": baseline, "saved": persisted or current["values"],
                "digest": digest, "persistenceError": persistence_error}
    if action == "apply":
        target = json.loads(sys.argv[2])
        baseline = json.loads(sys.argv[3])
        return {"runtime": apply(target, baseline, query())}
    if action == "save":
        return {"digest": save(json.loads(sys.argv[2]), json.loads(sys.argv[3]), json.loads(sys.argv[4]))}
    if action == "reset":
        return reset_saved(json.loads(sys.argv[2]), json.loads(sys.argv[3]), json.loads(sys.argv[4]))
    raise ValueError("Unknown action")


if __name__ == "__main__":
    try:
        print(json.dumps({"ok": True, **main()}))
    except (ValueError, KeyError, TypeError, OSError, RuntimeError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        result = {"ok": False, "error": str(error)}
        if len(sys.argv) > 1 and sys.argv[1] == "apply" and "rollback failed" in str(error):
            try:
                result["runtime"] = query()
            except (ValueError, KeyError, TypeError, OSError, RuntimeError, subprocess.SubprocessError, json.JSONDecodeError):
                pass
        print(json.dumps(result))
        sys.exit(1)
