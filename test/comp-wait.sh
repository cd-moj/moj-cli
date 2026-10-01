#!/bin/bash
# comp-wait.sh — o moj-comp espera o veredicto SEM DESISTIR SOZINHO (01/10/2026; relato de usuário: o submit saía
# em ~90 s mandando rodar `subs`).
#
#   bash test/comp-wait.sh
#
# curl FALSO no PATH (molde de test/comp-submit-busy.sh): o history vem de $T/h/<k> — a resposta da k-ésima
# consulta é o arquivo de MAIOR k ≤ contagem —, então o teste decide quando cada veredicto "sai". $T/nonet/<k>
# = a k-ésima consulta fica sem rede (000); $T/err401 = sessão expirada; $T/slow = a resposta demora 5 s.
# Afirma: o submit espera além das 30 voltas de antes; o aviso de demora cita Ctrl-C; o Ctrl-C COMO O TERMINAL
# MANDA (SIGINT ao GRUPO: bash + sleep/curl) sai com 130 e diz que a submissão fica; --no-wait não consulta nada;
# `wait` espera todas as pendentes; sem rede no meio segue; 401 para; fora de terminal não há `\r`; o `monitor`
# não trava esperando veredicto e mostra o veredicto numa volta seguinte.
# Roda no artefato dist/moj-comp se existir, senão no repo.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: rc=$(cat "$T/rc" 2>/dev/null) $(tr '\r' '~' < "$T/err" 2>/dev/null | head -c 300)"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg/comp-prova/outbox" "$T/cfg/comp-treino" "$T/work"
printf 'tok' > "$T/cfg/token-prova"; printf 'tok' > "$T/cfg/token-treino"
printf 'A\tcol#pa\tAlfa\n' > "$T/cfg/comp-prova/problems.tsv"
printf 'int main(){return 0;}\n' > "$T/work/sol.c"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; -H|-A|-X|--max-time|--data-binary) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
body='{"success":true}'; code=200
case "$url" in
  */history*)
    n=$(( $(cat "$FAKE/count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$FAKE/count"
    [[ -e "$FAKE/slow" ]] && sleep 5
    if [[ -e "$FAKE/err401" ]]; then code=401; body='{"success":false,"error":{"message":"Sessão expirada — entre de novo","code":"auth_required"}}'
    elif [[ -e "$FAKE/nonet/$n" ]]; then code=000; body=''
    else k="$(ls "$FAKE/h" | sort -n | awk -v n="$n" '$1 <= n' | tail -1)"; body="$(cat "$FAKE/h/$k")"; fi;;
  */submit*) body="{\"success\":true,\"submission_id\":\"$(cat "$FAKE/subid")\",\"status\":\"queued\"}";;
  */offline-submit*) body='{"success":true,"results":[{"status":"accepted","submission_id":"m1aaaaaa","counted_at":1790000000}],"accepted":1,"rejected":0}';;
  */contest/beacon*) body='{"success":true,"server_utc":1790000000,"beacon":"x"}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '%s' "$code"
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-comp"; [[ -x "$BIN" ]] || BIN="$CLI/moj-comp"
echo "usando: $BIN"
export FAKE="$T"
# history: tempo:login:problema:lang:veredicto:epoch:id
hl(){ printf '1790000000:time01:col#pa:C:%s:1790000000:%s\n' "$2" "$1"; }
reset(){ rm -rf "$T/h" "$T/nonet" "$T/count" "$T/err401" "$T/slow"; mkdir -p "$T/h" "$T/nonet"; }
run(){ ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" -c "$@" >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }
count(){ cat "$T/count" 2>/dev/null || echo 0; }

echo "== submit espera além das 30 voltas de antes =="
reset; echo s1aaaaaa > "$T/subid"
hl s1aaaaaa 'Not Answered Yet' > "$T/h/0"; hl s1aaaaaa 'Accepted' > "$T/h/40"
MOJ_COMP_POLL=0.05 run prova submit A sol.c
chk "veredicto na 40ª consulta (antes desistia na 30ª)"   '[[ "$(cat "$T/rc")" == 0 ]] && grep -qx "veredicto: Accepted" "$T/out" && (( $(count) >= 40 ))'
chk "diz que o Ctrl-C para de esperar"                    'grep -q "Ctrl-C para de esperar" "$T/out"'
chk "nenhum \"acompanhe com subs\" de desistência"        '! grep -q "ainda não saiu" "$T/out"'
chk "fora de terminal: sem \\r na saída"                  '! grep -q $'"'"'\r'"'"' "$T/out" "$T/err"'

echo "== aviso de demora =="
reset; hl s1aaaaaa 'Running' > "$T/h/0"; hl s1aaaaaa 'Wrong Answer' > "$T/h/12"
MOJ_COMP_POLL=0.3 MOJ_COMP_SLOW=1 run prova submit A sol.c
chk "aviso no stderr cita Ctrl-C, subs e wait"           'grep -q "está demorando" "$T/err" && grep -q "Ctrl-C" "$T/err" && grep -q "moj-comp wait" "$T/err"'
chk "e o veredicto sai depois"                           'grep -qx "veredicto: Wrong Answer" "$T/out"'

echo "== treino: a rota do problema =="
reset; hl s1aaaaaa 'Not Answered Yet' > "$T/h/0"; hl s1aaaaaa 'Accepted' > "$T/h/3"
MOJ_COMP_POLL=0.05 run treino submit 'col#pa' sol.c
chk "treino também espera e mostra"                      '[[ "$(cat "$T/rc")" == 0 ]] && grep -qx "veredicto: Accepted" "$T/out"'

echo "== Ctrl-C como o terminal manda (SIGINT ao GRUPO) =="
ctrlc(){ # <segundos-antes-do-ctrl-c> — CLI em grupo próprio (set -m), SIGINT p/ o grupo inteiro
  set -m
  ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent MOJ_COMP_POLL=1 \
      exec bash "$BIN" -c prova submit A sol.c >"$T/out" 2>"$T/err" ) &
  local pid=$!; set +m
  sleep "$1"; kill -INT -- "-$pid" 2>/dev/null; wait "$pid"; echo $? > "$T/rc"; }
reset; hl s1aaaaaa 'Not Answered Yet' > "$T/h/0"
ctrlc 2.5
chk "durante o sleep: rc 130"                            '[[ "$(cat "$T/rc")" == 130 ]]'
chk "diz que a submissão continua e como voltar"         'grep -q "continua na fila do juiz" "$T/err" && grep -q "moj-comp wait" "$T/err"'
reset; hl s1aaaaaa 'Not Answered Yet' > "$T/h/0"; touch "$T/slow"
ctrlc 1.5
chk "durante um curl lento: rc 130 e a mesma mensagem"   '[[ "$(cat "$T/rc")" == 130 ]] && grep -q "continua na fila do juiz" "$T/err"'
rm -f "$T/slow"

echo "== --no-wait =="
reset; hl s1aaaaaa 'Not Answered Yet' > "$T/h/0"
run prova submit A sol.c --no-wait
chk "sai na hora, sem consultar o history"               '[[ "$(cat "$T/rc")" == 0 && "$(count)" == 0 ]] && grep -q "espere com .moj-comp wait." "$T/out"'

echo "== wait: as pendentes da conta =="
reset
{ hl old11111 'Accepted'; hl w1aaaaaa 'Not Answered Yet'; hl w2bbbbbb 'Running'; } > "$T/h/0"
{ hl old11111 'Accepted'; hl w1aaaaaa 'Wrong Answer'; hl w2bbbbbb 'Running'; } > "$T/h/3"
{ hl old11111 'Accepted'; hl w1aaaaaa 'Wrong Answer'; hl w2bbbbbb 'Accepted'; } > "$T/h/5"
MOJ_COMP_POLL=0.05 run prova wait
chk "espera as 2 pendentes (a julgada fica de fora)"     'grep -q "aguardando 2 veredicto" "$T/out"'
chk "cada uma quando sai, com o problema"                '[[ "$(cat "$T/rc")" == 0 ]] && grep -qx "col#pa (w1aaaaaa): Wrong Answer" "$T/out" && grep -qx "col#pa (w2bbbbbb): Accepted" "$T/out"'
chk "na ordem em que saíram"                             '[[ "$(grep -n w1aaaaaa "$T/out" | cut -d: -f1)" -lt "$(grep -n w2bbbbbb "$T/out" | cut -d: -f1)" ]]'
reset; hl old11111 'Accepted' > "$T/h/0"
run prova wait
chk "nada pendente: avisa e sai 0"                       '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "nenhuma submissão esperando veredicto" "$T/out"'
reset; { hl w1aaaaaa 'Not Answered Yet'; hl w2bbbbbb 'Running'; } > "$T/h/0"; { hl w1aaaaaa 'Not Answered Yet'; hl w2bbbbbb 'Accepted'; } > "$T/h/2"
MOJ_COMP_POLL=0.05 run prova wait w2bbbbbb
chk "wait <id>: só aquele"                               '[[ "$(cat "$T/rc")" == 0 ]] && grep -qx "veredicto: Accepted" "$T/out" && ! grep -q w1aaaaaa "$T/out"'
reset; hl t1aaaaaa 'Not Answered Yet' > "$T/h/0"; hl t1aaaaaa 'Accepted' > "$T/h/3"
MOJ_COMP_POLL=0.05 run treino wait
chk "treino: wait pelo history-full"                     '[[ "$(cat "$T/rc")" == 0 ]] && grep -qx "veredicto: Accepted" "$T/out"'

echo "== rede e sessão =="
reset; hl s1aaaaaa 'Not Answered Yet' > "$T/h/0"; hl s1aaaaaa 'Accepted' > "$T/h/6"; touch "$T/nonet/2" "$T/nonet/3" "$T/nonet/4"
MOJ_COMP_POLL=0.05 run prova submit A sol.c
chk "sem rede no meio: segue e mostra o veredicto"       '[[ "$(cat "$T/rc")" == 0 ]] && grep -qx "veredicto: Accepted" "$T/out"'
reset; hl s1aaaaaa 'Not Answered Yet' > "$T/h/0"; touch "$T/err401"
MOJ_COMP_POLL=0.05 run prova submit A sol.c
chk "sessão expirada: para com a mensagem do servidor"   '[[ "$(cat "$T/rc")" == 1 && "$(count)" == 1 ]] && grep -q "HTTP 401: Sessão expirada" "$T/err"'

echo "== monitor não trava esperando veredicto =="
reset; printf 'pacote' > "$T/cfg/comp-prova/outbox/1790000000-a.pkt"
hl m1aaaaaa 'Not Answered Yet' > "$T/h/0"; hl m1aaaaaa 'Accepted' > "$T/h/3"
( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent MOJ_COMP_MONITOR_TICK=1 \
    timeout 6 bash "$BIN" -c prova monitor >"$T/out" 2>"$T/err" ) ; echo $? > "$T/rc"
chk "aceitou o pacote e seguiu dando voltas"             'grep -q "ACEITA" "$T/out" && (( $(grep -c "rede: ONLINE" "$T/out") >= 3 ))'
chk "mostrou o veredicto numa volta seguinte"            'grep -q "^  veredicto col#pa (m1aaaaaa): Accepted" "$T/out"'

echo ""; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
