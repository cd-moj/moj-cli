#!/bin/bash
# ua.sh — a CLI se apresenta pelo User-Agent: "<tool>/<build>" sempre, e NA MÁQUINA DE PROVA com o
# UA do navegador da imagem na frente (/etc/moj/user-agent ou MOJ_UA_FILE; MOJ_USER_AGENT força).
# É o que faz o moj-comp passar no gate de navegador por sede e ter a MESMA chave de máquina do
# browser — e o que deixa o servidor separar pedidos web × CLI. Testa a lib e o artefato (curl falso).
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
ua_of(){ ( MOJ_TOOL="$1" MOJ_UA_FILE="${2:-/nonexistent/ua}" MOJ_USER_AGENT="${3:-}" ; [[ -n "$MOJ_USER_AGENT" ]] || unset MOJ_USER_AGENT; source "$CLI/lib/core.sh" 2>/dev/null; printf '%s' "$MOJ_UA" ); }
echo "== lib/core.sh =="
chk "sem arquivo: só tool/build"           '[[ "$(ua_of moj-comp)" == "moj-comp/dev" ]]'
printf 'Mozilla/5.0 (MLinux/26brspso/0123456789abcdef0123456789abcdef/4104648619) Gecko/20100101 Firefox/148.0\r\nlixo\n' > "$T/ua"
chk "com arquivo: UA da máquina + tool/build (1ª linha, sem CR)" '[[ "$(ua_of moj-comp "$T/ua")" == "Mozilla/5.0 (MLinux/26brspso/0123456789abcdef0123456789abcdef/4104648619) Gecko/20100101 Firefox/148.0 moj-comp/dev" ]]'
chk "MOJ_USER_AGENT vence o arquivo"        '[[ "$(ua_of moj "$T/ua" "Custom UA X")" == "Custom UA X moj/dev" ]]'
chk "HDR leva -A"  '( MOJ_TOOL=moj-contest; source "$CLI/lib/core.sh" 2>/dev/null; [[ " ${HDR[*]} " == *" -A "* ]] )'
echo "== curl falso: o -A chega na requisição (artefato ou repo) =="
mkdir -p "$T/bin"; cat > "$T/bin/curl" <<'EOF'
#!/bin/bash
# registra os argumentos e devolve um /moj.build vazio (200)
printf '%s\n' "$@" > "${FAKE_CURL_LOG:?}"
for a in "$@"; do [[ "$a" == -w ]] && { echo -n "200"; exit 0; }; done
exit 0
EOF
chmod +x "$T/bin/curl"
BIN="$CLI/dist/moj-comp"; [[ -x "$BIN" ]] || BIN="$CLI/moj-comp"
FAKE_CURL_LOG="$T/args" PATH="$T/bin:$PATH" MOJ_UA_FILE="$T/ua" MOJ_CONFIG_DIR="$T/cfg" bash "$BIN" version >/dev/null 2>&1 || true
chk "curl recebeu -A com o UA da máquina e moj-comp/" 'grep -qx -- "-A" "$T/args" && grep -q "MLinux/26brspso/.* moj-comp/" "$T/args"'
echo "== ajuda do artefato não vaza a lib =="
[[ -x "$CLI/dist/moj-comp" ]] && chk "help sem tripa interna" '! bash "$CLI/dist/moj-comp" help 2>/dev/null | grep -q "core.sh\|@INLINE\|set -euo"'
echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
