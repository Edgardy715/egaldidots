#!/usr/bin/env python3
"""Emit Cava ASCII bands for one exact MPRIS player's PulseAudio stream."""

import argparse
import errno
import json
import os
from pathlib import Path
import re
import select
import signal
import subprocess
import sys
import tempfile
import time

from audio_discovery import stream_identity
from process_lifetime import die_with_parent


BARS = 24
MAX_BAND = 65535
ZERO = " ".join(["0"] * BARS)
# Each pactl query emits client events itself; reacting to those loops forever.
DISCOVERY_EVENT = re.compile(rb" on (?:sink-input|sink|server)(?:\s|$)")
CLIENT_EVENT = re.compile(rb"'change' on client #(\d+)(?:\s|$)")


def _token(value):
    return str(value or "").strip().lower()


def player_tokens(identity, desktop, bus):
    tokens = {_token(identity)} if identity else set()
    if desktop:
        tokens.add(_token(Path(desktop).name.removesuffix(".desktop")))
    prefix = "org.mpris.mediaplayer2."
    if _token(bus).startswith(prefix):
        tokens.add(_token(bus)[len(prefix):].split(".")[0])
    return tokens - {""}


def select_stream(snapshot, identity, desktop, bus):
    """Return (stream index, actual sink monitor), or None if unsafe to select."""
    wanted = player_tokens(identity, desktop, bus)
    if not wanted:
        return None
    clients = snapshot.get("clients") or []
    sinks = {str(s.get("index")): s for s in snapshot.get("sinks") or []}
    matches = []
    for stream in snapshot.get("sink-inputs") or []:
        if stream.get("corked") is True or _token((stream.get("properties") or {}).get("pulse.corked")) == "true":
            continue
        props = stream.get("properties") or {}
        client_id = str(stream["client"]) if stream.get("client") is not None else str(props.get("client.id") or "")
        owner = next((c.get("properties") or {} for c in clients
                      if str(c.get("index")) == client_id), {})
        if not owner:
            owner = next((c.get("properties") or {} for c in clients
                          if str((c.get("properties") or {}).get("object.id")) == client_id), {})
        labels = {_token(stream_identity(stream, clients)["appName"])}
        for source in (props, owner):
            labels.add(_token(Path(str(source.get("application.process.binary") or "")).name))
            desktop_file = source.get("application.desktop_file")
            if desktop_file:
                labels.add(_token(Path(str(desktop_file)).name.removesuffix(".desktop")))
        if not wanted.intersection(labels):
            continue
        sink = sinks.get(str(stream.get("sink")))
        monitor = (sink or {}).get("monitor_source")
        if monitor and str(stream.get("index", "")).isdigit():
            matches.append((int(stream["index"]), str(monitor)))
    return matches[0] if len(matches) == 1 else None


def snapshot():
    result = {}
    for kind in ("sink-inputs", "clients", "sinks"):
        completed = subprocess.run(["pactl", "-f", "json", "list", kind],
                                   capture_output=True, check=True, timeout=2)
        result[kind] = json.loads(completed.stdout)
    return result


def stream_clients(state):
    owners = {str(item.get("client") if item.get("client") is not None
                  else (item.get("properties") or {}).get("client.id", ""))
              for item in state.get("sink-inputs") or []}
    return owners | {str(client.get("index")) for client in state.get("clients") or []
                     if str((client.get("properties") or {}).get("object.id")) in owners}


def discovery_event(line, clients):
    if DISCOVERY_EVENT.search(line):
        return True
    match = CLIENT_EVENT.search(line)
    return bool(match and match[1].decode("ascii") in clients)


def config(fifo):
    return f"""[general]
bars = 24
framerate = 60
autosens = 0
sensitivity = 100
lower_cutoff_freq = 60

[input]
method = fifo
source = {fifo}
sample_bits = 16
sample_rate = 44100
channels = 2

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 65535
bar_delimiter = 32
frame_delimiter = 10
channels = mono

[smoothing]
noise_reduction = 0

[color]
gradient = 0
"""


def stop_process(proc):
    if proc is None:
        return
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=0.5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=0.5)
    for pipe in (proc.stdout, proc.stdin):
        if pipe:
            pipe.close()


class Capture:
    def __init__(self, directory):
        self.fifo = Path(directory) / "audio.fifo"
        os.mkfifo(self.fifo, 0o600)
        self.cfg = Path(directory) / "cava.conf"
        self.cfg.write_text(config(self.fifo))
        self.cava = None
        self.parec = None
        self.writer = None
        self.frames = bytearray()

    def start(self, index, monitor):
        self.stop()
        parent = os.getpid()
        self.cava = subprocess.Popen(["stdbuf", "-o0", "cava", "-p", str(self.cfg)],
                                     stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                     stderr=sys.stderr,
                                     preexec_fn=lambda: die_with_parent(parent))
        # Cava blocks opening the FIFO until its writer appears.
        for _ in range(50):
            if self.cava.poll() is not None:
                raise RuntimeError("cava exited before opening FIFO")
            try:
                self.writer = os.open(self.fifo, os.O_WRONLY | os.O_NONBLOCK)
                break
            except OSError as exc:
                if exc.errno != errno.ENXIO:
                    raise
                time.sleep(0.02)
        if self.writer is None:
            raise RuntimeError("cava did not open FIFO")
        os.set_blocking(self.writer, True)
        self.parec = subprocess.Popen([
            "parec", "--monitor-stream", str(index), "--device", monitor,
            "--raw", "--format=s16le", "--rate=44100", "--channels=2",
            "--latency-msec=20"], stdout=self.writer, stderr=sys.stderr,
            preexec_fn=lambda: die_with_parent(parent))
        os.close(self.writer)
        self.writer = None
        os.set_blocking(self.cava.stdout.fileno(), False)

    def stop(self):
        stop_process(self.parec)
        self.parec = None
        if self.writer is not None:
            os.close(self.writer)
            self.writer = None
        stop_process(self.cava)
        self.cava = None
        self.frames.clear()

    def pump(self, timeout, events=None):
        readers = [events] if events else []
        if self.cava and self.parec:
            readers.append(self.cava.stdout)
        event_data = None
        for source in select.select(readers, [], [], timeout)[0]:
            if source is events:
                event_data = os.read(source.fileno(), 4096)
            else:
                data = os.read(source.fileno(), 65536)
                if not data:
                    raise RuntimeError("audio child exited")
                self.frames.extend(data)
                while b"\n" in self.frames:
                    line, _, rest = self.frames.partition(b"\n")
                    self.frames = bytearray(rest)
                    fields = line.split()
                    if len(fields) == BARS:
                        try:
                            bands = [int(value) for value in fields]
                        except ValueError:
                            continue
                        if all(0 <= value <= MAX_BAND for value in bands):
                            print(" ".join(map(str, bands)), flush=True)
                if len(self.frames) > 4096:
                    self.frames.clear()
        return event_data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identity", default="")
    parser.add_argument("--desktop", default="")
    parser.add_argument("--bus", default="")
    args = parser.parse_args()
    stopping = False

    def request_stop(_signum, _frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)
    active = None
    selected = None
    clients = set()
    last_zero = 0.0
    subscription = None
    event_buffer = b""
    retry_at = 0.0
    refresh_at = 0.0
    with tempfile.TemporaryDirectory(prefix="isla-cava-") as directory:
        capture = Capture(directory)
        try:
            while not stopping:
                started = time.monotonic()
                if subscription is None and started >= retry_at:
                    try:
                        parent = os.getpid()
                        subscription = subprocess.Popen(
                            ["pactl", "subscribe"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            env={**os.environ, "LC_ALL": "C"},
                            preexec_fn=lambda: die_with_parent(parent))
                        event_buffer = b""
                        refresh_at = started
                    except OSError as exc:
                        print(f"cava_stream: subscription: {exc}", file=sys.stderr)
                        retry_at = started + 1
                if started >= refresh_at:
                    try:
                        state = snapshot()
                        clients = stream_clients(state)
                        selected = select_stream(state, args.identity, args.desktop, args.bus)
                        # Reconcile rarely as well: servers can omit metadata events.
                        refresh_at = started + (30 if subscription else 1)
                    except (OSError, subprocess.SubprocessError, ValueError, json.JSONDecodeError) as exc:
                        print(f"cava_stream: discovery: {exc}", file=sys.stderr)
                        selected = None
                        refresh_at = time.monotonic() + 1
                if selected != active or (selected and
                                          (capture.cava.poll() is not None or capture.parec.poll() is not None)):
                    capture.stop()
                    active = None
                    if selected:
                        try:
                            capture.start(*selected)
                            active = selected
                        except (OSError, RuntimeError) as exc:
                            capture.stop()
                            print(f"cava_stream: capture: {exc}", file=sys.stderr)
                if active is None and started - last_zero >= 0.5:
                    print(ZERO, flush=True)
                    last_zero = started
                while not stopping and time.monotonic() - started < 1:
                    now = time.monotonic()
                    if now >= refresh_at:
                        break
                    try:
                        data = capture.pump(min(0.1, max(0, 1 - (now - started)),
                                                max(0, refresh_at - now)),
                                            subscription.stdout if subscription else None)
                        if data == b"":
                            stop_process(subscription)
                            subscription = None
                            capture.stop()
                            active = selected = None
                            retry_at = refresh_at = time.monotonic() + 1
                        elif data:
                            event_buffer += data
                            while b"\n" in event_buffer:
                                line, event_buffer = event_buffer.split(b"\n", 1)
                                if discovery_event(line, clients):
                                    refresh_at = min(refresh_at, time.monotonic() + 0.05)
                            if len(event_buffer) > 4096:
                                event_buffer = b""
                    except (OSError, RuntimeError) as exc:
                        print(f"cava_stream: stream: {exc}", file=sys.stderr)
                        capture.stop()
                        active = None
                        refresh_at = time.monotonic()
                        break
        finally:
            capture.stop()
            stop_process(subscription)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        # QML can close stdout before delivering SIGTERM; main's finally stopped children.
        sys.stdout = open(os.devnull, "w")
