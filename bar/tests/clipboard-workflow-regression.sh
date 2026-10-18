#!/bin/sh
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/cliphist" <<'MOCK'
#!/bin/sh
case "$1" in
list)
    printf '1\tTexto largo con varias líneas…\n2\t[[ binary data png 640x320 ]]\n'
    i=3; while [ "$i" -le 40 ]; do printf '%s\tEntrada de prueba %s\n' "$i" "$i"; i=$((i+1)); done ;;
decode)
    if [ "$2" = 2 ]; then cat "$ISLA_CLIPBOARD_IMAGE"; else i=1; while [ "$i" -le 100 ]; do printf 'Contenido completo, línea %s\n' "$i"; i=$((i+1)); done; fi ;;
wipe) exit 1 ;;
esac
MOCK
cat > "$tmp/wl-copy" <<'MOCK'
#!/bin/sh
cat > "$ISLA_COPY_OUT"
MOCK
chmod +x "$tmp/cliphist" "$tmp/wl-copy"
magick -size 640x320 gradient:steelblue-coral "$tmp/image.png"
ISLA_CONFIG="$tmp/config.json" ISLA_CLIPBOARD_LIBRARY="$tmp/library" ISLA_CLIPBOARD_IMAGE="$tmp/image.png" ISLA_COPY_OUT="$tmp/copied" PATH="$tmp:$PATH" QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" timeout 26s quickshell -p bar/clipboard-workflow-regression.qml > "$tmp/log" 2>&1 || { cat "$tmp/log"; exit 1; }
grep -q 'PASS: actual pill clipboard' "$tmp/log" || { cat "$tmp/log"; exit 1; }
ISLA_CLIPBOARD_IMAGE="$tmp/image.png" "$tmp/cliphist" decode 1 > "$tmp/expected"
cmp "$tmp/expected" "$tmp/copied"
echo 'PASS: actual pill clipboard preview and collection workflow'
