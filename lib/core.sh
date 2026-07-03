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
MOJ_URL="${MOJ_URL:-https://moj.naquadah.com.br}"
CONTEST="${MOJ_CONTEST:-treino}"
CFG="${MOJ_CONFIG_DIR:-$HOME/.config/moj}"
ED="${EDITOR:-${VISUAL:-}}"; [[ -n "$ED" ]] || { command -v nano >/dev/null && ED=nano || ED=vi; }
HDR=(); [[ -n "${MOJ_HOST:-}" ]] && HDR=(-H "Host: $MOJ_HOST")
die(){ printf '%s: %s\n' "$MOJ_TOOL" "$*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
have jq || die "preciso do 'jq'."; have curl || die "preciso do 'curl'."

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
  cf="$CFG/cache/$(printf '%s' "$p" | md5sum 2>/dev/null | cut -c1-24).json"
  age=$(( $(date +%s) - $(stat -c %Y "$cf" 2>/dev/null || echo 0) ))
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
