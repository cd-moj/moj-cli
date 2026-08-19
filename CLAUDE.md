# moj-cli — CLI de autoria de problemas

`moj` é a CLI de autoria de problemas do MOJ: **sem git, sem chave — só o seu login do MOJ**.
Espelha o editor web falando com a mesma API (`/api/v1/problems/*`). Repo git próprio.
**Ver `README.md`** e o cabeçalho do script `moj` (lista completa de subcomandos).
Workspace multi-repo: ver `../CLAUDE.md`.

- Dois fluxos: **interativo** (`moj edit <id|pasta>`, campos como na web) ou **arquivos locais**
  (`moj clone <id>` … edita … `moj push`). Também: `login/whoami`, `ls`, `board` (painel dos seus
  problemas + o que revisar), `new`, `test`, `preview`, `download/upload`, `public`, `publish`
  (público => o servidor **valida + calibra**, via `set-public`), `calibrate`, `status [<id>]` /
  `check <id>` (QA: validação + TL por juiz + solução good sem TL / falhou em todas as máquinas),
  `calibrate` (global, `--hosts/--all-judges/--per-cpu` = direcionada como na web, `--judges` =
  lista do parque, `--all-stale` = lote), `calib` (a calibração POR EXTENSO, por juiz/solução/teste — `--json` p/ ferramentas externas),
  `calib-report` (baixa o report.html de uma solução calibrada), `testrun`/`testrun-status`
  (roda UMA solução avulsa NO JUIZ, fora do history — exige permissão de edição),
  `share` (= adiciona membro à org), `org` (list/create/members/public/rm — **ACESSO**: a org é o
  `<org>` do id; membros escrevem, admins mexem na trava de público; `rm` só org **vazia**),
  `mv <id> <org>` (move rascunho, muda o id), `collection` (ls/create/show/add/remove/rename/delete — **COLEÇÃO = tag de agrupamento**,
  m:n, ORTOGONAL à org; nome pode ter espaços; curada: só marca em coleção existente).
- Config por ambiente: `MOJ_URL` (default `https://moj.naquadah.com.br`), `MOJ_HOST` (header
  `Host` p/ teste local), `EDITOR`.
- É um **cliente** da API — não tem lógica de julgamento própria. **O formato de pacote tem fonte
  única: `cdmoj/docs/PACOTE.md`** (inclusive o `.moj-id`, que é ESTE repo quem escreve e que **não**
  sobe ao servidor). **Título = campo** (`.moj-id` `.title` → `display_title`), **não** o `% Título`
  do texto (legado); por isso `push`/`upload` exigem título.
- **Mexeu no formato do pacote?** Atualize o **`cdmoj/docs/PACOTE.md`** (fonte única) no mesmo commit;
  o `README.md` daqui só resume e aponta p/ ele — não redescreva o formato (a divergência de cópias
  já gerou o bug do título vazio).
- **Camadas**: `moj` (autoria de problemas) + `moj-contest` (gestão de contest) + `moj-judges`
  (gerência fina dos juízes: slots/particionamento, config por juiz, relatório de correções —
  sessão `.admin` do treino) compartilham o núcleo SOURCED `lib/core.sh` (config/env,
  `api()`/cache/`http_code`/`api_post_file`, e o **token POR CONTEST** em
  `~/.config/moj/token-<contest>`, com fallback legado `token` p/ o treino). `moj <camada> …`
  delega ao executável `moj-<camada>` (ao lado do script ou no PATH) — padrão p/ camadas
  futuras. `bash -euo pipefail` em todos; `bash -n` antes de commitar.
- **Distribuição continua de 1 arquivo**: `bash mkdist.sh` embute a lib nos artefatos
  `dist/{moj,moj-contest,moj-judges}` (marcadores `# @INLINE-BEGIN/END`); são ELES que o cdmoj
  serve em `web/moj*` (ver `cdmoj/docs/DEPLOY.md`). Nunca copie o script do repo direto.
  **O `make deploy` do cdmoj sincroniza sozinho** (alvo `cli-dist` roda o mkdist do checkout
  irmão e copia o que divergir) — mudou a CLI, o próximo deploy embarca.
- Pegadinha de bash: `local a=x b=$a` NÃO funciona com `set -u` (o `local` expande os argumentos
  antes de atribuir) — declare e atribua em comandos separados.
- Pegadinha de bash 2: função que termina num laço `while` cujo corpo acaba em `[[ … ]] && {…}`
  VAZA rc 1 quando a última iteração não casa — e `x="$(essa_funcao)"` sob `set -e` mata o
  processo MUDO (foi o `moj test --run` parando sem mensagem depois do pré-voo). Função-leitora
  termina com `return 0` explícito; atribuição de comando que pode falhar leva `|| true`.
- **`moj test --run` só se testa DE VERDADE em máquina com bwrap REAL** (o dev tem fbwrap e morre
  antes do caminho de julgamento — use o juiz de produção como bancada: copie o pacote + mojtools
  p/ ~ribas e rode com `CAGE_ROOT` apontando p/ a rootfs).
- Pegadinha de LOCALE: a CLI roda na máquina do USUÁRIO — awk numérico SEM `LC_ALL=C` quebra em
  pt_BR: no mawk (o awk default do Ubuntu) `"0.21"+0 == 0` (strtod espera vírgula) e `%f` imprime
  vírgula (foi o "pior 0,00s" do relato do Edson; gawk não reproduz — ignora locale sem
  --use-lc-numeric). TODO awk/printf de número com ponto leva `LC_ALL=C` na frente.
- Rodapé de commit: **só** `Co-Authored-By:`, **nunca** uma linha `Claude-Session:` (ruído no histórico).
- **Doc junto com o código** (doc atrasada = bug): mudou subcomando/contrato? atualize o `README.md`, o
  cabeçalho de `moj` e `cdmoj/docs/API.md` (+ `openapi.json`) no mesmo commit.
