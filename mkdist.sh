#!/bin/bash
# mkdist.sh — gera dist/{moj,moj-contest} AUTO-CONTIDOS: troca o bloco entre os marcadores
# `# @INLINE-BEGIN` e `# @INLINE-END` pelo conteúdo de lib/core.sh. Mantém a instalação por
# curl de UM arquivo (servidos como cdmoj/web/moj e cdmoj/web/moj-contest — ver
# cdmoj/docs/DEPLOY.md). Roda bash -n em cada artefato.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
[[ -f lib/core.sh ]] || { echo "mkdist: lib/core.sh não encontrada" >&2; exit 1; }
mkdir -p dist
# carimbo de build: <git-short>-<data-do-commit> (fallback data de hoje fora de git). É o que o
# `moj version`/`doctor` comparam com o /moj.build servido — o cli-dist do cdmoj copia
# dist/moj.build p/ web/moj.build junto com os artefatos.
BUILD="$(git log -1 --format='%h-%cd' --date=format:%Y%m%d 2>/dev/null || true)"
[[ -n "$BUILD" ]] || BUILD="nogit-$(date +%Y%m%d)"
for tool in moj moj-contest moj-judges; do
  [[ -f "$tool" ]] || { echo "mkdist: pulando $tool (não existe)"; continue; }
  grep -q '^# @INLINE-BEGIN' "$tool" || { echo "mkdist: $tool sem marcador @INLINE-BEGIN" >&2; exit 1; }
  awk 'BEGIN{skip=0}
    /^# @INLINE-BEGIN/{skip=1; while ((getline l < "lib/core.sh") > 0) print l; close("lib/core.sh"); next}
    /^# @INLINE-END/{skip=0; next}
    skip==0{print}' "$tool" \
  | sed "s/^MOJ_CLI_BUILD=\"dev\"\$/MOJ_CLI_BUILD=\"$BUILD\"/" > "dist/$tool"
  chmod +x "dist/$tool"
  bash -n "dist/$tool"
  grep -q "^MOJ_CLI_BUILD=\"$BUILD\"\$" "dist/$tool" || { echo "mkdist: $tool sem carimbo de build" >&2; exit 1; }
  echo "dist/$tool OK ($(wc -c < "dist/$tool") bytes, build $BUILD)"
done
printf '%s\n' "$BUILD" > dist/moj.build
echo "dist/moj.build = $BUILD"
