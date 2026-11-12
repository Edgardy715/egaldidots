#!/bin/sh
# usage: run.sh <outdir> <legacy0/1> <left0/1>
cd "$(dirname "$0")"; mkdir -p "$1"; rm -f "$1"/*.png
ISLA_CONFIG=$PWD/cfg/isla.json DROP_OUT=$PWD/$1 DROP_LEGACY=$2 DROP_LEFT=$3 QT_QPA_PLATFORM=wayland timeout 20 quickshell -p ${DROP_QML:-drop-frames.qml} 2>&1 | grep -v "WAYLAND\|--- WARNING\|actually running\|qmlscanner" | grep -i "warn\|error\|fail" | head -8
magick montage "$1"/s*.png -tile 2x -geometry 840x300+4+4 -background '#111' "$1-sheet.png"
