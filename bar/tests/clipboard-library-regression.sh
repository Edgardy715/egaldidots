#!/bin/sh
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/cliphist" <<'EOF'
#!/bin/sh
case "$1" in
    list) [ -f "$ISLA_WIPED" ] || printf '1\tshort\n2\t[[ binary data png 64x32 ]]\n' ;;
    decode) [ "$2" = 2 ] && cat "$ISLA_CLIPBOARD_IMAGE" || printf 'full untruncated text\n' ;;
    wipe) touch "$ISLA_WIPED" ;;
esac
EOF
cat > "$tmp/wl-copy" <<'EOF'
#!/bin/sh
count=1
[ -f "$ISLA_COPY_COUNT" ] && count=$(($(cat "$ISLA_COPY_COUNT") + 1))
printf '%s' "$count" > "$ISLA_COPY_COUNT"
cat > "$ISLA_COPY_OUT.$count"
EOF
chmod +x "$tmp/cliphist" "$tmp/wl-copy"
magick -size 64x32 xc:steelblue "$tmp/image.png"
ISLA_CLIPBOARD_LIBRARY="$tmp/library" ISLA_WIPED="$tmp/wiped" ISLA_CLIPBOARD_IMAGE="$tmp/image.png" ISLA_COPY_OUT="$tmp/copied" ISLA_COPY_COUNT="$tmp/count" PATH="$tmp:$PATH" QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" timeout 12s quickshell -p bar/clipboard-library-regression.qml > "$tmp/log" 2>&1 || { cat "$tmp/log"; exit 1; }
grep -q 'PASS: clipboard library controller integration' "$tmp/log" || { cat "$tmp/log"; exit 1; }
printf 'full untruncated text\n' > "$tmp/expected-text"
cmp "$tmp/expected-text" "$tmp/copied.1"
cmp "$tmp/image.png" "$tmp/copied.2"
[ -f "$tmp/wiped" ]
echo 'PASS: clipboard library save, collections, filters, wipe, reopen, preview and exact copy'
