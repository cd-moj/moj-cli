#!/bin/bash
# tl-clock-conf.sh — o RELÓGIO DO TL na CLI (05/11/2026; cdmoj/docs/PACOTE.md "Relógio do TL"). Sem rede.
#   · o pré-voo (`gate`) reprova TLCLOCK/WALLTL inválidos e o relógio de CPU num problema paralelo — a mesma regra
#     do validate-problem.sh (conf_tlclock_sane), que reprova o pacote no servidor;
#   · o menu `moj edit → 8 → 13` grava/tira o TLCLOCK (no FIM do conf: a linha fica DENTRO do tl-checksum, trocar
#     recalibra) e o `→ 14` grava/limpa o WALLTL, que só vale com o relógio de CPU;
#   · `moj calib`/`moj check` dizem o relógio de CPU; com a parede (ou servidor antigo, sem tl_clock), nada muda.
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"; CLI="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj" 2>/dev/null
set +e; set +o pipefail
type tlclock_conf_gate >/dev/null 2>&1 || { echo "FAIL: tlclock_conf_gate não carregou"; exit 1; }
pass=0; fail=0
ck(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
P="$T/p"; mkdir -p "$P/docs" "$P/tests/input" "$P/tests/output" "$P/sols/good"
printf '# x\n\n## Entrada\n\n## Saída\n' > "$P/docs/enunciado.md"
printf '1\n' > "$P/tests/input/sample1"; printf '1\n' > "$P/tests/output/sample1"; printf 'int main(){}\n' > "$P/sols/good/a.c"
printf '{"id":"o#p","repo":"o","prob":"p","title":"P"}' > "$P/.moj-id"
gok(){ printf "$1" > "$P/conf"; gate "$P" >/dev/null 2>&1; }

echo "== gate: TLCLOCK e WALLTL =="
ck "conf sem as chaves passa"                   'gok "CALIBRATIONTL=5\n"'
ck "TLCLOCK=wall e TLCLOCK=cpu passam"          'gok "TLCLOCK=wall\n" && gok "TLCLOCK=cpu\n"'
ck "aspas e comentário no valor passam" "gok \"TLCLOCK='cpu'  # icpc\\n\""
ck "TLCLOCK=CPU (maiúscula) reprova, como no servidor" '! gok "TLCLOCK=CPU\n"'
ck "TLCLOCK=parede reprova"                     '! gok "TLCLOCK=parede\n"'
ck "a mensagem diz qual chave"                  '[[ "$(gate "$P" 2>&1 >/dev/null)" == *"TLCLOCK=parede inválido"* ]]'
ck "WALLTL 1, 8.5 e 60 passam"                  'gok "TLCLOCK=cpu\nWALLTL=1\n" && gok "TLCLOCK=cpu\nWALLTL=8.5\n" && gok "TLCLOCK=cpu\nWALLTL=60\n"'
ck "WALLTL 0.5, 61, abc e 8,5 reprovam"         '! gok "WALLTL=0.5\n" && ! gok "WALLTL=61\n" && ! gok "WALLTL=abc\n" && ! gok "WALLTL=8,5\n"'
ck "cpu com CPUNEEDED=4 reprova; parede com CPUNEEDED=4 passa" '! gok "TLCLOCK=cpu\nCPUNEEDED=4\n" && gok "TLCLOCK=wall\nCPUNEEDED=4\n"'
ck "a mensagem do paralelo"                     '[[ "$(printf "TLCLOCK=cpu\nCPUNEEDED=4\n" > "$P/conf"; gate "$P" 2>&1 >/dev/null)" == *"problema paralelo precisa do relógio de parede"* ]]'

echo "== menu moj edit → 8 → 13/14 (respostas de uma fila no lugar do teclado) =="
Q="$T/q"; ask(){ local l; l="$(head -n1 "$Q")"; tail -n +2 "$Q" > "$Q.t"; mv "$Q.t" "$Q"; printf '%s' "$l"; }
menu(){ printf "$1" > "$Q"; edit_conf "$P" >/dev/null 2>&1; }
printf 'TLMOD[calibrafactor]=1.35\nCALIBRATIONTL=5\n' > "$P/conf"
menu '14\n8\nv\n'
ck "14 sem o relógio de CPU: nada muda"         '! grep -q "^WALLTL" "$P/conf"'
menu '13\ncpu\nv\n'
ck "13 → cpu: TLCLOCK=cpu no FIM do conf"       '[[ "$(tail -n1 "$P/conf")" == TLCLOCK=cpu && "$(head -n1 "$P/conf")" == "TLMOD[calibrafactor]=1.35" ]]'
menu '14\n8\nv\n'
ck "14: grava o WALLTL"                         '[[ "$(conf_get "$P" WALLTL)" == 8 ]]'
menu '14\n70\nv\n'
ck "14 com valor inválido (70): nada muda"      '[[ "$(conf_get "$P" WALLTL)" == 8 ]]'
ck "o menu mostra o relógio e o WALLTL"         '[[ "$(printf "v\n" > "$Q"; edit_conf "$P" 2>/dev/null)" == *"13) relógio do TL (TLCLOCK): cpu   14) teto mínimo de parede (WALLTL): 8"* ]]'
menu '13\nrelogio\nv\n'
ck "13 com valor inválido: nada muda"           '[[ "$(conf_get "$P" TLCLOCK)" == cpu ]]'
menu '13\nWALL\nv\n'
ck "13 → WALL (maiúscula aceita): TLCLOCK e WALLTL saem" '! grep -q "^TLCLOCK" "$P/conf" && ! grep -q "^WALLTL" "$P/conf"'
MT="${MOJTOOLS_DIR:-$CLI/../mojtools}"
if [[ -f "$MT/tl-checksum.sh" ]]; then
  printf 'CALIBRATIONTL=5\n' > "$P/conf"; c1="$(bash "$MT/tl-checksum.sh" "$P")"
  menu '13\ncpu\nv\n'
  ck "o tl-checksum MUDA com o relógio (trocar recalibra)" '[[ -n "$c1" && "$(bash "$MT/tl-checksum.sh" "$P")" != "$c1" ]]'
else echo "  (sem mojtools em $MT: pulei a conferência do tl-checksum)"; fi

echo "== moj calib / moj check: o relógio de CPU =="
cat > "$T/calib.json" <<'JSON'
{"success":true,"id":"col#pa","checksum":"50d87838e003d32b","version":"a15f065a04074d64","being_calibrated":false,"calibrating":[],"good_langs":["c"],"tl_override":{},"tl_method":"moj","kattis":{"a":2.0,"b":1.5,"r":1.0},"tl_clock":"cpu","wall_tl":8.0,"time_limits":{"c":"0.4","default":"0.4"},"time_limits_calibrated":{"c":"0.4","default":"0.4"},"time_limits_by_method":{"moj":{"calibrated":{"c":"0.4","default":"0.4"},"effective":{"c":"0.4","default":"0.4"}},"kattis":{"calibrated":{"c":"1","default":"1"},"effective":{"c":"1","default":"1"}}},"missing_langs":[],"allow_tle":false,"drift":{},"hosts":[{"host":"juiz1","tl":{"c":".4","default":".4"},"tl_kattis":{"c":"1","default":"1"},"missing":[],"at":1793025188,"version":"a15f065a04074d64","stale":false,"sols":[],"validator":null}]}
JSON
cat > "$T/tl.json" <<'JSON'
{"success":true,"problem":"col#pa","checksum":"50d87838e003d32b","time_limits":{"c":"0.4","default":"0.4"},"time_limits_calibrated":{"c":"0.4","default":"0.4"},"tl_override":{},"tl_method":"moj","kattis":{"a":2.0,"b":1.5,"r":1.0},"tl_clock":"cpu","wall_tl":8.0,"time_limits_by_method":{"moj":{"calibrated":{"c":"0.4","default":"0.4"},"effective":{"c":"0.4","default":"0.4"}},"kattis":{"calibrated":{"c":"1","default":"1"},"effective":{"c":"1","default":"1"}}},"calibrated_checksum":"50d87838e003d32b","hosts":{"juiz1":{"tl":{"c":".4","default":".4"},"at":1793025188,"tl_kattis":{"c":"1","default":"1"},"pkg_version":"a15f065a04074d64"}},"updated_at":1793025188,"calibrated_at":1793025188,"calibrated":true,"being_calibrated":false,"stale":false,"needs_recalibration":false}
JSON
need_login(){ :; }
api(){ case "$2" in /problems/calib*) cat "$T/calib.json";; /problems/tl*) cat "$T/tl.json";;
  /problems/validation*) echo '{"ok":true,"checks":[]}';;
  /problems/status*) echo '{"problems":[{"ready":true,"pending":[],"sols":{"state":"ok"},"inputs":{"state":"none"}}]}';; esac; }
jq -c '.hosts[0].sols = [{"file":"sleep.c","lang":"c","category":"slow","verdict":"Time Limit Exceeded,0p","method":"moj","tests":[{"name":"t1","code":"TLE","time":0.23,"tl":0.4,"wall":true},{"name":"t2","code":"AC","time":0.1,"tl":0.4}],"expect":{"state":"ok","why":"tle"}}]' "$T/calib.json" > "$T/x" && mv "$T/x" "$T/calib.json"
out="$(cmd_calib 'col#pa' 2>&1)"
ck "calib: o teste morto pela parede leva a marca; o outro não" '[[ "$out" == *"t1: TLE  0.23s  (tl 0.4s) · parede"* && "$out" == *"t2: AC  0.1s  (tl 0.4s)"* && "$out" != *"t2: AC  0.1s  (tl 0.4s) · parede"* ]]'
ck "calib: o relógio de CPU e o WALLTL (8.0 sai 8 em todo jq)" '[[ "$out" == *"relógio do TL: CPU (user+sys) — os tempos abaixo são de CPU; a parede é só um teto maior (WALLTL=8s)"* ]]'
out="$(cmd_check 'col#pa' 2>&1)"
ck "check: o relógio de CPU"                    '[[ "$out" == *"relógio do TL: CPU (user+sys) — o TL acima é tempo de CPU; a parede é só um teto maior (WALLTL=8s)"* ]]'
for f in calib tl; do jq -c '.tl_clock = "wall" | .wall_tl = null' "$T/$f.json" > "$T/x" && mv "$T/x" "$T/$f.json"; done
out="$(cmd_calib 'col#pa' 2>&1)"; out2="$(cmd_check 'col#pa' 2>&1)"
ck "parede: nenhuma linha de relógio"           '[[ "$out" != *"relógio do TL"* && "$out2" != *"relógio do TL"* ]]'
for f in calib tl; do jq -c 'del(.tl_clock, .wall_tl)' "$T/$f.json" > "$T/x" && mv "$T/x" "$T/$f.json"; done
out="$(cmd_calib 'col#pa' 2>&1)"; out2="$(cmd_check 'col#pa' 2>&1)"
ck "servidor antigo (sem tl_clock): nenhuma linha de relógio" '[[ "$out" != *"relógio do TL"* && "$out2" != *"relógio do TL"* ]]'

echo; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
