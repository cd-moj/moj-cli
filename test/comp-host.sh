#!/bin/bash
# comp-host.sh — o moj-comp fala com o ENDEREÇO DO CONTEST (16/10/2026): o servidor recusa sessão de time fora do
# subdomínio do contest (403 host_required), então a prova vai p/ https://<cid>.moj… e o treino fica no site principal.
#   · `login <cid>` e os comandos seguintes (a última prova gravada) → o subdomínio;
#   · `login treino` → o site principal; `login <url>` (subdomínio ou ?c=) → o contest certo;
#   · URL de OUTRO servidor é recusada (a senha iria p/ ela);
#   · MOJ_HOST de teste (MOJ_URL=http://127.0.0.1…): a URL fica e o Host vira <cid>.<MOJ_HOST>;
#   · o host_required de um servidor mostra o endereço certo; `moj-contest seed --live` loga os times no subdomínio.
# curl FALSO no PATH (molde de test/admin-guard-cli.sh). Roda nos artefatos dist/ se existirem.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1 :: rc=$(cat "$T/rc") log=$(head -c 300 "$T/log") err=$(head -c 200 "$T/err")"; ((fail++)); fi; }
mkdir -p "$T/bin"
cat > "$T/bin/curl" <<'CURL'
#!/bin/bash
out=""; url=""; want_code=0; method=GET; host=""
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2;; -w) want_code=1; shift 2;; -D) shift 2;; -X) method="$2"; shift 2;;
  -H) [[ "$2" == Host:* ]] && host="${2#Host: }"; shift 2;; --data-binary|-A|--max-time|-d) shift 2;; http*) url="$1"; shift;; *) shift;; esac; done
[[ -p /dev/stdin ]] && cat >/dev/null
printf '%s %s host=%s\n' "$method" "${url%%\?*}" "${host:--}" >> "$FAKE_LOG"
code=200
case "$url" in
  */auth/login*) body='{"success":true,"logged_in":true,"token":"tk1"}';;
  */auth/status*) body='{"success":true,"logged_in":true,"login":"t1"}';;
  */contest/news*) if [[ -n "${FAKE_HOSTREQ:-}" ]]; then code=403; body='{"success":false,"error":{"message":"Os times deste contest só entram pelo endereço dele","code":"host_required","url":"https://pv.moj.naquadah.com.br/contest/"}}'; else body='{"success":true,"news":[]}'; fi;;
  */contest/admin/seed*) body='{"success":true,"teams_created":0,"submissions":0,"board_lines":0,"by_verdict":{},"password":"pw"}';;
  *) body='{"success":true,"status":"ok"}';;
esac
if [[ -n "$out" ]]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
(( want_code )) && printf '%s' "$code"
exit 0
CURL
chmod +x "$T/bin/curl"
bin(){ local b="$CLI/dist/$1"; [[ -x "$b" ]] || b="$CLI/$1"; printf '%s' "$b"; }
run(){ local tool="$1"; shift; : > "$T/log"
  ( PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_URL="${URL:-https://moj.naquadah.com.br}" FAKE_LOG="$T/log" \
    bash "$(bin "$tool")" "$@" <<<"senha" >"$T/out" 2>"$T/err" ); echo $? > "$T/rc"; }
echo "usando: $(bin moj-comp)"

run moj-comp login pv -u t1
chk "login <cid>: POST no subdomínio da prova" 'grep -q "^POST https://pv.moj.naquadah.com.br/api/v1/auth/login host=-" "$T/log"'
run moj-comp news
chk "comando seguinte (a última prova gravada): subdomínio" 'grep -q "https://pv.moj.naquadah.com.br/api/v1/contest/news" "$T/log" && ! grep -q "//moj.naquadah.com.br/api" "$T/log"'
run moj-comp login treino -u alice
chk "login treino: site principal" 'grep -q "^POST https://moj.naquadah.com.br/api/v1/auth/login" "$T/log"'
run moj-comp login "https://moj.naquadah.com.br/contest/?c=fac_daniel_2026_2" -u t1
chk "login <url ?c=>: o contest no subdomínio" 'grep -q "^POST https://fac_daniel_2026_2.moj.naquadah.com.br/api/v1/auth/login" "$T/log"'
run moj-comp login "https://pv.moj.naquadah.com.br/contest/score/" -u t1
chk "login <url do subdomínio>: o contest dele" 'grep -q "^POST https://pv.moj.naquadah.com.br/api/v1/auth/login" "$T/log"'
URL=https://pv.moj.naquadah.com.br run moj-comp login treino -u alice
chk "MOJ_URL apontando p/ um subdomínio: o treino ainda vai ao site principal" 'grep -q "^POST https://moj.naquadah.com.br/api/v1/auth/login" "$T/log"'
run moj-comp login "https://evil.example/contest/?c=pv" -u t1
chk "URL de outro servidor: recusada sem mandar nada" '[[ $(cat "$T/rc") != 0 ]] && [[ ! -s "$T/log" ]] && grep -q "outro servidor" "$T/err"'
mkdir -p "$T/cfg"; printf 'tk' > "$T/cfg/token-a.b"
run moj-comp -c a.b news
chk "id que não vira subdomínio (a.b): site principal" 'grep -q "^GET https://moj.naquadah.com.br/api/v1/contest/news" "$T/log"'
URL=http://127.0.0.1:8080 MOJ_HOST=moj.naquadah.com.br run moj-comp -c pv news
chk "MOJ_HOST de teste: a URL fica, o Host vira <cid>.<MOJ_HOST>" 'grep -q "^GET http://127.0.0.1:8080/api/v1/contest/news host=pv.moj.naquadah.com.br" "$T/log"'
URL=http://127.0.0.1:8080 run moj-comp -c pv news
chk "servidor fora do moj.* (IP/localhost): fica nele" 'grep -q "^GET http://127.0.0.1:8080/api/v1/contest/news host=-" "$T/log"'
FAKE_HOSTREQ=1 run moj-comp -c pv news
chk "host_required do servidor: mostra o endereço certo" '[[ $(cat "$T/rc") != 0 ]] && grep -q "pv.moj.naquadah.com.br/contest/" "$T/err"'

mkdir -p "$T/cfg"; printf 'tk' > "$T/cfg/token-pv"
run moj-contest -c pv seed --live 2 --password pw
chk "seed --live: os times logam e submetem pelo subdomínio" 'grep -q "^POST https://pv.moj.naquadah.com.br/api/v1/auth/login" "$T/log" && grep -q "^POST https://pv.moj.naquadah.com.br/api/v1/submit" "$T/log"'
run moj-contest -c pv seed --teams 2 --subs 3
chk "seed (histórico, rota de admin): segue no site principal" 'grep -q "^POST https://moj.naquadah.com.br/api/v1/contest/admin/seed" "$T/log"'

echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
