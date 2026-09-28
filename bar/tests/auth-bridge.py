#!/usr/bin/env python3
"""Test the repository askpass and fish wrapper using fake replies and executables."""
import json
import os
from pathlib import Path
import re
import shlex
import socket
import subprocess
import tempfile
import threading

repo = Path(__file__).resolve().parents[2]
askpass = repo / "fish/.local/bin/isla-sudo-askpass"
fish_config = repo / "fish/.config/fish/config.fish"


def check(value, label):
    if not value:
        raise AssertionError(label)


def bridge_case(arguments, reply, expected_code, expected_prompt, tracked=True):
    with tempfile.TemporaryDirectory(prefix="isla-askpass-test-") as directory:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            listener.bind(str(Path(directory) / "isla-sudo-askpass.sock"))
            listener.listen(1)
            listener.settimeout(5)
            requests = []
            failures = []

            def serve():
                try:
                    client, _ = listener.accept()
                    with client:
                        client.settimeout(5)
                        data = b""
                        while b"\n" not in data:
                            chunk = client.recv(4096)
                            if not chunk:
                                raise AssertionError("bridge closed before request")
                            data += chunk
                        requests.append(json.loads(data.split(b"\n", 1)[0]))
                        for fragment in reply:
                            client.sendall(fragment)
                except Exception as error:
                    failures.append(type(error).__name__)

            server = threading.Thread(target=serve)
            server.start()
            env = dict(os.environ, XDG_RUNTIME_DIR=directory, SUDO_PROMPT="Fallback prompt")
            env.pop("ISLA_AUTH_ID", None)
            if tracked:
                env["ISLA_AUTH_ID"] = "fixture-operation"
            result = subprocess.run([str(askpass), *arguments], env=env,
                                    capture_output=True, timeout=6)
            server.join(timeout=6)
            check(not server.is_alive() and not failures, "fake bridge server completed")
            check(result.returncode == expected_code, "askpass exit status")
            check(not result.stderr, "askpass writes no diagnostics or responses to stderr")
            check(len(requests) == 1, "single askpass request")
            check(requests[0]["prompt"] == expected_prompt, "argv prompt priority and sanitization")
            check(requests[0]["tracked"] is tracked, "tracked flag")
            check(bool(requests[0]["id"]), "operation id exists")
            if tracked:
                check(requests[0]["id"] == "fixture-operation", "operation id retained")
            expected_output = b"fixture-response\n" if expected_code == 0 else b""
            check(result.stdout == expected_output, "askpass response or cancellation")


bridge_case(["Actual\nprompt\r"], [b"fixture-", b"response\n"], 0, "Actual prompt ")
bridge_case([], [b"fixture-response\n"], 0, "Fallback prompt", tracked=False)
bridge_case(["Cancel prompt"], [b"__ISLA_CANCEL__\n"], 1, "Cancel prompt")
bridge_case(["Disconnected prompt"], [], 1, "Disconnected prompt")
with tempfile.TemporaryDirectory(prefix="isla-askpass-missing-") as directory:
    missing = subprocess.run([str(askpass)], env=dict(os.environ, XDG_RUNTIME_DIR=directory),
                             capture_output=True, timeout=5)
    check(missing.returncode == 1 and not missing.stdout
          and "no está disponible" in missing.stderr.decode(),
          "missing shell reports bridge failure without a password response")

wrapper_match = re.search(r"^function sudo --wraps /usr/bin/sudo.*?^end$",
                          fish_config.read_text(), re.MULTILINE | re.DOTALL)
check(wrapper_match is not None, "repository sudo wrapper exists")
with tempfile.TemporaryDirectory(prefix="isla-sudo-wrapper-test-") as directory:
    root = Path(directory)
    executable = '''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
kind = Path(sys.argv[0]).name
with open(os.environ["ISLA_TEST_LOG"], "a") as output:
    output.write(json.dumps({"kind": kind, "args": sys.argv[1:],
                             "id": os.environ.get("ISLA_AUTH_ID", "")}) + "\\n")
if kind == "sudo-fake":
    raise SystemExit(int(os.environ["ISLA_TEST_VALIDATE"] if sys.argv[1:] == ["-A", "-v"]
                         else os.environ["ISLA_TEST_COMMAND"]))
'''
    for name in ["sudo-fake", "qs"]:
        path = root / name
        path.write_text(executable)
        path.chmod(0o700)
    wrapper = wrapper_match.group().replace("command /usr/bin/sudo", "command " + shlex.quote(str(root / "sudo-fake")))
    check("command /usr/bin/sudo" not in wrapper, "all sudo calls replaced with fake")

    def wrapper_case(arguments, expected, validation=0, command=0):
        log = root / "calls.jsonl"
        log.unlink(missing_ok=True)
        env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"],
                   ISLA_TEST_LOG=str(log), ISLA_TEST_VALIDATE=str(validation),
                   ISLA_TEST_COMMAND=str(command))
        env.pop("ISLA_AUTH_ID", None)
        invocation = "sudo " + " ".join(shlex.quote(argument) for argument in arguments)
        result = subprocess.run(["fish", "--no-config", "-c", wrapper + "\n" + invocation],
                                env=env, capture_output=True, timeout=5)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        expected = [[calls[0]["id"] if arg == "<id>" else arg for arg in args]
                    for args in expected]
        check([call["args"] for call in calls] == expected, "wrapper forwards expected arguments")
        check(result.returncode == (validation or command), "wrapper preserves command status")
        check(not result.stdout and not result.stderr, "wrapper emits no fake data")
        if calls[0]["args"] == ["-A", "-v"]:
            check(calls[0]["id"] and calls[0]["id"] == calls[1]["id"], "preflight correlation")
            check(calls[1]["kind"] == "qs" and calls[1]["args"][5] == "validated",
                  "validated result comes from preflight")
            check(calls[1]["args"][-1] == str(validation), "preflight status reported")
            if validation == 0:
                check(not calls[-1]["id"], "ordinary command does not inherit tracked id")

    for args in [["-S", "id"], ["--stdin", "id"], ["-k", "-S", "id"],
                 ["-kS", "id"], ["-u", "root", "-S", "id"], ["-Su", "root", "id"],
                 ["-A", "id"], ["--askpass", "id"], ["-kA", "id"]]:
        wrapper_case(args, [args])
    for args in [["-u", "root", "id"], ["-k", "id"], ["--user=root", "id"],
                 ["-uSomeUser", "id"], ["-p", "-S", "id"], ["--prompt=-S", "id"],
                 ["--", "echo", "-S"]]:
        wrapper_case(args, [["-A", *args]])
    # Ordinary commands preserve preflight; command arguments never become sudo flags.
    for args in [["echo"], ["echo", "-S"], ["echo", "--stdin"]]:
        wrapper_case(args, [["-A", "-v"],
                            ["-c", "bar", "ipc", "call", "sudoAuth", "validated", "<id>", "0"],
                            ["-A", *args]])
    wrapper_case(["echo"], [["-A", "-v"],
                           ["-c", "bar", "ipc", "call", "sudoAuth", "validated", "<id>", "1"]],
                 validation=1)
    wrapper_case(["echo"], [["-A", "-v"],
                           ["-c", "bar", "ipc", "call", "sudoAuth", "validated", "<id>", "0"],
                           ["-A", "echo"]], command=7)
    wrapper_case(["-S", "id"], [["-S", "id"]], command=9)

print("PASS: isolated askpass socket and fish sudo option forwarding")
