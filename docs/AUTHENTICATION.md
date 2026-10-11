# Authentication and locking

Isla presents sudo and Polkit requests through AuthSurface and AuthPrompt.
Polkit, PAM and sudo validate credentials; the shell only presents the request
and forwards the response.

## Setup

The installer links the Fish askpass helper and installs the lockscreen launcher.
Start a new Fish session after installation and keep Isla running to receive
sudo prompts. Existing terminals need their Fish configuration reloaded.

To install the lockscreen launcher separately:

```sh
bash bar/lockscreen/install.sh
```

The launcher is installed under
`${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-lockscreen/lock.sh`, with a backup
of the previous launcher. `~/.local/bin/isla-lock` forwards to it. Super + L,
hypridle and the session menu use this lockscreen; failure to start the
Quickshell lock falls back to hyprlock when available.

The installed launcher points at the checkout. Reinstall it after moving the
repository. Never use preview mode as a real lockscreen.

## Requests

Enter submits once; Escape cancels. If the account selector is open, Escape
closes it first. A rejected password can be retried immediately. Password fields
clear on submission, cancellation and flow changes, and responses are not logged.
Polkit can provide multiple accounts or request a visible, non-secret response.

The Fish wrapper preserves explicit stdin and askpass options. `sudo -S` keeps
stdin; normal commands use Isla's askpass prompt. The helper reports connection
errors on stderr and leaves stdout empty. It does not change sudo or PAM policy.

## Implementation

The backend validates request IDs and messages, rejects duplicate responses and
ignores results from an old flow. Polkit takes priority over pending sudo
requests. The Unix socket is restricted to the current user; reloads hand off
the listener so an old instance cannot remove the replacement's socket.

AuthSurface connects the backend to a view. Tests can supply a fake backend
without registering an authentication agent or using the desktop socket.

## Tests

```sh
python bar/tests/auth-backend.py
python bar/tests/auth-bridge.py
python bar/tests/auth-transport.py
python bar/tests/lockscreen-launcher.py
```

These use temporary processes, sockets and simulated responses. The transport
test needs Wayland. They do not verify real PAM authentication or physical
multi-monitor locking; check those separately on the target system.
