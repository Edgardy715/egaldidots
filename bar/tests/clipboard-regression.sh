#!/bin/sh
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/cliphist" <<'EOF'
#!/bin/sh
case "$1" in
    list) sleep 0.2; printf '1\ttexto\n2\t[[ binary data png ]]\n' ;;
    decode) [ "$2" = 2 ] && cat "$ISLA_CLIPBOARD_IMAGE" || printf ' contenido\nsegunda línea\n' ;;
    wipe) printf 'wipe\n' >> "$ISLA_WIPE_OUT"; sleep 0.2; [ "$ISLA_CLIPBOARD_TEST_TYPE" != clear-error ] ;;
esac
EOF
cat > "$tmp/wl-copy" <<'EOF'
#!/bin/sh
printf '%s' "$*" > "$ISLA_COPY_ARGS"
cat > "$ISLA_COPY_OUT"
EOF
chmod +x "$tmp/cliphist" "$tmp/wl-copy"
magick -size 64x32 xc:steelblue "$tmp/image.png"
for kind in text image clear clear-error clear-reduced; do
ISLA_WIPE_OUT="$tmp/wipe-$kind" ISLA_COPY_OUT="$tmp/copied" ISLA_COPY_ARGS="$tmp/args" ISLA_CLIPBOARD_IMAGE="$tmp/image.png" ISLA_CLIPBOARD_TEST_TYPE="$kind" PATH="$tmp:$PATH" \
    QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" timeout 5s quickshell -p bar/clipboard-regression.qml > "$tmp/log" 2>&1 || {
        cat "$tmp/log"
        exit 1
    }
if [ "$kind" = clear ] || [ "$kind" = clear-error ] || [ "$kind" = clear-reduced ]; then
    grep -q 'PASS: clipboard clears asynchronously' "$tmp/log"
    [ "$(wc -l < "$tmp/wipe-$kind")" -eq 1 ]
    continue
fi
grep -q 'PASS: clipboard loads, filters and copies' "$tmp/log"
if [ "$kind" = image ]; then cp "$tmp/image.png" "$tmp/expected"; else printf ' contenido\nsegunda línea\n' > "$tmp/expected"; fi
cmp "$tmp/copied" "$tmp/expected"
[ ! -s "$tmp/args" ]
done
echo 'PASS: clipboard async load, previews, exact copy, clear success/error and duplicate guard'
