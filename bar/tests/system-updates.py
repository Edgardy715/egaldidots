#!/usr/bin/env python3
"""Update bridge tests: private Git remotes and mocked package/systemd PATH only."""
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "scripts/system-updates.py"
spec = importlib.util.spec_from_file_location("updates", SOURCE)
updates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updates)
REAL_GIT = shutil.which("git")
FAKE = '''#!PYTHON
import json, os, signal, sys, time
from pathlib import Path
name = Path(sys.argv[0]).name
state = Path(os.environ['UPDATE_TEST_STATE'])
with (state / 'calls').open('a') as log:
    log.write(json.dumps([name, *sys.argv[1:]]) + '\\n')
config = json.loads((state / 'commands').read_text()).get(name, {})
def interrupted(*_):
    print('Interrupt signal received', flush=True)
    sys.exit(130)
signal.signal(signal.SIGINT, interrupted)
time.sleep(config.get('sleep', 0))
print(config.get('stdout', ''), end='', flush=True)
print(config.get('stderr', ''), end='', file=sys.stderr, flush=True)
time.sleep(config.get('hold', 0))
sys.exit(config.get('code', 0))
'''.replace("PYTHON", sys.executable)
# Transient unit double: runs the command with output appended to the unit log,
# records its pid for systemctl, then writes the ExecStopPost exit marker.
SYSTEMD_RUN = '''#!PYTHON
import json, os, shutil, subprocess, sys
from pathlib import Path
state = Path(os.environ['UPDATE_TEST_STATE'])
args = sys.argv[1:]
with (state / 'calls').open('a') as log:
    log.write(json.dumps(['systemd-run', *args]) + '\\n')
config = json.loads((state / 'commands').read_text()).get('systemd-run', {})
if config.get('code'):
    print(config.get('stderr', ''), end='', file=sys.stderr)
    sys.exit(config['code'])
split = args.index('--')
options, command = args[:split], args[split + 1:]
output = next(item.split('append:', 1)[1] for item in options if item.startswith('StandardOutput=append:'))
unit = options[options.index('--unit') + 1]
env = dict(os.environ)
for index, item in enumerate(options):
    if item == '-E':
        key, value = options[index + 1].split('=', 1)
        env[key] = value
command[0] = shutil.which(Path(command[0]).name, path=os.environ['PATH'])
pid = state / (unit + '.pid')
with open(output, 'a') as handle:
    child = subprocess.Popen(command, stdout=handle, stderr=handle, env=env)
    pid.write_text(str(child.pid))
    code = child.wait()
    pid.unlink()
    handle.write(f'isla-exit {code} {"success" if code == 0 else "exit-code"}\\n')
sys.exit(code)
'''.replace("PYTHON", sys.executable)
SYSTEMCTL = '''#!PYTHON
import json, os, signal, sys
from pathlib import Path
state = Path(os.environ['UPDATE_TEST_STATE'])
args = [item for item in sys.argv[1:] if item != '--user']
with (state / 'calls').open('a') as log:
    log.write(json.dumps(['systemctl', *sys.argv[1:]]) + '\\n')
pid = state / (args[-1] + '.pid')
if args[0] == 'is-active':
    sys.exit(0 if pid.exists() else 3)
if args[0] == 'kill' and pid.exists():
    os.kill(int(pid.read_text()), signal.SIGINT)
    sys.exit(0)
sys.exit(1)
'''.replace("PYTHON", sys.executable)
PACMAN_LOG = """:: Synchronizing package databases...
 core downloading...
:: Starting full system upgrade...
resolving dependencies...
looking for conflicting packages...

Packages (2) linux-cachyos-6.19-1  firefox-141-1

:: Proceed with installation? [Y/n]
:: Retrieving packages...
 linux-cachyos-6.19-1-x86_64 downloading...
 firefox-141-1-x86_64 downloading...
checking keyring...
checking package integrity...
checking available disk space...
:: Running pre-transaction hooks...
(1/1) Performing snapper pre snapshots for the following configurations...
==> root: 4211
:: Processing package changes...
(1/2) upgrading linux-cachyos
(2/2) upgrading firefox
:: Running post-transaction hooks...
"""


class UpdatesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="isla-updates-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.repo = self.base / "repo"
        self.origin = self.base / "origin"
        self.run_git("init", "--bare", str(self.origin))
        self.run_git("clone", str(self.origin), str(self.repo))
        self.run_git("config", "user.name", "Fixture", cwd=self.repo)
        self.run_git("config", "user.email", "fixture@example.invalid", cwd=self.repo)
        (self.repo / "file").write_text("initial")
        self.run_git("add", ".", cwd=self.repo)
        self.run_git("commit", "-m", "initial", cwd=self.repo)
        self.run_git("push", "-u", "origin", "HEAD", cwd=self.repo)
        self.branch = self.run_git("branch", "--show-current", cwd=self.repo).strip()
        self.script = self.repo / "bar/scripts/system-updates.py"
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(SOURCE, self.script)
        # Test infrastructure must not make the fixture repository dirty.
        (self.repo / ".git/info/exclude").write_text("bar/\n")
        (self.bin / "git").symlink_to(REAL_GIT)
        for name in ("checkupdates", "paru", "pacman", "flatpak", "kitty"):
            path = self.bin / name
            path.write_text(FAKE)
            path.chmod(0o755)
        for name, body in (("systemd-run", SYSTEMD_RUN), ("systemctl", SYSTEMCTL)):
            (self.bin / name).write_text(body)
            (self.bin / name).chmod(0o755)
        self.commands = {"checkupdates": {"code": 2}}
        self.save_commands()
        (self.base / "calls").touch()
        self.env = dict(os.environ, PATH=str(self.bin), XDG_RUNTIME_DIR=str(self.base / "runtime"),
                        UPDATE_TEST_STATE=str(self.base), GIT_CONFIG_NOSYSTEM="1",
                        GIT_CONFIG_GLOBAL=os.devnull, GIT_TERMINAL_PROMPT="0")
        self.patcher = patch.dict(os.environ, self.env, clear=True)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)
        self.repo_patch = patch.object(updates, "REPO", self.repo)
        self.repo_patch.start()
        self.addCleanup(self.repo_patch.stop)

    def run_git(self, *args, cwd=None):
        env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        return subprocess.check_output([REAL_GIT, *args], cwd=cwd, env=env, stderr=subprocess.PIPE, text=True)

    def save_commands(self):
        (self.base / "commands").write_text(json.dumps(self.commands))

    def cli(self, *args):
        return subprocess.run([sys.executable, str(self.script), *args], env=self.env,
                              capture_output=True, text=True, timeout=10)

    def events(self, result):
        return [json.loads(line) for line in result.stdout.splitlines() if line.strip()]

    def calls(self):
        return [json.loads(line) for line in (self.base / "calls").read_text().splitlines()]

    def upstream_commit(self):
        peer = self.base / "peer"
        self.run_git("clone", str(self.origin), str(peer))
        self.run_git("config", "user.name", "Fixture", cwd=peer)
        self.run_git("config", "user.email", "fixture@example.invalid", cwd=peer)
        (peer / "remote-file").write_text("remote")
        self.run_git("add", ".", cwd=peer)
        self.run_git("commit", "-m", "remote", cwd=peer)
        self.run_git("push", cwd=peer)

    def wait_for(self, predicate, timeout=3):
        deadline = time.monotonic() + timeout
        while not predicate() and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertTrue(predicate())

    def test_check_exit_codes_and_partial_errors(self):
        self.commands["paru"] = {"code": 1}
        self.save_commands()
        result = self.cli("check")
        self.assertEqual(result.returncode, 0, result.stderr)
        value = json.loads(result.stdout)
        self.assertEqual(value["system"]["count"], 0)
        self.assertEqual(value["aur"]["error"], "")  # paru -Qua: exit 1, no output, nothing pending
        self.assertFalse(value["shell"]["dirty"])
        self.assertEqual(value["shell"]["blocked"], "")
        self.assertEqual(value["shell"]["branch"], self.branch)
        self.assertTrue(value["flatpak"]["supported"])
        self.commands.update(checkupdates={"stdout": "one 1 -> 2\ntwo 2 -> 3\n"},
                             paru={"code": 1, "stderr": "error: error sending request for url"},
                             flatpak={"stdout": "org.example.App\n"})
        self.save_commands()
        value = json.loads(self.cli("check").stdout)
        self.assertEqual(value["system"]["count"], 2)
        self.assertTrue(value["system"]["available"])
        self.assertEqual(value["aur"]["error"], "network")
        self.assertIn("sending request", value["aur"]["detail"])
        self.assertEqual(value["flatpak"]["count"], 1)
        self.assertTrue(value["checkedAt"].endswith("+00:00"))
        self.commands["paru"] = {"code": 7, "stderr": "boom"}
        self.save_commands()
        self.assertEqual(json.loads(self.cli("check").stdout)["aur"]["error"], "failed")
        self.assertFalse(any(call[0] in ("sudo", "systemd-run", "kitty") for call in self.calls()))

    def test_optional_tools_and_no_aur(self):
        (self.bin / "paru").unlink()
        (self.bin / "flatpak").unlink()
        value = updates.check()
        self.assertFalse(value["aur"]["supported"])
        self.assertEqual(value["aur"]["error"], "")
        self.assertFalse(value["flatpak"]["supported"])
        self.assertEqual(value["flatpak"]["error"], "")
        self.assertEqual(updates.check(True)["aur"]["error"], "")
        (self.bin / "checkupdates").unlink()
        self.assertEqual(updates.check()["system"]["error"], "failed")

    def test_timeout(self):
        self.commands["checkupdates"] = {"sleep": 2}
        self.save_commands()
        with patch.object(updates, "TIMEOUT", .04):
            value = updates.package_check(["checkupdates"])
        self.assertEqual(value["error"], "timeout")

    def test_shell_update_ff_only_in_background_unit(self):
        self.upstream_commit()
        old_head = self.run_git("rev-parse", "HEAD", cwd=self.repo)
        value = updates.shell_check()
        self.assertEqual(value["count"], 1)
        self.assertEqual(value["error"], "")
        self.assertEqual(self.run_git("rev-parse", "HEAD", cwd=self.repo), old_head)
        result = self.cli("install", "shell")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.events(result)[-1]["result"], "success")
        self.assertTrue((self.repo / "remote-file").exists())
        unit = next(call for call in self.calls() if call[0] == "systemd-run")
        self.assertIn("--user", unit)
        self.assertEqual(unit[unit.index("--") + 1:], ["git", "-C", str(self.repo), "pull", "--ff-only", "--no-rebase"])

    def test_shell_refuses_tracked_and_untracked_changes(self):
        self.upstream_commit()
        for file in ("file", "new-file"):
            path = self.repo / file
            old = path.read_text() if path.exists() else None
            path.write_text("changed")
            status = updates.shell_check()
            self.assertTrue(status["dirty"])
            self.assertEqual(status["blocked"], "dirty")
            self.assertEqual(status["error"], "")
            result = self.cli("install", "shell")
            self.assertEqual(result.returncode, 1)
            self.assertEqual(self.events(result)[-1]["code"], "blocked")
            self.assertFalse((self.repo / "remote-file").exists())
            path.unlink() if old is None else path.write_text(old)

    def test_shell_missing_upstream_detached_ahead_diverged(self):
        self.run_git("branch", "--unset-upstream", cwd=self.repo)
        self.assertEqual(updates.shell_check()["blocked"], "no-upstream")
        self.assertEqual(self.cli("install", "shell").returncode, 1)
        self.run_git("branch", f"--set-upstream-to=origin/{self.branch}", cwd=self.repo)
        self.run_git("checkout", "--detach", cwd=self.repo)
        self.assertEqual(updates.shell_check()["blocked"], "detached")
        self.run_git("checkout", self.branch, cwd=self.repo)
        (self.repo / "file").write_text("local commit")
        self.run_git("commit", "-am", "local", cwd=self.repo)
        status = updates.shell_check()
        self.assertEqual((status["blocked"], status["error"], status["ahead"]), ("ahead", "", 1))
        self.assertEqual(self.cli("install", "shell").returncode, 1)
        self.upstream_commit()
        self.assertEqual(updates.shell_check()["count"], 1)
        self.assertEqual(self.cli("install", "shell").returncode, 1)
        self.assertFalse((self.repo / "remote-file").exists())

    def test_system_install_progress_snapshot_and_reboot(self):
        self.commands["pacman"] = {"stdout": PACMAN_LOG}
        self.save_commands()
        result = self.cli("install", "system", "--total", "2")
        self.assertEqual(result.returncode, 0, result.stderr)
        events = self.events(result)
        phases = [event["phase"] for event in events if event["event"] == "phase"]
        self.assertEqual(phases[0], "auth")
        final = events[-1]
        self.assertEqual((final["result"], final["snapshot"], final["reboot"], final["changed"]),
                         ("success", "4211", True, 2))
        unit = next(call for call in self.calls() if call[0] == "systemd-run")
        self.assertNotIn("--user", unit)
        for option in ("KillSignal=SIGINT", "SendSIGKILL=no", "LC_ALL=C"):
            self.assertIn(option, unit)
        self.assertEqual(unit[unit.index("--") + 1:], ["/usr/bin/pacman", "-Syu", "--noconfirm", "--noprogressbar"])
        self.assertFalse(any(call[0] in ("kitty", "sudo") for call in self.calls()))

    def test_progress_parser_counts_and_commit_point(self):
        progress = updates.Progress(2)
        lines = PACMAN_LOG.splitlines()
        for line in lines[:lines.index(" firefox-141-1-x86_64 downloading...") + 1]:
            progress.feed(line)
        self.assertEqual((progress.phase, progress.done, progress.total), ("download", 2, 2))
        self.assertTrue(progress.cancellable("system"))
        for line in lines[lines.index(" firefox-141-1-x86_64 downloading...") + 1:]:
            progress.feed(line)
        self.assertFalse(progress.cancellable("system"))
        self.assertEqual((progress.done, progress.changed), (2, ["linux-cachyos", "firefox"]))
        quiet = updates.Progress()
        for line in (":: Processing package changes...", "upgrading linux-cachyos-headers...", "upgrading foo..."):
            quiet.feed(line)
        self.assertEqual(quiet.done, 2)
        self.assertFalse(quiet.reboot())

    def test_failures_are_classified(self):
        cases = (("error: failed retrieving file 'x' from mirror\nerror: failed to commit transaction\n", "network"),
                 ("error: unable to lock database\n", "busy"),
                 ("error: Partition / too full: 10 blocks needed\nerror: not enough free disk space\n", "disk"),
                 (":: unresolvable package conflicts detected\n", "conflict"))
        for log, code in cases:
            self.commands["pacman"] = {"stdout": log, "code": 1}
            self.save_commands()
            final = self.events(self.cli("install", "system"))[-1]
            self.assertEqual((final["result"], final["code"]), ("error", code), log)
        self.commands["pacman"] = {"stdout": ":: Processing package changes...\n(1/2) upgrading glibc\n", "code": 1}
        self.save_commands()
        self.assertEqual(self.events(self.cli("install", "system"))[-1]["code"], "partial")

    def test_dismissed_authentication_is_a_cancellation(self):
        self.commands["systemd-run"] = {"code": 1, "stderr": "Failed to start transient service unit: Access denied\n"}
        self.save_commands()
        result = self.cli("install", "system")
        self.assertEqual(result.returncode, 1)
        final = self.events(result)[-1]
        self.assertEqual((final["result"], final["code"]), ("cancelled", "auth"))
        self.assertFalse(any(call[0] == "pacman" for call in self.calls()))

    def test_cancel_before_commit_and_refused_after(self):
        self.commands["pacman"] = {"stdout": ":: Retrieving packages...\n foo-1-x86_64 downloading...\n", "hold": 5}
        self.save_commands()
        process = subprocess.Popen([sys.executable, str(self.script), "install", "system"], env=self.env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            log = self.base / "runtime/isla/update-system.log"
            self.wait_for(lambda: log.exists() and "downloading" in log.read_text())
            self.assertEqual(self.cli("check").returncode, 1)  # the install holds the lock
            self.assertEqual(json.loads(self.cli("status").stdout)["active"], "system")
            self.assertEqual(self.cli("cancel", "system").returncode, 0)
            out, _ = process.communicate(timeout=5)
        finally:
            process.kill() if process.poll() is None else None
        final = [json.loads(line) for line in out.splitlines()][-1]
        self.assertEqual((final["result"], final["code"]), ("cancelled", "cancelled"))
        self.commands["pacman"] = {"stdout": ":: Running pre-transaction hooks...\n", "hold": 5}
        self.save_commands()
        process = subprocess.Popen([sys.executable, str(self.script), "install", "system"], env=self.env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.wait_for(lambda: "pre-transaction" in log.read_text())
            refused = self.cli("cancel", "system")
            self.assertEqual(refused.returncode, 1)
            self.assertEqual(json.loads(refused.stdout)["reason"], "committed")
            out, _ = process.communicate(timeout=8)
        finally:
            process.kill() if process.poll() is None else None
        self.assertEqual([json.loads(line) for line in out.splitlines()][-1]["result"], "success")

    def test_follow_reattaches_to_running_unit(self):
        self.assertEqual(self.events(self.cli("follow", "system"))[-1]["event"], "idle")
        self.commands["pacman"] = {"stdout": PACMAN_LOG, "hold": .6}
        self.save_commands()
        process = subprocess.Popen([sys.executable, str(self.script), "install", "system"], env=self.env,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            self.wait_for(lambda: (self.base / "isla-update-system.service.pid").exists())
            final = self.events(self.cli("follow", "system"))[-1]
            self.assertEqual((final["result"], final["snapshot"]), ("success", "4211"))
        finally:
            process.wait(timeout=5)

    def test_aur_and_flatpak_commands(self):
        self.assertEqual(self.cli("install", "aur").returncode, 0)
        self.assertEqual(self.cli("install", "flatpak").returncode, 0)
        units = [call for call in self.calls() if call[0] == "systemd-run"]
        aur, flatpak = (unit[unit.index("--") + 1:] for unit in units)
        self.assertEqual(aur[:2], ["paru", "-Sua"])
        self.assertIn("--noconfirm", aur)
        self.assertEqual(flatpak, ["flatpak", "update", "--noninteractive", "-y"])
        self.assertTrue(all("--user" in unit for unit in units))
        self.assertTrue(any(item.startswith("SUDO_ASKPASS=") for item in units[0]))

    def test_concurrent_check_and_install_refused(self):
        with updates.lock_file() as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.cli("check")
            self.assertEqual(result.returncode, 1)
            self.assertEqual(json.loads(result.stdout)["system"]["error"], "busy")
            refused = self.cli("install", "system")
            self.assertEqual(refused.returncode, 1)
            self.assertEqual(self.events(refused)[-1]["code"], "busy")
            self.assertEqual(self.calls(), [])
        self.assertEqual(self.cli("check").returncode, 0)


if __name__ == "__main__":
    unittest.main()
