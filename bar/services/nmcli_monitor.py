#!/usr/bin/env python3
"""Exec the read-only monitor with Quickshell's process lifetime."""
import os
import sys

from process_lifetime import die_with_parent

if __name__ == "__main__":
    die_with_parent(int(sys.argv[1]))
    os.execvp("nmcli", ["nmcli", "monitor"])
