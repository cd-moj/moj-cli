#!/bin/bash
# docs-publish.sh — `moj-contest docs` diz o que o servidor fez (auditoria do painel, 03/10/2026):
#   • `docs publish … --news` com a notícia NÃO criada avisa (antes passava calado);
#   • caderno publicado antes do início diz que a sede e os times o veem a partir do INÍCIO;
#   • `docs unpublish` diz quantas notícias com o anexo saíram junto;
#   • `docs generate` com a conversão p/ PDF falhando diz qual e que o PDF anterior segue.
# curl FALSO no PATH (molde de test/contest-priority.sh).
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: $(cat "$T/err" "$T/out" 2>/dev/null | head -c 300)"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg" "$T/work"; printf 'tok-dp' > "$T/cfg/token-dp"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; data=""
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; --data-binary) data="$2"; shift 2;;
  -H|-A|-X|--max-time) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
[[ "$data" == @* ]] && cp "${data#@}" "$FAKE/body.json"
[[ "$data" == @- ]] && cat > "$FAKE/body.json"
act="$(jq -r '.action // ""' "$FAKE/body.json" 2>/dev/null)"
case "$act" in
  publish)   body='{"success":true,"ok":true,"published":["contest.pt"],"news":false,"news_removed":0,"available":"at_start"}';;
  unpublish) body='{"success":true,"ok":true,"published":[],"news":false,"news_removed":2,"available":"now"}';;
  generate)  body='{"success":true,"generated":[],"failed":[{"type":"times","lang":"pt","reason":"pdf"}],"counts":{"ok":0,"fail":1}}';;
  *) body='{"success":true}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-contest"; [[ -x "$BIN" ]] || BIN="$CLI/moj-contest"
echo "usando: $BIN"
export FAKE="$T"
run(){ rm -f "$T/body.json"; ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" "$@" </dev/null >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

run -c dp docs publish caderno --news
chk "publish --news: corpo com news:true"               '[[ "$(jq -c "{action,type,news}" "$T/body.json")" == "{\"action\":\"publish\",\"type\":\"contest\",\"news\":true}" ]]'
chk "notícia não criada = aviso"                        'grep -q "notícia NÃO foi criada" "$T/err"'
chk "antes do início: diz que aparece no INÍCIO"        'grep -q "a partir do INÍCIO" "$T/out"'
run -c dp docs unpublish caderno
chk "unpublish: diz as notícias removidas"              'grep -q "2 notícia(s) com o anexo removida(s)" "$T/out" && ! grep -q "NÃO foi criada" "$T/err"'
run -c dp docs generate times
chk "generate: a conversão p/ PDF que falhou é dita"    'grep -q "times.pt — a conversão p/ PDF falhou" "$T/out"'

echo; echo "RESULT: $pass passed, $fail failed"; (( fail == 0 ))
