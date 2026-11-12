#!/bin/bash
Q(){ qs -c bar ipc call "$@" >/dev/null 2>&1; }
P(){ pgrep -x "qs|quickshell" | head -1; }
stat(){ p=$(P); echo "$1 pid=$p rss=$(awk '/VmRSS/{print $2}' /proc/$p/status)kB fd=$(ls /proc/$p/fd | wc -l) thr=$(ls /proc/$p/task | wc -l)"; }
stat base
for i in $(seq 1 25); do Q island launcher DP-1; Q island reload; Q island overview DP-1; Q island reloadColors; Q island hide; done
sleep 2; stat after_reload25
for s in launcher overview calendar mixer clipboard notifs connectivity workspaces focus; do for i in $(seq 1 40); do Q island $s DP-1; Q island hide; done; done
sleep 2; stat after_cycle360
sleep 20; stat idle20
p=$(P); a=$(awk '{print $14+$15}' /proc/$p/stat); sleep 10; b=$(awk '{print $14+$15}' /proc/$p/stat); echo "idle cpu ticks/10s: $((b-a))"
