#!/bin/bash
# push-exit.sh — o CÓDIGO DE SAÍDA do `moj push` e a regra "nunca sai com 1 calado" (16/10/2026, pergunta do Daniel
# Saad: o push saía com 1 sem mensagem). A consulta "o problema já existe?" caía no ramo de criação com QUALQUER
# falha (401 da sessão derrubada, 5xx, rede) e o pedido de criar a org — com a saída descartada — morria no `die`.
#
#   bash test/push-exit.sh
#
# curl FALSO no PATH (molde de test/comp-submit-busy.sh); o código de cada rota vem do ambiente (FAKE_GET,
# FAKE_REPO, FAKE_CREATE). Afirma:
#   · edição e envio SEM MUDANÇA saem com 0 (o mesmo sha); problema novo sai com 0, inclusive quando a org já
#     existe (409 no repo-create — antes era 1 calado);
#   · sessão inválida (401), rede (000) e 5xx na consulta saem com 1 COM a mensagem, sem POST nenhum;
#   · criação recusada (403) sai com 1 com a mensagem do servidor;
#   · nenhum caso sai com 1 sem nada no stderr.
# Roda no artefato dist/moj se existir, senão no repo.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: rc=$(cat "$T/rc") err=$(head -c 300 "$T/err")"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/p/docs" "$T/p/tests/input" "$T/p/tests/output" "$T/p/sols/good"
printf 'tok' > "$T/cfg/token"
printf '{"id":"o#p1","repo":"o","prob":"p1","title":"Um","base_rev":""}\n' > "$T/p/.moj-id"
printf '# Um\n' > "$T/p/docs/enunciado.md"; printf '1\n' > "$T/p/tests/input/sample1"; printf '2\n' > "$T/p/tests/output/sample1"
printf 'int main(){return 0;}\n' > "$T/p/sols/good/a.c"; printf 'TL=1\n' > "$T/p/conf"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; hdr=""; url=""; method=GET; want_code=0
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -D) hdr="$2"; shift 2;; -w) want_code=1; shift 2;;
  -X) method="$2"; shift 2;; -H|-A|--max-time|--data-binary|-d) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
path="${url#*/api/v1}"; printf '%s %s\n' "$method" "${path%%\?*}" >> "$FAKE_LOG"
err(){ printf '{"success":false,"error":{"message":"%s","code":"%s"}}' "$1" "$2"; }
case "$method ${path%%\?*}" in
  "GET /problems/get") code="${FAKE_GET:-200}"
     case "$code" in 2*) body='{"success":true,"id":"o#p1","rev":"r1"}';; 404) body="$(err 'Problema não existe' notfound)";;
       401) body="$(err 'Sessão inválida' auth_required)";; *) body='';; esac;;
  "POST /problems/repo-create") code="${FAKE_REPO:-200}"
     case "$code" in 2*) body='{"success":true,"repo":"o"}';; 409) body="$(err 'Org já existe' repo_taken)";; *) body="$(err x x)";; esac;;
  "POST /problems/create") code="${FAKE_CREATE:-200}"
     case "$code" in 2*) body='{"success":true,"id":"o#p1","sha":"aaaa1111","rev":"r1"}';;
       *) body="$(err 'Sem permissão para criar (mesma regra de criar contest)' create_forbidden)";; esac;;
  "POST /problems/edit") code=200; body='{"success":true,"id":"o#p1","sha":"bbbb2222","rev":"r2"}';;
  *) code=200; body='{"success":true}';;
esac
[[ "$code" == 000 ]] && { (( want_code )) && printf '000'; exit 7; }
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
[[ -n "$hdr" ]] && printf 'HTTP/1.1 %s X\r\n\r\n' "$code" > "$hdr"
(( want_code )) && printf '%s' "$code"
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj"; [[ -x "$BIN" ]] || BIN="$CLI/moj"
echo "usando: $BIN"
run(){ : > "$T/log"; ( cd "$T/p" && env PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_URL=http://fake FAKE_LOG="$T/log" "$@" \
         bash "$BIN" push 2>"$T/err" >"$T/out" ); echo $? > "$T/rc"; }
rc(){ cat "$T/rc"; }
posts(){ grep -c '^POST' "$T/log"; }

echo "== edição e envio sem mudança"
run FAKE_GET=200
chk "edição: rc 0 e 'enviado (edit)'" '[[ $(rc) == 0 ]] && grep -q "enviado (edit): o#p1" "$T/out"'
run FAKE_GET=200
chk "nada mudou: o mesmo envio de novo sai com 0" '[[ $(rc) == 0 ]] && grep -q "sha bbbb2222" "$T/out"'

echo "== problema novo"
run FAKE_GET=404 FAKE_REPO=200
chk "novo: rc 0 e 'enviado (novo)'" '[[ $(rc) == 0 ]] && grep -q "enviado (novo): o#p1" "$T/out"'
run FAKE_GET=404 FAKE_REPO=409
chk "novo numa org que já existe (409 no repo-create): rc 0 e cria (antes: 1 calado)" \
    '[[ $(rc) == 0 ]] && grep -q "enviado (novo)" "$T/out" && grep -q "POST /problems/create" "$T/log"'
run FAKE_GET=404 FAKE_REPO=200 FAKE_CREATE=403
chk "criação recusada: rc 1 com a mensagem do servidor" \
    '[[ $(rc) == 1 ]] && grep -q "criar .o#p1. falhou (HTTP 403): Sem permissão para criar" "$T/err"'

echo "== a consulta 'já existe?' falhou: rc 1 COM mensagem e nada enviado"
run FAKE_GET=401
chk "sessão inválida (401): rc 1, manda rodar 'moj login', nenhum POST" \
    '[[ $(rc) == 1 && $(posts) == 0 ]] && grep -q "moj login" "$T/err" && grep -q "HTTP 401" "$T/err"'
run FAKE_GET=000
chk "sem rede (000): rc 1 com 'não consegui falar', nenhum POST" '[[ $(rc) == 1 && $(posts) == 0 ]] && grep -q "não consegui falar" "$T/err"'
run FAKE_GET=502
chk "5xx: rc 1 com o código, nenhum POST" '[[ $(rc) == 1 && $(posts) == 0 ]] && grep -q "HTTP 502" "$T/err"'

echo "== nunca 1 calado"
bad=0
for g in 200 404 401 000 502 403; do for r in 200 409 401; do for c in 200 403 401; do
  run FAKE_GET=$g FAKE_REPO=$r FAKE_CREATE=$c
  [[ $(rc) == 0 || -s "$T/err" ]] || { echo "    calado: get=$g repo=$r create=$c"; bad=1; }
done; done; done
chk "nenhuma combinação (get × repo-create × create) sai com erro sem mensagem" '(( bad == 0 ))'

echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
