# moj — a CLI de autoria de problemas do MOJ

[English version: `README.en.md`](README.en.md)

Este documento segue o padrão **STE** (Simplified Technical English), adaptado ao português:
uma instrução por frase, frases curtas, voz ativa, um termo por conceito. O glossário está no fim.

`moj` cria e edita problemas do MOJ. Você não precisa de git. Você não precisa de chave SSH. Você
precisa só do seu login do MOJ. Há dois jeitos de trabalhar. Os dois dão acesso a tudo que a página
web tem.

- **Editor interativo**. Rode `moj edit <id|pasta>`. O menu mostra os mesmos campos da página.
- **Arquivos locais**. Rode `moj clone <id>`. Edite os arquivos com o seu editor. Rode `moj push`.

## Instalação

Requisitos: `bash`, `curl` e `jq`. Para `moj edit`, defina a variável `$EDITOR`.

1. Baixe o arquivo.
2. Torne o arquivo executável.
3. Coloque o arquivo no `PATH`.

```bash
curl -fsSL https://moj.naquadah.com.br/moj -o ~/.local/bin/moj && chmod +x ~/.local/bin/moj
```

Depois da instalação, use estes três comandos para manter a CLI em dia:

- `moj update` atualiza a própria CLI. Ele baixa os artefatos servidos e troca o arquivo no lugar.
- `moj version` compara o seu build com o build do servidor.
- `moj doctor` diagnostica o ambiente: atualização, `jq`, `curl`, mojtools, bwrap e sessão.
  Comece por ele quando algo parecer errado.

A CLI avisa sozinha quando está desatualizada. O servidor manda o cabeçalho `X-Moj-Cli-Status` em
toda resposta. Se o seu build ficou para trás, a CLI mostra um aviso no stderr uma vez por dia. O
comando segue normalmente. Uma CLI de antes de setembro de 2026 não tem marcador no User-Agent.
Essa CLI recebe a mesma dica anexada às mensagens de erro do servidor.

A CLI tem quatro camadas. Cada camada é um executável. Baixe só o que você usa.

| Executável | Quem usa | Como baixar |
|---|---|---|
| `moj` | autor de problemas | comando acima |
| `moj-contest` | organizador de contest (`moj contest …` delega aqui) | `curl -fsSL https://moj.naquadah.com.br/moj-contest -o ~/.local/bin/moj-contest && chmod +x ~/.local/bin/moj-contest` |
| `moj-comp` | competidor ou aluno (`moj comp …` delega aqui). É a única camada com o **modo offline** | `curl -fsSL https://moj.naquadah.com.br/moj-comp -o ~/.local/bin/moj-comp && chmod +x ~/.local/bin/moj-comp` |
| `moj-judges` | admin do parque de juízes (`moj judges …` delega aqui) | `curl -fsSL https://moj.naquadah.com.br/moj-judges -o ~/.local/bin/moj-judges && chmod +x ~/.local/bin/moj-judges` |

Os arquivos servidos são autocontidos. O script `mkdist.sh` gera cada um a partir de `lib/core.sh`
e da camada. Quando você roda do repositório, cada script carrega `lib/core.sh` diretamente.

### Configuração (opcional)

| Variável | Efeito |
|---|---|
| `MOJ_URL` | endereço do servidor. Default: `https://moj.naquadah.com.br` |
| `EDITOR` | editor de texto do `moj edit` |
| `MOJ_CONFIG_DIR` | pasta do token e do cache |
| `MOJ_CONTEST` | o contest alvo. Vale como `-c` no `moj-contest` e no `moj-comp` |
| `MOJ_HOST` | cabeçalho `Host`. Use em teste local |
| `MOJ_NO_CACHE=1` | desliga o cache local |
| `MOJ_UA_FILE`, `MOJ_USER_AGENT` | User-Agent extra. Ver a nota abaixo |

Toda CLI se apresenta ao servidor como `<tool>/<build>` no User-Agent. Se o arquivo
`/etc/moj/user-agent` existe, ou se `MOJ_USER_AGENT` está definida, a CLI manda esse valor na
frente. Na máquina de prova, esse valor é o User-Agent do navegador da imagem da sede. Com ele a
CLI passa no gate de navegador por sede e usa a mesma chave de máquina do navegador. Ver
`cdmoj/docs/MANUAL-ADMIN.md`, seção 7. O servidor separa pedidos da web e da CLI por esse marcador.

Para testar contra um servidor local:

```bash
export MOJ_URL=http://127.0.0.1:8080 MOJ_HOST=moj.charge.naquadah.com.br
```

## Editor interativo (recomendado)

```bash
moj login
moj edit competicao#meu-problema     # clona, se preciso, e abre o menu
```

O menu mostra os campos da página. Digite um número ou uma letra para editar um campo:

```
── Editando competicao#meu-problema  (pasta ./meu-problema) ──
  1) Título     2) Autor     3) Tags
  4) Enunciado (abre o $EDITOR)   5) Exemplos (N)   6) Testes ocultos (M)
  7) Soluções (good/wrong/slow/pass/upcoming)   8) Conf   9) Coleções
  0) Público    L) Linguagens    r) Compartilhar pasta    v) Pré-visualizar
  w) SALVAR (push)   P) Validar & Publicar   i) Info/validação   q) Sair
```

- O enunciado e o código das soluções abrem no seu `$EDITOR`.
- Título, autor e tags são campos de texto.
- Exemplos, testes e soluções têm submenus para adicionar, editar e remover.
- `8) Conf` tem atalhos para as opções comuns: `calibrafactor`, `ULIMITS`, `CALIBRATIONTL`,
  `ALLOWPARALLELTEST`, `STOPWHEN`. Também permite a edição bruta do arquivo.
- `9) Coleções` marca o problema em coleções existentes. Também cria uma coleção nova.

## Comandos do `moj`

| Comando | O que faz | Exemplo |
|---|---|---|
| `moj login` · `logout` · `whoami` | Gerencia a sessão. `whoami` mostra se você pode criar problemas. | `moj whoami` |
| `moj edit <id\|dir>` | Abre o editor interativo. | `moj edit apc#vetor1` |
| `moj ls [mine\|shared\|public]` · `moj repos` | Lista problemas e orgs. | `moj ls mine` |
| `moj info <id>` | Mostra tudo do problema: dono, público, coleções, validação, contagens. | `moj info apc#vetor1` |
| `moj new <org> <prob>` | Cria o esqueleto do pacote em `./<prob>`. `<org>` é a org do id `<org>#<prob>`. `<prob>` é um slug minúsculo `[a-z0-9._-]`. A CLI recusa outro formato e sugere o certo. | `moj new apc vetor1` |
| `moj clone <id> [dir]` | Baixa o pacote inteiro: enunciado, conf, exemplos, testes, soluções, `scripts/` e `tests/score`. | `moj clone apc#vetor1` |
| `moj test [dir] [--run [sol]]` | Faz o pré-voo local. Com `tests/score`, confere os grupos: distribuição, teste órfão, linha inválida. `--run` julga localmente com o mojtools. Exige Linux e bwrap. | `moj test --run` |
| `moj push [dir] [--force]` | Envia o pacote. Cria ou edita o problema. O envio é completo, com `scripts/`. | `moj push` |
| `moj doctor` · `moj version` · `moj update` | Diagnostica o ambiente · compara o build · atualiza a CLI. | `moj doctor` |
| `moj checker <dir> <checker.cpp> [--force]` | Instala um checker testlib. Exige o mojtools local (`MOJTOOLS_DIR`). Recusa sobrescrever um `scripts/` existente. `--force` substitui. | `moj checker ./p chk.cpp` |
| `moj interactive <dir> <arbitro> [--score]` | Instala o driver de problema interativo. Exige o mojtools local. | `moj interactive ./p arb.cpp` |
| `moj fn <dir> [--langs …] [--force]` | Instala os drivers de submissão de função em 5 linguagens, com sentinela anti-IO. Exige o mojtools local. | `moj fn ./p --langs c,py` |
| `moj preview [dir] [--lang en\|es]` | Renderiza o enunciado em HTML e abre no navegador. `--lang` renderiza a tradução, com o título e as explicações traduzidas. | `moj preview --lang en` |
| `moj title [dir] [--lang en\|es] [<título>]` | Mostra ou define o título. Com `--lang`, o título da tradução. Grava no `.moj-id`. Aplica no próximo `push`. | `moj title . --lang en "Sum"` |
| `moj download <id> [arq] [--sha <sha>]` | Baixa o pacote inteiro. `--sha` baixa a versão daquele commit. | `moj download apc#vetor1` |
| `moj upload <id> [dir\|arq] [--force]` | Sobe o pacote inteiro. Um diretório é empacotado pela CLI. A CLI exclui `.git`, caches e `.moj-id`, e gera um `.moj-meta.json` com título, coleções e linguagens do `.moj-id`. Formatos: `.tar.gz`, `.tar.bz2`, `.tar.zst`, `.zip`. Meta ausente preserva o que está no servidor. Tar sem o arquivo `tags` preserva as tags. | `moj upload apc#vetor1 ./vetor1` |
| `moj languages <dir> [c,cpp,py,…\|all]` | Define a lista de linguagens de submissão do problema. Sem argumento, mostra a lista. `all` libera todas as padrão. Grava no `.moj-id`. Aplica no próximo `push`. Obrigatória em problema de função ou de ban: sem ela, trocar a linguagem burla o driver. | `moj languages ./p c,py` |
| `moj export <id> [arq.tar.gz]` · `moj import <pacote> <pasta> [prob]` | Exporta no formato ICPC/Kattis. Importa um pacote Kattis como problema MOJ. O `.kattis.json` garante o round-trip. | `moj export apc#vetor1` |
| `moj rm <id>` | Remove o problema do acervo e do treino. Pede a confirmação com o id. | `moj rm apc#velho` |
| `moj log <id> [-n N]` · `moj log <id> <sha>` | Mostra o histórico git do problema. Cada save e cada upload é um commit. Com `<sha>`, mostra o `git show -p`. | `moj log apc#vetor1 -n 5` |
| `moj restore <id> <sha>` | Restaura a versão do commit como um commit novo. A história fica. Público e coleções ficam. Pede a confirmação com o sha. | `moj restore apc#vetor1 a1b2c3` |
| `moj validate <id> [--no-wait]` | Roda o portão de qualidade sem publicar. Valida enunciado, testes e soluções. Enfileira a calibração no juiz. Espera o relatório e imprime o `moj check`. `--no-wait` não espera. O problema continua privado. Atenção: cada chamada dispara uma calibração nova. Para só consultar, use `moj status` ou `moj check`. | `moj validate apc#vetor1` |
| `moj public <id> on\|off [--yes]` · `moj publish <id> [--yes]` | Publica ou despublica. Publicar faz o servidor validar e calibrar. A org precisa permitir público. | `moj publish apc#vetor1` |
| `moj calibrate <id> [--hosts h1,h2\|--all-judges\|--per-cpu]` · `--judges` · `--all-stale` | Calibra o problema. `--hosts` usa os juízes citados. `--all-judges` usa todos online. `--per-cpu` usa um juiz por modelo de CPU. `--judges` lista o parque. `--all-stale` recalibra todos os seus problemas marcados como "precisa recalibrar". Repetir não duplica. | `moj calibrate --all-stale` |
| `moj status [<id>]` · `moj check <id>` | Sem id: saúde do sistema. Com id: QA do problema: validação, TL por juiz, solução `good` sem TL. Mostra o aviso `TL OVERRIDE` quando o conf tem `TLOVERRIDE`. Mostra o porquê de "precisa recalibrar": data, checksums e commits. | `moj check apc#vetor1` |
| `moj board` | Mostra o painel dos seus problemas: público, validado, calibrado e o que precisa de revisão. | `moj board` |
| `moj calib <id>` | Mostra a calibração por extenso: cada juiz, cada solução, cada teste `{name,code,time,tl}`. `--json` imprime o JSON cru. | `moj --json calib apc#vetor1` |
| `moj calib-report <id> [--host <juiz> --sol <nome>] [-o out.html]` | Baixa o `report.html` de uma solução da calibração. Sem `--host` e `--sol`, lista os disponíveis. | `moj calib-report apc#vetor1` |
| `moj testrun <id\|dir> <arquivo> [--report out.html] [--no-wait]` | Roda uma solução avulsa no juiz, com a jaula e o TL da submissão real. Não entra no history nem no placar. Exige permissão de edição. | `moj testrun apc#vetor1 sol.cpp` |
| `moj testrun-status <run> [--report out.html]` | Consulta um testrun já enfileirado. | `moj testrun-status 1f3a…` |
| `moj mkdir <org>` · `moj share <org> <login>` · `moj unshare <org> <login>` | Cria uma org. Adiciona ou remove um membro. Atenção: o login precisa existir no treino e poder criar problemas. Senão o servidor responde 404 ou 403 e não grava nada. Remover não valida. | `moj share apc monitor.ana` |
| `moj org list\|create\|members\|public\|rm` | Gerencia orgs: membros e a trava de público. Uma org nasce privada. Só o admin da org muda a trava. `rm` remove uma org vazia. | `moj org public apc on` |
| `moj mv <id> <org>` | Move um rascunho para outra org. O id muda para `<org>#<prob>`. Recusa problema público ou em uso. | `moj mv ana#p apc` |
| `moj collection ls\|show\|create\|add\|remove\|rename\|delete\|status` | Gerencia coleções. `create "<nome>"` cria. `add` e `remove` marcam e desmarcam um problema. `show` lista. `rename` e `delete` valem para o dono da coleção. O servidor refaz as tags em segundo plano. A CLI acompanha até o fim. `--no-wait` não espera. | `moj collection add apc#vetor1 "APC 2026.1"` |

## Pacote do problema (arquivos)

A referência completa do formato é `cdmoj/docs/PACOTE.md`. Ela é a fonte única para os arquivos,
os metadados `.moj-meta.json` e `.moj-id`, as orgs, as coleções e o ciclo validar → calibrar →
publicar. O roteiro para montar um pacote do zero está em `mojtools/README.md`. Abaixo está o
resumo para quem usa a CLI.

O título é um campo. Ele não é uma linha no texto. Localmente, o título fica no `.moj-id`
(`.title`). No envio, ele vira `display_title` no `.moj-meta.json` do servidor. O renderizador
injeta o `<h1>`. Um `% Título` no topo do enunciado é legado. O renderizador o remove. Por isso
`moj push` e `moj upload` exigem um título.

```
<prob>/
  docs/enunciado.md         # enunciado em português (.md | .org | .tex). Exige ## Entrada e ## Saída.
                            #   Sem "% Título" (o título é campo). Imagens: base64 embutido.
  docs/enunciado.en.md      # (opcional) a tradução (en, es). Mesmas seções (## Input / ## Output).
  docs/notes/sample1.md     # (opcional) explicação de cada exemplo (1 markdown por exemplo)
  docs/notes/sample1.en.md  # (opcional) a explicação traduzida. Sem ela, o exemplo mostra a PT.
  docs/solucao.md           # (opcional) editorial. Só o autor vê. Não vai ao aluno.
  docs/solucao.en.md        # (opcional) o editorial traduzido (entra no documento de editorial em EN).
  conf                      # TL, ulimits, STOPWHEN. Atalhos no 'moj edit', opção 8.
  author                    # autores, 1 linha
  tags                      # 1 tag por linha
  tests/input/sample1  tests/output/sample1   # exemplos (pareados; aparecem no enunciado)
  tests/input/<nome>   tests/output/<nome>    # testes ocultos (correção)
  tests/score               # (opcional) grupos de pontuação por subtarefa. Viaja no push e no clone.
  sols/{good,wrong,slow,pass,upcoming}/<arquivo>   # soluções por categoria (good = aceita)
  scripts/                  # (opcional) correção especial (compile, compare, checker, árbitro).
                            #   Viaja no push e no clone: conteúdo, +x e symlinks.
                            #   Mexer em scripts/ dispara recalibração no juiz.
  .moj-id                   # ponteiro local (id, repo, prob, título, títulos das traduções,
                            #   coleções, linguagens, público). Não é enviado.
```

**Idiomas.** O português é obrigatório. Uma tradução é um arquivo ao lado, com o código do idioma
no nome. O título da tradução fica no `.moj-id` (`titles`): `moj title . --lang en "Hello World"`.
No `moj edit`, a opção `t` cuida das traduções e a opção `e` do editorial em cada idioma. `moj push`
e `moj clone` levam e trazem tudo. Em um clone, remover `docs/enunciado.en.md` e dar `push` remove
a tradução no servidor.

No servidor, os metadados ficam em `.moj-meta.json`: `display_title`, `public`, `collections`,
`languages`, `owner`. O servidor gera esse arquivo a partir do que você envia. Você não o edita.

`languages` é a lista de linguagens de submissão permitidas do problema. Lista vazia ou ausente
libera todas. Exemplo: `["pddl"]` para um problema que só aceita PDDL. A lista faz round-trip no
`.moj-id`: `clone` → `moj languages` → `push`.

`moj push` manda título, coleções e linguagens do `.moj-id`. `moj upload` sobe um `.tar` ou `.zip`
inteiro e manda os mesmos campos. De um diretório com `.moj-id`, a CLI gera o `.moj-meta.json` no
tar. De um tar de `moj download`, o meta real já está lá. Nos dois casos, o servidor lê só os
campos de conteúdo: título, coleções e linguagens. Campo ausente ou `[]` preserva o valor do
servidor. `public` e `owner` nunca vêm do tar.

## CLI do competidor (`moj-comp` / `moj comp …`)

`moj-comp` é a CLI do aluno ou competidor dentro de um contest.

| Comando | O que faz |
|---|---|
| `login <cid\|url>` | Entra no contest com as credenciais da organização. |
| `fetch` | Baixa todos os enunciados, em todos os idiomas que a prova oferece (`A.html`, `A.en.html`…). Você trabalha sem rede. |
| `problems` · `score` · `news` | Lista problemas (com os idiomas do enunciado de cada um) · mostra o placar · mostra avisos. |
| `statement <letra> [--lang en\|es]` | Baixa um enunciado. Sem `--lang`, todos os idiomas oferecidos. Com um idioma que a prova não oferece, a CLI recusa e lista os disponíveis. |
| `submit <letra> <arquivo>` | Envia e espera o veredicto. |
| `subs` | Lista as suas submissões e veredictos. |
| `clar ls` · `clar ask <letra\|geral> <texto>` | Lista e faz perguntas aos juízes. |
| `time` · `doctor` · `update` | Compara o relógio · diagnostica · atualiza. |
| `outbox` · `sync` · `monitor` | Mostra a fila offline · reenvia agora · vigia a queda de rede. |

**Modo offline.** Quando `submit` não alcança o servidor, a CLI empacota a submissão. O pacote é
cifrado com a chave pública do contest, recebida no login. O pacote leva o horário UTC corrente,
corrigido pelo desvio medido do relógio. `moj-comp monitor` vigia a rede. Quando a rede volta, ele
reenvia sozinho. A submissão conta no horário do carimbo. A rota é `/contest/offline-submit`. Um
beacon assinado do servidor e a hora de chegada cercam o carimbo. Ver `cdmoj/docs/FLOW.md`, seção
7½. O guia do competidor está em `/contest/cli.html` no servidor. Requisitos: `bash`, `curl`,
`jq` e `openssl`.

Vários subcomandos aceitam um apelido em português: `baixar` = `fetch`, `noticias` = `news`,
`relogio` = `time`, `reenviar` = `sync`. Nas outras camadas: `maquinas` = `machines`,
`test-run` = `testrun`. Use o que preferir.

A mesma CLI atende o treino livre, sem o modo offline. Rode `moj-comp login treino` com a conta do
site. Depois use `problems <busca>`, `statement <org#slug> [--lang en]` (grava `slug.html` e um
`slug.<lang>.html` por tradução), `submit <org#slug> <arquivo>` e `subs`. O guia do treino está em
`/treino/cli.html`.

## Gestão de contest (`moj-contest` / `moj contest …`)

`moj-contest` cria, reaproveita e administra contests pela API. Os mesmos bloqueios da web valem.
O corte é no servidor.

Há duas sessões:

1. Os comandos `create`, `template`, `export`, `duplicate`, `list` e `remove` usam a sessão do
   treino. Faça `moj login`.
2. Os comandos de administração exigem uma sessão naquele contest. Faça
   `moj-contest login <cid>` com uma conta `*.admin` do contest. O token fica em
   `~/.config/moj/token-<cid>`. Ele não substitui a sessão do treino.

O contest alvo vem de `-c <cid>` ou de `MOJ_CONTEST`.

| Comando | O que faz | Exemplo |
|---|---|---|
| `login <cid> [-u login]` · `logout [<cid>]` · `whoami` | Gerencia a sessão por contest. | `moj-contest login prova1 -u ana.admin` |
| `create [spec.json\|-] [--template <nome>] [--id --name --start --end] [--empty] [--modules a,b]` | Cria o contest. Aceita um spec JSON, um template salvo, ou os dois. Exige ao menos um problema. `--empty` cria a sala vazia. `--modules` liga módulos na criação. | `moj-contest create --empty --id lab1 --name "Lab 1" --end 1790000000 --modules maquinas` |
| `list` · `show <cid>` | Lista os seus contests · mostra o resumo de um, com os módulos ligados. | `moj-contest show lab1` |
| `export <cid> [arq] [--full]` | Grava o spec do contest em um arquivo. Sem credenciais. Traz a seção `modules{}` com os dados de cada módulo ligado. Sem segredos. | `moj-contest export lab1` |
| `duplicate <cid> [--id --name --start --end]` | Copia um contest. Sem usuários. O plano de rodadas acompanha as datas novas. | `moj-contest duplicate lab1 --id lab2` |
| `template list\|show\|save <nome> (--from-contest <cid> [--with-problems] \| --from-file f)\|rm\|rename` | Gerencia templates nomeados no servidor. | `moj-contest template save lab --from-contest lab1` |
| `modules [list]` · `modules on <ids>` · `modules off <ids>` | Gerencia os módulos do contest. `list` mostra ligado ou desligado, e se há dados de cada módulo. Desligar nunca apaga dado. Ids: `sedes maquinas rodadas documentos baloes coortes inscricoes telao classificacao`. | `moj-contest -c lab1 modules on baloes,documentos` |
| `settings get` · `settings set k=v …` | Lê e grava as configurações. Penalidade ICPC: `penalty_minutes=10`, `penalty_verdicts=wa,tle,mle,rte,ce`. Valor vazio: nenhum veredicto penaliza. Pool de juízes: `judges=cpu1,cpu2`. Vazio: qualquer juiz online. | `moj-contest -c lab1 settings set manual_verdict=true` |
| `extend <+min\|epoch> [--group <regex> [--reason <txt>]]` | Prorroga o fim. Com `--group`, só para os logins que casam. | `moj-contest -c lab1 extend +30 --group '^sala2'` |
| `problems ls\|add <id> [--name N] [--letter L]\|rm <letra>\|rename <letra> <nome>\|reorder <L1> <L2>…\|langs <letra> <l1,l2\|->\|judges <letra> <h1,h2\|->` | Gerencia os problemas do contest. `langs -` e `judges -` voltam a herdar do contest. | `moj-contest -c lab1 problems add apc#vetor1 --letter A` |
| `problems search <q> [--collection C]` · `problems draw [--collections "A,B"] [--tags a,b] [--count N] [--difficulty d] [--match any\|all] [--seed s] [--add]` | Busca no banco público. Sorteia por coleção, tag e dificuldade. `--add` adiciona o resultado. | `moj-contest -c lab1 problems draw --tags grafos --count 3 --add` |
| `users ls [--include-disabled]\|add <login> [--pass P] [--name N] [--email E]\|reset <login>\|rm\|disable\|logout <login>\|set-password-all <senha> [--include-disabled]` | Gerencia os usuários. `add` sem `--pass` sorteia a senha e a imprime. A troca geral pede confirmação. Por padrão ela não mexe nas contas desabilitadas. | `moj-contest -c lab1 users add ana` |
| `sessions` · `dashboard` · `score` · `audit [n]` · `access [dia]` · `news ls\|add\|rm` | Opera a prova. | `moj-contest -c lab1 dashboard` |
| `report [arquivo]` | Baixa o relatório estático da prova: um site navegável offline com placar, enunciados, runs sem código, clarifications anônimas, estatísticas e tarefas do staff. | `moj-contest -c lab1 report` |
| `rounds ls` · `rounds add <slug> --name N --start … --end … [--kind warmup]` · `rounds set` | Gerencia rodadas: aquecimento e prova oficial no mesmo contest. Datas aceitam epoch, `+90m`, `+2h` ou `"AAAA-MM-DD HH:MM"`. | `moj-contest -c lab1 rounds add aq --name Aquecimento --start +1h --end +2h --kind warmup` |
| `rounds problems <slug> [ls\|set <id,id…>\|add <id>\|rm <letra>]` | Define os problemas de cada rodada. Eles entram no ar quando a rodada é promovida. Você pode usar todo problema que o dono do contest pode ver: público, seu, de colaborador ou da org. | `moj-contest -c lab1 rounds problems aq set apc#a,apc#b` |
| `rounds colors <slug> [ls\|set <json>\|set A=RRGGBB,B=RRGGBB[,sonic]\|clear]` | Define as cores de balão da rodada. A rodada no ar grava na hora. A rodada planejada aplica na promoção. `clear` faz a rodada herdar as cores em vigor. | `moj-contest -c lab1 rounds colors prova set A=FF0000,B=0000FF` |
| `rounds promote [--force]` | Arquiva a rodada no ar e coloca a próxima no ar. Recusa com job em voo, veredicto pendente ou review aberto. Com o placar congelado, só é aceita a partir do fim da prova para todas as sedes + 1 minuto. `--force` não passa por cima desta regra. `rounds ls` lista os bloqueadores. Pede o id do contest. | `moj-contest -c lab1 rounds promote` |
| `rounds publish\|unpublish <slug>` · `rounds archive <slug> [arq]` · `rounds rm <slug>` | Libera o placar da rodada arquivada · baixa o arquivo bruto · apaga uma rodada que não foi ao ar. | `moj-contest -c lab1 rounds archive aq` |
| `cohorts ls` · `cohorts add\|set <id> [--name N] [--regex R] [--sees a,b] [--private\|--public] [--unranked\|--ranked] [--default]` · `cohorts rm <id>` · `cohorts assign <login> <id>` · `cohorts materialize` · `cohorts release [on\|off]` | Gerencia coortes de placar: times oficiais e convidados. Uma coorte privada não aparece no placar público. `--unranked` entra intercalado sem consumir posição. `--sees` diz quais coortes aquela enxerga. `--default` é a coorte de quem não casa com regex. `release` libera os resultados. | `moj-contest -c lab1 cohorts add ccl --regex '^ccl' --private` |
| `machines [--round <slug>] [--csv]` | Mostra time × IP × User-Agent da rodada. Marca quem trocou de máquina. Sugere a substring do gate. | `moj-contest -c lab1 machines --csv` |
| `ua-gate show` · `ua-gate check <login>` · `ua-gate set [--mode enforce\|off] [--from-login REGEX --expect '\\1'] [--region 'Sede=trecho']… [--regex 'REGEX=trecho']… [--exempt REGEX]… [--fallback S]` | Configura o gate de navegador por sede. `show` lista as regras. `check` diz o trecho esperado de um time. `--from-login` deriva o trecho do login. `--region` é o override de uma sede. `--exempt` é a isenção. Atenção: `--region`, `--regex` e `--exempt` substituem a lista inteira. | `moj-contest -c lab1 ua-gate check teambrspso001` |
| `docs ls` · `docs gen [info\|caderno\|times\|editorial…] [--lang pt\|en\|es\|both\|all]` | Lista e gera os documentos da prova em PDF e HTML. | `moj-contest -c lab1 docs gen caderno --lang pt` |
| `docs get <info\|caderno\|times\|all> [--lang …] [--fmt pdf\|html] [-o arq]` | Baixa um documento. Qualquer conta do contest pode usar `ls` e `get`. Eles mostram só o publicado. | `moj-contest -c lab1 docs get caderno -o caderno.pdf` |
| `docs publish <tipo> [--lang pt] [--news]` · `docs unpublish <tipo>` | Publica para a sede e para a seção "Prova". `--news` cria a notícia com o PDF. | `moj-contest -c lab1 docs publish caderno --news` |
| `docs cover <capa.pdf> [--lang pt]` · `docs cover --rm` | Define a capa do caderno em PDF. `--rm` volta à capa gerada. | `moj-contest -c lab1 docs cover capa.pdf` |
| `docs upload <tipo> <doc.pdf> [--lang pt]` · `docs upload <tipo> --rm` | Sobe o documento pronto. Ele vence o gerado. `--rm` volta ao gerado. | `moj-contest -c lab1 docs upload caderno final.pdf` |
| `docs set caderno_version=v1.2 [errata=…] [cover_note=…]` · `docs text <info\|capa> [--show\|--from arq\|--reset]` | Edita dados e textos dos documentos. Os textos são Markdown com marcadores `{{…}}`. | `moj-contest -c lab1 docs set caderno_version=v1.1` |
| `seed [--teams N] [--subs N] [--seed S]` | Povoa um contest de demonstração (`DEMO=1`) com dados sintéticos. | `moj-contest -c demo seed --teams 20` |
| `remove <cid>` | Tira o contest do ar. Exige `.admin` do treino. | `moj-contest remove lab1` |

### O spec de criação e os módulos

Um módulo é um grupo de recursos do contest. Uma prova de disciplina não liga nenhum. Uma prova
em laboratório com Maratona Linux liga `maquinas`. A Maratona liga todos. Desligar um módulo
esconde os painéis dele no admin. Nunca apaga dado.

Você não precisa ligar um módulo antes de usar o recurso. Um comando que grava o dado do módulo
liga o módulo sozinho: `rounds add` liga `rodadas`, `cohorts add` liga `coortes`, `ua-gate set`
liga `maquinas`, `docs gen` liga `documentos`. Só desligar é manual.

O spec JSON do `create` leva a seção `modules{}`. Cada chave é um módulo. O valor é `true` ou um
objeto com os dados do módulo. Um objeto presente liga o módulo, exceto com `on: false`.

```json
{
  "id": "lab1", "name": "Lab 1", "mode": "icpc", "end": 1790000000, "allow_empty": true,
  "modules": {
    "maquinas": { "ua_gate": { "mode": "enforce", "from_login": { "regex": "^team([a-z]{6})", "expect": "\\1" } },
                  "site_lock": { "enabled": true, "grace": 1200 } },
    "baloes":   { "colors": { "A": "FF0000" }, "during_freeze": false },
    "sedes":    { "regions": [ { "name": "Sorocaba", "regex": "^teambrspso" } ] },
    "rodadas":  true
  }
}
```

Seções: `sedes{regions, teams_meta, time_overrides}`, `baloes{colors, during_freeze}`,
`coortes{cohorts}`, `maquinas{ua_gate, site_lock, nutella_url}`, `rodadas{active, rounds}`,
`documentos{config}`, `inscricoes{enabled, window}`, `telao{views}`, `classificacao{algorithm,
config}`. O `export` devolve a mesma seção. Ele não devolve segredos. O `create` gera chaves novas
de webcast a partir de `views`. Uma seção com tipo errado responde 422 `modules_spec_invalid`.

## Quem pode criar

Criar problemas, orgs e coleções segue a mesma permissão de criar contests. O admin do treino libera
por usuário ou por número de problemas resolvidos. `moj whoami` mostra se você pode. Editar e
compartilhar problemas existentes funciona para dono e colaborador.

## Portão de qualidade

`moj push` faz o pré-voo local: título, enunciado, ao menos um exemplo e uma solução `good`. O
portão autoritativo roda no servidor. `moj publish` (igual a `moj public <id> on`) faz o servidor
validar e calibrar. Validar confere HTML, exemplos e a solução `good`. Calibrar faz um juiz rodar
as soluções `good` e reportar o TL. O problema entra no treino livre só se o portão passar.
Acompanhe com `moj check <id>`.

**Título obrigatório.** `moj push` recusa enviar sem título. Um `.title` vazio no `.moj-id` ou o
placeholder do `moj new` contam como sem título. Sem o título, o problema ficaria com o nome da
pasta. `moj upload` exige `display_title` no `.moj-meta.json` do pacote. A flag `--force` libera o
envio sem título, no push e no upload. `MOJ_ALLOW_NO_TITLE=1` continua aceita.

## Autoria local com o mojtools

Quatro comandos precisam de um checkout do [mojtools](https://github.com/cd-moj/mojtools) na sua
máquina. Coloque o checkout em `~/moj/mojtools`, irmão do repositório da CLI, ou defina
`MOJTOOLS_DIR=<caminho>`.

- `moj checker <dir> <checker.cpp>` instala um checker testlib normalizado. Ver
  `mojtools/docs/checker-testlib.md`.
- `moj interactive <dir> <arbitro.{cpp,py,sh}> [--score]` instala o driver de problema interativo.
  Ver `mojtools/docs/problema-interativo.md`.
- `moj fn <dir>` instala os drivers de submissão de função.
- `moj test <dir> --run [sol]` julga localmente com o `build-and-test.sh`. Ele julga cada
  `sols/good/*` ou uma solução dada. Sem TL calibrado, ele usa um TL transitório do
  `CALIBRATIONTL`. Exige Linux com bwrap real. A jaula é a mesma do juiz. No macOS e em hosts com
  fbwrap, o comando explica e aponta o fluxo remoto: `moj publish` ou `moj calibrate`, depois
  `moj check`.

A saída do `--run` mostra, por solução, o veredicto, os tempos por teste medidos na sua máquina e o
caminho do `report.html`:

```
julgando localmente (mojtools: /home/voce/mojtools; TL transitório 5s)…
  aula.java -> Accepted,100p. Pontos | 100 |
    tempos (TL 5s): 0.13 0.12 0.14 …
    31 teste(s), pior 0.14s
    relatório: /tmp/tmp.a1B2c3/report.html
```

## macOS

A CLI roda no macOS com bash 4 ou mais novo. Instale com `brew install bash`. A CLI recusa o
`/bin/bash` 3.2 da Apple com uma mensagem clara. Os utilitários BSD nativos funcionam: `base64`,
`stat`, `md5`, `readlink`. O julgamento local (`moj test --run`) não roda no macOS. A jaula do juiz
é Linux. Use o fluxo remoto: `moj publish`, `moj calibrate` e `moj check`.

## Privacidade do token

O token de sessão não aparece no `ps`. Os comandos `curl` autenticam com
`-H @~/.config/moj/hdr-<contest>`. O login cria esse arquivo com permissão 600. Sessões antigas
ganham o arquivo na primeira chamada. Em uma máquina compartilhada, outro usuário vê só o caminho
do arquivo. Ele nunca vê o token.

## Saída crua (`--json`)

`moj --json <ls|board|status|check|calib|calibrate|testrun|testrun-status|log|restore> …` imprime a
resposta da API sem formatação. Use em scripts. No `moj-contest`, a flag global `--json` funciona
do mesmo jeito.

## Glossário

| Termo | Significado |
|---|---|
| **contest** | uma prova ou lista com janela, problemas e contas. Tem um id minúsculo, que vira o subdomínio |
| **problema** | um pacote com enunciado, testes e soluções. Tem um id `<org>#<prob>` |
| **pacote** | o diretório do problema, com os arquivos listados acima |
| **org** | quem edita um problema. É o prefixo do id. Uma org é privada por padrão |
| **coleção** | um rótulo de agrupamento de problemas. Um problema pode ter várias coleções |
| **veredicto** | o resultado de uma submissão: `Accepted`, `Wrong Answer`, `Time Limit Exceeded` e outros |
| **TL** | time limit: o tempo máximo de execução por teste. O juiz mede o TL na calibração |
| **calibração** | o juiz roda as soluções `good` e mede o TL por máquina e por linguagem |
| **juiz** | a máquina que compila e executa as submissões |
| **placar** | a classificação dos times do contest |
| **sede** | o local físico de uma prova com várias sedes. No MOJ, uma sede é um nome e uma regex no login |
| **módulo** | um grupo de recursos do contest, ligado pelo admin |
| **rodada** | uma etapa do contest, com janela e problemas próprios: aquecimento, prova oficial |
| **token** | a credencial da sessão, guardada em `~/.config/moj/` |
| **spec** | o JSON que descreve um contest para o `create`, o `export` e os templates |
