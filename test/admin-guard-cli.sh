#!/bin/bash
# admin-guard-cli.sh — as CLIs diante das guardas do painel do treino (16/10/2026):
#   · `moj-contest remove` manda o id digitado no corpo (`confirm`) — o servidor passou a exigi-lo — e mostra a
#     lixeira que a resposta traz;
#   · `moj-judges config` de quem não é super-admin sai com erro e a mensagem do servidor (403 superadmin_required).
# curl FALSO no PATH (molde de test/comp-submit-busy.sh). Roda nos artefatos dist/ se existirem.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: rc=$(cat "$T/rc") out=$(head -c 200 "$T/out") err=$(head -c 200 "$T/err")"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg"; printf 'tok' > "$T/cfg/token"; printf 'tok' > "$T/cfg/token-treino"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; data=""; method=GET
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; -X) method="$2"; shift 2;;
  --data-binary) data="$2"; shift 2;; -H|-A|--max-time|-d) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
[[ "$data" == @- ]] && data="$(cat)"
printf '%s %s %s\n' "$method" "${url#*/api/v1}" "$data" >> "$FAKE_LOG"
code=200
case "$url" in
  */treino/admin/contest-remove*) body='{"success":true,"removed":true,"contest":"lab1","trash":".trash/lab1-1792100000"}';;
  */ops/judge-config*) if [[ "$method" == POST ]]; then code=403; body='{"success":false,"error":{"message":"Só o super-admin da plataforma pode fazer isto","code":"superadmin_required"}}'; else body='{"success":true,"configs":{}}'; fi;;
  *) body='{"success":true}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '%s' "$code"
exit 0
CURL
chmod +x "$T/bin/curl"
bin(){ local b="$CLI/dist/$1"; [[ -x "$b" ]] || b="$CLI/$1"; printf '%s' "$b"; }
run(){ local tool="$1"; shift; : > "$T/log"
  ( PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_URL=http://fake FAKE_LOG="$T/log" bash "$(bin "$tool")" "$@" <"$T/in" >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }
echo "usando: $(bin moj-contest) e $(bin moj-judges)"

printf 'lab1\n' > "$T/in"; run moj-contest remove lab1
chk "remove: manda confirm = o id digitado" 'grep -q "contest-remove {\"contest\":\"lab1\",\"confirm\":\"lab1\"}" "$T/log"'
chk "remove: mostra a lixeira que o servidor devolveu" '[[ $(cat "$T/rc") == 0 ]] && grep -q ".trash/lab1-1792100000" "$T/out"'
printf 'outro\n' > "$T/in"; run moj-contest remove lab1
chk "remove: id digitado errado não chama o servidor" '[[ $(cat "$T/rc") != 0 ]] && ! grep -q contest-remove "$T/log"'

: > "$T/in"; run moj-judges config j1 --reserve 1
chk "moj-judges config (não super): sai com erro e a mensagem do servidor" '[[ $(cat "$T/rc") != 0 ]] && grep -q "super-admin" "$T/err"'

echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
