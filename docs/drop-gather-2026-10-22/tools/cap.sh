#!/bin/bash
# usage: cap.sh <dir> <geometry> <seconds> <open-cmd> <close-cmd> <close-at>
d=$1; mkdir -p "$d"; rm -f "$d"/*.ppm "$d"/times
end=$(( $(date +%s%N) + ${3%.*}000000000 ))
( i=0; while [ $(date +%s%N) -lt $end ]; do grim -t ppm -g "$2" "$d/$(printf %04d $i).ppm"; echo "$i $(date +%s%N)" >> "$d/times"; i=$((i+1)); done ) &
sleep 0.25; t0=$(date +%s%N); eval "$4" >/dev/null; echo "open $t0" > "$d/events"
sleep "$6"; t1=$(date +%s%N); eval "$5" >/dev/null; echo "close $t1" >> "$d/events"
wait
