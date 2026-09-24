#!/bin/bash
# parallel-conf.sh — as chaves de PARALELISMO do conf na CLI (24/09/2026): o pré-voo (`gate`) reprova
# valor inválido de CPUNEEDED/SAMENUMA/MAXPARALLELTESTS/ALLOWPARALLELTEST — a mesma exigência do
# validate-problem.sh no servidor (conf_parallel_sane) — e aceita os válidos; e o conf_get/conf_set que o
# menu `moj edit → 8 → 7/8/9` usa faz o ida-e-volta. Sem rede. Guia: mojtools/docs/problema-paralelo.md.
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"; CLI="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj" 2>/dev/null
set +e; set +o pipefail
type parallel_conf_gate >/dev/null 2>&1 || { echo "FAIL: parallel_conf_gate não carregou"; exit 1; }
pass=0; fail=0
ck(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
P="$T/p"; mkdir -p "$P/docs" "$P/tests/input" "$P/tests/output" "$P/sols/good"
printf '# x\n\n## Entrada\n\n## Saída\n' > "$P/docs/enunciado.md"
printf '1\n' > "$P/tests/input/sample1"; printf '1\n' > "$P/tests/output/sample1"; printf 'int main(){}\n' > "$P/sols/good/a.c"
printf '{"id":"o#p","repo":"o","prob":"p","title":"P"}' > "$P/.moj-id"

echo "== gate: chaves ausentes / válidas passam =="
: > "$P/conf"
ck "conf vazio passa"                           'gate "$P" >/dev/null 2>&1'
printf 'CPUNEEDED=4\nSAMENUMA=y\nMAXPARALLELTESTS=2\nALLOWPARALLELTEST=n\n' > "$P/conf"
ck "CPUNEEDED=4 SAMENUMA=y MAXPARALLELTESTS=2 ALLOWPARALLELTEST=n passam" 'gate "$P" >/dev/null 2>&1'
ck "conf_get lê as quatro"                      '[[ "$(conf_get "$P" CPUNEEDED)" == 4 && "$(conf_get "$P" SAMENUMA)" == y && "$(conf_get "$P" MAXPARALLELTESTS)" == 2 && "$(conf_get "$P" ALLOWPARALLELTEST)" == n ]]'

echo "== gate: valores inválidos reprovam (a mesma regra do servidor) =="
printf 'CPUNEEDED=0\n' > "$P/conf";   ck "CPUNEEDED=0 reprova"     '! gate "$P" >/dev/null 2>&1'
printf 'CPUNEEDED=65\n' > "$P/conf";  ck "CPUNEEDED=65 reprova"    '! gate "$P" >/dev/null 2>&1'
printf 'CPUNEEDED=abc\n' > "$P/conf"; ck "CPUNEEDED=abc reprova"   '! gate "$P" >/dev/null 2>&1'
printf 'SAMENUMA=yes\n' > "$P/conf";  ck "SAMENUMA=yes reprova"    '! gate "$P" >/dev/null 2>&1'
printf 'MAXPARALLELTESTS=0\n' > "$P/conf"; ck "MAXPARALLELTESTS=0 reprova" '! gate "$P" >/dev/null 2>&1'
printf 'ALLOWPARALLELTEST=maybe\n' > "$P/conf"; ck "ALLOWPARALLELTEST=maybe reprova" '! gate "$P" >/dev/null 2>&1'
printf 'CPUNEEDED=abc\n' > "$P/conf"
ck "a mensagem diz qual chave"                  '[[ "$(gate "$P" 2>&1 >/dev/null)" == *"CPUNEEDED=abc inválido"* ]]'

echo "== conf_set (o que o menu 7/8/9 grava) =="
: > "$P/conf"
conf_set "$P" CPUNEEDED 8; conf_set "$P" SAMENUMA y; conf_set "$P" MAXPARALLELTESTS 3
ck "gravou as três"                             '[[ "$(conf_get "$P" CPUNEEDED)" == 8 && "$(conf_get "$P" SAMENUMA)" == y && "$(conf_get "$P" MAXPARALLELTESTS)" == 3 ]]'
conf_set "$P" CPUNEEDED ""; conf_set "$P" SAMENUMA ""
ck "vazio remove a linha (default do juiz)"     '! grep -q "^CPUNEEDED=\|^SAMENUMA=" "$P/conf" && grep -q "^MAXPARALLELTESTS=3" "$P/conf"'
ck "gate segue passando"                        'gate "$P" >/dev/null 2>&1'

echo "== moj-judges: subcomando parallel e --parallel-max existem =="
ck "moj-judges parallel no dispatch"            'grep -q "^  parallel) cmd_parallel" "$CLI/moj-judges"'
ck "config aceita --parallel-max"               'grep -q -- "--parallel-max) pmax=" "$CLI/moj-judges"'
ck "ajuda cita os dois"                         'grep -q "moj-judges parallel \[off|auto\]" "$CLI/moj-judges" && grep -q -- "--parallel-max N" "$CLI/moj-judges"'

echo; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
