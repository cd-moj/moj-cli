#!/bin/bash
# judges-width.sh — a LARGURA de um job em execução no `moj-judges show` (JQ_JOB_WIDTH, lib/core.sh).
# Relato de 30/09/2026: "[4 slots, 4 cpu/teste]" parecia 4 testes em paralelo; era 1 teste com as 4 CPUs
# juntas (CPUNEEDED=4). Agora sai "slots = testes por vez × slots por teste". Sem rede.
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"; CLI="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
MOJ_CONFIG_DIR="$T/cfg" source "$CLI/lib/core.sh" 2>/dev/null
set +e
pass=0; fail=0
ck(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: ${DBG:-}"; ((fail++)); fi; }
w(){ jq -r "$JQ_JOB_WIDTH"' jobwidth' <<<"$1"; }

DBG="$(w '{"slots":4,"test_cpus":4,"par_max":1,"same_numa":true,"cpu_needed":4}')"
ck "CPUNEEDED=4, 1 teste por vez: 4 slots = 1 teste × 4 slots (4 CPUs juntas, mesmo nó)" '[[ "$DBG" == " [4 slots = 1 teste por vez × 4 slots (4 CPUs juntas, mesmo nó NUMA)]" ]]'
DBG="$(w '{"slots":8,"test_cpus":4,"par_max":2}')"
ck "2 testes em paralelo de 4 CPUs: 8 slots = 2 × 4" '[[ "$DBG" == " [8 slots = 2 testes em paralelo × 4 slots por teste (4 CPUs cada)]" ]]'
DBG="$(w '{"slots":1,"test_cpus":1,"par_max":1}')"
ck "job de 1 slot: nada"                         '[[ -z "$DBG" ]]'
DBG="$(w '{"slots":3,"test_cpus":3,"par_max":1,"cpu_needed":1}')"
ck "largura pela MEMÓRIA: diz o CPUNEEDED e as CPUs a mais" '[[ "$DBG" == *"3 slots = 1 teste por vez"* && "$DBG" == *"CPUNEEDED=1; +2 CPU(s) pela memória"* ]]'
DBG="$(w '{"slots":4,"test_cpus":4}')"
ck "servidor antigo (sem par_max/cpu_needed): 1 teste por vez, sem a parte da memória" '[[ "$DBG" == " [4 slots = 1 teste por vez × 4 slots (4 CPUs juntas)]" ]]'
ck "o show usa o jobwidth (e diz a política geral)" 'grep -q "+ jobwidth" "$CLI/moj-judges" && grep -q "paralelo:  " "$CLI/moj-judges"'

echo; echo "RESULT: $pass passed, $fail failed"; exit $(( fail > 0 ? 1 : 0 ))
