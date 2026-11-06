#!/bin/bash
# argmax.sh — CONTEÚDO DE ARQUIVO NUNCA ANDA POR ARGV DO jq.
#
#   bash test/argmax.sh
#
# POR QUE EXISTE: em agosto/2026 o `moj-contest docs upload caderno <pdf>` morreu na cara do
# usuário com `/usr/bin/jq: Argument list too long`. O corpo era montado com
# `--arg b "$(_b64enc "$file")"` — o base64 inteiro no argumento — e o Linux limita **um**
# argumento a 128 KiB (MAX_ARG_STRLEN). Um caderno de 500 KB vira 665 KB em base64: nem chega
# perto de caber. O `moj` e o `moj-comp` já tinham aprendido isso (usam `--rawfile`); o
# `moj-contest` tinha três pontos que não.
#
# O teste tem duas metades, e as duas importam:
#   1. FUNCIONAL — roda os MESMOS programas jq dos três pontos com uma carga bem acima do teto.
#      Com o código antigo isto falha de verdade (não é simulação).
#   2. INVENTÁRIO — proíbe o padrão de voltar por outra porta, em qualquer CLI da família.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }

source "$CLI/lib/core.sh" 2>/dev/null || true
type _b64tmp >/dev/null 2>&1 || { echo "FAIL: falta o helper _b64tmp em lib/core.sh"; exit 1; }

# 600 KB -> ~800 KB de base64: 6× o teto de 128 KiB de um argumento
head -c 600000 /dev/urandom > "$T/grande.pdf"
b64="$(_b64tmp "$T/grande.pdf")"
chk "_b64tmp gera o arquivo"        '[[ -s "$b64" ]]'
chk "base64 passa dos 128 KiB"      '(( $(stat -c%s "$b64" 2>/dev/null || wc -c < "$b64") > 131072 ))'

echo "== os três corpos do moj-contest, com carga acima do teto =="
# docs upload
jq -cn --arg t contest --arg l en --rawfile b "$b64" \
  '{action:"upload",type:$t,lang:$l,pdf_b64:($b|rtrimstr("\n"))}' > "$T/up.json" 2>"$T/up.err"
chk "docs upload: jq monta o corpo"  '[[ -s "$T/up.json" && ! -s "$T/up.err" ]]'
chk "docs upload: base64 chegou inteiro" \
  '[[ "$(jq -r .pdf_b64 "$T/up.json" | wc -c)" -eq "$(( $(wc -c < "$b64") + 1 ))" ]]'
chk "docs upload: round-trip do PDF" \
  'jq -r .pdf_b64 "$T/up.json" | _b64dec > "$T/rt.pdf"; cmp -s "$T/grande.pdf" "$T/rt.pdf"'

# docs cover
jq -cn --arg l pt --rawfile b "$b64" '{action:"cover",lang:$l,pdf_b64:($b|rtrimstr("\n"))}' \
  > "$T/cv.json" 2>"$T/cv.err"
chk "docs cover: jq monta o corpo"   '[[ -s "$T/cv.json" && ! -s "$T/cv.err" ]]'

# docs text --from <arquivo> (markdown com imagem colada em data:URI passa fácil do teto)
{ printf '# Capa\n\n![](data:image/png;base64,'; cat "$b64"; printf ')\n'; } > "$T/capa.md"
jq -cn --arg k cover_pt --rawfile v "$T/capa.md" '{action:"config"} + {($k):($v|rtrimstr("\n"))}' \
  > "$T/tx.json" 2>"$T/tx.err"
chk "docs text: jq monta o corpo"    '[[ -s "$T/tx.json" && ! -s "$T/tx.err" ]]'
chk "docs text: texto chegou inteiro" \
  '[[ "$(jq -r ".cover_pt" "$T/tx.json" | wc -c)" -eq "$(wc -c < "$T/capa.md")" ]]'

echo "== respostas grandes da API e arquivos grandes: o jq recebe pelo stdin/arquivo (06/11/2026) =="
# Relato: "acho que quebramos moj-cli por ter soluções demais" — o `moj check --json` juntava as 4 respostas com
# `--argjson`, e o /problems/calib de um problema com muitas soluções × testes passa dos 128 KiB de UM argumento.
# Roda as funções REAIS (MOJ_CLI_LIB_ONLY=1), num subshell cada (o `moj` liga set -e).
NS=3000   # ~3000 soluções no calib ≈ 400 KB
jq -cn --argjson n "$NS" '{success:true, id:"col#pa", sols:[range($n) | {file:"s\(.).cpp", lang:"cpp", category:"good",
  verdict:"Accepted,100p", tests:[range(4) | {name:"t\(.)", code:"AC", time:0.01}]}]}' > "$T/calib.json"
chk "o calib de teste passa dos 128 KiB"   '(( $(wc -c < "$T/calib.json") > 131072 ))'
( MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj" 2>/dev/null; set +e; set +o pipefail
  need_login(){ :; }; RAW=1
  api(){ case "$2" in /problems/calib*) cat "$T/calib.json";; /problems/status*) echo '{"problems":[{"ready":true}]}';;
         *) echo '{"ok":true}';; esac; }
  cmd_check 'col#pa' > "$T/check.json" 2>"$T/check.err" )
chk "moj check --json: sem 'Argument list too long'" '! grep -q "Argument list" "$T/check.err"'
chk "moj check --json: o calib chega inteiro"        '[[ "$(jq ".calib.sols | length" "$T/check.json" 2>/dev/null)" == "$NS" ]]'
chk "moj check --json: o status é o 1º problema"     '[[ "$(jq -c .status "$T/check.json" 2>/dev/null)" == "{\"ready\":true}" ]]'
# pkg_to_json: o conf é conteúdo de ARQUIVO (TLOVERRIDE/TLMOD/comentários o fazem crescer)
P="$T/pkg"; mkdir -p "$P/docs" "$P/tests/input" "$P/tests/output" "$P/sols/good"
printf '# x\n\n## Entrada\n\n## Saída\n' > "$P/docs/enunciado.md"; echo autor > "$P/author"
printf '1\n' > "$P/tests/input/sample1"; printf '1\n' > "$P/tests/output/sample1"; printf 'int main(){}\n' > "$P/sols/good/a.c"
printf '{"id":"o#p","repo":"o","prob":"p","title":"P"}' > "$P/.moj-id"
{ echo 'CALIBRATIONTL=5'; for i in $(seq 1 4000); do echo "# linha de comentário $i do conf, com texto p/ engordar o arquivo"; done; } > "$P/conf"
chk "o conf de teste passa dos 128 KiB"    '(( $(wc -c < "$P/conf") > 131072 ))'
( MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj" 2>/dev/null; set +e; set +o pipefail
  pkg_to_json "$P" > "$T/pkg.json" 2>"$T/pkg.err" )
chk "pkg_to_json: sem 'Argument list too long'"      '! grep -q "Argument list" "$T/pkg.err"'
chk "pkg_to_json: o conf chega inteiro"              '[[ "$(jq -j .conf_text "$T/pkg.json" 2>/dev/null | wc -c)" == "$(wc -c < "$P/conf")" ]]'
rm -f "$P/conf"
( MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj" 2>/dev/null; set +e; set +o pipefail
  pkg_to_json "$P" > "$T/pkg0.json" 2>/dev/null )
chk "pkg_to_json: sem conf = \"\" (como antes)"       '[[ "$(jq -c .conf_text "$T/pkg0.json" 2>/dev/null)" == "\"\"" ]]'
# moj-contest create --template: o spec do template (esqueletos somam centenas de KB) mesclado ao spec
jq -cn '{duration:7200, login_lead:600, freeze_before_end:3600, mode:"icpc",
  modules:{esqueletos:{langs:{cpp:{mode:"custom", code:([range(9000)] | map("// linha de esqueleto") | join("\n"))}}}}}' > "$T/tpl.json"
chk "o template de teste passa dos 128 KiB" '(( $(wc -c < "$T/tpl.json") > 131072 ))'
( MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj-contest" 2>/dev/null; set +e; set +o pipefail
  _tpl_merge "$(cat "$T/tpl.json")" '{"name":"Prova","id":"p1"}' 1000000 > "$T/merged.json" 2>"$T/merged.err" )
chk "_tpl_merge: sem 'Argument list too long'"       '! grep -q "Argument list" "$T/merged.err"'
chk "_tpl_merge: absolutiza e mescla (start/end/login_start/freeze, spec por cima)" \
  '[[ "$(jq -c "[.start, .end, .login_start, .freeze, .name, .id, has(\"duration\")]" "$T/merged.json" 2>/dev/null)" == "[1000000,1007200,999400,1003600,\"Prova\",\"p1\",false]" ]]'
chk "_tpl_merge: o módulo grande chega inteiro"      '[[ "$(jq -r ".modules.esqueletos.langs.cpp.code" "$T/merged.json" 2>/dev/null | wc -l)" == 9000 ]]'

echo "== o padrão proibido não volta por outra porta =="
# RESPOSTA CRUA DA API nunca vai por argv do jq: a variável que recebe `$(api …)`/`$(api_t …)` INTEIRA (sem `| jq` na
# mesma atribuição — aí já é um pedaço pequeno) não pode aparecer como `--arg X "$var"`/`--argjson X "$var"` no mesmo
# executável; use o stdin (`<<<"$var"`, `printf … | jq -s`) ou um arquivo. Comentário não conta. Os nomes se repetem
# entre funções ($t, $end…), por isso só a resposta crua entra na lista.
apiv=""
for f in moj moj-contest moj-comp moj-judges; do
  for v in $(cd "$CLI" && awk 'match($0, /[a-z_][a-z0-9_]*="\$\((api|api_t) /) && index(substr($0, RSTART), "|") == 0 {
                 v = substr($0, RSTART, RLENGTH); sub(/=.*/, "", v); print v }' "$f" | sort -u); do
    hit="$(cd "$CLI" && grep -nE -- "--arg(json)?[[:space:]]+[A-Za-z_]+[[:space:]]+\"\\\$$v\"" "$f" | grep -vE '^[0-9]+:[[:space:]]*#')"
    [[ -n "$hit" ]] && apiv+="$f: \$$v → $hit"$'\n'
  done
done
[[ -z "$apiv" ]] || printf '%s' "$apiv" | sed 's/^/     /'
chk "nenhuma resposta da API por --arg/--argjson" '[[ -z "$apiv" ]]'

# `--arg x "$(...)"` cujo valor vem de ARQUIVO é o que estoura. Assinaturas conhecidas:
# _b64enc, cat, base64, xxd — e a variável que acabou de receber um `$(cat …)`.
achados="$(cd "$CLI" && grep -nE -- '--arg(json)?[[:space:]]+[A-Za-z_]+[[:space:]]+"\$\((_b64enc|cat |base64|xxd|slurp |api |api_t )' \
             moj moj-contest moj-comp moj-judges lib/*.sh 2>/dev/null)"
[[ -z "$achados" ]] || printf '%s\n' "$achados" | sed 's/^/     /'
chk "nenhum --arg alimentado por arquivo" '[[ -z "$achados" ]]'
rm -f "$b64"

echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
