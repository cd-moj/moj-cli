#!/bin/bash
# draw-private.sh — `moj-contest problems draw --include-private` (PR #35 do cdmoj): privados só
# com o opt-in. Sem a flag a URL NÃO leva include_private; com ela leva =1; privado sai com 🔒 na
# listagem e no --add; private_included:false (contest sem dono) avisa no stderr.
# curl FALSO no PATH registra método+URL em $T/calls e responde pelo caminho.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok' > "$T/cfg/token-lab1"; printf 'tok' > "$T/cfg/token-treino"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; m=GET
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -X) m="$2"; shift 2;; -D) : > "$2"; shift 2;; --data-binary) shift 2;; -H|-A|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
echo "$m $url" >> "$CALLS"
case "$url" in
  */contest/admin/draw*) body="$(cat "$DRAW_BODY")";;
  *) body='{"success":true,"problem_id":"x"}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
run(){ : > "$T/calls"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent CALLS="$T/calls" DRAW_BODY="$T/draw.json" \
    bash "$BIN" -c lab1 "$@" >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }
printf '%s' '{"success":true,"problems":[{"id":"org#p","title":"Prova da org","bucket":"unknown","private":true,"access":"shared"},{"id":"pub1","title":"Publico","bucket":"easy","private":false,"access":"public"}],"candidates":2,"drawn":2,"seed":7,"private_included":true}' > "$T/draw.json"

echo "== padrão: sem include_private =="
run problems draw --tags grafos --count 2
chk "rc 0"                                   '[[ "$(cat "$T/rc")" == 0 ]]'
chk "URL sem include_private"                '! grep -q include_private "$T/calls" && grep -q "/contest/admin/draw" "$T/calls"'
echo "== --include-private =="
run problems draw --tags grafos --count 2 --include-private
chk "URL com include_private=1"              'grep -q "include_private=1" "$T/calls"'
chk "privado sai com 🔒, público sem"         'grep -q "org#p 🔒" "$T/out" && grep "pub1" "$T/out" | grep -vq "🔒"'
run problems draw --count 2 --include-private --add
chk "--add: adiciona os dois e marca o privado" '[[ "$(grep -c "POST .*/contest/admin/problems" "$T/calls")" == 2 ]] && grep -q "+ org#p (Prova da org 🔒)" "$T/out"'
echo "== contest sem dono =="
printf '%s' '{"success":true,"problems":[{"id":"pub1","title":"Publico","bucket":"easy","private":false,"access":"public"}],"candidates":1,"drawn":1,"seed":7,"private_included":false}' > "$T/draw.json"
run problems draw --include-private
chk "avisa que ficou só com públicos"        'grep -q "não tem dono registrado" "$T/err"'
run problems draw
chk "sem a flag não avisa"                   '! grep -q "dono" "$T/err"'
run problems draw --bogus
chk "opção desconhecida ainda morre"         '[[ "$(cat "$T/rc")" != 0 ]]'

echo; echo "RESULT: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
