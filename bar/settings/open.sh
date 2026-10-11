#!/bin/sh
# Use the running shell's Config instance: one writer and live preview.
set -eu
bar_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec quickshell -p "$bar_dir" ipc call island settings
