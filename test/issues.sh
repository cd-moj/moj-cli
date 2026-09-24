#!/bin/bash
# issues.sh — `moj issues` (issues por problema) contra um servidor de VERDADE (o de dev por padrão). Cria
# uma org e um problema de teste e apaga os dois no fim (as issues vão junto com o problema).
#
#   MOJ_URL=https://moj.charge.naquadah.com.br:8443 MOJ_TEST_TOKEN=<token> bash test/issues.sh
#   bash test/issues.sh --mint <login>     # só no DEV: cria uma sessão em $RUNDIR/sessions (e apaga no fim)
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
BIN="$(readlink -f "${MOJ_BIN:-$CLI/moj}")"
export MOJ_URL="${MOJ_URL:-https://moj.charge.naquadah.com.br:8443}"
T="$(mktemp -d)"; MINTED=""; ORG="zz-iss-$EPOCHSECONDS"; PROB="soma"; ID="$ORG#$PROB"
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; sed 's/^/     | /' "$T/out" "$T/err" | head -8; ((fail++)); fi; }

if [[ "${1:-}" == --mint ]]; then
  L="${2:?uso: --mint <login>}"; RUNDIR="$(cd "$CLI/../run" && pwd)"
  MINTED="$(</proc/sys/kernel/random/uuid)"
  ( umask 077; printf 'CONTEST=treino\nLOGIN=%q\nUSERFULLNAME=%q\nLOGINAT=%q\nIP=127.0.0.1\nUA_B64=\nMKEY=ip:127.0.0.1\n' \
      "$L" "teste issues" "$EPOCHSECONDS" > "$RUNDIR/sessions/$MINTED" )
  MOJ_TEST_TOKEN="$MINTED"
fi
[[ -n "${MOJ_TEST_TOKEN:-}" ]] || { echo "defina MOJ_TEST_TOKEN (ou --mint <login> no dev)"; exit 2; }
mkdir -p "$T/cfg" "$T/w"; ( umask 077; printf '%s' "$MOJ_TEST_TOKEN" > "$T/cfg/token-treino" )
export MOJ_CONFIG_DIR="$T/cfg" MOJ_NO_CACHE=1 MOJ_UA_FILE=/nonexistent

api(){ curl -sS -H "Authorization: Bearer $MOJ_TEST_TOKEN" -H 'Content-Type: application/json' "$@"; }
cleanup(){
  api -X POST --data-binary "$(jq -cn --arg id "$ID" '{id:$id, confirm:$id}')" "$MOJ_URL/api/v1/problems/delete" >/dev/null 2>&1
  api -X POST --data-binary "$(jq -cn --arg n "$ORG" '{name:$n}')" "$MOJ_URL/api/v1/orgs/delete" >/dev/null 2>&1
  [[ -n "$MINTED" ]] && rm -f "$RUNDIR/sessions/$MINTED"
  rm -rf "$T"
}
trap cleanup EXIT
# m <dir> <args…> — roda o moj DENTRO de <dir>, stdin FECHADO (o texto só vem de -m/-F)
m(){ local d="$1"; shift; ( cd "$d" && timeout 60 bash "$BIN" "$@" >"$T/out" 2>"$T/err" </dev/null ); echo $? > "$T/rc"; }
rc(){ cat "$T/rc"; }

echo "== setup: org $ORG, problema $ID =="
m "$T/w" new "$ORG" "$PROB"; chk "moj new"                  '[[ $(rc) == 0 ]]'
P="$T/w/$PROB"; m "$P" title "Soma de dois"; m "$P" push; chk "push (create)" '[[ $(rc) == 0 ]]'

echo "== abrir, listar, comentar, fechar =="
m "$P" issues; chk "lista vazia (id da pasta)"             '[[ $(rc) == 0 ]] && grep -q "0 aberta(s), 0 fechada(s)" "$T/out"'
m "$P" issues new "Teste 7 fora do limite" -m "n=1296 e o enunciado diz N <= 1000"
chk "abre a #1 com o id da pasta"                          '[[ $(rc) == 0 ]] && grep -q "issue #1 aberta" "$T/out"'
m "$T/w" issues new "$ID" "TL do Python"; chk "abre a #2 com o id explícito" '[[ $(rc) == 0 ]] && grep -q "issue #2 aberta" "$T/out"'
printf 'linha 1\nlinha 2\n' > "$T/nota.txt"
m "$P" issues comment 1 -F "$T/nota.txt"; chk "comenta de arquivo (-F)" '[[ $(rc) == 0 ]] && grep -q "1 comentário" "$T/out"'
m "$P" issues comment 1; chk "comentar sem texto falha (e não espera o stdin)" '[[ $(rc) != 0 ]] && grep -q "falta o texto" "$T/err"'
m "$P" issues show 1; chk "show mostra corpo e comentário" 'grep -q "n=1296" "$T/out" && grep -q "    linha 2" "$T/out"'
m "$P" check; chk "check: não está pronto por causa da issue" 'grep -q "pronto: NÃO" "$T/out" && grep -q "issue(s) aberta(s)" "$T/out"'
m "$P" issues close 1 -m "t7 regerado"; chk "fecha com comentário" '[[ $(rc) == 0 ]] && grep -q "fechada" "$T/out"'
m "$P" issues close 1; chk "fechar de novo = recusa (409)"  '[[ $(rc) != 0 ]] && grep -q "já está fechada" "$T/err"'
m "$P" issues; chk "lista: 1 aberta, 1 fechada, fechada escondida" 'grep -q "1 aberta(s), 1 fechada(s)" "$T/out" && ! grep -q "Teste 7" "$T/out"'
m "$P" issues --all; chk "--all mostra a fechada"           'grep -q "Teste 7" "$T/out"'
m "$P" --json issues; chk "--json devolve o JSON cru"       '[[ "$(jq -r ".issues|length" "$T/out")" == 2 ]]'
m "$P" issues show 9; chk "issue inexistente"               '[[ $(rc) != 0 ]] && grep -q "não existe" "$T/err"'

echo; echo "passou: $pass  falhou: $fail"
[[ $fail -eq 0 ]]
