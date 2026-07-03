#!/bin/bash
# mkdist.sh — gera dist/{moj,moj-contest} AUTO-CONTIDOS: troca o bloco entre os marcadores
# `# @INLINE-BEGIN` e `# @INLINE-END` pelo conteúdo de lib/core.sh. Mantém a instalação por
# curl de UM arquivo (servidos como cdmoj/web/moj e cdmoj/web/moj-contest — ver
# cdmoj/docs/DEPLOY.md). Roda bash -n em cada artefato.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
[[ -f lib/core.sh ]] || { echo "mkdist: lib/core.sh não encontrada" >&2; exit 1; }
mkdir -p dist
for tool in moj moj-contest; do
  [[ -f "$tool" ]] || { echo "mkdist: pulando $tool (não existe)"; continue; }
  grep -q '^# @INLINE-BEGIN' "$tool" || { echo "mkdist: $tool sem marcador @INLINE-BEGIN" >&2; exit 1; }
  awk 'BEGIN{skip=0}
    /^# @INLINE-BEGIN/{skip=1; while ((getline l < "lib/core.sh") > 0) print l; close("lib/core.sh"); next}
    /^# @INLINE-END/{skip=0; next}
    skip==0{print}' "$tool" > "dist/$tool"
  chmod +x "dist/$tool"
  bash -n "dist/$tool"
  echo "dist/$tool OK ($(wc -c < "dist/$tool") bytes)"
done
