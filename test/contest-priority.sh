#!/bin/bash
# contest-priority.sh — a PRIORIDADE no julgamento e o FUSO da prova pela CLI (01–03/10/2026):
#   • `moj-contest -c <cid> settings set priority=prova` manda {"priority":"prova"} (texto) ao /contest/admin/settings;
#   • `settings set tz=America/Santiago` manda o fuso (texto); `tz=` vazio manda "" (volta ao padrão);
#   • `moj-contest priority <cid> <p>` (super-admin do treino) manda {contest, priority} ao
#     /treino/admin/contest-priority com o token do TREINO e diz a anterior; uso errado morre antes da rede.
#   • `moj-contest rounds undo` (03/10/2026, TCP 2026): confere o id do contest e manda {action:"undo", confirm}; com
#     atividade na rodada nova mostra o porquê do servidor e não envia nada.
# curl FALSO no PATH (molde de test/contest-create.sh): guarda URL, Authorization e corpo; resposta por rota.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: $(cat "$T/err" "$T/out" 2>/dev/null | head -c 300)"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok-treino' > "$T/cfg/token-treino"; printf 'tok-cp' > "$T/cfg/token-cp"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; data=""; auth=""
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; --data-binary) data="$2"; shift 2;;
  -H) [[ "$2" == @* ]] && auth="$(cat "${2#@}")"; [[ "$2" == Authorization* ]] && auth="$2"; shift 2;; -A|-X|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
[[ "$data" == @* ]] && cp "${data#@}" "$FAKE/body.json"
[[ "$data" == @- ]] && cat > "$FAKE/body.json"
printf '%s\n' "$url" >> "$FAKE/urls"; printf '%s\n' "$auth" >> "$FAKE/auths"
case "$url" in
  */treino/admin/contest-priority*) body='{"success":true,"contest":"cp","priority":"super","previous":"prova","changed":true}';;
  */contest/admin/settings*) body='{"success":true,"saved":true,"changed":["CONTEST_PRIORITY=prova"]}';;
  */contest/admin/rounds*)
    if [[ -n "$data" ]]; then body='{"success":true,"undone":true,"restored":"prova","pending":"extra","users":3,"submissions":7}'
    elif [[ -e "$FAKE/undo-blocked" ]]; then body='{"success":true,"active":"extra","undo":{"from":"prova","to":"extra","possible":false,"blockers":[{"code":"round_has_activity","detail":"a rodada no ar (extra) já tem atividade (submissões)"}]}}'
    else body='{"success":true,"active":"extra","undo":{"from":"prova","to":"extra","possible":true,"blockers":[]}}'; fi;;
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
run(){ rm -f "$T/body.json" "$T/urls" "$T/auths"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" "$@" <"${STDIN:-/dev/null}" >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

echo "== settings set priority=prova =="
run -c cp settings set priority=prova
chk "rc 0, corpo {priority:\"prova\"} em texto"       '[[ "$(cat "$T/rc")" == 0 && "$(jq -c . "$T/body.json")" == "{\"priority\":\"prova\"}" ]]'
chk "rota de Regras do contest"                       'grep -q "/contest/admin/settings?contest=cp" "$T/urls"'

echo "== settings set tz=… (fuso da prova, texto; vazio = padrão) =="
run -c cp settings set tz=America/Santiago
chk "rc 0, corpo {tz:\"America/Santiago\"}"           '[[ "$(cat "$T/rc")" == 0 && "$(jq -c . "$T/body.json")" == "{\"tz\":\"America/Santiago\"}" ]]'
run -c cp settings set tz=
chk "tz= vazio manda \"\" (volta ao padrão)"          '[[ "$(cat "$T/rc")" == 0 && "$(jq -c . "$T/body.json")" == "{\"tz\":\"\"}" ]]'

echo "== priority <cid> <p> (super-admin, token do treino) =="
run priority cp super
chk "rc 0 e diz a anterior"                           '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "cp: prioridade super (era prova)" "$T/out"'
chk "corpo {contest, priority}"                       '[[ "$(jq -c . "$T/body.json")" == "{\"contest\":\"cp\",\"priority\":\"super\"}" ]]'
chk "rota do painel do treino, com o token do TREINO" 'grep -q "/treino/admin/contest-priority" "$T/urls" && grep -q "tok-treino" "$T/auths"'
run priority cp
chk "uso errado morre antes da rede"                  '[[ "$(cat "$T/rc")" != 0 && ! -s "$T/urls" ]] && grep -q "uso: moj-contest priority" "$T/err"'
run help
chk "help documenta o comando"                        'grep -q "moj-contest priority <cid>" "$T/out"'

echo "== rounds undo (desfazer a última promoção — TCP 2026) =="
printf 'cp\n' > "$T/yes"; printf 'outro\n' > "$T/no"
STDIN="$T/yes" run -c cp rounds undo
chk "confirma o id e manda {action:undo, confirm:<cid>}" '[[ "$(cat "$T/rc")" == 0 && "$(jq -c . "$T/body.json")" == "{\"action\":\"undo\",\"confirm\":\"cp\"}" ]] && grep -q "desfeita: prova de volta ao ar (7 submissões); extra voltou a planejada" "$T/out"'
STDIN="$T/no" run -c cp rounds undo
chk "id errado: nada é enviado"                       '[[ "$(cat "$T/rc")" != 0 && ! -e "$T/body.json" ]] && grep -q "nada foi alterado" "$T/err"'
: > "$T/undo-blocked"; STDIN="$T/yes" run -c cp rounds undo
chk "com atividade: mostra o porquê e não envia"      '[[ "$(cat "$T/rc")" != 0 && ! -e "$T/body.json" ]] && grep -q "round_has_activity" "$T/err"'
rm -f "$T/undo-blocked"

echo ""; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
