#!/bin/bash
# tl-sim.sh — o bloco "simulação do TL" do `moj calib` (26/10/2026; cdmoj lib/tl-sim.sh). O servidor calcula, a CLI só
# mostra: uma linha por configuração (MOJ: fator; Kattis: resolução) com o TL e as soluções que sairiam erradas, e a
# sugestão de cada método. Com a calibração em voo, diz que espera; servidor anterior (sem tl_sim_state) = nada.
# Número do JSON passa por n0: o jq 1.7+ imprime o literal 2.0 como veio. Sem rede.
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"; CLI="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj" 2>/dev/null
set +e; set +o pipefail
pass=0; fail=0
ck(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
need_login(){ :; }
api(){ cat "$T/calib.json"; }
cat > "$T/calib.json" <<'JSON'
{"success":true,"id":"col#pa","checksum":"x","tl_method":"moj","kattis":{"a":2.0,"b":1.5,"r":1.0},"time_limits":{"c":"0.6275","default":"0.6275"},"hosts":[],
 "tl_sim_state":"ok",
 "tl_sim":{"hosts":["j1","j2"],"w":{"c":0.45,"default":0.45},"overrides":[],
   "moj":{"cf":1.35,"off":0,"interval":{"min":1.177778,"min_by":"pass/p.c","max":4.4,"max_by":"slow/s.c","n":4},
          "rows":[{"cf":1,"current":false,"tl":{"c":0.47,"default":0.47},"ok":false,"fail":["pass/p.c"],"unmeasured":[]},
                  {"cf":1.35,"current":true,"tl":{"c":0.6275,"default":0.6275},"ok":true,"fail":[],"unmeasured":[]}]},
   "kattis":{"a":2.0,"b":1.5,"r":1.0,
          "rows":[{"r":0.2,"current":false,"tl":{"c":1.0,"default":1.0},"ok":true,"fail":[],"unmeasured":["slow/k.c"]},
                  {"r":1.0,"current":true,"tl":{"c":1.0,"default":1.0},"ok":false,"fail":["slow/s.c"],"unmeasured":[]}]}},
 "tl_suggest":{"moj":{"state":"keep","cf":1.35,"why":"current_valid"},"kattis":{"state":"change","a":2.0,"b":1.5,"r":0.2,"why":"largest_r"}}}
JSON
out="$(cmd_calib 'col#pa' 2>&1)"
ck "o cabeçalho com os juízes"                 '[[ "$out" == *"simulação do TL (tempos desta calibração, juízes j1, j2; nada roda de novo):"* ]]'
ck "linha MOJ que reprova a pass"              '[[ "$out" == *"    MOJ fator 1: c=0.47s   ✗ pass/p.c"* ]]'
ck "linha MOJ atual, certa"                    '[[ "$out" == *"    MOJ fator 1.35 (atual): c=0.6275s   ✓"* ]]'
ck "Kattis: 1.0 sai 1 em todo jq; o não medido" '[[ "$out" == *"    Kattis r=0.2 s: c=1s   ✓  (não medido: slow/k.c)"* && "$out" == *"    Kattis r=1 s (atual): c=1s   ✗ slow/s.c"* ]]'
ck "as sugestões"                              '[[ "$out" == *"  sugestão MOJ: manter o fator 1.35"* && "$out" == *"  sugestão Kattis: a=2 b=1.5 r=0.2 s (a maior resolução que serve) — moj edit → 8 → 11 e 12"* ]]'
jq -c '.tl_suggest.moj = {state:"conflict", cf:1.35, why:"conflict", pass:"pass/p.c", slow:"slow/s.c"}' "$T/calib.json" > "$T/c" && mv "$T/c" "$T/calib.json"
out="$(cmd_calib 'col#pa' 2>&1)"
ck "conflito: nomeia a pass e a lenta"          '[[ "$out" == *"sugestão MOJ: nenhum fator serve: pass/p.c precisa de mais tempo do que slow/s.c gasta"* ]]'
jq -c '.tl_sim = null | .tl_suggest = null | .tl_sim_state = "calibrating"' "$T/calib.json" > "$T/c" && mv "$T/c" "$T/calib.json"
out="$(cmd_calib 'col#pa' 2>&1)"
ck "calibração em voo: espera"                  '[[ "$out" == *"simulação do TL: depois que a calibração terminar"* ]]'
jq -c '.tl_sim_state = "error"' "$T/calib.json" > "$T/c" && mv "$T/c" "$T/calib.json"
out="$(cmd_calib 'col#pa' 2>&1)"
ck "erro na simulação (servidor): diz que não deu"  '[[ "$out" == *"simulação do TL: não deu para calcular"* ]]'
jq -c 'del(.tl_sim, .tl_suggest, .tl_sim_state)' "$T/calib.json" > "$T/c" && mv "$T/c" "$T/calib.json"
out="$(cmd_calib 'col#pa' 2>&1)"
ck "servidor anterior (sem o campo): nenhuma linha" '[[ "$out" != *"simulação do TL"* && "$out" != *"sugestão"* ]]'

echo; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
