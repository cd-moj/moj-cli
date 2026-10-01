#!/bin/bash
# comp-submit-busy.sh — o moj-comp mostra o ERRO DO SERVIDOR no envio, sem fingir que é falta de rede
# (01/10/2026: o treino e as listas têm teto de 3 envios na fila por conta — 429 `submit_busy`).
#
#   bash test/comp-submit-busy.sh
#
# curl FALSO no PATH (molde de test/comp-statement.sh): /submit responde 429 com a mensagem do servidor.
# Afirma: no treino, rc != 0 com "HTTP 429" + a mensagem e SEM o "(sem rede?)"; no contest, rc != 0 e o envio
# NÃO vira pacote offline; e sem rede de verdade (código 000) o treino segue dizendo "sem rede".
# Roda no artefato dist/moj-comp se existir, senão no repo.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: $(head -c 300 "$T/err")"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg/comp-prova" "$T/cfg/comp-treino" "$T/work"
printf 'tok' > "$T/cfg/token-prova"; printf 'tok' > "$T/cfg/token-treino"
printf 'int main(){return 0;}\n' > "$T/work/sol.c"
printf 'A\tcol#pa\tAlfa\n' > "$T/cfg/comp-prova/problems.tsv"   # o que o `login`/`problems` deixam no disco
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; -H|-A|-X|--max-time|--data-binary) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
body=""; code=200
case "$url" in
  */submit*) if [[ -n "${FAKE_NONET:-}" ]]; then code=000; body='';
             else code=429; body='{"success":false,"error":{"message":"Você já tem 3 envio(s) aguardando veredicto — espere sair o resultado antes de enviar de novo","code":"submit_busy","inflight":3,"max":3}}'; fi;;
  */contest/problems*) body='{"success":true,"problems":[{"short_name":"A","problem_id":"col#pa","full_name":"Alfa"}]}';;
  */contest/beacon*) body='{"success":true,"server_utc":1,"beacon":"x"}';;
  *) body='{"success":true}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '%s' "$code"
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-comp"; [[ -x "$BIN" ]] || BIN="$CLI/moj-comp"
echo "usando: $BIN"
run(){ ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" -c "$1" "${@:2}" 2>"$T/err" ); echo $? > "$T/rc"; }

echo "== treino: 429 do teto aparece como erro do servidor =="
run treino submit 'col#pa' sol.c > "$T/out" || true
chk "rc != 0"                                  '[[ "$(cat "$T/rc")" != 0 ]]'
chk "HTTP 429 + a mensagem do servidor"        'grep -q "HTTP 429: Você já tem 3 envio(s) aguardando veredicto" "$T/err"'
chk "sem o falso \"(sem rede?)\""              '! grep -q "sem rede" "$T/err"'
echo "== contest: 429 não vira pacote offline =="
run prova submit A sol.c > "$T/out" || true
chk "rc != 0 e HTTP 429"                       '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "HTTP 429" "$T/err"'
chk "nada de modo emergencial"                 '! grep -q "SEM REDE" "$T/err" && ! grep -q "EMPACOTADA" "$T/out"'
echo "== contest sem o problems.tsv (antes do 1º \`problems\`): recarrega a lista e chega ao servidor =="
rm -f "$T/cfg/comp-prova/problems.tsv"
run prova submit A sol.c > "$T/out" || true
chk "não morre mudo: HTTP 429 do /submit"      '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "HTTP 429" "$T/err"'
echo "== treino sem rede de verdade: segue dizendo sem rede =="
FAKE_NONET=1 run treino submit 'col#pa' sol.c > "$T/out" || true
chk "rc != 0 e \"sem rede\""                   '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "sem rede" "$T/err"'

echo ""; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
