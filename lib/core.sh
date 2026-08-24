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
# carimbo de build: "dev" no repo; o mkdist.sh troca pelo <git-short>-<data> nos artefatos
# distribuídos (é o que `moj version`/`doctor` comparam com o /moj.build do servidor)
MOJ_CLI_BUILD="dev"
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
# _b64tmp <arquivo> -> ecoa o caminho de um TEMP com o base64 do arquivo, p/ entrar no jq por
# `--rawfile`. ⚠ NUNCA passe base64 por `--arg`: o Linux limita um argumento a 128 KiB e um PDF
# de caderno (500 KB -> 665 KB em base64) mata o jq com "Argument list too long" — o mesmo
# tropeço que o /submit e o /contest/admin/users já levaram no servidor. Quem chama apaga.
_b64tmp(){ local t; t="$(mktemp)" || return 1; _b64enc "$1" > "$t" || { rm -f "$t"; return 1; }; printf '%s' "$t"; }
# decode de base64 do stdin (GNU: -d; macOS/BSD: -D)
_b64dec(){ if base64 -d </dev/null >/dev/null 2>&1; then base64 -d; else base64 -D; fi; }
# epoch de uma data legível. GNU: `date -d` aceita quase tudo. BSD/macOS NÃO tem `-d` — tem
# `-j -f <formato>`, que EXIGE o formato exato, então tentamos os que a CLI documenta.
# ⚠ O ramo GNU vem PRIMEIRO: no Linux o resultado é o de sempre, byte a byte.
# ⚠ No BSD, formato só-data ("YYYY-MM-DD") herda a HORA ATUAL (o GNU usa 00:00) — por isso a
# forma documentada leva HH:MM, e é a que casa igual nos dois.
_date2epoch(){
  local v="$1" e f
  e="$(date -d "$v" +%s 2>/dev/null)" && [[ -n "$e" ]] && { printf '%s' "$e"; return 0; }
  for f in '%Y-%m-%d %H:%M:%S' '%Y-%m-%d %H:%M' '%Y-%m-%d'; do
    e="$(date -j -f "$f" "$v" +%s 2>/dev/null)" && [[ -n "$e" ]] && { printf '%s' "$e"; return 0; }
  done
  return 1
}
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

# ---- mojtools local (comandos de autoria que rodam NA MÁQUINA: checker/interactive/fn/test --run)
# Ordem: $MOJTOOLS_DIR -> irmão do checkout da CLI -> ~/moj/mojtools. die com dica de clone.
mojtools_dir(){
  local c
  [[ -n "${MOJTOOLS_DIR:-}" && ! -f "${MOJTOOLS_DIR}/build-and-test.sh" ]] \
    && echo "$MOJ_TOOL: ⚠ MOJTOOLS_DIR aponta p/ caminho inválido ($MOJTOOLS_DIR) — tentando os fallbacks" >&2
  for c in "${MOJTOOLS_DIR:-}" "$(dirname "$(_abspath "${BASH_SOURCE[1]:-$0}")")/../mojtools" "$HOME/moj/mojtools"; do
    [[ -n "$c" && -f "$c/build-and-test.sh" ]] && { _abspath "$c"; return 0; }
  done
  die "mojtools não encontrado — só é preciso p/ checker/interactive/fn/test --run: git clone https://github.com/cd-moj/mojtools ~/moj/mojtools (ou exporte MOJTOOLS_DIR). Diagnóstico: $MOJ_TOOL doctor"
}

# ---- versão / auto-atualização (comuns a TODAS as camadas: moj, moj-contest, moj-judges,
# moj-comp). O carimbo MOJ_CLI_BUILD (topo) casa com o /moj.build servido; cmd_update baixa
# os artefatos servidos e troca no lugar (usa $0 — vale no repo E no artefato inlined).
_server_build(){ curl -fsS --max-time 3 "${HDR[@]}" "$MOJ_URL/moj.build" 2>/dev/null | head -1 || true; }
cmd_version(){ local srv
  echo "$MOJ_TOOL build: $MOJ_CLI_BUILD"
  srv="$(_server_build)"
  if [[ -n "$srv" ]]; then
    echo "servidor ($MOJ_URL): build $srv"
    [[ "$MOJ_CLI_BUILD" == dev || "$MOJ_CLI_BUILD" == "$srv" ]] || echo "  ⚠ DESATUALIZADO — rode: $MOJ_TOOL update"
  else
    echo "servidor ($MOJ_URL): build indisponível"
  fi }
cmd_update(){ local self dir t dst tmp new nup=0 old="$MOJ_CLI_BUILD"
  self="$(readlink -f "$(_abspath "$0")" 2>/dev/null || _abspath "$0")"
  dir="$(dirname "$self")"
  for t in moj moj-contest moj-judges moj-comp; do
    dst="$dir/$t"
    [[ "$t" == "${self##*/}" || -f "$dst" ]] || continue     # o próprio + as camadas presentes
    tmp="$(mktemp "$dst.new.XXXXXX" 2>/dev/null)" || die "sem permissão de escrita em $dir — rode: sudo $MOJ_TOOL update"
    curl -fsS --max-time 60 "${HDR[@]}" -o "$tmp" "$MOJ_URL/$t" || { rm -f "$tmp"; die "download falhou: $MOJ_URL/$t"; }
    bash -n "$tmp" 2>/dev/null || { rm -f "$tmp"; die "artefato baixado inválido ($t) — nada foi trocado"; }
    chmod +x "$tmp"; mv -f "$tmp" "$dst"
    nup=$((nup+1))
  done
  new="$(grep -m1 '^MOJ_CLI_BUILD=' "$dir/${self##*/}" 2>/dev/null | cut -d'"' -f2)"
  echo "atualizado: $nup artefato(s) em $dir (build $old -> ${new:-?})"; }

# token_file [contest] -> caminho do token daquela sessão (não cria nada)
# (local a=x b=$a NÃO funciona com set -u: o `local` expande os argumentos antes de atribuir)
token_file(){ local c f; c="${1:-$CONTEST}"; f="$CFG/token-$c"
  [[ -f "$f" ]] && { printf '%s' "$f"; return; }
  [[ "$c" == treino && -f "$CFG/token" ]] && { printf '%s' "$CFG/token"; return; }
  printf '%s' "$f"; }
# token_save [contest]  (token no stdin) — grava com umask 077 (+ o header-file do curl)
token_save(){ local c="${1:-$CONTEST}"; mkdir -p "$CFG"; chmod 700 "$CFG" 2>/dev/null || true
  ( umask 077; cat > "$CFG/token-$c"
    printf 'Authorization: Bearer %s' "$(cat "$CFG/token-$c")" > "$CFG/hdr-$c" ); }
token_drop(){ local c="${1:-$CONTEST}"; rm -f "$CFG/token-$c" "$CFG/hdr-$c"
  [[ "$c" == treino ]] && rm -f "$CFG/token" "$CFG/hdr"; return 0; }
need_login(){ [[ -f "$(token_file)" ]] || die "faça '$MOJ_TOOL login' primeiro."; }
# auth_hdr_file [contest] -> header-file p/ `curl -H @arquivo`: o token NUNCA vai no argv
# (o -H "…Bearer …" aparece no ps/cmdline p/ qualquer usuário — ruim em máquina de lab).
# Migração preguiçosa: sessão antiga (só token-<c>) ganha o hdr na 1ª chamada.
auth_hdr_file(){ local c tf h; c="${1:-$CONTEST}"; tf="$(token_file "$c")"; h="$CFG/hdr-$c"
  [[ -f "$tf" ]] || return 1
  if [[ ! -f "$h" || "$h" -ot "$tf" ]]; then
    ( umask 077; printf 'Authorization: Bearer %s' "$(cat "$tf")" > "$h" ) 2>/dev/null || return 1
  fi
  printf '%s' "$h"; }

# _api_fail <http-code> <corpo> — mensagem de erro ÚTIL. Quando o corpo NÃO é JSON (a página de erro
# do NGINX: 504/502/413), o `jq` saía vazio e o usuário via só "moj:  (504)" — sem pista nenhuma, e
# sem saber que num timeout o servidor pode ter aplicado o pedido PELA METADE.
# Com API_SOFT=1 não mata: só devolve !=0 (o chamador trata o código; ver o 409 do push).
_api_fail(){
  local code="$1" out="$2" msg
  msg="$(jq -r '.error.message // .message // empty' <<<"$out" 2>/dev/null || true)"
  if [[ -z "$msg" ]]; then
    case "$code" in
      504|502) msg="o servidor passou do tempo-limite — o pedido PODE ter sido aplicado pela metade; confira com '$MOJ_TOOL info <id>' antes de repetir";;
      413)     msg="pacote grande demais p/ o servidor (client_max_body_size)";;
      000|'')  msg="não consegui falar com $MOJ_URL (rede? URL?)";;
      *)       msg="erro do servidor (resposta não-JSON)";;
    esac
  fi
  [[ "${API_SOFT:-0}" == 1 ]] && return 1
  die "$msg${code:+ ($code)}"
}
api(){ # api METHOD PATH [json] -> corpo JSON (erro -> die). Token resolvido POR CHAMADA.
  local m="$1" p="$2" data="${3:-}" auth=() out code tmp hf; tmp="$(mktemp)"
  hf="$(auth_hdr_file 2>/dev/null || true)"; [[ -n "$hf" ]] && auth=(-H "@$hf")
  if [[ -n "$data" ]]; then code="$(printf '%s' "$data" | curl -sS -o "$tmp" -w '%{http_code}' "${HDR[@]}" "${auth[@]}" -X "$m" -H 'Content-Type: application/json' --data-binary @- "$MOJ_URL/api/v1$p" 2>/dev/null || true)"
  else code="$(curl -sS -o "$tmp" -w '%{http_code}' "${HDR[@]}" "${auth[@]}" -X "$m" "$MOJ_URL/api/v1$p" 2>/dev/null || true)"; fi
  out="$(cat "$tmp")"; rm -f "$tmp"
  [[ "$code" =~ ^2 ]] && { printf '%s' "$out"; return 0; }
  _api_fail "$code" "$out"
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
http_code(){ local m="$1" p="$2" auth=() hf
  hf="$(auth_hdr_file 2>/dev/null || true)"; [[ -n "$hf" ]] && auth=(-H "@$hf")
  curl -sS -o /dev/null -w '%{http_code}' "${HDR[@]}" "${auth[@]}" -X "$m" "$MOJ_URL/api/v1$p" 2>/dev/null || echo 000; }
api_post_file(){ # api_post_file PATH BODYFILE -> POST grande (corpo via arquivo; evita ARG_MAX)
  # NUNCA chame dentro de um pipe (`api_post_file … | jq`): o `die` mata só o subshell, o `jq` da
  # ponta sai 0 e o push FALHAVA COM rc=0 — script nenhum detectava. Use `resp="$(api_post_file …)"`.
  local p="$1" f="$2" auth=() out code tmp hf; tmp="$(mktemp)"
  hf="$(auth_hdr_file 2>/dev/null || true)"; [[ -n "$hf" ]] && auth=(-H "@$hf")
  code="$(curl -sS -o "$tmp" -w '%{http_code}' "${HDR[@]}" "${auth[@]}" -X POST -H 'Content-Type: application/json' --data-binary @"$f" "$MOJ_URL/api/v1$p" 2>/dev/null || true)"
  out="$(cat "$tmp")"; rm -f "$tmp"
  API_LAST_CODE="$code"
  API_LAST_BODY="$out"   # com API_SOFT=1 o _api_fail não imprime: o chamador lê a msg daqui
  [[ "$code" =~ ^2 ]] && { printf '%s' "$out"; return 0; }
  _api_fail "$code" "$out"
}
# download autenticado p/ arquivo: api_get_to_file PATH DESTFILE (falha -> die)
api_get_to_file(){ local p="$1" dest="$2" auth=() code hf
  hf="$(auth_hdr_file 2>/dev/null || true)"; [[ -n "$hf" ]] && auth=(-H "@$hf")
  code="$(curl -sS -o "$dest" -w '%{http_code}' "${HDR[@]}" "${auth[@]}" "$MOJ_URL/api/v1$p" 2>/dev/null || true)"
  [[ "$code" =~ ^2 ]] || { [[ -f "$dest" ]] && rm -f "$dest"; die "download falhou${code:+ ($code)}"; }
}
enc(){ jq -rn --arg s "$1" '$s|@uri'; }
slurp(){ [[ -f "$1" ]] && jq -Rs . < "$1" || printf '""'; }
pause(){ read -rsp "  (enter p/ continuar) " _ </dev/tty; echo; }
ask(){ local p="$1" def="${2:-}" v; read -e -i "$def" -r -p "$p" v </dev/tty || true; printf '%s' "$v"; }
