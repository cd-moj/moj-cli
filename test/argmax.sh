#!/bin/bash
# argmax.sh — CONTEÚDO DE ARQUIVO NUNCA ANDA POR ARGV DO jq.
#
#   bash test/argmax.sh
#
# POR QUE EXISTE: em agosto/2026 o `moj-contest docs upload caderno <pdf>` morreu na cara do
# usuário com `/usr/bin/jq: Argument list too long`. O corpo era montado com
# `--arg b "$(_b64enc "$file")"` — o base64 inteiro no argumento — e o Linux limita **um**
# argumento a 128 KiB (MAX_ARG_STRLEN). Um caderno de 500 KB vira 665 KB em base64: nem chega
# perto de caber. O `moj` e o `moj-comp` já tinham aprendido isso (usam `--rawfile`); o
# `moj-contest` tinha três pontos que não.
#
# O teste tem duas metades, e as duas importam:
#   1. FUNCIONAL — roda os MESMOS programas jq dos três pontos com uma carga bem acima do teto.
#      Com o código antigo isto falha de verdade (não é simulação).
#   2. INVENTÁRIO — proíbe o padrão de voltar por outra porta, em qualquer CLI da família.
set -u
CLI="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }

source "$CLI/lib/core.sh" 2>/dev/null || true
type _b64tmp >/dev/null 2>&1 || { echo "FAIL: falta o helper _b64tmp em lib/core.sh"; exit 1; }

# 600 KB -> ~800 KB de base64: 6× o teto de 128 KiB de um argumento
head -c 600000 /dev/urandom > "$T/grande.pdf"
b64="$(_b64tmp "$T/grande.pdf")"
chk "_b64tmp gera o arquivo"        '[[ -s "$b64" ]]'
chk "base64 passa dos 128 KiB"      '(( $(stat -c%s "$b64" 2>/dev/null || wc -c < "$b64") > 131072 ))'

echo "== os três corpos do moj-contest, com carga acima do teto =="
# docs upload
jq -cn --arg t contest --arg l en --rawfile b "$b64" \
  '{action:"upload",type:$t,lang:$l,pdf_b64:($b|rtrimstr("\n"))}' > "$T/up.json" 2>"$T/up.err"
chk "docs upload: jq monta o corpo"  '[[ -s "$T/up.json" && ! -s "$T/up.err" ]]'
chk "docs upload: base64 chegou inteiro" \
  '[[ "$(jq -r .pdf_b64 "$T/up.json" | wc -c)" -eq "$(( $(wc -c < "$b64") + 1 ))" ]]'
chk "docs upload: round-trip do PDF" \
  'jq -r .pdf_b64 "$T/up.json" | _b64dec > "$T/rt.pdf"; cmp -s "$T/grande.pdf" "$T/rt.pdf"'

# docs cover
jq -cn --arg l pt --rawfile b "$b64" '{action:"cover",lang:$l,pdf_b64:($b|rtrimstr("\n"))}' \
  > "$T/cv.json" 2>"$T/cv.err"
chk "docs cover: jq monta o corpo"   '[[ -s "$T/cv.json" && ! -s "$T/cv.err" ]]'

# docs text --from <arquivo> (markdown com imagem colada em data:URI passa fácil do teto)
{ printf '# Capa\n\n![](data:image/png;base64,'; cat "$b64"; printf ')\n'; } > "$T/capa.md"
jq -cn --arg k cover_pt --rawfile v "$T/capa.md" '{action:"config"} + {($k):($v|rtrimstr("\n"))}' \
  > "$T/tx.json" 2>"$T/tx.err"
chk "docs text: jq monta o corpo"    '[[ -s "$T/tx.json" && ! -s "$T/tx.err" ]]'
chk "docs text: texto chegou inteiro" \
  '[[ "$(jq -r ".cover_pt" "$T/tx.json" | wc -c)" -eq "$(wc -c < "$T/capa.md")" ]]'

echo "== o padrão proibido não volta por outra porta =="
# `--arg x "$(...)"` cujo valor vem de ARQUIVO é o que estoura. Assinaturas conhecidas:
# _b64enc, cat, base64, xxd — e a variável que acabou de receber um `$(cat …)`.
achados="$(cd "$CLI" && grep -nE -- '--arg[[:space:]]+[A-Za-z_]+[[:space:]]+"\$\((_b64enc|cat |base64|xxd)' \
             moj moj-contest moj-comp moj-judges lib/*.sh 2>/dev/null)"
[[ -z "$achados" ]] || printf '%s\n' "$achados" | sed 's/^/     /'
chk "nenhum --arg alimentado por arquivo" '[[ -z "$achados" ]]'
rm -f "$b64"

echo ""; echo "RESULT: $pass passed, $fail failed"; exit $(( fail>0?1:0 ))
