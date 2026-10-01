#!/bin/bash
# function-langs.sh — FUNCTION_LANGS no pré-voo do `moj` (function_conf_gate, a MESMA regra do
# validate-problem.sh `conf_function_sane`): linguagem listada precisa de scripts/<lang>/compile.sh;
# ids canônicos (py3 → py); comentário e aspas fora; sem a linha, nada a conferir. Sem rede.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
MOJ_CONFIG_DIR="$T/cfg" MOJ_CLI_LIB_ONLY=1 source "$CLI/moj" 2>/dev/null
set +e
pass=0; fail=0
ck(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: ${DBG:-}"; ((fail++)); fi; }
P="$T/p"; mkdir -p "$P/scripts/c" "$P/scripts/py3"; : > "$P/scripts/c/compile.sh"; : > "$P/scripts/py3/compile.sh"
g(){ printf '%s\n' "$1" > "$P/conf"; DBG="$(function_conf_gate "$P" 2>&1)"; RC=$?; }
g 'CALIBRATIONTL=5';                 ck "sem a linha: passa"                         '[[ $RC == 0 && -z "$DBG" ]]'
g 'FUNCTION_LANGS=c,py';             ck "c,py com driver (py3 → py): passa"          '[[ $RC == 0 ]]'
g 'FUNCTION_LANGS="C, PY3"';         ck "aspas, caixa e espaço: passa"               '[[ $RC == 0 ]]'
g 'FUNCTION_LANGS=c,java';           ck "java sem compile.sh: reprova e diz qual"   '[[ $RC != 0 && "$DBG" == *"falta scripts/java/compile.sh"* ]]'
g 'FUNCTION_LANGS=c,x$y';            ck "id inválido: reprova"                       '[[ $RC != 0 && "$DBG" == *"não é id de linguagem"* ]]'
g 'FUNCTION_LANGS=c # comentário';   ck "comentário fora: passa"                     '[[ $RC == 0 ]]'
g 'FUNCTION_LANGS=*';                ck "glob não expande: reprova como id inválido" '[[ $RC != 0 && "$DBG" == *"'"'"'*'"'"'"* ]]'
ck "o pré-voo (gate) chama a conferência" 'grep -q "function_conf_gate \"\$d\" || ok=0" "$CLI/moj"'
echo; echo "RESULT: $pass passed, $fail failed"; exit $(( fail > 0 ? 1 : 0 ))
