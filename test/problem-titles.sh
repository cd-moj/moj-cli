#!/bin/bash
# problem-titles.sh — `moj-contest problems titles [<letra>]` e `problems apply-titles [<letra>…]` (03/10/2026).
# O nome do problema no contest segue o idioma da prova; `titles` lista os títulos PT/EN/ES que o servidor
# devolve (GET /contest/admin/problems: `titles` + `name_lang`) e `apply-titles` é o botão da Central
# (POST {action:"apply_titles", letters?}). curl FALSO no PATH registra método+URL e o corpo dos POSTs.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok' > "$T/cfg/token-lab1"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; m=GET
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -X) m="$2"; shift 2;; -D) : > "$2"; shift 2;;
  --data-binary) if [[ "$2" == @- ]]; then cat >> "$POSTS"; else cat "${2#@}" >> "$POSTS"; fi; echo >> "$POSTS"; shift 2;; -H|-A|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
echo "$m $url" >> "$CALLS"
if [[ "$m" == POST ]]; then
  body='{"success":true,"saved":true,"changed":[{"letter":"A","name":"Corrida de Robôs","to":"Carrera de Robots","lang":"es"}],"problems":[]}'
else
  body='{"success":true,"name_lang":"es","problems":[
    {"letter":"A","name":"Corrida de Robôs","problem_id":"org#tri","titles":{"pt":"Corrida de Robôs","en":"Robot Race","es":"Carrera de Robots"}},
    {"letter":"B","name":"Soma","problem_id":"org#mono"}]}'
fi
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
run(){ : > "$T/calls"; : > "$T/posts"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent CALLS="$T/calls" POSTS="$T/posts" \
    bash "$BIN" -c lab1 "$@" >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

echo "== titles =="
run problems titles
chk "rc 0 e GET em /contest/admin/problems" '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "GET .*/contest/admin/problems" "$T/calls"'
chk "A lista PT/EN/ES, marca o atual (←) e o idioma da prova (*)" 'grep "^A" "$T/out" | grep -q "PT: Corrida de Robôs ←" && grep "^A" "$T/out" | grep -q "ES: Carrera de Robots \*"'
chk "B sem tradução: um título só" 'grep "^B" "$T/out" | grep -q "um título só"'
chk "stderr diz o idioma da prova e como trocar" 'grep -q "idioma da prova (nome padrão): ES" "$T/err" && grep -q "problems rename" "$T/err"'
run problems titles B
chk "titles <letra>: só aquela" '! grep -q "^A" "$T/out" && grep -q "^B" "$T/out"'
run problems titles Z
chk "letra que não existe: erro" '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "não está no contest" "$T/err"'
echo "== apply-titles =="
run problems apply-titles
chk "POST apply_titles sem letras" '[[ "$(jq -c . "$T/posts")" == "{\"action\":\"apply_titles\"}" ]]'
chk "mostra o que trocou" 'grep -q "A: Corrida de Robôs → Carrera de Robots" "$T/out"'
run problems apply-titles A C
chk "com letras: letters no corpo" '[[ "$(jq -c .letters "$T/posts")" == "[\"A\",\"C\"]" ]]'

echo; echo "RESULT: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
