#!/usr/bin/env python3
"""Line-delimited JSON bridge for the Isla audio page (PulseAudio on PipeWire)."""

import json
import math
import os
import re
import selectors
import signal
import subprocess
import sys
import time

import audio_pulse
import audio_meter
import audio_discovery
import audio_policy


PACTL = "pactl"
PAREC = "parec"
MAX_VOLUME = 1.5
SINK_FORMATS = frozenset({"pcm", "ac3-iec61937", "eac3-iec61937", "mpeg-iec61937",
                          "dts-iec61937", "mpeg2-aac-iec61937", "truehd-iec61937",
                          "dtshd-iec61937"})
RELEVANT_EVENT = re.compile(rb" on (?:sink|source|sink-input|source-output|card|server)(?:\s|$)")
KINDS = {
    "output": ("outputs", "sink"),
    "input": ("inputs", "source"),
    "playback": ("playback", "sink-input"),
    "recording": ("recording", "source-output"),
}


def emit(message):
    print(json.dumps(message, ensure_ascii=False, separators=(",", ":")), flush=True)


def command(args):
    result = subprocess.run([PACTL, *args], capture_output=True, text=True, check=False,
                            env={**os.environ, "LC_ALL": "C.UTF-8"}, timeout=8)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or
                           f"pactl terminó con código {result.returncode}")
    return result.stdout


def read_json(args):
    return json.loads(command(["-f", "json", *args]))


def volume_channels(item):
    values = item.get("volume") or {}
    channel_map = [part.strip() for part in str(item.get("channel_map") or "").split(",") if part.strip()]
    return [{"name": name, "volume": round(values[name]["value"] / 65536, 4)}
            for name in (channel_map or list(values)) if name in values]


def common(item):
    channels = volume_channels(item)
    props = item.get("properties") or {}
    description = item.get("description")
    if not description or description == "(null)":
        description = props.get("node.nick") or props.get("device.description") or item.get("name") or ""
    return {
        "id": str(item.get("index", "")),
        "name": str(item.get("name") or ""),
        "description": str(description),
        "mute": bool(item.get("mute", False)),
        "volume": round(max((channel["volume"] for channel in channels), default=0), 4),
        "channels": channels,
        "channelMap": [channel["name"] for channel in channels],
        "balance": float(item.get("balance") or 0),
        "baseVolume": round((item.get("base_volume") or {}).get("value", 65536) / 65536, 4),
        "hasVolume": bool(channels),
        "volumeWritable": bool(channels),
    }


def normalize(raw):
    can_rename = "pipewire" not in str(raw["info"].get("server_name") or "").lower()
    result = {"outputs": [], "inputs": [], "playback": [], "recording": [], "cards": [],
              "defaultOutput": raw["info"].get("default_sink_name") or "",
              "defaultInput": raw["info"].get("default_source_name") or ""}
    for item in raw["sinks"]:
        row = common(item)
        row["monitorSource"] = str(item["monitor_source"]) if item.get("monitor_source") is not None else row["name"] + ".monitor"
        row["ports"] = ports(item.get("ports"))
        row["activePort"] = str(item.get("active_port") or "")
        row["monitor"] = False
        row["canRename"] = can_rename
        row["card"] = str(item["card"]) if item.get("card") is not None else ""
        row["formats"] = list(dict.fromkeys(str(value).split(",", 1)[0].strip()
                                            for value in item.get("formats") or []))
        row["canSetFormats"] = "SET_FORMATS" in (item.get("flags") or [])
        result["outputs"].append(row)
    for item in raw["sources"]:
        row = common(item)
        row["ports"] = ports(item.get("ports"))
        row["activePort"] = str(item.get("active_port") or "")
        row["monitor"] = item.get("monitor_of_sink") not in (None, 4294967295, "n/a") or row["name"].endswith(".monitor")
        row["canRename"] = can_rename
        row["card"] = str(item["card"]) if item.get("card") is not None else ""
        result["inputs"].append(row)
    for key, devices, side in (("sink-inputs", "outputs", "sink"),
                               ("source-outputs", "inputs", "source")):
        target = "playback" if side == "sink" else "recording"
        for item in raw[key]:
            props = item.get("properties") or {}
            if props.get("application.name") == "Isla audio meter":
                continue
            row = common(item)
            identity = audio_discovery.stream_identity(item, raw.get("clients") or [])
            row.update(identity)
            row["name"] = identity["appName"]
            row["description"] = identity["mediaName"] or identity["appName"]
            row["device"] = str(item[side]) if item.get(side) is not None else ""
            row["corked"] = bool(item.get("corked", False))
            row["monitor"] = False
            row["meterSource"] = "playback:" + row["id"] if target == "playback" else next(
                (device["name"] for device in result["inputs"] if device["id"] == row["device"]), "")
            result[target].append(row)
    for item in raw["cards"]:
        props = item.get("properties") or {}
        profiles = item.get("profiles") or {}
        if isinstance(profiles, dict):
            profiles = [{"name": name, **value} for name, value in profiles.items()]
        row = {"id": str(item.get("index", "")), "name": str(item.get("name") or ""),
               "description": str(props.get("device.description") or item.get("name") or ""),
               "profiles": [{"name": str(profile.get("name") or ""),
                             "description": display_description(profile),
                             "available": profile.get("available") is not False,
                             "sinks": int(profile.get("sinks") or 0),
                             "sources": int(profile.get("sources") or 0),
                             "priority": int(profile.get("priority") or 0)}
                            for profile in profiles],
               "activeProfile": str(item.get("active_profile") or ""),
               "ports": ports(item.get("ports"))}
        row.update(audio_policy.card_capabilities(row))
        result["cards"].append(row)
    return result


def display_description(item):
    if item.get("description") not in (None, "", "(null)"):
        return str(item["description"])
    name = str(item.get("name") or "")
    names = {"off":"Apagado", "pro-audio":"Audio profesional",
             "output:analog-stereo":"Salida estéreo analógica", "input:analog-stereo":"Entrada estéreo analógica",
             "input:mono-fallback":"Micrófono mono", "output:hdmi-stereo":"HDMI / DisplayPort estéreo",
             "output:iec958-stereo":"Salida digital S/PDIF", "input:iec958-stereo":"Entrada digital S/PDIF",
             "analog-input-headset-mic":"Micrófono de auriculares", "analog-input-internal-mic":"Micrófono integrado",
             "analog-input-mic":"Micrófono", "analog-input-linein":"Entrada de línea",
             "analog-output-speaker":"Altavoces", "analog-output-headphones":"Auriculares"}
    return " + ".join(names.get(part, part) for part in name.split("+"))


def ports(items):
    if isinstance(items, dict):
        items = [{"name": name, **value} for name, value in items.items()]
    return [{"name": str(item.get("name") or ""),
             "description": display_description(item),
             "available": item.get("availability", item.get("available", "unknown")) not in ("not available", "unavailable", False),
             "latencyOffset": int(str(item.get("latency_offset") or 0).split()[0])} for item in (items or [])]


def snapshot():
    raw = read_json(["list"])
    raw["sink-inputs"] = raw.pop("sink_inputs", [])
    raw["source-outputs"] = raw.pop("source_outputs", [])
    raw["info"] = read_json(["info"])
    return normalize(raw)


def required_string(args, key):
    value = args.get(key)
    if not isinstance(value, str) or not value or len(value) > 256 or "\x00" in value:
        raise ValueError(f"{key} inválido")
    return value


def number(value, low, high, name):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not low <= value <= high:
        raise ValueError(f"{name} fuera de rango ({low}–{high})")
    return float(value)


def rename_request(args, state):
    if not isinstance(args, dict):
        raise ValueError("Argumentos inválidos")
    kind = required_string(args, "kind")
    if kind not in ("output", "input"):
        raise ValueError("Solo se pueden renombrar salidas y entradas")
    id_ = required_string(args, "id")
    row = next((item for item in state[KINDS[kind][0]] if item["id"] == id_), None)
    if row is None:
        raise ValueError("El dispositivo ya no existe")
    description = args.get("description")
    if (not isinstance(description, str) or not description.strip() or len(description) > 256 or
            any(ord(char) < 32 or ord(char) == 127 for char in description)):
        raise ValueError("Nombre de dispositivo inválido")
    return ("sink:" if kind == "output" else "source:") + row["name"], description.strip()


def action_command(action, args, state):
    if not isinstance(args, dict):
        raise ValueError("Argumentos inválidos")
    kind = required_string(args, "kind") if action not in ("setProfile", "setLatencyOffset", "setDeviceEnabled") else "card"
    if kind != "card" and kind not in KINDS:
        raise ValueError("Tipo de audio inválido")
    id_ = required_string(args, "id")
    collection = "cards" if kind == "card" else KINDS[kind][0]
    row = next((row for row in state[collection] if row["id"] == id_), None)
    if row is None:
        raise ValueError("El dispositivo o flujo ya no existe")
    target = KINDS[kind][1] if kind != "card" else "card"
    if action == "setVolume":
        volume = number(args.get("volume"), 0, MAX_VOLUME, "Volumen")
        if not row["hasVolume"]:
            raise ValueError("Este flujo no permite cambiar el volumen")
        old = row["volume"]
        values = [min(MAX_VOLUME, channel["volume"] * volume / old) if old else volume
                  for channel in row["channels"]]
        return ["set-" + target + "-volume", id_, *[f"{value * 100:.3f}%" for value in values]]
    if action == "setChannelVolumes":
        values = args.get("volumes")
        if not isinstance(values, list) or len(values) != len(row["channels"]) or not values:
            raise ValueError("Cantidad de canales inválida")
        return ["set-" + target + "-volume", id_,
                *[f"{number(value, 0, MAX_VOLUME, 'Volumen') * 100:.3f}%" for value in values]]
    if action == "setBalance":
        balance = number(args.get("balance"), -1, 1, "Balance")
        channels = row["channels"]
        if len(channels) != 2:
            raise ValueError("Balance disponible solo en estéreo")
        level = row["volume"]
        values = [level * (1 - max(0, balance)) if
                  ("left" in channel["name"] or channel["name"] in ("aux0", "0") or
                   (index == 0 and "right" not in channel["name"] and channel["name"] != "aux1")) else
                  level * (1 + min(0, balance)) for index, channel in enumerate(channels)]
        return ["set-" + target + "-volume", id_, *[f"{value * 100:.3f}%" for value in values]]
    if action == "setMute":
        mute = args.get("mute")
        if not isinstance(mute, bool):
            raise ValueError("Mute inválido")
        return ["set-" + target + "-mute", id_, "1" if mute else "0"]
    if action == "setDefault" and kind in ("output", "input"):
        return ["set-default-" + target, row["name"]]
    if action == "setPort" and kind in ("output", "input"):
        port = required_string(args, "port")
        if port not in [entry["name"] for entry in row["ports"]]:
            raise ValueError("Puerto desconocido")
        return ["set-" + target + "-port", id_, port]
    if action == "setDeviceEnabled" and kind == "card":
        profile = audio_policy.choose_profile(row, args.get("direction"), args.get("enabled"))
        return ["set-card-profile", id_, profile]
    if action == "setProfile" and kind == "card":
        profile = required_string(args, "profile")
        if profile not in [entry["name"] for entry in row["profiles"]]:
            raise ValueError("Perfil desconocido")
        return ["set-card-profile", id_, profile]
    if action == "setLatencyOffset" and kind == "card":
        port = required_string(args, "port")
        offset = args.get("offset")
        if isinstance(offset, bool) or not isinstance(offset, int) or not -2_000_000 <= offset <= 5_000_000:
            raise ValueError("Latencia fuera de rango")
        if port not in [entry["name"] for entry in row["ports"]]:
            raise ValueError("Puerto desconocido")
        return ["set-port-latency-offset", row["name"], port, str(offset)]
    if action == "moveStream" and kind in ("playback", "recording"):
        device = required_string(args, "device")
        candidates = state["outputs" if kind == "playback" else "inputs"]
        selected = next((item for item in candidates if item["id"] == device), None)
        if selected is None:
            raise ValueError("Destino desconocido")
        return ["move-" + target, id_, selected["name"]]
    if action == "killStream" and kind in ("playback", "recording"):
        return ["kill-" + target, id_]
    if action == "setFormats" and kind == "output":
        formats = args.get("formats")
        if not row["canSetFormats"]:
            raise ValueError("Esta salida no admite cambiar formatos")
        if not isinstance(formats, list) or not formats or len(formats) > len(SINK_FORMATS) or any(
                not isinstance(value, str) or value not in SINK_FORMATS for value in formats) or len(set(formats)) != len(formats):
            raise ValueError("Formatos de salida inválidos")
        return ["set-sink-formats", id_, ";".join(formats)]
    raise ValueError("Acción no disponible para este tipo")


class Bridge:
    def __init__(self):
        self.selector = selectors.DefaultSelector()
        os.set_blocking(sys.stdin.fileno(), False)
        self.selector.register(sys.stdin, selectors.EVENT_READ, ("input", None))
        self.input_buffer = b""
        self.subscription = None
        self.subscribe_buffer = b""
        self.meters = {}
        self.wanted_meters = set()
        self.levels = {}
        self.meter_envelopes = {}
        self.state = None
        self.dirty_at = 0
        self.dirty_started = 0
        self.pending = []
        self.pending_at = 0
        self.pending_started = 0
        self.last_levels = 0

    def update(self):
        try:
            new_state = snapshot()
        except (OSError, RuntimeError, subprocess.SubprocessError, ValueError, json.JSONDecodeError) as exc:
            emit({"type": "error", "message": str(exc)})
            return
        previous = {row["meterSource"]: row["device"] for row in
                    (self.state or {}).get("playback", [])}
        self.state = new_state
        emit({"type": "snapshot", **self.state})
        try:
            current = {row["meterSource"]: row["device"] for row in self.state["playback"]}
            for source in list(self.meters):
                if source in previous and previous[source] != current.get(source):
                    self.stop_meter(source)
            if self.wanted_meters:
                self.set_meters(list(self.wanted_meters))
        except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as exc:
            emit({"type": "error", "message": str(exc)})

    def subscribe(self):
        self.subscription = subprocess.Popen([PACTL, "subscribe"], stdout=subprocess.PIPE,
                                             stderr=subprocess.DEVNULL, bufsize=0)
        os.set_blocking(self.subscription.stdout.fileno(), False)
        self.selector.register(self.subscription.stdout, selectors.EVENT_READ, ("subscribe", None))

    def set_meters(self, sources):
        if not isinstance(sources, list) or len(sources) > 64 or any(not isinstance(s, str) for s in sources):
            raise ValueError("Fuentes de medidor inválidas")
        allowed = {r["name"] for r in self.state["inputs"]}
        allowed.update(r["monitorSource"] for r in self.state["outputs"])
        allowed.update(r["meterSource"] for r in self.state["playback"])
        self.wanted_meters = set(sources)
        wanted = set(sources) & allowed
        for source in list(self.meters):
            if source not in wanted:
                self.stop_meter(source)
        for source in wanted - self.meters.keys():
            args = [PAREC, *audio_meter.CAPTURE_OPTIONS]
            if source.startswith("playback:"):
                args.append("--monitor-stream=" + source.split(":", 1)[1])
                playback = next(row for row in self.state["playback"] if row["meterSource"] == source)
                output = next((row for row in self.state["outputs"] if row["id"] == playback["device"]), None)
                if not output:
                    continue
                args.append("--device=" + output["monitorSource"])
            else:
                args.append("--device=" + source)
            proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
            os.set_blocking(proc.stdout.fileno(), False)
            self.selector.register(proc.stdout, selectors.EVENT_READ, ("meter", source))
            self.meters[source] = proc
            self.levels[source] = 0
            self.meter_envelopes[source] = audio_meter.PeakMeter(time.monotonic())

    def mark_dirty(self):
        now = time.monotonic()
        if not self.dirty_started:
            self.dirty_started = now
        self.dirty_at = min(now + 0.12, self.dirty_started + 0.5)

    def flush_actions(self):
        actions, self.pending = self.pending, []
        self.pending_at = self.pending_started = 0
        if not actions:
            return
        emit({"type": "busy", "value": True})
        changed = False
        try:
            for action, args in actions:
                try:
                    if action == "renameDevice":
                        audio_pulse.rename_device(*rename_request(args, self.state))
                    else:
                        argv = action_command(action, args, self.state)
                        command(argv)
                        if argv[0] == "set-card-profile":
                            card = next(row for row in self.state["cards"] if row["id"] == args["id"])
                            card["activeProfile"] = argv[2]
                            card.update(audio_policy.card_capabilities(card))
                    changed = True
                except (OSError, RuntimeError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
                    emit({"type": "error", "message": str(exc)})
            if changed:
                self.mark_dirty()
        finally:
            emit({"type": "busy", "value": False})

    def stop_meter(self, source):
        proc = self.meters.pop(source)
        self.selector.unregister(proc.stdout)
        proc.terminate()
        proc.stdout.close()
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        error = proc.stderr.read().decode("utf-8", "replace").strip()
        proc.stderr.close()
        self.levels.pop(source, None)
        self.meter_envelopes.pop(source, None)
        return proc.returncode, error

    def handle(self, message):
        action = message.get("action")
        args = message.get("args") or {}
        if action == "refresh":
            self.flush_actions()
            self.dirty_at = self.dirty_started = 0
            self.update()
            return
        if action == "meters":
            self.set_meters(args.get("sources"))
            emit({"type": "levels", "levels": self.levels})
            return
        if self.state is None:
            raise ValueError("Audio aún no disponible")
        if action == "renameDevice":
            rename_request(args, self.state)
        else:
            action_command(action, args, self.state)
        key = ("volume", args["kind"], args["id"]) if action in (
            "setVolume", "setChannelVolumes", "setBalance") else None
        if key:
            self.pending = [(name, values) for name, values in self.pending
                            if ("volume", values.get("kind"), values.get("id")) != key or
                            name not in ("setVolume", "setChannelVolumes", "setBalance")]
        self.pending.append((action, args))
        now = time.monotonic()
        if not self.pending_started:
            self.pending_started = now
        self.pending_at = min(now + 0.035, self.pending_started + 0.15)

    def run(self):
        self.update()
        try:
            self.subscribe()
        except OSError as exc:
            emit({"type": "error", "message": str(exc)})
        try:
            while True:
                deadlines = [value for value in (self.dirty_at, self.pending_at) if value]
                if self.meters:
                    deadlines.append(self.last_levels + audio_meter.INTERVAL)
                timeout = max(0, min(deadlines) - time.monotonic()) if deadlines else 0.25
                for key, _ in self.selector.select(min(timeout, 0.25)):
                    kind, source = key.data
                    if kind == "input":
                        chunk = os.read(sys.stdin.fileno(), 65536)
                        if not chunk:
                            return
                        self.input_buffer += chunk
                        if len(self.input_buffer) > 262144:
                            self.input_buffer = b""
                            emit({"type": "error", "message": "Mensaje demasiado grande"})
                        while b"\n" in self.input_buffer:
                            line, self.input_buffer = self.input_buffer.split(b"\n", 1)
                            try:
                                message = json.loads(line)
                                if not isinstance(message, dict):
                                    raise ValueError("Mensaje inválido")
                                self.handle(message)
                            except (OSError, RuntimeError, subprocess.SubprocessError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
                                emit({"type": "error", "message": str(exc)})
                    elif kind == "subscribe":
                        data = os.read(key.fileobj.fileno(), 4096)
                        if data:
                            self.subscribe_buffer += data
                            while b"\n" in self.subscribe_buffer:
                                line, self.subscribe_buffer = self.subscribe_buffer.split(b"\n", 1)
                                if RELEVANT_EVENT.search(line):
                                    self.mark_dirty()
                            if len(self.subscribe_buffer) > 4096:
                                self.subscribe_buffer = b""
                        else:
                            self.selector.unregister(key.fileobj)
                            self.subscription.wait()
                            self.subscription = None
                            emit({"type": "error", "message": "Se desconectó el servidor de audio; reconectando…"})
                            return
                    else:
                        if source not in self.meters or self.meters[source].stdout is not key.fileobj:
                            continue
                        data = os.read(key.fileobj.fileno(), 32768)
                        if not data:
                            code, error = self.stop_meter(source)
                            if code:
                                emit({"type": "error", "message": error or
                                      "No se pudo leer el medidor de " + source})
                            continue
                        self.meter_envelopes[source].feed(data)
                now = time.monotonic()
                if self.pending_at and now >= self.pending_at:
                    self.flush_actions()
                if self.dirty_at and now >= self.dirty_at:
                    self.dirty_at = self.dirty_started = 0
                    self.update()
                if self.meters and now - self.last_levels >= audio_meter.INTERVAL:
                    self.last_levels = now
                    self.levels = {source: meter.value(now) for source, meter in self.meter_envelopes.items()}
                    emit({"type": "levels", "levels": self.levels})
        finally:
            for source in list(self.meters):
                self.stop_meter(source)
            if self.subscription:
                self.subscription.terminate()
                try:
                    self.subscription.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    self.subscription.kill()
                    self.subscription.wait()


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    Bridge().run()
