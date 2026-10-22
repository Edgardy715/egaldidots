#!/usr/bin/env python3
"""Owned fake executable only; never captures the real desktop."""
import asyncio
import importlib.util
import json
import os
from pathlib import Path
import signal
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("gpu_recording", Path(__file__).parents[1] / "services/gpu_recording.py")
gpu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpu)

FAKE = '''#!/usr/bin/env python3
import json, os, signal, sys, time, socket, select
from pathlib import Path
args = sys.argv[1:]
log = Path(os.environ["FIXTURE_LOG"])
def record(value):
    with log.open("a") as f: f.write(json.dumps(value) + "\\n")
record(args)
path = Path(args[args.index("-o")+1])
sock = socket.socket(socket.AF_UNIX)
sock.bind(args[args.index("-ipc")+1])
sock.listen()
mode = os.environ.get("FIXTURE_MODE", "normal")
def stop(sig, frame):
    record(sig)
    if mode != "empty": path.write_bytes(b"finalized mkv")
    sys.exit(0)
def pause(sig, frame): record(sig)
signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGUSR2, pause)
if mode == "fail":
    print("encoder initialization failed", file=sys.stderr)
    sys.exit(7)
if mode == "empty": sys.exit(0)
if mode == "cancel": sys.exit(1)
if mode == "delayed": time.sleep(.6)
path.write_bytes(b"mkv frame")
if mode == "crash":
    time.sleep(.4)
    sys.exit(9)
while True:
    if not select.select([sock], [], [], .02)[0]: continue
    conn, _ = sock.accept()
    request = json.loads(conn.makefile().readline())
    record(request)
    if mode == "reject-pause": result = "error"
    else: result = "ok"
    conn.sendall((json.dumps(dict(id=request["id"], result=result)) + "\\n").encode())
    conn.close()
'''


async def until(predicate):
    async with asyncio.timeout(4):
        while not predicate():
            await asyncio.sleep(.01)


class RecordingTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.binary = self.root / "fake-recorder"
        self.binary.write_text(FAKE)
        self.binary.chmod(0o700)
        self.log = self.root / "calls"
        self.env = patch.dict(os.environ, HOME=str(self.root), ISLA_GPU_RECORDER=str(self.binary), FIXTURE_LOG=str(self.log), FIXTURE_MODE="normal")
        self.env.start()
        self.output = []
        self.bridge = gpu.Bridge(self.output.append)
        self.bridge.refresh()

    async def asyncTearDown(self):
        await self.bridge.close()
        if self.log.exists():
            for call in self.calls():
                if isinstance(call, list) and "-ipc" in call:
                    shutil.rmtree(Path(call[call.index("-ipc")+1]).parent, ignore_errors=True)
        self.env.stop()
        self.temp.cleanup()

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    async def start(self, **options):
        await self.bridge.command(dict(action="start", **options))
        await until(lambda: self.bridge.state["phase"] != "starting")

    async def stop(self):
        await self.bridge.command(dict(action="stop"))
        await self.bridge.watcher

    async def test_lifecycle_deduplicates_actions_and_saves_once(self):
        self.assertTrue(self.bridge.state["connected"])
        self.assertIsNone(self.bridge.watcher)  # no idle timer/task
        await self.start(audio="both")
        self.assertEqual(self.bridge.state["phase"], "recording")
        args = self.calls()[0]
        self.assertEqual(args[args.index("-w") + 1], "portal")
        self.assertEqual(args[args.index("-a") + 1], "default_output|default_input")
        self.assertEqual(args[args.index("-f") + 1], "30")
        self.assertEqual(args[args.index("-q") + 1], "high")
        self.assertEqual(args[args.index("-k") + 1], "h264")
        self.assertEqual(args[args.index("-fm") + 1], "vfr")
        self.assertEqual(args[args.index("-tune") + 1], "performance")
        self.assertEqual(args[args.index("-encoder") + 1], "gpu")
        self.assertEqual(args[args.index("-fallback-cpu-encoding") + 1], "no")
        await self.bridge.command(dict(action="start"))
        await asyncio.sleep(.05)
        await self.bridge.command(dict(action="pause"))
        await self.bridge.command(dict(action="pause"))
        duration = self.bridge.duration()
        await asyncio.sleep(.08)
        self.assertEqual(self.bridge.duration(), duration)
        await self.bridge.command(dict(action="resume"))
        await self.bridge.command(dict(action="resume"))
        await self.stop()
        await self.bridge.command(dict(action="stop"))
        self.assertEqual(self.bridge.state["phase"], "idle")
        self.assertEqual(self.calls()[1:], [dict(id=1, name="set-paused", data=True), dict(id=1, name="set-paused", data=False), signal.SIGINT])
        saved = [event for event in self.output if event["type"] == "saved"]
        self.assertEqual(len(saved), 1)
        self.assertEqual(Path(saved[0]["outputPath"]).read_bytes(), b"finalized mkv")
        self.assertIsNone(self.bridge.process)

    async def test_picker_wait_and_cancel_do_not_claim_recording(self):
        os.environ["FIXTURE_MODE"] = "delayed"
        await self.bridge.command(dict(action="start"))
        await asyncio.sleep(.1)
        self.assertEqual(self.bridge.state["phase"], "starting")
        self.assertEqual(self.bridge.duration(), 0)
        await until(lambda: self.bridge.state["phase"] == "recording")
        await self.stop()
        self.output.clear()
        os.environ["FIXTURE_MODE"] = "cancel"
        await self.start()
        self.assertEqual(self.bridge.state["phase"], "error")
        self.assertFalse(any(e.get("phase") == "recording" for e in self.output))
        self.assertTrue(self.bridge.state["connected"])
        await self.bridge.command(dict(action="refresh"))
        self.assertEqual(self.bridge.state["phase"], "idle")

    async def test_failure_empty_and_unexecutable_never_save(self):
        for mode in ("fail", "empty"):
            os.environ["FIXTURE_MODE"] = mode
            await self.start()
            self.assertEqual(self.bridge.state["phase"], "error")
            self.assertEqual(self.bridge.state["outputPath"], "")
        self.binary.write_text("not an executable format")
        await self.bridge.command(dict(action="start"))
        self.assertEqual(self.bridge.state["phase"], "error")
        self.assertFalse(self.bridge.state["busy"])
        self.assertFalse(any(event["type"] == "saved" for event in self.output))
        self.assertFalse(any(event.get("phase") == "recording" for event in self.output))

    async def test_pause_rejection_preserves_state(self):
        os.environ["FIXTURE_MODE"] = "reject-pause"
        await self.start()
        await self.bridge.command(dict(action="pause"))
        self.assertEqual(self.bridge.state["phase"], "recording")
        self.assertTrue(self.bridge.state["error"])
        self.assertFalse(self.bridge.state["busy"])

    async def test_crash_keeps_partial_file_without_saved_notification(self):
        os.environ["FIXTURE_MODE"] = "crash"
        await self.start()
        self.assertEqual(self.bridge.state["phase"], "recording")
        path = self.bridge.path
        await self.bridge.watcher
        self.assertTrue(path.is_file())
        self.assertEqual(self.bridge.state["phase"], "error")
        self.assertFalse(any(event["type"] == "saved" for event in self.output))

    async def test_validation_binary_availability_and_argument_modes(self):
        for value in (None, [], {"action": "invalid"}, {"action": "start", "fps": True},
                      {"action": "start", "capture": "screen"}, {"action": "start", "audio": []}):
            await self.bridge.command(value)
            self.assertIsNone(self.bridge.process)
        for audio, expected in (("none", None), ("system", "default_output"), ("microphone", "default_input")):
            await self.start(audio=audio)
            args = self.calls()[-1]
            self.assertEqual(args[args.index("-w") + 1], "portal")
            self.assertEqual(args[args.index("-a") + 1] if "-a" in args else None, expected)
            await self.stop()
        os.environ["ISLA_GPU_RECORDER"] = "/missing/recorder"
        await self.bridge.command(dict(action="refresh"))
        self.assertFalse(self.bridge.state["connected"])
        self.assertTrue(self.bridge.state["setupRequired"])

    async def test_closed_output_pipe_still_finalizes(self):
        await self.start()
        path = self.bridge.path
        def broken_pipe(value):
            raise BrokenPipeError()
        self.bridge.output = broken_pipe
        await self.bridge.close()
        self.assertIsNone(self.bridge.process)
        self.assertEqual(path.read_bytes(), b"finalized mkv")
        self.assertEqual(self.bridge.state["phase"], "idle")

    @unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
    async def test_quickshell_teardown_finalizes_owned_process(self):
        qml = self.root / "teardown.qml"
        qml.write_text("""import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    settings.watchFiles: false
    Process {
        id: bridge
        property bool requested: false
        command: ["python3", %s]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                const message = JSON.parse(line)
                if (message.phase === "idle" && !bridge.requested) {
                    bridge.requested = true
                    bridge.write(JSON.stringify({action: "start", audio: "none"}) + "\\n")
                }
                if (message.phase === "recording") Qt.quit()
            }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: Qt.quit() }
}
""" % json.dumps(str(Path(gpu.__file__))))
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
        log = self.root / "quickshell.log"
        with log.open("wb") as stream:
            shell = await asyncio.create_subprocess_exec("qs", "-p", str(qml), env=env,
                stdout=stream, stderr=asyncio.subprocess.STDOUT)
        try:
            try:
                await asyncio.wait_for(shell.wait(), 8)
            except asyncio.TimeoutError:
                self.fail(log.read_text())
            self.assertEqual(shell.returncode, 0, log.read_text())
            self.assertTrue(self.log.exists(), log.read_text())
            await until(lambda: signal.SIGINT in self.calls())
            args = self.calls()[0]
            path = Path(args[args.index("-o")+1])
            await until(lambda: path.read_bytes() == b"finalized mkv")
        finally:
            if shell.returncode is None:
                shell.kill()
                await shell.wait()

    async def test_parent_kill_finalizes_owned_process(self):
        await self.check_process_shutdown(terminate="kill")

    async def test_sigterm_finalizes_owned_process(self):
        await self.check_process_shutdown(terminate=True)

    async def test_eof_finalizes_owned_process_without_signaling_unrelated(self):
        await self.check_process_shutdown(terminate=False)

    async def check_process_shutdown(self, terminate):
        unrelated = await asyncio.create_subprocess_exec(sys.executable, "-c", "import time; time.sleep(30)")
        backend = await asyncio.create_subprocess_exec(sys.executable, str(Path(gpu.__file__)),
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        try:
            initial = json.loads(await backend.stdout.readline())
            self.assertEqual(initial["phase"], "idle")
            backend.stdin.write(b'{"action":"start","audio":"none"}\n')
            await backend.stdin.drain()
            async with asyncio.timeout(4):
                while json.loads(await backend.stdout.readline()).get("phase") != "recording":
                    pass
            if terminate == "kill":
                backend.kill()
            elif terminate:
                backend.terminate()
            else:
                backend.stdin.close()
                await backend.stdin.wait_closed()
            stdout, stderr = await asyncio.wait_for(backend.communicate(), 4)
            self.assertEqual(backend.returncode, -signal.SIGKILL if terminate == "kill" else 0, stderr)
            events = [json.loads(line) for line in stdout.splitlines()]
            saved = [event for event in events if event["type"] == "saved"]
            if terminate == "kill":
                self.assertEqual(saved, [])
                args = self.calls()[0]
                path = Path(args[args.index("-o")+1])
            else:
                self.assertEqual(len(saved), 1)
                path = Path(saved[0]["outputPath"])
            self.assertEqual(path.read_bytes(), b"finalized mkv")
            self.assertIsNone(unrelated.returncode)
            self.assertEqual(self.calls()[1:], [signal.SIGINT])
        finally:
            if backend.returncode is None:
                backend.kill()
                await backend.wait()
            unrelated.terminate()
            await unrelated.wait()


if __name__ == "__main__":
    unittest.main()
