#!/bin/bash
# contest-create.sh — `moj-contest create --mode` (2026-09-16): a flag grava o campo `mode` do spec
# que vai ao POST /treino/contest-create/create; vence o spec/arquivo; valor fora da allowlist morre
# ANTES de falar com o servidor; sem a flag o campo não é inventado (o servidor assume icpc).
# curl FALSO no PATH captura o corpo (--data-binary @arquivo) em $T/body.json.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok' > "$T/cfg/token-treino"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; data=""
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; --data-binary) data="$2"; shift 2;; -H|-A|-X|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
[[ "$data" == @* ]] && cp "${data#@}" "${BODY_OUT:-/dev/null}"
body='{"success":true,"contest_id":"lab1","admin_login":"lab1.admin"}'
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
run(){ rm -f "$T/body.json"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent BODY_OUT="$T/body.json" bash "$BIN" "$@" >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

echo "== --mode obi vai no spec =="
run create --empty --id lab1 --name "Lab 1" --end 1790000000 --mode obi
chk "rc 0 e criado"                          '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "criado: lab1" "$T/out"'
chk "corpo: mode=obi, id, allow_empty"       '[[ "$(jq -c "[.mode,.id,.allow_empty]" "$T/body.json")" == "[\"obi\",\"lab1\",true]" ]]'
echo "== sem --mode: o campo não é inventado =="
run create --empty --id lab1 --end 1790000000
chk "corpo sem mode (servidor assume icpc)"  '[[ "$(jq -r "has(\"mode\")" "$T/body.json")" == false ]]'
echo "== --mode vence o spec do arquivo =="
printf '{"name":"X","mode":"icpc","end":1790000000,"allow_empty":true}' > "$T/work/spec.json"
run create spec.json --mode treino
chk "spec dizia icpc, flag manda treino"     '[[ "$(jq -r .mode "$T/body.json")" == treino ]]'
echo "== valor inválido: morre antes da rede =="
run create --empty --end 1790000000 --mode kattis
chk "rc != 0, mensagem lista os valores, sem POST" '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "icpc, obi, treino ou heuristic" "$T/err" && [[ ! -e "$T/body.json" ]]'
echo "== maiúsculas viram minúsculas =="
run create --empty --end 1790000000 --mode OBI
chk "OBI -> obi"                             '[[ "$(jq -r .mode "$T/body.json")" == obi ]]'
echo "== help cita --mode =="
run help
chk "help: --mode icpc|obi|treino|heuristic" 'grep -q "\-\-mode icpc|obi|treino|heuristic" "$T/out"'

echo; echo "RESULT: $pass passed, $fail failed"; [[ $fail -eq 0 ]]
