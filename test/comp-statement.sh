#!/bin/bash
# comp-statement.sh — o moj-comp pega o ENUNCIADO NOS IDIOMAS que a prova oferece (2026-09-15).
#
#   bash test/comp-statement.sh
#
# curl FALSO no PATH (molde de test/ua.sh) devolve /contest/problems com statement_langs por
# problema e /contest/statement?…&lang= canned. Afirma: `statement A` grava A.html (PT) + A.en.html
# (+ A.pdf quando há PDF), `statement A --lang en` só o EN, `--lang es` falha listando os
# disponíveis, `fetch` baixa tudo p/ todos os problemas, e no treino `statement org#slug` grava
# slug.html + slug.en.html de `statements`. Roda no artefato dist/moj-comp se existir, senão no repo.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg/comp-prova" "$T/cfg/comp-treino" "$T/work"
printf 'tok' > "$T/cfg/token-prova"; printf 'tok' > "$T/cfg/token-treino"
# curl falso: acha a URL, o -o e o -w; responde pelo caminho
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; -H|-A|-X|--max-time|--data-binary) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
body=""; code=200
case "$url" in
  */contest/problems*) body='{"success":true,"statement_langs":["pt","en"],"default_statement_lang":"en","problems":[{"short_name":"A","problem_id":"col#pa","full_name":"Alfa","has_statement_html":true,"has_statement_pdf":true,"statement_langs":["pt","en"],"time_limits":{"c":"1"}},{"short_name":"B","problem_id":"col#pb","full_name":"Beta","has_statement_html":true,"has_statement_pdf":false,"statement_langs":["pt"],"time_limits":{}}]}';;
  */contest/statement*problem=A*format=html*lang=en*) body='<html>EN A</html>';;
  */contest/statement*problem=A*format=html*lang=pt*) body='<html>PT A</html>';;
  */contest/statement*problem=A*format=pdf*lang=pt*) body='%PDF-A-PT';;
  */contest/statement*problem=A*format=pdf*lang=en*) body='%PDF-A-EN';;
  */contest/statement*problem=B*format=html*lang=pt*) body='<html>PT B</html>';;
  */contest/statement*) code=404; body='{"success":false,"error":{"code":"statement_notfound"}}';;
  */contest/samples*problem=A*) body='{"success":true,"problem":"A","problem_id":"col#pa","samples":[{"name":"sample1","input":"1 2\n","output":"3\n"},{"name":"sample2","input":"5\n","output":"5\n"}]}';;
  */contest/samples*) body='{"success":true,"problem":"B","problem_id":"col#pb","samples":[]}';;
  */treino/problem?id=*) body="{\"success\":true,\"id\":\"col#pa\",\"title\":\"Eco\",\"samples\":[{\"name\":\"sample1\",\"input\":\"9\\n\",\"output\":\"9\\n\"}],\"statement_langs\":[\"pt\",\"en\"],\"statement_html_b64\":\"$(printf '<html>PT TREINO</html>' | base64 -w0)\",\"statements\":{\"en\":{\"title\":\"Echo\",\"html_b64\":\"$(printf '<html>EN TREINO</html>' | base64 -w0)\"}}}";;
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

echo "== problems: coluna de idiomas =="
run prova problems > "$T/out" || true
chk "lista A com [pt/en] e B com [pt]"   'grep -q "A  Alfa.*\[pt/en\]" "$T/out" && grep -q "B  Beta.*\[pt\]" "$T/out"'
chk "aviso dos idiomas do contest + padrão en" 'grep -q "idiomas do enunciado: pt, en (padrão: en)" "$T/out"'
chk "problems.tsv com a 4ª coluna"       '[[ "$(awk -F"\t" "\$1==\"A\"{print \$4}" "$T/cfg/comp-prova/problems.tsv")" == "pt,en" ]]'

echo "== statement A: todos os idiomas =="
run prova statement A > "$T/out" || true
chk "A.html PT, A.en.html EN, A.pdf, A.en.pdf" '[[ "$(cat "$T/work/A.html")" == "<html>PT A</html>" && "$(cat "$T/work/A.en.html")" == "<html>EN A</html>" && -s "$T/work/A.pdf" && -s "$T/work/A.en.pdf" ]]'
chk "mensagem lista os arquivos"         'grep -q "A.en.html" "$T/out"'
rm -f "$T/work"/A.*
echo "== statement A --lang en: só o EN =="
run prova statement A --lang en > "$T/out" || true
chk "só A.en.html/A.en.pdf"              '[[ -s "$T/work/A.en.html" && ! -e "$T/work/A.html" && ! -e "$T/work/A.pdf" ]]'
echo "== statement A --lang es: erro claro =="
run prova statement A --lang es > "$T/out" || true
chk "rc != 0 e lista os disponíveis"     '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "idiomas disponíveis: pt, en" "$T/err"'
run prova statement A --lang xx > "$T/out" || true
chk "--lang xx recusado"                 '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "aceita pt, en ou es" "$T/err"'
echo "== statement B (só pt): nada de .en =="
rm -f "$T/work"/*; run prova statement B > "$T/out" || true
chk "B.html e nenhum B.en.*"             '[[ -s "$T/work/B.html" && ! -e "$T/work/B.en.html" ]]'

echo "== fetch: kit completo em todos os idiomas =="
rm -f "$T/work"/*; run prova fetch > "$T/out" || true
D="$T/work/prova-prova"
chk "A.html A.en.html A.pdf A.en.pdf B.html" '[[ -s "$D/A.html" && -s "$D/A.en.html" && -s "$D/A.pdf" && -s "$D/A.en.pdf" && -s "$D/B.html" && ! -e "$D/B.en.html" ]]'
chk "problemas.txt com os idiomas"       'grep -q "A	Alfa	pt,en" "$D/problemas.txt"'
chk "mensagem: idiomas pt, en, padrão en" 'grep -q "idiomas: pt, en, padrão en" "$T/out"'

echo "== treino: statement org#slug grava slug.html + slug.en.html =="
rm -rf "$T/work"/*; run treino statement 'col#pa' > "$T/out" || true
chk "pa.html PT e pa.en.html EN"         '[[ "$(cat "$T/work/pa.html")" == "<html>PT TREINO</html>" && "$(cat "$T/work/pa.en.html")" == "<html>EN TREINO</html>" ]]'
rm -rf "$T/work"/*; run treino statement 'col#pa' --lang en > "$T/out" || true
chk "--lang en: só pa.en.html"           '[[ -s "$T/work/pa.en.html" && ! -e "$T/work/pa.html" ]]'
run treino statement 'col#pa' --lang es > "$T/out" || true
chk "--lang es: erro com a lista"        '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "idiomas disponíveis: pt, en" "$T/err"'

echo ""; echo "== samples A: arquivos .in/.out com bytes exatos =="
run prova samples A > "$T/out" || true
chk "samples/A/sample1.in e sample2.out (bytes exatos, com a quebra final)" 'printf "1 2\n" | cmp -s - "$T/work/samples/A/sample1.in" && printf "5\n" | cmp -s - "$T/work/samples/A/sample2.out"'
chk "mensagem: 2 pares em samples/A"       'grep -q "2 par(es) em ./samples/A/" "$T/out"'
echo "== samples B: sem exemplos como arquivo (aviso, rc 0) =="
run prova samples B > "$T/out" || true
chk "rc 0 e aviso"                         '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "sem exemplos como arquivo" "$T/out" && [[ ! -e "$T/work/samples/B/sample1.in" ]]'
echo "== samples --dir =="
run prova samples A --dir "$T/work/ex" > "$T/out" || true
chk "grava na pasta pedida"                '[[ -s "$T/work/ex/A/sample1.out" ]]'
echo "== fetch traz samples/ no kit =="
rm -rf "$T/work/prova-prova"; run prova fetch > "$T/out" || true
chk "kit com samples/A e sem samples/B"    '[[ -s "$T/work/prova-prova/samples/A/sample1.in" && ! -d "$T/work/prova-prova/samples/B" ]]'
chk "resumo cita os exemplos"              'grep -q "exemplos: 2 par(es) em samples/" "$T/out"'
echo "== treino: samples org#slug =="
run treino samples col#pa > "$T/out" || true
chk "samples/pa/sample1.in = 9"            '[[ "$(cat "$T/work/samples/pa/sample1.in")" == 9 ]]'
echo "== help cita samples =="
run prova help > "$T/out" || true
chk "help tem 'samples <letra>'"           'grep -q "samples <letra>" "$T/out"'

echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
