#!/bin/bash
# portabilidade.sh — as CLIs rodam na máquina DO USUÁRIO, e ela pode ser um Mac.
#
#   bash test/portabilidade.sh
#
# POR QUE EXISTE: o `moj testrun` codificava a solução com `base64 -w0 "$arq"`. No BSD/macOS as
# DUAS pontas falham — não há `-w` e não se aceita arquivo posicional — e com `set -euo pipefail`
# o comando morria com rc=64 antes de qualquer chamada de rede. Pior que morrer: no caminho em
# que não morria, o arquivo saía VAZIO e a CLI mandava `code_b64:""` p/ o servidor. Foi um PR de
# fora (Roberto Sales, #1) que achou — daqui não se vê, porque o dev e o servidor são Linux.
#
# São DOIS modos, e nenhum basta sozinho:
#   ESTÁTICO — procura flag que só existe no GNU nos quatro executáveis. A `lib/core.sh` é
#              ISENTA: ela é justamente a camada que embrulha essas diferenças (`_b64enc`,
#              `_b64dec`, `_date2epoch`, `_mtime`, `_hash`, `_abspath`). Fora dela, use o helper.
#              ⚠ Roda tanto no repo quanto no ARTEFATO de dist — e no artefato a lib está
#              EMBUTIDA, então o bloco entre `@INLINE-BEGIN`/`@INLINE-END` é pulado; sem isso a
#              própria implementação do `_abspath` aparece como violação.
#   BSD FALSO — põe na frente do PATH um `base64` que se comporta como o da Apple antigo (sem
#              `-w`, sem arquivo posicional, sem `-d`; decodifica com `-D`) e prova o round-trip
#              pelos helpers. É o mais próximo de um Mac que se consegue sem um Mac.
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CLI="$(cd "$HERE/.." && pwd)"
ok=0; bad=0
chk(){ if eval "$2"; then echo "  ok: $1"; ((ok++)); else echo "  FALHA: $1"; ((bad++)); fi; }

echo "== ESTÁTICO: flag só-GNU fora da lib/core.sh =="
# padrão -> por que dói no BSD / o que usar
# ⚠ Um `X -flagGNU … || X -flagBSD …` (ou `|| echo`) NÃO é bug: é o fallback à mão, e há um
# caso em que ele é OBRIGATÓRIO — a resolução do próprio caminho (`readlink -f … || echo
# "$BASH_SOURCE"`) roda ANTES de a `core.sh` existir p/ oferecer `_abspath`. Já um
# `date -d … || die` não tem fallback nenhum: é quebra de verdade. A regra abaixo separa os
# dois pelo que vem depois do `||`.
declare -A GNU=(
  ['base64 +-w']='base64 -w não existe no BSD — use _b64enc'
  ['base64 +-d']='base64 -d só existe no macOS >= 12.3 — use _b64dec'
  ['stat +-c']='stat -c é GNU (BSD é -f) — use _mtime'
  ['readlink +-f']='readlink -f é GNU — use _abspath'
  ['md5sum']='md5sum não existe no BSD (é md5 -q) — use _hash'
  ['sed +-i +[^.]']='sed -i sem sufixo é GNU; no BSD exige argumento'
  ['date +-d ']='date -d é GNU (BSD é -j -f)'
  ['grep +-P']='grep -P é GNU'
  ['find .*-printf']='find -printf é GNU'
  ['xargs +-d']='xargs -d é GNU (use -0)'
  ['sort +-V']='sort -V é GNU'
)
# ⚠ o `||` que importa é o que vem DEPOIS da ferramenta, não o primeiro da linha: em
# `… && printf '%s' "$v" || date -d "$v" … || die`, olhar o primeiro `||` acha o `printf` e
# ABSOLVE um bug de verdade. (Foi o que aconteceu na 1ª versão deste teste.)
tem_fallback(){ # <linha> <ferramenta> — a alternativa IMEDIATA da ferramenta é um substituto?
  local t="$2" resto alt
  resto="${1#*$t}"
  [[ "$resto" == *"||"* ]] || return 1
  alt="${resto#*||}"
  # vale como substituto: a mesma ferramenta com a flag do BSD, um echo/printf, ou um helper da
  # própria core.sh (ex.: `readlink -f … || _abspath "$0"`)
  [[ "$alt" == *"$t"* || "$alt" == *echo* || "$alt" == *printf* || "$alt" == *_abspath* \
     || "$alt" == *_b64* || "$alt" == *_mtime* || "$alt" == *_hash* || "$alt" == *_date2epoch* ]]
}
# Corpo do executável SEM a camada de fallback. No REPO ela é o bloco `@INLINE-*`; no ARTEFATO
# o mkdist TIRA os marcadores, então o corte é pelas FUNÇÕES que a core.sh define — a
# implementação delas (`readlink -f … ; return`, `date -d …`) é a camada de compatibilidade, não
# uso indevido. ⚠ As linhas removidas viram VAZIAS, não somem: o `grep -n` depois relata o número
# de linha do arquivo de verdade (na 1ª versão elas sumiam e o número saía deslocado).
sem_lib(){
  local core="$CLI/lib/core.sh" fns=""
  [[ -f "$core" ]] && fns="$(grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$core" | tr -d '()' | paste -sd'|' -)"
  awk -v fns="$fns" '
    BEGIN{ if (fns != "") re = "^(" fns ")\\(\\)" }
    /@INLINE-BEGIN/ { s=1 }
    /@INLINE-END/   { s=0; print ""; next }
    {
      if (!s && re != "" && $0 ~ re) inf=1
      if (s || inf) { print "" } else { print }
      if (inf && /^\}/) inf=0
    }' "$1"
}
achou=0
for f in "$CLI"/moj "$CLI"/moj-comp "$CLI"/moj-contest "$CLI"/moj-judges; do
  [[ -f "$f" ]] || continue
  for pat in "${!GNU[@]}"; do
    tool="${pat%% *}"
    while IFS= read -r hit; do
      [[ -n "$hit" ]] || continue
      n="${hit%%:*}"; linha="${hit#*:}"
      [[ "$linha" =~ ^[[:space:]]*# ]] && continue
      tem_fallback "$linha" "$tool" && continue
      printf '  ACHADO %s:%s\n         %s\n         %s\n' \
        "$(basename "$f")" "$n" "${GNU[$pat]}" "$(printf '%s' "$linha" | sed 's/^[[:space:]]*//' | cut -c1-90)"
      achou=$((achou+1))
    done < <(sem_lib "$f" | grep -nE "$pat" 2>/dev/null)
  done
done
chk "nenhuma flag só-GNU SEM fallback nos executáveis" "[[ $achou -eq 0 ]]"

echo "== BSD FALSO: os helpers da core.sh sobrevivem a um base64 da Apple =="
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/base64" <<'STUB'
#!/bin/bash
# base64 da Apple ANTIGO: codifica de stdin ou -i ARQ; decodifica com -D; sem -w, -d, posicional
real=/usr/bin/base64; mode=enc; infile=""
while (( $# )); do
  case "$1" in
    -w*) echo "base64: invalid option -- 'w'" >&2; exit 64 ;;
    -d)  echo "base64: invalid option -- 'd'" >&2; exit 64 ;;
    -D)  mode=dec ;;
    -i)  shift; infile="$1" ;;
    -*)  echo "base64: illegal option $1" >&2; exit 64 ;;
    *)   echo "base64: positional file not supported" >&2; exit 64 ;;
  esac; shift
done
if [[ "$mode" == dec ]]; then exec "$real" -d
elif [[ -n "$infile" ]]; then exec "$real" < "$infile"
else exec "$real"; fi
STUB
chmod +x "$T/base64"
# amostras que já pegaram bug: binário com NUL, vazio, UTF-8 com byte alto, os dois paddings
head -c 200000 /dev/urandom > "$T/bin"
: > "$T/vazio"
printf 'acentua\303\247\303\243o \342\200\224 \000\001\377 fim\n' > "$T/misto"
head -c 3 /dev/urandom > "$T/pad3"; head -c 1 /dev/urandom > "$T/pad1"

for amostra in bin vazio misto pad3 pad1; do
  gnu="$(PATH=/usr/bin:/bin bash -c "source '$CLI/lib/core.sh' 2>/dev/null; _b64enc '$T/$amostra'")"
  bsd="$(PATH="$T:$PATH" bash -c "source '$CLI/lib/core.sh' 2>/dev/null; _b64enc '$T/$amostra'")"
  chk "encode $amostra: BSD == GNU" '[[ "$gnu" == "$bsd" ]]'
  # ⚠ o b64 de 200 KB vai por ARQUIVO: por argv estoura o ARG_MAX (bati nisso escrevendo o teste)
  printf '%s' "$bsd" > "$T/b64in"
  PATH="$T:$PATH" bash -c "source '$CLI/lib/core.sh' 2>/dev/null; _b64dec < '$T/b64in'" > "$T/rt"
  chk "round-trip $amostra sob BSD"  'cmp -s "$T/$amostra" "$T/rt"'
done

echo '== BSD FALSO: data (o "date -d" do moj-contest, que agenda a prova) =='
cat > "$T/date" <<'DSTUB'
#!/bin/bash
# date do BSD/macOS: não tem -d; converte com -j -f <formato>
real=/usr/bin/date
if [[ "${1:-}" == "-d" ]]; then echo "date: illegal option -- d" >&2; exit 1; fi
if [[ "${1:-}" == "-j" && "${2:-}" == "-f" ]]; then
  fmt="$3"; val="$4"; out="${5:-+%s}"
  exec "$real" --date="$(printf '%s' "$val")" "$out" 2>/dev/null || exit 1
fi
exec "$real" "$@"
DSTUB
chmod +x "$T/date"
printf '  (stub: -d recusado; -j -f aceito)\n'
for d in '2026-08-25 14:00' '2026-08-25 14:00:30'; do
  gnu="$(PATH=/usr/bin:/bin bash -c "source '$CLI/lib/core.sh' 2>/dev/null; _date2epoch '$d'")"
  bsd="$(PATH="$T:$PATH" bash -c "source '$CLI/lib/core.sh' 2>/dev/null; _date2epoch '$d'")"
  chk "data '$d': BSD == GNU" '[[ -n "$gnu" && "$gnu" == "$bsd" ]]'
done
# e o jeito ANTIGO (date -d cru) morre no stub — era o `moj-contest rounds` inutilizável no Mac
PATH="$T:$PATH" date -d '2026-08-25 14:00' +%s >/dev/null 2>&1; drc=$?
chk "o 'date -d' cru realmente falha no BSD" '[[ $drc -ne 0 ]]'

# e a regressão exata do PR #1: o código que estava no cmd_testrun morre sob BSD
PATH="$T:$PATH" bash -c '
  set -euo pipefail
  base64 -w0 "$1" > "$2" 2>/dev/null || base64 "$1" | tr -d "\n" > "$2"' _ "$T/misto" "$T/velho.b64" 2>/dev/null
rc=$?
chk "o jeito ANTIGO realmente quebra no BSD (rc!=0 ou saída vazia)" \
    '[[ $rc -ne 0 || ! -s "$T/velho.b64" ]]'

echo ""; echo "RESULT: $ok ok, $bad falha(s)"; exit $(( bad > 0 ))
