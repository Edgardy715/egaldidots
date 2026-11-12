#!/bin/bash
Q(){ qs -c bar ipc call "$@" >/dev/null 2>&1; }
c(){ coredumpctl list --since "$T0" 2>/dev/null | grep -c SIGSEGV; }
T0="$(date '+%F %T')"
echo "A) solo reload x60"; for i in $(seq 1 60); do Q island reload; sleep 0.3; done; sleep 3; echo "coredumps: $(c)"
T0="$(date '+%F %T')"
echo "B) solo superficies (sin reload) x9x40"; for s in launcher overview calendar mixer clipboard notifs connectivity workspaces focus; do for i in $(seq 1 40); do Q island $s DP-1; Q island hide; done; done; sleep 3; echo "coredumps: $(c)"
