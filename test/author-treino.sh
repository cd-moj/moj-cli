#!/bin/bash
# author-treino.sh — a AUTORIA é sempre na sessão do TREINO (28/10/2026). O servidor só responde /problems e
# /orgs numa sessão do treino (403 author_treino_only); o MOJ_CONTEST é do moj-contest e do moj-comp.
#
#   bash test/author-treino.sh
#
# curl FALSO no PATH (molde de test/push-exit.sh). Afirma:
#   · com MOJ_CONTEST=outro exportado, o `moj login` loga no treino e grava o token do treino;
#   · o `moj whoami` pergunta pelo treino;
#   · um 403 author_treino_only sai com a dica (sessão do treino, rode login sem MOJ_CONTEST).
# Roda no artefato dist/moj se existir, senão no repo.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: rc=$(cat "$T/rc") err=$(head -c 300 "$T/err") log=$(tr '\n' ' ' < "$T/log")"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; hdr=""; url=""; method=GET; want_code=0
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -D) hdr="$2"; shift 2;; -w) want_code=1; shift 2;;
  -X) method="$2"; shift 2;; -H|-A|--max-time|--data-binary|-d) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
path="${url#*/api/v1}"; printf '%s %s\n' "$method" "$path" >> "$FAKE_LOG"
code=200
case "$method ${path%%\?*}" in
  "POST /auth/login") body='{"success":true,"token":"tok-treino"}';;
  "GET /auth/status") body='{"success":true,"logged_in":true,"login":"autor","name":"Autor"}';;
  "GET /problems/mine") code=403
     body='{"success":false,"error":{"message":"Autoria de problema só na sessão do Treino Livre","code":"author_treino_only"}}';;
  *) body='{"success":true}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
[[ -n "$hdr" ]] && printf 'HTTP/1.1 %s X\r\n\r\n' "$code" > "$hdr"
(( want_code )) && printf '%s' "$code"
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj"; [[ -x "$BIN" ]] || BIN="$CLI/moj"
echo "usando: $BIN"
run(){ : > "$T/log"; env PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_URL=http://fake FAKE_LOG="$T/log" MOJ_CONTEST=outro \
         MOJ_NO_CACHE=1 bash "$BIN" "$@" 2>"$T/err" >"$T/out" < "$T/in"; echo $? > "$T/rc"; }

echo "== MOJ_CONTEST=outro exportado: o moj loga no TREINO"
printf 'autor\nsenha\n' > "$T/in"
run login autor
chk "login rc=0"                                  '[[ "$(cat "$T/rc")" == 0 ]]'
chk "POST /auth/login?contest=treino"             'grep -q "^POST /auth/login?contest=treino$" "$T/log"'
chk "nenhum pedido ao contest do MOJ_CONTEST"     '! grep -q "contest=outro" "$T/log"'
chk "token gravado como o do treino"              '[[ -f "$T/cfg/token-treino" || -f "$T/cfg/token" ]] && [[ ! -f "$T/cfg/token-outro" ]]'
: > "$T/in"
run whoami
chk "whoami pergunta pelo treino"                 'grep -q "^GET /auth/status?contest=treino$" "$T/log"'

echo "== 403 author_treino_only sai com a dica"
run ls
chk "rc != 0"                                     '[[ "$(cat "$T/rc")" != 0 ]]'
chk "mensagem do servidor + dica do treino"       'grep -q "Treino Livre" "$T/err" && grep -q "sessão do TREINO" "$T/err"'

echo; echo "RESULT: $pass passed, $fail failed"; (( fail == 0 ))
