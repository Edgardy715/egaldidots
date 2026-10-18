#!/usr/bin/env python3
"""Emit Cava ASCII bands for one exact MPRIS player's PulseAudio stream."""

import argparse
import ctypes
import errno
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import tempfile
import time

from audio_discovery import stream_identity


BARS = 24
MAX_BAND = 65535
ZERO = " ".join(["0"] * BARS)
PR_SET_PDEATHSIG = 1
LIBC = ctypes.CDLL(None, use_errno=True)


def die_with_parent(expected_parent):
    """Linux: kill the child even if the helper itself is killed without cleanup."""
    if LIBC.prctl(PR_SET_PDEATHSIG, signal.SIGKILL, 0, 0, 0) != 0:
        os._exit(1)
    if os.getppid() != expected_parent:
        os._exit(1)


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

    def pump(self, timeout):
        if not self.cava or not self.parec:
            time.sleep(timeout)
            return
        with selectors.DefaultSelector() as selected:
            selected.register(self.cava.stdout, selectors.EVENT_READ)
            for key, _ in selected.select(timeout):
                data = os.read(key.fileobj.fileno(), 65536)
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
    last_zero = 0.0
    with tempfile.TemporaryDirectory(prefix="isla-cava-") as directory:
        capture = Capture(directory)
        try:
            while not stopping:
                started = time.monotonic()
                try:
                    selected = select_stream(snapshot(), args.identity, args.desktop, args.bus)
                except (OSError, subprocess.SubprocessError, ValueError, json.JSONDecodeError) as exc:
                    print(f"cava_stream: discovery: {exc}", file=sys.stderr)
                    selected = None
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
                    try:
                        capture.pump(min(0.1, max(0, 1 - (time.monotonic() - started))))
                    except (OSError, RuntimeError) as exc:
                        print(f"cava_stream: stream: {exc}", file=sys.stderr)
                        capture.stop()
                        active = None
                        break
        finally:
            capture.stop()


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        # QML can close stdout before delivering SIGTERM; main's finally stopped children.
        sys.stdout = open(os.devnull, "w")
