#!/bin/bash
# update-warn.sh — aviso de CLI desatualizada: o servidor manda X-Moj-Cli-Status/X-Moj-Cli-Latest e a
# CLI avisa UMA vez por dia no stderr sem interromper o comando (curl falso grava os cabeçalhos via -D).
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
mkdir -p "$T/bin" "$T/cfg"; printf 'tok' > "$T/cfg/token-treino"
cat > "$T/bin/curl" <<'EOC'
#!/bin/bash
# curl falso: -o corpo, -D cabeçalhos (do FAKE_STATUS), -w código
out=""; hdr=""; while (($#)); do case "$1" in -o) out="$2"; shift;; -D) hdr="$2"; shift;; esac; shift; done
[[ -n "$out" ]] && printf '{"success":true,"login":"alice","contest":"treino"}' > "$out"
[[ -n "$hdr" && -n "${FAKE_STATUS:-}" ]] && printf 'HTTP/2 200\r\nContent-Type: application/json\r\nX-Moj-Cli-Status: %s\r\nX-Moj-Cli-Latest: fffffff-20991231\r\n\r\n' "$FAKE_STATUS" > "$hdr"
echo -n 200
EOC
chmod +x "$T/bin/curl"
run(){ FAKE_STATUS="${1:-}" PATH="$T/bin:$PATH" MOJ_CONFIG_DIR="$T/cfg" MOJ_UA_FILE=/nonexistent bash "$BIN" whoami >"$T/out" 2>"$T/err"; echo $?; }
for BIN in "$CLI/moj" "$CLI/dist/moj"; do
  [[ -x "$BIN" ]] || continue; rm -f "$T/cfg/.update-warned"
  echo "== $BIN =="
  chk "outdated: comando funciona (rc 0)"            '[[ "$(run outdated)" == 0 ]]'
  chk "outdated: avisa no stderr com 'update'"      'grep -q "versão nova.*update" "$T/err"'
  chk "outdated: stdout limpo (só a resposta)"      '! grep -q "versão nova" "$T/out"'
  chk "2ª vez no mesmo dia: silêncio (stamp)"       '[[ "$(run outdated)" == 0 ]] && ! grep -q "versão nova" "$T/err"'
  rm -f "$T/cfg/.update-warned"
  chk "current: sem aviso"                          '[[ "$(run current)" == 0 ]] && ! grep -q "versão nova" "$T/err"'
  chk "sem cabeçalho (servidor antigo): sem aviso, sem erro" '[[ "$(run "")" == 0 ]] && [[ ! -s "$T/err" ]]'
done
echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
