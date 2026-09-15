#!/bin/bash
# translations.sh — ENUNCIADO EM VÁRIOS IDIOMAS no round-trip da CLI (2026-09-15).
#
#   bash test/translations.sh
#
# pkg_to_json lê docs/enunciado.<lang>.md, docs/solucao.<lang>.md, docs/notes/<sample>.<lang>.md e
# o `titles` do .moj-id e manda `translations{<lang>}` (+ `titles`); json_to_pkg faz o caminho de
# volta byte a byte. Clone ciente (trans_rt) manda `null` p/ idioma sem arquivo (apaga no servidor);
# clone antigo sem tradução não manda o campo (não apaga a tradução de ninguém). Sem rede: as
# funções são carregadas com MOJ_CLI_LIB_ONLY=1.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
# carrega as funções do moj sem rodar o dispatch
MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj" 2>/dev/null
set +e; set +o pipefail   # o moj liga -euo pipefail; o teste conta falhas, não morre nelas
type pkg_to_json >/dev/null 2>&1 || { echo "FAIL: pkg_to_json não carregou (MOJ_CLI_LIB_ONLY)"; exit 1; }

P="$T/p"; mkdir -p "$P/docs/notes" "$P/tests/input" "$P/tests/output" "$P/sols/good"
printf 'Leia N.\n\n## Entrada\n\nx\n\n## Saída\n\ny\n' > "$P/docs/enunciado.md"
printf 'Read N.\n\n## Input\n\nx\n\n## Output\n\ny\n' > "$P/docs/enunciado.en.md"
printf '# Idea\n\nprint\n' > "$P/docs/solucao.en.md"
printf '1\n' > "$P/tests/input/sample1"; printf '1\n' > "$P/tests/output/sample1"
printf '2\n' > "$P/tests/input/sample2"; printf '2\n' > "$P/tests/output/sample2"
printf 'nota pt 1\n' > "$P/docs/notes/sample1.md"; printf 'note en 1\n' > "$P/docs/notes/sample1.en.md"
printf 'note en 2\n' > "$P/docs/notes/sample2.en.md"
printf 'a\n' > "$P/author"; printf '#x\n' > "$P/tags"; printf 'x=1\n' > "$P/conf"; printf 'int main(){}\n' > "$P/sols/good/a.c"
printf '{"id":"col#p","repo":"col","prob":"p","title":"Eco","titles":{"en":"Echo"},"format":"md","collections":[],"languages":[],"public":false,"scripts_rt":true,"docs_rt":true,"trans_rt":true}' > "$P/.moj-id"

echo "== pkg_to_json: translations + titles =="
J="$(pkg_to_json "$P")"
chk "translations.en com título/enunciado/editorial/notas" '[[ "$(jq -r ".translations.en | .title, .enunciado_md, .editorial_md, .notes.sample1, .notes.sample2" <<<"$J" | tr "\n" "|")" == "Echo|Read N."*"|# Idea"*"|note en 1|note en 2|" ]]'
chk "es sem arquivo = null (clone ciente apaga)" '[[ "$(jq -c ".translations.es" <<<"$J")" == null ]]'
chk "titles do .moj-id"                          '[[ "$(jq -c .titles <<<"$J")" == "{\"en\":\"Echo\"}" ]]'
chk "PT segue nos campos de sempre"             '[[ "$(jq -r ".enunciado_md" <<<"$J")" == "Leia N."* && "$(jq -r ".examples[0].explanation" <<<"$J")" == "nota pt 1" ]]'
chk "enunciado.en.md byte-fiel"                  '[[ "$(jq -r ".translations.en.enunciado_md" <<<"$J")" == "$(cat "$P/docs/enunciado.en.md")" ]]'

echo "== clone antigo (sem trans_rt, sem tradução local): NÃO manda translations =="
Q="$T/q"; cp -r "$P" "$Q"; rm -f "$Q/docs/enunciado.en.md" "$Q/docs/solucao.en.md" "$Q/docs/notes"/*.en.md
jq 'del(.trans_rt) | del(.titles)' "$P/.moj-id" > "$Q/.moj-id"
chk "sem campo translations"                     '! jq -e "has(\"translations\")" <<<"$(pkg_to_json "$Q")" >/dev/null'
echo "== clone antigo COM tradução local manda só o que tem (NUNCA null p/ os outros idiomas) =="
printf 'Lea N.\n\n## Entrada\n\nx\n\n## Salida\n\ny\n' > "$Q/docs/enunciado.es.md"
J2="$(pkg_to_json "$Q")"
chk "es presente e en AUSENTE (não apaga o en do servidor)" '[[ "$(jq -r ".translations.es.enunciado_md" <<<"$J2")" == "Lea N."* ]] && ! jq -e ".translations | has(\"en\")" <<<"$J2" >/dev/null'

echo "== json_to_pkg: o caminho de volta =="
R="$T/r"; printf '%s' "$J" | jq '. + {title:"Eco", format:"md"}' > "$T/src.json"
json_to_pkg "$T/src.json" "$R" "col#p"
chk "enunciado.en.md igual"                      'cmp -s "$P/docs/enunciado.en.md" "$R/docs/enunciado.en.md"'
chk "solucao.en.md igual (sem \\n final extra)" '[[ "$(cat "$R/docs/solucao.en.md")" == "$(cat "$P/docs/solucao.en.md")" ]]'
chk "notas en gravadas; nota pt gravada"         '[[ -f "$R/docs/notes/sample1.en.md" && -f "$R/docs/notes/sample2.en.md" && -f "$R/docs/notes/sample1.md" && "$(cat "$R/docs/notes/sample2.en.md")" == "note en 2" ]]'
chk "sem arquivo es"                             '[[ ! -f "$R/docs/enunciado.es.md" ]]'
chk ".moj-id com titles e trans_rt"              '[[ "$(jq -c ".titles, .trans_rt" "$R/.moj-id" | paste -sd" ")" == "{\"en\":\"Echo\"} true" ]]'
echo "== round-trip: pkg_to_json do clone == do original =="
chk "translations idênticas"                     '[[ "$(pkg_to_json "$R" | jq -cS .translations)" == "$(jq -cS .translations <<<"$J")" ]]'

echo "== moj title --lang =="
( cd "$T" && MOJ_CONFIG_DIR="$T/cfg" bash "$CLI/moj" title "$R" --lang es "Eco ES" >/dev/null 2>&1 )
chk "titles.es gravado"                          '[[ "$(jq -r .titles.es "$R/.moj-id")" == "Eco ES" ]]'
chk "sem arg mostra"                             'MOJ_CONFIG_DIR="$T/cfg" bash "$CLI/moj" title "$R" 2>/dev/null | grep -q "título (es): Eco ES"'

echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
