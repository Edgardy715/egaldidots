#!/usr/bin/env python3
"""Isla update bridge (stdlib only).

check [--no-aur]: JSON per source with count/packages. `error` is a stable code
  (network, timeout, busy, failed; empty on success) and `detail` the technical
  text for logs. Shell refusals are `blocked` (dirty, ahead, detached,
  no-upstream), not errors. Missing optional tools mean supported=false.
install SOURCE [--total N]: runs the upgrade in a transient systemd unit (system
  manager for pacman, user manager otherwise) so it never needs a terminal and
  survives a shell restart; streams JSON lines {"event": "phase"|"result"}.
follow SOURCE: reattach to a running unit. status: active source, if any.
cancel SOURCE: SIGINT the unit only before the package transaction commits.
No command overrides; repository is resolved from this script's location.
"""
import argparse
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time


REPO = Path(__file__).resolve().parents[2]
TIMEOUT = 45
SOURCES = ("system", "aur", "flatpak", "shell")
SNAPSHOT_HOOK = Path("/usr/share/libalpm/hooks/05-snap-pac-pre.hook")
POLL = .2
# The same keyword table classifies check failures and install logs.
ERRORS = (
    ("busy", ("unable to lock database", "could not lock database", "another isla update")),
    ("network", ("could not resolve", "name resolution", "unable to access", "cannot fetch updates",
                 "failed to synchronize", "failed retrieving file", "failed to retrieve",
                 "error sending request", "network is unreachable", "connection timed out",
                 "connection refused", "dns error", "could not read from remote")),
    ("disk", ("not enough free disk space", "no space left on device")),
    ("conflict", ("unresolvable package conflicts", "conflicting files", "conflicting dependencies",
                  "failed to prepare transaction", "could not satisfy dependencies")),
    ("signature", ("invalid or corrupted package", "unknown trust", "signature is invalid",
                   "could not be looked up remotely")),
    ("auth", ("interactive authentication required", "access denied", "not authorized",
              "authentication failed", "a password is required", "incorrect password attempt",
              "no password was provided")),
    ("timeout", ("timeout after",)),
)
REBOOT = re.compile(r"^(linux(?:-[a-z0-9]+)*|glibc|systemd|nvidia(?:-[a-z0-9]+)*)$")
NOT_KERNEL = ("-headers", "-docs", "-api-headers", "-firmware")
CHANGE = re.compile(r"^(?:\(\s*\d+/\s*(\d+)\)\s+)?(?:upgrading|installing|reinstalling|downgrading|removing)\s+(\S+?)(?:\.\.\.)?\s*$")


def classify(text):
    text = text.lower()
    for code, needles in ERRORS:
        if any(needle in text for needle in needles):
            return code
    return "failed"


def capture(args, cwd=None, accepted=(0,), quiet=()):
    """Run a probe; codes in `quiet` count as success only with empty output."""
    try:
        # C locale keeps tool messages in English so classify() can read them.
        process = subprocess.Popen(args, cwd=cwd, stdout=subprocess.PIPE, stdin=subprocess.DEVNULL,
                                   stderr=subprocess.PIPE, text=True, start_new_session=True,
                                   env=dict(os.environ, LC_ALL="C", LANG="C"))
        try:
            out, err = process.communicate(timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
            raise RuntimeError(f"{args[0]}: timeout after {TIMEOUT}s") from None
    except OSError as exc:
        raise RuntimeError(f"{args[0]}: {exc.strerror}") from exc
    if process.returncode in quiet and not out.strip() and not err.strip():
        return ""
    if process.returncode not in accepted:
        detail = (err or out).strip()[:600]
        raise RuntimeError(f"{args[0]} exited {process.returncode}: {detail}")
    return out.strip()


def git(*args):
    return capture(["git", *args], cwd=REPO)


def blank(packages=False):
    result = {"available": False, "count": 0, "error": "", "detail": ""}
    if packages:
        result["packages"] = []
    return result


def fail(result, exc):
    result["detail"] = str(exc)
    result["error"] = classify(str(exc))
    return result


def package_check(command, accepted=(0,), quiet=()):
    result = blank(True)
    try:
        result["packages"] = capture(command, accepted=accepted, quiet=quiet).splitlines()
        result["count"] = len(result["packages"])
        result["available"] = result["count"] > 0
    except RuntimeError as exc:
        fail(result, exc)
    return result


def shell_check():
    result = dict(blank(), dirty=False, branch="", blocked="")
    try:
        result["dirty"] = bool(git("status", "--porcelain", "--untracked-files=all"))
        try:
            result["branch"] = git("symbolic-ref", "--quiet", "--short", "HEAD")
        except RuntimeError:
            result["blocked"] = "detached"
            return result
        try:
            git("rev-parse", "--verify", "@{upstream}")
        except RuntimeError:
            result["blocked"] = "no-upstream"
            return result
        remote = git("config", "--get", f"branch.{result['branch']}.remote")
        if remote != ".":
            git("fetch", "--no-tags", "--", remote)
        ahead, behind = map(int, git("rev-list", "--left-right", "--count", "HEAD...@{upstream}").split())
        result["count"] = behind
        result["available"] = behind > 0
        result["blocked"] = "ahead" if ahead else "dirty" if result["dirty"] else ""
        result["ahead"] = ahead
    except (RuntimeError, ValueError) as exc:
        fail(result, exc)
    return result


def check(no_aur=False):
    aur = dict(blank(True), supported=bool(shutil.which("paru")))
    if aur["supported"] and not no_aur:
        # paru -Qua mirrors pacman -Qu: exit 1 with no output means nothing pending.
        aur.update(package_check(["paru", "-Qua"], quiet=(1,)))
    flatpak = dict(blank(True), supported=bool(shutil.which("flatpak")))
    if flatpak["supported"]:
        flatpak.update(package_check(["flatpak", "remote-ls", "--updates", "--columns=application"]))
    return {"system": package_check(["checkupdates"], accepted=(0, 2)),
            "aur": aur, "flatpak": flatpak, "shell": shell_check(),
            "snapshots": SNAPSHOT_HOOK.exists(),
            "checkedAt": datetime.now(timezone.utc).isoformat()}


def runtime_dir():
    base = Path(os.environ.get("XDG_RUNTIME_DIR") or
                Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")) / "isla"
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    return base


def lock_file():
    return (runtime_dir() / "system-updates.lock").open("a")


def unit(source):
    return f"isla-update-{source}.service"


def manager(source):
    return [] if source == "system" else ["--user"]


def paths(source):
    base = runtime_dir()
    return base / f"update-{source}.log", base / f"update-{source}.cancel"


def command(source):
    if source == "system":
        return ["/usr/bin/pacman", "-Syu", "--noconfirm", "--noprogressbar"]
    if source == "aur":
        # Background AUR builds cannot show a PKGBUILD review; privilege goes
        # through Isla's own sudo prompt (askpass) instead of a terminal.
        return ["paru", "-Sua", "--noconfirm", "--skipreview", "--noprogressbar",
                "--sudo", "sudo", "--sudoflags", "-A", "--removemake"]
    if source == "flatpak":
        return ["flatpak", "update", "--noninteractive", "-y"]
    return ["git", "-C", str(REPO), "pull", "--ff-only", "--no-rebase"]


class Progress:
    """Folds a pacman/paru/flatpak/git log into phase, counts and result facts."""

    def __init__(self, total=0):
        self.phase = "prepare"
        self.done = 0
        self.total = total
        self.package = ""
        self.committed = False
        self.snapshot = ""
        self.changed = []
        self.exit = None
        self.lines = []

    def feed(self, line):
        line = line.rstrip("\n")
        self.lines.append(line)
        text = line.strip()
        if text.startswith("isla-exit "):
            parts = text.split()
            self.exit = int(parts[1]) if len(parts) > 1 and parts[1].lstrip("-").isdigit() else 1
            return
        if text.startswith(":: Synchronizing package databases"):
            self.phase = "sync"
        elif text.startswith(":: Starting full system upgrade") or text.startswith(":: Looking for AUR upgrades"):
            self.phase = "prepare"
        elif match := re.match(r"^Packages \((\d+)\)", text):
            self.total = int(match.group(1))
        elif text.startswith(":: Retrieving packages") or text.startswith(":: Downloading PKGBUILDs"):
            self.phase, self.done = "download", 0
        elif self.phase == "download" and (match := re.match(r"^(\S+) downloading\.\.\.$", text)):
            self.done = min(self.done + 1, self.total or self.done + 1)
            self.package = match.group(1)
        elif match := re.match(r"^==> Making package: (\S+)", text):
            self.phase, self.package = "build", match.group(1)
        elif text.startswith(("checking keyring", "checking package integrity", "loading package files",
                              "checking for file conflicts", "checking available disk space")):
            self.phase = "verify"
        elif text.startswith("loading packages..."):
            self.phase, self.committed = "verify", True
        elif text.startswith(":: Running pre-transaction hooks"):
            self.phase, self.committed = "snapshot", True
        elif match := re.match(r"^==> root: (\d+)", text):
            self.snapshot = self.snapshot or match.group(1)
        elif text.startswith(":: Processing package changes"):
            self.phase, self.done, self.committed = "install", 0, True
        elif self.phase == "install" and (match := CHANGE.match(text)):
            self.done += 1
            if match.group(1):
                self.total = int(match.group(1))
            self.package = match.group(2)
            self.changed.append(match.group(2))
        elif text.startswith(":: Running post-transaction hooks"):
            self.phase = "finish"
        elif match := re.match(r"^(?:Installing|Updating) (\d+)/(\d+)", text):
            self.phase, self.done, self.total = "install", int(match.group(1)), int(match.group(2))

    def cancellable(self, source):
        return source in ("system", "aur", "flatpak") and not self.committed

    def event(self, source):
        return {"event": "phase", "source": source, "phase": self.phase, "done": self.done,
                "total": self.total, "package": self.package, "cancellable": self.cancellable(source)}

    def reboot(self):
        return any(REBOOT.match(name) and not name.endswith(NOT_KERNEL) for name in self.changed)


def emit(value):
    print(json.dumps(value, ensure_ascii=False), flush=True)


def outcome(source, progress, cancelled, launch_error=""):
    result = {"event": "result", "source": source, "snapshot": progress.snapshot,
              "reboot": progress.reboot(), "changed": len(progress.changed), "code": "", "detail": ""}
    if launch_error:
        code = classify(launch_error)
        result.update(result="cancelled" if code == "auth" else "error", code=code, detail=launch_error[-600:])
    elif progress.exit == 0:
        result["result"] = "success"
    elif cancelled and not progress.committed:
        result.update(result="cancelled", code="cancelled")
    else:
        detail = "\n".join(progress.lines[-40:])
        code = classify(detail)
        # Past the commit point a failure may leave a half-applied transaction.
        if progress.committed and code == "failed":
            code = "partial"
        result.update(result="error", code=code, detail=detail[-600:])
    return result


def active(source):
    return subprocess.run(["systemctl", *manager(source), "is-active", "--quiet", unit(source)],
                          stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0


def follow(source, log, cancel, total=0, runner=None):
    progress = Progress(total)
    last = None
    position = 0
    deadline = None
    while True:
        try:
            with log.open() as handle:
                handle.seek(position)
                chunk = handle.read()
                position = handle.tell()
        except FileNotFoundError:
            chunk = ""
        complete, _, rest = chunk.rpartition("\n")
        position -= len(rest.encode())
        for line in complete.splitlines() if complete else ():
            progress.feed(line)
        current = progress.event(source)
        if current != last:
            emit(current)
            last = current
        if progress.exit is not None:
            break
        if runner is not None and runner.poll() is not None and progress.exit is None:
            # systemd-run left before the unit wrote isla-exit: it never started.
            if deadline is None:
                deadline = time.monotonic() + 1
            elif time.monotonic() > deadline:
                emit(outcome(source, progress, False, runner.stderr.read() or "unit did not start"))
                return 1
        if runner is None and not active(source) and progress.exit is None:
            if deadline is None:
                deadline = time.monotonic() + 1
            elif time.monotonic() > deadline:
                progress.exit = progress.exit if progress.exit is not None else 1
                break
        time.sleep(POLL)
    if runner is not None:
        runner.wait()
    result = outcome(source, progress, cancel.exists())
    emit(result)
    return 0 if result["result"] == "success" else 1


def preflight(source):
    if source == "shell":
        status = shell_check()
        if status["error"]:
            raise RuntimeError(status["detail"])
        if status["blocked"]:
            raise RuntimeError(f"shell update blocked: {status['blocked']}")
        return
    if source == "aur" and not shutil.which("paru"):
        raise RuntimeError("paru: not installed")
    if source == "flatpak" and not shutil.which("flatpak"):
        raise RuntimeError("flatpak: not installed")


def install(source, total=0):
    preflight(source)
    log, cancel = paths(source)
    log.write_text("")
    cancel.unlink(missing_ok=True)
    env = {"LC_ALL": "C", "LANG": "C"}
    if source == "aur":
        askpass = Path.home() / ".local/bin/isla-sudo-askpass"
        env.update(SUDO_ASKPASS=str(askpass), PACMAN_AUTH="sudo -A")
    args = ["systemd-run", *manager(source), "--quiet", "--wait", "--collect", "--unit", unit(source),
            "--description", f"Isla update ({source})",
            "-p", f"StandardOutput=append:{log}", "-p", f"StandardError=append:{log}",
            # SIGINT lets pacman stop cleanly; never SIGKILL a transaction.
            "-p", "KillSignal=SIGINT", "-p", "SendSIGKILL=no", "-p", "TimeoutStopSec=infinity",
            "-p", "ExecStopPost=/bin/sh -c \"echo isla-exit $$EXIT_STATUS $$SERVICE_RESULT\""]
    for key, value in env.items():
        args += ["-E", f"{key}={value}"]
    emit({"event": "phase", "source": source, "phase": "auth" if source in ("system", "aur") else "prepare",
          "done": 0, "total": total, "package": "", "cancellable": False})
    runner = subprocess.Popen([*args, "--", *command(source)], stdin=subprocess.DEVNULL,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    return follow(source, log, cancel, total, runner)


def cancel_install(source):
    log, cancel = paths(source)
    progress = Progress()
    try:
        for line in log.read_text().splitlines():
            progress.feed(line)
    except FileNotFoundError:
        pass
    if not progress.cancellable(source) or progress.exit is not None:
        emit({"cancelled": False, "reason": "committed" if progress.committed else "idle"})
        return 1
    cancel.touch()
    code = subprocess.run(["systemctl", *manager(source), "kill", "--signal=SIGINT", unit(source)],
                          stdin=subprocess.DEVNULL, capture_output=True).returncode
    emit({"cancelled": code == 0})
    return 0 if code == 0 else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("check").add_argument("--no-aur", action="store_true")
    install_parser = sub.add_parser("install")
    install_parser.add_argument("target", choices=SOURCES)
    install_parser.add_argument("--total", type=int, default=0)
    for action in ("follow", "cancel"):
        sub.add_parser(action).add_argument("target", choices=SOURCES)
    sub.add_parser("status")
    args = parser.parse_args()
    try:
        if args.action == "status":
            emit({"active": next((source for source in SOURCES if active(source)), "")})
            return 0
        if args.action == "cancel":
            return cancel_install(args.target)
        if args.action == "follow":
            log, cancel = paths(args.target)
            if not active(args.target):
                emit({"event": "idle", "source": args.target})
                return 0
            return follow(args.target, log, cancel)
        with lock_file() as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise RuntimeError("Another Isla update check or installation is running") from None
            if args.action == "check":
                print(json.dumps(check(args.no_aur), ensure_ascii=False))
                return 0
            return install(args.target, args.total)
    except (OSError, RuntimeError) as exc:
        if args.action == "check":
            result = {"system": blank(True), "aur": dict(blank(True), supported=bool(shutil.which("paru"))),
                      "flatpak": dict(blank(True), supported=bool(shutil.which("flatpak"))),
                      "shell": dict(blank(), dirty=False, branch="", blocked=""),
                      "snapshots": SNAPSHOT_HOOK.exists(),
                      "checkedAt": datetime.now(timezone.utc).isoformat()}
            for source in SOURCES:
                fail(result[source], exc)
            print(json.dumps(result, ensure_ascii=False))
        else:
            code = classify(str(exc))
            emit({"event": "result", "source": getattr(args, "target", ""), "result": "error",
                  "code": "blocked" if "blocked" in str(exc) else code, "detail": str(exc),
                  "snapshot": "", "reboot": False, "changed": 0})
            print(f"Isla updates: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
