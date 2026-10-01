#!/bin/bash
# esqueletos.sh — `moj-contest -c <cid> esqueletos` (módulo `esqueletos` do cdmoj): ls/show/set/off/reset.
#   • set manda o código por ARQUIVO (--data-binary @arquivo do api_post_file), nunca por argv — inclusive
#     acima de 128 KiB (ARG_MAX), e lê do stdin com --from -;
#   • off/reset mandam a ação certa; show imprime o código, ou "padrão"/"sem esqueleto";
#   • ls diz o estado do módulo e do editor embutido.
# curl FALSO no PATH registra método+URL em $T/calls e o corpo em $T/posts; responde pelo caminho.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok' > "$T/cfg/token-lab1"; printf 'tok' > "$T/cfg/token-treino"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; m=GET
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -X) m="$2"; shift 2;; -D) : > "$2"; shift 2;;
  --data-binary) if [[ "$2" == @- ]]; then cat >> "$POSTS"; else cat "${2#@}" >> "$POSTS"; fi; echo >> "$POSTS"; shift 2;;
  -H|-A|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
echo "$m $url" >> "$CALLS"
body="$(cat "$GET_BODY")"
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
run(){ : > "$T/calls"; : > "$T/posts"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent CALLS="$T/calls" POSTS="$T/posts" GET_BODY="$T/get.json" \
    bash "$BIN" -c lab1 "$@" >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }
printf '%s' '{"success":true,"module_on":true,"editor_on":true,"effective":true,"score_mode":"treino","max_bytes":65536,"langs":{"c":{"mode":"custom","code":"#include <stdio.h>\nint main(){}\n"},"java":{"mode":"off"}}}' > "$T/get.json"

echo "== ls / show =="
run esqueletos
chk "ls: módulo e editor"                      'grep -q "módulo: ligado · editor embutido: ligado" "$T/out"'
chk "ls: c personalizado, java sem esqueleto"  'grep -q "^c .*personalizado (32 bytes)" "$T/out" && grep -q "^java .*sem esqueleto" "$T/out"'
run esqueletos show c
chk "show c: o código"                         'grep -q "int main(){}" "$T/out"'
run esqueletos show py
chk "show py: padrão"                          'grep -q "(py: padrão do MOJ)" "$T/out"'

echo "== set / off / reset =="
printf 'print("oi")\n' > "$T/work/esq.py"
run esqueletos set py --from esq.py
chk "set: POST na rota com action set e o código do arquivo" 'grep -q "^POST .*/contest/admin/esqueletos?contest=lab1" "$T/calls" && [[ "$(jq -c "[.action,.lang,.code]" "$T/posts")" == "[\"set\",\"py\",\"print(\\\"oi\\\")\\n\"]" ]]'
( cd "$T/work" && printf 'int main(){return 0;}\n' | PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent CALLS="$T/calls" POSTS="$T/posts" GET_BODY="$T/get.json" bash "$BIN" -c lab1 esqueletos set cpp --from - >/dev/null 2>&1 )
chk "set --from -: lê do stdin"                '[[ "$(jq -cs "last.code" "$T/posts")" == "\"int main(){return 0;}\\n\"" ]]'
head -c 200000 /dev/zero | tr '\0' 'x' > "$T/work/big.c"
run esqueletos set c --from big.c
chk "set com 200 KB: sem ARG_MAX (o corpo vai por arquivo)" '[[ "$(cat "$T/rc")" == 0 && "$(jq -r ".code|length" "$T/posts")" == 200000 ]]'
run esqueletos off java
chk "off: action off"                          '[[ "$(jq -c "[.action,.lang]" "$T/posts")" == "[\"off\",\"java\"]" ]]'
run esqueletos reset c
chk "reset: action reset"                      '[[ "$(jq -c "[.action,.lang]" "$T/posts")" == "[\"reset\",\"c\"]" ]]'
run esqueletos set py
chk "set sem --from: erro de uso"              '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "uso: esqueletos set" "$T/err"'
run esqueletos zap
chk "sub desconhecido: erro"                   '[[ "$(cat "$T/rc")" != 0 ]]'

echo; echo "RESULT: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
