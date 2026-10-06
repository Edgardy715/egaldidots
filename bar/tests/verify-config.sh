#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
jq empty "$root/shell.json.example"
jq -e '
  .appearance
  | (.fontScale | type == "number")
  and (.spacingScale | type == "number")
  and (.radiusScale | type == "number")
  and (.motionScale | type == "number")
  and (.fontFamily | type == "string")
' "$root/shell.json.example" >/dev/null
if rg -n --glob '*.qml' '"/home/' "$root"; then
  echo 'Hardcoded user path in QML' >&2
  exit 1
fi
rg -qx 'singleton Config Config.qml' "$root/Singletons/qmldir"
test -f "$root/components/IslandNotification.qml"
test -f "$root/components/IslandRestStatus.qml"
test -f "$root/components/IslandMediaVisualizer.qml"
test -f "$root/components/IslandMediaCover.qml"
test -f "$root/components/IslandMediaMetadata.qml"

test -f "$root/components/IslandMediaSummary.qml"
node "$root/tests/settings.cjs"
node "$root/tests/surface-boundaries.cjs"
echo 'Isla configuration checks passed.'
