Q(){ qs -c bar ipc call "$@"; }
chk(){ if pgrep -x qs >/dev/null; then echo "$1: vivo"; else echo "$1: CRASH"; ./relaunch.sh >/dev/null; fi; }
LONG=$(python3 -c "print('A'*20000)")
for j in '' '{' 'null' '[]' '{"id":1}' '{"id":"a","title":"'"$LONG"'"}' '{"id":"a","progress":-5}' '{"id":"a","progress":1e999}' '{"title":null}'; do Q activity start "$j" 2>&1|head -c 100; Q activity update "$j" >/dev/null 2>&1; Q activity end "$j" >/dev/null 2>&1; done; sleep 1; chk activity
for j in '' '{' '[]' '{"island":{"x":"abc"}}' '{"__proto__":{"a":1}}' '{"theme":{"scale":-1}}' '{"theme":{"scale":1e308}}'; do echo "upd[$j] => $(Q settings update "$j" 2>&1 | head -c 160)"; done; sleep 1; chk settings
Q settings get | head -c 300; echo; Q settings catalog | head -c 400; echo
