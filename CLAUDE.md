# moj-cli — CLI de autoria de problemas

`moj` é a CLI de autoria de problemas do MOJ: **sem git, sem chave — só o seu login do MOJ**.
Espelha o editor web falando com a mesma API (`/api/v1/problems/*`). Repo git próprio.
**Ver `README.md`** e o cabeçalho do script `moj` (lista completa de subcomandos).
Workspace multi-repo: ver `../CLAUDE.md`.

- Dois fluxos: **interativo** (`moj edit <id|pasta>`, campos como na web) ou **arquivos locais**
  (`moj clone <id>` … edita … `moj push`). Também: `login/whoami`, `ls`, `board` (painel dos seus
  problemas + o que revisar), `new`, `test`, `preview`, `download/upload`, `public`, `publish`
  (público => o servidor **valida + calibra**, via `set-public`), `calibrate`, `status [<id>]` /
  `check <id>` (QA: pacote + TL por juiz + solução good sem TL / falhou em todas as máquinas + soluções × categoria + entradas + `pronto: SIM` ou as pendências — os textos saem do `_RDY_JQ`, que só TRADUZ os códigos do servidor: a regra é do `lib/calib-expect.sh`),
  `calibrate` (global, `--hosts/--all-judges/--per-cpu` = direcionada como na web, `--judges` =
  lista do parque, `--all-stale` = lote), `validator` (validador de ENTRADA testlib: instala e roda
  local pelo `mojtools/testlib/install-validator.sh`, o MESMO `validator-run.sh` do juiz), `issues` (as issues do problema — `/problems/issues`; o texto só
  vem de `-m`/`-F`, o stdin nunca é lido sem `-F -`: pipe herdado que não fecha travaria o close; teste
  `test/issues.sh`), `calib` (a calibração POR EXTENSO, por juiz/solução/teste — `--json` p/ ferramentas externas),
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
- **Idiomas do enunciado (2026-09-15)**: `pkg_to_json` manda `translations{en,es}` (de
  `docs/enunciado.<lang>.md`, `solucao.<lang>.md`, `notes/*.<lang>.md`; `_trans_nd`, conteúdo por
  `--rawfile`) + `titles` do `.moj-id`; clone CIENTE (`trans_rt`) manda `null` p/ idioma sem arquivo
  (= apaga no servidor, como o `scripts_files`); `json_to_pkg` grava os arquivos e `titles`/`trans_rt`
  no `.moj-id`. `moj preview --lang`, `moj title --lang`, `moj edit` opções `t`/`e`. O `moj-comp`
  NUNCA adivinha idioma: pede só o que `statement_langs` (por problema, 4ª coluna do `problems.tsv`)
  listou — `statement <letra>` baixa todos (`A.html`, `A.en.html`…), `--lang` um só, idioma não
  oferecido = erro com a lista. Testes: `test/translations.sh` (funções via `MOJ_CLI_LIB_ONLY=1
  source moj`) e `test/comp-statement.sh` (curl falso; roda no artefato `dist/moj-comp` se existir).
- **`moj pull`, trava do push e id implícito (2026-09-22, issue #2 do Daniel Saad).** Dentro da pasta de
  um problema (ou de subpasta) o `<id>` é opcional: `pkg_root` sobe até o `.moj-id` (como o git acha o
  `.git`), `resolve_id` (vazio → o da pasta; `org#p` → ele; pasta clonada → a dela; nome SEM org → org
  do `.moj-id`) e `id_arg <regex-do-que-não-é-id>` define `ID`/`IDSHIFT` (a regex separa `on|off`, sha,
  `.tar.gz`). `rm`/`mv` continuam com id explícito de propósito; `status` sem id segue sendo a saúde do
  sistema. ⚠ `x="$(resolve_id …)" || exit 1` em comando SEPARADO do `local` (o die do subshell). Linha
  de base: `.moj-id.base_rev` (o `rev` do servidor) + `.moj-base` (TSV `hash\tcaminho` de cada arquivo
  do pacote + `.moj-id` com os campos de autoria; symlink entra pelo ALVO). **`pkg_files` TEM de listar
  exatamente o que o `pkg_to_json` lê** — mexeu num, mexa no outro (senão o pull apaga/ignora arquivo
  do pacote). `push`/`upload` mandam `base_rev`; 409 `stale_rev` vira `_stale_die` (quem/quando + as 3
  saídas); `--overwrite` = `force` (o `--force` antigo segue sendo só "pule pré-voo/título" — não passa
  pela trava). `moj pull` recusa com mudança local; `--force` copia a pasta p/ `<pasta>.local-<data>`;
  troca só os arquivos do pacote (`_pkg_swap`). `moj collection add/remove` de dentro da pasta sincroniza
  `collections`+`base_rev` quando a base era o servidor de antes (senão o próprio push seria recusado).
  Teste ponta a ponta contra o dev: `bash test/pull-push.sh --mint <login>` (cria sessão, org e problema
  de teste e apaga tudo; `MOJ_BIN=dist/moj` roda no artefato).
- **Problema paralelo (24/09/2026)**: `moj edit → 8 → 7/8/9` grava `CPUNEEDED`/`SAMENUMA`/
  `MAXPARALLELTESTS` (validados; vazio remove a linha = default do juiz); o pré-voo (`gate` →
  `parallel_conf_gate`) reprova valor inválido das 4 chaves — a MESMA regra do `validate-problem.sh`
  (`conf_parallel_sane`); `moj test --run` avisa quando `nproc < CPUNEEDED` (o b-a-t roda assim
  mesmo, com aviso no trace). `moj-judges`: `ls`/`show` mostram `slots.cpus/by_node/smt` e `hold`;
  `config --parallel-max`; `parallel off|auto [--cushion] [--share]` (chave `"*"` do judges-config).
  Teste: `test/parallel-conf.sh`. Mudou CLI ⇒ os 4 tutoriais web (regra da casa).
- **Problema sem exemplo (`SAMPLE=no` no `conf`, 2026-09-23)**: o pré-voo (`gate`) exige `sample*` OU
  `SAMPLE=no` (`sample_off`, a mesma regra do mojtools `stmt_no_samples` e do editor web `sampleOff`);
  `moj preview` manda `examples:[]` com a flag (o servido não tem exemplos); `moj edit` → 8 → 6 liga e
  desliga. O `samples` (arquivo na raiz) morreu — não o recrie. Formato em `cdmoj/docs/PACOTE.md`.
- **Mexeu no formato do pacote?** Atualize o **`cdmoj/docs/PACOTE.md`** (fonte única) no mesmo commit;
  o `README.md` daqui só resume e aponta p/ ele — não redescreva o formato (a divergência de cópias
  já gerou o bug do título vazio).
- **Camadas** (QUATRO executáveis): `moj` (autoria de problemas) + `moj-contest` (gestão de contest) + `moj-comp` (competidor/aluno, com o modo OFFLINE assinado) + `moj-judges`
  (gerência fina dos juízes: slots/particionamento, config por juiz, relatório de correções —
  sessão `.admin` do treino) compartilham o núcleo SOURCED `lib/core.sh` (config/env,
  `api()`/cache/`http_code`/`api_post_file`, e o **token POR CONTEST** em
  `~/.config/moj/token-<contest>`, com fallback legado `token` p/ o treino). `moj <camada> …`
  delega ao executável `moj-<camada>` (ao lado do script ou no PATH) — padrão p/ camadas
  futuras. `bash -euo pipefail` em todos; `bash -n` antes de commitar.
- **Distribuição continua de 1 arquivo**: `bash mkdist.sh` embute a lib nos artefatos
  `dist/{moj,moj-contest,moj-judges,moj-comp}` (marcadores `# @INLINE-BEGIN/END`); são ELES que o cdmoj
  serve em `web/moj*` (ver `cdmoj/docs/DEPLOY.md`). Nunca copie o script do repo direto.
  **O `make deploy` do cdmoj sincroniza sozinho** (alvo `cli-dist` roda o mkdist do checkout
  irmão e copia o que divergir) — mudou a CLI, o próximo deploy embarca.
- **Teste o ARTEFATO, não só o script do repo**: no `dist/` a lib é EMBUTIDA, então há defeito que
  só existe lá. Foi o caso da ajuda do `moj-comp`, que no repo saía certa e no artefato emendava no
  cabeçalho da `core.sh` e despejava 16 linhas de tripa interna no competidor. Depois de `mkdist.sh`,
  rode `bash dist/<tool> help` nos quatro e confira que nada de interno (`core.sh`, `@INLINE`,
  `set -euo`) aparece. A ajuda corta sozinha (comentários da 2ª linha até o primeiro
  não-comentário): **não** volte a escrever faixa de `sed` com número à mão.
- Pegadinha de bash: `local a=x b=$a` NÃO funciona com `set -u` (o `local` expande os argumentos
  antes de atribuir) — declare e atribua em comandos separados.
- Pegadinha de bash 2: função que termina num laço `while` cujo corpo acaba em `[[ … ]] && {…}`
  VAZA rc 1 quando a última iteração não casa — e `x="$(essa_funcao)"` sob `set -e` mata o
  processo MUDO (foi o `moj test --run` parando sem mensagem depois do pré-voo). Função-leitora
  termina com `return 0` explícito; atribuição de comando que pode falhar leva `|| true`.
- **`moj test --run` só se testa DE VERDADE em máquina com bwrap REAL** (o dev tem fbwrap e morre
  antes do caminho de julgamento — use o juiz de produção como bancada: copie o pacote + mojtools
  p/ ~ribas e rode com `CAGE_ROOT` apontando p/ a rootfs).
- **CONTEÚDO DE ARQUIVO NUNCA ANDA POR ARGV DO `jq`.** O Linux limita **um argumento** a
  **128 KiB**, e o erro é na cara do usuário: `/usr/bin/jq: Argument list too long`. Aconteceu em
  2026-08-24 no `moj-contest docs upload caderno <pdf>` — um caderno de 500 KB vira 665 KB em
  base64 (o `moj` e o `moj-comp` já usavam `--rawfile`; o `moj-contest` tinha TRÊS pontos que
  não: upload, cover e `docs text --from`). Regra: base64/markdown/código vão por
  **`--rawfile <arquivo>`** (helper `_b64tmp` em `lib/core.sh`), nunca por `--arg "$(…)"`. É a
  mesma classe do servidor (ver `cdmoj/CLAUDE.md`), e o guarda é `test/argmax.sh`, que roda os
  corpos de verdade com carga acima do teto **e** faz o inventário do padrão proibido nos quatro
  executáveis.
- **PORTABILIDADE: a CLI roda na máquina do USUÁRIO, e ela pode ser um Mac.** O dev e o servidor
  são Linux, então flag só-GNU passa despercebida aqui e quebra lá — já aconteceu três vezes
  (o `awk` de locale abaixo, e o `base64` do `testrun`/`log`/`comp statement`, que veio por PR de
  fora: no BSD não há `-w0` nem arquivo posicional, e com `set -euo pipefail` o comando morria com
  rc=64 — no caminho em que não morria, mandava `code_b64:""` p/ o servidor).
  **A `lib/core.sh` é a camada que embrulha essas diferenças** — use os helpers dela em vez de
  escrever a alternativa à mão: `_b64enc <arq>` / `_b64dec` (stdin), `_date2epoch`, `_mtime`,
  `_hash`, `_abspath`. A ÚNICA exceção legítima é a resolução do próprio caminho
  (`readlink -f … || echo "$BASH_SOURCE"`), que roda ANTES de a lib existir.
  Guarda: **`bash test/portabilidade.sh`** — varre os quatro executáveis atrás de flag só-GNU
  **sem fallback** e roda os helpers com um `base64`/`date` de BSD simulados no PATH. Rode junto
  com o `bash -n` antes de commitar.
- Pegadinha de LOCALE: a CLI roda na máquina do USUÁRIO — awk numérico SEM `LC_ALL=C` quebra em
  pt_BR: no mawk (o awk default do Ubuntu) `"0.21"+0 == 0` (strtod espera vírgula) e `%f` imprime
  vírgula (foi o "pior 0,00s" do relato do Edson; gawk não reproduz — ignora locale sem
  --use-lc-numeric). TODO awk/printf de número com ponto leva `LC_ALL=C` na frente.
- Rodapé de commit: **só** `Co-Authored-By:`, **nunca** uma linha `Claude-Session:` (ruído no histórico).
- **Doc junto com o código** (doc atrasada = bug): mudou subcomando/contrato? atualize o `README.md`, o
  cabeçalho de `moj` e `cdmoj/docs/API.md` (+ `openapi.json`) no mesmo commit.
- **Documentação em STE (Simplified Technical English), nos DOIS idiomas** (pedido do Ribas,
  2026-09-05): `README.md` (PT), `README.en.md` (EN, mesmo conteúdo e ordem), o cabeçalho de ajuda
  dos quatro executáveis e os quatro tutoriais web que citam CLI (`cdmoj/web/problemas/tutorial.html`,
  `web/treino/criar/tutorial.html`, `web/contest/cli.html`, `web/treino/cli.html`) seguem estas
  regras: **uma instrução por frase**; frases de até ~20 palavras; **voz ativa e imperativo** em
  procedimento ("Rode…"/"Run…"); presente; **um termo por conceito** (glossário no fim do README:
  contest, problema/problem, pacote/package, veredicto/verdict, sede/site, módulo/module,
  rodada/round, token, juiz/judge, placar/scoreboard — nunca sinônimos alternados); sem gíria, sem
  metáfora, sem parênteses encadeados, sem "etc."; passos em lista numerada; aviso como frase
  própria ("Atenção: …"/"Warning: …"); termo de comando em `código`. Comando novo nasce assim nos
  quatro lugares (README PT+EN, cabeçalho, tutorial) — a regra `cli-muda-tutorial-acompanha` vale.
