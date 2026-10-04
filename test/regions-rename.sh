#!/bin/bash
# regions-rename.sh — `moj-contest regions set … --rename VELHO=NOVO` (auditoria do painel, 03/10/2026): a sede
# renomeada leva junto o escopo do staff, o gate e o telão (o servidor faz; a CLI manda `renames`) e, depois de
# gravar, a CLI avisa o que ainda aponta p/ sede que não existe (`orphan_refs`). curl FALSO no PATH.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: $(cat "$T/err" "$T/out" 2>/dev/null | head -c 300)"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok-rg' > "$T/cfg/token-rg"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; data=""
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; --data-binary) data="$2"; shift 2;;
  -H|-A|-X|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
[[ "$data" == @* ]] && cp "${data#@}" "$FAKE/body.json"
SUM='{"logins":1,"counts":{"explicit":0,"orphan":0,"regex":1,"stopped":0,"none":0},"nodes":[{"i":0,"name":"Alfa","depth":0,"members":1}],"stopped":[],"none":[]}'
if [[ -n "$data" ]]; then body="{\"success\":true,\"saved\":true,\"sig\":\"s2\",\"summary\":$SUM,\"assigned\":[],\"failed\":[],\"refs_renamed\":2,\"orphan_refs\":[{\"where\":\"ua_gate\",\"name\":\"Velha\"}]}"
else body="{\"success\":true,\"sig\":\"s1\",\"tree\":[],\"mode\":\"\",\"summary\":$SUM}"; fi
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
export FAKE="$T"
run(){ rm -f "$T/body.json"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" "$@" </dev/null >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

printf '[{"name":"Alfa","regex":"^a"}]' > "$T/work/sedes.json"
run -c rg regions set sedes.json --rename A=Alfa --rename "Sede B=Sede Bê"
chk "rc 0; corpo com renames [{A→Alfa},{Sede B→Sede Bê}] e expect_sig" '[[ "$(cat "$T/rc")" == 0 && "$(jq -c ".renames" "$T/body.json")" == "[{\"from\":\"A\",\"to\":\"Alfa\"},{\"from\":\"Sede B\",\"to\":\"Sede Bê\"}]" && "$(jq -r .expect_sig "$T/body.json")" == s1 ]]'
chk "diz quantas configurações acompanharam"            'grep -q "2 configuração(ões) acompanharam" "$T/out"'
chk "avisa a referência órfã (gate, «Velha»)"          'grep -q "gate de navegador «Velha»" "$T/out"'
run -c rg regions set sedes.json
chk "sem --rename: o corpo não leva renames"           '[[ "$(jq -r "has(\"renames\")" "$T/body.json")" == false ]]'
run -c rg regions set sedes.json --rename semigual
chk "--rename sem = morre antes da rede"               '[[ "$(cat "$T/rc")" != 0 && ! -e "$T/body.json" ]]'

echo; echo "RESULT: $pass passed, $fail failed"; (( fail == 0 ))
