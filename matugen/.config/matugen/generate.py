#!/usr/bin/env python3
"""Generate and publish one Matugen palette and its native templates."""

import argparse
import fcntl
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


ROLES = (
    "surface", "background", "on_surface", "on_surface_variant", "primary",
    "on_primary", "primary_container", "on_primary_container", "secondary",
    "on_secondary", "secondary_container", "on_secondary_container", "tertiary",
    "on_tertiary", "tertiary_container", "on_tertiary_container", "error",
    "on_error", "error_container", "on_error_container", "outline",
    "outline_variant", "surface_container", "surface_container_low", "surface_container_high",
    "surface_container_highest", "surface_container_lowest",
)
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")


class WallpaperAppliedError(RuntimeError):
    """The live wallpaper changed, but its palette could not be published."""


class PaletteReloadError(RuntimeError):
    """The palette was published, but a running Isla could not load it."""


def color(value, label):
    if isinstance(value, dict):
        value = value.get("color") or value.get("hex")
    if not isinstance(value, str) or not HEX.fullmatch(value):
        raise ValueError(f"Matugen returned an invalid {label}: {value!r}")
    return value.lower()


def normalize_dump(raw, mode):
    colors = raw.get("colors")
    if not isinstance(colors, dict):
        raise ValueError("Matugen JSON has no colors object")
    # Matugen 4 uses colors.role.dark/light.color; older releases used
    # colors.dark/light.role. Preserve both explicit schemes in our API.
    if isinstance(colors.get("dark"), dict):
        schemes = {
            branch: {role: color(colors[branch][role], f"{branch}.{role}")
                     for role in ROLES}
            for branch in ("dark", "light")
        }
    else:
        schemes = {
            branch: {role: color(colors[role][branch], f"{branch}.{role}")
                     for role in ROLES}
            for branch in ("dark", "light")
        }
    # Preserve every native role for consumers such as Neovim, not just the UI minimum.
    if isinstance(colors.get("dark"), dict):
        for branch in ("dark", "light"):
            for role, entry in colors[branch].items():
                schemes[branch][role] = color(entry, f"{branch}.{role}")
    else:
        for role, entries in colors.items():
            for branch in ("dark", "light"):
                if isinstance(entries, dict) and branch in entries:
                    schemes[branch][role] = color(entries[branch], f"{branch}.{role}")
    selected = schemes[mode]
    base16 = raw.get("base16")
    if not isinstance(base16, dict):
        raise ValueError("Matugen JSON has no native base16 colors")
    # Base16 ANSI order: 0=base00, 1=base08, 2=base0B, 3=base0A,
    # 4=base0D, 5=base0E, 6=base0C, 7=base05, then bright variants.
    ansi = ("base00", "base08", "base0b", "base0a", "base0d", "base0e",
            "base0c", "base05", "base03", "base08", "base0b", "base0a",
            "base0d", "base0e", "base0c", "base07")
    terminal = {}
    for index, name in enumerate(ansi):
        entry = base16[name]
        if isinstance(entry, dict) and mode in entry:
            entry = entry[mode]
        terminal[f"color{index}"] = color(entry, f"base16.{name}.{mode}")
    # Kitty's native template uses base00/base05. Keep the canonical terminal
    # surface identical so Starship contrast is calculated on the actual canvas.
    terminal.update(background=terminal["color0"],
                    foreground=terminal["color7"], cursor=selected["primary"])
    return schemes, terminal


def safe_relative(value, label):
    path = Path(value)
    if not value or path.is_absolute() or any(part in (".", "..") for part in path.parts):
        raise ValueError(f"Unsafe {label} path: {value!r}")
    return path


def load_manifest(config_dir):
    path = config_dir / "templates" / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(manifest, list):
        raise ValueError("Template manifest must be a list")
    seen = {"palette.json"}
    entries = []
    for entry in manifest:
        if not isinstance(entry, dict):
            raise ValueError("Template manifest entries must be objects")
        source = safe_relative(entry["input"], "input")
        target = safe_relative(entry["output"], "output")
        if str(target) in seen:
            raise ValueError(f"Duplicate template output: {target}")
        seen.add(str(target))
        input_path = config_dir / "templates" / source
        if not input_path.is_file() or not input_path.resolve().is_relative_to((config_dir / "templates").resolve()):
            raise ValueError(f"Template does not exist inside template directory: {source}")
        entries.append((input_path, target))
    return entries


def toml_string(value):
    return json.dumps(str(value), ensure_ascii=False)


def write_config(path, entries, generation):
    lines = ["[config]", "# Intentionally no wallpaper command or reload hooks.", ""]
    for index, (source, target) in enumerate(entries):
        output = generation / target
        output.parent.mkdir(parents=True, exist_ok=True)
        lines += [f"[templates.isla_{index}]", f"input_path = {toml_string(source)}",
                  f"output_path = {toml_string(output)}", ""]
    path.write_text("\n".join(lines), encoding="utf-8")


def run_matugen(binary, config, wall, mode, json_output):
    command = [binary, "-c", str(config), "-m", mode, "--source-color-index", "0"]
    if json_output:
        command += ["--json", "hex"]
    command += ["image", str(wall)]
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode:
        detail = (result.stderr or result.stdout).strip()
        raise RuntimeError(f"Matugen failed ({result.returncode}): {detail}")
    return result.stdout


def replace_symlink(path, target):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        temporary.symlink_to(target)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def publish_links(cache, entries, create=True):
    outputs = cache / "outputs"
    for _, target in entries:
        destination = outputs / target
        expected = Path(os.path.relpath(cache / "current" / target, destination.parent))
        if destination.exists() and not destination.is_symlink():
            raise RuntimeError(f"Refusing to replace non-symlink output: {destination}")
        if destination.is_symlink() and os.readlink(destination) != str(expected):
            raise RuntimeError(f"Refusing to replace foreign output symlink: {destination}")
    metadata = {"palette.json": "current/palette.json",
                "current-wallpaper": "current/wallpaper",
                "wallpaper.txt": "current/wallpaper.txt"}
    for name, expected in metadata.items():
        link = cache / name
        if link.exists() and not link.is_symlink():
            raise RuntimeError(f"Refusing to replace non-symlink metadata: {link}")
        if link.is_symlink() and os.readlink(link) != expected:
            raise RuntimeError(f"Refusing to replace foreign metadata symlink: {link}")
    if create:
        for _, target in entries:
            destination = outputs / target
            expected = Path(os.path.relpath(cache / "current" / target, destination.parent))
            if not destination.is_symlink():
                replace_symlink(destination, expected)
        for name, expected in metadata.items():
            link = cache / name
            if not link.is_symlink():
                replace_symlink(link, expected)


def optional(command, label, allowed_codes=()):
    if shutil.which(command[0]) is None:
        return
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=3)
    except subprocess.TimeoutExpired:
        print(f"matugen: optional {label} reload timed out", file=sys.stderr)
        return
    if result.returncode and result.returncode not in allowed_codes:
        print(f"matugen: optional {label} reload failed: {(result.stderr or result.stdout).strip()}", file=sys.stderr)


def running(name):
    if shutil.which("pgrep") is None:
        return False
    try:
        return subprocess.run(["pgrep", "-x", name], capture_output=True, timeout=3).returncode == 0
    except subprocess.TimeoutExpired:
        return False


def reload_isla(config_home):
    binary = shutil.which("quickshell")
    if not binary:
        return True
    shell = config_home / "quickshell" / "bar"
    try:
        instances = subprocess.run([binary, "-p", str(shell), "list", "--json"],
                                   capture_output=True, text=True, timeout=3)
        if instances.returncode:
            raise RuntimeError((instances.stderr or instances.stdout).strip())
        if not json.loads(instances.stdout):
            return True
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"matugen: could not determine whether Isla is running: {error}", file=sys.stderr)
        return True
    try:
        result = subprocess.run([binary, "-p", str(shell), "ipc", "call", "island", "reloadColors"],
                                capture_output=True, text=True, timeout=3)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"matugen: Isla palette reload failed: {error}", file=sys.stderr)
        return False
    if result.returncode:
        print(f"matugen: Isla palette reload failed: {(result.stderr or result.stdout).strip()}",
              file=sys.stderr)
        return False
    return True


def reload_clients(config_home):
    starship = config_home / "starship" / "matugen.py"
    if starship.is_file():
        optional([sys.executable, str(starship)], "Starship")
    optional(["fish", "--no-config", "-c",
              "set -U matugen_sync_signal (date +%s%N)"], "Fish")
    # FileView may watch the old symlink target after current is atomically
    # replaced. Address the exact shell configuration, not another instance.
    isla_reloaded = reload_isla(config_home)
    optional(["hyprctl", "reload"], "Hyprland")
    for name, label in (("kitty", "Kitty"), ("nvim", "Neovim")):
        if running(name):
            # Exit 1 means the process disappeared between pgrep and pkill.
            optional(["pkill", "-USR1", "-x", name], label, allowed_codes=(1,))
    return isla_reloaded


def transition_fps():
    try:
        result = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True,
                                text=True, timeout=1, check=True)
        monitors = json.loads(result.stdout)
        if not isinstance(monitors, list):
            return 144
        rates = [float(item["refreshRate"]) for item in monitors
                 if isinstance(item, dict) and not item.get("disabled") and math.isfinite(float(item.get("refreshRate", 0)))
                 and float(item.get("refreshRate", 0)) > 0]
        if rates:
            return min(240, max(30, math.ceil(max(rates))))
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError):
        pass
    return 144


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wallpaper", nargs="?", type=Path)
    parser.add_argument("--seed", action="store_true", help="Publish colors without changing the live wallpaper or reloading clients")
    parser.add_argument("--refresh", action="store_true", help="Regenerate the current wallpaper without a transition")
    parser.add_argument("--reduce-motion", action="store_true", help="Change wallpaper without spatial animation")
    parser.add_argument("--isla-feedback", action="store_true", help="Coordinate wallpaper apply with Isla feedback")
    parser.add_argument("--mode", choices=("dark", "light"), default="dark")
    args = parser.parse_args()
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    cache = cache_home / "matugen"
    cache.mkdir(parents=True, exist_ok=True)
    with (cache / "apply.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        wallpaper = args.wallpaper
        if wallpaper is None and args.refresh:
            marker = cache / "current-wallpaper"
            if not marker.is_symlink():
                raise ValueError("No current Matugen wallpaper to refresh")
            wallpaper = marker.resolve(strict=True)
        if wallpaper is None:
            parser.error("wallpaper is required unless --refresh uses the current wallpaper")
        wall = wallpaper.expanduser().resolve(strict=True)
        if not wall.is_file():
            raise ValueError(f"Wallpaper is not a file: {wall}")
        config_dir = Path(__file__).resolve().parent
        entries = load_manifest(config_dir)
        binary = shutil.which("matugen")
        if not binary:
            raise RuntimeError("matugen executable is unavailable")
        generations = cache / "generations"
        generations.mkdir(exist_ok=True)
        generation = Path(tempfile.mkdtemp(prefix="gen-", dir=generations))
        old_current = os.readlink(cache / "current") if (cache / "current").is_symlink() else None
        committed = False
        wallpaper_changed = False
        transition_end = 0
        try:
            config = generation / "runtime.toml"
            write_config(config, entries, generation)
            # JSON output and native template rendering happen in this invocation.
            raw = json.loads(run_matugen(binary, config, wall, args.mode, True))
            schemes, terminal = normalize_dump(raw, args.mode)
            palette = dict(version=1, generator="matugen", mode=args.mode,
                           wallpaper=str(wall), colors=schemes[args.mode],
                           schemes=schemes, terminal=terminal)
            (generation / "palette.json").write_text(
                json.dumps(palette, indent=2) + "\n", encoding="utf-8")
            (generation / "wallpaper").symlink_to(wall)
            (generation / "wallpaper.txt").write_text(f"{wall}\n", encoding="utf-8")
            for _, target in entries:
                if not (generation / target).is_file():
                    raise RuntimeError(f"Matugen did not render {target}")
            # Validate every public destination before changing the live wallpaper.
            publish_links(cache, entries, create=False)
            if not args.seed and not args.refresh:
                optional_awww = shutil.which("awww")
                if not optional_awww:
                    raise RuntimeError("awww executable is unavailable")
                command = [optional_awww, "img", str(wall), "--transition-type", "none" if args.reduce_motion else "grow",
                           "--transition-pos", "top", "--transition-duration", "1.45",
                           "--transition-bezier", "0.65,0,0.35,1", "--transition-step", "35",
                           "--transition-fps", str(144 if args.reduce_motion else transition_fps())]
                if args.isla_feedback:
                    print("ISLA_WALLPAPER_HANDOFF", flush=True)
                if args.isla_feedback and not args.reduce_motion:
                    transition_end = time.monotonic() + 1.45
                subprocess.run(command, check=True)
                wallpaper_changed = True
            publish_links(cache, entries)
            replace_symlink(cache / "current", Path("generations") / generation.name)
            committed = True
        except Exception as error:
            if not committed and (cache / "current").is_symlink() and os.readlink(cache / "current") != old_current:
                if old_current is None:
                    (cache / "current").unlink()
                else:
                    replace_symlink(cache / "current", old_current)
            shutil.rmtree(generation, ignore_errors=True)
            if wallpaper_changed:
                raise WallpaperAppliedError(str(error)) from error
            raise
        print(f"matugen: published {args.mode} palette for {wall}")
        if not args.seed and not reload_clients(config_home):
            raise PaletteReloadError("running Isla kept its previous palette")
        if transition_end:
            time.sleep(max(0, transition_end - time.monotonic()))


if __name__ == "__main__":
    try:
        main()
    except WallpaperAppliedError as error:
        print(f"matugen: wallpaper changed but palette generation failed: {error}", file=sys.stderr)
        sys.exit(3)
    except PaletteReloadError as error:
        print(f"matugen: palette published but live reload failed: {error}", file=sys.stderr)
        sys.exit(3)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(f"matugen: {error}", file=sys.stderr)
        sys.exit(1)
