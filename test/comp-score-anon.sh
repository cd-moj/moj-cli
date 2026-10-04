#!/bin/bash
# comp-score-anon.sh — `moj-comp score` num contest de placar ANÔNIMO (03/10/2026): a API manda ao competidor só o
# agregado (JSON, nenhum nome nem nota); a CLI mostra o resumo em vez de despejar o JSON como se fosse o placar.
# curl FALSO no PATH (molde de test/comp-submit-busy.sh). Roda no artefato dist/moj-comp se existir.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: $(head -c 300 "$T/out") $(head -c 200 "$T/err")"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg/comp-prova" "$T/work"; printf 'tok' > "$T/cfg/token-prova"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; -H|-A|-X|--max-time|--data-binary) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
case "$url" in
  */contest/score*) body="$(cat "$FAKE/score")";;
  */contest/beacon*) body='{"success":true,"server_utc":1,"beacon":"x"}';;
  *) body='{"success":true}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '200'
exit 0
CURL
chmod +x "$T/bin/curl"; export FAKE="$T"
BIN="$CLI/dist/moj-comp"; [[ -x "$BIN" ]] || BIN="$CLI/moj-comp"
echo "usando: $BIN"
run(){ ( cd "$T/work" && PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" -c prova score >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }

printf '{"anon":true,"mode":"icpc","n":5,"guests":0,"frozen":true,"supported":true,"problems":["A","B"],"per_problem":{"A":3,"B":1},"dist":{"0":2,"1":2,"2":1},"q":{"p25":1,"median":1,"p75":0,"max":2}}' > "$T/score"
run
chk "anônimo: rc 0 e o resumo (participantes, por problema, quartis, congelado)" '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "placar anônimo" "$T/out" && grep -q "participantes: 5" "$T/out" && grep -q "A=3 B=1" "$T/out" && grep -q "máximo 2" "$T/out" && grep -q "congelado" "$T/out"'
chk "…e não despeja o JSON"                     '! grep -q "{" "$T/out"'
printf 'icpc s\ndesc:asc:flag:username:univ short:team name:univ full:A:Total:Penalty:LastAC\nbr:t1:U:Time 1:Univ:1/600:1:10:10\n' > "$T/score"
run
chk "placar normal: segue o TXT (minutos)"      '[[ "$(cat "$T/rc")" == 0 ]] && grep -q "t1:U:Time 1:Univ:1/10" "$T/out"'

echo ""; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
