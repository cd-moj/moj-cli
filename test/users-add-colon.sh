#!/bin/bash
# users-add-colon.sh — `moj-contest -c <cid> users add <login> --name N` com ':' no nome (TCP 2026, 04/10/2026):
# o servidor grava o ':' como '∶' (U+2236 — o placar é TXT separado por ':') e devolve `adjusted`; a CLI mostra o
# nome GRAVADO (e não diz nada quando o nome não mudou). curl FALSO no PATH (molde de test/contest-priority.sh).
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: $(cat "$T/err" "$T/out" 2>/dev/null | head -c 300)"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok-treino' > "$T/cfg/token-treino"; printf 'tok-nc' > "$T/cfg/token-nc"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; data=""
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; --data-binary) data="$2"; shift 2;;
  -H|-A|-X|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
[[ "$data" == @* ]] && cp "${data#@}" "$FAKE/body.json"
[[ "$data" == @- ]] && cat > "$FAKE/body.json"
case "$url" in
  */contest/admin/user-add*)
    n="$(jq -r '.fullname // ""' "$FAKE/body.json")"
    if [[ "$n" == *:* ]]; then t="${n//:/∶}"
      body="$(jq -cn --arg f "$n" --arg t "$t" '{success:true,saved:true,user:{login:"t1",password:"pw1",fullname:$t,email:""},adjusted:[{login:"t1",field:"fullname",from:$f,to:$t}]}')"
    else body='{"success":true,"saved":true,"user":{"login":"t2","password":"pw2","fullname":"Normal","email":""}}'; fi;;
  *) body='{"success":true}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
export FAKE="$T"
run(){ rm -f "$T/body.json"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" "$@" </dev/null >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

run -c nc users add t1 --name 'localhost:6767'
chk "manda o nome cru (o servidor decide)"        '[[ "$(jq -r .fullname "$T/body.json")" == "localhost:6767" ]]'
chk "mostra a senha e o nome GRAVADO com ∶"       '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "^t1  senha: pw1" "$T/out" && grep -q "nome gravado: localhost∶6767" "$T/out"'
run -c nc users add t2 --name 'Normal'
chk "nome sem ':' = só a credencial"              '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "^t2  senha: pw2" "$T/out" && ! grep -q "nome gravado" "$T/out"'
echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
