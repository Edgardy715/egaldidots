#!/bin/bash
pkill -x qs; sleep 1
ISLA_CONFIG=/tmp/claude-1000/qa/shell.json setsid nohup qs -c bar --no-duplicate > /tmp/claude-1000/qa/qs.out 2>&1 < /dev/null &
for i in $(seq 1 40); do sleep 0.5; qs -c bar ipc call notifctl count >/dev/null 2>&1 && break; done
sleep 3; pgrep -x qs | head -1
