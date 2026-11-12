#!/bin/bash
A(){ qs -c bar ipc call activity "$@" 2>&1 | tr -d '\n'; echo -n " "; }
Q(){ qs -c bar ipc call "$@" >/dev/null 2>&1; }
LOG=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1); N0=$(qs log $LOG 2>/dev/null | wc -l); T0="$(date '+%F %T')"
p=$(pgrep -x qs|head -1); echo base rss $(awk '/VmRSS/{print $2}' /proc/$p/status)
echo "--- validación"
A start '{"id":"a1","title":"Normal","progress":0.5}'; A start '{"id":"a1","title":"Duplicado"}'; A start '{"id":"a2","title":""}'; A start '{"id":"a3","title":"x","progress":2}'; A start '{"id":"a4","title":"x","progress":-1}'; A start '{"id":"a5","title":"x","progress":"0.5"}'; A update '{"id":"zz","progress":0.1}'; A end '{"id":"a1","state":"done"}'; A end '{"id":"a1","state":"done"}'; A update '{"id":"a1","progress":0.2}'; A start '{"id":"../../x","title":"x"}'; A start '{"id":"b","title":"‮RTL\u0007ctl'"$(printf 'Z%.0s' $(seq 1 400))"'"}'; echo
echo "--- 150 activities + notifs + dnd"
for i in $(seq 1 150); do A start "{\"id\":\"s$i\",\"title\":\"Tarea $i\",\"subtitle\":\"sub\",\"progress\":$(python3 -c "print($i/150)")}" >/dev/null; [ $((i%10)) = 0 ] && notify-send "n$i" "cuerpo"; [ $((i%25)) = 0 ] && Q notifctl toggleDnd; done
Q notifctl disableDnd; sleep 1; grim act1.png; Q island peek DP-1; sleep 1.5; grim act2.png; Q island hide
for i in $(seq 1 150); do A end "{\"id\":\"s$i\",\"state\":\"done\"}" >/dev/null; done; sleep 2; grim act3.png
echo; echo "alive: $(pgrep -x qs|wc -l) rss $(awk '/VmRSS/{print $2}' /proc/$(pgrep -x qs|head -1)/status)"
qs log $LOG 2>/dev/null | tail -n +$N0 | grep -iE "warn|error|TypeError|undefined|binding|Cannot" | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-170 | grep -v textinput | sort | uniq -c | sort -rn | head
echo coredumps: $(coredumpctl list --since "$T0" 2>/dev/null | grep -c SIGSEGV)
