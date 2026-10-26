#!/bin/bash
# tl-method-conf.sh — os MÉTODOS DE TL na CLI (26/10/2026; cdmoj/docs/PACOTE.md "Métodos de TL"). Sem rede.
#   · o pré-voo (`gate`) reprova TLMETHOD/KATTIS_* inválidos — a mesma regra do validate-problem.sh
#     (conf_tlmethod_sane), que reprova o pacote no servidor;
#   · o menu `moj edit → 8 → 11` grava o método na 1ª linha do conf sem mexer em outro byte (a linha sai do
#     tl-checksum: trocar não recalibra) e o `→ 12` grava/limpa os parâmetros do Kattis;
#   · conf_get/conf_set leem e preservam a ÚLTIMA linha sem \n final (o conf_set a apagava ao regravar);
#   · `moj calib`/`moj check` mostram os dois métodos (JSON de um /problems/calib real do servidor novo) e, com
#     o servidor antigo (sem os campos), saem como antes;
#   · os textos novos do _RDY_JQ (as margens do Kattis, "não medido") e a linha do TLMOD sum/mult (`tl_mods`);
#   · `moj test --run` grava as duas metades na tabela local (build-and-test FALSO; sem bwrap de verdade).
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"; CLI="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
MOJ_CLI_LIB_ONLY=1 MOJ_CONFIG_DIR="$T/cfg" source "$CLI/moj" 2>/dev/null
set +e; set +o pipefail
type tlmethod_conf_gate >/dev/null 2>&1 || { echo "FAIL: tlmethod_conf_gate não carregou"; exit 1; }
pass=0; fail=0
ck(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }
P="$T/p"; mkdir -p "$P/docs" "$P/tests/input" "$P/tests/output" "$P/sols/good"
printf '# x\n\n## Entrada\n\n## Saída\n' > "$P/docs/enunciado.md"
printf '1\n' > "$P/tests/input/sample1"; printf '1\n' > "$P/tests/output/sample1"; printf 'int main(){}\n' > "$P/sols/good/a.c"
printf '{"id":"o#p","repo":"o","prob":"p","title":"P"}' > "$P/.moj-id"
gok(){ printf "$1" > "$P/conf"; gate "$P" >/dev/null 2>&1; }

echo "== gate: TLMETHOD e os parâmetros do Kattis =="
ck "conf sem as chaves passa"                   'gok "CALIBRATIONTL=5\n"'
ck "TLMETHOD=moj passa"                         'gok "TLMETHOD=moj\n"'
ck "TLMETHOD=kattis passa"                      'gok "TLMETHOD=kattis\n"'
ck "aspas e comentário no valor passam" "gok \"TLMETHOD='kattis'  # Kattis\\n\""
ck "TLMETHOD=icpc reprova"                      '! gok "TLMETHOD=icpc\n"'
ck "TLMETHOD=Kattis (maiúscula) reprova, como no servidor" '! gok "TLMETHOD=Kattis\n"'
ck "a mensagem diz qual chave"                  '[[ "$(gate "$P" 2>&1 >/dev/null)" == *"TLMETHOD=Kattis inválido"* ]]'
ck "KATTIS_AC_TO_TIME_LIMIT 1 e 100 passam"     'gok "KATTIS_AC_TO_TIME_LIMIT=1\n" && gok "KATTIS_AC_TO_TIME_LIMIT=100\n"'
ck "KATTIS_AC_TO_TIME_LIMIT 0.5, 101, abc e 2,5 reprovam" '! gok "KATTIS_AC_TO_TIME_LIMIT=0.5\n" && ! gok "KATTIS_AC_TO_TIME_LIMIT=101\n" && ! gok "KATTIS_AC_TO_TIME_LIMIT=abc\n" && ! gok "KATTIS_AC_TO_TIME_LIMIT=2,5\n"'
ck "KATTIS_TIME_LIMIT_TO_TLE 1.5 passa; 0.9 reprova" 'gok "KATTIS_TIME_LIMIT_TO_TLE=1.5\n" && ! gok "KATTIS_TIME_LIMIT_TO_TLE=0.9\n"'
ck "KATTIS_TIME_RESOLUTION 0.1, .5 e 10 passam" 'gok "KATTIS_TIME_RESOLUTION=0.1\n" && gok "KATTIS_TIME_RESOLUTION=.5\n" && gok "KATTIS_TIME_RESOLUTION=10\n"'
ck "KATTIS_TIME_RESOLUTION 0 e 10.5 reprovam"   '! gok "KATTIS_TIME_RESOLUTION=0\n" && ! gok "KATTIS_TIME_RESOLUTION=10.5\n"'
ck "o locale do usuário não importa (awk com LC_ALL=C)" 'LC_ALL=pt_BR.UTF-8 _num_in 0.5 0 10 x 2>/dev/null'

echo "== conf_get/conf_set: a última linha sem \\n final =="
printf 'A=1\nB=2' > "$P/conf"
ck "conf_get lê a última linha"                 '[[ "$(conf_get "$P" B)" == 2 ]]'
conf_set "$P" C 3
ck "conf_set preserva a última linha (antes a apagava)" 'grep -qx "B=2" "$P/conf" && grep -qx "C=3" "$P/conf" && grep -qx "A=1" "$P/conf"'

echo "== conf_set_top: o resto do conf igual byte a byte =="
ORIG='TLMOD[calibrafactor]=1.35\nULIMITS[-u]=10000\nCALIBRATIONTL=5'
printf "$ORIG" > "$T/orig"; printf "$ORIG" > "$P/conf"
conf_set_top "$P" TLMETHOD kattis
ck "kattis: a 1ª linha + o conf de antes, intacto (sem \\n final)" '[[ "$(head -n1 "$P/conf")" == TLMETHOD=kattis ]] && cmp -s <(tail -n +2 "$P/conf") "$T/orig"'
conf_set_top "$P" TLMETHOD ""
ck "vazio: tira a linha e volta ao conf de antes, byte a byte" 'cmp -s "$P/conf" "$T/orig"'
printf 'A=1\nTLMETHOD=moj\nB=2\n' > "$P/conf"; conf_set_top "$P" TLMETHOD kattis
ck "linha no meio: sai de lá e vai p/ o topo"   '[[ "$(cat "$P/conf")" == $'"'"'TLMETHOD=kattis\nA=1\nB=2'"'"' ]]'
MT="${MOJTOOLS_DIR:-$CLI/../mojtools}"
if [[ -f "$MT/tl-checksum.sh" ]]; then
  printf "$ORIG" > "$P/conf"; c1="$(bash "$MT/tl-checksum.sh" "$P")"; v1="$(bash "$MT/tl-checksum.sh" --all-sols "$P")"
  conf_set_top "$P" TLMETHOD kattis
  ck "os dois carimbos do tl-checksum não mudam com a troca" '[[ -n "$c1" && "$(bash "$MT/tl-checksum.sh" "$P")" == "$c1" && "$(bash "$MT/tl-checksum.sh" --all-sols "$P")" == "$v1" ]]'
else echo "  (sem mojtools em $MT: pulei a conferência do tl-checksum)"; fi

echo "== menu moj edit → 8 → 11/12 (respostas de uma fila no lugar do teclado) =="
Q="$T/q"; ask(){ local l; l="$(head -n1 "$Q")"; tail -n +2 "$Q" > "$Q.t"; mv "$Q.t" "$Q"; printf '%s' "$l"; }
menu(){ printf "$1" > "$Q"; edit_conf "$P" >/dev/null 2>&1; }
printf "$ORIG" > "$P/conf"
menu '11\nkattis\nv\n'
ck "11 → kattis: TLMETHOD na 1ª linha, resto intacto" '[[ "$(head -n1 "$P/conf")" == TLMETHOD=kattis ]] && cmp -s <(tail -n +2 "$P/conf") "$T/orig"'
menu '12\n2.5\n2\n0.5\nv\n'
ck "12: grava os três parâmetros"               '[[ "$(conf_get "$P" KATTIS_AC_TO_TIME_LIMIT)" == 2.5 && "$(conf_get "$P" KATTIS_TIME_LIMIT_TO_TLE)" == 2 && "$(conf_get "$P" KATTIS_TIME_RESOLUTION)" == 0.5 ]]'
menu '12\n0.5\n2\n0.5\nv\n'
ck "12 com valor inválido (a=0.5): nada muda"   '[[ "$(conf_get "$P" KATTIS_AC_TO_TIME_LIMIT)" == 2.5 ]]'
menu '12\n\n\n\nv\n'
ck "12 vazio: as três linhas saem (o padrão)"   '! grep -q "^KATTIS_" "$P/conf"'
menu '11\nicpc\nv\n'
ck "11 com método inválido: nada muda"          '[[ "$(head -n1 "$P/conf")" == TLMETHOD=kattis ]]'
menu '11\nMOJ\nv\n'
ck "11 → MOJ (maiúscula aceita): a linha sai"   '! grep -q "^TLMETHOD" "$P/conf"'
ck "e o menu mostra o método e os parâmetros"   '[[ "$(printf "v\n" > "$Q"; edit_conf "$P" 2>/dev/null)" == *"11) método do TL (TLMETHOD): moj   12) parâmetros do Kattis: a=2.0 b=1.5 r=1.0"* ]]'

echo "== moj calib / moj check: os dois métodos (JSON do servidor novo) =="
cat > "$T/calib.json" <<'JSON'
{"success":true,"id":"col#pa","checksum":"50d87838e003d32b","version":"a15f065a04074d64","being_calibrated":false,"calibrating":[],"good_langs":["c"],"tl_override":{},"tl_method":"kattis","kattis":{"a":2.0,"b":1.5,"r":1.0},"time_limits":{"c":"1","default":"1"},"time_limits_calibrated":{"c":"1","default":"1"},"time_limits_by_method":{"moj":{"calibrated":{"c":"0.4","default":"0.4"},"effective":{"c":"0.4","default":"0.4"}},"kattis":{"calibrated":{"c":"1","default":"1"},"effective":{"c":"1","default":"1"}}},"missing_langs":[],"allow_tle":false,"drift":{},"summary":{"hosts":2,"total":3,"bad":1,"note":0,"bad_files":["slow/m.c"],"note_files":[],"missing":[],"validator":{"state":"unknown","total":0,"invalid":0,"failed":0}},"summary_alt":{"hosts":2,"total":3,"bad":0,"note":0,"bad_files":[],"note_files":[],"missing":[],"validator":{"state":"unknown","total":0,"invalid":0,"failed":0}},"hosts":[{"host":"juiz1","tl":{"c":".3035","default":".3035"},"tl_kattis":{"c":"1","default":"1"},"missing":[],"at":1793025188,"version":"a15f065a04074d64","stale":false,"sols":[{"file":"sol.c","lang":"c","category":"good","verdict":"Accepted,100p","tests":[{"name":"t1","code":"AC","time":0.25,"tl":5}],"method":"kattis","expect":{"state":"ok","why":"all_ac","counts":{"AC":1},"tmax":0.25,"tl":1,"drift":0,"method":"kattis","need":2.0},"expect_alt":{"state":"ok","why":"all_ac","counts":{"AC":1},"tmax":0.25,"tl":0.4,"drift":0,"method":"moj"}},{"file":"s.c","lang":"c","category":"slow","verdict":"Time Limit Exceeded,0p","tests":[{"name":"t1","code":"TLE","time":2.5035,"tl":0.3035,"code_alt":"TLE","tl_alt":1}],"method":"moj","etl":2.5035,"expect":{"state":"ok","why":"tle","counts":{"TLE":1},"tmax":null,"tl":1,"drift":0,"method":"kattis","need":1.5,"ratio":2.5035,"etl":2.5035},"expect_alt":{"state":"ok","why":"tle","counts":{"TLE":1},"tmax":null,"tl":0.4,"drift":0,"method":"moj"}},{"file":"m.c","lang":"c","category":"slow","verdict":"Time Limit Exceeded,0p","tests":[{"name":"t1","code":"TLE","time":0.6,"tl":0.3035,"code_alt":"AC","tl_alt":1}],"method":"moj","etl":2.5035,"expect":{"state":"bad","why":"no_tle","counts":{"AC":1},"tmax":0.6,"tl":1,"drift":0,"method":"kattis","need":1.5,"ratio":null,"etl":2.5035},"expect_alt":{"state":"ok","why":"tle","counts":{"TLE":1},"tmax":null,"tl":0.4,"drift":0,"method":"moj"}}],"validator":null},{"host":"juiz2","tl":{"c":".4","default":".4"},"tl_kattis":{},"missing":["c"],"at":1793025188,"version":"","stale":false,"sols":[],"validator":null}]}
JSON
cat > "$T/tl.json" <<'JSON'
{"success":true,"problem":"col#pa","checksum":"50d87838e003d32b","time_limits":{"c":"1","default":"1"},"time_limits_calibrated":{"c":"1","default":"1"},"tl_override":{},"tl_method":"kattis","kattis":{"a":2.0,"b":1.5,"r":1.0},"time_limits_by_method":{"moj":{"calibrated":{"c":"0.4","default":"0.4"},"effective":{"c":"0.4","default":"0.4"}},"kattis":{"calibrated":{"c":"1","default":"1"},"effective":{"c":"1","default":"1"}}},"calibrated_checksum":"50d87838e003d32b","hosts":{"juiz1":{"tl":{"c":".3035","default":".3035"},"at":1793025188,"tl_kattis":{"c":"1","default":"1"},"pkg_version":"a15f065a04074d64"},"juiz2":{"tl":{"c":".4","default":".4"},"at":1793025188,"pkg_version":"a15f065a04074d64"}},"updated_at":1793025188,"calibrated_at":1793025188,"calibrated":true,"being_calibrated":false,"stale":false,"needs_recalibration":false}
JSON
need_login(){ :; }
api(){ case "$2" in /problems/calib*) cat "$T/calib.json";; /problems/tl*) cat "$T/tl.json";;
  /problems/validation*) echo '{"ok":true,"checks":[]}';;
  /problems/status*) echo '{"problems":[{"ready":false,"pending":["sols_divergent:1"],"sols":{"state":"bad","bad":1},"inputs":{"state":"none"}}]}';; esac; }
out="$(cmd_calib 'col#pa' 2>&1)"
ck "calib: o método do conf e os parâmetros (a=2, igual em todo jq)" '[[ "$out" == *"método do TL: Kattis (a=2 b=1.5 r=1)"* ]]'
ck "calib: o TL dos dois métodos"               '[[ "$out" == *"TL (máx entre juízes): c=1s · pelo MOJ: c=0.4s"* ]]'
ck "calib: o resumo pelo outro método"          '[[ "$out" == *"pelo MOJ, se trocar o método: 3 de 3 conforme"* ]]'
ck "calib: o juiz com as duas metades"          '[[ "$out" == *"TL Kattis: c=1 default=1  · MOJ: c=.3035 default=.3035"* ]]'
ck "calib: o juiz antigo, sem a metade Kattis"  '[[ "$out" == *"juiz2"*"TL Kattis: (sem TL)"* ]]'
ck "calib: o juízo pelo outro método (chip)"    '[[ "$out" == *"[✗ DIVERGENTE] slow/m.c [c]: Time Limit Exceeded,0p   · MOJ: ✓ conforme"* ]]'
ck "calib: o esperado com a margem do Kattis"   '[[ "$out" == *"esperado (Kattis): estourar o tempo em pelo menos 1 teste por 1.5 × o TL"* ]]'
ck "calib: o teste pelos dois métodos"          '[[ "$out" == *"MOJ TLE  0.6s  (tl 0.3035s)   · Kattis AC (tl 1s)"* ]]'
ck "calib: o porquê pelo outro método só quando difere (aqui, todos conformes)" '[[ "$(grep -c "^      pelo MOJ: " <<<"$out")" == 0 ]]'
out="$(cmd_check 'col#pa' 2>&1)"
ck "check: a linha do método e o TL do outro"   '[[ "$out" == *"método do TL: Kattis (a=2 b=1.5 r=1) · pelo MOJ: c=0.4s"* ]]'
ck "check: por máquina, a metade do método do conf" '[[ "$out" == *"juiz1: c=1   · MOJ: c=.3035"* && "$out" == *"juiz2: (sem TL)   (falta: c)   · MOJ: c=.4"* ]]'
echo "== TLMOD sum/mult do conf (tl_mods, 26/10/2026): o TL já vem com o ajuste e a linha diz qual =="
cp "$T/calib.json" "$T/calib.nomods.json"; cp "$T/tl.json" "$T/tl.nomods.json"
jq -c '.tl_mods = {"sum":{"spim":2.0},"mult":{"cpp":1.5}}' "$T/calib.nomods.json" > "$T/calib.json"
jq -c '.tl_mods = {"sum":{"spim":2.0},"mult":{"cpp":1.5}}' "$T/tl.nomods.json" > "$T/tl.json"
out="$(cmd_calib 'col#pa' 2>&1)"
ck "calib: a linha do TLMOD (o 2.0 sai 2 em todo jq)" '[[ "$out" == *"⚙ TLMOD no conf (já incluído no TL): cpp×1.5 spim+2s"* ]]'
out="$(cmd_check 'col#pa' 2>&1)"
ck "check: a linha do TLMOD"                    '[[ "$out" == *"⚙ TLMOD no conf (o juiz soma/multiplica por cima do calibrado; o TL acima já inclui): cpp×1.5 spim+2s"* ]]'
mv "$T/calib.nomods.json" "$T/calib.json"; mv "$T/tl.nomods.json" "$T/tl.json"
out="$(cmd_calib 'col#pa' 2>&1)"; out2="$(cmd_check 'col#pa' 2>&1)"
ck "sem tl_mods (servidor anterior): nenhuma linha de TLMOD" '[[ "$out" != *TLMOD* && "$out2" != *TLMOD* ]]'
cp "$T/calib.json" "$T/calib.kattis.json"
jq -c '.tl_method = "moj" | .hosts |= map(.sols |= map(.expect as $e | .expect = .expect_alt | .expect_alt = $e))' "$T/calib.kattis.json" > "$T/calib.json"
out="$(cmd_calib 'col#pa' 2>&1)"
ck "calib (conf no MOJ): o porquê pelo Kattis aparece quando o juízo difere" '[[ "$out" == *"[✓ conforme] slow/m.c [c]: Time Limit Exceeded,0p   · Kattis: ✗ DIVERGENTE"* && "$out" == *"      pelo Kattis: passou em todos no tempo — o TL não pega esta solução"* ]]'
cp "$T/calib.kattis.json" "$T/calib.json"
echo "== servidor ANTIGO (sem os campos dos dois métodos): sai como antes =="
jq -c 'del(.tl_method,.kattis,.time_limits_by_method,.summary_alt) | .hosts |= map(del(.tl_kattis) | .sols |= map(del(.expect_alt,.method,.etl) | .tests |= map(del(.code_alt,.tl_alt))))' "$T/calib.json" > "$T/c2" && mv "$T/c2" "$T/calib.json"
jq -c 'del(.tl_method,.kattis,.time_limits_by_method) | .hosts |= map_values(del(.tl_kattis))' "$T/tl.json" > "$T/t2" && mv "$T/t2" "$T/tl.json"
out="$(cmd_calib 'col#pa' 2>&1)"
ck "calib: sem linha de método nem chip"        '[[ "$out" != *"método do TL"* && "$out" != *"· Kattis"* && "$out" != *"· MOJ"* ]]'
ck "calib: o teste como antes"                  '[[ "$out" == *"t1: TLE  0.6s  (tl 0.3035s)"* ]]'
out="$(cmd_check 'col#pa' 2>&1)"
ck "check: sem a linha de método; por máquina o tl de antes" '[[ "$out" != *"método do TL"* && "$out" == *"juiz1: c=.3035"* ]]'

echo "== textos do _RDY_JQ: as margens do Kattis =="
rj(){ jq -nr "$_RDY_JQ$1"; }
ck "tl_no_margin"   '[[ "$(rj "{why:\"tl_no_margin\",need:2.0,tmax:0.6,tl:1} | xgot")" == "aceita, mas sem a folga do Kattis: 2 × 0.6s passa do TL de 1s (TLOVERRIDE baixo demais?)" ]]'
ck "tle_no_margin com a razão" '[[ "$(rj "{why:\"tle_no_margin\",ratio:1.2345,need:1.5} | xgot")" == *"só 1.23 × o TL — o Kattis pede 1.5 ×"* ]]'
ck "tle_no_margin sem a razão" '[[ "$(rj "{why:\"tle_no_margin\",need:1.5} | xgot")" == *"só um pouco acima do TL"* ]]'
ck "tle_unmeasured" '[[ "$(rj "{why:\"tle_unmeasured\",etl:2.7,need:1.5} | xgot")" == *"parou no teto de 2.7s antes de 1.5 × o TL"* ]]'
ck "other_method"   '[[ "$(rj "{why:\"other_method\"} | xgot")" == *"não julgou a solução por este método de TL — recalibre"* ]]'
ck "pílula não medido" '[[ "$(rj "{state:\"unmeasured\"} | xpill")" == "• não medido" ]]'
ck "esperado: Kattis com a margem; MOJ como antes" '[[ "$(rj "\"good\" | xwant({method:\"kattis\",need:2.0})")" == *"(Kattis)"*"2 × o pior tempo"* && "$(rj "\"slow\" | xwant({method:\"moj\"})")" == "esperado: TLE em pelo menos 1 teste, sem errar os outros" ]]'

echo "== moj test --run: a tabela local leva as duas metades =="
mkdir -p "$T/bin" "$T/mt"
printf '#!/bin/bash\necho "bubblewrap 0.8.0"\n' > "$T/bin/bwrap"; chmod +x "$T/bin/bwrap"
cat > "$T/mt/build-and-test.sh" <<'SH'
#!/bin/bash
# build-and-test FALSO: guarda a tabela recebida e responde no contrato (workdir na 1ª linha, veredicto na última)
w="$(mktemp -d "$TLCAP.w.XXXX")"; cp "$3/tl" "$TLCAP"
printf 'EXECTIME t1 0.21 AC\n' > "$w/run-trace.log"
if [[ -n "${FAKE_OLD:-}" ]]; then printf "TL_LANG='5'\n" > "$w/report.env"; else printf "TL_LANG='1'\nTL_METHOD='kattis'\n" > "$w/report.env"; fi
echo "$w"; echo "Accepted,100p"
SH
printf 'TLMETHOD=kattis\n' > "$P/conf"; rm -f "$P/tl"
out="$( export TLCAP="$T/tlcap" MOJTOOLS_DIR="$T/mt" PATH="$T/bin:$PATH"; cmd_test "$P" --run 2>&1 )"; rc=$?
ck "julgou (rc 0) e mostra o método usado" '[[ $rc -eq 0 && "$out" == *"a.c -> Accepted,100p"* && "$out" == *"tempos (TL 1s, método Kattis): 0.21"* ]]'
ck "a tabela local: TL[default] + declare -A TLKATTIS + TLKATTIS[default]" '[[ "$(cat "$T/tlcap")" == $'"'"'TL[default]=5\ndeclare -A TLKATTIS\nTLKATTIS[default]=5'"'"' ]]'
ck "a tabela transitória some depois"           '[[ ! -e "$P/tl" ]]'
out="$( export TLCAP="$T/tlcap" MOJTOOLS_DIR="$T/mt" PATH="$T/bin:$PATH" FAKE_OLD=1; cmd_test "$P" --run 2>&1 )"; rc=$?
ck "mojtools antigo (sem TL_METHOD no report.env): segue, sem o método" '[[ $rc -eq 0 && "$out" == *"tempos (TL 5s): 0.21"* ]]'

echo; echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))
