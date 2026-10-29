#!/bin/bash
# access-refused.sh — `moj-contest -c <cid> access [dia]` (29/10/2026): depois dos logins do dia, as TENTATIVAS
# RECUSADAS (`refused` do /contest/admin/access-log) com hora, login (`?` = conta inexistente), código e IP;
# servidor antigo (sem o campo) ou dia sem recusa = a saída de antes; `--json` devolve o corpo cru, sem a seção.
# curl FALSO no PATH (molde de test/contest-priority.sh).
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: $(cat "$T/err" "$T/out" 2>/dev/null | head -c 300)"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok-ac' > "$T/cfg/token-ac"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D|--data-binary|-H|-A|-X|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
printf '%s\n' "$url" >> "$FAKE/urls"
case "$(cat "$FAKE/mode" 2>/dev/null)" in
  old) body='{"success":true,"day":"2026-10-29","entries":[{"time":1793280000,"login":"t1","ip":"1.1.1.1","user_agent":"ff"}],"alerts":[]}';;
  *)   body='{"success":true,"day":"2026-10-29","entries":[{"time":1793280000,"login":"t1","ip":"1.1.1.1","user_agent":"ff"}],"alerts":[],"refused":[{"time":1793280100,"login":"t1","ip":"2.2.2.2","user_agent":"ff","code":"login_not_open","http":403},{"time":1793280050,"login":"","ip":"3.3.3.3","user_agent":"ff","code":"bad_creds","http":401}]}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
export FAKE="$T"
run(){ rm -f "$T/urls"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" "$@" </dev/null >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

echo "== servidor novo: logins + tentativas recusadas =="
run -c ac access 2026-10-29
chk "rc 0 e a rota do dia"                      '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "/contest/admin/access-log?contest=ac&day=2026-10-29" "$T/urls"'
chk "o login do dia aparece"                    'grep -q "t1 *1.1.1.1" "$T/out"'
chk "seção das recusas, com código e IP"        'grep -q "^tentativas recusadas:" "$T/out" && grep -q "t1 *login_not_open *2.2.2.2" "$T/out"'
chk "conta inexistente sai como ?"              'grep -qE "\? +bad_creds +3.3.3.3" "$T/out"'
echo "== servidor antigo (sem refused): a saída de antes =="
echo old > "$T/mode"; run -c ac access 2026-10-29
chk "rc 0, sem a seção"                         '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "t1" "$T/out" && ! grep -q "recusadas" "$T/out"'
echo "== --json: o corpo cru, sem a seção =="
rm -f "$T/mode"; run --json -c ac access 2026-10-29
chk "JSON válido com refused e sem texto extra" '[[ "$(jq -r ".refused | length" "$T/out")" == 2 ]] && ! grep -q "recusadas" "$T/out"'

echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
