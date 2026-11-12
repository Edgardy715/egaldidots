Q(){ qs -c bar ipc call "$@"; }
chk(){ if pgrep -x qs >/dev/null; then echo "$1: vivo"; else echo "$1: CRASH"; ./relaunch.sh >/dev/null; fi; }
W9(){ hyprctl dispatch 'hl.dsp.focus({ workspace = "9" })' >/dev/null; }
W1(){ hyprctl dispatch 'hl.dsp.focus({ workspace = "1" })' >/dev/null; }
safe(){ [ "$(hyprctl activeworkspace -j | python3 -c "import json,sys;print(json.load(sys.stdin)['windows'])")" = 0 ] || { echo "ABORT: ws no vacío"; W1; exit 1; }; }
W9; sleep .7
Q island hide >/dev/null; Q island launcher DP-1 >/dev/null; sleep 1; safe
python3 -c "print('x'*10000,end='')" > big.txt; wtype "$(cat big.txt)"; sleep 1.5; grim l1.png; chk launcher10k
Q island hide >/dev/null; Q island launcher DP-1 >/dev/null; sleep .8; safe
wtype '"'"'"'\${HOME}%s\\ 😀 ‮rtl'; sleep 1; grim l2.png
for i in $(seq 1 30); do wtype -k Escape; done; sleep 1; grim l2b.png; chk esc30
Q island hide >/dev/null; Q island launcher DP-1 >/dev/null; sleep .8; safe
for i in $(seq 1 40); do wtype -k Tab; done; wtype -k Return; for i in $(seq 1 20); do wtype -k Down; done; wtype -k Return; sleep 1.5; grim l3.png; chk tabreturn
hyprctl clients -j | python3 -c "import json,sys;[print('cliente nuevo:',c['class'],c['title'][:40]) for c in json.load(sys.stdin)]"
W1
