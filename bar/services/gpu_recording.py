#!/usr/bin/env python3
"""Owned GPU Screen Recorder process; JSON commands on stdin, states on stdout.

EOF stops and finalizes this bridge's recording with SIGINT. Idle waits only on
stdin; elapsed/readiness checks exist only while a capture process is alive.
"""
import asyncio
import contextlib
import ctypes
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid


LIBC = ctypes.CDLL(None, use_errno=True)


def die_with_parent(expected_parent):
    """Use the existing cava ownership pattern, with SIGINT to finalize the muxer."""
    if LIBC.prctl(1, signal.SIGINT, 0, 0, 0) != 0 or os.getppid() != expected_parent:
        os._exit(1)


def recorder_binary():
    explicit = os.environ.get("ISLA_GPU_RECORDER")
    if explicit:
        candidate = Path(explicit)
        return str(candidate) if candidate.is_absolute() and candidate.is_file() and os.access(candidate, os.X_OK) else None
    return shutil.which("gpu-screen-recorder") or next((str(p) for p in
        [Path.home() / ".local/lib/isla/gpu-screen-recorder/usr/bin/gpu-screen-recorder"]
        if p.is_file() and os.access(p, os.X_OK)), None)


class Bridge:
    def __init__(self, emit=None):
        self.output = emit or (lambda state: print(json.dumps(state, ensure_ascii=False), flush=True))
        self.process = None
        self.watcher = None
        self.path = None
        self.ipc_directory = None
        self.started = None
        self.elapsed = 0.0
        self.diagnostics = b""
        self.state = dict(type="state", connected=False, phase="idle", elapsedSeconds=0,
                          outputPath="", error="", setupRequired=False, pauseSupported=True, busy=False)

    def emit(self, value):
        try:
            self.output(value)
        except (BrokenPipeError, OSError):
            # Losing the UI output pipe must not abandon the owned capture.
            self.output = lambda value: None

    def publish(self, **values):
        self.state.update(values)
        self.emit(dict(self.state))

    def refresh(self):
        available = recorder_binary() is not None
        self.publish(connected=available, setupRequired=not available,
                     phase=self.state["phase"] if self.process else "idle" if available else "error",
                     error="" if available else "Instala GPU Screen Recorder para grabar la pantalla.")

    def duration(self):
        return self.elapsed + (time.monotonic() - self.started if self.started is not None else 0)

    def nonempty_output(self):
        try:
            return self.path.is_file() and self.path.stat().st_size > 0
        except OSError:
            return False

    async def drain(self, stream):
        while chunk := await stream.read(4096):
            self.diagnostics = (self.diagnostics + chunk)[-2048:]

    async def watch(self, process):
        drains = [asyncio.create_task(self.drain(stream)) for stream in (process.stdout, process.stderr)]
        exited = asyncio.create_task(process.wait())
        try:
            while not exited.done():
                # The muxer opens the output after capture/encoder setup, including the portal picker.
                if self.state["phase"] == "starting" and self.nonempty_output():
                    self.started = time.monotonic()
                    self.publish(phase="recording", busy=False)
                elif self.state["phase"] == "recording":
                    self.publish(elapsedSeconds=self.duration())
                with contextlib.suppress(asyncio.TimeoutError):
                    await asyncio.wait_for(asyncio.shield(exited), .2 if self.state["phase"] == "starting" else 1)
            code = await exited
            await asyncio.gather(*drains)
            self.elapsed = self.duration()
            self.started = None
            self.process = None
            self.ipc_directory.cleanup()
            self.ipc_directory = None
            if code == 0 and self.nonempty_output():
                path = str(self.path)
                self.emit(dict(type="saved", outputPath=path))
                self.publish(phase="idle", busy=False, elapsedSeconds=self.elapsed, outputPath=path, error="")
            else:
                diagnostic = self.diagnostics.decode(errors="replace").strip()[-700:]
                error = "La grabación no se pudo guardar. Comprueba la selección de pantalla y el codificador GPU."
                if "kms" in diagnostic.lower() or "permission" in diagnostic.lower():
                    error = "No hay permiso para capturar el monitor. Elige la captura mediante portal."
                self.publish(phase="error", busy=False, elapsedSeconds=self.elapsed, outputPath="", error=error)
        finally:
            for task in drains + [exited]:
                if not task.done():
                    task.cancel()
            await asyncio.gather(*drains, exited, return_exceptions=True)

    def send_signal(self, sig):
        try:
            # Popen retains ownership until wait/reap; never signal by name or process group.
            self.process.send_signal(sig)
            return True
        except ProcessLookupError:
            return False

    async def command(self, data):
        if not isinstance(data, dict) or data.get("action") not in ("start", "stop", "pause", "resume", "refresh"):
            self.publish(error="Comando de grabación no válido.")
            return
        action = data["action"]
        if action == "refresh":
            if self.process:
                self.publish(elapsedSeconds=self.duration())
            else:
                self.refresh()
            return
        if action == "start":
            if self.process:
                return
            capture, audio = data.get("capture", "portal"), data.get("audio", "system")
            if capture != "portal" or audio not in ("none", "system", "microphone", "both") or "fps" in data:
                self.publish(error="Opciones de grabación no válidas.")
                return
            binary = recorder_binary()
            if not binary:
                self.refresh()
                return
            self.path = Path.home() / "Videos/Recordings" / (time.strftime("Isla-%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:8] + ".mkv")
            args = [binary, "-w", capture, "-f", "30", "-q", "high", "-k", "h264", "-encoder", "gpu",
                    "-fallback-cpu-encoding", "no", "-fm", "vfr", "-tune", "performance", "-o", str(self.path)]
            source = {"none": "", "system": "default_output", "microphone": "default_input", "both": "default_output|default_input"}[audio]
            if source:
                args += ["-a", source]
            self.elapsed, self.started, self.diagnostics = 0.0, None, b""
            self.publish(phase="starting", busy=True, elapsedSeconds=0, outputPath="", error="")
            try:
                self.path.parent.mkdir(parents=True, exist_ok=True)
                self.ipc_directory = tempfile.TemporaryDirectory(prefix="isla-gsr-")
                args += ["-ipc", str(Path(self.ipc_directory.name) / "control.sock")]
                parent = os.getpid()
                spawn = asyncio.create_task(asyncio.create_subprocess_exec(
                    *args, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
                    start_new_session=True, preexec_fn=lambda: die_with_parent(parent)))
                try:
                    self.process = await asyncio.shield(spawn)
                except asyncio.CancelledError:
                    self.process = await spawn
                    self.watcher = asyncio.create_task(self.watch(self.process))
                    raise
            except (OSError, subprocess.SubprocessError):
                if self.ipc_directory:
                    self.ipc_directory.cleanup()
                    self.ipc_directory = None
                self.publish(phase="error", busy=False, error="No se pudo iniciar GPU Screen Recorder. Comprueba la instalación y la carpeta Videos/Recordings.")
                return
            self.watcher = asyncio.create_task(self.watch(self.process))
        elif self.process and action == "stop" and self.state["phase"] != "stopping":
            self.elapsed = self.duration()
            self.started = None
            self.publish(phase="stopping", busy=True)
            self.send_signal(signal.SIGINT)
        elif self.process and ((action == "pause" and self.state["phase"] == "recording") or
                               (action == "resume" and self.state["phase"] == "paused")):
            self.publish(busy=True)
            writer = None
            try:
                async with asyncio.timeout(3):
                    reader, writer = await asyncio.open_unix_connection(str(Path(self.ipc_directory.name) / "control.sock"), limit=4096)
                    writer.write((json.dumps(dict(id=1, name="set-paused", data=action == "pause")) + "\n").encode())
                    await writer.drain()
                    reply = json.loads(await reader.readline())
                    if not isinstance(reply, dict) or reply.get("id") != 1 or reply.get("result") != "ok":
                        raise ValueError("Pause rejected")
                if self.process and self.state["phase"] in ("recording", "paused"):
                    if action == "pause":
                        self.elapsed = self.duration()
                        self.started = None
                    else:
                        self.started = time.monotonic()
                    self.publish(phase="paused" if action == "pause" else "recording", elapsedSeconds=self.duration(), error="")
            except (OSError, ValueError, asyncio.TimeoutError):
                self.publish(error="No se pudo confirmar la pausa. Comprueba el estado antes de reintentar.")
            finally:
                if writer:
                    writer.close()
                    with contextlib.suppress(OSError):
                        await writer.wait_closed()
                self.publish(busy=self.state["phase"] in ("starting", "stopping"))

    async def close(self):
        if self.process:
            await self.command(dict(action="stop"))
            # Keep the owner alive until the muxer has finalized; EOF never abandons a capture.
            await self.watcher


async def main():
    bridge = Bridge()
    current_task = asyncio.current_task()
    loop = asyncio.get_running_loop()
    loop.add_signal_handler(signal.SIGTERM, current_task.cancel)
    loop.add_signal_handler(signal.SIGINT, current_task.cancel)
    bridge.refresh()
    reader = asyncio.StreamReader(limit=4096)
    protocol = asyncio.StreamReaderProtocol(reader)
    transport, _ = await asyncio.get_running_loop().connect_read_pipe(lambda: protocol, sys.stdin)
    try:
        while True:
            try:
                line = await reader.readline()
            except ValueError:
                bridge.publish(error="Comando demasiado largo.")
                continue
            if not line:
                break
            try:
                data = json.loads(line)
            except (ValueError, UnicodeDecodeError):
                bridge.publish(error="Comando JSON no válido.")
                continue
            await bridge.command(data)
    finally:
        loop.add_signal_handler(signal.SIGTERM, lambda: None)
        loop.add_signal_handler(signal.SIGINT, lambda: None)
        await bridge.close()
        transport.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, BrokenPipeError, asyncio.CancelledError):
        pass
