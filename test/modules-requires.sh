#!/bin/bash
# modules-requires.sh — `moj-contest -c <cid> modules list` mostra (🔒) o pré-requisito que falta e `modules on` repassa a
# recusa do servidor (422 requires_shared_users — inscricoes num contest de contas próprias; relato do Daniel Valle,
# 07/10/2026). curl FALSO no PATH (molde de test/contest-priority.sh).
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: $(cat "$T/err" "$T/out" 2>/dev/null | head -c 300)"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok-treino' > "$T/cfg/token-treino"; printf 'tok-lc' > "$T/cfg/token-lc"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; data=""; code=200
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; --data-binary) data="$2"; shift 2;;
  -H|-A|-X|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
[[ "$data" == @* ]] && cp "${data#@}" "$FAKE/body.json"
[[ "$data" == @- ]] && cat > "$FAKE/body.json"
case "$url" in
  */contest/admin/modules*)
    if [[ -n "$data" ]]; then code=422
      body='{"success":false,"error":{"message":"A inscrição usa as contas do Treino Livre (cada aluno se inscreve com a conta dele no treino), e este contest tem contas próprias","code":"requires_shared_users"}}'
    else body='{"success":true,"modules":[{"id":"sedes","on":true,"detected":true,"reason":"regions.json","requires":{"ok":true}},{"id":"inscricoes","on":false,"detected":false,"reason":"","requires":{"ok":false,"code":"requires_shared_users","message":"x"}}],"enabled":["sedes"]}'; fi;;
  *) body='{"success":true}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '%s' "$code"
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
export FAKE="$T"
run(){ rm -f "$T/body.json"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" "$@" </dev/null >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

run -c lc modules list
chk "list: inscricoes com 🔒 e o que falta; sedes sem cadeado" '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "inscricoes.*🔒 precisa das contas do treino" "$T/out" && ! grep -q "sedes.*🔒" "$T/out"'
run -c lc modules on inscricoes
chk "on: a recusa do servidor chega (rc≠0 e a mensagem)" '[[ "$(cat "$T/rc")" != 0 ]] && grep -q "contas do Treino Livre" "$T/err" "$T/out"'
echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
