"""Linux child lifetime guard for single-threaded service launchers."""
import ctypes
import os
import signal

LIBC = ctypes.CDLL(None, use_errno=True)


def die_with_parent(expected_parent):
    """Kill the child even if its owner dies before it can run cleanup."""
    if LIBC.prctl(1, signal.SIGKILL, 0, 0, 0) != 0:
        os._exit(1)
    if os.getppid() != expected_parent:
        os._exit(1)
