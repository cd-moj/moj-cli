#!/bin/bash
# tl-unified-conf.sh — o TL ÚNICO na CLI (05/11/2026; cdmoj/docs/PACOTE.md "TL único"). Sem rede.
#   · o pré-voo (`gate`) reprova TLUNIFIED fora de y|n — a mesma regra do validate-problem.sh (conf_tlunified_sane);
#   · o menu `moj edit → 8 → 15` grava TLUNIFIED=y (no fim do conf: a linha entra no tl-checksum, ligar recalibra) e o
#     tira com n/vazio;
#   · `moj calib`/`moj check` dizem o TL único; sem ele (ou servidor antigo, sem tl_unified), nada muda.
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"; CLI="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj" 2>/dev/null
set +e; set +o pipefail
type tlunified_conf_gate >/dev/null 2>&1 || { echo "FAIL: tlunified_conf_gate não carregou"; exit 1; }
pass=0; fail=0
ck(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
P="$T/p"; mkdir -p "$P/docs" "$P/tests/input" "$P/tests/output" "$P/sols/good"
printf '# x\n\n## Entrada\n\n## Saída\n' > "$P/docs/enunciado.md"
printf '1\n' > "$P/tests/input/sample1"; printf '1\n' > "$P/tests/output/sample1"; printf 'int main(){}\n' > "$P/sols/good/a.c"
printf '{"id":"o#p","repo":"o","prob":"p","title":"P"}' > "$P/.moj-id"
gok(){ printf "$1" > "$P/conf"; gate "$P" >/dev/null 2>&1; }

echo "== gate: TLUNIFIED =="
ck "sem a chave, y e n passam"                 'gok "CALIBRATIONTL=5\n" && gok "TLUNIFIED=y\n" && gok "TLUNIFIED=n\n"'
ck "TLUNIFIED=sim reprova, com a chave na mensagem" '! gok "TLUNIFIED=sim\n" && [[ "$(gate "$P" 2>&1 >/dev/null)" == *"TLUNIFIED=sim inválido"* ]]'

echo "== menu moj edit → 8 → 15 =="
Q="$T/q"; ask(){ local l; l="$(head -n1 "$Q")"; tail -n +2 "$Q" > "$Q.t"; mv "$Q.t" "$Q"; printf '%s' "$l"; }
menu(){ printf "$1" > "$Q"; edit_conf "$P" >/dev/null 2>&1; }
printf 'TLMOD[calibrafactor]=1.35\nCALIBRATIONTL=5\n' > "$P/conf"
menu '15\ny\nv\n'
ck "15 → y: TLUNIFIED=y no FIM do conf"         '[[ "$(tail -n1 "$P/conf")" == TLUNIFIED=y && "$(head -n1 "$P/conf")" == "TLMOD[calibrafactor]=1.35" ]]'
ck "o menu mostra o TL único"                  '[[ "$(printf "v\n" > "$Q"; edit_conf "$P" 2>/dev/null)" == *"15) TL único em todas as linguagens (TLUNIFIED): sim"* ]]'
menu '15\ntalvez\nv\n'
ck "15 com valor inválido: nada muda"          '[[ "$(conf_get "$P" TLUNIFIED)" == y ]]'
menu '15\nn\nv\n'
ck "15 → n: a linha sai"                       '! grep -q "^TLUNIFIED" "$P/conf"'
MT="${MOJTOOLS_DIR:-$CLI/../mojtools}"
if [[ -f "$MT/tl-checksum.sh" ]]; then
  c1="$(bash "$MT/tl-checksum.sh" "$P")"; menu '15\ny\nv\n'
  ck "o tl-checksum MUDA com o TL único (ligar recalibra)" '[[ -n "$c1" && "$(bash "$MT/tl-checksum.sh" "$P")" != "$c1" ]]'
else echo "  (sem mojtools em $MT: pulei a conferência do tl-checksum)"; fi

echo "== moj calib / moj check =="
printf '%s' '{"success":true,"id":"col#pa","checksum":"x","version":"y","being_calibrated":false,"calibrating":[],"good_langs":["c","py"],"tl_override":{},"tl_mods":{"unified":true},"tl_method":"moj","tl_unified":true,"time_limits":{"c":"1.775","py":"1.775","default":"1.775"},"time_limits_calibrated":{"c":"0.3035","py":"1.775","default":"0.3035"},"missing_langs":[],"hosts":[]}' > "$T/calib.json"
printf '%s' '{"success":true,"problem":"col#pa","checksum":"x","time_limits":{"c":"1.775","py":"1.775","default":"1.775"},"tl_override":{},"tl_mods":{"unified":true},"tl_method":"moj","tl_unified":true,"hosts":{},"calibrated":true,"stale":false,"needs_recalibration":false}' > "$T/tl.json"
need_login(){ :; }
api(){ case "$2" in /problems/calib*) cat "$T/calib.json";; /problems/tl*) cat "$T/tl.json";;
  /problems/validation*) echo '{"ok":true,"checks":[]}';;
  /problems/status*) echo '{"problems":[{"ready":true,"pending":[],"sols":{"state":"ok"},"inputs":{"state":"none"}}]}';; esac; }
out="$(cmd_calib 'col#pa' 2>&1)"; out2="$(cmd_check 'col#pa' 2>&1)"
ck "calib: a linha do TL único"                '[[ "$out" == *"TL único: o mesmo em todas as linguagens"* ]]'
ck "check: a linha do TL único"                '[[ "$out2" == *"TL único: o mesmo em todas as linguagens"* ]]'
ck "o unified do tl_mods não vira linha de TLMOD" '[[ "$out" != *"TLMOD no conf"* && "$out2" != *"TLMOD no conf"* ]]'
for f in calib tl; do jq -c 'del(.tl_unified) | .tl_mods = {}' "$T/$f.json" > "$T/x" && mv "$T/x" "$T/$f.json"; done
out="$(cmd_calib 'col#pa' 2>&1)"; out2="$(cmd_check 'col#pa' 2>&1)"
ck "servidor antigo (sem tl_unified): nenhuma linha" '[[ "$out" != *"TL único"* && "$out2" != *"TL único"* ]]'

echo; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
