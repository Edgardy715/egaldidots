#!/usr/bin/env python3
"""Isolated CLI contract checks; socket transport is mocked by design."""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import pathlib
import os
import socket
import sys
import threading
import tempfile
from unittest.mock import patch

sys.dont_write_bytecode = True
script = pathlib.Path(__file__).resolve().parents[1] / "scripts/isla-activity"
spec = importlib.util.spec_from_loader("isla_activity", importlib.machinery.SourceFileLoader("isla_activity", str(script)))
cli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cli)


class FakeSocket:
    events = []
    def __init__(self, *args): pass
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def settimeout(self, value): pass
    def connect(self, path): pass
    def sendall(self, data): self.events.append(data.decode())


FakeSocket.events = []
with patch.object(cli.socket, "socket", FakeSocket):
    cli._warned = False
    for arguments in (["start", "--id", "build", "--title", "cargo build", "--progress", "-1"],
                      ["update", "--id=build", "--progress", "0.42", "--subtitle", "312/740"],
                      ["end", "--id", "build", "--state", "done"]):
        with patch.object(sys, "argv", [str(script), *arguments]):
            assert cli.main() == 0
    assert [json.loads(row)["op"] for row in FakeSocket.events] == ["start", "update", "end"]
    assert json.loads(FakeSocket.events[1])["progress"] == 0.42
    FakeSocket.events.clear()
    with patch.object(sys, "argv", [str(script), "run", "--title", "test", "--id", "r", "--", sys.executable, "-c", "raise SystemExit(7)"]):
        assert cli.main() == 7
    events = [json.loads(row) for row in FakeSocket.events]
    assert [e["op"] for e in events] == ["start", "end"]
    assert all(value is not None for event in events for value in event.values())
    assert events[1]["state"] == "failed"
    assert events[1]["subtitle"].endswith(" s")
    FakeSocket.events.clear()
    with patch.object(sys, "argv", [str(script), "run", "--title", "ok", "--", sys.executable, "-c", "pass"]):
        assert cli.main() == 0
    assert json.loads(FakeSocket.events[-1])["state"] == "done"

    FakeSocket.events.clear()
    with patch.object(sys, "argv", [str(script), "pipe", "--id", "p"]), patch.object(sys, "stdin", io.StringIO("1%\n2%\n42%\n100%\n")):
        assert cli.main() == 0
    events = [json.loads(row) for row in FakeSocket.events]
    assert events[0]["op"] == "start" and events[-1]["op"] == "end"
    updates = [e for e in events if e["op"] == "update"]
    assert updates[-1]["progress"] == 1.0
    FakeSocket.events.clear()
    clock = iter(i / 1000 for i in range(1000))
    with patch.object(sys, "argv", [str(script), "pipe", "--id", "burst"]), \
            patch.object(sys, "stdin", io.StringIO("42%\n" * 1000)), patch.object(cli.time, "monotonic", side_effect=lambda: next(clock)):
        assert cli.main() == 0
    assert len([row for row in FakeSocket.events if json.loads(row)["op"] == "update"]) <= 31

    FakeSocket.events.clear()
    with patch.object(cli.socket, "socket", side_effect=PermissionError("EPERM")), contextlib.redirect_stderr(io.StringIO()) as err:
        cli._warned = False
        assert not cli.send({"op": "start"})
        assert not cli.send({"op": "end"})
        assert err.getvalue().count("no está disponible") == 1

fish = pathlib.Path(__file__).resolve().parents[1] / "scripts/fish/isla.fish"
import subprocess
subprocess.run(["fish", "-n", str(fish)], check=True)
with tempfile.TemporaryDirectory() as absent:
    wrapped = subprocess.run([str(script), "run", "--title", "stdio", "--", sys.executable, "-c",
                              "import sys; print(input()); print('child stderr',file=sys.stderr); sys.exit(7)"],
                             input="child stdin\n", capture_output=True, text=True,
                             env=dict(os.environ, XDG_RUNTIME_DIR=absent))
    assert wrapped.returncode == 7 and wrapped.stdout == "child stdin\n"
    assert "child stderr" in wrapped.stderr and wrapped.stderr.count("no está disponible") == 1
with tempfile.TemporaryDirectory() as temp:
    runtime = pathlib.Path(temp) / "runtime"
    (runtime / "isla").mkdir(parents=True)
    sock_path = runtime / "isla/activity.sock"
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        server.bind(str(sock_path))
    except PermissionError as exc:
        print(f"SKIP real AF_UNIX transport: bind denied ({exc})")
    else:
        server.listen()
        received = []
        def accept_events():
            for _ in range(2):
                conn, _ = server.accept()
                with conn: received.append(conn.recv(8192).decode())
        thread = threading.Thread(target=accept_events, daemon=True)
        thread.start()
        env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime))
        subprocess.run([str(script), "start", "--id", "actual", "--title", "test"], env=env, check=True)
        subprocess.run([str(script), "end", "--id", "actual", "--state", "done"], env=env, check=True)
        thread.join(2)
        assert len(received) == 2 and '"op":"start"' in received[0] and '"op":"end"' in received[1]
        print("PASS real AF_UNIX transport")
    server.close()

# Exercise the production fish hook with fake compositor/CLI executables.
with tempfile.TemporaryDirectory() as temp:
    base = pathlib.Path(temp)
    fakebin = base / "bin"; fakebin.mkdir()
    log = base / "events"
    (fakebin / "hyprctl").write_text('#!/bin/sh\nif [ "$ISLA_TEST_FOCUSED" = 1 ]; then p=$PPID; else p=999999; fi\nprintf \'{"pid":%s}\\n\' "$p"\n')
    (fakebin / "jq").write_text('#!/bin/sh\nsed -n \'s/.*"pid":\\([0-9]*\\).*/\\1/p\'\n')
    (fakebin / "isla-activity").write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$ISLA_TEST_LOG"\n')
    for exe in fakebin.iterdir(): exe.chmod(0o755)
    config = base / "config.json"; config.write_text('{"activities":{"longCommandSeconds":3}}')
    runtime_env = dict(os.environ, PATH=f"{fakebin}:/usr/bin:/bin", ISLA_CONFIG=str(config), ISLA_TEST_LOG=str(log))
    def fish_case(name, duration, command, active, code=0):
        log.unlink(missing_ok=True)
        body = f'source "{fish}"; __isla_activity_postexec "{command}" {code} {duration}; or true'
        env = dict(runtime_env, ISLA_TEST_FOCUSED="1" if active == "focused" else "0")
        subprocess.run(["fish", "--no-config", "-c", body], env=env, capture_output=True, text=True, check=True)
        return log.read_text().splitlines() if log.exists() else []
    assert not fish_case("short", 1000, "true", "away")
    assert not fish_case("focused", 5000, "slowok", "focused")
    away = fish_case("away", 5000, "slowok", "away")
    assert len(away) == 2 and "--state done" in away[-1], away
    failed = fish_case("failed", 5000, "slowfail", "away", 1)
    assert len(failed) == 2 and "--state failed" in failed[-1]
    assert "--subtitle 1 m 12 s" in fish_case("duration", 72000, "slowok", "away")[-1]
    config.write_text('{"activities":{"longCommandSeconds":3,"enabled":false}}')
    assert not fish_case("disabled", 5000, "slowok", "away")
    config.write_text('{"activities":{"longCommandSeconds":3.5}}')
    assert not fish_case("fractional-short", 3400, "slowok", "away")
    assert len(fish_case("fractional-long", 3600, "slowok", "away")) == 2

    # PATH without isla-activity must resolve the sibling CLI from the sourced fish file.
    config.write_text('{"activities":{"longCommandSeconds":3}}')
    fallback_bin = base / "fallback-bin"; fallback_bin.mkdir()
    for name in ("hyprctl", "jq"):
        (fallback_bin / name).symlink_to(fakebin / name)
    scripts = base / "scripts"; fish_dir = scripts / "fish"; fish_dir.mkdir(parents=True)
    fish_copy = fish_dir / "isla.fish"; fish_copy.write_text(fish.read_text())
    sibling_cli = scripts / "isla-activity"
    sibling_cli.write_text((fakebin / "isla-activity").read_text()); sibling_cli.chmod(0o755)
    env = dict(runtime_env, PATH=f"{fallback_bin}:/usr/bin:/bin", ISLA_TEST_FOCUSED="0")
    log.unlink(missing_ok=True)
    installed = base / "home/.config/fish/conf.d/isla.fish"
    installed.parent.mkdir(parents=True)
    installed.symlink_to(fish_copy)
    body = f'source "{installed}"; __isla_activity_postexec fallback 0 5000'
    subprocess.run(["fish", "--no-config", "-c", body], env=env, capture_output=True, text=True, check=True)
    assert log.exists() and len(log.read_text().splitlines()) == 2
print("PASS activity CLI run done/failed, inherited stdio/status without shell, 1000/s pipe coalescing, one-time warning and fish hook cases/fallback")
