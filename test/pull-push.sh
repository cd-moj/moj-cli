#!/bin/bash
# pull-push.sh — `moj pull`, a TRAVA do push/upload e o id implícito, contra um servidor de VERDADE
# (o de dev por padrão). Cria uma org e um problema de teste e apaga os dois no fim.
#
#   MOJ_URL=https://moj.charge.naquadah.com.br:8443 MOJ_TEST_TOKEN=<token> bash test/pull-push.sh
#   bash test/pull-push.sh --mint <login>     # só no DEV: cria uma sessão em $RUNDIR/sessions (e apaga no fim)
#
# Duas pastas do MESMO problema fazem o papel de dois autores (A = a sua, B = "a web / o colega").
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
BIN="$(readlink -f "${MOJ_BIN:-$CLI/moj}")"
export MOJ_URL="${MOJ_URL:-https://moj.charge.naquadah.com.br:8443}"
T="$(mktemp -d)"; MINTED=""; ORG="zz-pull-$EPOCHSECONDS"; PROB="soma"; ID="$ORG#$PROB"; COLL="zz pull $EPOCHSECONDS"
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }

if [[ "${1:-}" == --mint ]]; then
  # dev: a sessão é um arquivo em $RUNDIR/sessions (o que o /auth/login grava). Nunca em produção.
  L="${2:?uso: --mint <login>}"; RUNDIR="$(cd "$CLI/../run" && pwd)"
  MINTED="$(</proc/sys/kernel/random/uuid)"
  ( umask 077; printf 'CONTEST=treino\nLOGIN=%q\nUSERFULLNAME=%q\nLOGINAT=%q\nIP=127.0.0.1\nUA_B64=\nMKEY=ip:127.0.0.1\n' \
      "$L" "teste pull-push" "$EPOCHSECONDS" > "$RUNDIR/sessions/$MINTED" )
  MOJ_TEST_TOKEN="$MINTED"
fi
[[ -n "${MOJ_TEST_TOKEN:-}" ]] || { echo "defina MOJ_TEST_TOKEN (ou --mint <login> no dev)"; exit 2; }
mkdir -p "$T/cfg" "$T/w"; ( umask 077; printf '%s' "$MOJ_TEST_TOKEN" > "$T/cfg/token-treino" )
export MOJ_CONFIG_DIR="$T/cfg" MOJ_NO_CACHE=1 MOJ_UA_FILE=/nonexistent

api(){ curl -sS -H "Authorization: Bearer $MOJ_TEST_TOKEN" -H 'Content-Type: application/json' "$@"; }
cleanup(){
  api -X POST --data-binary "$(jq -cn --arg id "$ID" '{id:$id, confirm:$id}')" "$MOJ_URL/api/v1/problems/delete" >/dev/null 2>&1
  api -X POST --data-binary "$(jq -cn --arg n "$COLL" '{name:$n}')" "$MOJ_URL/api/v1/problems/collection-delete" >/dev/null 2>&1
  api -X POST --data-binary "$(jq -cn --arg n "$ORG" '{name:$n}')" "$MOJ_URL/api/v1/orgs/delete" >/dev/null 2>&1
  [[ -n "$MINTED" ]] && rm -f "$RUNDIR/sessions/$MINTED"
  rm -rf "$T"
}
trap cleanup EXIT
# m <dir> <args…> — roda o moj DENTRO de <dir>; saída em $T/out, $T/err, rc em $T/rc
m(){ local d="$1"; shift; ( cd "$d" && bash "$BIN" "$@" >"$T/out" 2>"$T/err" </dev/null ); echo $? > "$T/rc"; }
rc(){ cat "$T/rc"; }

echo "== setup: org $ORG, problema $ID (pasta A) =="
m "$T/w" whoami; chk "whoami responde com login"         'grep -q "login: [^?]" "$T/out"'
m "$T/w" new "$ORG" "$PROB"; chk "moj new"                   '[[ $(rc) == 0 && -f "$T/w/$PROB/.moj-id" ]]'
mv "$T/w/$PROB" "$T/w/A"; A="$T/w/A"
m "$A" title "Soma de dois"
m "$A" push; chk "push (create) aceito"                    '[[ $(rc) == 0 ]] && grep -q "enviado (novo)" "$T/out"'
chk "base_rev gravado + .moj-base"                         '[[ -n "$(jq -r .base_rev "$A/.moj-id")" && -s "$A/.moj-base" ]]'
chk ".moj-base não sobe (fora do pkg_files)"               '! bash -c "MOJ_CLI_LIB_ONLY=1 source \"$BIN\"; pkg_files \"$A\"" | grep -q moj-base'
m "$T/w" clone "$ID" B; B="$T/w/B"
chk "clone B com base_rev igual ao de A"                   '[[ $(rc) == 0 && "$(jq -r .base_rev "$B/.moj-id")" == "$(jq -r .base_rev "$A/.moj-id")" ]]'
m "$A" pull; chk "pull sem mudança = já está atualizado"   '[[ $(rc) == 0 ]] && grep -q "já está atualizado" "$T/out"'

echo "== B (outro autor) muda; o push de A (velho) é RECUSADO =="
printf 'Some dois inteiros.\n\n## Entrada\n\nDois inteiros.\n\n## Saída\n\nA soma.\n' > "$B/docs/enunciado.md"
printf '5 7\n' > "$B/tests/input/t1"; printf '12\n' > "$B/tests/output/t1"
m "$B" push; chk "push de B aceito"                        '[[ $(rc) == 0 ]] && grep -q "enviado (edit)" "$T/out"'
echo "texto de A" >> "$A/author"
m "$A" push; chk "push de A recusado (409 stale_rev)"      '[[ $(rc) != 0 ]] && grep -q "mudou no servidor" "$T/err" && grep -q "moj push --overwrite" "$T/err"'
chk "a recusa diz QUEM mudou"                              'grep -q "(por " "$T/err"'

echo "== pull: mudança local não enviada => recusa; --force guarda cópia =="
m "$A" pull; chk "pull recusa e lista o arquivo"          '[[ $(rc) != 0 ]] && grep -q "alterado: author" "$T/err"'
chk "nada foi trocado em A"                                '[[ ! -f "$A/tests/input/t1" ]] && grep -q "texto de A" "$A/author"'
echo "print(1)" > "$A/gerador.py"
m "$A" pull --force; chk "pull --force traz a versão do servidor" '[[ $(rc) == 0 && -f "$A/tests/input/t1" ]] && grep -q "Some dois" "$A/docs/enunciado.md"'
chk "a cópia .local-* tem a mudança de A"                  'ls -d "$T/w"/A.local-* >/dev/null 2>&1 && grep -q "texto de A" "$T/w"/A.local-*/author'
chk "arquivo que não é do pacote fica"                     '[[ -f "$A/gerador.py" ]]'
chk "resumo lista o que chegou"                            'grep -q "novo:     tests/input/t1" "$T/out"'
m "$A" push; chk "push de A agora passa"                   '[[ $(rc) == 0 ]] && grep -q "enviado (edit)" "$T/out"'

echo "== pull sem mudança local: traz, e o que sumiu no servidor some aqui =="
m "$B" pull; chk "B puxa o push de A"                      '[[ $(rc) == 0 ]]'
rm -f "$B/tests/input/t1" "$B/tests/output/t1"; m "$B" push
m "$A" pull; chk "pull em A sem mudança local aceita"      '[[ $(rc) == 0 ]] && grep -q "removido: tests/input/t1" "$T/out"'
chk "t1 sumiu de A também"                                 '[[ ! -e "$A/tests/input/t1" && ! -e "$A/tests/output/t1" ]]'
echo "local" >> "$A/tags"
m "$A" pull; chk "servidor igual + mudança local = dica do push" '[[ $(rc) == 0 ]] && grep -q "não mudou" "$T/out" && grep -q "local" "$A/tags"'
m "$A" push

echo "== id implícito (issue #2) =="
m "$A/tests" check; chk "check sem id numa SUBPASTA"       '[[ $(rc) == 0 ]] && grep -q "^$ID" "$T/out"'
m "$A/docs" log -n 3; chk "log sem id"                     '[[ $(rc) == 0 && -s "$T/out" ]]'
sha="$(awk "NR==1{print \$1}" "$T/out")"
m "$A" log "$sha"; chk "log <sha> sem id (sha não é id)"  '[[ $(rc) == 0 ]] && grep -q "^commit " "$T/out"'
m "$A" info "$PROB"; chk "nome sem a org usa a org do .moj-id" '[[ $(rc) == 0 ]] && grep -q "id: $ID" "$T/out"'
m "$A" public off; chk "public off sem id"                 '[[ $(rc) == 0 ]] && grep -q "despublicado" "$T/out"'
m "$T/w" check; chk "fora da pasta: pede o id"             '[[ $(rc) != 0 ]] && grep -q "falta o <id>" "$T/err"'
m "$T/w" info "$PROB"; chk "fora da pasta: nome sem org pede a org" '[[ $(rc) != 0 ]] && grep -q "não diz a org" "$T/err"'
m "$A" rm; chk "rm continua exigindo o id"                 '[[ $(rc) != 0 ]] && grep -q "uso: moj rm" "$T/err"'
m "$A/sols" pull; chk "pull de uma subpasta"               '[[ $(rc) == 0 ]] && grep -q "já está atualizado" "$T/out"'

echo "== coleção pela CLI dentro da pasta: a pasta acompanha (push não é recusado) =="
m "$T/w" collection create "$COLL"
m "$A" collection add "$COLL"; chk "collection add sem id" '[[ $(rc) == 0 ]] && jq -e --arg c "$COLL" ".collections | index(\$c)" "$A/.moj-id" >/dev/null'
m "$A" pull; chk "pasta segue em dia depois da coleção"    'grep -q "já está atualizado" "$T/out"'
m "$A" push; chk "push depois da coleção passa"            '[[ $(rc) == 0 ]]'
m "$B" push; chk "B (sem a coleção) é recusado"            '[[ $(rc) != 0 ]] && grep -q "mudou no servidor" "$T/err"'

echo "== upload: mesma trava =="
m "$B" upload; chk "upload de B (velho) recusado"          '[[ $(rc) != 0 ]] && grep -q "moj upload --overwrite" "$T/err"'
m "$B" upload --overwrite; chk "upload --overwrite passa"  '[[ $(rc) == 0 ]] && grep -q "enviado:" "$T/out"'
m "$A" push; chk "A ficou velho depois do upload de B"     '[[ $(rc) != 0 ]]'
m "$A" push --overwrite; chk "push --overwrite passa"      '[[ $(rc) == 0 ]]'

echo "== pasta de antes do pull (sem .moj-base) =="
rm -f "$B/.moj-base"; m "$B" pull
chk "sem linha de base e diferente: recusa explicando"     '[[ $(rc) != 0 ]] && grep -q "antes de o .moj pull. existir" "$T/err"'
m "$B" pull --force; chk "--force resolve"                  '[[ $(rc) == 0 && -s "$B/.moj-base" ]]'
m "$B" pull; chk "depois: já está atualizado"               'grep -q "já está atualizado" "$T/out"'

echo; echo "passou: $pass  falhou: $fail"
[[ $fail -eq 0 ]]
