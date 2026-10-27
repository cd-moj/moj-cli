#!/bin/bash
# contest-reg-link.sh — `moj-contest -c <cid> inscricoes link [--novo|--revogar]` (27/10/2026): o LINK PRIVADO de
# inscrição de contest SUPER SECRETO (cdmoj lib/registration.sh). Sem opção: GET /contest/admin/registrations e mostra o
# link (ou diz que o contest é comum, que não há link, ou que só o admin o recebe); --novo manda {action:"link-rotate"};
# --revogar manda {action:"link-revoke"}; opção errada morre antes da rede.
# curl FALSO no PATH (molde de test/contest-priority.sh): guarda URL e corpo; a resposta segue o estado em $FAKE/state.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: $(cat "$T/err" "$T/out" 2>/dev/null | head -c 300)"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok-cp' > "$T/cfg/token-cp"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; data=""
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; --data-binary) data="$2"; shift 2;;
  -H|-A|-X|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
[[ "$data" == @- ]] && { cat > "$FAKE/body.json"; data=x; }
[[ "$data" == @* ]] && cp "${data#@}" "$FAKE/body.json"
printf '%s\n' "$url" >> "$FAKE/urls"
L='"url":"https://moj.exemplo/contests/inscricao/?c=cp&k=0123456789abcdef0123456789abcdef"'
st="$(cat "$FAKE/state" 2>/dev/null)"
if [[ -s "$FAKE/body.json" ]]; then grep -q link-revoke "$FAKE/body.json" && st=sem || st=ativo; fi
case "$st" in
  comum) pl='{"secret":false,"active":false,"created_at":0}';;
  sem)   pl='{"secret":true,"active":false,"created_at":0}';;
  chefe) pl='{"secret":true,"active":true,"created_at":1}';;
  *)     pl="{\"secret\":true,\"active\":true,\"created_at\":1,$L}";;
esac
body="{\"success\":true,\"enabled\":true,\"private_link\":$pl}"
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
export FAKE="$T"
run(){ rm -f "$T/body.json" "$T/urls"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" "$@" </dev/null >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

echo "== mostrar o link =="
echo ativo > "$T/state"; run -c cp inscricoes link
chk "link ativo: imprime o link, por GET na rota de inscrições" '[[ "$(cat "$T/rc")" == 0 && "$(cat "$T/out")" == "https://moj.exemplo/contests/inscricao/?c=cp&k=0123456789abcdef0123456789abcdef" && ! -e "$T/body.json" ]] && grep -q "/contest/admin/registrations?contest=cp" "$T/urls"'
echo sem > "$T/state"; run -c cp inscricoes link
chk "sem link: diz que ninguém de fora se inscreve e como gerar" 'grep -q "sem link privado: ninguém de fora consegue se inscrever (gere com: moj-contest inscricoes link --novo)" "$T/out"'
echo comum > "$T/state"; run -c cp inscricoes link
chk "contest comum: aponta o link público"   'grep -q "contest comum: a inscrição é pelo link público https://moj.naquadah.com.br/contests/inscricao/?c=cp" "$T/out"'
echo chefe > "$T/state"; run -c cp inscricoes link
chk "sem o link na resposta (juiz-chefe): diz que só o admin o recebe" 'grep -q "link ativo (só o admin do contest recebe o link)" "$T/out"'

echo "== gerar de novo e revogar =="
echo sem > "$T/state"; run -c cp inscricoes link --novo
chk "--novo manda {action:link-rotate} e imprime o link novo" '[[ "$(cat "$T/rc")" == 0 && "$(jq -c . "$T/body.json")" == "{\"action\":\"link-rotate\"}" && "$(cat "$T/out")" == *"&k=0123456789abcdef0123456789abcdef" ]]'
run -c cp inscricoes link --revogar
chk "--revogar manda {action:link-revoke}"    '[[ "$(cat "$T/rc")" == 0 && "$(jq -c . "$T/body.json")" == "{\"action\":\"link-revoke\"}" ]] && grep -q "sem link privado" "$T/out"'
run -c cp inscricoes link --apaga
chk "opção errada: morre antes da rede"       '[[ "$(cat "$T/rc")" != 0 && ! -s "$T/urls" ]] && grep -q "uso: inscricoes link" "$T/err"'

echo; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
