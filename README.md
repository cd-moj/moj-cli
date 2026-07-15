# moj — CLI de autoria de problemas do MOJ

Crie e edite problemas do MOJ **sem git e sem chave SSH**. Você só precisa do seu **login do
MOJ**. Dois jeitos de trabalhar (acesso a **tudo** que a página web tem):

- **Editor interativo** (como preencher os campos da página): `moj edit <id|pasta>`
- **Arquivos locais** (use seu editor favorito): `moj clone <id>` → edite os arquivos → `moj push`

## Instalação

Precisa de `bash`, `curl`, `jq` (e um editor para `moj edit`, via `$EDITOR`). Baixe e ponha no PATH:

```bash
curl -fsSL https://moj.naquadah.com.br/moj -o ~/.local/bin/moj && chmod +x ~/.local/bin/moj
```

Para a camada de **gestão de contest** (`moj contest …` / `moj-contest`), baixe também:

```bash
curl -fsSL https://moj.naquadah.com.br/moj-contest -o ~/.local/bin/moj-contest && chmod +x ~/.local/bin/moj-contest
```

Para a camada de **gerência de juízes** (`moj judges …` / `moj-judges`, só admin):

```bash
curl -fsSL https://moj.naquadah.com.br/moj-judges -o ~/.local/bin/moj-judges && chmod +x ~/.local/bin/moj-judges
```

| `moj judges` | O que faz (sessão `.admin` do treino) |
|---|---|
| `ls` · `show <host>` | saúde dos juízes (slots ocupados/total, partição, cache **em disco**, TLs, drenando/desabilitado) · detalhe + jobs correntes **com idade** (`há Xm` — job preso fica óbvio) |
| `config <host> [--partition off\|numa\|cpus:<X>] [--reserve N] [--disable\|--enable]` | **particiona a máquina em SLOTS** (corrige N problemas ao mesmo tempo, cada job pinado no seu conjunto de cpus); o agente drena e aplica |
| `reset <host>` · `restart <host>` | **RECUPERAÇÃO sem SSH**: mata os jobs presos (SIGKILL no grupo de processos, reportando) e reconcilia a config; `restart` ainda re-executa o agente — o servidor re-enfileira o que estava atribuído (fila não se perde). Chega MESMO com o juiz travado |
| `cancel <id> [--inprogress]` | remove calibrações do problema da FILA (pendentes + direcionadas não entregues; em execução só com a flag — prefira `reset`) |
| `results [host] [-n N]` | relatório de correções por juiz (veredicto, tempo, quem/qual) |
| `clearcache <host>` · `calibrate <id> [--hosts …]` · `queue` · `status` | operação do parque (`calibrate` repetido NÃO duplica: servidor responde `already_queued`) |

(Os arquivos servidos são auto-contidos — gerados por `mkdist.sh` a partir de `lib/core.sh` +
cada camada. Rodando do repo, os scripts sourceiam `lib/core.sh` direto.)

Config (opcional): `MOJ_URL` (default `https://moj.naquadah.com.br`), `EDITOR`. Para testar local:
`export MOJ_URL=http://127.0.0.1:8080 MOJ_HOST=moj.charge.naquadah.com.br`.

## Editor interativo (recomendado)

```bash
moj login
moj edit competicao#meu-problema     # clona (se preciso) e abre o menu
```

O menu espelha os campos da página — escolha um número/letra para editar:

```
── Editando competicao#meu-problema  (pasta ./meu-problema) ──
  1) Título     2) Autor     3) Tags
  4) Enunciado (abre o $EDITOR)   5) Exemplos (N)   6) Testes ocultos (M)
  7) Soluções (good/wrong/slow/pass/upcoming)   8) Conf   9) Coleções
  0) Público    r) Compartilhar pasta    v) Pré-visualizar
  w) SALVAR (push)   P) Validar & Publicar   i) Info/validação   q) Sair
```

Enunciado e código de solução abrem no seu `$EDITOR`; título/autor/tags são campos editáveis;
exemplos/testes/soluções têm submenus de adicionar/editar/remover; `conf` tem atalhos para as
opções comuns (calibrafactor, ULIMITS, CALIBRATIONTL, ALLOWPARALLELTEST, STOPWHEN…) + edição
bruta; `9) Coleções` marca o problema em coleções (tags) existentes ou cria uma nova coleção.

## Comandos

| Comando | O que faz |
|---|---|
| `moj login` / `logout` / `whoami` | sessão (mostra se você pode criar problemas) |
| `moj edit <id\|dir>` | **editor interativo** (campos da página) |
| `moj ls [mine\|shared\|public]` · `moj repos` | listas |
| `moj info <id>` | tudo do problema (dono, público, coleções, validação, contagens) |
| `moj new <org> <prob>` | scaffold completo do pacote em `./<prob>` (o 1º arg é a **org** do id `<org>#<prob>`) |
| `moj clone <id> [dir]` | baixa o pacote **inteiro** (enunciado, conf, exemplos, testes, soluções, **`scripts/` e `tests/score`**) |
| `moj test [dir] [--run [sol]]` · `moj push [dir] [--force]` | pré-voo local (**`--run` JULGA localmente** via mojtools; Linux+bwrap) · envia (cria/edita; **round-trip completo**, `scripts/` incluído) |
| `moj checker <dir> <checker.cpp>` · `moj interactive <dir> <arbitro> [--score]` | instala **checker testlib** / **problema interativo** normalizados (requerem checkout local do mojtools; `MOJTOOLS_DIR` aponta) |
| `moj preview [dir]` | renderiza o enunciado em HTML (abre no navegador) |
| `moj download <id> [arq]` · `moj upload <id> [dir\|arq] [--force]` | baixa/sobe o pacote inteiro; **`upload` de um DIRETÓRIO empacota sozinho** (exclui `.git`/caches/`.moj-id`) — formatos `.tar.gz`/`.tar.bz2`/`.tar.zst`/`.zip` |
| `moj validate <id>` | **portão de qualidade sem publicar**: valida (enunciado/testes/soluções) + pede calibração ao juiz e mostra o relatório. O problema **continua privado** — é o comando para prova em elaboração |
| `moj public <id> on\|off` · `moj publish <id>` · `moj calibrate <id>` | publicar (público => o servidor **valida + calibra**; a ORG precisa permitir) / calibrar |
| `moj status [<id>]` · `moj check <id>` | sem id: saúde do sistema; com id: **QA do problema** (validação, TL por juiz, solução `good` sem TL / falhou em todas as máquinas) |
| `moj board` | painel dos seus problemas: público/validado/calibrado + o que **precisa revisar** |
| `moj mkdir <org>` · `moj share <org> <login>` / `unshare …` | cria org / adiciona membro (quem edita) |
| `moj org list\|create\|members\|public\|rm` | gestão de **orgs**: membros (quem escreve) + **trava de público** (privada por padrão ⇒ problemas nunca ficam públicos; só admin da org muda). `rm <nome>` remove uma org **vazia** (a implícita não sai) |
| `moj mv <id> <org>` | move um **rascunho** p/ outra org (muda o id `<org>#<prob>`; bloqueia se público/em uso) |
| `moj collection ls\|show\|create\|add\|remove\|rename\|delete` | **coleções = TAGS de agrupamento** (m:n, ORTOGONAL à org; o nome pode ter **espaços**). `create "<nome>"`, `add/remove <id> "<nome>"` (marca/desmarca no problema), `show "<nome>"` (browse), `rename`/`delete` (dono da coleção) |

## Pacote do problema (arquivos)

> **Referência completa do formato: `cdmoj/docs/PACOTE.md`** (fonte única: o que é cada arquivo, os
> metadados `.moj-meta.json`/`.moj-id`, orgs, coleções, ciclo validar→calibrar→publicar). Roteiro de
> montar um pacote do zero: `mojtools/README.md`. Abaixo, o resumo p/ quem usa a CLI.

O **título é um CAMPO**, não uma linha no texto: localmente ele fica no `.moj-id` (`.title`); ao
enviar vira `display_title` no `.moj-meta.json` do servidor e o render injeta o `<h1>`. Um `% Título`
no topo do enunciado é **legado** (o render o ignora/remove). Por isso `moj push`/`upload` exigem um
título (ver "Portão de qualidade").

```
<prob>/
  docs/enunciado.md         # enunciado (.md | .org | .tex); exige as seções ## Entrada e ## Saída.
                            #   SEM "% Título" (o título é campo). Imagens: use base64 embutido.
  docs/sample-notes.json    # (opcional) explicações dos exemplos, um por posição, NA ORDEM
  docs/solucao.md           # (opcional) editorial — só p/ o SETTER, NÃO vai ao aluno
  conf                      # TL/ulimits/STOPWHEN… (atalhos no 'moj edit', opção 8)
  author                    # autor(es), 1 linha
  tags                      # 1 tag por linha
  tests/input/sample1  tests/output/sample1   # exemplos (pareados; aparecem no enunciado)
  tests/input/<nome>   tests/output/<nome>    # testes ocultos (correção)
  tests/score               # (opcional) grupos de pontuação por subtarefa — viaja no push/clone
  sols/{good,wrong,slow,pass,upcoming}/<arquivo>   # soluções por categoria (good = aceita)
  scripts/                  # (opcional) correção especial (compile/compare/checker/árbitro) —
                            #   VIAJA no push/clone (round-trip completo: conteúdo, +x e symlinks;
                            #   mexer em scripts/ dispara recalibração no juiz)
  .moj-id                   # ponteiro LOCAL (id/repo/prob/TÍTULO/coleções/LINGUAGENS/público) — NÃO é enviado
```

No servidor os metadados ficam em `.moj-meta.json` (`display_title`, `public`, `collections`,
`languages`, `owner`) — gerado a partir do que você envia; você não o edita à mão. **`languages`** =
ids de linguagem de submissão permitidos deste problema (`[]`/ausente = todas; ex.: `["pddl"]` p/ um
problema que só aceita PDDL); faz round-trip no `.moj-id` (`clone`→edita→`push`). `moj push` manda os
campos (title/coleções/linguagens do `.moj-id`); `moj upload` sobe um `.tar`/`.zip` inteiro (o
`.moj-meta.json`, com `display_title` e `languages`, tem de estar no pacote).

## Gestão de contest (`moj-contest` / `moj contest …`)

CLI da camada de **contest** — cria, reaproveita e administra contests pela API (os mesmos
bloqueios da web valem; o corte é no servidor). Sessões: criação/templates/export/duplicate/
list/remove usam a sessão do **treino** (`moj login`); administração exige sessão **naquele
contest** (`moj-contest login <cid>` com uma conta `*.admin` do contest — token por contest em
`~/.config/moj/token-<cid>`). O contest-alvo vem de `-c <cid>` ou `MOJ_CONTEST`.

| Comando | O que faz |
|---|---|
| `login <cid> [-u login]` · `logout [<cid>]` · `whoami` | sessão por contest |
| `create [spec.json\|-] [--template N] [--id --name --start --end]` | cria (spec JSON, template salvo, ou ambos) |
| `list` · `show <cid>` | seus contests · resumo de um |
| `export <cid> [arq] [--full]` · `duplicate <cid> [--id --name --start --end]` | spec p/ arquivo (sem credenciais) · cópia (sem usuários) |
| `template list\|show\|save <nome> (--from-contest <cid> [--with-problems] \| --from-file f)\|rm\|rename` | templates nomeados no servidor |
| `settings get` · `settings set k=v …` · `extend <+min\|epoch>` | configurações do contest (penalidade ICPC: `penalty_minutes=10`, `penalty_verdicts=wa,tle,mle,rte,ce` — vírgulas; vazio = nenhum penaliza; pool de juízes: `judges=cpu1,cpu2` — vazio = qualquer juiz online) |
| `problems ls\|add <id>\|rm <letra>\|rename\|reorder\|langs <letra> <l1,l2\|->\|judges <letra> <h1,h2\|->` | problemas do contest (`langs -`/`judges -` = volta a herdar do contest) |
| `problems search <q> [--collection C]` · `problems draw [--collections "A,B"] [--tags a,b] [--count N] [--difficulty d] [--seed s] [--add]` | banco público: busca e **sorteio por coleção/tag/dificuldade** (`--add` já adiciona) |
| `users ls\|add\|reset\|rm\|disable\|logout <login>\|set-password-all <senha>` | usuários (troca geral pede confirmação) |
| `sessions` · `dashboard` · `score` · `audit [n]` · `access [dia]` · `news ls\|add\|rm` | operação da prova |
| `report [arquivo]` | baixa o **relatório estático da prova** (tar.gz navegável offline: placar aberto + enunciados, runs sem código/log, clarifications anônimas, estatísticas, tarefas do staff, infra) |
| `remove <cid>` | tira do ar (lixeira; exige `.admin` do treino) |

## Quem pode criar

Criar problemas / orgs / coleções segue a **mesma permissão de criar contests** (admin do treino
libera por usuário ou por nº de problemas resolvidos). `moj whoami` mostra se você pode; editar e
compartilhar problemas existentes funciona para quem é dono/colaborador.

## Portão de qualidade

`moj push` faz pré-voo local (**título**, enunciado, ≥1 exemplo, solução `good`). O portão
**autoritativo** roda no servidor: `moj publish` (= `moj public <id> on`) faz o servidor **validar**
(HTML+exemplos+`good` aceita) **E calibrar** (um juiz roda as `good` e reporta o TL). Só entra no
treino livre se o portão passar. Acompanhe com `moj check <id>` (valida/calibra por juiz, TL, `good` sem TL).

**Título obrigatório:** `moj push` recusa enviar sem um título (o `.title` do `.moj-id` vazio ou o
placeholder do `moj new`) — senão o problema fica com o **nome da pasta**. `moj upload` idem: exige
`display_title` no `.moj-meta.json` do pacote. Escape unificado: `--force` (tanto no push quanto no
upload; `MOJ_ALLOW_NO_TITLE=1` segue aceito por compat).

## Autoria local com o mojtools (checker testlib, interativo, julgar local)

Com um checkout do [mojtools](https://github.com/cd-moj/mojtools) na máquina (irmão do repo da CLI,
`~/moj/mojtools`, ou `MOJTOOLS_DIR=<caminho>`):

- `moj checker <dir> <checker.cpp>` — instala um **checker testlib** normalizado
  (`mojtools/docs/checker-testlib.md`).
- `moj interactive <dir> <arbitro.{cpp,py,sh}> [--score]` — instala o driver de **problema
  interativo** (`mojtools/docs/problema-interativo.md`).
- `moj test <dir> --run [sol]` — **julga localmente** com o `build-and-test.sh` (cada `sols/good/*`
  ou uma solução dada; sem `tl` calibrado usa um TL transitório do `CALIBRATIONTL`). Exige **Linux
  com bwrap real** — a jaula é a mesma do juiz. No macOS (sem bwrap) e em hosts com fbwrap (dev),
  o comando explica e aponta o fluxo remoto: `moj publish`/`moj calibrate` + `moj check`.

## macOS

A CLI roda no macOS com **bash ≥ 4** (`brew install bash` — o `/bin/bash` 3.2 da Apple é recusado
com mensagem clara) e os utilitários BSD nativos (base64/stat/md5/readlink já são tratados de forma
portável). O que NÃO roda no macOS é o julgamento local (`moj test --run`) — a jaula do juiz é
Linux (bwrap/namespaces); use o fluxo remoto (`moj publish`/`calibrate`/`check`).

## Privacidade do token

O token de sessão **não aparece no `ps`**: os curls autenticam com `-H @~/.config/moj/hdr-<contest>`
(arquivo 600 criado no login; sessões antigas ganham o arquivo na primeira chamada) — em máquina
compartilhada (laboratório), outro usuário rodando `ps` vê só o caminho do arquivo, nunca o token.

## Saída crua (--json)

`moj --json <ls|board|status|check> …` imprime a resposta da API sem formatação (scripts/pipelines);
no `moj-contest` a flag global `--json` já existia e continua igual (agora ambos usam o mesmo `out()`).
