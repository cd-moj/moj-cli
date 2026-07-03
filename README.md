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
| `moj new <pasta> <prob>` | scaffold completo do pacote em `./<prob>` |
| `moj clone <id> [dir]` | baixa o pacote **inteiro** (enunciado, conf, exemplos, testes, todas as soluções) |
| `moj test [dir]` · `moj push [dir] [--force]` | pré-voo local · envia (cria/edita) |
| `moj preview [dir]` | renderiza o enunciado em HTML (abre no navegador) |
| `moj download <id> [arq]` · `moj upload <id> <arq>` | baixa/sobe o pacote `.tar.gz`/`.tar.bz2`/`.tar.zst`/`.zip` |
| `moj public <id> on\|off` · `moj publish <id>` · `moj calibrate <id>` | publicar (público => o servidor **valida + calibra**) / calibrar |
| `moj status [<id>]` · `moj check <id>` | sem id: saúde do sistema; com id: **QA do problema** (validação, TL por juiz, solução `good` sem TL / falhou em todas as máquinas) |
| `moj board` | painel dos seus problemas: público/validado/calibrado + o que **precisa revisar** |
| `moj mkdir <org>` · `moj share <org> <login>` / `unshare …` | cria org / adiciona membro (quem edita) |
| `moj org list\|create\|members\|public\|rm` | gestão de **orgs**: membros (quem escreve) + **trava de público** (privada por padrão ⇒ problemas nunca ficam públicos; só admin da org muda). `rm <nome>` remove uma org **vazia** (a implícita não sai) |
| `moj mv <id> <org>` | move um **rascunho** p/ outra org (muda o id `<org>#<prob>`; bloqueia se público/em uso) |
| `moj collection ls\|show\|create\|add\|remove\|rename\|delete` | **coleções = TAGS de agrupamento** (m:n, ORTOGONAL à org; o nome pode ter **espaços**). `create "<nome>"`, `add/remove <id> "<nome>"` (marca/desmarca no problema), `show "<nome>"` (browse), `rename`/`delete` (dono da coleção) |

## Pacote do problema (arquivos)

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
  tests/score               # (opcional) grupos de pontuação por subtarefa
  sols/{good,wrong,slow,pass,upcoming}/<arquivo>   # soluções por categoria (good = aceita)
  scripts/                  # (opcional) correção especial (compile/compare por linguagem) — só via 'moj upload'
  .moj-id                   # ponteiro LOCAL (id/repo/prob/TÍTULO/coleções/público) — NÃO é enviado
```

No servidor os metadados ficam em `.moj-meta.json` (`display_title`, `public`, `collections`, `owner`) —
gerado a partir do que você envia; você não o edita à mão. `moj push` manda os campos (title do `.moj-id`);
`moj upload` sobe um `.tar`/`.zip` inteiro (o `.moj-meta.json`, com `display_title`, tem de estar no pacote).

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
`display_title` no `.moj-meta.json` do pacote. Escapes: `moj push --force` / `MOJ_ALLOW_NO_TITLE=1
moj upload …` (o servidor então deriva o título do enunciado/pasta).
