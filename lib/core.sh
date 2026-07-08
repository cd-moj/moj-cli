# moj-cli/lib/core.sh — núcleo COMPARTILHADO das CLIs do MOJ (moj, moj-contest, camadas
# futuras). SOURCED pelos scripts no repo (dev) e EMBUTIDO nos artefatos de 1 arquivo pelo
# mkdist.sh (instalação por curl continua de arquivo único) — por isso SEM shebang e SEM set.
#
# Config por ambiente: MOJ_URL (default https://moj.naquadah.com.br), MOJ_CONTEST (contest da
# sessão; default treino), MOJ_CONFIG_DIR, MOJ_HOST (header Host p/ teste local), MOJ_NO_CACHE.
# O chamador pode definir MOJ_TOOL (nome exibido nos erros) ANTES de sourcear.
#
# TOKEN POR CONTEST: $CFG/token-<contest> — o moj-contest loga em vários contests sem
# atropelar a sessão do treino. Fallback legado: $CFG/token (só p/ treino; zero migração).

MOJ_TOOL="${MOJ_TOOL:-moj}"
die(){ printf '%s: %s\n' "$MOJ_TOOL" "$*" >&2; exit 1; }
# bash>=4 ANTES de qualquer bashismo (mapfile, read -i, ${x^^}): o /bin/bash do macOS é 3.2
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || die "preciso de bash >= 4 (macOS: brew install bash e rode com ele)"
MOJ_URL="${MOJ_URL:-https://moj.naquadah.com.br}"
CONTEST="${MOJ_CONTEST:-treino}"
CFG="${MOJ_CONFIG_DIR:-$HOME/.config/moj}"
ED="${EDITOR:-${VISUAL:-}}"; [[ -n "$ED" ]] || { command -v nano >/dev/null && ED=nano || ED=vi; }
HDR=(); [[ -n "${MOJ_HOST:-}" ]] && HDR=(-H "Host: $MOJ_HOST")
have(){ command -v "$1" >/dev/null 2>&1; }
have jq || die "preciso do 'jq'."; have curl || die "preciso do 'curl'."

# ---- helpers PORTÁVEIS (Linux/GNU e macOS/BSD) --------------------------------------------
# base64 de um arquivo, SEM quebra de linha (GNU: -w0; BSD não tem -w e não quebra por default)
_b64enc(){ base64 -w0 < "$1" 2>/dev/null || base64 < "$1" | tr -d '\n'; }
# decode de base64 do stdin (GNU: -d; macOS/BSD: -D)
_b64dec(){ if base64 -d </dev/null >/dev/null 2>&1; then base64 -d; else base64 -D; fi; }
# mtime em epoch (GNU stat -c %Y; BSD stat -f %m)
_mtime(){ stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }
# hash curto de uma string (md5sum GNU; md5 -q BSD; shasum último recurso)
_hash(){ { md5sum 2>/dev/null || md5 -q 2>/dev/null || shasum 2>/dev/null; } <<<"$1" | cut -d' ' -f1 | cut -c1-24; }
# caminho absoluto resolvendo symlinks (GNU readlink -f; fallback cd/pwd -P + readlink em loop)
_abspath(){
  if readlink -f "$1" >/dev/null 2>&1; then readlink -f "$1"; return; fi
  local t="$1" d b i=0
  while [[ -L "$t" && $i -lt 40 ]]; do d="$(cd "$(dirname "$t")" && pwd -P)"; t="$(readlink "$t")"
    [[ "$t" == /* ]] || t="$d/$t"; i=$((i+1)); done
  printf '%s/%s' "$(cd "$(dirname "$t")" && pwd -P)" "$(basename "$t")"
}
# epoch -> data legível (GNU date -d @N; BSD date -r N); falha = ecoa o epoch
_fmt_epoch(){ date -d "@$1" "${2:-+%d/%m %H:%M}" 2>/dev/null || date -r "$1" "${2:-+%d/%m %H:%M}" 2>/dev/null || echo "$1"; }

# ---- saída crua (--json): flag global tratada pelo chamador; out() imprime JSON cru quando
# RAW=1, senão aplica o filtro jq -r legível. (Antes só o moj-contest tinha.)
RAW="${RAW:-0}"
out(){ if [[ "$RAW" == 1 ]]; then cat; else jq -r "$1"; fi; }

# ---- mojtools local (comandos de autoria que rodam NA MÁQUINA: checker/interactive/test --run)
# Ordem: $MOJTOOLS_DIR -> irmão do checkout da CLI -> ~/moj/mojtools. die com dica de clone.
mojtools_dir(){
  local c
  for c in "${MOJTOOLS_DIR:-}" "$(dirname "$(_abspath "${BASH_SOURCE[1]:-$0}")")/../mojtools" "$HOME/moj/mojtools"; do
    [[ -n "$c" && -f "$c/build-and-test.sh" ]] && { _abspath "$c"; return 0; }
  done
  die "mojtools não encontrado — clone github.com/cd-moj/mojtools e exporte MOJTOOLS_DIR=<caminho>"
}

# token_file [contest] -> caminho do token daquela sessão (não cria nada)
# (local a=x b=$a NÃO funciona com set -u: o `local` expande os argumentos antes de atribuir)
token_file(){ local c f; c="${1:-$CONTEST}"; f="$CFG/token-$c"
  [[ -f "$f" ]] && { printf '%s' "$f"; return; }
  [[ "$c" == treino && -f "$CFG/token" ]] && { printf '%s' "$CFG/token"; return; }
  printf '%s' "$f"; }
# token_save [contest]  (token no stdin) — grava com umask 077
token_save(){ local c="${1:-$CONTEST}"; mkdir -p "$CFG"; chmod 700 "$CFG" 2>/dev/null || true
  ( umask 077; cat > "$CFG/token-$c" ); }
token_drop(){ local c="${1:-$CONTEST}"; rm -f "$CFG/token-$c"; [[ "$c" == treino ]] && rm -f "$CFG/token"; return 0; }
need_login(){ [[ -f "$(token_file)" ]] || die "faça '$MOJ_TOOL login' primeiro."; }

api(){ # api METHOD PATH [json] -> corpo JSON (erro -> die). Token resolvido POR CHAMADA.
  local m="$1" p="$2" data="${3:-}" auth=() out code tmp tf; tmp="$(mktemp)"; tf="$(token_file)"
  [[ -f "$tf" ]] && auth=(-H "Authorization: Bearer $(cat "$tf")")
  if [[ -n "$data" ]]; then code="$(printf '%s' "$data" | curl -sS -o "$tmp" -w '%{http_code}' "${HDR[@]}" "${auth[@]}" -X "$m" -H 'Content-Type: application/json' --data-binary @- "$MOJ_URL/api/v1$p" 2>/dev/null || true)"
  else code="$(curl -sS -o "$tmp" -w '%{http_code}' "${HDR[@]}" "${auth[@]}" -X "$m" "$MOJ_URL/api/v1$p" 2>/dev/null || true)"; fi
  out="$(cat "$tmp")"; rm -f "$tmp"
  [[ "$code" =~ ^2 ]] && { printf '%s' "$out"; return 0; }
  die "$(jq -r '.error.message // .message // empty' <<<"$out" 2>/dev/null || true)${code:+ ($code)}"
}
# cache local de GET: devolve o que está salvo se ainda fresco (TTL s); senão busca e grava.
# Evita repetir round-trips caros. MOJ_NO_CACHE=1 ignora o cache.
api_get_cached(){ local ttl="$1" p="$2" cf age out
  [[ "${MOJ_NO_CACHE:-0}" == 1 ]] && { api GET "$p"; return; }
  cf="$CFG/cache/$(_hash "$p").json"
  age=$(( $(date +%s) - $(_mtime "$cf") ))
  if [[ -f "$cf" ]] && (( age < ttl )); then cat "$cf"; return 0; fi
  out="$(api GET "$p")" || return 1
  ( umask 077; mkdir -p "$(dirname "$cf")" 2>/dev/null; printf '%s' "$out" > "$cf" ) 2>/dev/null
  printf '%s' "$out"; }
http_code(){ local m="$1" p="$2" auth=() tf; tf="$(token_file)"
  [[ -f "$tf" ]] && auth=(-H "Authorization: Bearer $(cat "$tf")")
  curl -sS -o /dev/null -w '%{http_code}' "${HDR[@]}" "${auth[@]}" -X "$m" "$MOJ_URL/api/v1$p" 2>/dev/null || echo 000; }
api_post_file(){ # api_post_file PATH BODYFILE -> POST grande (corpo via arquivo; evita ARG_MAX)
  local p="$1" f="$2" auth=() out code tmp tf; tmp="$(mktemp)"; tf="$(token_file)"
  [[ -f "$tf" ]] && auth=(-H "Authorization: Bearer $(cat "$tf")")
  code="$(curl -sS -o "$tmp" -w '%{http_code}' "${HDR[@]}" "${auth[@]}" -X POST -H 'Content-Type: application/json' --data-binary @"$f" "$MOJ_URL/api/v1$p" 2>/dev/null || true)"
  out="$(cat "$tmp")"; rm -f "$tmp"
  [[ "$code" =~ ^2 ]] && { printf '%s' "$out"; return 0; }
  die "$(jq -r '.error.message // .message // empty' <<<"$out" 2>/dev/null || true)${code:+ ($code)}"
}
# download autenticado p/ arquivo: api_get_to_file PATH DESTFILE (falha -> die)
api_get_to_file(){ local p="$1" dest="$2" auth=() code tf; tf="$(token_file)"
  [[ -f "$tf" ]] && auth=(-H "Authorization: Bearer $(cat "$tf")")
  code="$(curl -sS -o "$dest" -w '%{http_code}' "${HDR[@]}" "${auth[@]}" "$MOJ_URL/api/v1$p" 2>/dev/null || true)"
  [[ "$code" =~ ^2 ]] || { [[ -f "$dest" ]] && rm -f "$dest"; die "download falhou${code:+ ($code)}"; }
}
enc(){ jq -rn --arg s "$1" '$s|@uri'; }
slurp(){ [[ -f "$1" ]] && jq -Rs . < "$1" || printf '""'; }
pause(){ read -rsp "  (enter p/ continuar) " _ </dev/tty; echo; }
ask(){ local p="$1" def="${2:-}" v; read -e -i "$def" -r -p "$p" v </dev/tty || true; printf '%s' "$v"; }
